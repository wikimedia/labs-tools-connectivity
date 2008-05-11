 --
 -- Significant speedup
 --

SET SESSION TRANSACTION ISOLATION LEVEL READ UNCOMMITTED;


############################################################
delimiter //

#
# Outputs non-empty ordered table to stdout.
# Prepends the output with heading info on a rule to invoke in an outer handler.
# Now '''isolated.sh''' is considered as the outer handler for this script.
#
DROP PROCEDURE IF EXISTS outifexists//
CREATE PROCEDURE outifexists ( tablename VARCHAR(255), outt VARCHAR(255), outf VARCHAR(255), ordercol VARCHAR(255), rule VARCHAR(255) )
  BEGIN
    DECLARE cnt INT;
    DECLARE st1 VARCHAR(255);
    DECLARE st2 VARCHAR(255);

    SET @st1=CONCAT( 'SELECT count(*) INTO @cnt FROM ', tablename );
    PREPARE stmt FROM @st1;
    EXECUTE stmt;
    DEALLOCATE PREPARE stmt;

    IF @cnt>0
    THEN
      SELECT CONCAT(':: echo ', outt, ': ', @cnt ) as title;
      SELECT CONCAT(':: ', rule, ' ', @fprefix, outf ) as title;

      SET @st2=CONCAT( 'SELECT * FROM ', tablename, ' ORDER BY ', ordercol, ' ASC' );
      PREPARE stmt FROM @st2;
      EXECUTE stmt;
      DEALLOCATE PREPARE stmt;
    END IF;
  END;
//
      
#
# This function is useful for former articles moved out from zero namespace.
# Returns namespace prefix by its numerical identifier.
#
DROP FUNCTION IF EXISTS getnsprefix//
CREATE FUNCTION getnsprefix ( ns INT )
  RETURNS VARCHAR(255)
  DETERMINISTIC
  BEGIN
    DECLARE wrconstruct VARCHAR(255);

    SELECT ns_name INTO wrconstruct
           FROM toolserver.namespace
           WHERE dbname='ruwiki_p' AND
                 ns_id=ns;

    IF wrconstruct != ''
      THEN
        SET wrconstruct=CONCAT( wrconstruct, ':' );
    END IF;

    RETURN wrconstruct;

  END;
//

#
# Create a task with respect to edits count minimization. Not for AWB,
# but for automated uploader, which is supposed to be implemented.
#
DROP PROCEDURE IF EXISTS combineandout//
CREATE PROCEDURE combineandout ()
  BEGIN
    DECLARE cnt INT;

    #
    # Create common for isolated and deadend analysis list of articles
    # to be edited.
    #
    DROP TABLE IF EXISTS task;
    CREATE TABLE task(
      id int(8) unsigned NOT NULL default '0',
      deact int(8) signed NOT NULL default '0',
      isoact int(8) signed NOT NULL default '0',
      isocat varchar(255) binary NOT NULL default '',
      PRIMARY KEY (id)
    ) ENGINE=MEMORY AS
    #
    # Initialize with isolated articles to be edited.
    #
    SELECT id,
           0 as deact,
           act as isoact,
           coolcat as isocat
           FROM isolated,
                orcat
           WHERE act!=0 and
                 uid=isolated.cat;
    #
    # Add dead-end articles to be edited updating existent rows.
    #
    INSERT INTO task
    SELECT id,
           act as deact,
           0 as isoact,
           '' as isocat
           FROM del
           WHERE act!=0
    ON DUPLICATE KEY UPDATE deact=del.act;

    SELECT count( * ) INTO cnt
           FROM task; 

    IF cnt>0
      THEN
        #
        # Output common task for processing in an outer handler.
        # 
        SELECT CONCAT( ':: echo ', cnt, ' articles to be edited' ) as title;
        SELECT CONCAT( ':: out ', @fprefix, 'task.txt' );
        SELECT CONCAT( getnsprefix(page_namespace), page_title ) as title,
               deact,
               isoact,
               isocat
               FROM task,
                    ruwiki_p.page
               WHERE id=page_id
               ORDER BY deact+deact+isoact DESC, page_title ASC;
    END IF;

    DROP TABLE task;
  END;
//

delimiter ;
############################################################

