 --
 -- Authors: [[:ru:user:Mashiah Davidson]]
 --
 -- Caution: PROCEDUREs defined here may have output designed for handle.sh.
 --
 -- Shared procedures: cleanup_wrong_redirects
 --                    nr2X2nr
 --                    throw_multiple_redirects
 --                    redirector_unload
 --
 -- Multiple redirects: Some multiple (double, triple, etc) redirects are
 --               collected here. It is strange for me to know that
 --               Mediawiki engine does not recognize most of them.
 --
 -- Wrong redirects: Wrong redirect pages can be found somitimes, and they are
 --                  wrong because they work as redirects in the web but
 --                  contain some garbage links making impossible any links
 --                  analysis in the database.
 --
 -- <pre>

############################################################
delimiter //

#
# Forms wrong redirects table wr and filters redirect pages table appropriately.
# For namespace 14 outputs a list of all redirects because they are prohibited.
#
# Inputs: r, pl.
#
# Outputs: wr, r filtered.
#
DROP PROCEDURE IF EXISTS cleanup_wrong_redirects//
CREATE PROCEDURE cleanup_wrong_redirects (namespace INT)
  BEGIN
    DECLARE st VARCHAR(255);
    DECLARE res VARCHAR(255);
    DECLARE eng VARCHAR(7) DEFAULT 'MEMORY';

    SELECT cry_for_memory( 32*@redirects_count ) INTO @res;
    IF @res!=''
      THEN
        SELECT CONCAT( ':: echo ', @res );
        IF SUBSTRING( @res FROM 1 FOR 8 )='... ... '
          THEN
            SELECT 'MyISAM' INTO @eng;
        END IF;
    END IF;

    # the amount of links from redirect pages in a given namespace
    DROP TABLE IF EXISTS rlc;

    SET @st=CONCAT( "CREATE TABLE rlc ( rlc_cnt int(8) unsigned NOT NULL default '0', rlc_id int(8) unsigned NOT NULL default '0' ) ENGINE=", @eng, ";" );
    PREPARE stmt FROM @st;
    EXECUTE stmt;
    DEALLOCATE PREPARE stmt;

    #
    # INSERT INTO rlc (rlc_cnt, rlc_id)
    # SELECT count(*) as rlc_cnt,
    #        r_id as rlc_id
    #        FROM pl,
    #             r<namespace>
    #        WHERE pl_from=r_id
    #        GROUP BY r_id;
    #
    SET @st=CONCAT( 'INSERT INTO /* SLOW_OK */ rlc (rlc_cnt, rlc_id) SELECT count(*) as rlc_cnt, r_id as rlc_id FROM pl, r', namespace, ' WHERE pl_from=r_id GROUP BY r_id;' );
    PREPARE stmt FROM @st;
    EXECUTE stmt;
    DEALLOCATE PREPARE stmt;

    # REDIRECT PAGES WITH MORE THAN ONE LINK
    SET @st=CONCAT( 'DROP TABLE IF EXISTS wr', namespace );
    PREPARE stmt FROM @st;
    EXECUTE stmt;
    DEALLOCATE PREPARE stmt;
    SET @st=CONCAT( 'CREATE TABLE wr', namespace, ' (wr_title varchar(255) binary NOT NULL default ', "''", ', wr_id int(8) unsigned NOT NULL default ', "'0'", ', PRIMARY KEY (wr_title)) ENGINE=MyISAM;' );
    PREPARE stmt FROM @st;
    EXECUTE stmt;
    DEALLOCATE PREPARE stmt;   

    SET @st=CONCAT( 'INSERT IGNORE INTO wr', namespace, ' (wr_title, wr_id) SELECT r_title as wr_title, r_id as wr_id FROM r', namespace, ', rlc WHERE rlc_cnt>1 and rlc_id=r_id;' );
    PREPARE stmt FROM @st;
    EXECUTE stmt;
    DEALLOCATE PREPARE stmt;

    DROP TABLE rlc;

    CALL outcolifexists( CONCAT( 'wr', namespace ), 'wrong redirects', 'wr.txt', 'wr_title', 'wr_title', 'out' );

    # prevent taking wrong redirects into account
    SET @st=CONCAT( 'DELETE r', namespace, ' FROM r', namespace, ', wr', namespace, ' WHERE r_id=wr_id;' );
    PREPARE stmt FROM @st;
    EXECUTE stmt;
    DEALLOCATE PREPARE stmt;

    IF namespace=14
      THEN
        # redirects in this namespace are prohibited
        # they do not supply articles with proper categories
        CALL outifexists( CONCAT( 'r', namespace ), CONCAT( 'redirects for namespace ', namespace), 'r.txt', 'r_title', 'out' );
    END IF;

    IF namespace=0
      THEN
        CALL actuality( 'znswrongredirects' );
    END IF;
  END;
//

#
# Throws redirects and redirect chains and adds all redirected chains
# into pl table as regular links.
#
# Inputs: r2r, nr2r, r2nr.
#
# Outputs: pl modified
#
DROP PROCEDURE IF EXISTS nr2X2nr//
CREATE PROCEDURE nr2X2nr (iteration INT)
  BEGIN
    DECLARE cnt INT;
    DECLARE chainlen INT DEFAULT '1';

    #
    # Just in case there is no nr2r;
    #
    SET @pl_count=0;

    SELECT count(*) INTO cnt
           FROM nr2r;

    WHILE cnt>0 DO

      SELECT CONCAT( ':: echo . ', cnt, ' links from non-redirects to non-redirects via a chain of ', chainlen, ' redirects found at iteration ', iteration );

      #
      # Rectify redirects adding appropriate direct links.
      #
      INSERT INTO plr (pl_from, pl_to)
      SELECT nr2r_from as pl_from,
             r2nr_to as pl_to
             FROM nr2r,
                  r2nr
             WHERE nr2r_to=r2nr_from;

      #
      # One step of new long-redirect driven "links to be added" collection.
      #
      # Notes: After the redirects seaming nr2r table is being deleted, 
      #        so we can change its contents easily. Table r2nr cannot
      #        be used this way because it is good to keep it for other tools.
      #
      #        Wrong thing: Rings make the loop always running.
      #        On the other hand, this just works provided redirect rings are
      #        prevented in r2r.
      #
      DROP TABLE IF EXISTS nr2X2r;
      CREATE TABLE nr2X2r (
        nr2r_to int(8) unsigned NOT NULL default '0',
        nr2r_from int(8) unsigned NOT NULL default '0'
      ) ENGINE=MEMORY;

      INSERT INTO nr2X2r (nr2r_to, nr2r_from)
      SELECT r2r_to as nr2r_to,
             nr2r_from
             FROM r2r,
                  nr2r
             WHERE r2r_from=nr2r_to;

      DROP TABLE nr2r;

      SELECT count(*) INTO cnt
             FROM nr2X2r;

      #
      # Now X=X2r everywhere
      # 
      RENAME TABLE nr2X2r TO nr2r;

      SET chainlen=chainlen+1;

    END WHILE;
  END;
//

#
# Redirect chanis throwing optimization for huge nr2r tables.
#
# Avoids use of MyISAM tables for nr2r, which makes processing far too slow.
#
# Inputs: pl, r<ns>, nr<ns>.
#
# Outputs: pl modified.
#
DROP PROCEDURE IF EXISTS fast_nr2X2nr//
CREATE PROCEDURE fast_nr2X2nr (namespace INT)
  BEGIN
    DECLARE st VARCHAR(255);
    DECLARE portion INT;
    DECLARE shift INT DEFAULT '0';
    DECLARE pcnt INT;
    DECLARE iteration INT DEFAULT '0';
    DECLARE my_plcount INT;

    SELECT CAST(@@max_heap_table_size/32 AS UNSIGNED) INTO portion;

    SET pcnt=portion;

    SELECT @base_pl_count INTO my_plcount;

    SELECT ':: echo starting nr2r iterations';

    SET @starttime1=now();

    DROP TABLE IF EXISTS nr2r;

    WHILE my_plcount>0 DO

      IF portion > my_plcount
        THEN
          SELECT my_plcount INTO portion;
      END IF;

      DROP /* SLOW_OK */ TABLE IF EXISTS part_pl;
      CREATE TABLE part_pl (
        dst int(8) unsigned NOT NULL default '0',
        src int(8) unsigned NOT NULL default '0'
      ) ENGINE=MEMORY;

      #
      # INSERT INTO part_pl /* SLOW_OK */ (dst,src)
      # SELECT pl_to as dst,
      #        pl_from as src
      #        FROM pl
      #        LIMIT <shift>,<portion>;
      #
      SET @st=CONCAT( 'INSERT INTO part_pl /* SLOW_OK */ (dst,src) SELECT pl_to as dst, pl_from as src FROM pl LIMIT ', shift, ',', portion, ';' );
      PREPARE stmt FROM @st;
      EXECUTE stmt;
      DEALLOCATE PREPARE stmt;

      CREATE TABLE nr2r (
        nr2r_to int(8) unsigned NOT NULL default '0',
        nr2r_from int(8) unsigned NOT NULL default '0',
        KEY (nr2r_to)
      ) ENGINE=MEMORY;

      #
      # INSERT INTO nr2r (nr2r_to, nr2r_from)
      # SELECT r_id as nr2r_to,
      #        src as nr2r_from
      #        FROM part_pl,
      #             r<namespace>
      #        WHERE src in (
      #                       SELECT id
      #                              FROM nr<namespace>
      #                     ) and
      #              dst=r_id;
      #
      SET @st=CONCAT( 'INSERT INTO nr2r (nr2r_to, nr2r_from) SELECT r_id as nr2r_to, src as nr2r_from FROM part_pl, r', namespace, ' WHERE src in ( SELECT id FROM nr', namespace, ' ) and dst=r_id ORDER BY r_id;' );
      PREPARE stmt FROM @st;
      EXECUTE stmt;
      DEALLOCATE PREPARE stmt;

      SELECT count(*) INTO pcnt
             FROM nr2r;

      IF pcnt>0
        THEN
          CALL nr2X2nr(iteration);
      END IF;

      DROP TABLE nr2r;

      DROP /* SLOW_OK */ TABLE part_pl;

      SELECT my_plcount-portion INTO my_plcount;
      SELECT shift+portion INTO shift;
      SELECT iteration+1 INTO iteration;

    END WHILE;

    SELECT CONCAT( ':: echo nr2r links caching time: ', TIMEDIFF(now(), @starttime1));
  END;
//

#
# Constructs all links from redirects to redirects.
#
# Inputs: pl, r<ns>, nr<ns>.
#
# Outputs: pl modified, mr output into a file, ruwikir, orcatr, r2nr, r2r.
#
DROP PROCEDURE IF EXISTS throw_multiple_redirects//
CREATE PROCEDURE throw_multiple_redirects (namespace INT)
  BEGIN
    DECLARE st VARCHAR(255);
    DECLARE res VARCHAR(255);
    DECLARE cnt VARCHAR(255);
    DECLARE est1 VARCHAR(255) DEFAULT '';
    DECLARE est2 VARCHAR(255) DEFAULT '';

    #
    # Long redirects like double and triple do not work in web API,
    # thus they need to be straightened.
    #
    # Reaching the target via a long redirect requires more than one click,
    # but all hyperlink jumps are uniquely defined and can be easily fixed.
    # Here links via long redirects are threated as valid links for
    # connectivity analysis.
    #

    #
    # All links from and to redirects in our namespace.
    #
    DROP TABLE IF EXISTS l;
    CREATE TABLE l (
      l_to int(8) unsigned NOT NULL default '0',
      l_from int(8) unsigned NOT NULL default '0',
      PRIMARY KEY (l_to,l_from)
    ) ENGINE=MEMORY;

    SET @st=CONCAT( 'SELECT count(*) INTO @cnt FROM r', namespace, ';' );
    PREPARE stmt FROM @st;
    EXECUTE stmt;
    DEALLOCATE PREPARE stmt;

    SELECT cry_for_memory( 32*@cnt ) INTO @res;
    IF @res!=''
      THEN
        SELECT CONCAT( ':: echo ', @res );
    END IF;

    IF SUBSTRING( @res FROM 1 FOR 8 )='... ... '
      THEN
        SELECT ':: echo ... MyISAM engine is chosen for redirect identifiers table';
        SELECT 'MyISAM' INTO @r_identifiers_engine;
      ELSE
        SELECT 'MEMORY' INTO @r_identifiers_engine;
    END IF;

    DROP TABLE IF EXISTS rrr;
    SET @st=CONCAT( "CREATE TABLE rrr ( pid int(8) unsigned NOT NULL default '0', PRIMARY KEY (pid) ) ENGINE=", @r_identifiers_engine, ";" );
    PREPARE stmt FROM @st;
    EXECUTE stmt;
    DEALLOCATE PREPARE stmt;

    SET @st=CONCAT( 'INSERT INTO rrr (pid) SELECT r_id as pid FROM r', namespace, ';' );
    PREPARE stmt FROM @st;
    EXECUTE stmt;
    DEALLOCATE PREPARE stmt;

    INSERT INTO l (l_to, l_from)
    SELECT pl_to as l_to,
           pl_from as l_from
           FROM pl,
                rrr as rrr1,
                rrr as rrr2
           WHERE pl_from=rrr1.pid and
                 pl_to=rrr2.pid;

    #
    # Names of redirect pages linking other redirects.
    # This table contains everything required for multiple redirects resolving.
    #
    DROP TABLE IF EXISTS mr;
    CREATE TABLE mr (
      mr_title varchar(255) binary NOT NULL default ''
    ) ENGINE=MEMORY;

    IF namespace!=0
      THEN
        SET @st=CONCAT( 'INSERT INTO mr (mr_title) SELECT CONCAT( getnsprefix( ', namespace, ', "', @target_lang, '" ), r_title ) as mr_title FROM l, r', namespace, ' WHERE l_from=r_id;' );
        PREPARE stmt FROM @st;
        EXECUTE stmt;
        DEALLOCATE PREPARE stmt;
      ELSE
        INSERT INTO mr (mr_title)
        SELECT r_title as mr_title
               FROM l,
                    r0
               WHERE l_from=r_id;
    END IF;

    CALL outifexists( 'mr', 'redirects linking redirects', 'mr.info', 'mr_title', 'upload mr' );

    DROP TABLE mr;

    #
    # Upper limit on a cluster size. Must not be huge; however, let see...
    #
    SET @st=CONCAT( 'SELECT count(*) INTO @rcount FROM r', namespace, ';' );
    PREPARE stmt FROM @st;
    EXECUTE stmt;
    DEALLOCATE PREPARE stmt;

    #
    # Isolated analysis of redirecting links to avoid rings and throw multiple
    # redirect chains.
    #
    CALL isolated( namespace, 'redirects', @rcount );

    #
    # now we have orcatr and ruwikir.
    #
    CALL isolated_refresh( 'r', namespace );

    #
    # Prevent redirect rings in r2r table for normal function of other
    # chains seaming.
    #
    DELETE ruwikir
           FROM orcatr,
                ruwikir
           WHERE coolcat NOT RLIKE '\_1$' and
                 cat=uid;

    # Cluster _1 is of nothing to do with, regular redirects.
    # Clusters like _X, X>1 are rings and cannot point outside redirects set.
    # Cluserts _1_..._1_X, X>1 are like above but with a source chain.
    DELETE FROM orcatr
           WHERE coolcat NOT RLIKE '^\_1\_1';

    # Clusters like _1_..._1 are all to be thrown

    SET @starttime1=now();

    DROP TABLE IF EXISTS r2r;
    CREATE TABLE r2r (
      r2r_to int(8) unsigned NOT NULL default '0',
      r2r_from int(8) unsigned NOT NULL default '0',
      PRIMARY KEY (r2r_to,r2r_from)
    ) ENGINE=MEMORY;

    # All links from our namespace redirects to non-redirects.
    DROP TABLE IF EXISTS r2nr;

    SET @st=CONCAT( "CREATE TABLE r2nr ( r2nr_to int(8) unsigned NOT NULL default '0', r2nr_from int(8) unsigned NOT NULL default '0' ) ENGINE=", @nr_eng, ";" );
    PREPARE stmt FROM @st;
    EXECUTE stmt;
    DEALLOCATE PREPARE stmt;

    # INSERT INTO /* SLOW_OK */ r2r (r2r_to, r2r_from)
    # SELECT id as r2r_to,
    #        src as r2r_from
    #        FROM part_pl,
    #             ruwikir
    #        WHERE src in (
    #                      SELECT pid
    #                             FROM rrr
    #                     ) and
    #              dst=id;
    SET @est1='INSERT INTO /* SLOW_OK */ r2r (r2r_to, r2r_from) SELECT id as r2r_to, src as r2r_from FROM part_pl, ruwikir WHERE src in ( SELECT pid FROM rrr ) and dst=id;';

    #
    # INSERT INTO /* SLOW_OK */ r2nr (r2nr_to, r2nr_from)
    # SELECT nr<namespace>.id as r2nr_to,
    #        src as r2nr_from
    #        FROM part_pl,
    #             nr<namespace>
    #        WHERE src in (
    #                      SELECT pid
    #                             FROM rrr
    #                     ) and
    #              dst=nr<namespace>.id;
    #
    SET @est2=CONCAT( 'INSERT INTO /* SLOW_OK */ r2nr (r2nr_to, r2nr_from) SELECT nr', namespace, '.id as r2nr_to, src as r2nr_from FROM part_pl, nr', namespace, ' WHERE src in ( SELECT pid FROM rrr ) and dst=nr', namespace, '.id;' );

    SELECT ':: echo starting r2r/r2nr iterations';

    CALL pl_by_parts( @base_pl_count, 0, @est1, @est2 );

    SELECT CONCAT( ':: echo r2r/r2nr links caching time: ', TIMEDIFF(now(), @starttime1));

    DROP TABLE orcatr;
    DROP TABLE ruwikir;
    DROP TABLE rrr;

    IF namespace=0
      THEN
        #
        # Redirects to disambiguation pages.
        #
        DROP TABLE IF EXISTS cnad;
        CREATE TABLE cnad (
          cnad_id int(8) unsigned NOT NULL default '0',
          PRIMARY KEY (cnad_id)
        ) ENGINE=MEMORY AS
        SELECT DISTINCT r2nr_from as cnad_id
               FROM r2nr,
                    d
               WHERE r2nr_to=d_id;

        #
        # Now disambiguation pages and redirects to.
        #
        # Note: Redirects are being merged to disambiguation pages,
        #       so key violation impossible.
        #
        INSERT INTO cnad (cnad_id)
        SELECT d_id as cnad_id
               FROM d;

        IF @iwspy!='off'
          THEN
            #
            # Redirects to pages not forming valid links.
            #
            DROP TABLE IF EXISTS cnar;
            CREATE TABLE cnar (
              cnar_id int(8) unsigned NOT NULL default '0',
              KEY (cnar_id)
            ) ENGINE=MEMORY AS
            SELECT DISTINCT r2nr_from as cnar_id
                   FROM r2nr,
                        cna
                   WHERE r2nr_to=cna_id;

            #
            # For redundant titles filtering in iwikispy.
            #
            DROP TABLE IF EXISTS iw_filter;
            CREATE TABLE iw_filter (
              name varchar(255) binary NOT NULL default '',
              PRIMARY KEY (name)
            ) ENGINE=MEMORY;

            INSERT INTO iw_filter (name)
            SELECT title as name
                   FROM nr0,
                        cna
                   WHERE cna_id=id;

            #
            # Note: Redirects are being merged to articles,
            #       so key violation looks impossible.
            #       However, better to prevent, because data is live and could
            #       change during selection.
            #
            INSERT INTO iw_filter (name)
            SELECT r_title as name
                   FROM r0,
                        cnar
                   WHERE cnar_id=r_id
            ON DUPLICATE KEY UPDATE name=r_title;

            SELECT CONCAT( ':: echo ', count(*), ' distinct page titles correspond to pages not forming valid links' )
                   FROM iw_filter;

            DROP TABLE cnar;
        END IF;
    END IF;

    #
    # One more infinite loop prevention step.
    #
    DELETE FROM r2r
           WHERE r2r_to=r2r_from;

    DROP TABLE IF EXISTS plr;
    CREATE TABLE plr (
      pl_from int(8) unsigned NOT NULL default '0',
      pl_to int(8) unsigned NOT NULL default '0'
    ) ENGINE=MyISAM;

    CALL fast_nr2X2nr( namespace );

    # kill duplicates and make order
    ALTER /* SLOW_OK */ IGNORE TABLE plr ADD PRIMARY KEY (pl_from, pl_to);

    INSERT INTO pl (pl_from, pl_to)
    SELECT pl_from,
           pl_to
           FROM plr;

    SELECT CONCAT( ':: echo ', count(*), ' distinct links through a redirect chain' )
           FROM plr;

    DROP TABLE IF EXISTS bwl;
    CREATE TABLE bwl (
      id int(8) unsigned NOT NULL default '0'
    ) ENGINE=MEMORY;

    INSERT INTO bwl (id)
    SELECT pl_from as id
           FROM plr
           WHERE pl_from=pl_to;

    DROP TABLE plr;

    CALL outifexists( CONCAT( 'bwl' ), 'pages back-linked through redirect chains', 'bwl.txt', 'id', 'out' );

    DROP TABLE bwl;

    SELECT count(*) INTO @pl_count
           FROM pl;

    SELECT CONCAT( ':: echo ', @pl_count, ' overall (direct & redirected) links count' );
  END;
//

DROP PROCEDURE IF EXISTS redirector_unload//
CREATE PROCEDURE redirector_unload (namespace INT)
  BEGIN
    # partial namespacer unload
    IF namespace=0
      THEN
        DROP TABLE IF EXISTS r0;
      ELSE
        ALTER TABLE r14 ENGINE=MyISAM;
    END IF;
    IF namespace!=10
      THEN
        DROP TABLE IF EXISTS r2nr;
      ELSE
        DROP TABLE IF EXISTS r2nr10;
        RENAME TABLE r2nr TO r2nr10;
    END IF;

    DROP TABLE r2r;
  END;
//

delimiter ;
############################################################

-- </pre>
