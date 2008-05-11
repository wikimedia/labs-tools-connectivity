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
      a2i_to varchar(255) binary NOT NULL default '',
      KEY (a2i_to)
    ) ENGINE=MEMORY AS
    SELECT dl_from as a2i_from,
           d2i_from as a2i_via,
           d2i_to as a2i_to
           FROM dl,
                d2i
           WHERE dl_to=d2i_from;

    DROP TABLE d2i;

    SELECT CONCAT( ':: echo ', count(*), ' links from articles to articles through disambiguation pages linking isolates' )
           FROM a2i;

    SELECT CONCAT( ':: echo ', count(DISTINCT a2i_to), ' isolated articles may become linked' )
           FROM a2i;

    INSERT INTO isocat
    SELECT cv_title as ic_title,
           count(DISTINCT a2i_to) as ic_count
           FROM nrcat0,
                ruwiki0,
                a2i,
                catvolume
           WHERE nrc_id=id and
                 title=a2i_to and
                 nrc_to=cv_title
           GROUP BY cv_title;

    UPDATE catvolume,
           isocat
           SET cv_dsgcount=ic_count
           WHERE ic_title=cv_title;
    DELETE FROM isocat;
  END;
//

DROP PROCEDURE IF EXISTS disambiguator_unload//
CREATE PROCEDURE disambiguator_unload ()
  BEGIN
    DROP TABLE IF EXISTS dl;
    DROP TABLE IF EXISTS ld;
  END;
//

delimiter ;
############################################################
