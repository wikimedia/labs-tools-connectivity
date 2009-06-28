 --
 -- Authors: [[:ru:user:Mashiah Davidson]], still alone
 --
 -- Caution: PROCEDUREs defined here may have output designed for handle.sh.
 -- 
 -- Shared procedures: categories
 --                    categorylinks
 --                    categorystats
 --                    isolated_by_category
 --
 -- Shared functins: nrcatuid
 --
 -- <pre>

 --
 -- Significant speedup
 --

SET SESSION TRANSACTION ISOLATION LEVEL READ UNCOMMITTED;


############################################################
delimiter //

#
# Do all the connectivity analysis.
#
DROP PROCEDURE IF EXISTS categories//
CREATE PROCEDURE categories ()
  BEGIN
    SELECT ':: echo CATEGORIZER SETUP';

    SET @starttime=now();

    CALL cache_namespace_pages( 14 );
    # fortunately for this namespace we do not depend on temporary data
    DROP TABLE p14;

    DROP TABLE IF EXISTS categories;
    CREATE TABLE categories (
      id int(8) unsigned NOT NULL default '0',
      title varchar(255) binary NOT NULL default '',
      PRIMARY KEY (id),
      UNIQUE KEY title (title)
    ) ENGINE=MyISAM AS
    SELECT id,
           title
           FROM nr14;

    # allows unique identifiers for non-existent categories
    SELECT max(id)+1 INTO @freecatid
           FROM categories;

    SELECT CONCAT( ':: echo categories prefetch time: ', timediff(now(), @starttime));
  END;
//


DROP FUNCTION IF EXISTS nrcatuid//
CREATE FUNCTION nrcatuid (name VARCHAR(255))
  RETURNS INT
  DETERMINISTIC
  BEGIN
    DECLARE res INT;

    SELECT id INTO res
           FROM categories
           WHERE title=name;

    RETURN res;
  END;
//

DROP PROCEDURE IF EXISTS categorylinks//
CREATE PROCEDURE categorylinks (namespace INT)
  BEGIN
    DECLARE st VARCHAR(511);

    DROP TABLE IF EXISTS nrcatl;
    SET @st=CONCAT( 'CREATE TABLE nrcatl ( nrcl_from int(8) unsigned NOT NULL default ', "'0',", ' nrcl_cat int(8) unsigned NOT NULL default ', "'0',", ' KEY (nrcl_from), KEY (nrcl_cat) ) ENGINE=MEMORY AS SELECT nr', namespace, '.id as nrcl_from, categories.id as nrcl_cat FROM ', @dbname, '.categorylinks, nr', namespace, ', categories WHERE nr', namespace, '.id=cl_from and cl_to=categories.title;' );
    PREPARE stmt FROM @st;
    EXECUTE stmt;
    DEALLOCATE PREPARE stmt;

    SELECT CONCAT( ':: echo ', count(*), ' categorizing links for non-redirect pages' )
           FROM nrcatl;
  END;
//

DROP PROCEDURE IF EXISTS categorystats//
CREATE PROCEDURE categorystats (inname VARCHAR(255), outname VARCHAR(255))
  BEGIN
    DECLARE st VARCHAR(511);

    SET @st=CONCAT( 'DROP TABLE IF EXISTS ', outname, ';' );
    PREPARE stmt FROM @st;
    EXECUTE stmt;
    DEALLOCATE PREPARE stmt;

    SET @st=CONCAT( 'CREATE TABLE ', outname, " ( cat int(8) unsigned NOT NULL default '0', cnt int(8) unsigned NOT NULL default '0', PRIMARY KEY (cat) ) ENGINE=MyISAM AS SELECT nrcl_cat as cat, count(DISTINCT id) as cnt FROM nrcatl0, ", inname, ' WHERE id=nrcl_from GROUP BY nrcl_cat;' );
    PREPARE stmt FROM @st;
    EXECUTE stmt;
    DEALLOCATE PREPARE stmt;

    # as well as it is now applied to isolates,
    # let remove isolated categories from the stat.
    SET @st=CONCAT( 'DELETE ', outname, ' FROM ', outname,', ll_orcat WHERE uid=', outname, '.cat;' );
    PREPARE stmt FROM @st;
    EXECUTE stmt;
    DEALLOCATE PREPARE stmt;
  END;
//

#
# Preparing data to use in external "isolated by category" tool.
#
DROP PROCEDURE IF EXISTS isolated_by_category//
CREATE PROCEDURE isolated_by_category ()
  BEGIN
    SET @starttime=now();

    #
    # Amount of articles for each category.
    # Note: Think about uncategorized articles.
    #
    CALL categorystats( 'articles', 'catvolume' );

    CALL categorystats( 'ruwiki0', 'isocatvolume' );

    DROP TABLE IF EXISTS catvolume0;
    RENAME TABLE catvolume TO catvolume0;
    DROP TABLE IF EXISTS isocatvolume0;
    RENAME TABLE isocatvolume TO isocatvolume0;

    CALL actuality( 'isolatedbycategory' );

    SELECT CONCAT( ':: echo isolated for category web tool time: ', timediff(now(), @starttime));
  END;
//

delimiter ;
############################################################

-- </pre>
