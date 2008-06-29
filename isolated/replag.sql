 --
 -- Authors: [[:ru:user:Mashiah Davidson]], still alone
 --
 -- Caution: PROCEDUREs defined here may have output designed for handle.sh.
 -- 
 -- Shared procedures: replag
 --                    actual_replag
 --                    pretend
 --                    performed_confirmatin
 --                    actuality
 --
 -- <pre>

 --
 -- Significant speedup
 --

SET SESSION TRANSACTION ISOLATION LEVEL READ UNCOMMITTED;


############################################################
delimiter //

#
# Replication timestamp and replication lag for ruwiki (yet).
#
DROP PROCEDURE IF EXISTS replag//
CREATE PROCEDURE replag ()
  BEGIN
    # ruwiki is placed on s3 and the largest wiki on s3 is frwiki
    # when the last edit there happen?
    SELECT max( rc_timestamp ) INTO @rep_time
           FROM frwiki_p.recentchanges;

    SELECT CONCAT( ':: echo last replicated timestamp: ', @rep_time );

    # store run time value for referencing
    SELECT now() INTO @run_time;

    # how old the latest edit there is?
    SELECT CONCAT( ':: replag ', timediff(@run_time, @rep_time)) as title;
  END;
//

#
# Runs replag and copies its measurements into @rep_act and @run_act
# for use in pretend() and actuality()
#
DROP PROCEDURE IF EXISTS actual_replag//
CREATE PROCEDURE actual_replag ()
  BEGIN
    CALL replag();
    SET @rep_act=@rep_time;
    SET @run_act=@run_time;
  END;
//

#
# Permanent storage for inter-run timing data.
#
# Pretends to renew timestamp for an action given
# stores last successfull something time as well as
# current time to pretnd to renew.
#
DROP PROCEDURE IF EXISTS pretend//
CREATE PROCEDURE pretend ( action VARCHAR(255) )
  BEGIN
    DECLARE st VARCHAR(255);

    # permanent storage for inter-run data created here if not exists
    SET @st=CONCAT( 'CREATE TABLE IF NOT EXISTS ', action, ' ( ts TIMESTAMP(14) NOT NULL, valid int(8) unsigned NOT NULL default ', "'0'", ' ) ENGINE=MyISAM;' );
    PREPARE stmt FROM @st;
    EXECUTE stmt;
    DEALLOCATE PREPARE stmt;

    # no need to keep old data, especially when stats hasn't been uploaded
    SET @st=CONCAT( 'DELETE FROM ', action, ' WHERE valid=0;' );
    PREPARE stmt FROM @st;
    EXECUTE stmt;
    DEALLOCATE PREPARE stmt;

    # just in case of stats uploaded during this run
    SET @st=CONCAT( 'INSERT INTO ', action, ' SELECT "', @rep_act, '" as ts, 0 as valid;' );
    PREPARE stmt FROM @st;
    EXECUTE stmt;
    DEALLOCATE PREPARE stmt;
  END;
//

# 
# Run trough handle sh 'server done' command
# when an action someone pretended to in the past is for sure happend.
#
DROP PROCEDURE IF EXISTS performed_confirmation//
CREATE PROCEDURE performed_confirmation ( action VARCHAR(255) )
  BEGIN
    DECLARE st VARCHAR(255);

    # Note: Crazy mysql updates timestamp value with current timestamp,
    #       that's why need to add stupid things like ts=ts.
    SET @st=CONCAT( 'UPDATE ', action, ' SET valid=1-valid, ts=ts;' );
    PREPARE stmt FROM @st;
    EXECUTE stmt;
    DEALLOCATE PREPARE stmt;

    # no need to keep old data cause the action has performed
    SET @st=CONCAT( 'DELETE FROM ', action, ' WHERE valid=0;' );
    PREPARE stmt FROM @st;
    EXECUTE stmt;
    DEALLOCATE PREPARE stmt;

    SET @st=CONCAT( 'SELECT CONCAT( ', "':: echo action ", action, " is performed, replication timestamp is '", ', ts ) FROM ', action, ' WHERE valid=1;' );
    PREPARE stmt FROM @st;
    EXECUTE stmt;
    DEALLOCATE PREPARE stmt;
  END;
//

#
# Permanent storage for information on actuality.
#
DROP PROCEDURE IF EXISTS actuality//
CREATE PROCEDURE actuality ( action VARCHAR(255) )
  BEGIN
    DECLARE st VARCHAR(255);

    # permanent storage for inter-run data created here if not exists
    SET @st=CONCAT( 'CREATE TABLE IF NOT EXISTS ', action, ' ( rep TIMESTAMP(14) NOT NULL, run TIMESTAMP(14) NOT NULL, actual TIMESTAMP(14) NOT NULL ) ENGINE=MyISAM;' );
    PREPARE stmt FROM @st;
    EXECUTE stmt;
    DEALLOCATE PREPARE stmt;

    # no need to keep old data because the action has performed
    SET @st=CONCAT( 'DELETE FROM ', action, ';' );
    PREPARE stmt FROM @st;
    EXECUTE stmt;
    DEALLOCATE PREPARE stmt;

    # just in case of stats uploaded during this run
    SET @st=CONCAT( 'INSERT INTO ', action, ' SELECT "', @rep_act, '" as rep, "', @run_act, '" as run, "', now(), '" as actual;' );
    PREPARE stmt FROM @st;
    EXECUTE stmt;
    DEALLOCATE PREPARE stmt;
  END;
//

delimiter ;
############################################################

-- </pre>
