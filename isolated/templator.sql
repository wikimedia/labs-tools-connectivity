 --
 -- Authors: [[:ru:user:Mashiah Davidson]]
 --
 -- Caution: PROCEDUREs defined here may have output designed for handle.sh.
 -- 
 -- Shared procedures: a2a_templating
 --
 -- <pre>

############################################################
delimiter //

DROP PROCEDURE IF EXISTS a2a_templating//
CREATE PROCEDURE a2a_templating ()
  BEGIN
    DECLARE st VARCHAR(511);

    #
    # Creation of the output table.
    #
    # Note: Due to use of nr2X2nr, we have to reuse pl name for this table.
    #
    DROP TABLE IF EXISTS pl;
    CREATE TABLE pl (
      pl_from int(8) unsigned NOT NULL default '0',
      pl_to int(8) unsigned NOT NULL default '0'
    ) ENGINE=MEMORY;

    #
    # Articles transcluded directly in other articles.
    #
    # Note: Fast when transclusion is completely unusual for article titles.
    #       The more are transcluded the slower this query is.
    #
    # INSERT IGNORE INTO pl (pl_from, pl_to)
    # SELECT tl_from as pl_from,
    #        id as pl_to
    #        FROM <dbname>.templatelinks,
    #             <dbname>.page,
    #             articles
    #        WHERE tl_namespace=0 and
    #              tl_from IN (
    #                           SELECT id
    #                                  FROM articles
    #                         ) and
    #              page_namespace=0 and
    #              page_title=tl_title and
    #              page_id=id;
    #
    SET @st=CONCAT( 'INSERT IGNORE INTO pl (pl_from, pl_to) SELECT tl_from as pl_from, id as pl_to FROM ', @dbname, '.templatelinks, ', @dbname, '.page, articles WHERE tl_namespace=0 and tl_from IN ( SELECT id FROM articles ) and page_namespace=0 and page_title=tl_title and page_id=id;' );
    PREPARE stmt FROM @st;
    EXECUTE stmt;
    DEALLOCATE PREPARE stmt;

    SELECT CONCAT( ':: echo ', count(*), ' templating links from article to article' )
           FROM pl;

    #
    # This table contains info on templating of zero namespace redirects
    # in articles.
    #
    # Note: Table name selection is dictated by nr2X2nr called below.
    #
    DROP TABLE IF EXISTS nr2r;
    CREATE TABLE nr2r (
      nr2r_to int(8) unsigned NOT NULL default '0',
      nr2r_from int(8) unsigned NOT NULL default '0',
      KEY (nr2r_to)
    ) ENGINE=MEMORY;

    #
    # INSERT INTO nr2r (nr2r_to, nr2r_from)
    # SELECT r_id as nr2r_to,
    #        tl_from as nr2r_from
    #        FROM <dbname>.templatelinks,
    #             <dbname>.page,
    #             r0
    #        WHERE tl_namespace=0 and
    #              tl_from in (
    #                           SELECT id
    #                                  FROM articles
    #                         ) and
    #              page_namespace=0 and
    #              page_title=tl_title and
    #              page_id=r_id;
    #
    SET @st=CONCAT( 'INSERT INTO nr2r (nr2r_to, nr2r_from) SELECT r_id as nr2r_to, tl_from as nr2r_from FROM ', @dbname, '.templatelinks, ', @dbname, '.page, r0 WHERE tl_namespace=0 and tl_from in ( SELECT id FROM articles ) and page_namespace=0 and page_title=tl_title and page_id=r_id;' );
    PREPARE stmt FROM @st;
    EXECUTE stmt;
    DEALLOCATE PREPARE stmt;

    SELECT CONCAT( ':: echo ', count(*), ' templating links from articles to redirects' )
           FROM nr2r;

    DROP TABLE IF EXISTS plr;
    CREATE TABLE plr (
      pl_from int(8) unsigned NOT NULL default '0',
      pl_to int(8) unsigned NOT NULL default '0'
    ) ENGINE=MyISAM;

    CALL nr2X2nr('0');
    DROP TABLE nr2r;

    INSERT INTO pl (pl_from, pl_to)
    SELECT pl_from,
           pl_to
           FROM plr;

    DROP TABLE plr;

    SELECT count(*) INTO @pl_count
           FROM pl;

    SELECT CONCAT( ':: echo ', @pl_count, ' overall (direct & redirected) articles templating links count' );
  END;
//

#
# Filters table t2p removing links occuring from template docuemntation.
#
DROP PROCEDURE IF EXISTS template_documentation_link_cleanup//
CREATE PROCEDURE template_documentation_link_cleanup ()
  BEGIN
    #
    # Correspondence between template pages and their documentation pages.
    #
    DROP TABLE IF EXISTS doct;
    CREATE TABLE doct (
      doc int(8) unsigned NOT NULL default '0',
      t int(8) unsigned NOT NULL default '0' 
    ) ENGINE=MEMORY AS
    SELECT docsrc.id AS doc,
           docdst.id AS t
           FROM regular_templates as docsrc,
                regular_templates as docdst
           WHERE docsrc.title LIKE CONCAT( '%/', @template_documentation_subpage_name ) AND
                 docdst.title=substr(docsrc.title FROM 1 FOR length(docsrc.title)-1-length(@template_documentation_subpage_name));

    SELECT CONCAT( ':: echo ', count(*), ' templates with documentation page found' )
           FROM doct;

    #
    # Documentation pages sometimes are redirects to other documents.
    #
    INSERT INTO doct (doc, t)
    SELECT r2nr_to AS doc,
           id AS t
           FROM r10,
                regular_templates,
                r2nr10
           WHERE r_title LIKE CONCAT( '%/', @template_documentation_subpage_name) AND
                 title=substr(r_title FROM 1 FOR length(r_title)-1-length(@template_documentation_subpage_name)) AND
                 r_id=r2nr_from;

    SELECT CONCAT( ':: echo ', count(*), ' templates with documentation found' )
           FROM doct;

    DROP TABLE r10;

    #
    # Links present on template pages due to the documentation included.
    #
    DROP TABLE IF EXISTS r_t2p;
    CREATE TABLE r_t2p (
      r_t2p_from int(8) unsigned NOT NULL default '0',
      r_t2p_to int(8) unsigned NOT NULL default '0' 
    ) ENGINE=MEMORY AS
    SELECT DISTINCT templ.t2p_from as r_t2p_from,
                    docum.t2p_to as r_t2p_to
           FROM t2p as docum,
                t2p as templ,
                doct
           WHERE docum.t2p_from=doc AND
                 templ.t2p_from=t;

    DROP TABLE doct;

    #
    # Links from the documentation page are being removed here from
    # templates as not occuring in articles with templating.
    #
    DELETE t2p
           FROM t2p,
                r_t2p
           WHERE t2p_from=r_t2p_from AND
                 t2p_to=r_t2p_to;

    SELECT CONCAT( ':: echo ', count(*), ' links from templates to main namespace pages after documentation links removal' )
           FROM t2p;

    DROP TABLE r_t2p;
  END;
//

#
# Collection of links occuring in articles due to templates used.
#
# Notes: This function does not work properly and thus is not used currently.
#
#        Variable @massive_lists_recognition_alive is associated with this code.
#        As far as it is not initialized, the function is never called and
#        no data is being prepared especially for it.
#
DROP PROCEDURE IF EXISTS recognizable_template_links//
CREATE PROCEDURE recognizable_template_links ()
  BEGIN
    DECLARE st VARCHAR(511);

    SET @starttime1=now();

    DROP TABLE IF EXISTS tcp;
    SET @st=CONCAT( 'CREATE TABLE tcp ( uid int(8) unsigned NOT NULL AUTO_INCREMENT, tcp_name varchar (255) binary NOT NULL default ', "''", ', PRIMARY KEY (uid), UNIQUE KEY (tcp_name) ) ENGINE=MEMORY AS SELECT DISTINCT pl_title as tcp_name FROM ', @dbname, '.pagelinks WHERE pl_namespace=0;' );
    PREPARE stmt FROM @st;
    EXECUTE stmt;
    DEALLOCATE PREPARE stmt;

    SELECT CONCAT( ':: echo ', count(*), ' distinct main namespace names used in links' )
           FROM tcp;

    SELECT CONCAT( ':: echo tcp processing time: ', TIMEDIFF(now(), @starttime1));

    SET @starttime1=now();

    DROP TABLE IF EXISTS t20;
    SET @st=CONCAT( 'CREATE TABLE t20 ( t20_from int(8) unsigned NOT NULL default ', "'0'", ', t20_to int(8) unsigned NOT NULL default ', "'0'", ', KEY (t20_from), KEY (t20_to) ) ENGINE=MEMORY AS /* SLOW_OK */ SELECT STRAIGHT_JOIN pl_from as t20_from, uid as t20_to FROM ', @dbname, '.pagelinks, tcp WHERE pl_namespace=0 and pl_from IN ( SELECT id FROM regular_templates ) and pl_title=tcp_name;' );
    PREPARE stmt FROM @st;
    EXECUTE stmt;
    DEALLOCATE PREPARE stmt;

    SELECT CONCAT( ':: echo ', count(*), ' links from templating pages to main namespace' )
           FROM t20;

    SELECT CONCAT( ':: echo t20 processing time: ', TIMEDIFF(now(), @starttime1));

    SET @starttime1=now();

    DROP TABLE IF EXISTS a20;
    SET @st=CONCAT( 'CREATE TABLE a20 ( a20_from int(8) unsigned NOT NULL default ', "'0'", ', a20_to int(8) unsigned NOT NULL default ', "'0'", ' ) ENGINE=MEMORY AS /* SLOW_OK */ SELECT STRAIGHT_JOIN pl_from as a20_from, uid as a20_to FROM ', @dbname, '.pagelinks, tcp WHERE pl_namespace=0 and pl_from IN ( SELECT id FROM articles ) and pl_title=tcp_name;' );
    PREPARE stmt FROM @st;
    EXECUTE stmt;
    DEALLOCATE PREPARE stmt;

    SELECT CONCAT( ':: echo ', count(*), ' links from articles to main namespace' )
           FROM a20;

    SELECT CONCAT( ':: echo a20 processing time: ', TIMEDIFF(now(), @starttime1));

    SET @starttime1=now();

    DELETE a20
           FROM ti,
                t20,
                a20
           WHERE ti_to=t20_from and
                 ti_from=a20_from and
                 t20_to=a20_to;

    SELECT CONCAT( ':: echo ', count(*), ' links mentioned in article texts and linking main namespace' )
           FROM a20;

    SELECT CONCAT( ':: echo template links deletion time: ', TIMEDIFF(now(), @starttime1));

    SET @starttime1=now();

    DROP TABLE IF EXISTS tcl;
    CREATE TABLE tcl (
      lid int(8) unsigned NOT NULL default '0',
      llen int(8) unsigned NOT NULL default '0',
      PRIMARY KEY (lid)
    ) ENGINE=MEMORY AS
    SELECT uid as lid,
           length(tcp_name) as llen
           FROM tcp;

    ALTER TABLE a20 ADD KEY (a20_to);

    SELECT CONCAT( ':: echo tcl and a20 altering time: ', TIMEDIFF(now(), @starttime1));

    SET @starttime1=now();

    #
    # Articles by their length.
    #
    DROP TABLE IF EXISTS text_len;
    CREATE TABLE text_len (
      id INT(8) unsigned NOT NULL default '0',
      page_len INT(8) unsigned NOT NULL default '0',
      PRIMARY KEY (id)
    ) ENGINE=MyISAM;
    SET @st=CONCAT( 'INSERT INTO text_len (id, page_len) SELECT id, page_len FROM ', @dbname, '.page, articles WHERE id=page_id;' );
    PREPARE stmt FROM @st;
    EXECUTE stmt;
    DEALLOCATE PREPARE stmt;

    SELECT CONCAT( ':: echo overal articles length is ', sum(page_len), ' bytes' )
           FROM text_len;

    SELECT CONCAT( ':: echo articles overal length computation time: ', TIMEDIFF(now(), @starttime1));

#
#    This should output the amount of massive link lists.
#
#    But it doesn't due to unrecognized links from templates doing
#    concatenation on link destination names.
#
#    SELECT id, 
#           # 4 here states for '[[' and ']]'
#           (page_len-sum(llen))/count(*)-4 as criterion
#           FROM a20, 
#                tcl,
#                text_len
#           WHERE id=a20_from and
#                 a20_to=lid
#           GROUP by id 
#           ORDER by criterion asc 
#           LIMIT 10;
  END;
//

delimiter ;
############################################################

-- </pre>
