 --
 -- Authors: [[:ru:user:Mashiah Davidson]]
 --
 -- Caution: PROCEDUREs defined here may have output designed for suggest.sh.
 -- 
 -- Shared procedures: dsuggest
 --                    interwiki_suggest
 --                    interwiki_suggest_translate
 --
 -- <pre>

############################################################
delimiter //

#
# This procedure is being called from isolated articles categorization tool in
# order to list all isolated articles for a given category.
#
DROP PROCEDURE IF EXISTS isolated_for_category//
CREATE PROCEDURE isolated_for_category (cat_given VARCHAR(255), target_lang VARCHAR(16))
  BEGIN
    DECLARE st VARCHAR(255);

    SET @st=CONCAT( "SELECT cat, title FROM ", dbname_for_lang( target_lang ), ".categorylinks, ruwiki0 WHERE id=cl_from and cl_to=\"", cat_given, "\" ORDER BY title ASC;" );
    PREPARE stmt FROM @st;
    EXECUTE stmt;
    DEALLOCATE PREPARE stmt;
  END;
//


#
# This procedure is being called from isolated articles categorization tool in
# order to list all isolated articles for a given category for which there
# are linking suggestions exist through links disambiguation.
#
DROP PROCEDURE IF EXISTS isolated_for_category_dsuggestable//
CREATE PROCEDURE isolated_for_category_dsuggestable (cat_given VARCHAR(255), target_lang VARCHAR(16))
  BEGIN
    DECLARE st VARCHAR(255);

    SET @st=CONCAT( "SELECT DISTINCT cat, title FROM ", dbname_for_lang( target_lang ), ".categorylinks, ruwiki0, isdis WHERE ruwiki0.id=cl_from and cl_to=\"", cat_given, "\" and isdis.id=ruwiki0.id ORDER BY title ASC;" );
    PREPARE stmt FROM @st;
    EXECUTE stmt;
    DEALLOCATE PREPARE stmt;
  END;
//

#
# This procedure is being called from isolated articles categorization tool in
# order to list all isolated articles for a given category for which there
# are linking suggestions exist as interwiki links show.
#
DROP PROCEDURE IF EXISTS isolated_for_category_ilsuggestable//
CREATE PROCEDURE isolated_for_category_ilsuggestable (cat_given VARCHAR(255), target_lang VARCHAR(16), foreign_lang VARCHAR(16))
  BEGIN
    DECLARE st VARCHAR(511);

    IF foreign_lang=''
      THEN
        SET @st=CONCAT( "SELECT DISTINCT cat, title FROM ", dbname_for_lang( target_lang ), ".categorylinks, ruwiki0, isres WHERE ruwiki0.id=cl_from and cl_to=\"", cat_given, "\" and isres.id=ruwiki0.id ORDER BY title ASC;" );
      ELSE
        SET @st=CONCAT( "SELECT DISTINCT cat, title FROM ", dbname_for_lang( target_lang ), ".categorylinks, ruwiki0, isres WHERE ruwiki0.id=cl_from and cl_to=\"", cat_given, "\" and isres.id=ruwiki0.id and isres.lang=\"", foreign_lang, "\" ORDER BY title ASC;" );
    END IF;
    PREPARE stmt FROM @st;
    EXECUTE stmt;
    DEALLOCATE PREPARE stmt;
  END;
//

#
# This procedure is being called from isolated articles categorization tool in
# order to list all isolated articles for a given category for which there
# are translate and linking suggestions exist as interwiki links show.
#
DROP PROCEDURE IF EXISTS isolated_for_category_itsuggestable//
CREATE PROCEDURE isolated_for_category_itsuggestable (cat_given VARCHAR(255), target_lang VARCHAR(16), foreign_lang VARCHAR(16))
  BEGIN
    DECLARE st VARCHAR(511);

    IF foreign_lang=''
      THEN
        SET @st=CONCAT( "SELECT DISTINCT cat, title FROM ", dbname_for_lang( target_lang ), ".categorylinks, ruwiki0, istres WHERE ruwiki0.id=cl_from and cl_to=\"", cat_given, "\" and istres.id=ruwiki0.id ORDER BY title ASC;" );
      ELSE
        SET @st=CONCAT( "SELECT DISTINCT cat, title FROM ", dbname_for_lang( target_lang ), ".categorylinks, ruwiki0, istres WHERE ruwiki0.id=cl_from and cl_to=\"", cat_given, "\" and istres.id=ruwiki0.id and istres.lang=\"", foreign_lang, "\" ORDER BY title ASC;" );
    END IF;
    PREPARE stmt FROM @st;
    EXECUTE stmt;
    DEALLOCATE PREPARE stmt;
  END;
//

DROP PROCEDURE IF EXISTS wikifies_for_category_and_foreign//
CREATE PROCEDURE wikifies_for_category_and_foreign (cat_given VARCHAR(255), target_lang VARCHAR(16), foreign_lang VARCHAR(16), tablename VARCHAR(16), shift INT)
  BEGIN
    DECLARE st VARCHAR(511);

    IF cat_given=''
      THEN
        SET @st=CONCAT( "SELECT suggestn, count(id) as cnt FROM ", tablename, " WHERE ", tablename, ".lang=\"", foreign_lang, "\" GROUP BY suggestn ORDER BY cnt DESC, suggestn ASC LIMIT ", shift, ",100;" );
        PREPARE stmt FROM @st;
        EXECUTE stmt;
        DEALLOCATE PREPARE stmt;
      ELSE

#
# Redirects to be taken into account.
#

#        SET @st=CONCAT( "CREATE TABLE pc(
#                          title VARCHAR(255) binary NOT NULL default '',
#                          PRIMARY KEY (title)
#                      ) ENGINE=MEMORY AS
#                SELECT DISTINCT page_title as title
#                       FROM ", dbname_for_lang( target_lang ), ".categorylinks,
#                            ", dbname_for_lang( target_lang ), ".page
#                       WHERE page_id=cl_from and
#                             cl_to=\"", cat_given, "\";" );

        SET @st=CONCAT( "CREATE TABLE pc( title VARCHAR(255) binary NOT NULL default '', PRIMARY KEY (title) ) ENGINE=MEMORY AS SELECT DISTINCT page_title as title FROM ", dbname_for_lang( target_lang ), ".categorylinks, ", dbname_for_lang( target_lang ), ".page WHERE page_id=cl_from and cl_to=\"", cat_given, "\";" );
        PREPARE stmt FROM @st;
        EXECUTE stmt;
        DEALLOCATE PREPARE stmt;

#        SET @st=CONCAT( "SELECT suggestn,
#                                count(id) as cnt
#                                FROM pc,
#                                     isres
#                                WHERE title=suggestn and
#                                      isres.lang=\"", foreign_lang, "\"
#                                GROUP BY suggestn
#                                ORDER BY cnt DESC,
#                                         suggestn ASC
#                                LIMIT ", shift, ", 100;" );

        SET @st=CONCAT( "SELECT suggestn, count(id) as cnt FROM pc, ", tablename, " WHERE title=suggestn and ", tablename, ".lang=\"", foreign_lang, "\" GROUP BY suggestn ORDER BY cnt DESC, suggestn ASC LIMIT ", shift, ", 100;" );
        PREPARE stmt FROM @st;
        EXECUTE stmt;
        DEALLOCATE PREPARE stmt;
 
        DROP TABLE pc;
    END IF;
  END;
//

#
# This procedure is called directly from link suggestion tool to show
# disambiguation pages lining isolates and articles linking that disambiguation
# pages.
#
DROP PROCEDURE IF EXISTS dsuggest//
CREATE PROCEDURE dsuggest (iid VARCHAR(255), target_lang VARCHAR(16))
  BEGIN
    DECLARE st VARCHAR(511);
    DECLARE done INT DEFAULT 0;
    DECLARE via_title VARCHAR(255);
    DECLARE via_id INT;
    DECLARE cur CURSOR FOR SELECT DISTINCT name, a2i_via FROM isdis, d0site, ruwiki0 WHERE isdis.id=ruwiki0.id AND ruwiki0.title=iid AND d0site.id=a2i_via ORDER BY name ASC;
    DECLARE CONTINUE HANDLER FOR SQLSTATE '02000' SET done = 1;

    OPEN cur;

    REPEAT
      FETCH cur INTO via_title, via_id;
      IF NOT done
        THEN
          SELECT CONCAT( '::', via_title );
          
          SET @st=CONCAT( 'SELECT DISTINCT CONCAT( ', "':::'", ' , page_title ) FROM isdis, ', dbname_for_lang( target_lang ), ".page, ruwiki0 WHERE ruwiki0.title=\"", iid, "\" and isdis.id=ruwiki0.id and a2i_via=", via_id, ' and a2i_from=page_id ORDER BY page_title ASC;' );
          PREPARE stmt FROM @st;
          EXECUTE stmt;
          DEALLOCATE PREPARE stmt;

      END IF;
    UNTIL done END REPEAT;

    CLOSE cur;
  END;
//

#
# Lists disambiguation pages linked from an article given.
#
DROP PROCEDURE IF EXISTS suggestd//
CREATE PROCEDURE suggestd (iid VARCHAR(255), target_lang VARCHAR(16), namespace INT)
  BEGIN
    DECLARE st VARCHAR(255);

    SET @st=CONCAT( 'SELECT DISTINCT name FROM ', dbname_for_lang( target_lang ), ".page, dl", namespace, ", d0site WHERE page_title=\"", iid, "\" AND page_id=dl_from AND d0site.id=dl_to ORDER BY name ASC;" );
    PREPARE stmt FROM @st;
    EXECUTE stmt;
    DEALLOCATE PREPARE stmt;
  END;
//

DROP PROCEDURE IF EXISTS interwiki_suggest//
CREATE PROCEDURE interwiki_suggest (iid VARCHAR(255))
  BEGIN
    DECLARE done INT DEFAULT 0;
    DECLARE language VARCHAR(16);
    DECLARE cur CURSOR FOR SELECT DISTINCT lang FROM isres, ruwiki0 WHERE title=iid AND ruwiki0.id=isres.id ORDER BY lang ASC;
    DECLARE CONTINUE HANDLER FOR SQLSTATE '02000' SET done = 1;

    OPEN cur;

    REPEAT
      FETCH cur INTO language;
      IF NOT done
        THEN
          SELECT CONCAT( '::', language );
          
          SELECT DISTINCT CONCAT( ':::' , suggestn )
                 FROM isres,
                      ruwiki0
                 WHERE title=iid and
                       ruwiki0.id=isres.id and
                       lang=language
                 ORDER BY suggestn ASC;

      END IF;
    UNTIL done END REPEAT;

    CLOSE cur;
  END;
//

DROP PROCEDURE IF EXISTS interwiki_suggest_wikify//
CREATE PROCEDURE interwiki_suggest_wikify (iid VARCHAR(255))
  BEGIN
    DECLARE done INT DEFAULT 0;
    DECLARE ttl VARCHAR(255);
    DECLARE cur CURSOR FOR SELECT DISTINCT title FROM isres, ruwiki0 WHERE suggestn=iid AND ruwiki0.id=isres.id ORDER BY title ASC;
    DECLARE CONTINUE HANDLER FOR SQLSTATE '02000' SET done = 1;

    OPEN cur;

    REPEAT
      FETCH cur INTO ttl;
      IF NOT done
        THEN
          SELECT CONCAT( '::', ttl );
          
          SELECT DISTINCT CONCAT( ':::' , lang )
                 FROM isres,
                      ruwiki0
                 WHERE suggestn=iid and
                       ruwiki0.id=isres.id and
                       title=ttl
                 ORDER BY lang ASC;

      END IF;
    UNTIL done END REPEAT;

    CLOSE cur;
  END;
//

DROP PROCEDURE IF EXISTS interwiki_suggest_translate//
CREATE PROCEDURE interwiki_suggest_translate (iid VARCHAR(255))
  BEGIN
    DECLARE done INT DEFAULT 0;
    DECLARE language VARCHAR(16);
    DECLARE cur CURSOR FOR SELECT DISTINCT lang FROM istres, ruwiki0 WHERE title=iid AND ruwiki0.id=istres.id ORDER BY lang ASC;
    DECLARE CONTINUE HANDLER FOR SQLSTATE '02000' SET done = 1;

    OPEN cur;

    REPEAT
      FETCH cur INTO language;
      IF NOT done
        THEN
          SELECT CONCAT( '::', language );
          
          SELECT DISTINCT CONCAT( ':::' , suggestn )
                 FROM istres,
                      ruwiki0
                 WHERE title=iid and
                       ruwiki0.id=istres.id and
                       lang=language
                 ORDER BY suggestn ASC;

      END IF;
    UNTIL done END REPEAT;

    CLOSE cur;
  END;
//

DROP PROCEDURE IF EXISTS ordered_cat_list//
CREATE PROCEDURE ordered_cat_list (tablename VARCHAR(255), shift INT)
  BEGIN
    DECLARE st VARCHAR(255);

    SET @st=CONCAT( 'SELECT title, ', tablename, '.cnt, 100*', tablename, '.cnt/catvolume0.cnt FROM catvolume0, ', tablename, ', categories WHERE catvolume0.cat=id and ', tablename, '.cat=id ORDER BY ', tablename, '.cnt DESC LIMIT ', shift, ',100;' );
    PREPARE stmt FROM @st;
    EXECUTE stmt;
    DEALLOCATE PREPARE stmt;
  END;
//

DROP PROCEDURE IF EXISTS ordered_cat_list_for_lang//
CREATE PROCEDURE ordered_cat_list_for_lang (tablename VARCHAR(255), foreignlang VARCHAR(16), shift INT)
  BEGIN
    DECLARE st VARCHAR(255);

    SET @st=CONCAT( 'SELECT title, ', tablename, '.a_amnt, 100*', tablename, '.a_amnt/catvolume0.cnt FROM catvolume0, ', tablename, ', categories WHERE catvolume0.cat=id and ', tablename, '.cat=id and ', tablename, '.lang="', foreignlang, '" ORDER BY ', tablename, '.a_amnt DESC LIMIT ', shift, ',100;' );
    PREPARE stmt FROM @st;
    EXECUTE stmt;
    DEALLOCATE PREPARE stmt;
  END;
//

delimiter ;
############################################################

-- </pre>
