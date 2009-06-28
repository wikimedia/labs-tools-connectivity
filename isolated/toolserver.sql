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

delimiter ;
############################################################

-- </pre>
