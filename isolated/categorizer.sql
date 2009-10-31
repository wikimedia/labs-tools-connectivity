 --
 -- Authors: [[:ru:user:Mashiah Davidson]]
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
# Caches pages for ns=14 and prepares the categories table.
#
DROP PROCEDURE IF EXISTS categories//
CREATE PROCEDURE categories ()
  BEGIN
    DECLARE st VARCHAR(511);

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

    DROP TABLE IF EXISTS visible_categories;
    CREATE TABLE visible_categories (
      id int(8) unsigned NOT NULL default '0',
      title varchar(255) binary NOT NULL default '',
      PRIMARY KEY (id),
      UNIQUE KEY title (title)
    ) ENGINE=MEMORY;

    DROP TABLE IF EXISTS nrcatl;
    SET @st=CONCAT( 'INSERT INTO visible_categories SELECT id, title FROM categories WHERE id NOT IN ( SELECT pp_page FROM ', @dbname, '.page_props WHERE pp_propname="hiddencat" );' );
    PREPARE stmt FROM @st;
    EXECUTE stmt;
    DEALLOCATE PREPARE stmt;

    #
    # Some of redundant categories are visible, so we take such names from
    #    @i18n_page/VisibleAuxiliaryCategories
    #
    SET @st=CONCAT( 'DELETE visible_categories FROM visible_categories, ', @dbname, '.page, ', @dbname, '.pagelinks WHERE title=pl_title and pl_namespace=14 and page_id=pl_from and page_namespace=4 and page_title="', @i18n_page, '/VisibleAuxiliaryCategories";' );
    PREPARE stmt FROM @st;
    EXECUTE stmt;
    DEALLOCATE PREPARE stmt;

    SELECT CONCAT( ':: echo ', count(*), ' visible categories found' )
           FROM visible_categories;

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

#
# Articles are considered as non-categorized if they belong only to 
# hidden categories or to categories listed at
#    @i18n_page/VisibleAuxiliaryCategories
#
DROP PROCEDURE IF EXISTS notcategorized//
CREATE PROCEDURE notcategorized ()
  BEGIN
    DECLARE st VARCHAR(511);
    DECLARE cnt INT;

    DROP TABLE IF EXISTS nocat;
    SET @st=CONCAT( "CREATE TABLE nocat ( nc_title varchar(255) binary NOT NULL default '', act INT(8) unsigned NOT NULL default '0', PRIMARY KEY (nc_title) ) ENGINE=MEMORY AS SELECT title AS nc_title, 1 as act FROM articles WHERE id NOT IN ( SELECT cl_from FROM visible_categories, ", @dbname, ".categorylinks WHERE cl_to=title );" );
    PREPARE stmt FROM @st;
    EXECUTE stmt;
    DEALLOCATE PREPARE stmt;

    SELECT count(*) INTO cnt
           FROM nocat;

    SELECT CONCAT( ':: echo ', cnt, ' articles with no regular categories' );

    SET @st=CONCAT( 'SELECT pl_title INTO @non_categorized_articles_category FROM ', @dbname, '.page, ', @dbname, '.pagelinks WHERE pl_namespace=14 and page_id=pl_from and page_namespace=4 and page_title="', @i18n_page, '/NonCategorizedArticles" LIMIT 1;' );
    PREPARE stmt FROM @st;
    EXECUTE stmt;
    DEALLOCATE PREPARE stmt;

    IF @non_categorized_articles_category!='NULL'
      THEN
        SET @st=CONCAT( 'INSERT INTO nocat SELECT title as nc_title, -1 as act FROM articles, ', @dbname, '.categorylinks WHERE id=cl_from and cl_to="', @non_categorized_articles_category, '" ON DUPLICATE KEY UPDATE act=0;' );
        PREPARE stmt FROM @st;
        EXECUTE stmt;
        DEALLOCATE PREPARE stmt;

        IF cnt>0
          THEN
            IF @enable_informative_output>0
              THEN
                SELECT CONCAT(':: out ', @fprefix, 'nca.info' ) as title;
                SELECT nc_title
                       FROM nocat
                       ORDER BY nc_title ASC;
            END IF;

            SELECT count( * ) INTO cnt
               FROM nocat
               WHERE act=1;
            IF cnt>0
              THEN
                SELECT CONCAT(':: echo +: ', cnt ) as title;
                SELECT CONCAT( ':: out ', @fprefix, 'ncaset.txt' );
                SELECT nc_title
                       FROM nocat
                       WHERE act=1
                       ORDER BY nc_title ASC;
            END IF;
        END IF;
    
        SELECT count( * ) INTO cnt
               FROM nocat
               WHERE act=-1;
        IF cnt>0
          THEN
            SELECT CONCAT(':: echo -: ', cnt ) as title;
            SELECT CONCAT( ':: out ', @fprefix, 'ncarem.txt' );
            SELECT nc_title
                   FROM nocat
                   WHERE act=-1
                   ORDER BY nc_title ASC;
        END IF;
    END IF;
  END;
//

DROP PROCEDURE IF EXISTS categorystats//
CREATE PROCEDURE categorystats (inname VARCHAR(255), outname VARCHAR(255))
  BEGIN
    DECLARE st VARCHAR(1024);

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

DROP PROCEDURE IF EXISTS langcategorystats//
CREATE PROCEDURE langcategorystats (inname VARCHAR(255), outname VARCHAR(255))
  BEGIN
    DECLARE st VARCHAR(1024);

    SET @st=CONCAT( 'DROP TABLE IF EXISTS ', outname, ';' );
    PREPARE stmt FROM @st;
    EXECUTE stmt;
    DEALLOCATE PREPARE stmt;

    SET @st=CONCAT( 'CREATE TABLE ', outname, " ( cat int(8) unsigned NOT NULL default '0', lang varchar(10) not null default '', a_amnt int(8) unsigned not null default '0', i_amnt int(8) unsigned not null default '0', PRIMARY KEY (lang, cat) ) ENGINE=MyISAM AS SELECT nrcl_cat as cat, lang, count(distinct suggestn) as a_amnt, count(distinct id) as i_amnt FROM nrcatl0, ", inname, ' WHERE id=nrcl_from GROUP BY lang, nrcl_cat;' );
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
