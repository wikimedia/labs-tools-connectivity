 --
 -- Authors: [[:ru:user:Mashiah Davidson]], still alone
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
# Select pages in a set given by nrcat table and categorized there as
# disambiguation pages.
#
DROP PROCEDURE IF EXISTS collect_disambig//
CREATE PROCEDURE collect_disambig ()
  BEGIN
    #
    # Disambiguation pages collected here.
    # The list is superflous, i.e. contains pages from all namespaces.
    #
    # With namespace=14 it does show if disambiguations category is split into
    # subcategories.
    #
    DROP TABLE IF EXISTS d;
    CREATE TABLE d (
      d_id int(8) unsigned NOT NULL default '0',
      PRIMARY KEY (d_id)
    ) ENGINE=MEMORY AS
    SELECT DISTINCT nrcl_from as d_id
           FROM nrcatl
                 #                   disambiguation pages
           WHERE nrcl_cat=nrcatuid( 'Многозначные_термины' );

    SELECT CONCAT( ':: echo ', count(*), ' disambiguation names found' )
           FROM d;
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

    SELECT CONCAT( ':: echo ', count(*), ' links from disambigs to articles' )
           FROM ld;

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

    SELECT CONCAT( ':: echo ', count(*), ' one way links from articles to disambigs' )
           FROM dl;
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
    ) ENGINE=MEMORY;

    SET @st=CONCAT( 'INSERT INTO disambiguate SELECT nr', namespace, '.title as d_title, dss_cnt as d_cnt FROM dsstat, nr', namespace, ' WHERE nr', namespace, '.id=dss_id ORDER BY dss_cnt DESC;' );
    PREPARE stmt FROM @st;
    EXECUTE stmt;
    DEALLOCATE PREPARE stmt;

    DROP TABLE dsstat;
  END;
//

#
# Copies disambiguate table into a table with a name given for cgi tools
#
DROP PROCEDURE IF EXISTS disambiguator_refresh//
CREATE PROCEDURE disambiguator_refresh ( dsname VARCHAR(255) )
  BEGIN
    DECLARE st VARCHAR(255);

    SET @st=CONCAT( 'DROP TABLE IF EXISTS ', dsname, ';' );
    PREPARE stmt FROM @st;
    EXECUTE stmt;
    DEALLOCATE PREPARE stmt;

    SET @st=CONCAT( 'RENAME TABLE disambiguate TO ', dsname, ';' );
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
    ) ENGINE=MEMORY AS
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

    SELECT CONCAT( ':: echo ', count(DISTINCT id), ' isolated articles may become linked' )
           FROM a2i;

    CALL categorystats( 'a2i', 'sgdcatvolume' );

    DROP TABLE IF EXISTS isdis;
    RENAME TABLE a2i TO isdis;

    DROP TABLE IF EXISTS sgdcatvolume0;
    RENAME TABLE sgdcatvolume TO sgdcatvolume0;

    CALL actuality( 'dsuggestor' );
  END;
//

DROP PROCEDURE IF EXISTS disambiguator_unload//
CREATE PROCEDURE disambiguator_unload ()
  BEGIN
    DROP TABLE IF EXISTS dl;
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

    CALL disambiguator_refresh( 'disambiguate0' );

    CALL actuality( 'disambiguator' );

    SELECT CONCAT( ':: echo links disambiguator processing time: ', timediff(now(), @starttime));
  END;
//

delimiter ;
############################################################

-- </pre>
