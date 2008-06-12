 --
 -- Authors: [[:ru:user:Mashiah Davidson]], still alone
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
 -- Types of isolated claster chains: The connectivity analysis here relies on
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
 -- Expected outputs: Isolated claster chains of various types, what's to be
 --                   (un)taged in relation to disconnexion.
 --
 -- Tested with: Article links
 --              Categorytree links
 --              Redirects in various namespaces
 --
 -- <pre>

 --
 -- Significant speedup
 --

SET SESSION TRANSACTION ISOLATION LEVEL READ UNCOMMITTED;


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
    DROP TABLE chrono;

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
    INSERT IGNORE INTO l
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
      DELETE FROM todelete;
      INSERT INTO todelete
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

      DELETE FROM todelete;
      INSERT INTO todelete
             SELECT DISTINCT otl_to as id
                    FROM otl
                    WHERE otl_to NOT IN
                          (
                           SELECT otl_from
                                  FROM otl
                          );
      DELETE FROM otl
             WHERE otl_to IN
                   (
                    SELECT id
                           FROM todelete
                   );

      DELETE FROM todelete;
      INSERT INTO todelete
             SELECT DISTINCT otl_from as id
                    FROM otl
                    WHERE otl_from NOT IN
                          (
                           SELECT otl_to
                                  FROM otl
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
DROP PROCEDURE IF EXISTS filterscc//
CREATE PROCEDURE filterscc (IN rank INT)
  BEGIN
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
    INSERT INTO todelete
           SELECT id
                  FROM ga,
                       newparent_grps
                  WHERE f=gid;
    INSERT INTO todelete
           SELECT ga.id
                  FROM ga,
                       rga
                  WHERE ga.id=rga.id and
                        ga.f<rga.f;
    INSERT INTO todelete
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
    DELETE FROM otl
           WHERE otl_from IN
                 (
                  SELECT id
                         FROM todelete
                 );
  END;
//

#
# Look for cluster id for each article pretending to be isolated.
#
DROP PROCEDURE IF EXISTS grpsplitga//
CREATE PROCEDURE grpsplitga ()
  BEGIN
    DECLARE changescount INT;

    # copy otl as required using a given links order
    DROP TABLE IF EXISTS eotl;
    CREATE TABLE eotl(
      eotl_from int(8) unsigned NOT NULL default '0',
      eotl_to int(8) unsigned NOT NULL default '0',
      KEY (eotl_from),
      KEY (eotl_to)
    ) ENGINE=MEMORY AS
    SELECT otl_from as eotl_from,
           otl_to as eotl_to
           FROM otl;
    # add self-links to avoid loosing minimal id for articles having it
    INSERT INTO eotl
           SELECT DISTINCT otl_from as eotl_from,
                           otl_from as eotl_to
                  FROM otl;

    # initializing search with min of ids of parents as a claster id for each 
    # article
    DROP TABLE IF EXISTS ga;
    CREATE TABLE ga (
      f int(8) unsigned NOT NULL default '0',
      id int(8) unsigned NOT NULL default '0',
      PRIMARY KEY (id)
    ) ENGINE=MEMORY AS
    SELECT min(eotl_from) as f,
           eotl_to as id
           FROM eotl
           GROUP BY eotl_to;

    REPEAT

      # simple copy of ga, name changed to mftmp
      DROP TABLE IF EXISTS mftmp;
      CREATE TABLE mftmp (
        f int(8) unsigned NOT NULL default '0',
        id int(8) unsigned NOT NULL default '0',
        PRIMARY KEY (id)
      ) ENGINE=MEMORY AS
      SELECT f,
             id
             FROM ga;

      # look for parents for current minimal group id there
      DROP TABLE IF EXISTS ga;
      CREATE TABLE ga (
        f int(8) unsigned NOT NULL default '0',
        id int(8) unsigned NOT NULL default '0',
        PRIMARY KEY (id)
      ) ENGINE=MEMORY AS
      SELECT min(f) as f,
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
                   mftmp.f!=ga.f;

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

    # copy otl as required using a given links order
    DROP TABLE IF EXISTS eotl;
    CREATE TABLE eotl(
      eotl_from int(8) unsigned NOT NULL default '0',
      eotl_to int(8) unsigned NOT NULL default '0',
      KEY (eotl_from),
      KEY (eotl_to)
    ) ENGINE=MEMORY AS
    SELECT otl_to as eotl_from,
           otl_from as eotl_to
           FROM otl;
    # add self-links to avoid loosing minal id for articles having it
    INSERT INTO eotl
           SELECT DISTINCT otl_to as eotl_from,
                           otl_to as eotl_to
                  FROM otl;

    # initializing search with min of ids of parents as a claster id for each 
    # article
    DROP TABLE IF EXISTS rga;
    CREATE TABLE rga (
      f int(8) unsigned NOT NULL default '0',
      id int(8) unsigned NOT NULL default '0',
      PRIMARY KEY (id)
    ) ENGINE=MEMORY AS
    SELECT min(eotl_from) as f,
           eotl_to as id
           FROM eotl
           GROUP BY eotl_to;

    REPEAT

      # simple copy of rga, name changed to mftmp
      DROP TABLE IF EXISTS mftmp;
      CREATE TABLE mftmp (
        f int(8) unsigned NOT NULL default '0',
        id int(8) unsigned NOT NULL default '0',
        PRIMARY KEY (id)
      ) ENGINE=MEMORY AS
      SELECT f,
             id
             FROM rga;

      # look for parents for current minimal group id there
      DROP TABLE IF EXISTS rga;
      CREATE TABLE rga (
        f int(8) unsigned NOT NULL default '0',
        id int(8) unsigned NOT NULL default '0',
        PRIMARY KEY (id)
      ) ENGINE=MEMORY AS
      SELECT min(f) as f,
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
                   mftmp.f!=rga.f;

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
# Identifies isolated singlets (orphanes).
#
DROP PROCEDURE IF EXISTS _1//
CREATE PROCEDURE _1 (category VARCHAR(255))
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
            INSERT INTO orcat
            SELECT @freecatid as uid,
                   CONCAT( 'Википедия:Изолированные_статьи/', category ) as cat,
                   category as coolcat;
            SET @freecatid=@freecatid+1;
        END IF;

        INSERT INTO isolated
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

#
# Orphaned strongly connected components (oscc) with 1 < size <= maxsize.
#
DROP PROCEDURE IF EXISTS oscc//
CREATE PROCEDURE oscc (maxsize INT, upcat VARCHAR(255))
  BEGIN
    # all links to pages having no more than maxsize-1 parenting links
    DROP TABLE IF EXISTS otl;
    CREATE TABLE otl(
      otl_to int(8) unsigned NOT NULL default '0',
      otl_from int(8) unsigned NOT NULL default '0',
      KEY (otl_from),
      KEY (otl_to)
    ) ENGINE=MEMORY AS
    SELECT DISTINCT lc_pid as otl_to,
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

    CALL oscchull( @alldeleted );

    # Modify group set upon links cleanup
    DELETE FROM ga
           WHERE id NOT IN 
                 (
                  SELECT otl_to 
                         FROM otl
                 );

    #
    # For an article belonging to isolated cluster this table provides the
    # claster size.
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
    INSERT IGNORE INTO orcat
    SELECT @freecatid as uid,
           CONCAT( 'Википедия:Изолированные_статьи/', upcat, '_', cnt ) as cat,
           CONCAT(upcat,'_',cnt) as coolcat
           FROM grp
           GROUP BY cnt;
    SET @freecatid=@freecatid+1;

    INSERT INTO isolated
    SELECT ga.id as id,
           catuid(CONCAT(upcat,'_',grp.cnt)) as cat,
           1 as act
           FROM ga,
                grp
           WHERE grp.id=ga.f
    # this disables any action for articles already registered properly
    ON DUPLICATE KEY UPDATE act=0;
  END;
//

#
# Look for isolated components of size less or equal to maxsize.
#
DROP PROCEDURE IF EXISTS isolated_layer//
CREATE PROCEDURE isolated_layer (maxsize INT, upcat VARCHAR(255))
  BEGIN
    IF maxsize>=1
      THEN
        # parenting links count for each parented article
        DELETE FROM lc;
        INSERT INTO lc
        SELECT l_to as lc_pid,
               count( * ) as lc_amnt
               FROM l
               GROUP BY l_to;
        
        CALL _1( CONCAT(upcat, '_1') );

        IF maxsize>=2
          THEN CALL oscc( maxsize, upcat );
        END IF;

        # used only for ..._1 clasters detection,
        # provides the ability to use INSERT ... ON DUPLICATE KEY UPDATE ... there
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
CREATE PROCEDURE forest_walk (targetset VARCHAR(255), maxsize INT, claster_type VARCHAR(255), outprefix VARCHAR(255))
  BEGIN
    DECLARE tmp VARCHAR(255);
    DECLARE rank INT;
    DECLARE cnt INT;
    DECLARE curcatuid INT;
    DECLARE whatsinfo INT;
    DECLARE actmaxsize INT DEFAULT '1';

    CALL isolated_layer(maxsize, claster_type);

    IF maxsize>=2
      THEN
        SELECT count(*) INTO cnt
               FROM grp;
        IF cnt>0
          THEN
            SELECT MAX(grp.cnt) INTO actmaxsize
                 FROM grp;
        END IF;
    END IF;

    # all found SCC may parent others exclusively
    # search again excluding increasing SCC ranks starting from orphanes
    SET rank=1;
    WHILE rank<=actmaxsize DO
      SET tmp=CONCAT(claster_type, '_', rank );
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

          SELECT CONCAT( ':: out ', @fprefix, targetset, '.stat' );
          SELECT CONCAT( outprefix, '[[:Категория:', cat, '|', tmp, ']]: ', cnt )
                 FROM orcat
                 WHERE coolcat=tmp;

          IF @enable_informative_output>0
          THEN
            SELECT CONCAT( ':: out ', @fprefix, tmp, '.info' );
            SELECT id,
                   title
                   FROM isolated,
                        articles
                   WHERE cat=curcatuid and
                         isolated.id=articles.id and
                         act>=0
                   ORDER BY title ASC; 
          END IF;

          # If the orphaned category is changed for some of articles,
          # there will be two rows in the table representing each of them,
          # one for old category removal and other is a new category.
          # Let's save our edits combining remove and put operations.
          #
          # who is duped (changed category)
          DROP TABLE IF EXISTS ttt;
          CREATE TABLE ttt(
            id int(8) unsigned NOT NULL default '0'
          ) ENGINE=MEMORY AS
          SELECT id
                 FROM isolated
                 GROUP BY id 
                 HAVING count(*)>1;
          # remove operation is not required, remove during replace
          DELETE isolated
                 FROM isolated,
                      ttt
                 WHERE isolated.id=ttt.id and
                       isolated.act=-1;
          DROP TABLE ttt;

          # for redirects we do as it is for categories,
          # just if especially set in @enable_informative_output
          IF targetset='articles'
            THEN
              SET whatsinfo=1;
            ELSE
              IF @enable_informative_output>0
                THEN
                  SET whatsinfo=1;
                ELSE
                  SET whatsinfo=0;
              END IF;
          END IF;
          IF whatsinfo=1
            THEN
              SELECT count( * ) INTO cnt
                     FROM isolated 
                     WHERE cat=curcatuid and
                           act=1;
              IF cnt>0
                THEN
                  SELECT CONCAT( ':: out ', @fprefix, tmp, '.txt' );
                  SELECT title
                         FROM isolated,
                              articles
                         WHERE cat=curcatuid AND
                               act=1 AND
                               isolated.id=articles.id
                         ORDER BY title ASC;
              END IF;
          END IF;

          # prepare deep into the scc forest
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
      WHEN 'Википедия:Страницы-сироты'
        THEN
          # the proper return for simple
          RETURN '_1';
      ELSE
        SET position=LOCATE('Википедия:Изолированные_статьи/',wcat);
        IF position=1
        THEN
          # truncate the beginning of wcat
          SET wcat=SUBSTRING( wcat FROM 1+LENGTH( 'Википедия:Изолированные_статьи/' ) );
          REPEAT
            SET position=LOCATE('сирота',wcat);
            IF position=1
            THEN
              SET wcat=SUBSTRING( wcat FROM 1+LENGTH( 'сирота' ) );
              SET argue=1+CAST(wcat AS DECIMAL);
              SET outcat=CONCAT(outcat, REPEAT('_1', argue));
              SET wcat=SUBSTRING( wcat FROM 1+LENGTH( argue-1 ) );
            ELSE
              SET position=LOCATE('кольцо2',wcat);
              IF position=1
              THEN
                SET outcat=CONCAT(outcat,'_2');
                SET wcat=SUBSTRING( wcat FROM 1+LENGTH( 'кольцо2' ) );
              ELSE
                SET position=LOCATE('кластер',wcat);
                IF position=1
                  THEN
                    SET wcat=SUBSTRING( wcat FROM 1+LENGTH( 'кластер' ) );
                    SET argue=CAST(wcat AS DECIMAL);
                    IF argue<1
                    THEN
                      RETURN '_wrong_claster_size_';
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
    DECLARE tmp VARCHAR(255);
    DECLARE rank INT;
    DECLARE cnt INT;
    DECLARE overall INT;

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
        CALL redirector_unload();
    END IF;

    SELECT CONCAT( ':: echo isolated ', targetset,' processing:') as title;

    # CREATING SOME TABLES FOR OUT AND FOR TEMPEMPORARY

    #
    # Main out table for isolated articles processing.
    #
    DROP TABLE IF EXISTS isolated;
    CREATE TABLE isolated (
      id int(8) unsigned NOT NULL default '0',
      cat int(8) unsigned NOT NULL default '0',
      act int(8) signed NOT NULL default '1',
      KEY (id),
      PRIMARY KEY ( id, cat ),
      KEY (cat)
    ) ENGINE=MEMORY;

    #
    # List of claster types (category based) for isolated articles.
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
        INSERT INTO orcat
        SELECT categories.id as uid,
               page_title as cat,
               convertcat( page_title ) as coolcat
               FROM ruwiki_p.categorylinks,
                    ruwiki_p.page,
                    categories
                    WHERE page_title=categories.title and
                          cl_to='Википедия:Изолированные_статьи' and
                          page_id=cl_from and
                                         # this should be constant because
                                         # isolates are registered with
                                         # categories mechanism
                          page_namespace=14;

        SELECT CONCAT( ':: echo . ', count(*), ' isolated categories templated' )
               FROM orcat;
     
        #
        # Initializing main output table with currently registered 
        # isolated articles and their categories.
        #
        INSERT INTO isolated
        SELECT nrcl_from as id,
               uid as cat,
               -1 as act
               FROM nrcatl,
                    orcat
               WHERE nrcl_cat=uid;

        SELECT CONCAT( ':: echo . ', count(*), ' isolated articles templated' )
               FROM isolated;
    END IF;

    # temporary table
    DROP TABLE IF EXISTS todelete;
    CREATE TABLE todelete (
      id int(8) unsigned NOT NULL default '0',
      PRIMARY KEY (id)
    ) ENGINE=MEMORY;

    # temporary table
    DROP TABLE IF EXISTS lc;
    CREATE TABLE lc(
      lc_pid int(8) unsigned NOT NULL default '0',
      lc_amnt int(8) unsigned NOT NULL default '0',
      PRIMARY KEY (lc_pid)
    ) ENGINE=MEMORY;

    # temporary table
    DROP TABLE IF EXISTS parented;
    CREATE TABLE parented(
      pid int(8) unsigned NOT NULL default '0',
      PRIMARY KEY (pid)
    ) ENGINE=MEMORY;
    IF targetset!='redirects'
      THEN
        INSERT INTO parented
        SELECT id as pid
               FROM articles
               ORDER by id ASC;
      ELSE
        SET @st=CONCAT( 'INSERT INTO parented SELECT r_id as pid FROM r', namespace, ' ORDER by r_id ASC;' );
        PREPARE stmt FROM @st;
        EXECUTE stmt;
        DEALLOCATE PREPARE stmt;
    END IF;

    # choose right limit for recursion depth allowed
    CALL forest_walk( targetset, maxsize, '', '*' );

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
            SELECT CONCAT(':: echo parented isolates: ', cnt ) as title;
            SELECT CONCAT( ':: out ', @fprefix, 'orem.txt' );
            SELECT CONCAT(getnsprefix(page_namespace), page_title) as title
                   FROM isolated,
                        ruwiki_p.page
                   WHERE act=-1 AND
                         id=page_id
                   ORDER BY page_title ASC;
        END IF;
    END IF;

    #
    # Overall isolated articles count.
    #
    SELECT count(*) INTO overall
           FROM isolated
           WHERE act>=0;

    SELECT CONCAT( ':: echo ', overall, ' isolated ', targetset, ' found' );
    
    SELECT CONCAT( ':: out ', @fprefix, targetset, '.stat' );
    SELECT CONCAT( 'Общее количество изолированных статей: ', overall );

    # this table is pretty well worn here after isolated processing
    #
    # linker unload
    DROP TABLE l;

    SELECT CONCAT( ':: echo isolated ', targetset, ' processing time: ', timediff(now(), @starttime));
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
    ) ENGINE=MEMORY AS
    SELECT uid,
           coolcat
           FROM orcat;

    DROP TABLE IF EXISTS ruwiki_ns;
    CREATE TABLE ruwiki_ns (
      id int(8) unsigned NOT NULL default '0',
      cat varchar(255) binary NOT NULL default '',
      title varchar(255) binary NOT NULL default '',
      PRIMARY KEY (id),
      KEY (cat)
    ) ENGINE=MEMORY;

    IF postfix='r'
      THEN
        #
        # Redirects as they belong to redirect chains.
        #
        SET @st=CONCAT( 'INSERT INTO ruwiki_ns SELECT isolated.id, coolcat as cat, r_title FROM isolated, r', namespace, ', orcat_ns WHERE act>=0 and isolated.id=r_id and uid=isolated.cat;' );
        PREPARE stmt FROM @st;
        EXECUTE stmt;
        DEALLOCATE PREPARE stmt;
      ELSE
        #
        # Isolated articles as they belong to different claster chains.
        # Categories as they belong to categorytree paths.
        #
        # isolated refresh
        INSERT INTO ruwiki_ns
        SELECT isolated.id,
               coolcat as cat,
               title
               FROM isolated,
                    articles,
                    orcat_ns
               WHERE act>=0 and
                     isolated.id=articles.id and
                     uid=isolated.cat;
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
