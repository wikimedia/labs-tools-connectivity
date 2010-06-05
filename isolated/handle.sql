 --
 -- Authors: [[:ru:user:Mashiah Davidson]]
 --
 -- Caution: PROCEDUREs defined here may have output designed for handle.sh.
 --
 -- Shared procedures: outifexists
 --                    combineandout
 --
 -- <pre>

 --
 -- Initialize an unique prefix for use as a filename prefix
 --

set @fprefix='';

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

      #
      # Note: no way to prepend rows with a namespace prefix here
      #
      SET @st2=CONCAT( 'SELECT * FROM ', tablename, ' ORDER BY ', ordercol, ' ASC' );
      PREPARE stmt FROM @st2;
      EXECUTE stmt;
      DEALLOCATE PREPARE stmt;
    END IF;
  END;
//
      
DROP PROCEDURE IF EXISTS outcolifexists//
CREATE PROCEDURE outcolifexists ( tablename VARCHAR(255), outt VARCHAR(255), outf VARCHAR(255), outcol VARCHAR(255), ordercol VARCHAR(255), rule VARCHAR(255) )
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

      #
      # Note: no way to prepend rows with a namespace prefix here
      #
      SET @st2=CONCAT( 'SELECT ', outcol, ' FROM ', tablename, ' ORDER BY ', ordercol, ' ASC' );
      PREPARE stmt FROM @st2;
      EXECUTE stmt;
      DEALLOCATE PREPARE stmt;
    END IF;
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
    DECLARE st VARCHAR(255);

    SELECT ':: echo COMBINATOR';

    SET @starttime=now();

    #
    # Create common for isolated and deadend analysis list of articles
    # to be edited.
    #
    DROP TABLE IF EXISTS task;
    CREATE TABLE task(
      id int(8) unsigned NOT NULL default '0',
      ncaact int(8) signed NOT NULL default '0',
      deact int(8) signed NOT NULL default '0',
      isoact int(8) signed NOT NULL default '0',
      isocat varchar(255) binary NOT NULL default '',
      importance int(8) unsigned NOT NULL default '0',
      PRIMARY KEY (id)
    ) ENGINE=MEMORY;

    SELECT max(length(ns_name)) INTO @cnt
           FROM toolserver.namespace
           WHERE dbname=@dbname;

    IF @cnt>0
      THEN
        SET @st=CONCAT( 'ALTER TABLE task ADD COLUMN title VARCHAR( ', 256+@cnt, ' ) binary NOT NULL default ', "''", ';' );
        PREPARE stmt FROM @st;
        EXECUTE stmt;
        DEALLOCATE PREPARE stmt;

      ELSE
        ALTER TABLE task 
              ADD COLUMN title VARCHAR(511) binary NOT NULL default '';
    END IF;

    #
    # Initialize with isolated articles to be edited.
    #
    INSERT INTO task
    SELECT id,
           0 as ncaact,
           0 as deact,
           act as isoact,
           coolcat as isocat,
           '' as title,
           0 as importance
           FROM isolated,
                orcat
           WHERE act!=0 and
                 uid=isolated.cat
    #
    # Hard to imagine a situation when duplicates may occur here,
    # however, it has been met once; thus better to have it double checked.
    #
    ON DUPLICATE KEY UPDATE isoact=isolated.act, isocat=orcat.coolcat;

    #
    # Add dead-end articles to be edited updating existent rows.
    #
    INSERT INTO task
    SELECT id,
           0 as ncaact,
           act as deact,
           0 as isoact,
           '' as isocat,
           '' as title,
           0 as importance
           FROM del
           WHERE act!=0
    ON DUPLICATE KEY UPDATE deact=del.act;

    #
    # Add non-categorized articles to be edited updating existent rows.
    #
    INSERT INTO task
    SELECT nc_id,
           act as ncaact,
           0 as deact,
           0 as isoact,
           '' as isocat,
           '' as title,
           0 as importance
           FROM nocat
           WHERE act!=0
    ON DUPLICATE KEY UPDATE ncaact=nocat.act;

    SELECT count( * ) INTO cnt
           FROM task; 

    IF cnt>0
      THEN
        #
        # This request doesn't insert anything, it does update on this
        # strange manner. The reason is that <dbname>.page is not granted
        # to users for update.
        #
        # Preparing the updated table with title and importance columns set
        # I hope I prevent outer handler to be waiting for data in the next
        # query performing ':: out'.
        #
        SET @st=CONCAT( 'INSERT INTO task SELECT id, ncaact, deact, isoact, isocat, CONCAT( getnsprefix(page_namespace,"', @target_lang, '"), page_title ) as title, 0 as importance FROM task, ', @dbname, '.page WHERE id=page_id ON DUPLICATE KEY UPDATE title=CONCAT( getnsprefix(page_namespace,"', @target_lang, '"), page_title ), importance=values(ncaact)+values(deact)+values(deact)+values(isoact);' );
        PREPARE stmt FROM @st;
        EXECUTE stmt;
        DEALLOCATE PREPARE stmt;

        #
        # To the moment some of the pages theoretically could be permanently
        # dropped from the database. No need to consider any actions to them.
        #
        DELETE FROM task
               WHERE title='';

        #
        # Final ':: out' speedup. Let it be sorting smoothly.
        #
        ALTER TABLE task ADD KEY (importance, title);

        #
        # Output common task for processing in an outer handler.
        # 
        SELECT CONCAT( ':: echo ', cnt, ' articles to be edited' ) as title;
        SELECT CONCAT( ':: out ', @fprefix, 'task.txt' );

        SELECT title,
               ncaact,
               deact,
               isoact,
               isocat
               FROM task
               ORDER BY importance DESC,
                        title ASC;
    END IF;

    DROP TABLE task;

    SELECT CONCAT( ':: echo nocat, isolated & deadend combining time: ', timediff(now(), @starttime));
  END;
//

delimiter ;
############################################################

-- </pre>
