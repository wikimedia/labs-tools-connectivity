 --
 -- Authors: [[:ru:user:Mashiah Davidson]], still alone
 --
 -- Caution: PROCEDUREs defined here may have output designed for handle.sh.
 -- 
 -- Shared procedures: a2a_templating
 --
 -- <pre>

 --
 -- Significant speedup
 --

SET SESSION TRANSACTION ISOLATION LEVEL READ UNCOMMITTED;


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
    # Articles encapsulated directly into other articles.
    # Note: Fast when templating is completely unusual for articles.
    #       Than more are templated than slower this selection is.
    SET @st=CONCAT( 'INSERT IGNORE INTO pl SELECT tl_from as pl_from, id as pl_to FROM ', @dbname, '.templatelinks, articles WHERE tl_namespace=0 and tl_from IN ( SELECT id FROM articles ) and title=tl_title;' );
    PREPARE stmt FROM @st;
    EXECUTE stmt;
    DEALLOCATE PREPARE stmt;

    SELECT CONCAT( ':: echo ', count(*), ' templating links from article to article' )
           FROM pl;

    #
    # This table contain info on templating of zero namespace redirects
    # in articles.
    #
    # Note: Table name selection is dictated by nr2X2nr called below.
    #
    DROP TABLE IF EXISTS nr2r;

    SET @st=CONCAT( 'CREATE TABLE nr2r ( nr2r_to int(8) unsigned NOT NULL default ', "'0'", ', nr2r_from int(8) unsigned NOT NULL default ', "'0'", ', KEY (nr2r_to) ) ENGINE=MEMORY AS SELECT r_id as nr2r_to, tl_from as nr2r_from FROM ', @dbname, '.templatelinks, r0 WHERE tl_namespace=0 and tl_from in ( SELECT id FROM articles ) and tl_title=r_title;' );
    PREPARE stmt FROM @st;
    EXECUTE stmt;
    DEALLOCATE PREPARE stmt;

    SELECT CONCAT( ':: echo ', count(*), ' templating links from articles to redirects' )
           FROM nr2r;

    CALL nr2X2nr();
    DROP TABLE nr2r;
    DROP TABLE r2r;

    SELECT CONCAT( ':: echo ', count(*), ' overall (direct & redirected) articles templating links count' )
           FROM pl;
  END;
//

delimiter ;
############################################################

-- </pre>
