 --
 -- Authors: [[:ru:user:Mashiah Davidson]], still alone
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
           WHERE domain=CONCAT( language, '.wikipedia.org');

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

    SELECT server into srv
           FROM toolserver.wiki
           WHERE domain=CONCAT( language, '.wikipedia.org');

    SELECT lang INTO res
           FROM toolserver.wiki
           WHERE server=srv and
                 family='wikipedia'
           ORDER BY size DESC
           LIMIT 1;

    RETURN res;
  END;
//

delimiter ;
############################################################

-- </pre>