 --
 -- Authors: [[:ru:user:Mashiah Davidson]],
 --          [[:ru:user:VasilievVV]] aka vvv
 --
 -- Caution: PROCEDUREs defined here may have output designed for handle.sh.
 -- 
 -- Shared procedures: server
 --
 -- <pre>

 --
 -- Significant speedup
 --

SET SESSION TRANSACTION ISOLATION LEVEL READ UNCOMMITTED;


############################################################
delimiter //

#
# Replication timestamp and replication lag for a language given.
#
DROP FUNCTION IF EXISTS server_num//
CREATE FUNCTION server_num ( language VARCHAR(64) )
  RETURNS INT
  DETERMINISTIC
  BEGIN
    DECLARE srv INT;

    #
    # Extracts sql server name suffux for the language given
    #
    SELECT server INTO srv
           FROM toolserver.wiki
           WHERE family='wikipedia' and
                 lang=language and
                 is_closed=0;

    RETURN srv;
  END;
//

DROP FUNCTION IF EXISTS largest_neighbour//
CREATE FUNCTION largest_neighbour ( language VARCHAR(64) )
  RETURNS VARCHAR(64)
  DETERMINISTIC
  BEGIN
    DECLARE srv INT;
    DECLARE res VARCHAR(64);

    SELECT dbname INTO res
           FROM toolserver.wiki
           WHERE server=server_num( language ) and
                 family='wikipedia' and
                 #
                 # just in case, who knows...
                 #
                 is_closed=0
           ORDER BY size DESC
           LIMIT 1;

    RETURN res;
  END;
//

DROP FUNCTION IF EXISTS dbname_for_lang//
CREATE FUNCTION dbname_for_lang ( language VARCHAR(64) )
  RETURNS VARCHAR(64)
  DETERMINISTIC
  BEGIN
    DECLARE srv INT;
    DECLARE res VARCHAR(64);

    SELECT dbname INTO res
           FROM toolserver.wiki
           WHERE family='wikipedia' and
                 is_closed=0 and
                 lang=language
           LIMIT 1;

    RETURN res;
  END;
//

DROP PROCEDURE IF EXISTS project_for_everywhere//
CREATE PROCEDURE project_for_everywhere ( srv INT, language VARCHAR(64) )
  BEGIN
    DECLARE done INT DEFAULT 0;
    DECLARE ready INT DEFAULT 0;
    DECLARE cur_sv INT DEFAULT 0;
    DECLARE st VARCHAR(511);
    DECLARE scur CURSOR FOR SELECT DISTINCT server FROM toolserver.wiki WHERE family='wikipedia' and is_closed=0 ORDER BY server ASC;
    DECLARE CONTINUE HANDLER FOR SQLSTATE '02000' SET done = 1;

    OPEN scur;
    SET done = 0;

    REPEAT
      FETCH scur INTO cur_sv;
      IF NOT done
        THEN
          #
          # Outside handler to distribute good news between sql servers
          #
          # Notes: Better if distributed over db-servers, which sometimes
          #        handle more than one sql server and share content.
          #
          #        Better if current server was not handled from outside.
          #
          SELECT CONCAT( ':: s', cur_sv, ' proj' );
          # hope this reduces the density of sql connection requests,
          # which is limited
          SELECT sleep( 1 ) INTO ready;
      END IF;
    UNTIL done END REPEAT;

    CLOSE scur;
  END;
//

DROP PROCEDURE IF EXISTS emit_for_everywhere//
CREATE PROCEDURE emit_for_everywhere ( srv INT, language VARCHAR(64) )
  BEGIN
    DECLARE done INT DEFAULT 0;
    DECLARE ready INT DEFAULT 0;
    DECLARE cur_sv INT DEFAULT 0;
    DECLARE st VARCHAR(511);
    DECLARE scur CURSOR FOR SELECT DISTINCT server FROM toolserver.wiki WHERE family='wikipedia' and is_closed=0 ORDER BY server ASC;
    DECLARE CONTINUE HANDLER FOR SQLSTATE '02000' SET done = 1;

    CALL replag( language );

    OPEN scur;
    SET done = 0;

    REPEAT
      FETCH scur INTO cur_sv;
      IF NOT done
        THEN
          #
          # Outside handler to distribute good news between sql servers
          #
          # Notes: Better if distributed over db-servers, which sometimes
          #        handle more than one sql server and share content.
          #
          #        Better if current server was not handled from outside.
          #
          SELECT CONCAT( ':: s', cur_sv, ' emit ', @rep_time );
          # hope this reduces the density of sql connection requests,
          # which is limited
          SELECT sleep( 1 ) INTO ready;
      END IF;
    UNTIL done END REPEAT;

    CLOSE scur;
  END;
//

#
# This function is useful for former articles moved out from zero namespace.
# Returns namespace prefix by its numerical identifier.
#
DROP FUNCTION IF EXISTS getnsprefix//
CREATE FUNCTION getnsprefix ( ns INT, targetlang VARCHAR(32) )
  RETURNS VARCHAR(255)
  DETERMINISTIC
  BEGIN
    DECLARE wrconstruct VARCHAR(255);

    SELECT ns_name INTO wrconstruct
           FROM toolserver.namespace
           WHERE dbname=dbname_for_lang(targetlang) and
                 ns_id=ns;

    IF wrconstruct != ''
      THEN
        SET wrconstruct=CONCAT( wrconstruct, ':' );
    END IF;

    RETURN wrconstruct;

  END;
//

delimiter ;
############################################################

-- </pre>
