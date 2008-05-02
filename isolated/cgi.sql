
 --
 -- Significant speedup
 --

SET SESSION TRANSACTION ISOLATION LEVEL READ UNCOMMITTED;


############################################################
delimiter //

#
# This procedure is called directly from link suggestion tool to show
# disambiguation pages lining isolates and articles linking that disambiguation
# pages.
#
DROP PROCEDURE IF EXISTS dsuggest//
CREATE PROCEDURE dsuggest (iid VARCHAR(255))
  BEGIN
    DECLARE done INT DEFAULT 0;
    DECLARE via_title VARCHAR(255);
    DECLARE via_id INT;
    DECLARE cur CURSOR FOR SELECT DISTINCT page_title, a2i_via FROM isdis, ruwiki_p.page WHERE a2i_to=iid AND page_id=a2i_via ORDER BY page_title ASC;
    DECLARE CONTINUE HANDLER FOR SQLSTATE '02000' SET done = 1;

    OPEN cur;

    REPEAT
      FETCH cur INTO via_title, via_id;
      IF NOT done
        THEN
          SELECT CONCAT( '::', via_title );
          
          SELECT DISTINCT CONCAT( ':::' , page_title )
                 FROM isdis,
                      ruwiki_p.page
                 WHERE a2i_to=iid and
                       a2i_via=via_id and
                       a2i_from=page_id
                 ORDER BY page_title ASC;

      END IF;
    UNTIL done END REPEAT;

    CLOSE cur;
  END;
//

DROP PROCEDURE IF EXISTS interwiki_suggest//
CREATE PROCEDURE interwiki_suggest (iid VARCHAR(255))
  BEGIN
    DECLARE done INT DEFAULT 0;
    DECLARE language VARCHAR(10);
    DECLARE cur CURSOR FOR SELECT DISTINCT lang FROM isres, ruwiki0 WHERE title=iid AND id=isolated ORDER BY lang ASC;
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
                       id=isolated and
                       lang=language
                 ORDER BY suggestn ASC;

      END IF;
    UNTIL done END REPEAT;

    CLOSE cur;
  END;
//

DROP PROCEDURE IF EXISTS interwiki_suggest_translate//
CREATE PROCEDURE interwiki_suggest_translate (iid VARCHAR(255))
  BEGIN
    DECLARE done INT DEFAULT 0;
    DECLARE language VARCHAR(10);
    DECLARE cur CURSOR FOR SELECT DISTINCT lang FROM istres, ruwiki0 WHERE title=iid AND id=isolated ORDER BY lang ASC;
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
                       id=isolated and
                       lang=language
                 ORDER BY suggestn ASC;

      END IF;
    UNTIL done END REPEAT;

    CLOSE cur;
  END;
//

delimiter ;
############################################################
