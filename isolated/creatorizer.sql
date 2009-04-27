 --
 -- Authors: [[:ru:user:Mashiah Davidson]], still alone
 --
 -- Caution: PROCEDUREs defined here may have output designed for handle.sh.
 -- 
 -- Shared procedures: creatorizer
 --
 -- <pre>

 --
 -- Significant speedup
 --

SET SESSION TRANSACTION ISOLATION LEVEL READ UNCOMMITTED;


############################################################
delimiter //

#
# For use in "ISOLATED ARTICLES CREATORS".
#
DROP PROCEDURE IF EXISTS creatorizer//
CREATE PROCEDURE creatorizer ()
  BEGIN
    DECLARE st VARCHAR(511);

    SELECT ':: echo CREATORIZER';

    #
    # For a set given by ruwiki0.id's look for initial revisions
    #
    DROP TABLE IF EXISTS firstrev;
    SET @st=CONCAT( 'CREATE TABLE firstrev ( title varchar(255) binary NOT NULL default ', "''", ', garbage int(8) unsigned NOT NULL default ', "'0'", ', revision int(8) unsigned NOT NULL default ', "'0'", ', PRIMARY KEY (revision) ) ENGINE=MEMORY AS SELECT title, rev_page as garbage, min(rev_id) as revision FROM ', @target_lang, 'wiki_p.revision, ruwiki0 WHERE rev_page=id GROUP BY rev_page;' );
    PREPARE stmt FROM @st;
    EXECUTE stmt;
    DEALLOCATE PREPARE stmt;

    SELECT CONCAT( ':: echo ', count(*), ' initial revisions for isolates found' )
           FROM firstrev;

    # now extract username (and usertext)
    # Note: it can be done within the previous query, unfortunately
    #       containing some extra data (not yet used anywhere)
    DROP TABLE IF EXISTS creators;
    SET @st=CONCAT( 'CREATE TABLE creators ( title varchar(255) binary NOT NULL default ', "''", ', user int(8) unsigned NOT NULL default ', "'0'", ', user_text varchar(255) binary NOT NULL default ', "''", ' ) ENGINE=MyISAM AS SELECT title, rev_user as user, rev_user_text as user_text FROM ', @target_lang, 'wiki_p.revision, firstrev WHERE revision=rev_id;' );
    PREPARE stmt FROM @st;
    EXECUTE stmt;
    DEALLOCATE PREPARE stmt;

    DROP TABLE firstrev;

    # creatorizer refresh
    DROP TABLE IF EXISTS creators0;
    RENAME TABLE creators TO creators0;
    CALL actuality( 'creatorizer' );

    SELECT CONCAT( ':: echo ', count(DISTINCT user, user_text), ' isolated articles creators found' )
           FROM creators0;
  END;
//

delimiter ;
############################################################

-- </pre>
