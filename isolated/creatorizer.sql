 --
 -- Authors: [[:ru:user:Mashiah Davidson]], still alone
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
DROP PROCEDURE IF EXISTS by_creators//
CREATE PROCEDURE by_creators ()
  BEGIN
    # for a set given by ruwiki0.id's look for initial revisions
    DROP TABLE IF EXISTS firstrev;
    CREATE TABLE firstrev (
      title varchar(255) binary NOT NULL default '',
      garbage int(8) unsigned NOT NULL default '0',
      revision int(8) unsigned NOT NULL default '0',
      PRIMARY KEY (revision)
    ) ENGINE=MEMORY AS
    SELECT title,
           rev_page as garbage,
           min(rev_id) as revision
           FROM ruwiki_p.revision,
                ruwiki0
           WHERE rev_page=id
           GROUP BY rev_page;

    SELECT CONCAT( ':: echo ', count(*), ' initial revisions for isolates found' )
           FROM firstrev;

    # now extract username (and usertext)
    # Note: it can be done within the previous query, unfortunately
    #       containing some extra data (not yet used anywhere)
    DROP TABLE IF EXISTS creators;
    CREATE TABLE creators (
      title varchar(255) binary NOT NULL default '',
      user int(8) unsigned NOT NULL default '0',
      user_text varchar(255) binary NOT NULL default ''
    ) ENGINE=MEMORY AS
    SELECT title,
           rev_user as user,
           rev_user_text as user_text
           FROM ruwiki_p.revision,
                firstrev
           WHERE revision=rev_id;

    DROP TABLE firstrev;

    SELECT CONCAT( ':: echo ', count(DISTINCT user, user_text), ' isolated articles creators found' )
           FROM creators;
  END;
//

DROP PROCEDURE IF EXISTS creatorizer//
CREATE PROCEDURE creatorizer ()
  BEGIN
    #
    # For use in "ISOLATED ARTICLES CREATORS".
    #
    # Note: postponed as low priority task.
    CALL by_creators();

    # creatorizer refresh
    DROP TABLE IF EXISTS creators0;
    RENAME TABLE creators TO creators0;
    CALL actuality( 'creatorizer' );
  END;
//

delimiter ;
############################################################

-- </pre>
