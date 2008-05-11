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
# Also throws redirects and redirect chains and add all redirected chains
# into pl table as regular links.
#
# Inputs: r, nr, pl.
#
# Outputs: wr, pl filtered, r filtered, r2nr, mr output into a file
#
DROP PROCEDURE IF EXISTS cleanup_redirects//
CREATE PROCEDURE cleanup_redirects (namespace INT)
  BEGIN
    DECLARE cnt INT;
    DECLARE chainlen INT DEFAULT '1';

    # the amount of links from redirect pages in a given namespace
    DROP TABLE IF EXISTS rlc;
    CREATE TABLE rlc (
      rlc_cnt int(8) unsigned NOT NULL default '0',
      rlc_id int(8) unsigned NOT NULL default '0'
    ) ENGINE=MEMORY AS
    SELECT count(*) as rlc_cnt,
           r_id as rlc_id
           FROM pl,
                r
           WHERE pl_from=r_id
           GROUP BY r_id;

    # REDIRECT PAGES WITH MORE THAN ONE LINK
    DROP TABLE IF EXISTS wr;
    CREATE TABLE wr (
      wr_title varchar(255) binary NOT NULL default '',
      PRIMARY KEY (wr_title)
    ) ENGINE=MEMORY AS
    SELECT r_title as wr_title
           FROM r,
                rlc
           WHERE rlc_cnt>1 and
                 rlc_id=r_id;
    DROP TABLE rlc;

    CALL outifexists( 'wr', 'wrong redirects', 'wr.txt', 'wr_title', 'out' );

    # prevent taking wrong redirects into account
    DELETE FROM r
           WHERE r_title IN
                 (
                  SELECT wr_title
                         FROM wr
                 );

    IF namespace=14
      THEN
        # redirects in this namespace are prohibited
        # they do not supply articles with proper categories
        CALL outifexists( 'r', CONCAT( 'redirects for namespace ', namespace), 'r.txt', 'r_title', 'out' );
    END IF;

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
    DROP TABLE IF EXISTS r2r;
    CREATE TABLE r2r (
      r2r_to int(8) unsigned NOT NULL default '0',
      r2r_from int(8) unsigned NOT NULL default '0',
      KEY (r2r_to)
    ) ENGINE=MEMORY AS 
    SELECT r_id as r2r_to,
           pl_from as r2r_from
           FROM pl,
                r
           WHERE pl_from in
                 (
                  SELECT r_id
                         FROM r
                 ) and
                 pl_to=r_id;

    #
    # Names of redirect pages linking other redirects.
    # This table contains everything required for multiple redirects resolving.
    #
    DROP TABLE IF EXISTS mr;
    CREATE TABLE mr (
      mr_title varchar(255) binary NOT NULL default ''
    ) ENGINE=MEMORY AS
    SELECT r_title as mr_title
           FROM r2r,
                r
           WHERE r2r_from=r_id;

    CALL outifexists( 'mr', 'redirects linking redirects', 'mr.info', 'mr_title', 'upload' );

    DROP TABLE mr;

    # All links from non-redirects to redirects for a given namespace.
    DROP TABLE IF EXISTS nr2r;
    CREATE TABLE nr2r (
      nr2r_to int(8) unsigned NOT NULL default '0',
      nr2r_from int(8) unsigned NOT NULL default '0',
      KEY (nr2r_to)
    ) ENGINE=MEMORY AS 
    SELECT r_id as nr2r_to,
           pl_from as nr2r_from
           FROM pl,
                r
           WHERE pl_from in
                 (
                  SELECT nr_id 
                         FROM nr
                 ) and
                 pl_to=r_id;

    SELECT CONCAT( ':: echo ', count(*), ' links from non-redirects to redirects' )
           FROM nr2r;
           
    # All links from our namespace redirects to articles.
    DROP TABLE IF EXISTS r2nr;
    CREATE TABLE r2nr (
      r2nr_to int(8) unsigned NOT NULL default '0',
      r2nr_from int(8) unsigned NOT NULL default '0'
    ) ENGINE=MEMORY AS 
    SELECT nr_id as r2nr_to,
           pl_from as r2nr_from
           FROM pl,
                nr
           WHERE pl_from in
                 (
                  SELECT r_id
                         FROM r
                 ) and
                 pl_to=nr_id;

    SELECT count(*) INTO cnt
           FROM r2nr;

    WHILE cnt>0 DO

      SELECT CONCAT( ':: echo ', cnt, ' links from non-redirects to non-redirects via a chain of ', chainlen, ' redirects' );

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

      SELECT CONCAT( ':: echo ', count(*), ' links after ', chainlen, '-redirect chains rectification' )
             FROM pl;

      #
      # One step of new long-redirect driven "links to be added" collection.
      #
      # Note: We've lost all the redirect rings here because of pure redirects
      #       in a ring unable to link non-redirects.
      #
      DROP TABLE IF EXISTS r2X2nr;
      CREATE TABLE r2X2nr (
        r2nr_to int(8) unsigned NOT NULL default '0',
        r2nr_from int(8) unsigned NOT NULL default '0'
      ) ENGINE=MEMORY;

      INSERT INTO r2X2nr
      SELECT r2nr_to,
             r2r_from as r2nr_from
             FROM r2r,
                  r2nr
             WHERE r2r_to=r2nr_from;

      DROP TABLE r2nr;

      SELECT count(*) INTO cnt
             FROM r2X2nr;

      #
      # Now X=r2X everywhere
      # 
      RENAME TABLE r2X2nr TO r2nr;

      SET chainlen=chainlen+1;

    END WHILE;

    DROP TABLE r2r;
    DROP TABLE nr2r;

  END;
//

DROP PROCEDURE IF EXISTS redirector_refresh//
CREATE PROCEDURE redirector_refresh (namespace INT)
  BEGIN
    IF namespace=0
      THEN
        DROP TABLE IF EXISTS wr0;
        RENAME TABLE wr TO wr0;
    END IF;

    IF namespace=14
      THEN
        DROP TABLE IF EXISTS r14;
        RENAME TABLE r TO r14;
        DROP TABLE IF EXISTS wr14;
        RENAME TABLE wr TO wr14;
    END IF;
  END;
//


DROP PROCEDURE IF EXISTS redirector_unload//
CREATE PROCEDURE redirector_unload (namespace INT)
  BEGIN
    IF namespace=0
      THEN
        DROP TABLE r;
    END IF;
    DROP TABLE r2nr;
  END;
//

delimiter ;
############################################################

