 --
 -- Authors: [[:ru:user:Mashiah Davidson]], still alone
 --
 -- Purpose: [[:en:Connectivity (graph theory)|Connectivity]] analysis script
 --          for [[:ru:|Russian Wikipedia]] and probably others if ready
 --          to approve some guidances on
 --            - what is an article and 
 --            - what is a relevant link.
 -- 
 -- Use: Nice to be called from 
 --      '''[[:ru:User:Mashiah_Davidson\toolserver\isolated.sh|isolated.sh]]'''.
 --
 -- Output: There is some API, which can be threated as an output API,
 --         however, for now it is much easier to deal with output of 
 --         '''isolated.sh''', as well as the output of that script is put
 --         into a set of files with mind-understandable names and content.
 --
 -- What is an article: Originally, the {{comment|Main|
 --                                               zero}} namespace has been
 --                                               itroduced for articles. 
 --                     Actually it does also contain the redirect pages for
 --                     articles, disambiguation pages, soft redirects and
 --                     sometimes some templates (which is wrong on my own
 --                     opinion, but sometimes used).
 --
 -- Relevant linking concept: Links from chronological articles are not too
 --                           relevant, and they are threated as links from 
 --                           a time-oriented portal.
 --                           Some articles lists are not too relevant either,
 --                           all the links from collaborational lists are
 --                           also ignored.
 --
 -- Side effects: Some multiple (double, triple, etc) redirects are also
 --               collected by the way. It is strange for me to know that
 --               Mediawiki engine does not recognize most of them.
 --               Wrong redirect pages can be found somitimes, and they are
 --               wrong because they work as redirects in the web but contain
 --               some garbage links making impossible any links analysis 
 --               in the database.
 --               One more side effect is the ability to run the analysis for
 --               categories tree and know if there any cycles or uncategorized
 --               categories present.
 --
 --
 -- Expected outputs: Isolated articles of various types, what's to tag
 --                   and what is to be untagged in relation to disconnexion.
 --                   The same for dead-end pages, the list is more correct
 --                   than autocollected one in terms of article definition,
 --                   id est it is smarter dealing with zero namespace.
 --             
 -- Types of isolated articles: The connectivity analysis here relies on
 --                             some concepts from [[graphs theory]].
 --                             One important thing is the concept of
 --                             a [[strongly connected component]] 
 --                             (aka scc or cluster), which is
 --                             the subgraph of a graph given of the maximal
 --                             possible size with every verticle (article)
 --                             reachable from each other in this subgraph.
 --                             We are interested in orphaned strongly
 --                             connected components (aka oscc), and chains
 --                             of such orphaned clusters.
 --                             It is kwown after ... (do not remember)
 --                             that clusters are all constructed from cycles
 --                             of various sizes.
 -- 
 -- Namespace and complexity control:
 --
 -- <pre>

 --
 --       Before passing this script to mysql three variables should be set
 --       in the same mysql session:
 --            - @namespace;
 --            - @max_scc_size;
 --            - max_sp_recursion_depth.
 --       Refer to isolated.sh for example.
 --

 --
 --       Enable/disable informative output, such as
 --       current sets of isolated and dead-end articles.
 --

set @enable_informative_output=0;

 --
 --       Tune if one of memory tables does not fit.
 --

#set @@max_heap_table_size=16777216;
#set @@max_heap_table_size=33554432;
#set @@max_heap_table_size=67108864;
#set @@max_heap_table_size=134217728;
#set @@max_heap_table_size=268435456;
set @@max_heap_table_size=536870912;
#set @@max_heap_table_size=1073741824;

 --
 -- Significant speedup
 --

SET SESSION TRANSACTION ISOLATION LEVEL READ UNCOMMITTED;

 --
 -- Functions and procedures definition
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

      SET @st2=CONCAT( 'SELECT * FROM ', tablename, ' ORDER BY ', ordercol, ' ASC' );
      PREPARE stmt FROM @st2;
      EXECUTE stmt;
      DEALLOCATE PREPARE stmt;
    END IF;
  END;
//
      
#
# Caches the namespace given to local tables 
#   r (for redirects),
#   articles (for articles)
#   pl (for links)
# for speedup
#
DROP PROCEDURE IF EXISTS cache_namespace//
CREATE PROCEDURE cache_namespace (num INT)
  BEGIN
    DECLARE acount INT;

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
           WHERE page_namespace=num;

    SELECT CONCAT( ':: echo ', count(*), ' pages found for namespace ', num, ':' )
           FROM p;

    ## requested by qq[IrcCity]
    #CALL outifexists( 'p', CONCAT( 'namespace ', num), 'p.info', 'p_title', 'out' );

    # Non-redirects
    DROP TABLE IF EXISTS nr;
    CREATE TABLE nr (
      nr_id int(8) unsigned NOT NULL default '0',
      nr_title varchar(255) binary NOT NULL default '',
      PRIMARY KEY (nr_id)
    ) ENGINE=MEMORY AS
    SELECT p_id as nr_id,
           p_title as nr_title
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

    SELECT CONCAT( ':: echo . redirects: ', count(*) )
           FROM r;

    # Categories cache for non-redirects
    # Requires @@max_heap_table_size not less than 536870912 for zero namespace.
    DROP TABLE IF EXISTS nrcat;
    CREATE TABLE nrcat (
      nrc_id int(8) unsigned NOT NULL default '0',
      nrc_to varchar(255) binary NOT NULL default '',
      KEY (nrc_id)
    ) ENGINE=MEMORY AS
    SELECT nr_id as nrc_id,
           cl_to as nrc_to
           FROM ruwiki_p.categorylinks,
                nr
           WHERE nr_id=cl_from;

    SELECT CONCAT( ':: echo ', count(*), ' categorizing links for non-redirects' )
           FROM nrcat;

    #
    # In order to exclude disambiguations from articles set,
    # disambiguation pages are collected here into d table.
    #
    CALL collect_disambig();

    #
    # Collaborative lists collected here to for links table filtering.
    # The list is superflous, i.e. contains pages outside namespace num
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
    SELECT DISTINCT nrc_id as cllt_id
           FROM nrcat
                #      secondary lists
           WHERE nrc_to='Списки_статей_для_координации_работ';

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
    # different types, since they all work as regular categories.
    #
    IF num!=14
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
        SELECT DISTINCT nrc_id as cna_id
               FROM nrcat
                     #      soft redirects
               WHERE nrc_to='Википедия:Мягкие_перенаправления';

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
      a_id int(8) unsigned NOT NULL default '0',
      a_title varchar(255) binary NOT NULL default '',
      PRIMARY KEY (a_id),
      UNIQUE KEY title (a_title)
    ) ENGINE=MEMORY AS
    SELECT nr_id as a_id,
           nr_title as a_title
           FROM nr
           WHERE nr_id NOT IN 
                 (
                  SELECT DISTINCT cna_id
                         FROM cna
                 );
    DROP TABLE cna;

    SELECT count(*) INTO acount
           FROM articles;

    SELECT CONCAT( ':: echo ', acount, ' articles found' );

    # No restriction on maximal scc size does not mean infinite
    # computational resources, but it is known for sure that maximal
    # scc size does not exceed the amount of elements in the set.
    IF @max_scc_size=0
      THEN
        SET @max_scc_size=acount;
    END IF;

    IF num=0
      THEN
        #
        # Chrono articles
        #
        DROP TABLE IF EXISTS chrono;
        CREATE TABLE chrono (
          chr_id int(8) unsigned NOT NULL default '0',
          PRIMARY KEY  (chr_id)
        ) ENGINE=MEMORY AS
        SELECT DISTINCT a_id as chr_id
               FROM articles
                     #             Common Era years 
               WHERE a_title LIKE '_!_год' escape '!' OR
                     a_title LIKE '__!_год' escape '!' OR             
                     a_title LIKE '___!_год' escape '!' OR             
                     a_title LIKE '____!_год' escape '!' OR
                     #             years B.C.
                     a_title LIKE '_!_год!_до!_н.!_э.' escape '!' OR             
                     a_title LIKE '__!_год!_до!_н.!_э.' escape '!' OR             
                     a_title LIKE '___!_год!_до!_н.!_э.' escape '!' OR             
                     a_title LIKE '____!_год!_до!_н.!_э.' escape '!' OR
                     #             decades
                     a_title LIKE '_-е' escape '!' OR             
                     a_title LIKE '__-е' escape '!' OR             
                     a_title LIKE '___-е' escape '!' OR
                     a_title LIKE '____-е' escape '!' OR
                     #             decades B.C.
                     a_title LIKE '_-е!_до!_н.!_э.' escape '!' OR             
                     a_title LIKE '__-е!_до!_н.!_э.' escape '!' OR             
                     a_title LIKE '___-е!_до!_н.!_э.' escape '!' OR
                     a_title LIKE '____-е!_до!_н.!_э.' escape '!' OR
                     #             centuries
                     a_title LIKE '_!_век' escape '!' OR
                     a_title LIKE '__!_век' escape '!' OR
                     a_title LIKE '___!_век' escape '!' OR
                     a_title LIKE '____!_век' escape '!' OR
                     a_title LIKE '_____!_век' escape '!' OR
                     a_title LIKE '______!_век' escape '!' OR
                     #             centuries B.C.
                     a_title LIKE '_!_век!_до!_н.!_э.' escape '!' OR
                     a_title LIKE '__!_век!_до!_н.!_э.' escape '!' OR
                     a_title LIKE '___!_век!_до!_н.!_э.' escape '!' OR
                     a_title LIKE '____!_век!_до!_н.!_э.' escape '!' OR
                     a_title LIKE '_____!_век!_до!_н.!_э.' escape '!' OR
                     a_title LIKE '______!_век!_до!_н.!_э.' escape '!' OR
                     #             milleniums
                     a_title LIKE '_!_тысячелетие' escape '!' OR
                     a_title LIKE '__!_тысячелетие' escape '!' OR
                     #             milleniums B.C.
                     a_title LIKE '_!_тысячелетие!_до!_н.!_э.' escape '!' OR
                     a_title LIKE '__!_тысячелетие!_до!_н.!_э.' escape '!' OR
                     a_title LIKE '___!_тысячелетие!_до!_н.!_э.' escape '!' OR
                     #             years in different application domains
                     a_title LIKE '_!_год!_в!_%' escape '!' OR
                     a_title LIKE '__!_год!_в!_%' escape '!' OR
                     a_title LIKE '___!_год!_в!_%' escape '!' OR
                     a_title LIKE '____!_год!_в!_%' escape '!' OR
                     #             calendar dates in the year
                     a_title LIKE '_!_января' escape '!' OR
                     a_title LIKE '__!_января' escape '!' OR
                     a_title LIKE '_!_февраля' escape '!' OR
                     a_title LIKE '__!_февраля' escape '!' OR
                     a_title LIKE '_!_марта' escape '!' OR
                     a_title LIKE '__!_марта' escape '!' OR
                     a_title LIKE '_!_апреля' escape '!' OR
                     a_title LIKE '__!_апреля' escape '!' OR
                     a_title LIKE '_!_мая' escape '!' OR
                     a_title LIKE '__!_мая' escape '!' OR
                     a_title LIKE '_!_июня' escape '!' OR
                     a_title LIKE '__!_июня' escape '!' OR
                     a_title LIKE '_!_июля' escape '!' OR
                     a_title LIKE '__!_июля' escape '!' OR
                     a_title LIKE '_!_августа' escape '!' OR
                     a_title LIKE '__!_августа' escape '!' OR
                     a_title LIKE '_!_сентября' escape '!' OR
                     a_title LIKE '__!_сентября' escape '!' OR
                     a_title LIKE '_!_октября' escape '!' OR
                     a_title LIKE '__!_октября' escape '!' OR
                     a_title LIKE '_!_ноября' escape '!' OR
                     a_title LIKE '__!_ноября' escape '!' OR
                     a_title LIKE '_!_декабря' escape '!' OR
                     a_title LIKE '__!_декабря' escape '!' OR
                     #             year lists by the first week day 
                     a_title LIKE 'Високосный!_год,!_начинающийся!_в%' escape '!' OR
                     a_title LIKE 'Невисокосный!_год,!_начинающийся!_в%' escape '!';

        SELECT CONCAT( ':: echo ', count(*), ' chronological articles found' )
               FROM chrono;
    END IF;

    DROP TABLE IF EXISTS pl;
    IF num!=14
      THEN

        #
        # Cahing page links to the given namespace for speedup.
        #
        # Notes: 1) Links to existant pages cached only, i.e. no "red links".
        #        2) One of the key points here is that we do not try
        #           to save pl_title to memory, the table this way will
        #           be too large.
        CREATE TABLE pl (
          pl_from int(8) unsigned NOT NULL default '0',
          pl_to int(8) unsigned NOT NULL default '0'
        ) ENGINE=MEMORY AS /* SLOW_OK */
        SELECT pl_from,
               p_id as pl_to
               FROM ruwiki_p.pagelinks,
                    p
               WHERE pl_namespace=num and
                     pl_title=p_title;

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
                             FROM p
                     );

        SELECT CONCAT( ':: echo ', count(*), ' namespace ', num, ' links point namespace ', num )
               FROM pl;

      ELSE
        #
        # Caching category links for speedup.
        #
        CREATE TABLE pl (
          pl_from int(8) unsigned NOT NULL default '0',
          pl_to int(8) unsigned NOT NULL default '0'
        ) ENGINE=MEMORY AS
        SELECT p_id as pl_from,
               nrc_id as pl_to
               FROM nrcat,
                    p
               WHERE nrc_to=p_title;

        SELECT CONCAT( ':: echo ', count(*), ' links point namespace ', num )
               FROM pl;
    END IF;

    DROP TABLE p;
  END;
//

#
# Forms wrong redirects table wr and filters redirects table appropriately.
# For namespace 14 outputs a list of all redirects because they are prohibited.
#
# Also throws redirects and redirect chains and add all redirected chains
# into pl table as regular links.
#
DROP PROCEDURE IF EXISTS cleanup_redirects//
CREATE PROCEDURE cleanup_redirects (namespace INT)
  BEGIN
    DECLARE cnt INT;
    DECLARE chainlen INT DEFAULT '1';

    # the amount of links from redirect pages in a given namespace
    DROP TABLE IF EXISTS rlc;
    CREATE TABLE rlc (
      rlc_cnt int(8) unsigned NOT NULL default '0',
      rlc_id int(8) unsigned NOT NULL default '0'
    ) ENGINE=MEMORY AS
    SELECT count(*) as rlc_cnt,
           r_id as rlc_id
           FROM pl,
                r
           WHERE pl_from=r_id
           GROUP BY r_id;

    # REDIRECT PAGES WITH MORE THAN ONE LINK
    DROP TABLE IF EXISTS wr;
    CREATE TABLE wr (
      wr_title varchar(255) binary NOT NULL default '',
      PRIMARY KEY (wr_title)
    ) ENGINE=MEMORY AS
    SELECT r_title as wr_title
           FROM r,
                rlc
           WHERE rlc_cnt>1 and
                 rlc_id=r_id;
    DROP TABLE rlc;

    CALL outifexists( 'wr', 'wrong redirects', 'wr.txt', 'wr_title', 'out' );

    # prevent taking wrong redirects into account
    DELETE FROM r
           WHERE r_title IN
                 (
                  SELECT wr_title
                         FROM wr
                 );

    IF namespace=14
      THEN
        # redirects in this namespace are prohibited
        # they do not supply articles with proper categories
        CALL outifexists( 'r', CONCAT( 'redirects for namespace ', namespace), 'r.txt', 'r_title', 'out' );
    END IF;

    #
    # Long redirects like double and triple do not work in web API,
    # thus they need to be straightened.
    #
    # Reaching the target via a long redirect requires more than one click,
    # but all hyperlink jumps are uniquely defined and can be easily fixed.
    # Here links via long redirects are threated as valid links for
    # connectivity analysis.
    #

    #
    # All links from and to redirects in our namespace.
    #
    DROP TABLE IF EXISTS r2r;
    CREATE TABLE r2r (
      r2r_to int(8) unsigned NOT NULL default '0',
      r2r_from int(8) unsigned NOT NULL default '0',
      KEY (r2r_to)
    ) ENGINE=MEMORY AS 
    SELECT r_id as r2r_to,
           pl_from as r2r_from
           FROM pl,
                r
           WHERE pl_from in
                 (
                  SELECT r_id
                         FROM r
                 ) and
                 pl_to=r_id;

    #
    # Names of redirect pages linking other redirects.
    # This table contains everything required for multiple redirects resolving.
    #
    DROP TABLE IF EXISTS mr;
    CREATE TABLE mr (
      mr_title varchar(255) binary NOT NULL default ''
    ) ENGINE=MEMORY AS
    SELECT r_title as mr_title
           FROM r2r,
                r
           WHERE r2r_from=r_id;

    CALL outifexists( 'mr', 'redirects linking redirects', 'mr.info', 'mr_title', 'upload' );

    DROP TABLE mr;

    # All links from non-redirects to redirects for a given namespace.
    DROP TABLE IF EXISTS nr2r;
    CREATE TABLE nr2r (
      nr2r_to int(8) unsigned NOT NULL default '0',
      nr2r_from int(8) unsigned NOT NULL default '0',
      KEY (nr2r_to)
    ) ENGINE=MEMORY AS 
    SELECT r_id as nr2r_to,
           pl_from as nr2r_from
           FROM pl,
                r
           WHERE pl_from in
                 (
                  SELECT nr_id 
                         FROM nr
                 ) and
                 pl_to=r_id;

    SELECT CONCAT( ':: echo ', count(*), ' links from non-redirects to redirects' )
           FROM nr2r;
           
    # All links from our namespace redirects to articles.
    DROP TABLE IF EXISTS r2nr;
    CREATE TABLE r2nr (
      r2nr_to int(8) unsigned NOT NULL default '0',
      r2nr_from int(8) unsigned NOT NULL default '0'
    ) ENGINE=MEMORY AS 
    SELECT nr_id as r2nr_to,
           pl_from as r2nr_from
           FROM pl,
                nr
           WHERE pl_from in
                 (
                  SELECT r_id
                         FROM r
                 ) and
                 pl_to=nr_id;

    SELECT count(*) INTO cnt
           FROM r2nr;

    WHILE cnt>0 DO

      SELECT CONCAT( ':: echo ', cnt, ' links from non-redirects to non-redirects via a chain of ', chainlen, ' redirects' );

      #
      # Rectify redirects adding appropriate direct links.
      #
      INSERT INTO pl
      SELECT nr2r_from as pl_from,
             r2nr_to as pl_to
             FROM nr2r,
                  r2nr
             WHERE nr2r_to=r2nr_from;

      SELECT CONCAT( ':: echo ', count(*), ' links after ', chainlen, '-redirect chains rectification' )
             FROM pl;

      #
      # One step of new long-redirect driven "links to be added" collection.
      #
      # Note: We've lost all the redirect rings here because of pure redirects
      #       in a ring unable to link non-redirects.
      #
      DROP TABLE IF EXISTS r2X2nr;
      CREATE TABLE r2X2nr (
        r2nr_to int(8) unsigned NOT NULL default '0',
        r2nr_from int(8) unsigned NOT NULL default '0'
      ) ENGINE=MEMORY;

      INSERT INTO r2X2nr
      SELECT r2nr_to,
             r2r_from as r2nr_from
             FROM r2r,
                  r2nr
             WHERE r2r_to=r2nr_from;

      DROP TABLE r2nr;

      SELECT count(*) INTO cnt
             FROM r2X2nr;

      #
      # Now X=r2X everywhere
      # 
      RENAME TABLE r2X2nr TO r2nr;

      SET chainlen=chainlen+1;

    END WHILE;

    DROP TABLE r2r;
    DROP TABLE nr2r;

  END;
//

#
# Filters links from timelines and collaboration lists.
# Also adds links to {{templated}} articles, because they cannot be
# considered as non-reachable.
#
DROP PROCEDURE IF EXISTS apply_linking_rules//
CREATE PROCEDURE apply_linking_rules (namespace INT)
  BEGIN
    IF namespace=0
      THEN

        # deletion of links from timelines
        DELETE FROM l
               WHERE l_from IN
                     (
                      SELECT chr_id
                             FROM chrono
                     );
        DROP TABLE chrono;

        SELECT CONCAT( ':: echo ', count(*), ' links after chrono-cleanup' )
               FROM l;
    END IF;

    #
    #  Well, next, if an article is {{included as a template}}
    #  it is, probably, not isolated, because it is visible
    #  even without any hyperlink jumping.
    #

    #
    # {{templating}} of articles is equivalent to links
    # from including articles to included ones.
    #

    # Articles encapsulated directly into other articles.
    # Note: Fast when templating is completely unusual for articles.
    #       Than more are templated than slower this selection.
    INSERT IGNORE INTO l
    SELECT a_id as l_to,
           tl_from as l_from
           FROM ruwiki_p.templatelinks, 
                articles
                              # donno if this is true for ns=14
                              # e.g. I cannot imagine templating of a category
           WHERE tl_namespace=namespace and
                 tl_from IN
                 (
                  SELECT a_id 
                         FROM articles
                 ) and
                 a_title=tl_title;

    SELECT CONCAT( ':: echo ', count(*), ' links after templating interpretion' )
           FROM l;

    # Articles encapsulated into other articles via our namespace redirects.
    # Note: Even slower, so pleasure if the selection result is close to empty.
    INSERT IGNORE INTO l
    SELECT a_id as l_to,
           tl_from as l_from
           FROM ruwiki_p.templatelinks, 
                r,
                r2nr,
                articles
           WHERE tl_namespace=namespace and
                 tl_from IN
                 (
                  SELECT a_id 
                         FROM articles
                 ) and
                 r_title=tl_title and
                 r2nr_from=r_id and
                 r2nr_to=a_id;

    SELECT CONCAT( ':: echo ', count(*), ' links after redirected templating interpretion' )
           FROM l;

    IF @namespace=0
      THEN
        DROP TABLE r;
    END IF;
    DROP TABLE r2nr;
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

        # deletion of links to timelines and colloborational lists,
        # recoverable, since we have a2cr
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

#
# Obtains maximal isolated subgraph of a given graph.
#
DROP PROCEDURE IF EXISTS oscchull//
CREATE PROCEDURE oscchull (OUT linkscount INT)
  BEGIN
    DECLARE prevlinkscount INT;

    REPEAT
    
      SELECT count(*) INTO prevlinkscount FROM otl;

      DROP TABLE IF EXISTS otllc;
      CREATE TABLE otllc(
        otllc_pid int(8) unsigned NOT NULL default '0',
        otllc_amnt int(8) unsigned NOT NULL default '0',
        PRIMARY KEY (otllc_pid)
      ) ENGINE=MEMORY AS
      SELECT otl_to as otllc_pid,
             count( * ) as otllc_amnt
             FROM otl
             GROUP BY otl_to;
      DELETE FROM todelete;
      INSERT INTO todelete
             SELECT lc_pid as id
                    FROM lc,
                         otllc
                    WHERE otllc_pid=lc_pid and
                          otllc_amnt!=lc_amnt;
      DELETE FROM otl
             WHERE otl_from IN
                   (
                    SELECT id
                           FROM todelete
                   );

      DELETE FROM todelete;
      INSERT INTO todelete
             SELECT DISTINCT otl_to as id
                    FROM otl
                    WHERE otl_to NOT IN
                          (
                           SELECT otl_from
                                  FROM otl
                          );
      DELETE FROM otl
             WHERE otl_to IN
                   (
                    SELECT id
                           FROM todelete
                   );

      DELETE FROM todelete;
      INSERT INTO todelete
             SELECT DISTINCT otl_from as id
                    FROM otl
                    WHERE otl_from NOT IN
                          (
                           SELECT otl_to
                                  FROM otl
                          );
      DELETE FROM otl
             WHERE otl_from IN
                   (
                    SELECT id
                           FROM todelete
                   );

      SELECT count(*) INTO linkscount FROM otl;

    UNTIL prevlinkscount=linkscount
    END REPEAT;

  END;
//

#
# CORE, DELETION OF HUGE OR LINKED SCC's
#
DROP PROCEDURE IF EXISTS filterscc//
CREATE PROCEDURE filterscc (IN rank INT)
  BEGIN
    DROP TABLE IF EXISTS newparent_grps;
    CREATE TABLE newparent_grps (
      gid int( 8 ) unsigned NOT NULL default '0'
    ) ENGINE=MEMORY AS
    SELECT DISTINCT rga.f as gid
           FROM ga,
                rga
           WHERE ga.id=rga.id AND
                 ga.f>rga.f;

    DELETE FROM todelete;
    INSERT INTO todelete
           SELECT id
                  FROM ga,
                       newparent_grps
                  WHERE f=gid;
    INSERT INTO todelete
           SELECT ga.id
                  FROM ga,
                       rga
                  WHERE ga.id=rga.id and
                        ga.f<rga.f;
    INSERT INTO todelete
           SELECT ga.id
                  FROM ga,
                       rga,
                       grp,
                       rgrp
                  WHERE grp.cnt=rgrp.cnt and
                        grp.id=rgrp.id and
                        grp.cnt>rank and
                        grp.id=ga.f and
                        rgrp.id=rga.f and
                        ga.f=rga.f and
                        ga.id=rga.id;

    DELETE FROM otl
           WHERE otl_from IN
                 (
                  SELECT id
                         FROM todelete
                 );

  END;
//

#
# Look for cluster id for each article pretending to be isolated.
#
DROP PROCEDURE IF EXISTS grpsplitga//
CREATE PROCEDURE grpsplitga ()
  BEGIN
    DECLARE changescount INT;

    # copy otl as required using a given links order
    DROP TABLE IF EXISTS eotl;
    CREATE TABLE eotl(
      eotl_from int(8) unsigned NOT NULL default '0',
      eotl_to int(8) unsigned NOT NULL default '0',
      KEY (eotl_from),
      KEY (eotl_to)
    ) ENGINE=MEMORY AS
    SELECT otl_from as eotl_from,
           otl_to as eotl_to
           FROM otl;
    # add self-links to avoid loosing minal id for articles having it
    INSERT INTO eotl
           SELECT DISTINCT otl_from as eotl_from,
                           otl_from as eotl_to
                  FROM otl;

    # initializing search with min of ids of parents as a claster id for each 
    # article
    DROP TABLE IF EXISTS ga;
    CREATE TABLE ga (
      f int(8) unsigned NOT NULL default '0',
      id int(8) unsigned NOT NULL default '0',
      PRIMARY KEY (id)
    ) ENGINE=MEMORY AS
    SELECT min(eotl_from) as f,
           eotl_to as id
           FROM eotl
           GROUP BY eotl_to;

    REPEAT

      # simple copy of ga, name changed to mftmp
      DROP TABLE IF EXISTS mftmp;
      CREATE TABLE mftmp (
        f int(8) unsigned NOT NULL default '0',
        id int(8) unsigned NOT NULL default '0',
        PRIMARY KEY (id)
      ) ENGINE=MEMORY AS
      SELECT f,
             id
             FROM ga;

      # look for parents for current minimal group id there
      DROP TABLE IF EXISTS ga;
      CREATE TABLE ga (
        f int(8) unsigned NOT NULL default '0',
        id int(8) unsigned NOT NULL default '0',
        PRIMARY KEY (id)
      ) ENGINE=MEMORY AS
      SELECT min(f) as f,
             eotl_to as id
             FROM eotl,
                  mftmp
             WHERE id=eotl_from
             GROUP BY eotl_to;

      # if there any changes occured
      SELECT count( * ) INTO changescount
             FROM ga,
                  mftmp
             WHERE mftmp.id=ga.id and
                   mftmp.f!=ga.f;

    UNTIL changescount=0
    END REPEAT;

    # making count of members for each group
    DROP TABLE IF EXISTS grp;
    CREATE TABLE grp (
      id int(8) unsigned NOT NULL default '0',
      cnt int(8) unsigned NOT NULL default '0'
    ) ENGINE=MEMORY AS
    SELECT count(*) as cnt,
           f as id
           FROM ga
           GROUP BY f;

  END;
//

#
# Look for cluster id for each article pretending to be isolated
# when all the links direction is inversed.
#
DROP PROCEDURE IF EXISTS grpsplitrga//
CREATE PROCEDURE grpsplitrga ()
  BEGIN
    DECLARE changescount INT;

    # copy otl as required using a given links order
    DROP TABLE IF EXISTS eotl;
    CREATE TABLE eotl(
      eotl_from int(8) unsigned NOT NULL default '0',
      eotl_to int(8) unsigned NOT NULL default '0',
      KEY (eotl_from),
      KEY (eotl_to)
    ) ENGINE=MEMORY AS
    SELECT otl_to as eotl_from,
           otl_from as eotl_to
           FROM otl;
    # add self-links to avoid loosing minal id for articles having it
    INSERT INTO eotl
           SELECT DISTINCT otl_to as eotl_from,
                           otl_to as eotl_to
                  FROM otl;

    # initializing search with min of ids of parents as a claster id for each 
    # article
    DROP TABLE IF EXISTS rga;
    CREATE TABLE rga (
      f int(8) unsigned NOT NULL default '0',
      id int(8) unsigned NOT NULL default '0',
      PRIMARY KEY (id)
    ) ENGINE=MEMORY AS
    SELECT min(eotl_from) as f,
           eotl_to as id
           FROM eotl
           GROUP BY eotl_to;

    REPEAT

      # simple copy of rga, name changed to mftmp
      DROP TABLE IF EXISTS mftmp;
      CREATE TABLE mftmp (
        f int(8) unsigned NOT NULL default '0',
        id int(8) unsigned NOT NULL default '0',
        PRIMARY KEY (id)
      ) ENGINE=MEMORY AS
      SELECT f,
             id
             FROM rga;

      # look for parents for current minimal group id there
      DROP TABLE IF EXISTS rga;
      CREATE TABLE rga (
        f int(8) unsigned NOT NULL default '0',
        id int(8) unsigned NOT NULL default '0',
        PRIMARY KEY (id)
      ) ENGINE=MEMORY AS
      SELECT min(f) as f,
             eotl_to as id
             FROM eotl,
                  mftmp
             WHERE id=eotl_from
             GROUP BY eotl_to;

      # if there any changes occured
      SELECT count( * ) INTO changescount
             FROM rga,
                  mftmp
             WHERE mftmp.id=rga.id and
                   mftmp.f!=rga.f;

    UNTIL changescount=0
    END REPEAT;

    # making count of members for each group
    DROP TABLE IF EXISTS rgrp;
    CREATE TABLE rgrp (
      id int(8) unsigned NOT NULL default '0',
      cnt int(8) unsigned NOT NULL default '0'
    ) ENGINE=MEMORY AS
    SELECT count(*) as cnt,
           f as id
           FROM rga
           GROUP BY f;

  END;
//

#
# Returns unique isolated category identifier by a category pseudo-name.
#
DROP FUNCTION IF EXISTS catuid//
CREATE FUNCTION catuid (coolname VARCHAR(255))
  RETURNS INT
  DETERMINISTIC
  BEGIN
    DECLARE res INT;

    SELECT uid INTO res
           FROM orcat
           WHERE coolcat=coolname;

    RETURN res;
  END;
//

#
# Identifies isolated singlets (orphanes).
#
DROP PROCEDURE IF EXISTS _1//
CREATE PROCEDURE _1 (category VARCHAR(255))
  BEGIN
    DECLARE catknown INT;
    DECLARE cntr INT;

    SELECT count(*) INTO cntr
           FROM parented
           WHERE pid NOT IN
                 (
                  SELECT lc_pid
                         FROM lc
                 );
    IF cntr>0
      THEN
        SELECT count(*) INTO catknown
               FROM orcat
               WHERE coolcat=category;

        IF catknown=0
          THEN
            INSERT INTO orcat
            SELECT 0 as uid,
                   CONCAT( 'Википедия:Изолированные_статьи/', category ) as cat,
                   category as coolcat;
        END IF;

        INSERT INTO isolated
        SELECT pid as id,
               catuid(category) as cat,
               1 as act
               FROM parented
               WHERE pid NOT IN
                     (
                      SELECT lc_pid
                             FROM lc
                     )
        # this disables any action for articles already registered properly
        ON DUPLICATE KEY UPDATE act=0;
    END IF;
  END;
//

#
# Orphaned strongly connected components (oscc) with 1 < size <= maxsize.
#
DROP PROCEDURE IF EXISTS oscc//
CREATE PROCEDURE oscc (maxsize INT, upcat VARCHAR(255))
  BEGIN
    # all links to pages having no more than maxsize-1 parenting links
    DROP TABLE IF EXISTS otl;
    CREATE TABLE otl(
      otl_to int(8) unsigned NOT NULL default '0',
      otl_from int(8) unsigned NOT NULL default '0',
      KEY (otl_from),
      KEY (otl_to)
    ) ENGINE=MEMORY AS
    SELECT DISTINCT lc_pid as otl_to,
                    l_from as otl_from
           FROM lc,
                l
           WHERE lc_pid=l_to and
                 lc_amnt<maxsize;
    DELETE FROM otl
           WHERE otl_from IN
                 (
                  SELECT id
                         FROM isolated
                         WHERE act>=0
                 );

    CALL oscchull( @alldeleted );

    # minimums flying with links
    CALL grpsplitga();

    # Now we don't know if there any SCC linked from others or orphaned only.
    # The call below repeats minimums float with the initial links set reversed
    # and puts the partitioning results to 'rga' and 'rgrp'.

    # minimums flying with reversed links
    CALL grpsplitrga();

    CALL filterscc( maxsize );

    CALL oscchull( @alldeleted );

    # Modify group set upon links cleanup
    DELETE FROM ga
           WHERE id NOT IN 
                 (
                  SELECT otl_to 
                         FROM otl
                 );

    #
    # For an article belonging to isolated cluster this table provides the
    # claster size.
    #
    DROP TABLE IF EXISTS grp;
    CREATE TABLE grp (
      id int(8) unsigned NOT NULL default '0',
      cnt int(8) unsigned NOT NULL default '0'
    ) ENGINE=MEMORY AS
    SELECT count(*) as cnt,
           f as id
           FROM ga
           GROUP BY f;

    #
    # New categories added with temporal names in order to give them an id.
    #
    INSERT IGNORE INTO orcat
    SELECT 0 as uid,
           CONCAT( 'Википедия:Изолированные_статьи/', upcat, '_', cnt ) as cat,
           CONCAT(upcat,'_',cnt) as coolcat
           FROM grp
           GROUP BY cnt;

    INSERT INTO isolated
    SELECT ga.id as id,
           catuid(CONCAT(upcat,'_',grp.cnt)) as cat,
           1 as act
           FROM ga,
                grp
           WHERE grp.id=ga.f
    # this disables any action for articles already registered properly
    ON DUPLICATE KEY UPDATE act=0;
  END;
//

#
# Look for isolated components of size less or equal to maxsize.
#
DROP PROCEDURE IF EXISTS isolated_layer//
CREATE PROCEDURE isolated_layer (maxsize INT, upcat VARCHAR(255))
  BEGIN
    IF maxsize>=1
      THEN
        # parenting links count for each parented article
        DELETE FROM lc;
        INSERT INTO lc
               SELECT l_to as lc_pid,
                      count( * ) as lc_amnt
                      FROM l
                      GROUP BY l_to;
        
        CALL _1( CONCAT(upcat, '_1') );

        IF maxsize>=2
          THEN CALL oscc( maxsize, upcat );
        END IF;

        # used only for ..._1 clasters detection,
        # provides the ability to use INSERT ... ON DUPLICATE KEY UPDATE ... there
        # select from isolated maybe is too wide
        DELETE FROM parented
               WHERE pid IN
                     (
                      SELECT id
                             FROM isolated
                             WHERE act>=0
                     );
    END IF;
  END;
//

#
# Identifies isolated clusters and sub-chains for a given chain node.
#
# Note: This procedure may need to be rewritten with a statement prepare
#       to avoid running trough all numbers from 1 upto maxsize.
#
DROP PROCEDURE IF EXISTS forest_walk//
CREATE PROCEDURE forest_walk (maxsize INT, claster_type VARCHAR(255), outprefix VARCHAR(255))
  BEGIN
    DECLARE tmp VARCHAR(255);
    DECLARE rank INT;
    DECLARE cnt INT;
    DECLARE curcatuid INT;
    DECLARE whatsinfo INT;
    DECLARE actmaxsize INT DEFAULT '1';

    CALL isolated_layer(maxsize, claster_type);

    IF maxsize>=2
      THEN
        SELECT count(*) INTO cnt
               FROM grp;
        IF cnt>0
          THEN
            SELECT MAX(grp.cnt) INTO actmaxsize
                 FROM grp;
        END IF;
    END IF;

    # all found SCC may parent others exclusively
    # search again excluding increasing SCC ranks starting from orphanes
    SET rank=1;
    WHILE rank<=actmaxsize DO
      SET tmp=CONCAT(claster_type, '_', rank );
      SET curcatuid=catuid(tmp);

      # if any SCC of type tmp found
      SELECT count( * ) INTO cnt
             FROM isolated 
             WHERE cat=curcatuid and
                   act>=0;
      IF cnt>0
        THEN
          # report on progress
          SELECT CONCAT( ':: echo ', tmp, ': ', cnt ) as title;

          SELECT CONCAT( ':: out ', @fprefix, 'stat' );
          SELECT CONCAT( outprefix, '[[:Категория:', cat, '|', tmp, ']]: ', cnt )
                 FROM orcat
                 WHERE coolcat=tmp;

          IF @enable_informative_output>0
          THEN
            SELECT CONCAT( ':: out ', @fprefix, tmp, '.info' );
            SELECT id,
                   a_title
                   FROM isolated,
                        articles
                   WHERE cat=curcatuid and
                         id=a_id and
                         act>=0
                   ORDER BY a_title ASC; 
          END IF;

          # If the orphaned category is changed for some of articles,
          # there will be two rows in the table representing each of them,
          # one for old category removal and other is a new category.
          # Let's save our edits combining remove and put operations.
          #
          # who is duped (changed category)
          DROP TABLE IF EXISTS ttt;
          CREATE TABLE ttt(
            id int(8) unsigned NOT NULL default '0'
          ) ENGINE=MEMORY AS
          SELECT id
                 FROM isolated
                 GROUP BY id 
                 HAVING count(*)>1;
          # remove operation not needed
          DELETE isolated
                 FROM isolated,
                      ttt
                 WHERE isolated.id=ttt.id and
                       isolated.act=-1;
          DROP TABLE ttt;

          IF @namespace=0
            THEN
              SET whatsinfo=1;
            ELSE
              IF @namespace=14
                THEN
                  IF @enable_informative_output>0
                    THEN
                      SET whatsinfo=1;
                    ELSE
                      SET whatsinfo=0;
                  END IF;
                ELSE
                  SET whatsinfo=0;
              END IF;
          END IF;
          IF whatsinfo=1
            THEN
              SELECT count( * ) INTO cnt
                     FROM isolated 
                     WHERE cat=curcatuid and
                           act=1;
              IF cnt>0
                THEN
                  SELECT CONCAT( ':: out ', @fprefix, tmp, '.txt' );
                  SELECT a_title
                         FROM isolated,
                              articles
                         WHERE cat=curcatuid AND
                               act=1 AND
                                id=a_id
                         ORDER BY a_title ASC;
              END IF;
          END IF;

          # prepare deep into the scc forest
          DELETE FROM l
                 WHERE l_from IN
                       (
                        SELECT id
                               FROM isolated
                               WHERE cat=curcatuid and
                                     act>=0
                       );

          # recursive call
          CALL forest_walk (maxsize, tmp, CONCAT('*', outprefix));
      END IF;
      SET rank=rank+1;
    END WHILE;
  END;
//

#
# Converts human-readable? orcat names to really usefull and clear.
#
DROP FUNCTION IF EXISTS convertcat//
CREATE FUNCTION convertcat ( wcat VARCHAR(255) )
  RETURNS VARCHAR(255)
  DETERMINISTIC
  BEGIN
    DECLARE position INT;
    DECLARE argue INT;
    DECLARE outcat VARCHAR(255) DEFAULT '';
    CASE wcat
      WHEN 'Википедия:Страницы-сироты'
        THEN
          # the proper return for simple
          RETURN '_1';
      ELSE
        SET position=LOCATE('Википедия:Изолированные_статьи/',wcat);
        IF position=1
        THEN
          # truncate the beginning of wcat
          SET wcat=SUBSTRING( wcat FROM 1+LENGTH( 'Википедия:Изолированные_статьи/' ) );
          REPEAT
            SET position=LOCATE('сирота',wcat);
            IF position=1
            THEN
              SET wcat=SUBSTRING( wcat FROM 1+LENGTH( 'сирота' ) );
              SET argue=1+CAST(wcat AS DECIMAL);
              SET outcat=CONCAT(outcat, REPEAT('_1', argue));
              SET wcat=SUBSTRING( wcat FROM 1+LENGTH( argue-1 ) );
            ELSE
              SET position=LOCATE('кольцо2',wcat);
              IF position=1
              THEN
                SET outcat=CONCAT(outcat,'_2');
                SET wcat=SUBSTRING( wcat FROM 1+LENGTH( 'кольцо2' ) );
              ELSE
                SET position=LOCATE('кластер',wcat);
                IF position=1
                  THEN
                    SET wcat=SUBSTRING( wcat FROM 1+LENGTH( 'кластер' ) );
                    SET argue=CAST(wcat AS DECIMAL);
                    IF argue<1
                    THEN
                      RETURN '_wrong_claster_size_';
                    END IF;
                    SET outcat=CONCAT(outcat, '_', argue);
                    SET wcat=SUBSTRING( wcat FROM 1+LENGTH( argue ) );
                  ELSE
                    RETURN '_wrong_specifier_';
                END IF;
              END IF;
            END IF;
          UNTIL wcat=''
          END REPEAT;
          # the proper return for complex
          RETURN outcat;
        ELSE
          RETURN '_wrong_categoryname_';
        END IF;
    END CASE;
  END;
//

#
# Obtain all the scc's and chans for scc's of size less or equal to maxsize.
#
DROP PROCEDURE IF EXISTS isolated//
CREATE PROCEDURE isolated (maxsize INT)
  BEGIN
    DECLARE tmp VARCHAR(255);
    DECLARE rank INT;
    DECLARE cnt INT;
    DECLARE overall INT;

    SELECT ':: echo isolated processing:' as title;

    # CREATING SOME TABLES FOR OUT AND TEMP

    #
    # List of claster types (category based) for isolated articles.
    #
    DROP TABLE IF EXISTS orcat;
    CREATE TABLE orcat (
      uid int(8) unsigned NOT NULL AUTO_INCREMENT,
      cat varchar(255) binary NOT NULL default '',
      coolcat varchar(255) binary NOT NULL default '',
      PRIMARY KEY (uid),
      KEY(cat),
      UNIQUE KEY(coolcat)
    ) ENGINE=MEMORY;

    IF @namespace=0
      THEN
        INSERT INTO orcat
        SELECT 0 as uid,
               page_title as cat,
               convertcat( page_title ) as coolcat
               FROM ruwiki_p.categorylinks,
                    ruwiki_p.page
                    WHERE cl_to='Википедия:Изолированные_статьи' and
                          page_id=cl_from and
                                         # this should be constant because
                                         # isolates are registered with
                                         # categories mechanism
                          page_namespace=14;
    END IF;

    #
    # Initializing main output table with currently registered 
    # isolated articles and their categories.
    #
    INSERT INTO isolated
    SELECT nrc_id as id,
           uid as cat,
           -1 as act
           FROM nrcat,
                orcat
           WHERE nrc_to=cat;

    # temporary table
    DROP TABLE IF EXISTS todelete;
    CREATE TABLE todelete (
      id int(8) unsigned NOT NULL default '0',
      PRIMARY KEY (id)
    ) ENGINE=MEMORY;

    # temporary table
    DROP TABLE IF EXISTS lc;
    CREATE TABLE lc(
      lc_pid int(8) unsigned NOT NULL default '0',
      lc_amnt int(8) unsigned NOT NULL default '0',
      PRIMARY KEY (lc_pid)
    ) ENGINE=MEMORY;

    # temporary table
    DROP TABLE IF EXISTS parented;
    CREATE TABLE parented(
      pid int(8) unsigned NOT NULL default '0',
      PRIMARY KEY (pid)
    ) ENGINE=MEMORY AS
    SELECT a_id as pid
           FROM articles
           ORDER by a_id ASC;

    # choose right limit for recursion depth allowed
    CALL forest_walk(maxsize,'','*');

    # from oscchull
    DROP TABLE IF EXISTS otllc;
    
    # from grpsplitga/rga
    DROP TABLE IF EXISTS rgrp;
    DROP TABLE IF EXISTS grp;
    DROP TABLE IF EXISTS mftmp;
    DROP TABLE IF EXISTS rga;
    DROP TABLE IF EXISTS ga;
    DROP TABLE IF EXISTS eotl;
    
    # from filterscc
    DROP TABLE IF EXISTS newparent_grps;

    # from oscc
    DROP TABLE IF EXISTS otl;

    DROP TABLE todelete;
    DROP TABLE lc;
    DROP TABLE parented;

    # ARTICLES TO BE REMOVED FROM THE CURRENT ISOLATED ARTICLES LIST

    IF @namespace=0
      THEN
        SELECT count( * ) INTO cnt
               FROM isolated 
               WHERE act=-1;

        IF cnt>0
          THEN
            SELECT CONCAT(':: echo parented isolates: ', cnt ) as title;
            SELECT CONCAT( ':: out ', @fprefix, 'orem.txt' );
            SELECT CONCAT(getnsprefix(page_namespace), page_title) as title
                   FROM isolated,
                        ruwiki_p.page
                   WHERE act=-1 AND
                         id=page_id
                   ORDER BY page_title ASC;
        END IF;
    END IF;

    #
    # Overall isolated articles count.
    #
    SELECT count(*) INTO overall
           FROM isolated
           WHERE act>=0;

    SELECT CONCAT( ':: echo ', overall, ' isolated articles found' );
    
    SELECT CONCAT( ':: out ', @fprefix, 'stat' );
    SELECT CONCAT( 'Общее количество изолированных статей: ', overall );

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

#
# Preparing data to use in external tools.
#
DROP PROCEDURE IF EXISTS outertools//
CREATE PROCEDURE outertools ()
  BEGIN
    IF @namespace!=14
      THEN
        # for sure, namespace=0

        # outer tools moved after a namespace change need to continue working
        # with categories
        DROP TABLE IF EXISTS nrcat0;
        RENAME TABLE nrcat TO nrcat0;

        # redirector refresh
        DROP TABLE IF EXISTS wr0;
        RENAME TABLE wr TO wr0;

        #
        # List of isolated articles by cluster they belong to.
        #
        DROP TABLE IF EXISTS ruwiki0;
        CREATE TABLE ruwiki0 (
          id int(8) unsigned NOT NULL default '0',
          title varchar(255) binary NOT NULL default '',
          def int(8) unsigned NOT NULL default '0',
          PRIMARY KEY (id)
        ) ENGINE=MEMORY AS
        SELECT id,
               a_title AS title,
               if( cat=catuid('_1'), 0, 1 ) AS def
               FROM isolated,
                    articles
               WHERE act>=0 and
                     id=a_id;

        #
        # For use in "ISOLATED ARTICLES FOR A CATEGORY".
        #

        #
        # Amount of articles for each category.
        # Note: Think about uncategorized articles.
        #
        DROP TABLE IF EXISTS catvolume;
        CREATE TABLE catvolume (
          cv_title varchar(255) binary NOT NULL default '',
          cv_count int(8) unsigned NOT NULL default '0',
          PRIMARY KEY (cv_title)
        ) ENGINE=MEMORY AS
        SELECT nrc_to as cv_title,
               count(*) as cv_count
               FROM nrcat0,
                    articles
               WHERE a_id=nrc_id
               GROUP BY nrc_to;

        ALTER TABLE catvolume ADD (
          cv_isocount int(8) unsigned NOT NULL default '0',
          cv_dsgcount int(8) unsigned NOT NULL default '0',
          cv_ilscount int(8) unsigned NOT NULL default '0',
          cv_tlscount int(8) unsigned NOT NULL default '0'
        );

        #
        # No need to create additional stat for isolated categories.
        # Pretend they are not exist.
        #
        DELETE catvolume
               FROM catvolume,
                    orcat
               WHERE cv_title=cat;

        DROP TABLE IF EXISTS isocat;
        CREATE TABLE isocat (
          ic_title varchar(255) binary NOT NULL default '',
          ic_count int(8) unsigned NOT NULL default '0',
          PRIMARY KEY (ic_title)
        ) ENGINE=MEMORY AS
        SELECT cv_title as ic_title,
               count( * ) as ic_count
               FROM nrcat0,
                    ruwiki0,
                    catvolume
                    WHERE id=nrc_id and
                          cv_title=nrc_to
                    GROUP BY nrc_to;

        UPDATE catvolume,
               isocat
               SET cv_isocount=ic_count
               WHERE ic_title=cv_title;
        DELETE FROM isocat;

        #
        # For use in "ISOLATES LINKED BY DISAMBIGUATIONS LINKED BY ARTICLES".
        #

        #
        # Isolated articles linked from disambiguations.
        # 
        DROP TABLE IF EXISTS d2i;
        CREATE TABLE d2i (
          d2i_from int(8) unsigned NOT NULL default '0',
          d2i_to varchar(255) binary NOT NULL default '',
          KEY (d2i_to)
        ) ENGINE=MEMORY AS
        SELECT ld_from as d2i_from,
               title as d2i_to
               FROM ruwiki0,
                    ld
               WHERE id=ld_to;

        SELECT CONCAT( ':: echo ', count(*), ' links from disambigs to isolated articles' )
               FROM d2i;

        #
        # Links from articles to articles through disambiguation pages linking isolates.
        # 
        DROP TABLE IF EXISTS a2i;
        CREATE TABLE a2i (
          a2i_from int(8) unsigned NOT NULL default '0',
          a2i_via int(8) unsigned NOT NULL default '0',
          a2i_to varchar(255) binary NOT NULL default '',
          KEY (a2i_to)
        ) ENGINE=MEMORY AS
        SELECT dl_from as a2i_from,
               d2i_from as a2i_via,
               d2i_to as a2i_to
               FROM dl,
                    d2i
               WHERE dl_to=d2i_from;

        DROP TABLE d2i;

        SELECT CONCAT( ':: echo ', count(*), ' links from articles to articles through disambiguation pages linking isolates' )
               FROM a2i;

        SELECT CONCAT( ':: echo ', count(DISTINCT a2i_to), ' isolated articles may become linked' )
               FROM a2i;

        INSERT INTO isocat
        SELECT cv_title as ic_title,
               count(DISTINCT a2i_to) as ic_count
               FROM nrcat0,
                    ruwiki0,
                    a2i,
                    catvolume
               WHERE nrc_id=id and
                     title=a2i_to and
                     nrc_to=cv_title
               GROUP BY cv_title;

        UPDATE catvolume,
               isocat
               SET cv_dsgcount=ic_count
               WHERE ic_title=cv_title;
        DELETE FROM isocat;

        DROP TABLE IF EXISTS dl;
        DROP TABLE IF EXISTS ld;
      ELSE
        # for sure, namespace=14

        #
        # For "CATEGORYTREE CONNECTIVITY".
        #

        # unnecessary table, not used unlike to ns=0
        DROP TABLE IF EXISTS nrcat;

        # redirector refresh
        DROP TABLE IF EXISTS r14;
        RENAME TABLE r TO r14;
        DROP TABLE IF EXISTS wr14;
        RENAME TABLE wr TO wr14;

        #
        # List of categorytree paths.
        #
        DROP TABLE IF EXISTS orcat14;
        CREATE TABLE orcat14 (
          uid int(8) unsigned NOT NULL AUTO_INCREMENT,
          coolcat varchar(255) binary NOT NULL default '',
          PRIMARY KEY (uid)
        ) ENGINE=MEMORY AS
        SELECT uid,
               coolcat
               FROM orcat;

        #
        # Categories as they belong to categorytree paths.
        #
        DROP TABLE IF EXISTS ruwiki14;
        CREATE TABLE ruwiki14 (
          id int(8) unsigned NOT NULL default '0',
          cat varchar(255) binary NOT NULL default '',
          title varchar(255) binary NOT NULL default '',
          PRIMARY KEY (id),
          KEY (cat)
        ) ENGINE=MEMORY AS
        SELECT id,
               orcat14.coolcat as cat,
               a_title AS title
               FROM isolated,
                    articles,
                    orcat14
               WHERE act>=0 and
                     id=a_id and
                     uid=isolated.cat;

        #
        # For use in "ISOLATES WITH LINKED INTERWIKI".
        #
        # Note: postponed because takes too much time.
        CALL inter_langs();

        # suggestor refresh
        DROP TABLE IF EXISTS isdis;
        RENAME TABLE a2i TO isdis;
        DROP TABLE IF EXISTS isres;
        RENAME TABLE res TO isres;
        DROP TABLE IF EXISTS istres;
        RENAME TABLE tres TO istres;

        # categorizer refresh
        DROP TABLE isocat;
        DROP TABLE IF EXISTS catvolume0;
        RENAME TABLE catvolume TO catvolume0;

        #
        # For use in "ISOLATED ARTICLES CREATORS".
        #
        # Note: postponed as low priority task.
        CALL by_creators();
    END IF;
  END;
//

#
# Do all the connectivity analysis.
#
DROP PROCEDURE IF EXISTS connectivity//
CREATE PROCEDURE connectivity ()
  BEGIN

    SELECT CONCAT( ':: echo NAMESPACE ', @namespace );

    # ruwiki is placed on s3 and the largest wiki on s3 is frwiki
    # when the last edit there happen?
    SELECT max( rc_timestamp ) INTO @rep_time
    FROM frwiki_p.recentchanges;

    SELECT CONCAT( ':: echo last replicated timestamp: ', @rep_time );

    #
    #  CONNECTIVITY ANALYSIS INITIALIZIATION
    #
    SELECT ':: echo init:' as title;

    SET @starttime=now();

    # how old the latest edit there is?
    SELECT CONCAT( ':: replag ', timediff(now(), @rep_time)) as title;

    IF @namespace=0
      THEN
        # permanent storage for inter-run data on statistics upload
        CREATE TABLE IF NOT EXISTS wikistat (
          ts TIMESTAMP(14) NOT NULL,
          valid int(8) unsigned NOT NULL default '0'
        ) ENGINE=MyISAM;

        # no need to keep old data, especially when stats hasn't been uploaded
        DELETE FROM wikistat
               WHERE valid=0;

        # just in case stats will be uploaded during this run
        INSERT INTO wikistat
        SELECT @rep_time as ts,
               0 as valid;
    END IF;

    # the name-prefix for all output files, distinct for each run
    SET @fprefix=CONCAT( CAST( NOW() + 0 AS UNSIGNED ), '.' );

    # preloads tables and recognizes redirects and articles
    # requires @@max_heap_table_size not less than 134217728 for zero namespace;
    CALL cache_namespace( @namespace );

    # throws redirect chains and adds paths to links collected earlier
    # also collects wrong redirects
    CALL cleanup_redirects( @namespace );

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
    SELECT a_id as l_to,
           pl_from as l_from
           FROM pl,
                articles
           WHERE pl_from in
                 (
                  SELECT a_id 
                         FROM articles
                 ) and
                 pl_to=a_id and
                 pl_from!=a_id;

    SELECT CONCAT( ':: echo ', count(*), ' links from articles to articles' )
           FROM l;

    SELECT CONCAT( ':: echo init time: ', timediff(now(), @starttime));

    #
    #  DISAMBIG LINKS PROCESSING
    #

    SET @starttime=now();

    IF @namespace!=14
      THEN
        # Constructs two tables of links:
        #  - a2d named dl;
        #  - d2a named ld.
        CALL construct_dlinks();

        #
        #  LINKS DISAMBIGUATOR
        #
        CALL disambiguator();
    END IF;

    DROP TABLE d;
    DROP TABLE nr;
    DROP TABLE pl;

    SELECT CONCAT( ':: echo links disambiguator processing time: ', timediff(now(), @starttime));

    #
    #  DEAD-END ARTICLES PROCESSING
    #
    SET @starttime=now();

    CALL deadend(@namespace);

    SELECT CONCAT( ':: echo dead-end processing time: ', timediff(now(), @starttime));

    #
    #  ISOLATED ARTICLES PROCESSING
    #
    SET @starttime=now();

    # For isolated and dead-end articles analysis some articles like
    # timelines and collaborational lists do not form relevant linking.
    # All irrelevant links are excluded from valid links here.
    # One more thing is the {{templated articles}} (if templated in articles)
    # are obviously always parented, their content is visible even without 
    # any hyperlink jumps.
    CALL apply_linking_rules( @namespace );

    #
    # Main out table for isolated articles processing.
    #
    DROP TABLE IF EXISTS isolated;
    CREATE TABLE isolated (
      id int(8) unsigned NOT NULL default '0',
      cat int(8) unsigned NOT NULL default '0',
      act int(8) signed NOT NULL default '1',
      KEY (id),
      PRIMARY KEY ( id, cat ),
      KEY (cat)
    ) ENGINE=MEMORY;

    CALL isolated( @max_scc_size );

    # this table is pretty well worn here after isolated processing
    DROP TABLE l;

    SELECT CONCAT( ':: echo isolated processing time: ', timediff(now(), @starttime));

    IF @namespace=0
      THEN
        # socket for the template maintainer
        # minimizes amount of edits combining results for deadend and isolated analysis
        CALL combineandout();

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
    END IF;

    DROP TABLE del;
  END;
//

#
# Do outer tools as appropriate.
#
DROP PROCEDURE IF EXISTS doouter//
CREATE PROCEDURE doouter ()
  BEGIN

    #
    # Prepare some usefull data for web tools.
    #
    SET @starttime=now();

    # Prepare data for use in external tools.
    CALL outertools();

    DROP TABLE articles;
    DROP TABLE isolated;
    DROP TABLE orcat;

    SELECT CONCAT( ':: echo outer tools related stuff time: ', timediff(now(), @starttime));
  END;
//

DROP PROCEDURE IF EXISTS stat_uploaded//
CREATE PROCEDURE stat_uploaded ()
  BEGIN
    # Note: Crazy mysql updates timestamp value with current timestamp,
    #       that's why need to add stupid things like ts=ts.
    UPDATE wikistat
           SET valid=1-valid,
               ts=ts;

    # no need to keep old data
    DELETE FROM wikistat
           WHERE valid=0;

    SELECT CONCAT( ':: echo isolated stat uploaded, replication timestamp is ', ts )
           FROM wikistat
           WHERE valid=1;
  END;
//

delimiter ;
############################################################

#
# This call can be now performed from outside, it does everything we need.
#
CALL connectivity();

-- </pre>
