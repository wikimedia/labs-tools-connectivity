 --
 -- Authors: [[:ru:user:Mashiah Davidson]], still alone
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
# Caches the pages for a namespace given to local tables 
#   p@namespace  (for all pages, mostly for pagelinks caching),
#   nr@namespace (for non-redirects)
#   r@namespace  (for redirects)
# for speedup
#
DROP PROCEDURE IF EXISTS cache_namespace_pages//
CREATE PROCEDURE cache_namespace_pages (namespace INT)
  BEGIN
    DECLARE st VARCHAR(255);

    # Requires @@max_heap_table_size not less than 134217728 for zero namespace.
    DROP TABLE IF EXISTS p;
    CREATE TABLE p (
      p_id int(8) unsigned NOT NULL default '0',
      p_title varchar(255) binary NOT NULL default '',
      p_is_redirect tinyint(1) unsigned NOT NULL default '0',
      PRIMARY KEY (p_id),
      UNIQUE KEY rtitle (p_title)
    ) ENGINE=MEMORY AS
    SELECT page_id as p_id,
           page_title as p_title,
           page_is_redirect as p_is_redirect
           FROM ruwiki_p.page
           WHERE page_namespace=namespace;

    SELECT CONCAT( ':: echo ', count(*), ' pages found for namespace ', namespace, ':' )
           FROM p;

    ## requested by qq[IrcCity]
    #CALL outifexists( 'p', CONCAT( 'namespace ', namespace), 'p.info', 'p_title', 'out' );

    # Non-redirects
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

    # Redirect pages
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
CREATE PROCEDURE classify_namespace (IN namespace INT, INOUT maxsize INT)
  BEGIN
    DECLARE acount INT;
    DECLARE st VARCHAR(255);

    CALL categorylinks( namespace );

    #
    # In order to exclude disambiguations from articles set,
    # disambiguation pages are collected here into d table.
    #
    CALL collect_disambig();

    #
    # Collaborative lists collected here to for links table filtering.
    # The list is superflous, i.e. contains pages outside the namespace
    #
    #
    # With namespace=14 it does show if secondary lists category is split into
    # subcategories.
    #
    DROP TABLE IF EXISTS cllt;
    CREATE TABLE cllt (
      cllt_id int(8) unsigned NOT NULL default '0',
      PRIMARY KEY  (cllt_id)
    ) ENGINE=MEMORY AS
    SELECT DISTINCT nrcl_from as cllt_id
           FROM nrcatl
                #      secondary lists
           WHERE nrcl_cat=nrcatuid('Списки_статей_для_координации_работ');

    SELECT CONCAT( ':: echo ', count(*), ' secondary list names found' )
           FROM cllt;

    #
    # Categorized non-articles.
    #
    # With namespace=14 is not used because of nature of links and pages.
    #
    DROP TABLE IF EXISTS cna;
    CREATE TABLE cna (
      cna_id int(8) unsigned NOT NULL default '0',
      KEY  (cna_id)
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
        # Add soft redirects to cna.
        #
        INSERT INTO cna
        SELECT DISTINCT nrcl_from as cna_id
               FROM nrcatl
                     #      soft redirects
               WHERE nrcl_cat=nrcatuid('Википедия:Мягкие_перенаправления');

        #
        # Add collaborative lists to cna.
        #
        INSERT INTO cna
        SELECT cllt_id as cna_id
               FROM cllt;

        SELECT CONCAT( ':: echo ', count(*), ' categorized exclusion names found' )
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

    DROP TABLE cna;

    SELECT count(*) INTO acount
           FROM articles;

    SELECT CONCAT( ':: echo ', acount, ' articles found' );

    # No restriction on maximal scc size does not mean infinite
    # computational resources, but it is known for sure that maximal
    # scc size does not exceed the amount of elements in the set.
    IF maxsize=0
      THEN
        SET maxsize=acount;
    END IF;

    IF namespace=0
      THEN
        #
        # Chrono articles
        #
        DROP TABLE IF EXISTS chrono;
        CREATE TABLE chrono (
          chr_id int(8) unsigned NOT NULL default '0',
          PRIMARY KEY  (chr_id)
        ) ENGINE=MEMORY AS
        SELECT DISTINCT id as chr_id
               FROM articles
                     #           Common Era years 
               WHERE title LIKE '_!_год' escape '!' OR
                     title LIKE '__!_год' escape '!' OR             
                     title LIKE '___!_год' escape '!' OR             
                     title LIKE '____!_год' escape '!' OR
                     #           years B.C.
                     title LIKE '_!_год!_до!_н.!_э.' escape '!' OR             
                     title LIKE '__!_год!_до!_н.!_э.' escape '!' OR             
                     title LIKE '___!_год!_до!_н.!_э.' escape '!' OR             
                     title LIKE '____!_год!_до!_н.!_э.' escape '!' OR
                     #           decades
                     title LIKE '_-е' escape '!' OR             
                     title LIKE '__-е' escape '!' OR             
                     title LIKE '___-е' escape '!' OR
                     title LIKE '____-е' escape '!' OR
                     #           decades B.C.
                     title LIKE '_-е!_до!_н.!_э.' escape '!' OR             
                     title LIKE '__-е!_до!_н.!_э.' escape '!' OR             
                     title LIKE '___-е!_до!_н.!_э.' escape '!' OR
                     title LIKE '____-е!_до!_н.!_э.' escape '!' OR
                     #           centuries
                     title LIKE '_!_век' escape '!' OR
                     title LIKE '__!_век' escape '!' OR
                     title LIKE '___!_век' escape '!' OR
                     title LIKE '____!_век' escape '!' OR
                     title LIKE '_____!_век' escape '!' OR
                     title LIKE '______!_век' escape '!' OR
                     #           centuries B.C.
                     title LIKE '_!_век!_до!_н.!_э.' escape '!' OR
                     title LIKE '__!_век!_до!_н.!_э.' escape '!' OR
                     title LIKE '___!_век!_до!_н.!_э.' escape '!' OR
                     title LIKE '____!_век!_до!_н.!_э.' escape '!' OR
                     title LIKE '_____!_век!_до!_н.!_э.' escape '!' OR
                     title LIKE '______!_век!_до!_н.!_э.' escape '!' OR
                     #           milleniums
                     title LIKE '_!_тысячелетие' escape '!' OR
                     title LIKE '__!_тысячелетие' escape '!' OR
                     #             milleniums B.C.
                     title LIKE '_!_тысячелетие!_до!_н.!_э.' escape '!' OR
                     title LIKE '__!_тысячелетие!_до!_н.!_э.' escape '!' OR
                     title LIKE '___!_тысячелетие!_до!_н.!_э.' escape '!' OR
                     #             years in different application domains
                     title LIKE '_!_год!_в!_%' escape '!' OR
                     title LIKE '__!_год!_в!_%' escape '!' OR
                     title LIKE '___!_год!_в!_%' escape '!' OR
                     title LIKE '____!_год!_в!_%' escape '!' OR
                     #             calendar dates in the year
                     title LIKE '_!_января' escape '!' OR
                     title LIKE '__!_января' escape '!' OR
                     title LIKE '_!_февраля' escape '!' OR
                     title LIKE '__!_февраля' escape '!' OR
                     title LIKE '_!_марта' escape '!' OR
                     title LIKE '__!_марта' escape '!' OR
                     title LIKE '_!_апреля' escape '!' OR
                     title LIKE '__!_апреля' escape '!' OR
                     title LIKE '_!_мая' escape '!' OR
                     title LIKE '__!_мая' escape '!' OR
                     title LIKE '_!_июня' escape '!' OR
                     title LIKE '__!_июня' escape '!' OR
                     title LIKE '_!_июля' escape '!' OR
                     title LIKE '__!_июля' escape '!' OR
                     title LIKE '_!_августа' escape '!' OR
                     title LIKE '__!_августа' escape '!' OR
                     title LIKE '_!_сентября' escape '!' OR
                     title LIKE '__!_сентября' escape '!' OR
                     title LIKE '_!_октября' escape '!' OR
                     title LIKE '__!_октября' escape '!' OR
                     title LIKE '_!_ноября' escape '!' OR
                     title LIKE '__!_ноября' escape '!' OR
                     title LIKE '_!_декабря' escape '!' OR
                     title LIKE '__!_декабря' escape '!' OR
                     #           year lists by the first week day 
                     title LIKE 'Високосный!_год,!_начинающийся!_в%' escape '!' OR
                     title LIKE 'Невисокосный!_год,!_начинающийся!_в%' escape '!';

        SELECT CONCAT( ':: echo ', count(*), ' chronological articles found' )
               FROM chrono;
    END IF;
  END;
//

#
# Caches the page links for a namespace given to table pl for speedup
#
DROP PROCEDURE IF EXISTS cache_namespace_links//
CREATE PROCEDURE cache_namespace_links (namespace INT)
  BEGIN
    DROP TABLE IF EXISTS pl;

    #
    # Cahing page links to the given namespace for speedup.
    #
    # Notes: 1) Links to existent pages cached only, i.e. no "red links".
    #        2) One of the key points here is that we didn't try
    #           saving pl_title, the table this way might be too large.
    #
    CREATE TABLE pl (
      pl_from int(8) unsigned NOT NULL default '0',
      pl_to int(8) unsigned NOT NULL default '0'
    ) ENGINE=MEMORY AS /* SLOW_OK */
    SELECT pl_from,
           p_id as pl_to
           FROM ruwiki_p.pagelinks,
                p0
           WHERE pl_namespace=namespace and
                 pl_title=p_title;

    SELECT CONCAT( ':: echo ', count(*), ' links point namespace ', namespace )
           FROM pl;

    #
    # Delete everything going from other namespaces.
    #
    # Note: No proof for necessity of this operation in terms
    #       of speedup. However, it also does not look making
    #       the analysis slower. 
    #       Can be helpfull for projects with meta part developed well.
    DELETE FROM pl
           WHERE pl_from NOT IN
                 (
                  SELECT p_id 
                         FROM p0
                 );
    DROP TABLE p0;

    SELECT CONCAT( ':: echo ', count(*), ' namespace ', namespace, ' links point namespace ', namespace )
           FROM pl;
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
# Inputs: r, nr, pl, articles, d.
#
# Main output for connectivity analysis:
#   l  - links from articles to articles,
#   ld - links from disambiguation pages to articles,
#   dl - links from articles to disambiguation pages.
#
# Side output: wr, r filtered, r2nr, mr output into a file
#
# Notes: Now requires @@max_heap_table_size to be equal to 268435456 bytes
#        for main namespace analysis in ruwiki.
#
DROP PROCEDURE IF EXISTS throwNhull4subsets//
CREATE PROCEDURE throwNhull4subsets (namespace INT)
  BEGIN
    DECLARE st VARCHAR(255);

    # collects wrong redirects and excludes them from pl
    CALL cleanup_wrong_redirects( namespace );

    # throws redirect chains and adds paths to pl
    CALL throw_multiple_redirects( namespace );

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
    # Notes: Now the links table requires @@max_heap_table_size 
    #        to be equal to 268435456 bytes for main namespace analysis 
    #        in ruwiki.
    #        Namespace 14 probably must be free of redirect links - todo.
    #

    #
    # Here we can construct links from articles to articles.
    #
    INSERT IGNORE INTO l
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

    SELECT CONCAT( ':: echo ', count(*), ' links from articles to articles' )
           FROM l;


    SELECT CONCAT( ':: echo init time: ', timediff(now(), @starttime));

    IF namespace!=14
      THEN
        SELECT ':: echo LINKS DISAMBIGUATOR';

        SET @starttime=now();

        # Constructs two tables of links:
        #  - a2d named dl;
        #  - d2a named ld.
        # dl and ld are not in l, so we use pl again there
        CALL construct_dlinks();

        #
        #  LINKS DISAMBIGUATOR
        #
        CALL disambiguator( namespace );

        CALL disambiguator_refresh( 'disambiguate0' );

        CALL actuality( 'disambiguator' );

        SELECT CONCAT( ':: echo links disambiguator processing time: ', timediff(now(), @starttime));
    END IF;

    DROP TABLE pl;
    # partial disambiguator unload
    DROP TABLE d;
    # partial namespacer unload
    SET @st=CONCAT( 'DROP TABLE nr', namespace, ';' );
    PREPARE stmt FROM @st;
    EXECUTE stmt;
    DEALLOCATE PREPARE stmt;
  END;
//

#
# Do all the zero namespace connectivity analysis assuming maxsize as
# maximal possible claster size, zero means no limit.
#
DROP PROCEDURE IF EXISTS zero_namespace_connectivity//
CREATE PROCEDURE zero_namespace_connectivity ( maxsize INT )
  BEGIN
    SELECT ':: echo ZERO NAMESPACE';

    # the name-prefix for all output files, distinct for each function call
    SET @fprefix=CONCAT( CAST( NOW() + 0 AS UNSIGNED ), '.' );

    #
    # Let wikistat be the permanent storage 
    #     for inter-run data on statistics upload
    #
    # aka WikiMirrorTime al CurrentRunTime
    #
    CALL pretend( 'wikistat' );

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
    # Note: Requires @@max_heap_table_size not less than 134217728
    #
    CALL classify_namespace( 0, maxsize );

    #
    # For pl - namespace links cached in memory
    #
    CALL cache_namespace_links( 0 );

    #
    # Gives us l, ld, dl and some others: wr, mr, r filtered, r2nr.
    #
    CALL throwNhull4subsets( 0 );

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

    # socket for the template maintainer
    # minimizes amount of edits combining results for deadend and isolated analysis
    CALL combineandout();
    DROP TABLE del;

    CALL isolated_refresh( '0', 0 );

    #
    # STATIST INITIATION
    #

    # initiate statistics upload 
    SELECT count(*) INTO @validexists
           FROM wikistat
           WHERE valid=1;
    SELECT max(ts) INTO @curts
           FROM wikistat
           WHERE valid=0;
    IF @validexists=0
      THEN
        # first statistics upload
        SELECT CONCAT( ':: stat ', @curts, ' 00:00:00' );
      ELSE
        SELECT max(ts) INTO @valid
               FROM wikistat
               WHERE valid=1;
        SELECT timediff(@curts, @valid) INTO @valid;

        SELECT CONCAT( ':: stat ', @curts, ' ', @valid );
    END IF;

    # pack files for delivery
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
  END;
//

DROP PROCEDURE IF EXISTS zero_namespace_postponed_tools//
CREATE PROCEDURE zero_namespace_postponed_tools ()
  BEGIN
    SELECT ':: echo POSTPONED ZERO NAMESPACE TOOLS';

    CALL suggestor();

    CALL creatorizer();
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
    CALL classify_namespace( 14, maxsize );

    CALL categorybridge();

    #
    # Gives us l, ld, dl and some others: wr, mr, r filtered, r2nr.
    #
    CALL throwNhull4subsets( 14 );

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
