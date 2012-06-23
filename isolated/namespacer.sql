 --
 -- Authors: [[:ru:user:Mashiah Davidson]]
 --
 -- Caution: PROCEDUREs defined here may have output designed for handle.sh.
 -- 
 -- Shared procedures: cache_namespace_pages
 --                    zero_namespace_connectivity
 --                    zero_namespace_postponed_tools
 --                    categorytree_connectivity
 --
 -- What is an article: Originally, the {{comment|Main|
 --                                               zero}} namespace has been
 --                                               itroduced for articles. 
 --                     Actually it does also contain redirect pages,
 --                     disambiguation pages, colloborative article lists,
 --                     soft redirects and sometimes
 --                     templates (which is wrong on my own opinion, but used).
 -- <pre>

############################################################
delimiter //

#
# Caches the pages for a namespace given to local tables 
#   p<namespace>  (for all pages, just for namespace 10),
#   nr<namespace> (for non-redirects)
#   r<namespace>  (for redirects)
# for speedup
#
DROP PROCEDURE IF EXISTS cache_namespace_pages//
CREATE PROCEDURE cache_namespace_pages (namespace INT)
  BEGIN
    DECLARE st VARCHAR(511);
    DECLARE cnt INT;
    DECLARE res VARCHAR(255) DEFAULT '';
    DECLARE eng VARCHAR(7) DEFAULT '';

    #
    # Non-redirects
    #
    SELECT 'MEMORY' INTO @nr_eng;

    #
    # SELECT count(*) INTO @cnt
    #        FROM <dbname>.page
    #        WHERE page_namespace=<namespace> and
    #              page_is_redirect=0;
    #
    SET @st=CONCAT( 'SELECT count(*) INTO @cnt FROM ', @dbname, '.page WHERE page_namespace=', namespace, ' and page_is_redirect=0;' );
    PREPARE stmt FROM @st;
    EXECUTE stmt;
    DEALLOCATE PREPARE stmt;

    DROP TABLE IF EXISTS nr;
    IF @cnt=0
      THEN
        CREATE TABLE nr (
          id int(8) unsigned NOT NULL default '0',
          title varchar(255) binary NOT NULL default '',
          PRIMARY KEY (id)
        ) ENGINE=MEMORY;
        SET @nr_len=255;
      ELSE
        #
        # SELECT MAX(LENGTH(page_title)) INTO @nr_len
        #        FROM <dbname>.page
        #        WHERE page_namespace=<namespace> and
        #              page_is_redirect=0;
        #
        SET @st=CONCAT( 'SELECT MAX(LENGTH(page_title)) INTO @nr_len FROM ', @dbname, '.page WHERE page_namespace=', namespace, ' and page_is_redirect=0;' );
        PREPARE stmt FROM @st;
        EXECUTE stmt;
        DEALLOCATE PREPARE stmt;

        SELECT cry_for_memory( (@nr_len+72)*@cnt ) INTO @res;
        IF @res!=''
          THEN
            SELECT CONCAT( ':: echo ', @res );
            IF SUBSTRING( @res FROM 1 FOR 8 )='... ... '
              THEN
                SELECT 'MyISAM' INTO @nr_eng;
            END IF;
        END IF;

        #
        # CREATE TABLE nr (
        #   id int(8) unsigned NOT NULL default '0',
        #   title varchar(<nr_len>) binary NOT NULL default '',
        #   PRIMARY KEY (id)
        # ) ENGINE=<nr_eng>;
        #
        SET @st=CONCAT( 'CREATE TABLE nr ( id int(8) unsigned NOT NULL default ', "'0'", ', title varchar(', @nr_len, ') binary NOT NULL default ', "''", ', PRIMARY KEY (id) ) ENGINE=', @nr_eng, ';' );
        PREPARE stmt FROM @st;
        EXECUTE stmt;
        DEALLOCATE PREPARE stmt;

        #
        # INSERT INTO nr (id, title)
        # SELECT page_id as id,
        #        page_title as title
        #        FROM <dbname>.page
        #        WHERE page_namespace=<namespace> and
        #              page_is_redirect=0;
        #
        SET @st=CONCAT( 'INSERT INTO nr (id, title) SELECT page_id as id, page_title as title FROM ', @dbname, '.page WHERE page_namespace=', namespace, ' and page_is_redirect=0;' );
        PREPARE stmt FROM @st;
        EXECUTE stmt;
        DEALLOCATE PREPARE stmt;
    END IF;

    SELECT CONCAT( ':: echo . non-redirects: ', count(*), ' (', @nr_eng, ' table)' )
           FROM nr;

    #
    # Redirect pages
    #
    SELECT 'MEMORY' INTO @eng;

    #
    # SELECT count(*) INTO @redirects_count
    #        FROM <dbname>.page
    #        WHERE page_namespace=<namespace> and
    #              page_is_redirect=1;
    #
    SET @st=CONCAT( 'SELECT count(*) INTO @redirects_count FROM ', @dbname, '.page WHERE page_namespace=', namespace, ' and page_is_redirect=1;' );
    PREPARE stmt FROM @st;
    EXECUTE stmt;
    DEALLOCATE PREPARE stmt;

    DROP TABLE IF EXISTS r;
    IF @redirects_count=0
      THEN
        CREATE TABLE r (
          r_id int(8) unsigned NOT NULL default '0',
          r_title varchar(255) binary NOT NULL default '',
          PRIMARY KEY rid (r_id)
        ) ENGINE=MEMORY;
        SET @r_len=255;
      ELSE
        #
        # SELECT MAX(LENGTH(page_title)) INTO @r_len
        #        FROM <dbname>.page
        #        WHERE page_namespace=<namespace> and
        #              page_is_redirect=1;
        #
        SET @st=CONCAT( 'SELECT MAX(LENGTH(page_title)) INTO @r_len FROM ', @dbname, '.page WHERE page_namespace=', namespace, ' and page_is_redirect=1;' );
        PREPARE stmt FROM @st;
        EXECUTE stmt;
        DEALLOCATE PREPARE stmt;

        SELECT cry_for_memory( (@r_len+72)*@redirects_count ) INTO @res;
        IF @res!=''
          THEN
            SELECT CONCAT( ':: echo ', @res );
            IF SUBSTRING( @res FROM 1 FOR 8 )='... ... '
              THEN
                SELECT 'MyISAM' INTO @eng;
            END IF;
        END IF;

        #
        # CREATE TABLE r (
        #   r_id int(8) unsigned NOT NULL default '0',
        #   r_title varchar(<r_len>) binary NOT NULL default '',
        #   PRIMARY KEY rid (r_id)
        # ) ENGINE=<eng>;
        #
        SET @st=CONCAT( 'CREATE TABLE r ( r_id int(8) unsigned NOT NULL default ', "'0'", ', r_title varchar(', @r_len, ') binary NOT NULL default ', "''", ', PRIMARY KEY rid (r_id) ) ENGINE=', @eng, ';' );
        PREPARE stmt FROM @st;
        EXECUTE stmt;
        DEALLOCATE PREPARE stmt;

        #
        # INSERT INTO r (r_id, r_title)
        # SELECT page_id as r_id,
        #        page_title as r_title
        #        FROM <dbname>.page
        #        WHERE page_namespace=<namespace> and
        #              page_is_redirect=1;
        #
        SET @st=CONCAT( 'INSERT INTO r (r_id, r_title) SELECT page_id as r_id, page_title as r_title FROM ', @dbname, '.page WHERE page_namespace=', namespace, ' and page_is_redirect=1;' );
        PREPARE stmt FROM @st;
        EXECUTE stmt;
        DEALLOCATE PREPARE stmt;
    END IF;

    SELECT CONCAT( ':: echo . redirect pages: ', count(*), ' (', @eng, ' table)' )
           FROM r;

    SET @st=CONCAT( 'DROP TABLE IF EXISTS nr', namespace, ';' );
    PREPARE stmt FROM @st;
    EXECUTE stmt;
    DEALLOCATE PREPARE stmt;
    SET @st=CONCAT( 'RENAME TABLE nr TO nr', namespace, ';' );
    PREPARE stmt FROM @st;
    EXECUTE stmt;
    DEALLOCATE PREPARE stmt;

    SET @st=CONCAT( 'DROP TABLE IF EXISTS r', namespace, ';' );
    PREPARE stmt FROM @st;
    EXECUTE stmt;
    DEALLOCATE PREPARE stmt;
    SET @st=CONCAT( 'RENAME TABLE r TO r', namespace, ';' );
    PREPARE stmt FROM @st;
    EXECUTE stmt;
    DEALLOCATE PREPARE stmt;

    IF namespace=10
      THEN
        ALTER TABLE r10 ADD UNIQUE KEY rtitle (r_title);
    END IF;

  END;
//

#
# Categorized non-articles are given for each project by page named
#    @i18n_page/CategorizedNonArticles
# in fourth namespace.
#
DROP PROCEDURE IF EXISTS get_categorized_non_articles//
CREATE PROCEDURE get_categorized_non_articles (namespace INT)
  BEGIN
    DECLARE st VARCHAR(511);

    DROP TABLE IF EXISTS cllt;
    CREATE TABLE cllt (
      cllt_id int(8) unsigned NOT NULL default '0',
      PRIMARY KEY  (cllt_id)
    ) ENGINE=MEMORY;

    #
    # INSERT INTO cllt (cllt_id)
    # SELECT DISTINCT cl_from as cllt_id
    #        FROM <dbname>.page,
    #             <dbname>.pagelinks,
    #             <dbname>.categorylinks
    #        WHERE pl_title=cl_to and
    #              pl_namespace=14 and
    #              page_id=pl_from and
    #              page_namespace=4 and
    #              page_title="<i18n_page>/CategorizedNonArticles";
    #
    SET @st=CONCAT( 'INSERT INTO cllt (cllt_id) SELECT DISTINCT cl_from as cllt_id FROM ', @dbname, '.page, ', @dbname, '.pagelinks, ', @dbname, '.categorylinks WHERE pl_title=cl_to and pl_namespace=14 and page_id=pl_from and page_namespace=4 and page_title="', @i18n_page, '/CategorizedNonArticles";' );
    PREPARE stmt FROM @st;
    EXECUTE stmt;
    DEALLOCATE PREPARE stmt;

    SET @st=CONCAT( 'DELETE FROM cllt WHERE cllt_id not in (select id from nr', namespace, ');' );
    PREPARE stmt FROM @st;
    EXECUTE stmt;
    DEALLOCATE PREPARE stmt;

    SELECT count(*) INTO @collaborative_lists_count
           FROM cllt;

    SELECT CONCAT( ':: echo ', @collaborative_lists_count, ' categorized non-articles found for namespace ', namespace );
  END;
//

#
# Chrono articles are defined by a set of links to category pages from
# page named
#    @i18n_page/ArticlesNotFormingValidLinks
# in fourth namespace.
#
# See also: another version of this function commented out below.
#
DROP PROCEDURE IF EXISTS get_chrono//
CREATE PROCEDURE get_chrono ()
  BEGIN
    DECLARE st VARCHAR(511);

    DROP TABLE IF EXISTS chrono;
    CREATE TABLE chrono (
      chr_id int(8) unsigned NOT NULL default '0',
      PRIMARY KEY  (chr_id)
    ) ENGINE=MEMORY;

    SET @st=CONCAT( 'INSERT INTO chrono (chr_id) SELECT DISTINCT cl_from as chr_id FROM ', @dbname, '.page, ', @dbname, '.pagelinks, ', @dbname, '.categorylinks WHERE pl_title=cl_to and pl_namespace=14 and page_id=pl_from and page_namespace=4 and page_title="', @i18n_page, '/ArticlesNotFormingValidLinks";' );
    PREPARE stmt FROM @st;
    EXECUTE stmt;
    DEALLOCATE PREPARE stmt;

    #
    # Just in case, good to cleanup non-articles from the set.
    #
    DELETE FROM chrono
           WHERE chr_id NOT IN 
                 (
                   SELECT id
                          FROM articles
                 );

    SELECT count(*) INTO @chrono_articles_count
           FROM chrono;

    SELECT CONCAT( ':: echo ', @chrono_articles_count, ' chronological articles found' );

    DROP TABLE IF EXISTS noncr;
    SET @st=CONCAT( 'CREATE TABLE noncr (noncr_id int(8) unsigned NOT NULL default "0", PRIMARY KEY (noncr_id)) ENGINE=', @articles_eng, ';' );
    PREPARE stmt FROM @st;
    EXECUTE stmt;
    DEALLOCATE PREPARE stmt;

    INSERT INTO noncr (noncr_id)
    SELECT id as noncr_id
           FROM articles
           WHERE id NOT IN
                 (
                   SELECT chr_id
                          FROM chrono
                 );

    SELECT CONCAT( ':: echo ', count(*), ' non-chronological articles as the result' )
           FROM noncr;
  END;
//

#
# Constructs nrcatl, the categorizing links for the namespace given.
# Derermines several classes for non-redirects such as 
#   articles (for articles)
#   d (for disambiguation pages)
#   cllt (for colloborative lists of article links)
#   chrono (for chronological timelines, which are articles)
#
# Substitutes maxsize parameter by actual articles count when maxsize=0.
#
DROP PROCEDURE IF EXISTS classify_namespace//
CREATE PROCEDURE classify_namespace (IN namespace INT, IN targetset VARCHAR(255), INOUT maxsize INT)
  BEGIN
    DECLARE st VARCHAR(255);
    DECLARE main_page VARCHAR(255);
    DECLARE r_flag INT;
    DECLARE main_page_id INT;
    DECLARE mp_ns INT;
    DECLARE acnt VARCHAR(255);
    DECLARE res VARCHAR(255) DEFAULT '';

    CALL categorylinks( namespace );

    #
    # In order to exclude disambiguations from target set,
    # disambiguation pages are being collected here into d table.
    #
    DROP TABLE IF EXISTS d;
    CREATE TABLE d (
      d_id int(8) unsigned NOT NULL default '0',
      PRIMARY KEY (d_id)
    ) ENGINE=MEMORY;

    CALL collect_disambig( @dbname, namespace, ':: echo ' );
    #
    # One more call to another version of this function allows some languages
    # controlling difference between disambiguation category content and
    # templated content.
    #

    #
    # Actual list of categories identifying non-articles may vary with
    # the project language.
    #
    CALL get_categorized_non_articles( namespace );

    #
    # Categorized or templated non-articles.
    #
    # With namespace=14 is not used because of the nature of links and pages.
    #
    DROP TABLE IF EXISTS cna;
    CREATE TABLE cna (
      cna_id int(8) unsigned NOT NULL default '0',
      PRIMARY KEY (cna_id)
    ) ENGINE=MEMORY;
 
    #
    # Categorization does not allow category namespace pages to be of
    # different types, as well as they all work as regular categories.
    #
    IF namespace!=14
      THEN
        IF namespace=0
          THEN
            SET @main_page='Main_Page';
            SET @mp_ns=0;

            SET @st=CONCAT( 'SELECT page_is_redirect, page_id INTO @r_flag, @main_page_id FROM ', @dbname, '.page WHERE page_namespace=0 AND page_title="', @main_page, '";' );
            PREPARE stmt FROM @st;
            EXECUTE stmt;
            DEALLOCATE PREPARE stmt;

            WHILE @r_flag!=0 DO
              #
              # Note: This supposes the redirects chain from 'Main_Page' to
              #       real main page doesn't include any wrong redirects!
              #
              SET @st=CONCAT( 'SELECT pl_title, pl_namespace INTO @main_page, @mp_ns FROM ', @dbname,'.pagelinks WHERE pl_from=', @main_page_id, ' LIMIT 1;' );
              PREPARE stmt FROM @st;
              EXECUTE stmt;
              DEALLOCATE PREPARE stmt;
          
              IF @mp_ns=0
                THEN
                  SET @st=CONCAT( 'SELECT page_is_redirect, page_id INTO @r_flag, @main_page_id FROM ', @dbname,'.page WHERE page_namespace=0 AND page_title="', @main_page, '";' );
                  PREPARE stmt FROM @st;
                  EXECUTE stmt;
                  DEALLOCATE PREPARE stmt;
                  IF @main_page_id IS NULL
                    THEN
                      SET @mp_ns=NULL;
                      SET @r_flag=0;
                  END IF;
                ELSE
                  SET @r_flag=0;
              END IF;
            END WHILE;

            IF @mp_ns=0
              THEN
                INSERT INTO cna (cna_id)
                SELECT @main_page_id as cna_id;

                SELECT CONCAT( ':: echo main page found for zero namespace' );
              ELSE
                IF @main_page_id IS NULL
                  THEN
                    SELECT CONCAT( ':: echo main page is not linked via "Main_Page" redirect, so it is not found' );
                  ELSE
                    SELECT CONCAT( ':: echo main page is out of zero namespace' );
                END IF;
            END IF;

        END IF;

        #
        # Add disambiguations to cna.
        #
        INSERT INTO cna (cna_id)
        SELECT d_id as cna_id
               FROM d
        #
        # Just in case the main page is marked as disambig,
        # which sounds strange.
        #
        ON DUPLICATE KEY UPDATE cna_id=d_id;

        #
        # Add collaborative lists to cna.
        #
        INSERT INTO cna (cna_id)
        SELECT cllt_id as cna_id
               FROM cllt
        #
        # Disambiguation pages may sometimes be collaborative lists at the
        # same time. Icon at the top right looks nice in this case =)
        #
        ON DUPLICATE KEY UPDATE cna_id=cllt_id;

        SELECT CONCAT( ':: echo ', count(*), ' categorized or templated exclusion names found' )
               FROM cna;
    END IF;
    DROP TABLE cllt;

    SELECT 'MEMORY' INTO @articles_eng;

    IF namespace!=10
      THEN
        SET @st=CONCAT( 'SELECT count(distinct id) INTO @acnt FROM nr', namespace, ' WHERE id NOT IN ( SELECT DISTINCT cna_id FROM cna );' );
        PREPARE stmt FROM @st;
        EXECUTE stmt;
        DEALLOCATE PREPARE stmt;

        SELECT 'MEMORY' INTO @articles_eng;

        SELECT cry_for_memory( 32*@acnt ) INTO @res;
        IF @res!=''
          THEN
            SELECT CONCAT( ':: echo ', @res );
            IF SUBSTRING( @res FROM 1 FOR 8 )='... ... '
              THEN
                SELECT CONCAT( ':: echo ... MyISAM engine is chosen for ', targetset, ' table' );
                SELECT 'MyISAM' INTO @articles_eng;
            END IF;
        END IF;

        DROP TABLE IF EXISTS articles;
        SET @st=CONCAT( 'CREATE TABLE articles ( id int(8) unsigned NOT NULL default ', "'0'", ', PRIMARY KEY (id) ) ENGINE=', @articles_eng, ';' );
        PREPARE stmt FROM @st;
        EXECUTE stmt;
        DEALLOCATE PREPARE stmt;

        SET @st=CONCAT( 'INSERT INTO articles (id) SELECT id FROM nr', namespace, ' WHERE id NOT IN ( SELECT DISTINCT cna_id FROM cna );' );
        PREPARE stmt FROM @st;
        EXECUTE stmt;
        DEALLOCATE PREPARE stmt;
      ELSE
        # Articles (i.e. non-redirects and non-disambigs for current namespace)
        DROP TABLE IF EXISTS articles;
        CREATE TABLE articles (
          id int(8) unsigned NOT NULL default '0',
          PRIMARY KEY (id)
        ) ENGINE=MEMORY;

        ALTER TABLE articles ADD COLUMN title varchar(255) binary NOT NULL default '';
        ALTER TABLE articles ADD UNIQUE KEY title (title);

        SET @st=CONCAT( 'INSERT INTO articles (id, title) SELECT id, title FROM nr', namespace, ' WHERE id NOT IN ( SELECT DISTINCT cna_id FROM cna );' );
        PREPARE stmt FROM @st;
        EXECUTE stmt;
        DEALLOCATE PREPARE stmt;
    END IF;

    SELECT count(*) INTO @articles_count
           FROM articles;

    SELECT CONCAT( ':: echo ', @articles_count, ' ', targetset, ' found' );

    # No restriction on maximal scc size does not mean infinite
    # computational resources, but it is known for sure that maximal
    # scc size does not exceed the amount of elements in the set.
    IF maxsize=0
      THEN
        SET maxsize=@articles_count;
    END IF;

    IF namespace=0
      THEN
        CALL get_chrono();

        #
        # cna now collects all pages not forming valid links.
        #
        # Note: Articles are being merged to non-articles,
        #       thus key violations impossible.
        #
        INSERT INTO cna (cna_id)
        SELECT chr_id as cna_id
               FROM chrono;

        SELECT CONCAT( ':: echo ', count(*), ' pages not forming valid links' )
               FROM cna;

        #
        # Articles with no visible categories.
        #
        CALL notcategorized();
      ELSE
        IF namespace=10
          THEN
            DROP TABLE IF EXISTS cna10;
            RENAME TABLE cna TO cna10;
          ELSE
            DROP TABLE cna;
        END IF;
    END IF;

  END;
//

#
# Caches the page links for a namespace given to table pl for speedup
#
DROP PROCEDURE IF EXISTS cache_namespace_links//
CREATE PROCEDURE cache_namespace_links (namespace INT)
  BEGIN
    DECLARE st VARCHAR(511);

    SET @starttime1=now();

    DROP TABLE IF EXISTS pl;
    CREATE TABLE pl (
      pl_from int(8) unsigned NOT NULL default '0',
      pl_to int(8) unsigned NOT NULL default '0'
    ) ENGINE=MyISAM;

    #
    # Cahing page links to the given namespace for speedup.
    #
    # Notes: 1) Links to existent pages cached only, i.e. no "red links".
    #        2) One of the key points here is that we didn't try
    #           saving pl_title, the table this way might be too huge.
    #        3) Thanks to Magnus Manske for query optimization.
    #
    # INSERT /* SLOW_OK */ INTO pl
    # SELECT pl_from, 
    #        page_id AS pl_to 
    #        FROM <dbname>.page,
    #             <dbname>.pagelinks
    #        WHERE pl_title=page_title and
    #              page_namespace=namespace and
    #              pl_namespace=namespace;
    #
    SET @st=CONCAT( 'INSERT /* SLOW_OK */ INTO pl SELECT pl_from, page_id AS pl_to FROM ', @dbname, '.page, ', @dbname, '.pagelinks WHERE pl_title=page_title and page_namespace=', namespace, ' and pl_namespace=', namespace, ';' );
    PREPARE stmt FROM @st;
    EXECUTE stmt;
    DEALLOCATE PREPARE stmt;

    SELECT count(*) INTO @pl_count
           FROM pl;

    SELECT @pl_count INTO @base_pl_count;

    SELECT CONCAT( ':: echo ', @pl_count, ' links point namespace ', namespace );

    SELECT CONCAT( ':: echo links to namespace ', namespace, ' caching time: ', TIMEDIFF(now(), @starttime1));

    IF namespace=0
      THEN
        #
        # Note: The list of links occured in articles due to templates used,
        #       most likely can not be constructed, therefore the variable
        #       tested here is never initialized.
        #
        IF @massive_lists_recognition_alive!=''
          THEN
            CALL recognizable_template_links();
        END IF;

        IF @template_documentation_subpage_name!=''
          THEN
            #
            # All links from regular templates to zero namespace pages.
            #
            DROP TABLE IF EXISTS t2p;
            CREATE TABLE t2p ( 
              t2p_from int(8) unsigned NOT NULL default '0',
              t2p_to int(8) unsigned NOT NULL default '0',
              KEY (t2p_from),
              KEY (t2p_to)
            ) ENGINE=MEMORY AS /* SLOW_OK */ 
            SELECT pl_from as t2p_from,
                   pl_to as t2p_to
                   FROM pl
                   WHERE pl_from IN (
                                      SELECT id
                                             FROM regular_templates
                                    );

            SELECT CONCAT( ':: echo ', count(*), ' links from templating pages to existent main namespace pages' )
                   FROM t2p;
        END IF;
    END IF;
  END;
//

#
# Creates a bridge between categorizing links format and pagelinks format,
# i.e. reverses links and renames columns.
#
DROP PROCEDURE IF EXISTS categorybridge//
CREATE PROCEDURE categorybridge ()
  BEGIN
    #
    # Generally speaking, 
    # if we reverse categories categorizing links we will not lose them.
    # Some columns renaming is required.
    #
    ALTER TABLE nrcatl CHANGE COLUMN nrcl_from pl_to int(8) unsigned NOT NULL default '0';
    ALTER TABLE nrcatl CHANGE COLUMN nrcl_cat pl_from int(8) unsigned NOT NULL default '0';
    DROP TABLE IF EXISTS pl;
    RENAME TABLE nrcatl TO pl;

    SELECT count(*) INTO @pl_count
           FROM pl;

    SELECT @pl_count INTO @base_pl_count;

    SELECT CONCAT( ':: echo ', @pl_count, ' links for categorytree' );
  END;
//


DROP PROCEDURE IF EXISTS pl_by_parts//
CREATE PROCEDURE pl_by_parts (IN plcount INT, IN shift INT, IN extst1 VARCHAR(255), IN extst2 VARCHAR(255))
  BEGIN
    DECLARE st VARCHAR(255);
    DECLARE my_plcount INT;
    DECLARE portion INT;
    DECLARE iteration INT DEFAULT '0';

    SELECT CAST(@@max_heap_table_size/32 AS UNSIGNED) INTO portion;

    SELECT plcount INTO my_plcount;

    WHILE my_plcount>0 DO

      IF portion > my_plcount
        THEN
          SELECT my_plcount INTO portion;
      END IF;

      DROP /* SLOW_OK */ TABLE IF EXISTS part_pl;
      CREATE TABLE part_pl (
        dst int(8) unsigned NOT NULL default '0',
        src int(8) unsigned NOT NULL default '0'
      ) ENGINE=MEMORY;

      #
      # INSERT INTO part_pl /* SLOW_OK */ (dst,src)
      # SELECT pl_to as dst,
      #        pl_from as src
      #        FROM pl
      #        LIMIT <shift>,<portion>;
      #
      SET @st=CONCAT( 'INSERT INTO part_pl /* SLOW_OK */ (dst,src) SELECT pl_to as dst, pl_from as src FROM pl LIMIT ', shift, ',', portion, ';' );
      PREPARE stmt FROM @st;
      EXECUTE stmt;
      DEALLOCATE PREPARE stmt;

      #
      # External statements execution.
      #
      SELECT extst1 INTO @st;
      PREPARE stmt FROM @st;
      EXECUTE stmt;
      DEALLOCATE PREPARE stmt;

      SELECT extst2 INTO @st;
      IF @st!=''
        THEN
          PREPARE stmt FROM @st;
          EXECUTE stmt;
          DEALLOCATE PREPARE stmt;
      END IF;

      SELECT CONCAT( ':: echo . iteration ', iteration );

      DROP /* SLOW_OK */ TABLE part_pl;

      SELECT my_plcount-portion INTO my_plcount;
      SELECT shift+portion INTO shift;
      SELECT iteration+1 INTO iteration;

    END WHILE;
  END;
//


#
# Inputs: r<ns>, nr<ns>, pl, articles, d.
#
# Main output for connectivity analysis - table l
# (links from articles to articles).
#
# Side output: wr<ns>, r<ns> filtered, r2nr, mr output into a file
#
DROP PROCEDURE IF EXISTS throwNhull4subsets//
CREATE PROCEDURE throwNhull4subsets (IN namespace INT, IN targetset VARCHAR(255))
  BEGIN
    DECLARE res VARCHAR(255) DEFAULT '';
    DECLARE est VARCHAR(255) DEFAULT '';
    DECLARE est2 VARCHAR(255) DEFAULT '';

    # collects wrong redirects and excludes them from r<ns>
    CALL cleanup_wrong_redirects( namespace );

    # throws redirect chains and adds paths to pl
    CALL throw_multiple_redirects( namespace );

    #
    # Experimental data: one row of l takes near to 52 bytes on 64-bit system
    # after indexing.
    #
    SELECT cry_for_memory( 54*@pl_count ) INTO @res;
    IF @res!=''
      THEN
        SELECT CONCAT( ':: echo ', @res );
    END IF;

    # Table l is created here for all links, which are to be taken into account.
    DROP TABLE IF EXISTS l;
    IF SUBSTRING( @res FROM 1 FOR 8 )='... ... '
      THEN
        SELECT ':: echo ... MyISAM engine is chosen for article links table';

        CREATE TABLE l (
          l_to int(8) unsigned NOT NULL default '0',
          l_from int(8) unsigned NOT NULL default '0',
          PRIMARY KEY (l_to,l_from)
        ) ENGINE=MyISAM;
      ELSE
        CREATE TABLE l (
          l_to int(8) unsigned NOT NULL default '0',
          l_from int(8) unsigned NOT NULL default '0',
          PRIMARY KEY (l_to,l_from)
        ) ENGINE=MEMORY;
    END IF;

    #
    # Before any analysis we need to identify all the valid links
    # between articles. Here the links table l is constructed as containing
    #  - direct links from article to article
    #  - links from article to article via a redirect from the namespace given
    #  - links from article to article via a long (double, triple, etc) redirect
    #

    SET @starttime1=now();

    #
    # Here we can construct links from articles to articles.
    #
    # INSERT IGNORE INTO l /* SLOW_OK */ (l_to, l_from)
    # SELECT id as l_to,
    #        src as l_from
    #        FROM part_pl,
    #             articles
    #        WHERE src in
    #              (
    #               SELECT id 
    #                      FROM articles
    #              ) and
    #              dst=id and
    #              src!=id
    #        ORDER BY id ASC, src ASC;
    SET @est='INSERT IGNORE INTO l /* SLOW_OK */ (l_to, l_from) SELECT id as l_to, src as l_from FROM part_pl, articles WHERE src in ( SELECT id FROM articles ) and dst=id and src!=id ORDER BY id ASC, src ASC;';

    SELECT ':: echo starting l iterations for redirected links';

    #
    # For dead-end pages recognition
    #
    DROP TABLE IF EXISTS lwl;
    SET @st=CONCAT( 'CREATE TABLE lwl (lwl_id int(8) unsigned NOT NULL default "0", PRIMARY KEY (lwl_id)) ENGINE=', @articles_eng, ';' );
    PREPARE stmt FROM @st;
    EXECUTE stmt;
    DEALLOCATE PREPARE stmt;

    #
    # Here we can construct the list of non-dead-end articles.
    #
    # INSERT IGNORE INTO lwl /* SLOW_OK */ (lwl_id)
    # SELECT src as lwl_id
    #        FROM part_pl,
    #             < noncr | articles >
    #        WHERE src in
    #              (
    #               SELECT id 
    #                      FROM articles
    #              ) and
    #              dst=[noncr_]id and
    #              src!=[noncr_]id
    #        ORDER BY src ASC;
    IF namespace=0
      THEN
        SET @est2='INSERT IGNORE INTO lwl /* SLOW_OK */ (lwl_id) SELECT src as lwl_id FROM part_pl, noncr WHERE src in ( SELECT id FROM articles ) and dst=noncr_id and src!=noncr_id ORDER BY src ASC;';
      ELSE
        SET @est2='INSERT IGNORE INTO lwl /* SLOW_OK */ (lwl_id) SELECT src as lwl_id FROM part_pl, articles WHERE src in ( SELECT id FROM articles ) and dst=id and src!=id ORDER BY src ASC;';
    END IF;

    IF @pl_count > @base_pl_count
    THEN
      #
      # Note: Rest of pl contains non ordered links added during redicrect
      #       chains rectification. On the other hand they consitute
      #       a minor portion in the overal set.
      #
      #       Adding those link in the order leads to rundom insertion into a
      #       huge table for final iterations moving big amount of data.
      #
      #       In order to avoid such long running queries it is worse to add
      #       non ordered data first and then always move something,
      #       but not that much.
      #
    CALL pl_by_parts( @pl_count-@base_pl_count, @base_pl_count, @est, @est2 );
    END IF;

    SELECT ':: echo starting l iterations for direct links';

    #
    # Processing lower well-ordered part.
    #
    CALL pl_by_parts( @base_pl_count, 0, @est, @est2 );

    DROP TABLE IF EXISTS noncr;

    SELECT count(*) INTO @articles_to_articles_links_count
           FROM l;

    SELECT CONCAT( ':: echo ', @articles_to_articles_links_count, ' unique links from ', targetset, ' to ', targetset );

    SELECT CONCAT( ':: echo ', count(*), ' non-dead-end pages found among ', targetset )
           FROM lwl;

    SELECT CONCAT( ':: echo links from ', targetset, ' to ', targetset, ' caching time: ', TIMEDIFF(now(), @starttime1));
  END;
//

#
# Project root toolserver page provides several figures characterizing
# the namespace. Here those figures are being stored to tables.
#
DROP PROCEDURE IF EXISTS store_paraphrases//
CREATE PROCEDURE store_paraphrases ()
  BEGIN
    DECLARE art_lnks_per_ch INT DEFAULT '0';
    DECLARE other_lnks_per_other INT DEFAULT (@articles_to_articles_links_count-@chrono_to_articles_links_count)/(@articles_count-@chrono_articles_count);

    DECLARE ch_links_prc REAL(5,3) DEFAULT @articles_to_chrono_links_count*100/@articles_to_articles_links_count;
    DECLARE ch_lnks_per_ch INT DEFAULT '0';

    IF @chrono_articles_count!=0
      THEN
        SET art_lnks_per_ch=@chrono_to_articles_links_count/@chrono_articles_count;
        SET ch_lnks_per_ch=@articles_to_chrono_links_count/@chrono_articles_count;
    END IF;

    #
    # ZNS, zero namespace stat
    #

    # permanent storage for inter-run data created here if not exists
    CREATE TABLE IF NOT EXISTS zns (
      articles INT(8) unsigned NOT NULL default '0',
      chrono INT(8) unsigned NOT NULL default '0',
      disambig INT(8) unsigned NOT NULL default '0',
      cllt INT(8) unsigned NOT NULL default '0'
    ) ENGINE=MyISAM;

    # no need to keep old data because the action has performed
    DELETE FROM zns;

    # just in case of stats uploaded during this run
    INSERT INTO zns (articles, chrono, disambig, cllt)
    VALUES ( @articles_count, @chrono_articles_count, @disambiguation_pages_count, @collaborative_lists_count );

    #
    # FCH, from chrono articles
    #

    # permanent storage for inter-run data created here if not exists
    CREATE TABLE IF NOT EXISTS fch (
      clinks INT(8) unsigned NOT NULL default '0',
      alinks INT(8) unsigned NOT NULL default '0'
    ) ENGINE=MyISAM;

    # no need to keep old data because the action has performed
    DELETE FROM fch;

    # just in case of stats uploaded during this run
    INSERT INTO fch (clinks, alinks)
    VALUES ( art_lnks_per_ch, other_lnks_per_other );

    #
    # TCH, to chrono articles
    #

    # permanent storage for inter-run data created here if not exists
    CREATE TABLE IF NOT EXISTS tch (
      clratio REAL(5,3) NOT NULL default '0',
      linksc INT(8) unsigned NOT NULL default '0'
    ) ENGINE=MyISAM;

    # no need to keep old data because the action has performed
    DELETE FROM tch;

    # just in case of stats uploaded during this run
    INSERT INTO tch (clratio, linksc)
    VALUES ( ch_links_prc, ch_lnks_per_ch );

    # permanent storage for inter-run data created here if not exists
    CREATE TABLE IF NOT EXISTS inda (
      isolated INT(8) unsigned NOT NULL default '0',
      isotypes INT(8) unsigned NOT NULL default '0',
      deadend INT(8) unsigned NOT NULL default '0'
    ) ENGINE=MyISAM;

    DELETE FROM inda;

    INSERT INTO inda (isolated, isotypes, deadend)
    VALUES ( @isolated_articles_count, @isolated_articles_types_count, @deadend_articles_count );
  END;
//

#
# Do all the templates namespace connectivity analysis assuming maxsize as
# maximal possible cluster size, zero means no limit.
#
DROP PROCEDURE IF EXISTS collect_template_pages//
CREATE PROCEDURE collect_template_pages ( maxsize INT )
  BEGIN
    DECLARE st VARCHAR(255);
    DECLARE templator_needed INT DEFAULT '0';
    DECLARE res VARCHAR(255) DEFAULT '';

    #
    # Lost hope
    #
    IF @massive_links_recognition_alive IS NULL
      THEN
        SET @massive_links_recognition_alive='';
    END IF;

    IF @massive_links_recognition_alive!=''
      THEN
        SET @templator_needed=1;
    END IF;
    IF @template_documentation_subpage_name!=''
      THEN
        SET @templator_needed=1;
    END IF;

    IF @disambiguations_look_recognized=0
      THEN
        SET @templator_needed=0;
    END IF;

    IF @templator_needed=1
      THEN
        SELECT ':: echo TEMPLATE PAGES';

        # the name-prefix for all output files, distinct for each function call
        SET @fprefix=CONCAT( CAST( NOW() + 0 AS UNSIGNED ), '.' );

        # pre-loads r10 and nr10 tables for fast access
        CALL cache_namespace_pages( 10 );

        CALL classify_namespace( 10, 'templates', maxsize );

        #
        # For pl - namespace links cached in memory
        #
        CALL cache_namespace_links( 10 );

        CALL throwNhull4subsets( 10, 'templates' );

        DROP TABLE IF EXISTS regular_templates;
        ALTER TABLE articles ENGINE=MyISAM;
        RENAME TABLE articles TO regular_templates;

        # partial namespacer unload
        DROP TABLE nr10;

        #
        # nr2r10 will be very helpfull for redirects seaming
        #
        CALL redirector_unload( 10 );

        #
        # Note: This count is just for a memory cry, and it looks too expencive for this minor purpose,
        #       MyISAM engine pre-set might be a good compromize.
        #       Does it help by caching templatelinks table for future use in ti construction?
        #
        SET @st=CONCAT( 'SELECT /* SLOW_OK */ count(*) INTO @tl_count FROM ', @dbname, '.templatelinks;' );
        PREPARE stmt FROM @st;
        EXECUTE stmt;
        DEALLOCATE PREPARE stmt;

        SET @st=CONCAT( 'SELECT cry_for_memory( ', 32*@tl_count, ' ) INTO @res;' );
        PREPARE stmt FROM @st;
        EXECUTE stmt;
        DEALLOCATE PREPARE stmt;
        IF @res!=''
          THEN
            SELECT CONCAT( ':: echo ', @res );
        END IF;

        #
        # Templating links storage.
        #
        # Notes: Lots of templates are not used in articles directly and came 
        #        with templating, so should be excluded.
        #
        #        Links to non-existent templates are not there.
        #
        DROP TABLE IF EXISTS ti;
        IF SUBSTRING( @res FROM 1 FOR 8 )='... ... '
          THEN
            SELECT ':: echo ... MyISAM engine is chosen for templating links table';

            CREATE TABLE ti (
              ti_from int(8) unsigned NOT NULL default '0',
              ti_to int(8) unsigned NOT NULL default '0'
            ) ENGINE=MyISAM;
          ELSE
            CREATE TABLE ti (
              ti_from int(8) unsigned NOT NULL default '0',
              ti_to int(8) unsigned NOT NULL default '0'
            ) ENGINE=MEMORY;
        END IF;

        #
        # INSERT /* SLOW_OK */ INTO ti
        # SELECT tl_from as ti_from,
        #        page_id AS ti_to
        #        FROM <dbname>.page,
        #             <dbname>.templatelinks
        #        WHERE tl_title=page_title and
        #              page_namespace=10 and
        #              tl_namespace=10;
        #
        SET @st=CONCAT( 'INSERT /* SLOW_OK */ INTO ti SELECT tl_from as ti_from, page_id AS ti_to FROM ', @dbname, '.page, ', @dbname, '.templatelinks WHERE tl_title=page_title and page_namespace=10 and tl_namespace=10;' );
        PREPARE stmt FROM @st;
        EXECUTE stmt;
        DEALLOCATE PREPARE stmt;

        SELECT CONCAT( ':: echo ', count(*), ' template occurrences found' )
               FROM ti;

        ALTER TABLE ti ADD KEY (ti_from);

        #
        # Templates categorization links could be useful, so it can be enabled here.
        #
        # categorizer: bless nrcatl, sorry for naming...
        # DROP TABLE IF EXISTS nrcatl10;
        # RENAME TABLE nrcatl TO nrcatl10;
        #
        # Currently disabled.
        #
        DROP TABLE nrcatl;

        IF @template_documentation_subpage_name=''
          THEN
            DROP TABLE r2nr10;
            DROP TABLE r10;
        END IF;
      ELSE
        SELECT ':: echo TEMPLATOR IS NOT REQUIRED';
    END IF;
  END;
//


#
# Do all the zero namespace connectivity analysis assuming maxsize as
# maximal possible cluster size, zero means no limit.
#
DROP PROCEDURE IF EXISTS zero_namespace_connectivity//
CREATE PROCEDURE zero_namespace_connectivity ( maxsize INT )
  BEGIN
    DECLARE st VARCHAR(255);

    IF @disambiguations_look_recognized>0
      THEN
        SELECT ':: echo ZERO NAMESPACE';

        # the name-prefix for all output files, distinct for each function call
        SET @fprefix=CONCAT( CAST( NOW() + 0 AS UNSIGNED ), '.' );

        #
        # Let wikistat table be a permanent storage 
        #     for inter-run data on statistics upload
        #
        # aka WikiMirrorTime al CurrentRunTime
        #
        CALL pretend( 'wikistat' );

        SET @initstarttime=now();

        # pre-loads r0 and nr0 tables for fast access
        CALL cache_namespace_pages( 0 );

        #
        # Constructs nrcatl for categorylinks.
        #
        # Based on nrcatl, recognizes
        #   articles,
        #   d - disambiguations,
        #   cllt - colloborative lists and
        #   chrono - chronological articles.
        #
        # Modifies maxsize if 0.
        #
        CALL classify_namespace( 0, 'articles', maxsize );

        #
        # For pl - namespace links cached in memory
        #
        CALL cache_namespace_links( 0 );

        IF @template_documentation_subpage_name!=''
          THEN
            #
            # Note: Template usage statistics query below works on the inner join
            #       of ti with articles on id=ti_from. Deletion is a major speedup.
            #
            DELETE FROM ti
                   WHERE ti_from NOT IN (select id from articles);

            #
            # Template usage statistics
            #
            DROP TABLE IF EXISTS templatetop;
            CREATE TABLE templatetop (
              t_id int(8) unsigned NOT NULL default '0',
              a_cnt int(8) unsigned NOT NULL default '0',
              PRIMARY KEY (t_id)
            ) ENGINE=MEMORY AS
            SELECT ti_to as t_id,
                   count(DISTINCT ti_from) as a_cnt
                   FROM ti
                   GROUP BY t_id;

            SELECT CONCAT( ':: echo ', count(*), ' distinct templating names used in articles' )
                   FROM templatetop;
        END IF;

        DROP TABLE IF EXISTS ti;

        #
        # Gives us l and some others: wr, mr, r filtered, r2nr.
        #
        CALL throwNhull4subsets( 0, 'articles' );

        SELECT CONCAT( ':: echo zero namespace time: ', TIMEDIFF(now(), @initstarttime));

        SELECT ':: echo LINKS DISAMBIGUATOR';

        SET @starttime=now();

        #
        # Collects ld, dl and disambiguate0.
        #
        CALL constructNdisambiguate();

        #
        # <<Disambiguation rule>> disregard index.
        #
        CALL store_drdi();

        DROP TABLE pl;
        DROP TABLE d;

        #
        # Named disambiguations list for use in web tools.
        #
        DROP TABLE IF EXISTS d0site;
        SET @st=CONCAT( 'CREATE TABLE d0site ( id int(8) unsigned NOT NULL default ', "'0'", ', name varchar(255) binary NOT NULL default ', "''", ', PRIMARY KEY (id) ) ENGINE=MyISAM AS SELECT cnad_id as id, page_title as name FROM cnad, ', @dbname, '.page WHERE page_id=cnad_id;' );
        PREPARE stmt FROM @st;
        EXECUTE stmt;
        DEALLOCATE PREPARE stmt;
    
        DROP TABLE cnad;

        # partial namespacer unload
        DROP TABLE nr0;

        SELECT CONCAT( ':: echo links disambiguator processing time: ', TIMEDIFF(now(), @starttime));

        #
        # DEAD-END ARTICLES PROCESSING
        #
        CALL deadend( 0 );

        #
        # ISOLATED ARTICLES PROCESSING
        #
        # Creates table named as isolated.

        SELECT ':: echo ISOLATED ARTICLES';

        CALL isolated( 0, 'articles', maxsize );

        DROP TABLE chrono;

        #
        # Four paraphrases for titlepage.
        #
        CALL store_paraphrases();

        #
        # A socket for the template maintainer everybody have spoken about.
        # Minimizes the amount of edits, combining results for
        # non-categorized, deadend and isolated analysis
        #
        CALL combineandout();

        DROP TABLE del;
        DROP TABLE nocat;

        CALL isolated_refresh( '0', 0 );

        #
        # Initiate statistics upload on isolated chains
        #
        # Note: Case with @connectivity_project_root empty is 
        #       catched by outside handler.
        #
        SELECT CONCAT( ':: stat ', max(ts), ' ', @master_server_id, ' ', @connectivity_project_root, '/stat' )
               FROM wikistat
               WHERE valid=0;

        #
        # Pack files for delivery
        #
        SELECT ':: 7z';

        # allow orcat table to be used in postponed namespace 0 tools
        DROP TABLE IF EXISTS ll_orcat;
        RENAME TABLE orcat TO ll_orcat;

        # outer tools moved after a namespace change need to continue working
        # with categories
        # categorizer: bless nrcatl
        DROP TABLE IF EXISTS nrcatl0;
        RENAME TABLE nrcatl TO nrcatl0;

        # Uses articles table, so cannot be postponed yet.
        CALL isolated_by_category();

        # unload articlizer
        DROP TABLE articles;

        # unload isolated
        DROP TABLE isolated;
      ELSE
        SELECT ':: echo ZERO NAMESPACE CONNECTIVITY CANNOT BE PERFORMED';
    END IF;
  END;
//

DROP PROCEDURE IF EXISTS zero_namespace_postponed_tools//
CREATE PROCEDURE zero_namespace_postponed_tools ( server INT )
  BEGIN
    IF @disambiguations_look_recognized>0
      THEN
        SELECT ':: echo POSTPONED ZERO NAMESPACE TOOLS';

        CALL suggestor( server );

        CALL creatorizer();
      ELSE
        SELECT ':: echo NO POSTPONED TOOLS FOR ZERO NAMESPACE';
    END IF;
  END;
//

DROP PROCEDURE IF EXISTS categorytree_connectivity//
CREATE PROCEDURE categorytree_connectivity ( maxsize INT )
  BEGIN
    #
    # For "CATEGORYTREE CONNECTIVITY".
    #
    SELECT ':: echo CATEGORYTREE CONNECTIVITY';

    SET @starttime=now();

    # the name-prefix for all output files, distinct for each function call
    SET @fprefix=CONCAT( CAST( NOW() + 0 AS UNSIGNED ), '.' );

    #
    # Constructs nrcatl for categorylinks, based on this table
    # preloads tables and recognizes articles, disambiguations, colloborative
    # lists and chronological articles.
    #
    # Modifies maxsize if 0.
    #
    CALL classify_namespace( 14, 'categories', maxsize );

    CALL categorybridge();

    #
    # Gives us l and some others: wr, mr, r filtered, r2nr.
    #
    CALL throwNhull4subsets( 14, 'categories' );

    DROP TABLE pl;
    # partial disambiguator unload
    DROP TABLE d;
    # partial namespacer unload
    DROP TABLE nr14;

    #
    # DEAD-END ARTICLES PROCESSING
    #
    # Note: do we need this for ns=14?
    CALL deadend( 14 );

    DROP TABLE del;

    #
    #  ISOLATED ARTICLES PROCESSING
    #

    SELECT ':: echo CATEGORYGRAPH';

    # Creates table named as isolated.
    CALL isolated( 14, 'categories', maxsize );

    CALL isolated_refresh( '14', 14 );

    # unnecessary table, not used unlike to ns=0
    # unload categorizer
    DROP TABLE IF EXISTS nrcat;

    CALL actuality( 'categoryspruce' );

    # unload articlizer
    DROP TABLE articles;

    # unload isolated
    DROP TABLE isolated;
    DROP TABLE orcat;

    SELECT CONCAT( ':: echo categoryspruce web tool time: ', TIMEDIFF(now(), @starttime));
  END;
//

delimiter ;
############################################################

-- </pre>
