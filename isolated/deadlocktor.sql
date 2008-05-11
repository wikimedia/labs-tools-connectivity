 --
 -- Significant speedup
 --

SET SESSION TRANSACTION ISOLATION LEVEL READ UNCOMMITTED;


############################################################
delimiter //

#
# Collects dead-end articles, i.e. articles having no links to other
# existent articles. Also forms the list of new dead-end articles for
# registration and the list of pages wikified enough to be excluded
# from registered dead-end articles list.
#
DROP PROCEDURE IF EXISTS deadend//
CREATE PROCEDURE deadend (namespace INT)
  BEGIN
    DECLARE cnt INT;

    # temporarily delete links to chrono articles
    IF namespace=0
      THEN
        # List of links from articles to chrono articles
        DROP TABLE IF EXISTS a2cr;
        CREATE TABLE a2cr (
          a2cr_to INT(8) unsigned NOT NULL default '0',
          a2cr_from INT(8) unsigned NOT NULL default '0',
          KEY ( a2cr_to )
        ) ENGINE=MEMORY AS
        SELECT l_to as a2cr_to,
               l_from as a2cr_from
               FROM l
               WHERE l_to IN
                     (
                      SELECT chr_id
                             FROM chrono
                     );

        SELECT CONCAT( ':: echo ', count(*), ' to be excluded as links to chrono articles' )
               FROM a2cr;

        # deletion of links to timelines, recoverable, since we have a2cr
        DELETE FROM l
               WHERE l_to IN
                     (
                      SELECT DISTINCT a2cr_to
                             FROM a2cr
                     );

        SELECT CONCAT( ':: echo ', count(*), ' links after chrono links exclusion' )
               FROM l;

    END IF;

    # Begin the procedure for dead end pages
    SELECT ':: echo dead end pages processing:' as title;

    # DEAD-END PAGES REGISTERED AT THE MOMENT
    DROP TABLE IF EXISTS del;
    CREATE TABLE del (
      id int(8) unsigned NOT NULL default '0',
      act int(8) signed NOT NULL default '0',
      PRIMARY KEY (id)
    ) ENGINE=MEMORY AS
    SELECT nrc_id as id,
           -1 as act
           FROM nrcat
           #            a category registering deadend articles
           WHERE nrc_to='Википедия:Тупиковые_статьи';

    # articles with links to articles
    DROP TABLE IF EXISTS lwl;
    CREATE TABLE lwl (
      lwl_id int(8) unsigned NOT NULL default '0',
      PRIMARY KEY (lwl_id)
    ) ENGINE=MEMORY AS 
    SELECT DISTINCT l_from as lwl_id
           FROM l;

    # CURRENT DEAD-END ARTICLES
    INSERT INTO del
    SELECT a_id as id,
           1 as act
           FROM articles
           WHERE a_id NOT IN
           (
            SELECT lwl_id
                   FROM lwl
           )
    ON DUPLICATE KEY UPDATE act=0;

    DROP TABLE lwl;

    SELECT count(*) INTO cnt
           FROM del
           WHERE act>=0;
    SELECT CONCAT(':: echo total: ', cnt ) as title;

    IF cnt>0
      THEN
        IF @enable_informative_output>0
          THEN
            SELECT CONCAT(':: out ', @fprefix, 'de.info' ) as title;
            SELECT id,
                   a_title
                   FROM del,
                        articles
                   WHERE a_id=id and
                         act>=0
                   ORDER BY a_title ASC;
        END IF;

        IF namespace=0
          THEN
            SELECT count( * ) INTO cnt
                   FROM del
                   WHERE act=1;
            IF cnt>0
              THEN
                SELECT CONCAT(':: echo +: ', cnt ) as title;
                SELECT CONCAT( ':: out ', @fprefix, 'deset.txt' );
                SELECT a_title
                       FROM del,
                            articles
                       WHERE act=1 AND
                             id=a_id
                       ORDER BY a_title ASC;
            END IF;
        END IF;
    END IF;

    IF namespace=0
      THEN
        SELECT count( * ) INTO cnt
               FROM del
               WHERE act=-1;

        IF cnt>0
          THEN
            SELECT CONCAT(':: echo -: ', cnt ) as title;
            SELECT CONCAT( ':: out ', @fprefix, 'derem.txt' );
            SELECT CONCAT(getnsprefix(page_namespace), page_title) as title
                   FROM del,
                        ruwiki_p.page
                   WHERE act=-1 AND
                         id=page_id
                   ORDER BY page_title ASC;
        END IF;

        # Restore previously deleted links to cronological articles
        INSERT INTO l
        SELECT a2cr_to as l_to,
               a2cr_from as l_from
               FROM a2cr;

        DROP TABLE a2cr;

        SELECT CONCAT( ':: echo ', count(*), ' links after chrono links restore' )
               FROM l;
     END IF;
  END;
//

delimiter ;
############################################################

