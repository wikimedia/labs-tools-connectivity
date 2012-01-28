 --
 -- Authors: [[:ru:user:Mashiah Davidson]]
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

    IF @deadend_category_name!=''
      THEN
        INSERT INTO del (id, act)
        SELECT nrcl_from as id,
               -1 as act
               FROM nrcatl
               WHERE nrcl_cat=nrcatuid(@deadend_category_name);
    END IF;
  END;
//

DROP PROCEDURE IF EXISTS get_link_sources//
CREATE PROCEDURE get_link_sources ()
  BEGIN
#    DECLARE cnt INT DEFAULT '0';
#    DECLARE shift INT DEFAULT '0';
#    DECLARE portion INT DEFAULT '16777216';
#
#    WHILE cnt<@articles_to_articles_links_count DO
#
#      SET @st=CONCAT( 'INSERT /* SLOW_OK */ INTO lwl (lwl_id) SELECT l_from as lwl_id FROM l LIMIT ', shift, ', ', portion, ';' );
#      PREPARE stmt FROM @st;
#      EXECUTE stmt;
#      DEALLOCATE PREPARE stmt;
# 
#      SELECT count(*) INTO cnt
#             FROM lwl;
#
#      SELECT shift+portion INTO shift;
#    END WHILE;

    INSERT /* SLOW_OK */ INTO lwl (lwl_id)
    SELECT l_from as lwl_id
           FROM l;
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
    DECLARE cnt INT DEFAULT '0';
    DECLARE st VARCHAR(255);
    DECLARE res VARCHAR(255);

    SELECT ':: echo DEADLOCKTOR';

    SET @starttime=now();

    IF namespace=0
      THEN
        SELECT count(*) INTO @cnt
               FROM l,
                    chrono
               WHERE l_to=chr_id;

        SELECT cry_for_memory( 54*@cnt ) INTO @res;
        IF @res!=''
          THEN
            SELECT CONCAT( ':: echo ', @res );
        END IF;

        IF SUBSTRING( @res FROM 1 FOR 8 )='... ... '
          THEN
            SELECT ':: echo ... MyISAM engine is chosen for categorizing links table';
            SELECT 'MyISAM' INTO @res;
          ELSE
            SELECT 'MEMORY' INTO @res;
        END IF;

        # List of links from articles to chrono articles
        DROP TABLE IF EXISTS a2cr;
        SET @st=CONCAT( 'CREATE TABLE a2cr ( a2cr_to int(8) unsigned NOT NULL default ', "'0',", ' a2cr_from int(8) unsigned NOT NULL default ', "'0',", ' KEY (a2cr_to) ) ENGINE=', @res, ';' );
        PREPARE stmt FROM @st;
        EXECUTE stmt;
        DEALLOCATE PREPARE stmt;

        INSERT INTO a2cr (a2cr_to, a2cr_from)
        SELECT l_to as a2cr_to,
               l_from as a2cr_from
               FROM l,
                    chrono
               WHERE l_to=chr_id;

        SELECT count(*) INTO @articles_to_chrono_links_count
               FROM a2cr;

        IF @articles_to_chrono_links_count>0
          THEN
            SELECT CONCAT( ':: echo ', @articles_to_chrono_links_count, ' links to be excluded as pointing chrono articles' );
        END IF;
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
      lwl_id int(8) unsigned NOT NULL default '0'
    ) ENGINE=MyISAM;

    # 
    # Note: Has been killed on s1 for table with primary key 
    #       look for distinct values may take long.
    #
    IF namespace=0
      THEN
        IF @articles_to_chrono_links_count>0
          THEN
            ALTER /* SLOW_OK */ TABLE a2cr ADD KEY (a2cr_from);

            INSERT /* SLOW_OK */ INTO lwl (lwl_id)
            SELECT l_from as lwl_id
                   FROM l
                   WHERE NOT EXISTS (
                                      SELECT a2cr_to,
                                             a2cr_from
                                             FROM a2cr
                                             WHERE a2cr_to=l_to and
                                                   a2cr_from=l_from
                                    );
          ELSE
            CALL get_link_sources();
#            INSERT /* SLOW_OK */ INTO lwl (lwl_id)
#            SELECT l_from as lwl_id
#                   FROM l;
        END IF;

        DROP TABLE a2cr;
      ELSE
        CALL get_link_sources();
#        INSERT /* SLOW_OK */ INTO lwl (lwl_id)
#        SELECT l_from as lwl_id
#               FROM l;
    END IF;

    # kill duplicates and make order
    ALTER /* SLOW_OK */ IGNORE TABLE lwl ADD PRIMARY KEY (lwl_id);
    SELECT count(*) INTO @cnt
           FROM lwl;

    IF CAST(@@max_heap_table_size/32 AS UNSIGNED)>@cnt
      THEN
        # make it fast, it is now not that huge
        ALTER /* SLOW_OK */ TABLE lwl ENGINE=MEMORY;
    END IF;

    # CURRENT DEAD-END ARTICLES
    INSERT INTO del (id, act)
    SELECT id,
           1 as act
           FROM articles
           WHERE id NOT IN (
                             SELECT lwl_id
                                    FROM lwl
                           )
    ON DUPLICATE KEY UPDATE act=0;

    DROP TABLE lwl;

    SELECT count(*) INTO @deadend_articles_count
           FROM del
           WHERE act>=0;

    SELECT CONCAT(':: echo total: ', @deadend_articles_count ) as title;

    IF @deadend_articles_count>0
      THEN
        IF namespace=0
          THEN
            SELECT count( * ) INTO cnt
                   FROM del
                   WHERE act=1;
            IF cnt>0
              THEN
                SELECT CONCAT(':: echo +: ', cnt ) as title;

                SELECT CONCAT( ':: out ', @fprefix, 'deset.txt' );
                SET @st=CONCAT( 'SELECT page_title FROM del, ', @dbname, '.page WHERE act=1 AND id=page_id ORDER BY page_title ASC;' );
                PREPARE stmt FROM @st;
                EXECUTE stmt;
                DEALLOCATE PREPARE stmt;
                SELECT ':: sync';
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
            SET @st=CONCAT( 'SELECT CONCAT(getnsprefix(page_namespace,"', @target_lang, '"), page_title) as title FROM del, ', @dbname, '.page WHERE act=-1 AND id=page_id ORDER BY page_title ASC;' );
            PREPARE stmt FROM @st;
            EXECUTE stmt;
            DEALLOCATE PREPARE stmt;
            SELECT ':: sync';
        END IF;
    END IF;

    SELECT CONCAT( ':: echo dead-end processing time: ', TIMEDIFF(now(), @starttime));
  END;
//

delimiter ;
############################################################

-- </pre>
