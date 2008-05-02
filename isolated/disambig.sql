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
    SELECT DISTINCT nrc_id as d_id
           FROM nrcat
                 #      disambiguation pages
           WHERE nrc_to='Многозначные_термины';

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
                  SELECT a_id 
                         FROM articles
                 ) and
                 pl_to=d_id;

    SELECT CONCAT( ':: echo ', count(*), ' links from articles to disambigs' )
           FROM dl;

    #
    # Here we adding direct links from disambiguations to articles.
    #
    INSERT IGNORE INTO ld
    SELECT a_id as ld_to,
           pl_from as ld_from
           FROM pl,
                articles
           WHERE pl_from in
                 (
                  SELECT d_id 
                         FROM d
                 ) and
                 pl_to=a_id;

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
# Creates statistics on disambiguation pages linking and puts it into
# disambiguate0.
#
DROP PROCEDURE IF EXISTS disambiguator//
CREATE PROCEDURE disambiguator ()
  BEGIN
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
    ) ENGINE=MEMORY AS
    SELECT nr_title as d_title,
           dss_cnt as d_cnt
           FROM dsstat,
                nr
           WHERE nr_id=dss_id
           ORDER BY dss_cnt DESC;
    DROP TABLE dsstat;

    DROP TABLE IF EXISTS disambiguate0;
    RENAME TABLE disambiguate TO disambiguate0;
  END;
//

delimiter ;
############################################################
