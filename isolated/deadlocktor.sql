 --
 -- Authors: [[:ru:user:Mashiah Davidson]], still alone
 --
 -- Caution: PROCEDUREs defined here may have output designed for handle.sh.
 --
 -- Shared procedures: deadend
 --
 -- Linking rules: Links to non-articles are not taken into account
 --                (even for links to disambiguations or unexistent articles)
 --
 -- Expected outputs: Deadend articles list, what's to be (un)taged in relation
 --                   to article links existance.
 --
 -- <pre>

 --
 -- Significant speedup
 --

SET SESSION TRANSACTION ISOLATION LEVEL READ UNCOMMITTED;


############################################################
delimiter //

#
# New multilingual way to determine deadend pages already templated/marked.
#
# DEAD-END PAGES REGISTERED AT THE MOMENT
#
DROP PROCEDURE IF EXISTS get_known_deadend//
CREATE PROCEDURE get_known_deadend ()
  BEGIN
    DECLARE st VARCHAR(511);

    #
    # Category name for deadend articles categoryname.
    #
    # Derived from @i18n_page/DeadEndArticles.
    #
    SET @st=CONCAT( 'SELECT DISTINCT pl_title INTO @deadend_category_name FROM ', @target_lang, 'wiki_p.page, ', @target_lang, 'wiki_p.pagelinks WHERE pl_namespace=14 and page_id=pl_from and page_namespace=4 and page_title="', @i18n_page, '/DeadEndArticles" ORDER BY pl_title ASC LIMIT 1;' );
    PREPARE stmt FROM @st;
    EXECUTE stmt;
    DEALLOCATE PREPARE stmt;

    INSERT INTO del
    SELECT nrcl_from as id,
           -1 as act
           FROM nrcatl
           WHERE nrcl_cat=nrcatuid(@deadend_category_name);
  END;
//

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
    DECLARE st VARCHAR(255);

    SELECT ':: echo DEADLOCKTOR';

    SET @starttime=now();

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

        SELECT count(*) INTO @articles_to_chrono_links_count
               FROM a2cr;

        SELECT CONCAT( ':: echo ', @articles_to_chrono_links_count, ' to be excluded as links to chrono articles' );

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

    # DEAD-END PAGES STORAGE
    DROP TABLE IF EXISTS del;
    CREATE TABLE del (
      id int(8) unsigned NOT NULL default '0',
      act int(8) signed NOT NULL default '0',
      PRIMARY KEY (id)
    ) ENGINE=MEMORY;

    IF namespace=0
      THEN
        #
        # DEAD-END PAGES REGISTERED AT THE MOMENT
        #
        CALL get_known_deadend();
    END IF;

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
    SELECT id,
           1 as act
           FROM articles
           WHERE id NOT IN
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
            SELECT del.id,
                   title
                   FROM del,
                        articles
                   WHERE articles.id=del.id and
                         act>=0
                   ORDER BY title ASC;
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
                SELECT title
                       FROM del,
                            articles
                       WHERE act=1 AND
                             del.id=articles.id
                       ORDER BY title ASC;
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

            SET @st=CONCAT( 'SELECT CONCAT(getnsprefix(page_namespace,"', @target_lang, '"), page_title) as title FROM del, ', @target_lang, 'wiki_p.page WHERE act=-1 AND id=page_id ORDER BY page_title ASC;' );
            PREPARE stmt FROM @st;
            EXECUTE stmt;
            DEALLOCATE PREPARE stmt;
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

    SELECT CONCAT( ':: echo dead-end processing time: ', timediff(now(), @starttime));
  END;
//

delimiter ;
############################################################

-- </pre>
