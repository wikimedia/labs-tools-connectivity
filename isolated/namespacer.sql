 --
 -- Authors: [[:ru:user:Mashiah Davidson]],
 --          [[:ru:user:Vlsergey]]
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

 --
 -- Significant speedup
 --

SET SESSION TRANSACTION ISOLATION LEVEL READ UNCOMMITTED;

############################################################
delimiter //

#
# This procedure obtains connecitity project root page name from
# a templated named {{Connectivity project root}} and stores it in
# @connectivity_project_root variable.
#
DROP PROCEDURE IF EXISTS get_connectivity_project_root//
CREATE PROCEDURE get_connectivity_project_root (targetlang VARCHAR(32))
  BEGIN
    DECLARE st VARCHAR(511);

    SET @connectivity_project_root='';

    SET @st=CONCAT( 'SELECT CONCAT( getnsprefix( pl_namespace, "', targetlang, '" ), pl_title ) INTO @connectivity_project_root FROM ', dbname_for_lang( targetlang ), '.page, ', dbname_for_lang( targetlang ), '.pagelinks WHERE pl_from=page_id and page_namespace=10 and page_title="Connectivity_project_root" LIMIT 1;' );
    PREPARE stmt FROM @st;
    EXECUTE stmt;
    DEALLOCATE PREPARE stmt;

    IF @connectivity_project_root='NULL'
      THEN
        SET @connectivity_project_root='';
    END IF;
  END;
//


#
# Caches the pages for a namespace given to local tables 
#   p<namespace>  (for all pages, mostly for pagelinks caching),
#   nr<namespace> (for non-redirects)
#   r<namespace>  (for redirects)
# for speedup
#
DROP PROCEDURE IF EXISTS cache_namespace_pages//
CREATE PROCEDURE cache_namespace_pages (namespace INT)
  BEGIN
    DECLARE st VARCHAR(511);
    DECLARE cnt INT;

    #
    # Calculate the amount of rows for pages in the namespace given.
    #
    SET @st=CONCAT( 'SELECT count(*) INTO @cnt FROM ', @dbname, '.page WHERE page_namespace=', namespace, ';' );
    PREPARE stmt FROM @st;
    EXECUTE stmt;
    DEALLOCATE PREPARE stmt;

    #
    # Experimental data: one row of p takes near to 400 bytes on 64-bit system.
    #
    CALL allow_allocation( 512*@cnt );

    #
    # Cache pages.
    #
    DROP TABLE IF EXISTS p;
    SET @st=CONCAT( 'CREATE TABLE p ( p_id int(8) unsigned NOT NULL default ', "'0'", ', p_title varchar(255) binary NOT NULL default ', "''", ', p_is_redirect tinyint(1) unsigned NOT NULL default ', "'0'", ', PRIMARY KEY (p_id), UNIQUE KEY rtitle (p_title) ) ENGINE=MEMORY AS SELECT page_id as p_id, page_title as p_title, page_is_redirect as p_is_redirect FROM ', @dbname, '.page WHERE page_namespace=', namespace, ';' );
    PREPARE stmt FROM @st;
    EXECUTE stmt;
    DEALLOCATE PREPARE stmt;

    SELECT CONCAT( ':: echo ', count(*), ' pages found for namespace ', namespace, ':' )
           FROM p;

    #
    # Non-redirects
    #
    DROP TABLE IF EXISTS nr;
    CREATE TABLE nr (
      id int(8) unsigned NOT NULL default '0',
      title varchar(255) binary NOT NULL default '',
      PRIMARY KEY (id)
    ) ENGINE=MEMORY AS
    SELECT p_id as id,
           p_title as title
           FROM p
           WHERE p_is_redirect=0;

    SELECT CONCAT( ':: echo . non-redirects: ', count(*) )
           FROM nr;

    #
    # Redirect pages
    #
    DROP TABLE IF EXISTS r;
    CREATE TABLE r (
      r_id int(8) unsigned NOT NULL default '0',
      r_title varchar(255) binary NOT NULL default '',
      PRIMARY KEY  (r_id),
      UNIQUE KEY rtitle (r_title)
    ) ENGINE=MEMORY AS
    SELECT p_id as r_id,
           p_title as r_title
           FROM p
           WHERE p_is_redirect=1;

    SELECT CONCAT( ':: echo . redirect pages: ', count(*) )
           FROM r;

    SET @st=CONCAT( 'DROP TABLE IF EXISTS p', namespace, ';' );
    PREPARE stmt FROM @st;
    EXECUTE stmt;
    DEALLOCATE PREPARE stmt;
    SET @st=CONCAT( 'RENAME TABLE p TO p', namespace, ';' );
    PREPARE stmt FROM @st;
    EXECUTE stmt;
    DEALLOCATE PREPARE stmt;

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

    SET @st=CONCAT( 'INSERT INTO cllt SELECT DISTINCT cl_from as cllt_id FROM ', @dbname, '.page, ', @dbname, '.pagelinks, ', @dbname, '.categorylinks WHERE pl_title=cl_to and pl_namespace=14 and page_id=pl_from and page_namespace=4 and page_title="', @i18n_page, '/CategorizedNonArticles";' );
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

    SET @st=CONCAT( 'INSERT INTO chrono SELECT DISTINCT cl_from as chr_id FROM ', @dbname, '.page, ', @dbname, '.pagelinks, ', @dbname, '.categorylinks WHERE pl_title=cl_to and pl_namespace=14 and page_id=pl_from and page_namespace=4 and page_title="', @i18n_page, '/ArticlesNotFormingValidLinks";' );
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
        #
        # Add disambiguations to cna.
        #
        INSERT INTO cna
        SELECT d_id as cna_id
               FROM d;

        #
        # Add collaborative lists to cna.
        #
        INSERT INTO cna
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

    # Articles (i.e. non-redirects and non-disambigs for current namespace)
    DROP TABLE IF EXISTS articles;
    CREATE TABLE articles (
      id int(8) unsigned NOT NULL default '0',
      title varchar(255) binary NOT NULL default '',
      PRIMARY KEY (id),
      UNIQUE KEY title (title)
    ) ENGINE=MEMORY;

    SET @st=CONCAT( 'INSERT INTO articles SELECT id, title FROM nr', namespace, ' WHERE id NOT IN ( SELECT DISTINCT cna_id FROM cna );' );
    PREPARE stmt FROM @st;
    EXECUTE stmt;
    DEALLOCATE PREPARE stmt;

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
        INSERT INTO cna
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

    #
    # Cahing page links to the given namespace for speedup.
    #
    # Notes: 1) Links to existent pages cached only, i.e. no "red links".
    #        2) One of the key points here is that we didn't try
    #           saving pl_title, the table this way might be too huge.
    #        3) STRAIGHT_JOIN leads to connect first the pagelinks table.
    #           This way we have a straight pass through the pl_namespace
    #           index and then single pass trough a hash join in memory
    #           (=fast) for p<namespace>.
    #           This is much better than iteration trough p<namespace> with
    #           later indexed titles matching for all p<namespace> values.
    #
    SET @st=CONCAT( 'CREATE TABLE pl ( pl_from int(8) unsigned NOT NULL default ', "'0'", ', pl_to int(8) unsigned NOT NULL default ', "'0'", ' ) ENGINE=MEMORY AS /* SLOW_OK */ SELECT STRAIGHT_JOIN pl_from, p_id as pl_to FROM ', @dbname, '.pagelinks, p', namespace, ' WHERE pl_namespace=', namespace, ' and pl_title=p_title;' );
    PREPARE stmt FROM @st;
    EXECUTE stmt;
    DEALLOCATE PREPARE stmt;

    SELECT count(*) INTO @pl_count
           FROM pl;

    SELECT CONCAT( ':: echo ', @pl_count, ' links point namespace ', namespace );

    SELECT CONCAT( ':: echo links to namespace ', namespace, ' caching time: ', timediff(now(), @starttime1));

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

    #
    # Delete everything going from other namespaces.
    #
    # Note: No proof for necessity of this operation in terms
    #       of speedup. However, it also does not look making
    #       the analysis slower. 
    #       Can be helpfull for projects with meta part developed well.
    SET @st=CONCAT( 'DELETE FROM pl WHERE pl_from NOT IN ( SELECT p_id FROM p', namespace, ' );' );
    PREPARE stmt FROM @st;
    EXECUTE stmt;
    DEALLOCATE PREPARE stmt;

    IF namespace!=10
      THEN
        SET @st=CONCAT( 'DROP TABLE p', namespace, ';' );
        PREPARE stmt FROM @st;
        EXECUTE stmt;
        DEALLOCATE PREPARE stmt;
    END IF;

    SELECT count(*) INTO @pl_count
           FROM pl;

    SELECT CONCAT( ':: echo ', @pl_count, ' namespace ', namespace, ' links point namespace ', namespace );
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

    SELECT CONCAT( ':: echo ', count(*), ' links for categorytree' )
           FROM pl;
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
    # collects wrong redirects and excludes them from r<ns>
    CALL cleanup_wrong_redirects( namespace );

    # throws redirect chains and adds paths to pl
    CALL throw_multiple_redirects( namespace );

    #
    # Experimental data: one row of l takes near to 52 bytes on 64-bit system.
    #
    CALL allow_allocation( 64*@pl_count );

    # Table l is created here for all links, which are to be taken into account.
    DROP TABLE IF EXISTS l;
    CREATE TABLE l (
      l_to int(8) unsigned NOT NULL default '0',
      l_from int(8) unsigned NOT NULL default '0',
      PRIMARY KEY (l_to,l_from)
    ) ENGINE=MEMORY;

    #
    # Before any analysis running we need to identify all the valid links
    # between articles. Here the links table l is constructed as containing
    #  - direct links from article to article
    #  - links from article to article via a redirect from the namespace given
    #  - links from article to article via a long (double, triple, etc) redirect
    #

    SET @starttime1=now();

    #
    # Here we can construct links from articles to articles.
    #
    INSERT IGNORE INTO l /* SLOW_OK */
    SELECT id as l_to,
           pl_from as l_from
           FROM pl,
                articles
           WHERE pl_from in
                 (
                  SELECT id 
                         FROM articles
                 ) and
                 pl_to=id and
                 pl_from!=id;

    SELECT count(*) INTO @articles_to_articles_links_count
           FROM l;

    SELECT CONCAT( ':: echo ', @articles_to_articles_links_count, ' links from ', targetset, ' to ', targetset );

    SELECT CONCAT( ':: echo links from ', targetset, ' to ', targetset, ' caching time: ', timediff(now(), @starttime1));

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
    INSERT INTO zns
    VALUES ( @articles_count, @chrono_articles_count, @disambiguation_pages_count, @collaborative_lists_count );

    # no need to keep old data because the action has performed
    DELETE FROM fch;

    # just in case of stats uploaded during this run
    INSERT INTO fch
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
    INSERT INTO tch
    VALUES ( ch_links_prc, ch_lnks_per_ch );

  END;
//

# Do all the zero namespace connectivity analysis assuming maxsize as
# maximal possible claster size, zero means no limit.
#
DROP PROCEDURE IF EXISTS collect_template_pages//
CREATE PROCEDURE collect_template_pages ( maxsize INT )
  BEGIN
    DECLARE templator_needed INT DEFAULT '0';

    #
    # Lost hope
    #
    IF @massive_links_recognition_alive='NULL'
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

    IF @disambiguation_templates_initialized=0
      THEN
        SET @templator_needed=0;
    END IF;

    IF @templator_needed=1
      THEN
        SELECT ':: echo TEMPLATE PAGES';

        # the name-prefix for all output files, distinct for each function call
        SET @fprefix=CONCAT( CAST( NOW() + 0 AS UNSIGNED ), '.' );

        # pre-loads p10, r10 and nr10 tables for fast access
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

        SET @st=CONCAT( 'SELECT count(*) INTO @tl_count FROM ', @dbname, '.templatelinks;' );
        PREPARE stmt FROM @st;
        EXECUTE stmt;
        DEALLOCATE PREPARE stmt;

        SET @st=CONCAT( 'CALL allow_allocation( ', 32*@tl_count, ' );' );
        PREPARE stmt FROM @st;
        EXECUTE stmt;
        DEALLOCATE PREPARE stmt;

        #
        # Templating links storage with info on template name length for
        # each link.
        #
        # Notes: Lots of templates are not used in articles directly and came 
        #        with templating, so should be excluded.
        #
        #        Links to non-existent templates are not there.
        #
        DROP TABLE IF EXISTS ti;
        CREATE TABLE ti (
          ti_from int(8) unsigned NOT NULL default '0',
          ti_to int(8) unsigned NOT NULL default '0',
          KEY (ti_from)
        ) ENGINE=MEMORY;

        SET @st=CONCAT( 'INSERT INTO ti /* SLOW_OK */ SELECT STRAIGHT_JOIN tl_from as ti_from, p_id as ti_to FROM ', @dbname, '.templatelinks, p10 WHERE tl_namespace=10 and tl_title=p_title;' );
        PREPARE stmt FROM @st;
        EXECUTE stmt;
        DEALLOCATE PREPARE stmt;

        SELECT CONCAT( ':: echo ', count(*), ' template occurrences found' )
               FROM ti;

        DROP TABLE p10;

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
# maximal possible claster size, zero means no limit.
#
DROP PROCEDURE IF EXISTS zero_namespace_connectivity//
CREATE PROCEDURE zero_namespace_connectivity ( maxsize INT )
  BEGIN
    IF @disambiguation_templates_initialized>0
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

        # pre-loads p0, r0 and nr0 tables for fast access
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
            # Template usage statistics
            #
            DROP TABLE IF EXISTS templatetop;
            CREATE TABLE templatetop (
              t_id int(8) unsigned NOT NULL default '0',
              a_cnt int(8) unsigned NOT NULL default '0',
              PRIMARY KEY (t_id)
            ) ENGINE=MEMORY AS
            SELECT ti_to as t_id,
                   count(DISTINCT id) as a_cnt
                   FROM ti,
                        articles
                   WHERE ti_from=id
                   GROUP BY t_id;

            SELECT CONCAT( ':: echo ', count(*), ' distinct templating names used in articles' )
                   FROM templatetop;
        END IF;

        DROP TABLE IF EXISTS ti;

        #
        # FCH, from chrono articles
        #

        # permanent storage for inter-run data created here if not exists
        CREATE TABLE IF NOT EXISTS fch (
          clinks INT(8) unsigned NOT NULL default '0',
          alinks INT(8) unsigned NOT NULL default '0'
        ) ENGINE=MyISAM;

        #
        # Gives us l and some others: wr, mr, r filtered, r2nr.
        #
        CALL throwNhull4subsets( 0, 'articles' );

        SELECT CONCAT( ':: echo zero namespace time: ', timediff(now(), @initstarttime));

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

        SELECT CONCAT( ':: echo links disambiguator processing time: ', timediff(now(), @starttime));

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
        # Three paraphrases for titlepage.
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
    IF @disambiguation_templates_initialized>0
      THEN
        SELECT ':: echo POSTPONED ZERO NAMESPACE TOOLS';

        CALL suggestor( server );

        CALL creatorizer();
      ELSE
        SELECT ':: echo NO POSTPONED TOOLS FOR ZERO NAMESPACE';
    END IF;
  END;
//

#
# Prepare data for categoryspruce web tool
#
DROP PROCEDURE IF EXISTS categoryspruce//
CREATE PROCEDURE categoryspruce ()
  BEGIN
    SET @starttime=now();

    #
    # For "CATEGORYTREE CONNECTIVITY".
    #

    # unnecessary table, not used unlike to ns=0
    # unload categorizer
    DROP TABLE IF EXISTS nrcat;

    CALL actuality( 'categoryspruce' );

    # unload articlizer
    DROP TABLE articles;

    # unload isolated
    DROP TABLE isolated;
    DROP TABLE orcat;

    SELECT CONCAT( ':: echo categoryspruce web tool time: ', timediff(now(), @starttime));
  END;
//

DROP PROCEDURE IF EXISTS categorytree_connectivity//
CREATE PROCEDURE categorytree_connectivity ( maxsize INT )
  BEGIN
    SELECT ':: echo CATEGORYTREE CONNECTIVITY';

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

    CALL categoryspruce();
  END;
//

delimiter ;
############################################################

-- </pre>
