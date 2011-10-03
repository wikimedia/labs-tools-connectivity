 --
 -- Authors: [[:ru:user:Mashiah Davidson]]
 --
 -- Caution: PROCEDUREs defined here may have output designed for handle.sh.
 -- 
 -- Shared procedures: isolated
 --                    isolated_refresh
 --              
 -- Relevant linking concept: First, based on an article definition, links
 --                           from articles considered only.
 --
 --                           Links from chronological articles are not too
 --                           relevant, and they are threated as links from 
 --                           a time-oriented portal.
 --
 -- Types of isolated cluster chains: The connectivity analysis here relies on
 --                                   some concepts from [[graphs theory]].
 --                                   One important thing is the concept of
 --                                   a [[strongly connected component]] 
 --                                   (aka scc or cluster), which is
 --                                   the subgraph of a graph given of the
 --                                   maximal possible size with every verticle
 --                                   (article) reachable from each other in
 --                                   this subgraph.
 --                                   We are interested in orphaned strongly
 --                                   connected components (aka oscc), and
 --                                   chains of such orphaned clusters.
 --                                   It is kwown after ... (do not remember)
 --                                   that clusters are all constructed from
 --                                   cycles of various sizes.
 --
 -- Expected outputs: Isolated cluster chains of various types, what's to be
 --                   (un)taged in relation to disconnexion.
 --
 -- Tested with: Article links
 --              Categorytree links
 --              Redirects in various namespaces
 --
 -- <pre>

############################################################
delimiter //

#
# Filters out links from timelines (chronological articles).
# Also adds links to {{templated}} articles, because they cannot be
# considered as non-reachable and even don't need any clicks to be read.
#
# Note: Designed especially for articles, not for categories or redirects.
#
DROP PROCEDURE IF EXISTS apply_linking_rules//
CREATE PROCEDURE apply_linking_rules (namespace INT)
  BEGIN
    # deletion of links from timelines
    DELETE FROM l
           WHERE l_from IN
                 (
                  SELECT chr_id
                         FROM chrono
                 );

    SELECT @articles_to_articles_links_count-count(*) INTO @chrono_to_articles_links_count
           FROM l;

    SELECT CONCAT( ':: echo ', count(*), ' links after chrono-cleanup' )
           FROM l;

    #
    #  Well, next, if an article is {{included as a template}}
    #  it is, probably, not isolated, because it is visible
    #  even without any hyperlink jumping.
    #

    #
    # {{templating}} of articles is equivalent to links
    # from including articles to included ones.
    #

    CALL a2a_templating();

    #
    # Copy resulting redirected templating links to l.
    #
    INSERT IGNORE INTO l (l_to, l_from)
    SELECT pl_to as l_to,
           pl_from as l_from
           FROM pl;
    DROP TABLE pl;

    SELECT CONCAT( ':: echo ', count(*), ' links after redirected templating interpretion' )
           FROM l;
  END;
//

#
# Obtains maximal isolated subgraph of a given graph.
#
DROP PROCEDURE IF EXISTS oscchull//
CREATE PROCEDURE oscchull (OUT linkscount INT)
  BEGIN
    DECLARE prevlinkscount INT;

    REPEAT
    
      SELECT count(*) INTO prevlinkscount FROM otl;

      DROP TABLE IF EXISTS otllc;
      CREATE TABLE otllc(
        otllc_pid int(8) unsigned NOT NULL default '0',
        otllc_amnt int(8) unsigned NOT NULL default '0',
        PRIMARY KEY (otllc_pid)
      ) ENGINE=MEMORY AS
      SELECT otl_to as otllc_pid,
             count( * ) as otllc_amnt
             FROM otl
             GROUP BY otl_to;

      #
      # lc stores amount of links for articles belonging a component of size
      #    above the limit (maxsize)
      # otllc stores amount of links for articles, which may belog to
      #       components of size < maxsize.
      #
      # Once the amount of links in lc and otllc is different
      # (usually otllc_ambt < lc_amnt) it is time to consider link sources as
      # linked from a large component  and and exclude it from otl.
      #
      DELETE FROM todelete;
      INSERT INTO todelete (id)
             SELECT lc_pid as id
                    FROM lc,
                         otllc
                    WHERE otllc_pid=lc_pid and
                          otllc_amnt!=lc_amnt;
      DELETE FROM otl
             WHERE otl_from IN
                   (
                    SELECT id
                           FROM todelete
                   );

      DELETE FROM aset;
      INSERT INTO aset (id)
      SELECT DISTINCT otl_from as id
             FROM otl;

      DELETE FROM todelete;
      INSERT INTO todelete (id)
             SELECT DISTINCT otl_to as id
                    FROM otl
                    WHERE otl_to NOT IN
                          (
                           SELECT id
                                  FROM aset
                          );
      DELETE FROM otl
             WHERE otl_to IN
                   (
                    SELECT id
                           FROM todelete
                   );

      DELETE FROM aset;
      INSERT INTO aset (id)
      SELECT DISTINCT otl_to as id
             FROM otl;

      DELETE FROM todelete;
      INSERT INTO todelete (id)
             SELECT DISTINCT otl_from as id
                    FROM otl
                    WHERE otl_from NOT IN
                          (
                           SELECT id
                                  FROM aset
                          );
      DELETE FROM otl
             WHERE otl_from IN
                   (
                    SELECT id
                           FROM todelete
                   );

      SELECT count(*) INTO linkscount FROM otl;

    UNTIL prevlinkscount=linkscount
    END REPEAT;

  END;
//

#
# CORE, DELETION OF HUGE OR LINKED SCC's
#
# Output: otl table containing only top-level clusters of allowed size.
#
DROP PROCEDURE IF EXISTS filterscc//
CREATE PROCEDURE filterscc (IN rank INT)
  BEGIN
    #
    # Groups receiving new elements during reversed minimums flow should be
    # marked by nodes, which are out of top level (not linked) clusters
    # (there is nothing to spread minimum to at the top level).
    #
    # Here we select for group identifiers common for ga and rga but with
    # new elements in rga compared to ga.
    #
    DROP TABLE IF EXISTS newparent_grps;
    CREATE TABLE newparent_grps (
      gid int( 8 ) unsigned NOT NULL default '0'
    ) ENGINE=MEMORY AS
    SELECT DISTINCT rga.f as gid
           FROM ga,
                rga
           WHERE ga.id=rga.id AND
                 ga.f>rga.f;

    DELETE FROM todelete;

    #
    # Groups marked in direct minimums flow by nodes out of top level clusters
    # are out of top level clusters and should be marked for deletion.
    #
    INSERT INTO todelete (id)
    SELECT id
           FROM ga,
                newparent_grps
           WHERE f=gid;

    #
    # Repetition but with maximums instead of minimums.
    #
    DROP TABLE IF EXISTS newparent_grps;
    CREATE TABLE newparent_grps (
      gid int( 8 ) unsigned NOT NULL default '0'
    ) ENGINE=MEMORY AS
    SELECT DISTINCT rga.g as gid
           FROM ga,
                rga
           WHERE ga.id=rga.id AND
                 ga.g<rga.g;

    INSERT INTO todelete (id)
    SELECT id
           FROM ga,
                newparent_grps
           WHERE g=gid
    ON DUPLICATE KEY UPDATE id=ga.id;


    #
    # Nodes, whose group id changes during reversed minimums flow are marked
    # in direct flow by a node, which is upper to them, because there were
    # no bacward links found during the reversed flow.
    #
    # Note: May contain nodes already marked for deletion.
    #
    INSERT INTO todelete (id)
    SELECT ga.id
           FROM ga,
                rga
           WHERE ga.id=rga.id and
                 ga.f<rga.f
    ON DUPLICATE KEY UPDATE id=ga.id;

    #
    # Repetition but with maximums instead of minimums.
    #
    INSERT INTO todelete (id)
    SELECT ga.id
           FROM ga,
                rga
           WHERE ga.id=rga.id and
                 ga.g>rga.g
    ON DUPLICATE KEY UPDATE id=ga.id;

    #
    # Should mark too huge (cnt>rank) closed (stable up to links reversing)
    # clusters for deletion.
    #
    INSERT INTO todelete (id)
    SELECT ga.id
           FROM ga,
                rga,
                grp,
                rgrp
           WHERE grp.cnt=rgrp.cnt and
                 grp.id=rgrp.id and
                 grp.cnt>rank and
                 grp.id=ga.f and
                 rgrp.id=rga.f and
                 ga.f=rga.f and
                 ga.id=rga.id;

    #
    # Deletion of links from otl.
    #
    DELETE FROM otl
           WHERE otl_from IN
                 (
                  SELECT id
                         FROM todelete
                 );

    #
    # Links were just deleted from otl, it could become an open set again,
    # thus it is necessary to reduce the nodes set down to the maximal isolated
    # subgraph of the graph given by otl.
    #
    CALL oscchull( @alldeleted );

  END;
//

#
# Look for cluster id for each article pretending to be isolated.
#
DROP PROCEDURE IF EXISTS grpsplitga//
CREATE PROCEDURE grpsplitga ()
  BEGIN
    DECLARE changescount INT;
    DECLARE st VARCHAR(255);

    # copy otl as required using a given links order
    DROP TABLE IF EXISTS eotl;

    #
    # CREATE TABLE eotl(
    #   eotl_from int(8) unsigned NOT NULL default '0',
    #   eotl_to int(8) unsigned NOT NULL default '0',
    #   KEY (eotl_from),
    #   KEY (eotl_to)
    # ) ENGINE=<otl_eng>;
    #
    SET @st=CONCAT( 'CREATE TABLE eotl( eotl_from int(8) unsigned NOT NULL default "0", eotl_to int(8) unsigned NOT NULL default "0", KEY (eotl_from), KEY (eotl_to) ) ENGINE=', @otl_eng, ';' );
    PREPARE stmt FROM @st;
    EXECUTE stmt;
    DEALLOCATE PREPARE stmt;

    INSERT INTO eotl (eotl_from, eotl_to)
    SELECT otl_from as eotl_from,
           otl_to as eotl_to
           FROM otl;
    # add self-links to avoid loosing minimal id for articles having it
    INSERT INTO eotl (eotl_from, eotl_to)
           SELECT DISTINCT otl_from as eotl_from,
                           otl_from as eotl_to
                  FROM otl;

    # initializing search with min of ids of parents as a cluster id for each 
    # article
    DROP TABLE IF EXISTS ga;
    CREATE TABLE ga (
      f int(8) unsigned NOT NULL default '0',
      g int(8) unsigned NOT NULL default '0',
      id int(8) unsigned NOT NULL default '0',
      PRIMARY KEY (id)
    ) ENGINE=MEMORY AS
    SELECT min(eotl_from) as f,
           max(eotl_from) as g,
           eotl_to as id
           FROM eotl
           GROUP BY eotl_to;

    REPEAT

      # simple copy of ga, name changed to mftmp
      DROP TABLE IF EXISTS mftmp;
      CREATE TABLE mftmp (
        f int(8) unsigned NOT NULL default '0',
        g int(8) unsigned NOT NULL default '0',
        id int(8) unsigned NOT NULL default '0',
        PRIMARY KEY (id)
      ) ENGINE=MEMORY AS
      SELECT f,
             g,
             id
             FROM ga;

      # look for parents for current minimal group id there
      DROP TABLE IF EXISTS ga;
      CREATE TABLE ga (
        f int(8) unsigned NOT NULL default '0',
        g int(8) unsigned NOT NULL default '0',
        id int(8) unsigned NOT NULL default '0',
        PRIMARY KEY (id)
      ) ENGINE=MEMORY AS
      SELECT min(f) as f,
             max(g) as g,
             eotl_to as id
             FROM eotl,
                  mftmp
             WHERE id=eotl_from
             GROUP BY eotl_to;

      # if there any changes occured
      SELECT count( * ) INTO changescount
             FROM ga,
                  mftmp
             WHERE mftmp.id=ga.id and
                   mftmp.g-mftmp.f!=ga.g-ga.f;

    UNTIL changescount=0
    END REPEAT;

    # making count of members for each group
    DROP TABLE IF EXISTS grp;
    CREATE TABLE grp (
      id int(8) unsigned NOT NULL default '0',
      cnt int(8) unsigned NOT NULL default '0'
    ) ENGINE=MEMORY AS
    SELECT count(*) as cnt,
           f as id
           FROM ga
           GROUP BY f;

  END;
//

#
# Look for cluster id for each article pretending to be isolated
# when all the links direction is inversed.
#
DROP PROCEDURE IF EXISTS grpsplitrga//
CREATE PROCEDURE grpsplitrga ()
  BEGIN
    DECLARE changescount INT;
    DECLARE st VARCHAR(255);

    # copy otl as required using a given links order
    DROP TABLE IF EXISTS eotl;

    #
    # CREATE TABLE eotl(
    #   eotl_from int(8) unsigned NOT NULL default '0',
    #   eotl_to int(8) unsigned NOT NULL default '0',
    #   KEY (eotl_from),
    #   KEY (eotl_to)
    # ) ENGINE=<otl_eng>;
    #
    SET @st=CONCAT( 'CREATE TABLE eotl( eotl_from int(8) unsigned NOT NULL default "0", eotl_to int(8) unsigned NOT NULL default "0", KEY (eotl_from), KEY (eotl_to) ) ENGINE=', @otl_eng, ';' );
    PREPARE stmt FROM @st;
    EXECUTE stmt;
    DEALLOCATE PREPARE stmt;

    INSERT INTO eotl (eotl_from, eotl_to)
    SELECT otl_to as eotl_from,
           otl_from as eotl_to
           FROM otl;
    # add self-links to avoid loosing minal id for articles having it
    INSERT INTO eotl (eotl_from, eotl_to)
           SELECT DISTINCT otl_to as eotl_from,
                           otl_to as eotl_to
                  FROM otl;

    # initializing search with min of ids of parents as a cluster id for each 
    # article
    DROP TABLE IF EXISTS rga;
    CREATE TABLE rga (
      f int(8) unsigned NOT NULL default '0',
      g int(8) unsigned NOT NULL default '0',
      id int(8) unsigned NOT NULL default '0',
      PRIMARY KEY (id)
    ) ENGINE=MEMORY AS
    SELECT min(eotl_from) as f,
           max(eotl_from) as g,
           eotl_to as id
           FROM eotl
           GROUP BY eotl_to;

    REPEAT

      # simple copy of rga, name changed to mftmp
      DROP TABLE IF EXISTS mftmp;
      CREATE TABLE mftmp (
        f int(8) unsigned NOT NULL default '0',
        g int(8) unsigned NOT NULL default '0',
        id int(8) unsigned NOT NULL default '0',
        PRIMARY KEY (id)
      ) ENGINE=MEMORY AS
      SELECT f,
             g,
             id
             FROM rga;

      # look for parents for current minimal group id there
      DROP TABLE IF EXISTS rga;
      CREATE TABLE rga (
        f int(8) unsigned NOT NULL default '0',
        g int(8) unsigned NOT NULL default '0',
        id int(8) unsigned NOT NULL default '0',
        PRIMARY KEY (id)
      ) ENGINE=MEMORY AS
      SELECT min(f) as f,
             max(g) as g,
             eotl_to as id
             FROM eotl,
                  mftmp
             WHERE id=eotl_from
             GROUP BY eotl_to;

      # if there any changes occured
      SELECT count( * ) INTO changescount
             FROM rga,
                  mftmp
             WHERE mftmp.id=rga.id and
                   mftmp.g-mftmp.f!=rga.g-rga.f;

    UNTIL changescount=0
    END REPEAT;

    # making count of members for each group
    DROP TABLE IF EXISTS rgrp;
    CREATE TABLE rgrp (
      id int(8) unsigned NOT NULL default '0',
      cnt int(8) unsigned NOT NULL default '0'
    ) ENGINE=MEMORY AS
    SELECT count(*) as cnt,
           f as id
           FROM rga
           GROUP BY f;

  END;
//

#
# Returns unique isolated category identifier by a category pseudo-name.
#
DROP FUNCTION IF EXISTS catuid//
CREATE FUNCTION catuid (coolname VARCHAR(255))
  RETURNS INT
  DETERMINISTIC
  BEGIN
    DECLARE res INT;

    SELECT uid INTO res
           FROM orcat
           WHERE coolcat=coolname;

    RETURN res;
  END;
//

#
# Converts useful and clear orcat names to human-readable (?) form.
#
DROP FUNCTION IF EXISTS convertcoolcat//
CREATE FUNCTION convertcoolcat ( wcoolcat VARCHAR(255) )
  RETURNS VARCHAR(255)
  DETERMINISTIC
  BEGIN
    DECLARE argue INT;
    DECLARE outcat VARCHAR(255) DEFAULT '';
    DECLARE trstr VARCHAR(255) DEFAULT '';
    DECLARE trsym CHAR(1) DEFAULT '';

    IF @orphan_param_name=''
      THEN
        SET outcat=wcoolcat;
      ELSE
        IF @isolated_ring_param_name=''
          THEN
            SET outcat=wcoolcat;
          ELSE
            IF @isolated_cluster_param_name=''
              THEN
                SET outcat=wcoolcat;
              ELSE
                WHILE wcoolcat!='' DO
                  CASE RIGHT( wcoolcat, 2 )
                    WHEN '_1'
                      THEN
                        SET argue=-1;
                        WHILE RIGHT( wcoolcat, 2 ) = '_1' DO
                          SET wcoolcat=LEFT( wcoolcat, LENGTH( wcoolcat ) - 2 );
                          SET argue=argue+1;
                        END WHILE;
                        IF argue>-1
                          THEN
                            SET outcat=CONCAT( @orphan_param_name, argue, outcat );
                        END IF;
                    WHEN '_2'
                      THEN
                        WHILE RIGHT( wcoolcat, 2 ) = '_2' DO
                          SET wcoolcat=LEFT( wcoolcat, LENGTH( wcoolcat ) - 2 );
                          SET outcat=CONCAT( @isolated_ring_param_name, '2', outcat );
                        END WHILE;
                    ELSE
                      SET trstr='';
                      REPEAT
                        SET trsym=RIGHT( wcoolcat, 1 );
                        SET trstr=CONCAT( trsym, trstr );
                        SET wcoolcat=LEFT( wcoolcat, LENGTH( wcoolcat ) - 1 );
                      UNTIL trsym='_'
                      END REPEAT;
                      SET outcat=CONCAT( @isolated_cluster_param_name, RIGHT( trstr, LENGTH( trstr )-1 ), outcat );
                  END CASE;  
                END WHILE;
            END IF;
        END IF;
    END IF;
    RETURN CONCAT( @isolated_category_name, '/', outcat );
  END;
//

#
# Identifies isolated singlets (orphanes).
#
DROP PROCEDURE IF EXISTS _1//
CREATE PROCEDURE _1 (category VARCHAR(255), targetset VARCHAR(255))
  BEGIN
    DECLARE catknown INT;
    DECLARE cntr INT;

    SELECT count(*) INTO cntr
           FROM parented
           WHERE pid NOT IN
                 (
                  SELECT lc_pid
                         FROM lc
                 );
    IF cntr>0
      THEN
        SELECT count(*) INTO catknown
               FROM orcat
               WHERE coolcat=category;

        IF catknown=0
          THEN
            INSERT INTO orcat (uid, cat, coolcat)
            SELECT @freecatid as uid,
                   convertcoolcat( category ) as cat,
                   category as coolcat;
            SET @freecatid=@freecatid+1;
        END IF;

        INSERT INTO isolated (id, cat, act)
        SELECT pid as id,
               catuid(category) as cat,
               1 as act
               FROM parented
               WHERE pid NOT IN
                     (
                      SELECT lc_pid
                             FROM lc
                     )
        # this disables any action for articles already registered properly
        ON DUPLICATE KEY UPDATE act=0;
    END IF;
  END;
//

DROP FUNCTION IF EXISTS smart_action//
CREATE FUNCTION smart_action(cluster_size INT, acnt INT)
  RETURNS INT
  DETERMINISTIC
  BEGIN
    DECLARE result INT;

    IF acnt<2*cluster_size
      THEN
        SET result=0;
        SET @principle_component_size=cluster_size;
      ELSE
        SET result=1;
    END IF;

    RETURN result;
  END;
//

#
# Orphaned strongly connected components (oscc) with 1 < size <= maxsize.
#
DROP PROCEDURE IF EXISTS oscc//
CREATE PROCEDURE oscc (maxsize INT, upcat VARCHAR(255), targetset VARCHAR(255))
  BEGIN
    DECLARE lcnt INT;
    DECLARE res VARCHAR(255);

    SELECT sum(lc_amnt) INTO @lcnt
           FROM lc
           WHERE lc_amnt<maxsize;

    SELECT 'MEMORY' INTO @otl_eng;

    SELECT cry_for_memory( 54*@lcnt ) INTO @res;
    # @res could be reported up here but we would like to keep it silent

    DROP TABLE IF EXISTS otl;
    # all links to pages having no more than maxsize-1 parenting links
    IF SUBSTRING( @res FROM 1 FOR 8 )='... ... '
      THEN
        CREATE TABLE otl(
          otl_to int(8) unsigned NOT NULL default '0',
          otl_from int(8) unsigned NOT NULL default '0',
          KEY (otl_from),
          KEY (otl_to)
        ) ENGINE=MyISAM;

        SELECT 'MyISAM' INTO @otl_eng;
      ELSE
        CREATE TABLE otl(
          otl_to int(8) unsigned NOT NULL default '0',
          otl_from int(8) unsigned NOT NULL default '0',
          KEY (otl_from),
          KEY (otl_to)
        ) ENGINE=MEMORY;
    END IF;

    INSERT INTO otl /* SLOW OK */ (otl_to, otl_from)
    SELECT l_to as otl_to,
           l_from as otl_from
           FROM lc,
                l
           WHERE lc_pid=l_to and
                 lc_amnt<maxsize;
    DELETE FROM otl
           WHERE otl_from IN
                 (
                  SELECT id
                         FROM isolated
                         WHERE act>=0
                 );

    CALL oscchull( @alldeleted );

    # minimums flying with links
    CALL grpsplitga();

    # Now we don't know if there any SCC linked from others or orphaned only.
    # The call below repeats minimums float with the initial links set reversed
    # and puts the partitioning results to 'rga' and 'rgrp'.

    # minimums flying with reversed links
    CALL grpsplitrga();

    CALL filterscc( maxsize );

    # Modify group set upon links cleanup
    DELETE FROM ga
           WHERE id NOT IN 
                 (
                  SELECT otl_to 
                         FROM otl
                 );

    #
    # For an article belonging to an isolated cluster this table provides the
    # cluster size.
    #
    DROP TABLE IF EXISTS grp;
    CREATE TABLE grp (
      id int(8) unsigned NOT NULL default '0',
      cnt int(8) unsigned NOT NULL default '0'
    ) ENGINE=MEMORY AS
    SELECT count(*) as cnt,
           f as id
           FROM ga
           GROUP BY f;

    #
    # New categories added with temporal names in order to give them an id.
    #
    INSERT IGNORE INTO orcat (uid, cat, coolcat)
    SELECT @freecatid+cnt-1 as uid,
           convertcoolcat( CONCAT( upcat, '_', cnt ) ) as cat,
           CONCAT( upcat, '_', cnt ) as coolcat
           FROM grp
           GROUP BY cnt;
    # allows unique identifiers for non-existent categories
    SELECT max(uid)+1 INTO @freecatid
           FROM orcat;

    INSERT INTO isolated (id, cat, act)
    SELECT ga.id as id,
           catuid(CONCAT(upcat,'_',grp.cnt)) as cat,
           smart_action(grp.cnt, @articles_count) as act
           FROM ga,
                grp
           WHERE grp.id=ga.f and
                 grp.cnt<=maxsize
    # this disables any action for articles already registered properly
    ON DUPLICATE KEY UPDATE act=0;
  END;
//

#
# Look for isolated components of size less or equal to maxsize.
#
DROP PROCEDURE IF EXISTS isolated_layer//
CREATE PROCEDURE isolated_layer (maxsize INT, upcat VARCHAR(255), targetset VARCHAR(255))
  BEGIN
    IF maxsize>=1
      THEN
        # parenting links count for each parented article
        DELETE FROM lc;
        INSERT INTO lc /* SLOW_OK */ (lc_pid, lc_amnt)
        SELECT l_to as lc_pid,
               count( * ) as lc_amnt
               FROM l
               GROUP BY l_to;
        
        CALL _1( CONCAT(upcat, '_1'), targetset );

        IF maxsize>=2
          THEN CALL oscc( maxsize, upcat, targetset );
        END IF;

        # used only for ..._1 clusters detection,
        # provides the ability to use INSERT ... ON DUPLICATE KEY UPDATE ...
        # there
        # select from isolated maybe is too wide
        DELETE FROM parented
               WHERE pid IN
                     (
                      SELECT id
                             FROM isolated
                             WHERE act>=0
                     );
    END IF;
  END;
//

#
# Identifies isolated clusters and sub-chains for a given chain node.
#
# Note: This procedure may need to be rewritten with a statement prepare
#       to avoid running trough all numbers from 1 upto maxsize.
#
DROP PROCEDURE IF EXISTS forest_walk//
CREATE PROCEDURE forest_walk (targetset VARCHAR(255), maxsize INT, cluster_type VARCHAR(255), outprefix VARCHAR(255))
  BEGIN
    DECLARE tmp VARCHAR(255);
    DECLARE rank INT;
    DECLARE cnt INT;
    DECLARE curcatuid INT;
    DECLARE actmaxsize INT DEFAULT '1';
    DECLARE st VARCHAR(255);
    DECLARE comment_left VARCHAR(8) DEFAULT '';
    DECLARE comment_right VARCHAR(8) DEFAULT '';
    DECLARE pos INT DEFAULT '0';

    CALL isolated_layer(maxsize, cluster_type, targetset);

    IF maxsize>=2
      THEN
        SELECT count(*) INTO cnt
               FROM grp;
        IF cnt>0
          THEN
            SELECT MAX(grp.cnt) INTO actmaxsize
                 FROM grp;
            IF actmaxsize>maxsize
              THEN
                SET actmaxsize=maxsize;
            END IF;
        END IF;
    END IF;

    # all found SCC may parent others exclusively
    # search again excluding increasing SCC ranks starting from orphanes
    SET rank=1;
    WHILE rank<=actmaxsize DO
      SET tmp=CONCAT(cluster_type, '_', rank );
      SET curcatuid=catuid(tmp);

      # if any SCC of type tmp found
      SELECT count( * ) INTO cnt
             FROM isolated 
             WHERE cat=curcatuid and
                   act>=0;
      IF cnt>0
        THEN
          # report on progress
          SELECT CONCAT( ':: echo ', tmp, ': ', cnt ) as title;

          SELECT LOCATE( CONCAT( '_', @principle_component_size ), tmp ) INTO pos;
          IF pos>0
            THEN
              SET comment_left='<!-- ';
              SET comment_right=' -->';
            ELSE
              SET comment_left='';
              SET comment_right='';
          END IF;

          SELECT CONCAT( ':: out ', @fprefix, targetset, '.stat' );
          SELECT CONCAT( comment_left, outprefix, '[[:', getnsprefix(14,@target_lang), cat, '|', tmp, ']]: ', cnt, comment_right )
                 FROM orcat
                 WHERE coolcat=tmp;
          SELECT ':: sync';

          #
          # If the orphaned category is changed for some of articles,
          # there will be two rows in the table representing each of them,
          # one for the old category removal and the other one for a new
          # category.
          # Let's save our edits combining remove and put operations.
          #
          # Who is duped (got its category changed)?
          #
          # Note: Once the principle component is found, it and its 
          #       "children" categories mark up parented articles as isolates.
          #
          #       Let's keep duplicated items for such articles in the list;
          #       later the duplication will be removed, and this way
          #       all parented articles previously registered as isolates
          #       could still become unmarked.
          #
          DROP TABLE IF EXISTS ttt;
          CREATE TABLE ttt(
            id int(8) unsigned NOT NULL default '0'
          ) ENGINE=MEMORY AS
          SELECT id
                 FROM isolated
                 GROUP BY id 
                 HAVING count(*)>1;
          DELETE ttt
                 FROM ttt,
                      isolated
                 WHERE ttt.id=isolated.id AND
                       cat IN (
                               SELECT uid
                                      FROM orcat
                                      WHERE coolcat LIKE CONCAT( '%_', @principle_component_size, '%' )
                              );

          #
          # Remove operation is not required.
          #
          DELETE isolated
                 FROM isolated,
                      ttt
                 WHERE isolated.id=ttt.id and
                       isolated.act=-1;
          DROP TABLE ttt;

          IF targetset='articles'
            THEN
              SELECT count( * ) INTO cnt
                     FROM isolated 
                     WHERE cat=curcatuid and
                           act=1;
              IF cnt>0
                THEN
                  SELECT CONCAT( ':: out ', @fprefix, tmp, '.txt' );
                  SET @st=CONCAT( 'SELECT page_title FROM isolated, ', @dbname, '.page WHERE cat=', curcatuid, ' AND act=1 AND id=page_id ORDER BY page_title ASC;' );
                  PREPARE stmt FROM @st;
                  EXECUTE stmt;
                  DEALLOCATE PREPARE stmt;
                  SELECT ':: sync';
              END IF;
          END IF;

          # prepare dip into the scc forest
          DELETE FROM l
                 WHERE l_from IN
                       (
                        SELECT id
                               FROM isolated
                               WHERE cat=curcatuid and
                                     act>=0
                       );

          # recursive call
          CALL forest_walk( targetset, maxsize, tmp, CONCAT('*', outprefix) );
      END IF;
      SET rank=rank+1;
    END WHILE;
  END;
//

#
# Converts human-readable (?) orcat names to really usefull and clear.
#
DROP FUNCTION IF EXISTS convertcat//
CREATE FUNCTION convertcat ( wcat VARCHAR(255) )
  RETURNS VARCHAR(255)
  DETERMINISTIC
  BEGIN
    DECLARE position INT;
    DECLARE argue INT;
    DECLARE outcat VARCHAR(255) DEFAULT '';
    CASE wcat
      WHEN @old_orphan_category
        THEN
          # the proper return for simple
          RETURN '_1';
      ELSE
        SET position=LOCATE( CONCAT( @isolated_category_name, '/' ), wcat );
        IF position=1
        THEN
          # truncate the beginning of wcat
          SET wcat=SUBSTRING( wcat FROM 2+LENGTH( @isolated_category_name ) );
          REPEAT
            SET position=LOCATE( @orphan_param_name, wcat );
            IF position=1
            THEN
              SET wcat=SUBSTRING( wcat FROM 1+LENGTH( @orphan_param_name ) );
              SET argue=1+CAST(wcat AS DECIMAL);
              SET outcat=CONCAT(outcat, REPEAT('_1', argue));
              SET wcat=SUBSTRING( wcat FROM 1+LENGTH( argue-1 ) );
            ELSE
              SET position=LOCATE( CONCAT( @isolated_ring_param_name, '2' ), wcat );
              IF position=1
              THEN
                SET outcat=CONCAT(outcat,'_2');
                SET wcat=SUBSTRING( wcat FROM 2+LENGTH( @isolated_ring_param_name ) );
              ELSE
                SET position=LOCATE( @isolated_cluster_param_name, wcat );
                IF position=1
                  THEN
                    SET wcat=SUBSTRING( wcat FROM 1+LENGTH( @isolated_cluster_param_name ) );
                    SET argue=CAST(wcat AS DECIMAL);
                    IF argue<1
                    THEN
                      RETURN '_wrong_cluster_size_';
                    END IF;
                    SET outcat=CONCAT(outcat, '_', argue);
                    SET wcat=SUBSTRING( wcat FROM 1+LENGTH( argue ) );
                  ELSE
                    RETURN '_wrong_specifier_';
                END IF;
              END IF;
            END IF;
          UNTIL wcat=''
          END REPEAT;
          # the proper return for complex
          RETURN outcat;
        ELSE
          RETURN '_wrong_categoryname_';
        END IF;
    END CASE;
  END;
//

#
# Obtain all the scc's and chans for scc's of size less or equal to maxsize.
#
# Returns table named as isolated. 
#
# Uses for that tables l, nrcat, orcat, articles (... ?)
#
DROP PROCEDURE IF EXISTS isolated//
CREATE PROCEDURE isolated (namespace INT, targetset VARCHAR(255), maxsize INT)
  BEGIN
    DECLARE st VARCHAR(511);
    DECLARE rank INT;
    DECLARE cnt INT;
    DECLARE res VARCHAR(255);
    DECLARE isocl INT;
    DECLARE isocsl VARCHAR(255);

    SET @starttime=now();

    IF targetset='articles'
      THEN
        #
        # For isolated articles analysis some articles like timelines
        # do not form relevant linking. All irrelevant links are excluded 
        # from valid links here.
        #
        # One more thing is the {{templated articles}} 
        # (if templated in articles) are obviously always parented,
        # their content is visible even without any hyperlink jumps.
        #
        CALL apply_linking_rules( namespace );
    END IF;

    IF targetset!='redirects'
      THEN
        # redirector has carried out its purpose
        CALL redirector_unload( namespace );
    END IF;

    SELECT CONCAT( ':: echo isolated ', targetset,' processing:') as title;

    # CREATING SOME TABLES FOR OUT AND FOR TEMPEMPORARY

    # temporary table
    DROP TABLE IF EXISTS parented;

    CASE targetset
      WHEN 'redirects' THEN
        SET @st=CONCAT( "CREATE TABLE parented( pid int(8) unsigned NOT NULL default '0', PRIMARY KEY (pid) ) ENGINE=", @r_identifiers_engine, ";" );
        PREPARE stmt FROM @st;
        EXECUTE stmt;
        DEALLOCATE PREPARE stmt;

        SET @st=CONCAT( 'INSERT INTO parented (pid) SELECT r_id as pid FROM r', namespace, ';' );
        PREPARE stmt FROM @st;
        EXECUTE stmt;
        DEALLOCATE PREPARE stmt;
      WHEN 'articles' THEN
        SET @st=CONCAT( "CREATE TABLE parented( pid int(8) unsigned NOT NULL default '0', PRIMARY KEY (pid) ) ENGINE=", @articles_eng, ";" );
        PREPARE stmt FROM @st;
        EXECUTE stmt;
        DEALLOCATE PREPARE stmt;

        INSERT INTO parented (pid)
        SELECT id as pid
               FROM articles
               # not sure if sorting does help
               ORDER by id ASC;
      ELSE
        CREATE TABLE parented(
          pid int(8) unsigned NOT NULL default '0',
          PRIMARY KEY (pid)
        ) ENGINE=MEMORY;

        INSERT INTO parented (pid)
        SELECT id as pid
               FROM articles
               # not sure if sorting does help
               ORDER by id ASC;
    END CASE;  

    SELECT count(*) INTO cnt
           FROM parented;

    SELECT cry_for_memory( 62*cnt ) INTO @res;
    IF @res!=''
      THEN
        SELECT CONCAT( ':: echo ', @res );
    END IF;

    #
    # Main out table for isolated articles processing.
    #
    DROP TABLE IF EXISTS isolated;
    IF SUBSTRING( @res FROM 1 FOR 8 )='... ... '
      THEN
        SELECT ':: echo ... MyISAM engine is chosen for isolates table';

        CREATE TABLE isolated (
          id int(8) unsigned NOT NULL default '0',
          cat int(8) unsigned NOT NULL default '0',
          act int(8) signed NOT NULL default '1',
          KEY (id),
          PRIMARY KEY ( id, cat ),
          KEY (cat)
        ) ENGINE=MyISAM;
      ELSE
        CREATE TABLE isolated (
          id int(8) unsigned NOT NULL default '0',
          cat int(8) unsigned NOT NULL default '0',
          act int(8) signed NOT NULL default '1',
          KEY (id),
          PRIMARY KEY ( id, cat ),
          KEY (cat)
        ) ENGINE=MEMORY;
    END IF;

    #
    # List of cluster types (category based) for isolated articles.
    #
    DROP TABLE IF EXISTS orcat;
    CREATE TABLE orcat (
      uid int(8) unsigned NOT NULL AUTO_INCREMENT,
      cat varchar(255) binary NOT NULL default '',
      coolcat varchar(255) binary NOT NULL default '',
      PRIMARY KEY (uid),
      KEY(cat),
      UNIQUE KEY(coolcat)
    ) ENGINE=MEMORY;

    #
    # Synchronization between {{templated}} state and current toolserver state.
    #
    # Note: Only for articles analysis, not for redirects or categories.
    #
    IF targetset='articles'
      THEN
        IF @isolated_category_name!=''
          THEN
            #
            # Existing categories categorized as isolated with their id,
            # name, and name chifer.
            #
            # INSERT INTO orcat (uid, cat, coolcat)
            # SELECT categories.id as uid,
            #        page_title as cat,
            #        convertcat( page_title ) as coolcat
            #        FROM <dbname>.categorylinks, 
            #             <dbname>.page,
            #             categories
            #        WHERE page_title=categories.title and
            #              cl_to=', "'", @isolated_category_name, "'", ' and 
            #              page_id=cl_from and
            #              page_namespace=14;
            #
            # Note: Table requires expansion by linked but not created
            #       isolated categories, all changes are to be sinchronized 
            #       with nrcatl on uid=nrcl_cat. This might also cause
            #       influence on categories table.
            #
            SET @st=CONCAT( 'INSERT INTO orcat (uid, cat, coolcat) SELECT categories.id as uid, page_title as cat, convertcat( page_title ) as coolcat FROM ', @dbname, '.categorylinks, ', @dbname, '.page, categories WHERE page_title=categories.title and cl_to=', "'", @isolated_category_name, "'", ' and page_id=cl_from and page_namespace=14;' );
            PREPARE stmt FROM @st; 
            EXECUTE stmt; 
            DEALLOCATE PREPARE stmt; 

            SELECT CONCAT( ':: echo . ', count(*), ' isolated chain types registered' )
                   FROM orcat;
     
            #
            # Isolated articles might be marked as belonging to non-existent
            # categories.
            #
            DROP TABLE IF EXISTS ref_orcat;
            CREATE TABLE ref_orcat (
              uid int(8) unsigned NOT NULL AUTO_INCREMENT,
              cat varchar(255) binary NOT NULL default '',
              PRIMARY KEY (uid),
              KEY(cat)
            ) ENGINE=MEMORY;
            
            SELECT 1+CHAR_LENGTH( @isolated_category_name ) INTO isocl;
            SELECT CONCAT( @isolated_category_name, '/' ) INTO isocsl;

            #
            # INSERT INTO ref_orcat (cat)
            # SELECT cl_to as cat
            #        FROM <dbname>.categorylinks,
            #             <dbname>.page
            #        WHERE LEFT( cl_to, isocl ) = isocsl and
            #              cl_to NOT IN (
            #                             SELECT cat
            #                                    FROM orcat
            #                           ) and
            #              cl_from=page_id and
            #              page_namespace=0
            #        GROUP BY cl_to;
            #
            SET @st=CONCAT( 'INSERT INTO ref_orcat (cat) SELECT cl_to as cat FROM ', @dbname, '.categorylinks, ', @dbname, '.page WHERE LEFT( cl_to, ', isocl, ' ) = ', "'", isocsl, "'", ' and cl_to NOT IN ( SELECT cat FROM orcat ) and cl_from=page_id and page_namespace=0 GROUP BY cl_to;' );
            PREPARE stmt FROM @st; 
            EXECUTE stmt; 
            DEALLOCATE PREPARE stmt; 
            
            SELECT count(*) INTO cnt
                   FROM ref_orcat;

            INSERT INTO orcat (uid, cat, coolcat)
            SELECT @freecatid+uid,
                   cat,
                   convertcat( cat )
                   FROM ref_orcat;

            SELECT CONCAT( ':: echo . ', cnt, ' additional referenced isolated chain types registered' );

            #
            # Initializing main output table with currently registered 
            # isolated articles belonging to existent categories.
            #
            INSERT INTO isolated (id, cat, act)
            SELECT nrcl_from as id,
                   uid as cat,
                   -1 as act
                   FROM nrcatl,
                        orcat
                   WHERE nrcl_cat=uid;

            #
            # Now adding registered isolated articles with category pages to
            # be created.
            #
            # INSERT INTO isolated (id, cat, act)
            # SELECT cl_from as id,
            #        @freecatid+uid as cat,
            #        -1 as act
            #        FROM <dbname>.categorylinks,
            #             <dbname>.page,
            #             ref_orcat
            #        WHERE cl_to=cat and
            #              cl_from=page_id and
            #              page_namespace=0;
            #
            SET @st=CONCAT( 'INSERT INTO isolated (id, cat, act) SELECT cl_from as id, ', @freecatid, '+uid as cat, -1 as act FROM ', @dbname, '.categorylinks, ', @dbname, '.page, ref_orcat WHERE cl_to=cat and cl_from=page_id and page_namespace=0;' );
            PREPARE stmt FROM @st; 
            EXECUTE stmt; 
            DEALLOCATE PREPARE stmt; 

            SELECT @freecatid+cnt INTO @freecatid;

            DROP TABLE ref_orcat;

            SELECT CONCAT( ':: echo . ', count(*), ' isolated articles templated' )
                   FROM isolated;
        END IF;
    END IF;

    # temporary table
    DROP TABLE IF EXISTS todelete;
    CREATE TABLE todelete (
      id int(8) unsigned NOT NULL default '0',
      PRIMARY KEY (id)
    ) ENGINE=MEMORY;

    # temporary table
    DROP TABLE IF EXISTS aset;
    CREATE TABLE aset (
      id int(8) unsigned NOT NULL default '0',
      PRIMARY KEY (id)
    ) ENGINE=MEMORY;

    # temporary table
    DROP TABLE IF EXISTS lc;
    SET @st=CONCAT( "CREATE TABLE lc( lc_pid int(8) unsigned NOT NULL default '0', lc_amnt int(8) unsigned NOT NULL default '0', PRIMARY KEY (lc_pid) ) ENGINE=", @articles_eng, ';' );
    PREPARE stmt FROM @st;
    EXECUTE stmt;
    DEALLOCATE PREPARE stmt;

    SET @principle_component_size=0;

    # choose right limit for recursion depth allowed
    CALL forest_walk( targetset, maxsize, '', '*' );

    #
    # Once the principle component is detected it doesn't allow functions
    # performed for proper isolates (like suggestions search) work fast enough.
    #
    DELETE FROM isolated
           WHERE cat IN (
                   SELECT uid
                          FROM orcat
                          WHERE coolcat LIKE CONCAT( '%\_', @principle_component_size, '%' )
                 );

    # from oscchull
    DROP TABLE IF EXISTS otllc;
    
    # from grpsplitga/rga
    DROP TABLE IF EXISTS rgrp;
    DROP TABLE IF EXISTS grp;
    DROP TABLE IF EXISTS mftmp;
    DROP TABLE IF EXISTS rga;
    DROP TABLE IF EXISTS ga;
    DROP TABLE IF EXISTS eotl;
    
    # from filterscc
    DROP TABLE IF EXISTS newparent_grps;

    # from oscc
    DROP TABLE IF EXISTS otl;

    DROP TABLE todelete;
    DROP TABLE aset;
    DROP TABLE lc;
    DROP TABLE parented;

    # ARTICLES TO BE REMOVED FROM THE CURRENT ISOLATED ARTICLES LIST

    # again the check here is to be made for articles, not all the ns0
    IF targetset='articles'
      THEN
        SELECT count( * ) INTO cnt
               FROM isolated 
               WHERE act=-1;

        IF cnt>0
          THEN
            SELECT CONCAT( ':: echo parented isolates: ', cnt ) as title;

            SELECT CONCAT( ':: out ', @fprefix, 'orem.txt' );
            SET @st=CONCAT( 'SELECT CONCAT(getnsprefix(page_namespace,"', @target_lang, '"), page_title) as title FROM isolated, ', @dbname, '.page WHERE act=-1 AND id=page_id ORDER BY page_title ASC;' );
            PREPARE stmt FROM @st; 
            EXECUTE stmt; 
            DEALLOCATE PREPARE stmt; 
            SELECT ':: sync';
        END IF;
    END IF;

    #
    # Overall isolated articles count.
    #
    SELECT count(*) INTO @isolated_articles_count
           FROM isolated
           WHERE act>=0;

    SELECT count(DISTINCT cat) INTO @isolated_articles_types_count
           FROM isolated
           WHERE act>=0;

    SELECT CONCAT( ':: echo ', @isolated_articles_count, ' isolated ', targetset, ' of ', @isolated_articles_types_count, ' various types found' );
    
    SELECT CONCAT( ':: out ', @fprefix, targetset, '.stat' );
    SELECT CONCAT( '{{total amount of isolated articles}}: ', @isolated_articles_count );
    SELECT ':: sync';

    # this table is pretty well worn here after isolated processing
    #
    # linker unload
    DROP TABLE l;

    #
    # Isolated categories to be created.
    #
    IF targetset='articles'
      THEN
        SELECT count( * ) INTO cnt
               FROM orcat
               WHERE cat NOT IN (
                                  SELECT title
                                         FROM categories
                                         WHERE SUBSTRING( title FROM 1 FOR LENGTH( @isolated_category_name ) )=@isolated_category_name
                                ) AND
                     LOCATE( CONCAT( '_', @principle_component_size ), coolcat )=0 AND
                     coolcat!='_wrong_categoryname_';

        IF cnt>0
          THEN
            SELECT CONCAT( ':: upload cc ', @fprefix, 'newisocat.txt' );
            SELECT CONCAT( getnsprefix( 14, @target_lang ), cat , '|', coolcat )
                   FROM orcat
                   WHERE cat NOT IN (
                                      SELECT title
                                             FROM categories
                                             WHERE SUBSTRING( title FROM 1 FOR LENGTH( @isolated_category_name ) )=@isolated_category_name
                                    ) AND
                         LOCATE( CONCAT( '_', @principle_component_size ), coolcat )=0 AND
                         coolcat!='_wrong_categoryname_'
                   ORDER BY coolcat ASC;
            SELECT ':: sync';
        END IF;
    END IF;

    SELECT CONCAT( ':: echo isolated ', targetset, ' processing time: ', TIMEDIFF(now(), @starttime));
  END;
//

#
# Forms output tables for use in other tools with names concatenated with
# a postfix given.
#
DROP PROCEDURE IF EXISTS isolated_refresh//
CREATE PROCEDURE isolated_refresh (postfix VARCHAR(255), namespace INT)
  BEGIN
    DECLARE st VARCHAR(255);

    #
    # List of categorytree paths.
    #
    DROP TABLE IF EXISTS orcat_ns;
    CREATE TABLE orcat_ns (
      uid int(8) unsigned NOT NULL AUTO_INCREMENT,
      coolcat varchar(255) binary NOT NULL default '',
      PRIMARY KEY (uid)
    ) ENGINE=MyISAM AS
    SELECT uid,
           coolcat
           FROM orcat;

    DROP TABLE IF EXISTS ruwiki_ns;
    CREATE TABLE ruwiki_ns (
      id int(8) unsigned NOT NULL default '0',
      PRIMARY KEY (id)
    ) ENGINE=MyISAM;

    IF postfix='r'
      THEN
        IF @r_identifiers_engine='MEMORY'
          THEN
            ALTER TABLE ruwiki_ns ENGINE=MEMORY;
        END IF;
        ALTER TABLE orcat_ns ENGINE=MEMORY;

        ALTER TABLE ruwiki_ns ADD COLUMN cat int(8) unsigned NOT NULL default '0';

        #
        # Redirects as they belong to redirect chains.
        #
        SET @st=CONCAT( 'INSERT INTO ruwiki_ns (id, cat) SELECT isolated.id as id, uid as cat FROM isolated, r', namespace, ', orcat_ns WHERE act>=0 and isolated.id=r_id and uid=isolated.cat;' );
        PREPARE stmt FROM @st;
        EXECUTE stmt;
        DEALLOCATE PREPARE stmt;
      ELSE
        ALTER TABLE ruwiki_ns ADD COLUMN cat varchar(255) binary NOT NULL default '';
        ALTER TABLE ruwiki_ns ADD COLUMN title varchar(255) binary NOT NULL default '';
        ALTER TABLE ruwiki_ns ADD KEY (cat);

        #
        # Isolated articles as they belong to different cluster chains.
        # Categories as they belong to categorytree paths.
        #
        # isolated refresh
        SET @st=CONCAT( 'INSERT INTO ruwiki_ns (id, cat, title) SELECT isolated.id, coolcat as cat, page_title as title FROM isolated, ', @dbname, '.page, orcat_ns WHERE act>=0 and id=page_id and uid=isolated.cat;' );
        PREPARE stmt FROM @st;
        EXECUTE stmt;
        DEALLOCATE PREPARE stmt;
    END IF;

    #
    # Bless orcat tables with postfixed name.
    #
    SET @st=CONCAT( 'DROP TABLE IF EXISTS orcat', postfix, ';' );
    PREPARE stmt FROM @st;
    EXECUTE stmt;
    DEALLOCATE PREPARE stmt;
    SET @st=CONCAT( 'RENAME TABLE orcat_ns TO orcat', postfix, ';' );
    PREPARE stmt FROM @st;
    EXECUTE stmt;
    DEALLOCATE PREPARE stmt;

    SET @st=CONCAT( 'DROP TABLE IF EXISTS ruwiki', postfix, ';' );
    PREPARE stmt FROM @st;
    EXECUTE stmt;
    DEALLOCATE PREPARE stmt;
    SET @st=CONCAT( 'RENAME TABLE ruwiki_ns TO ruwiki', postfix, ';' );
    PREPARE stmt FROM @st;
    EXECUTE stmt;
    DEALLOCATE PREPARE stmt;
  END;
//

delimiter ;
############################################################

-- </pre>
