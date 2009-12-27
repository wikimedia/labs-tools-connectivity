 --
 -- Authors: [[:ru:user:Mashiah Davidson]],
 --          [[:ru:user:Kalan]]
 --
 -- Caution: PROCEDUREs defined here may have output designed for handle.sh.
 --
 -- Shared procedures: collect_disambig
 --                    disambigs_as_fusy_redirects
 --                    disambiguator_unload
 --                    constructNdisambiguate
 --
 -- <pre>

 --
 -- Significant speedup
 --

SET SESSION TRANSACTION ISOLATION LEVEL READ UNCOMMITTED;


############################################################
delimiter //

#
# Templates marking disambiguation pages are being collected by administrators
# at [[:ru:MediaWiki:Disambiguationspage]].
#
# So, here we extract links to template pages from this special page and then
# collect disambiguation pages templated.
# 
# This works much better than selection by category name, which could be
# different in its meaning, content and naming for various languages.
#
DROP PROCEDURE IF EXISTS collect_disambig//
CREATE PROCEDURE collect_disambig (dbname VARCHAR(32), namespace INT, prefix VARCHAR(32))
  BEGIN
    DECLARE st VARCHAR(511);

    #
    # All disambiguation templates including templates-redirects are being
    # stored here.
    #
    DROP TABLE IF EXISTS dt;
    SET @st=CONCAT( 'CREATE TABLE dt ( dt_title varchar(255) binary NOT NULL default "", PRIMARY KEY (dt_title) ) ENGINE=MEMORY AS SELECT DISTINCT pl_title as dt_title FROM ', dbname, '.page, ', dbname, '.pagelinks WHERE page_namespace=8 AND page_title="Disambiguationspage" AND pl_from=page_id AND pl_namespace=10' );
    PREPARE stmt FROM @st;
    EXECUTE stmt;
    DEALLOCATE PREPARE stmt;

    SELECT CONCAT( prefix, count(*), ' disambiguating template names found' )
           FROM dt;

    #
    # Dirty list of disambiguation pages, everything, 
    # not just the namespace given.
    #
    SET @st=CONCAT( 'INSERT INTO d SELECT DISTINCT tl_from as d_id FROM dt, ', dbname, '.templatelinks WHERE tl_namespace=10 and tl_title=dt_title;' );
    PREPARE stmt FROM @st;
    EXECUTE stmt;
    DEALLOCATE PREPARE stmt;

    SELECT count(*) INTO @disambiguation_pages_count
           FROM d;

    SELECT CONCAT( prefix, @disambiguation_pages_count, ' disambiguation pages for all namespaces' );

    IF namespace>=0
      THEN
        #
        # Disambiguation pages for the namespace given are being collected here.
        #
        SET @st=CONCAT( 'DELETE FROM d WHERE d_id not in (select id from nr', namespace, ');' );
        PREPARE stmt FROM @st;
        EXECUTE stmt;
        DEALLOCATE PREPARE stmt;

        SELECT count(*) INTO @disambiguation_pages_count
               FROM d;

        SELECT CONCAT( prefix, @disambiguation_pages_count, ' disambiguation pages found for namespace ', namespace );
    END IF;

    DROP TABLE dt;

  END;
//

#
# Links from articles to disambiguations are constructed here.
#
DROP PROCEDURE IF EXISTS construct_dlinks//
CREATE PROCEDURE construct_dlinks ()
  BEGIN
    #
    # Table dl is created here for links from articles to disambiguations.
    #
    DROP TABLE IF EXISTS dl;
    CREATE TABLE dl (
      dl_to int(8) unsigned NOT NULL default '0',
      dl_from int(8) unsigned NOT NULL default '0',
      PRIMARY KEY (dl_to,dl_from)
    ) ENGINE=MEMORY;

    # Table ld is created here for links from disambiguations to articles.
    DROP TABLE IF EXISTS ld;
    CREATE TABLE ld (
      ld_to int(8) unsigned NOT NULL default '0',
      ld_from int(8) unsigned NOT NULL default '0',
      PRIMARY KEY (ld_to,ld_from)
    ) ENGINE=MEMORY;

    #
    # Here we adding direct links from articles to disambiguations.
    #
    INSERT IGNORE INTO dl
    SELECT d_id as dl_to,
           pl_from as dl_from
           FROM pl,
                d
           WHERE pl_from in
                 (
                  SELECT id 
                         FROM articles
                 ) and
                 pl_to=d_id;

    SELECT CONCAT( ':: echo ', count(*), ' links from articles to disambigs' )
           FROM dl;

    #
    # Here we adding direct links from disambiguations to articles.
    #
    INSERT IGNORE INTO ld
    SELECT id as ld_to,
           pl_from as ld_from
           FROM pl,
                articles
           WHERE pl_from in
                 (
                  SELECT d_id 
                         FROM d
                 ) and
                 pl_to=id;

    SELECT count(*) INTO @disambiguations_to_articles_links_count
           FROM ld;

    SELECT CONCAT( ':: echo ', @disambiguations_to_articles_links_count, ' links from disambigs to articles' );

    #
    # Linking rings between articles and disambiguation pages are constructed
    # with technical links like {{tl|otheruses}} we do not to take this
    # special type of linking into account.
    #
    DELETE dl
           FROM dl,
                ld
           WHERE dl_to=ld_from and
                 dl_from=ld_to;

    SELECT count(*) INTO @aricles_to_disambiguations_links_count
           FROM dl;

    SELECT CONCAT( ':: echo ', @aricles_to_disambiguations_links_count, ' one way links from articles to disambigs' );
  END;
//

#
# Creates statistics on disambiguation pages linking.
#
DROP PROCEDURE IF EXISTS disambiguator//
CREATE PROCEDURE disambiguator (namespace INT)
  BEGIN
    DECLARE st VARCHAR(255);

    # statistics for amount of links from articles to each linked disambig
    DROP TABLE IF EXISTS dsstat;
    CREATE TABLE dsstat (
      dss_id int(8) unsigned NOT NULL default '0',
      dss_cnt int(8) unsigned NOT NULL default '0',
      PRIMARY KEY (dss_id)
    ) ENGINE=MEMORY AS                                                                                                                
    SELECT dl_to as dss_id,
           count(*) as dss_cnt
           FROM dl
           GROUP BY dl_to;

    DROP TABLE IF EXISTS disambiguate;
    CREATE TABLE disambiguate (
      d_title varchar(255) binary NOT NULL default '',
      d_cnt int(8) unsigned NOT NULL default '0'
    ) ENGINE=MyISAM;

    SET @st=CONCAT( 'INSERT INTO disambiguate SELECT nr', namespace, '.title as d_title, dss_cnt as d_cnt FROM dsstat, nr', namespace, ' WHERE nr', namespace, '.id=dss_id ORDER BY dss_cnt DESC;' );
    PREPARE stmt FROM @st;
    EXECUTE stmt;
    DEALLOCATE PREPARE stmt;

    DELETE FROM dsstat;

    # statistics on amount of links to disambigs for each article having such
    INSERT INTO dsstat
    SELECT dl_from as dss_id,
           count(*) as dss_cnt
           FROM dl
           GROUP BY dl_from;

    DROP TABLE IF EXISTS disambigtop;
    CREATE TABLE disambigtop (
      d_title varchar(255) binary NOT NULL default '',
      d_cnt int(8) unsigned NOT NULL default '0'
    ) ENGINE=MyISAM AS
    SELECT articles.title as d_title,
           dss_cnt as d_cnt
           FROM dsstat,
                articles
           WHERE articles.id=dss_id
           ORDER BY dss_cnt DESC;

    DROP TABLE dsstat;

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
    # Template documentation pages sometimes are redirects to other documents.
    #
    INSERT INTO doct
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

    #
    # Links present on template pages due to documentation included.
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

    #
    # Links from documentation page a being removed here from templates as
    # not occuring in articles with templating.
    #
    DELETE t2p
           FROM t2p,
                r_t2p
           WHERE t2p_from=r_t2p_from AND
                 t2p_to=r_t2p_to;

    SELECT CONCAT( ':: echo ', count(*), ' links from templates to main namespace pages after documentation links removal' )
           FROM t2p;

    DROP TABLE IF EXISTS tdl;
    CREATE TABLE tdl (
      dl_to int(8) unsigned NOT NULL default '0',
      dl_from int(8) unsigned NOT NULL default '0'
    ) ENGINE=MyISAM AS
    SELECT id as dl_from,
           t2p_to as dl_to
           FROM t2p,
                regular_templates
           WHERE t2p_to in (
                             SELECT cnad_id
                                    FROM cnad
                           ) AND
                 t2p_from=id;

    DROP TABLE IF EXISTS t2d;
    CREATE TABLE t2d (
      td_id int(8) unsigned NOT NULL default '0',
      t_title varchar(255) binary NOT NULL default '',
      d_cnt int(8) unsigned NOT NULL default '0',
      PRIMARY KEY (td_id)
    ) ENGINE=MEMORY AS
    SELECT id as td_id,
           title as t_title,
           count(t2p_to) as d_cnt
           FROM t2p,
                regular_templates
           WHERE t2p_to in (
                             SELECT cnad_id
                                    FROM cnad
                           ) AND
                 t2p_from=id
           GROUP BY t2p_from;

    SELECT CONCAT( ':: echo ', sum(d_cnt), ' links from templates to disambiguation pages' )
           FROM t2d;

    #
    # Redirected vs non-redirected combining.
    #
    # First create an imagination of self-redirects from/to every template.
    #
    INSERT INTO r2nr10
    SELECT id as r2nr_to,
           id as r2nr_from
           FROM regular_templates;

    DROP TABLE IF EXISTS tmpldisambig;
    CREATE TABLE tmpldisambig (
      td_id int(8) unsigned NOT NULL default '0',
      d_cnt int(8) unsigned NOT NULL default '0',
      a_cnt int(8) unsigned NOT NULL default '0',
      ad_cnt int(8) unsigned NOT NULL default '0'
    ) ENGINE=MyISAM AS
    SELECT r2nr_to as td_id,
           t_title,
           sum(a_cnt) as a_cnt,
           d_cnt,
           sum(a_cnt)*d_cnt as ad_cnt
           FROM templatetop,
                r2nr10,
                t2d
           WHERE t_id=r2nr_from AND
                 r2nr_to=td_id
           GROUP BY r2nr_to;

  END;
//

#
# Copies disambiguate table into a table with a name given for cgi tools
#
DROP PROCEDURE IF EXISTS disambiguator_refresh//
CREATE PROCEDURE disambiguator_refresh ( dsname VARCHAR(255), oldname VARCHAR(255) )
  BEGIN
    DECLARE st VARCHAR(255);

    SET @st=CONCAT( 'DROP TABLE IF EXISTS ', dsname, ';' );
    PREPARE stmt FROM @st;
    EXECUTE stmt;
    DEALLOCATE PREPARE stmt;

    SET @st=CONCAT( 'RENAME TABLE ', oldname, ' TO ', dsname, ';' );
    PREPARE stmt FROM @st;
    EXECUTE stmt;
    DEALLOCATE PREPARE stmt;
  END;
//


#
# Takes ruwiki0, dl and ld as inputs.
#
# Produces a2i table, containing links from articles to isolates
# through disambiguations (as if they are just redirects).
#
# Also updates catvolume table for categorizer.
#
DROP PROCEDURE IF EXISTS disambigs_as_fusy_redirects//
CREATE PROCEDURE disambigs_as_fusy_redirects ()
  BEGIN
    DECLARE st VARCHAR(511);

    #
    # Isolated articles linked from disambiguations.
    # 
    DROP TABLE IF EXISTS d2i;
    CREATE TABLE d2i (
      d2i_from int(8) unsigned NOT NULL default '0',
      d2i_to varchar(255) binary NOT NULL default '',
      KEY (d2i_to)
    ) ENGINE=MEMORY AS
    SELECT ld_from as d2i_from,
           title as d2i_to
           FROM ruwiki0,
                ld
           WHERE id=ld_to;

    SELECT CONCAT( ':: echo ', count(*), ' links from disambigs to isolated articles' )
           FROM d2i;

    #
    # Links from articles to articles through disambiguation pages linking isolates.
    # 
    DROP TABLE IF EXISTS a2i;
    CREATE TABLE a2i (
      a2i_from int(8) unsigned NOT NULL default '0',
      a2i_via int(8) unsigned NOT NULL default '0',
      id int(8) unsigned NOT NULL default '0',
      KEY (id)
    ) ENGINE=MyISAM AS
    SELECT dl_from as a2i_from,
           d2i_from as a2i_via,
           id
           FROM dl,
                d2i,
                ruwiki0
           WHERE dl_to=d2i_from and
                 title=d2i_to;

    DROP TABLE d2i;

    SELECT CONCAT( ':: echo ', count(*), ' links from articles to articles through disambiguation pages linking isolates' )
           FROM a2i;

    SELECT CONCAT( ':: echo ', count(DISTINCT id), ' isolated articles might become linked' )
           FROM a2i;

    CALL categorystats( 'a2i', 'sgdcatvolume' );

    DROP TABLE IF EXISTS isdis;
    RENAME TABLE a2i TO isdis;

    DROP TABLE IF EXISTS sgdcatvolume0;
    RENAME TABLE sgdcatvolume TO sgdcatvolume0;

    ALTER TABLE dl ENGINE=MyISAM;
    DROP TABLE IF EXISTS dl0;
    RENAME TABLE dl TO dl0;

    CALL actuality( 'dsuggestor' );
  END;
//

DROP PROCEDURE IF EXISTS disambiguator_unload//
CREATE PROCEDURE disambiguator_unload ()
  BEGIN
    DROP TABLE IF EXISTS ld;
  END;
//

#
# Outputs:
#   ld - links from disambiguation pages to articles,
#   dl - links from articles to disambiguation pages.
#   disambiguate0 - statistiscs on disambiguation pages linking
#
DROP PROCEDURE IF EXISTS constructNdisambiguate//
CREATE PROCEDURE constructNdisambiguate ()
  BEGIN
    SELECT ':: echo LINKS DISAMBIGUATOR';

    SET @starttime=now();

    # Constructs two tables of links:
    #  - a2d named dl;
    #  - d2a named ld.
    # dl and ld are not in l, so we use pl again there
    CALL construct_dlinks();

    #
    #  LINKS DISAMBIGUATOR
    #
    CALL disambiguator( 0 );

    CALL disambiguator_refresh( 'disambiguate0', 'disambiguate' );

    CALL disambiguator_refresh( 'disambigtop0', 'disambigtop' );

    CALL disambiguator_refresh( 'tmpldisambig0', 'tmpldisambig' );

    CALL disambiguator_refresh( 'dl10', 'tdl' );

    CALL actuality( 'disambiguator' );

    SELECT CONCAT( ':: echo links disambiguator processing time: ', timediff(now(), @starttime));
  END;
//

DROP PROCEDURE IF EXISTS store_drdi//
CREATE PROCEDURE store_drdi ()
  BEGIN
    DECLARE _l_ratio REAL(5,3) DEFAULT @aricles_to_disambiguations_links_count*100/(@aricles_to_disambiguations_links_count+@articles_to_articles_links_count);
    DECLARE _d_ratio REAL(5,3) DEFAULT @disambiguation_pages_count*100/(@disambiguation_pages_count+@articles_count);
    DECLARE _drdi REAL(5,3) DEFAULT _l_ratio*100/_d_ratio;

    #
    # DRDI, id est <<disambiguation rule>> disregard ratio.
    #

    # permanent storage for inter-run data created here if not exists
    CREATE TABLE IF NOT EXISTS drdi (
      l_ratio REAL(5,3) NOT NULL,
      lamnt INT(8) NOT NULL DEFAULT '0',
      d_ratio REAL(5,3) NOT NULL,
      DRDI REAL(5,3) NOT NULL
    ) ENGINE=MyISAM;

    # no need to keep old data because the action has performed
    DELETE FROM drdi;

    INSERT INTO drdi
    VALUES ( _l_ratio, @aricles_to_disambiguations_links_count, _d_ratio, _drdi );
  END;
//

delimiter ;
############################################################

-- </pre>
