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

 --
 -- Significant speedup
 --

SET SESSION TRANSACTION ISOLATION LEVEL READ UNCOMMITTED;


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

    # the amount of links from redirect pages in a given namespace
    DROP TABLE IF EXISTS rlc;
    CREATE TABLE rlc (
      rlc_cnt int(8) unsigned NOT NULL default '0',
      rlc_id int(8) unsigned NOT NULL default '0'
    ) ENGINE=MEMORY;

    SET @st=CONCAT( 'INSERT INTO rlc SELECT count(*) as rlc_cnt, r_id as rlc_id  FROM pl, r', namespace, ' WHERE pl_from=r_id GROUP BY r_id;' );
    PREPARE stmt FROM @st;
    EXECUTE stmt;
    DEALLOCATE PREPARE stmt;

    # REDIRECT PAGES WITH MORE THAN ONE LINK
    SET @st=CONCAT( 'DROP TABLE IF EXISTS wr', namespace );
    PREPARE stmt FROM @st;
    EXECUTE stmt;
    DEALLOCATE PREPARE stmt;
    SET @st=CONCAT( 'CREATE TABLE wr', namespace, ' (wr_title varchar(255) binary NOT NULL default ', "''", ', PRIMARY KEY (wr_title)) ENGINE=MyISAM;' );
    PREPARE stmt FROM @st;
    EXECUTE stmt;
    DEALLOCATE PREPARE stmt;   

    SET @st=CONCAT( 'INSERT IGNORE INTO wr', namespace, ' SELECT r_title as wr_title FROM r', namespace, ', rlc WHERE rlc_cnt>1 and rlc_id=r_id;' );
    PREPARE stmt FROM @st;
    EXECUTE stmt;
    DEALLOCATE PREPARE stmt;

    DROP TABLE rlc;

    CALL outifexists( CONCAT( 'wr', namespace ), 'wrong redirects', 'wr.txt', 'wr_title', 'out' );

    # prevent taking wrong redirects into account
    SET @st=CONCAT( 'DELETE FROM r', namespace, ' WHERE r_title IN ( SELECT wr_title FROM wr', namespace, ' );' );
    PREPARE stmt FROM @st;
    EXECUTE stmt;
    DEALLOCATE PREPARE stmt;

    IF namespace=14
      THEN
        # redirects in this namespace are prohibited
        # they do not supply articles with proper categories
        CALL outifexists( CONCAT( 'r', namespace ), CONCAT( 'redirects for namespace ', namespace), 'r.txt', 'r_title', 'out' );
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
CREATE PROCEDURE nr2X2nr ()
  BEGIN
    DECLARE cnt INT;
    DECLARE chainlen INT DEFAULT '1';

    SELECT count(*) INTO cnt
           FROM nr2r;

    WHILE cnt>0 DO

      SELECT CONCAT( ':: echo . ', cnt, ' links from non-redirects to non-redirects via a chain of ', chainlen, ' redirects' );

      #
      # Rectify redirects adding appropriate direct links.
      #
      # Note: pl has no unique keys, so data is redundant.
      #
      INSERT INTO pl
      SELECT nr2r_from as pl_from,
             r2nr_to as pl_to
             FROM nr2r,
                  r2nr
             WHERE nr2r_to=r2nr_from;

      SELECT count(*) INTO @pl_count
             FROM pl;

      SELECT CONCAT( ':: echo . ', @pl_count, ' links after ', chainlen, '-redirect chains rectification' );

      #
      # One step of new long-redirect driven "links to be added" collection.
      #
      # Notes: After the redirects throwing nr2r table is deleted, 
      #        so we can change its contents easily. Table r2nr cannot
      #        be used this way because it is involved in articles templating.
      #        Wrong thing: Rings make the loop always running.
      #        On the other hand, this works just when redirect rings are
      #        prevented in r2r.
      #
      DROP TABLE IF EXISTS nr2X2r;
      CREATE TABLE nr2X2r (
        nr2r_to int(8) unsigned NOT NULL default '0',
        nr2r_from int(8) unsigned NOT NULL default '0'
      ) ENGINE=MEMORY;

      INSERT INTO nr2X2r
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
# Constructs all links from redirects to redirects.
#
# Inputs: pl, r, nr.
#
# Outputs: pl modified, mr output into a file, ruwikir, orcatr, r2nr, r2r.
#
DROP PROCEDURE IF EXISTS throw_multiple_redirects//
CREATE PROCEDURE throw_multiple_redirects (namespace INT)
  BEGIN
    DECLARE st VARCHAR(255);

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

    SET @st=CONCAT( 'INSERT INTO l SELECT r_id as l_to, pl_from as l_from FROM pl, r', namespace, ' WHERE pl_from in ( SELECT r_id FROM r', namespace, ' ) and pl_to=r_id;' );
    PREPARE stmt FROM @st;
    EXECUTE stmt;
    DEALLOCATE PREPARE stmt;

    #
    # Names of redirect pages linking other redirects.
    # This table contains everything required for multiple redirects resolving.
    #
    DROP TABLE IF EXISTS mr;
    CREATE TABLE mr (
      mr_title varchar(255) binary NOT NULL default ''
    ) ENGINE=MEMORY;

    SET @st=CONCAT( 'INSERT INTO mr SELECT r_title as mr_title FROM l, r', namespace, ' WHERE l_from=r_id;' );
    PREPARE stmt FROM @st;
    EXECUTE stmt;
    DEALLOCATE PREPARE stmt;

    CALL outifexists( 'mr', 'redirects linking redirects', 'mr.info', 'mr_title', 'upload' );

    DROP TABLE mr;

    #
    # Upper limit on a claster size. Must not be huge; however, let see...
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
    # chains throwing.
    #
    DELETE ruwikir
           FROM orcatr,
                ruwikir
           WHERE coolcat NOT RLIKE '\_1$' and
                 cat=coolcat;

    # Claster _1 is of nothing to do with, regular redirects.
    # Clasters like _X, X>1 are rings and cannot point outside redirects set.
    # Claserts _1_..._1_X, X>1 are like above but with a source chain.
    DELETE FROM orcatr
           WHERE coolcat NOT RLIKE '^\_1\_1';

    # Clasters like _1_..._1 are all to be thrown

    DROP TABLE IF EXISTS r2r;
    CREATE TABLE r2r (
      r2r_to int(8) unsigned NOT NULL default '0',
      r2r_from int(8) unsigned NOT NULL default '0',
      PRIMARY KEY (r2r_to,r2r_from)
    ) ENGINE=MEMORY;

    SET @st=CONCAT( 'INSERT INTO r2r SELECT id as r2r_to, pl_from as r2r_from FROM pl, ruwikir WHERE pl_from in ( SELECT r_id FROM r', namespace, ' ) and pl_to=id;' );
    PREPARE stmt FROM @st;
    EXECUTE stmt;
    DEALLOCATE PREPARE stmt;

    # All links from non-redirects to redirects for a given namespace.
    DROP TABLE IF EXISTS nr2r;
    CREATE TABLE nr2r (
      nr2r_to int(8) unsigned NOT NULL default '0',
      nr2r_from int(8) unsigned NOT NULL default '0',
      KEY (nr2r_to)
    ) ENGINE=MEMORY;

    SET @st=CONCAT( 'INSERT INTO nr2r SELECT r_id as nr2r_to, pl_from as nr2r_from FROM pl, r', namespace, ' WHERE pl_from in ( SELECT id FROM nr', namespace, ' ) and pl_to=r_id;' );
    PREPARE stmt FROM @st;
    EXECUTE stmt;
    DEALLOCATE PREPARE stmt;

    SELECT CONCAT( ':: echo ', count(*), ' links from non-redirects to redirects' )
           FROM nr2r;
           
    # All links from our namespace redirects to non-redirects.
    DROP TABLE IF EXISTS r2nr;
    CREATE TABLE r2nr (
      r2nr_to int(8) unsigned NOT NULL default '0',
      r2nr_from int(8) unsigned NOT NULL default '0'
    ) ENGINE=MEMORY;

    SET @st=CONCAT( 'INSERT INTO r2nr SELECT nr', namespace, '.id as r2nr_to, pl_from as r2nr_from FROM pl, nr', namespace, ' WHERE pl_from in ( SELECT r_id FROM r', namespace, ' ) and pl_to=nr', namespace, '.id;' );
    PREPARE stmt FROM @st;
    EXECUTE stmt;
    DEALLOCATE PREPARE stmt;

    CALL nr2X2nr();

    DROP TABLE nr2r;
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
    DROP TABLE IF EXISTS r2nr;
  END;
//

delimiter ;
############################################################

-- </pre>
