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
                 domain=CONCAT(language,'.wikipedia.org') and
                 is_closed=0;

    RETURN srv;
  END;
//

DROP FUNCTION IF EXISTS largest_neighbour//
CREATE FUNCTION largest_neighbour ( language VARCHAR(64) )
  RETURNS VARCHAR(64)
  DETERMINISTIC
  BEGIN
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
    DECLARE res VARCHAR(64);

    SELECT dbname INTO res
           FROM toolserver.wiki
           WHERE family='wikipedia' and
                 is_closed=0 and
                 domain=CONCAT(language,'.wikipedia.org')
           LIMIT 1;

    RETURN res;
  END;
//

DROP FUNCTION IF EXISTS host_for_lang//
CREATE FUNCTION host_for_lang ( language VARCHAR(64) )
  RETURNS VARCHAR(255)
  DETERMINISTIC
  BEGIN
    DECLARE res VARCHAR(64);

    SELECT host_name INTO res
           FROM toolserver.wiki,
                u_mashiah_golem_p.server
           WHERE family='wikipedia' and
                 is_closed=0 and
                 domain=CONCAT(language,'.wikipedia.org') and
                 server=sv_id
           LIMIT 1;

    RETURN res;
  END;
//

DROP FUNCTION IF EXISTS host_for_srv//
CREATE FUNCTION host_for_srv ( srv INT )
  RETURNS VARCHAR(255)
  DETERMINISTIC
  BEGIN
    DECLARE res VARCHAR(64);

    SELECT host_name INTO res
           FROM u_mashiah_golem_p.server
           WHERE sv_id=srv
           LIMIT 1;

    RETURN res;
  END;
//

DROP PROCEDURE IF EXISTS project_for_everywhere//
CREATE PROCEDURE project_for_everywhere ( )
  BEGIN
    DECLARE done INT DEFAULT 0;
    DECLARE ready INT DEFAULT 0;
    DECLARE cur_sv INT DEFAULT 0;
    DECLARE srvlist VARCHAR(20);
    DECLARE scur CURSOR FOR SELECT DISTINCT server FROM toolserver.wiki WHERE family='wikipedia' and is_closed=0 ORDER BY server ASC;
    DECLARE CONTINUE HANDLER FOR SQLSTATE '02000' SET done = 1;

    SET srvlist = '';

    OPEN scur;
    SET done = 0;

    REPEAT
      FETCH scur INTO cur_sv;
      IF NOT done
        THEN
          #
          # Collect subject of interest server list
          #
          SET srvlist=CONCAT( srvlist, ' ', cur_sv );
      END IF;
    UNTIL done END REPEAT;

    CLOSE scur;

    SELECT CONCAT( ':: introduce', srvlist );
  END;
//

DROP PROCEDURE IF EXISTS emit_for_everywhere//
CREATE PROCEDURE emit_for_everywhere ( language VARCHAR(64), usr VARCHAR(64) )
  BEGIN
    DECLARE done INT DEFAULT 0;
    DECLARE ready INT DEFAULT 0;
    DECLARE cur_sv INT DEFAULT 0;
    DECLARE cur_host VARCHAR(255) DEFAULT '';
    DECLARE st VARCHAR(511);
    DECLARE scur CURSOR FOR SELECT host_name, MIN(server) as sv FROM toolserver.wiki, u_mashiah_golem_p.server WHERE family='wikipedia' and is_closed=0 and sv_id=server and host_name!=host_for_lang(language) GROUP BY host_name ORDER BY sv ASC;
    DECLARE CONTINUE HANDLER FOR SQLSTATE '02000' SET done = 1;

    CALL replag( language );

    OPEN scur;
    SET done = 0;

    REPEAT
      FETCH scur INTO cur_host, cur_sv;
      IF NOT done
        THEN
          #
          # Outside handler to distribute good news among sql hosts.
          #
          SELECT CONCAT( ':: s', cur_sv, ' emit ', @rep_time );
      END IF;
    UNTIL done END REPEAT;

    CLOSE scur;

    #
    # Current host log is updated with no call to the outside handler.
    #
    SET @st=CONCAT( 'INSERT INTO u_', usr, '_golem_p.language_stats SELECT "', language, '" as lang, "', @rep_time, '" as ts ON DUPLICATE KEY UPDATE ts="', @rep_time, '";' );
    PREPARE stmt FROM @st;
    EXECUTE stmt;
    DEALLOCATE PREPARE stmt;
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
