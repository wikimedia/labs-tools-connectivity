 --
 -- Autor: [[:ru:user:Mashiah Davidson]]
 --
 -- Purpose: [[:en:Connectivity (graph theory)|Connectivity]] analysis script
 --          for [[:ru:|Russian Wikipedia]].
 -- 
 -- Use: Nice to be called from 
 --      '''[[:ru:User:Mashiah_Davidson\toolserver\isolated.sh|isolated.sh]]'''.
 --
 -- Output: There is some API, which can be threated as an output API,
 --         however, for now it is much easier to deal with output of 
 --         '''isolated.sh''', as well as the output of this script is located
 --         into a set of files with mind-understandable names and content.
 --
 -- What is an article: Originally, the {{comment|Main|
 --                                               zero}} namespace has been
 --                                               itroduced for articles. 
 --                     Actually it also contains redirect pages for articles,
 --                     disambiguation pages, soft redirects and sometimes
 --                     some templates (which is wrong on my own opinion).
 --
 -- Relevant linking concept: Links from chronological articles are not too
 --                           relevant, and they are threated as links from 
 --                           a time-oriented portal.
 --                           Some articles lists are not too relevant too,
 --                           so in the future all links from lists,
 --                           which are not voted as good or gold can
 --                           also become ignored.
 --
 -- Side effect: Some double and triple redirects are also collected by the
 --              way. It is strange for me to know that mediawiki engine
 --              does not recognize most of them.
 --              Wrong redirect pages can be found somitimes, and they are
 --              wrong because they work as redirects in the web but contain
 --              some garbage links making impossible any links analysis 
 --              in the database.
 --
 -- Expected outputs: Isolated articles of various types, what's to tag
 --                   and what is to be untagged in relation to disconnexion.
 --                   The same for dead-end pages, the list is more correct
 --                   than autocollected one in terms of article definition,
 --                   id est it is smarter dealing with zero namespace.
 --             
 -- 
 -- Tune:
 --       choose the maximal oscc size
 --       for cached data
 --       5  takes up to 10 minutes,
 --       10 takes up to 15 minutes, 
 --       20 takes up to 20 minutes, 
 --       40 takes up to 25 minutes
 --       more articles requires @@max_heap_table_size=536870912
 -- <pre>

set @max_scc_size=10;

 --
 --       tune one if one of memory tables does not fit
 --

#set @@max_heap_table_size=16777216;
#set @@max_heap_table_size=33554432;
#set @@max_heap_table_size=67108864;
#set @@max_heap_table_size=134217728;
set @@max_heap_table_size=268435456;
#set @@max_heap_table_size=536870912;

 --
 --       choose right limit for recursion depth allowed
 --       set the recursion depth to 255 for the first run
 --       and then set it e.g. the critical path length doubled
 --

set max_sp_recursion_depth=10;
#set max_sp_recursion_depth=255;

 --
 -- Initialization section: threading of the initial graph
 --                         need to know what will be the number of
 --                         article, which will be got when user
 --                         clicks a link.
 --

SELECT ':: echo init:' as title;

# ruwiki is placed on s3 and the largest wiki on s3 is frwiki
# how old last edit there is?
SELECT CONCAT( ':: echo replag: ', timediff(now(), max(rc_timestamp))) as title
       FROM frwiki_p.recentchanges;

SET @fprefix=CONCAT( CAST( NOW() + 0 AS UNSIGNED ), '.' );

SET SESSION TRANSACTION ISOLATION LEVEL READ UNCOMMITTED;

# caching all zero namespace pages for speedup
# requires @@max_heap_table_size not less than 134217728;
DROP TABLE IF EXISTS `p`;
CREATE TABLE `p` (
  `p_id` int(8) unsigned NOT NULL default '0',
  `p_title` varchar(255) binary NOT NULL default '',
  `p_is_redirect` tinyint(1) unsigned NOT NULL default '0',
  PRIMARY KEY  (`p_id`),
  UNIQUE KEY `rtitle` (`p_title`)
) ENGINE=MEMORY AS
SELECT page_id as p_id,
       page_title as p_title,
       page_is_redirect as p_is_redirect
       FROM ruwiki_p.page
       WHERE page_namespace=0;

# Non-redirects from main (zero) namespace
DROP TABLE IF EXISTS `nrzn`;
CREATE TABLE `nrzn` (
  `nrzn_id` int(8) unsigned NOT NULL default '0',
  `nrzn_title` varchar(255) binary NOT NULL default ''
) ENGINE=MEMORY AS
SELECT p_id as nrzn_id,
       p_title as nrzn_title
       FROM p
       WHERE p_is_redirect=0;

# Non-articles by category in main namespace
DROP TABLE IF EXISTS `cna`;
CREATE TABLE `cna` (
  `cna_id` int(8) unsigned NOT NULL default '0',
  PRIMARY KEY  (`cna_id`)
) ENGINE=MEMORY AS
SELECT DISTINCT cl_from as cna_id
       FROM ruwiki_p.categorylinks 
#                  disambiguation pages
       WHERE cl_to='Многозначные_термины' OR
#                  soft redirects
             cl_to='Википедия:Мягкие_перенаправления';

# Articles (i.e. non-redirects and non-disambigs from main namespace)
DROP TABLE IF EXISTS `articles`;
CREATE TABLE `articles` (
  `a_id` int(8) unsigned NOT NULL default '0',
  `a_title` varchar(255) binary NOT NULL default '',
  PRIMARY KEY  (`a_id`),
  UNIQUE KEY `title` (`a_title`)
) ENGINE=MEMORY AS
SELECT nrzn_id as a_id,
       nrzn_title as a_title
       FROM nrzn
       WHERE nrzn_id NOT IN 
             (
              SELECT cna_id
                     FROM cna
             );
DROP TABLE cna;
DROP TABLE nrzn;

# Articles non-forming valid links such as chronological articles
DROP TABLE IF EXISTS `exclusions`;
CREATE TABLE `exclusions` (
  `excl_id` int(8) unsigned NOT NULL default '0',
  PRIMARY KEY  (`excl_id`)
) ENGINE=MEMORY AS
SELECT DISTINCT p_id as excl_id
       FROM p
#                         Common Era years 
       WHERE p_title LIKE '_!_год' escape '!' OR
             p_title LIKE '__!_год' escape '!' OR             
             p_title LIKE '___!_год' escape '!' OR             
             p_title LIKE '____!_год' escape '!' OR
#                         years B.C.
             p_title LIKE '_!_год!_до!_н.!_э.' escape '!' OR             
             p_title LIKE '__!_год!_до!_н.!_э.' escape '!' OR             
             p_title LIKE '___!_год!_до!_н.!_э.' escape '!' OR             
             p_title LIKE '____!_год!_до!_н.!_э.' escape '!' OR
#                         decades
             p_title LIKE '_-е' escape '!' OR             
             p_title LIKE '__-е' escape '!' OR             
             p_title LIKE '___-е' escape '!' OR
             p_title LIKE '____-е' escape '!' OR
#                         decades B.C.
             p_title LIKE '_-е!_до!_н.!_э.' escape '!' OR             
             p_title LIKE '__-е!_до!_н.!_э.' escape '!' OR             
             p_title LIKE '___-е!_до!_н.!_э.' escape '!' OR
             p_title LIKE '____-е!_до!_н.!_э.' escape '!' OR
#                         centuries
             p_title LIKE '_!_век' escape '!' OR
             p_title LIKE '__!_век' escape '!' OR
             p_title LIKE '___!_век' escape '!' OR
             p_title LIKE '____!_век' escape '!' OR
             p_title LIKE '_____!_век' escape '!' OR
             p_title LIKE '______!_век' escape '!' OR
#                         centuries B.C.
             p_title LIKE '_!_век!_до!_н.!_э.' escape '!' OR
             p_title LIKE '__!_век!_до!_н.!_э.' escape '!' OR
             p_title LIKE '___!_век!_до!_н.!_э.' escape '!' OR
             p_title LIKE '____!_век!_до!_н.!_э.' escape '!' OR
             p_title LIKE '_____!_век!_до!_н.!_э.' escape '!' OR
             p_title LIKE '______!_век!_до!_н.!_э.' escape '!' OR
#                         milleniums
             p_title LIKE '_!_тысячелетие' escape '!' OR
             p_title LIKE '__!_тысячелетие' escape '!' OR
#                         milleniums B.C.
             p_title LIKE '_!_тысячелетие!_до!_н.!_э.' escape '!' OR
             p_title LIKE '__!_тысячелетие!_до!_н.!_э.' escape '!' OR
             p_title LIKE '___!_тысячелетие!_до!_н.!_э.' escape '!' OR
#                         years in different application domains
             p_title LIKE '_!_год!_в!_%' escape '!' OR
             p_title LIKE '__!_год!_в!_%' escape '!' OR
             p_title LIKE '___!_год!_в!_%' escape '!' OR
             p_title LIKE '____!_год!_в!_%' escape '!' OR
#                         calendar dates in the year
             p_title LIKE '_!_января' escape '!' OR
             p_title LIKE '__!_января' escape '!' OR
             p_title LIKE '_!_февраля' escape '!' OR
             p_title LIKE '__!_февраля' escape '!' OR
             p_title LIKE '_!_марта' escape '!' OR
             p_title LIKE '__!_марта' escape '!' OR
             p_title LIKE '_!_апреля' escape '!' OR
             p_title LIKE '__!_апреля' escape '!' OR
             p_title LIKE '_!_мая' escape '!' OR
             p_title LIKE '__!_мая' escape '!' OR
             p_title LIKE '_!_июня' escape '!' OR
             p_title LIKE '__!_июня' escape '!' OR
             p_title LIKE '_!_июля' escape '!' OR
             p_title LIKE '__!_июля' escape '!' OR
             p_title LIKE '_!_августа' escape '!' OR
             p_title LIKE '__!_августа' escape '!' OR
             p_title LIKE '_!_сентября' escape '!' OR
             p_title LIKE '__!_сентября' escape '!' OR
             p_title LIKE '_!_октября' escape '!' OR
             p_title LIKE '__!_октября' escape '!' OR
             p_title LIKE '_!_ноября' escape '!' OR
             p_title LIKE '__!_ноября' escape '!' OR
             p_title LIKE '_!_декабря' escape '!' OR
             p_title LIKE '__!_декабря' escape '!' OR
#                         year lists by the first week day 
             p_title LIKE 'Високосный!_год,!_начинающийся!_в%' escape '!' OR
             p_title LIKE 'Невисокосный!_год,!_начинающийся!_в%' escape '!';

# List of articles forming valid links (refered as linkers below)
DROP TABLE IF EXISTS `linkers`;
CREATE TABLE `linkers` (
  `lkr_id` int(8) unsigned NOT NULL default '0',
  PRIMARY KEY  (`lkr_id`)
) ENGINE=MEMORY AS
SELECT a_id as lkr_id
       FROM articles
       WHERE a_id NOT IN 
             (
              SELECT excl_id
                     FROM exclusions
             );
DROP TABLE exclusions;

# Redirect pages in the main (zero) namespace
DROP TABLE IF EXISTS `rzn`;
CREATE TABLE `rzn` (
  `rzn_id` int(8) unsigned NOT NULL default '0',
  `rzn_title` varchar(255) binary NOT NULL default '',
  PRIMARY KEY  (`rzn_id`),
  UNIQUE KEY `rtitle` (`rzn_title`)
) ENGINE=MEMORY AS
SELECT p_id as rzn_id,
       p_title as rzn_title
       FROM p
       WHERE p_is_redirect=1;

# articles encapsulated directly into linkers
DROP TABLE IF EXISTS `ea1`;
CREATE TABLE ea1 (
  `ea1_to` int(8) unsigned NOT NULL default '0',
  `ea1_from` int(8) unsigned NOT NULL default '0'
) ENGINE=MEMORY AS
SELECT a_id as ea1_to,
       tl_from as ea1_from
       FROM ruwiki_p.templatelinks, 
            articles
       WHERE tl_namespace=0 and
             tl_from IN
             (
              SELECT lkr_id 
                     FROM linkers
             ) and
             a_title=tl_title;

# caching links to zero namespace pages for speedup
DROP TABLE IF EXISTS `pl`;
CREATE TABLE `pl` (
  `pl_from` int(8) unsigned NOT NULL default '0',
  `pl_to` int(8) unsigned NOT NULL default '0'
) ENGINE=MEMORY AS
SELECT pl_from,
       p_id as pl_to
       FROM ruwiki_p.pagelinks,
            p
       WHERE pl_namespace=0 and
             pl_title=p_title;
DROP TABLE p;

# the amount of links from main namespace redirect pages
# for wrong redirects recognition
DROP TABLE IF EXISTS `rlc`;
CREATE TABLE `rlc` (
  `rlc_cnt` int(8) unsigned NOT NULL default '0',
  `rlc_id` int(8) unsigned NOT NULL default '0'
) ENGINE=MEMORY AS
SELECT count(*) as rlc_cnt,
       rzn_id as rlc_id
       FROM pl,
            rzn
       WHERE pl_from=rzn_id
       GROUP BY rzn_id;

# REDIRECT PAGES WITH MORE THAN ONE LINK
DROP TABLE IF EXISTS `wr`;
CREATE TABLE `wr` (
  `wr_title` varchar(255) binary NOT NULL default '',
  PRIMARY KEY (`wr_title`)
) ENGINE=MEMORY AS
SELECT rzn_title as wr_title
       FROM rzn,
            rlc
       WHERE rlc_cnt>1 and
             rlc_id=rzn_id;
DROP TABLE rlc;

############################################################
delimiter //

DROP PROCEDURE IF EXISTS outifexists//
CREATE PROCEDURE outifexists ( tablename VARCHAR(255), outt VARCHAR(255), outf VARCHAR(255), ordercol VARCHAR(255) )
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
      SELECT CONCAT(':: out ', @fprefix, outf ) as title;

      SET @st2=CONCAT( 'SELECT * FROM ', tablename, ' ORDER BY ', ordercol, ' ASC' );
      PREPARE stmt FROM @st2;
      EXECUTE stmt;
      DEALLOCATE PREPARE stmt;
      SELECT '';
    END IF;
  END;
//
      
delimiter ;
############################################################

CALL outifexists( 'wr', 'wrong redirects', 'wr.txt', 'wr_title' );

# prevent taking into account links from wrong redirects
DELETE FROM rzn
       WHERE rzn_title IN
             (
              SELECT wr_title
                     FROM wr
             );

# articles encapsulated into linkers via main namespace redirects
DROP TABLE IF EXISTS `ea2`;
CREATE TABLE ea2 (
  `ea2_to` int(8) unsigned NOT NULL default '0',
  `ea2_from` int(8) unsigned NOT NULL default '0'
) ENGINE=MEMORY AS
SELECT a_id AS ea2_to,
       tl_from as ea2_from
       FROM ruwiki_p.templatelinks, 
            rzn,
            pl,
            articles
       WHERE tl_namespace=0 and
             tl_from IN
             (
              SELECT lkr_id 
                     FROM linkers
             ) and
             rzn_title=tl_title and
             pl_from=rzn_id and
             pl_to=a_id;

# articles linked directly from linkers
DROP TABLE IF EXISTS `l2a`;
CREATE TABLE l2a (
  `l2a_to` int(8) unsigned NOT NULL default '0',
  `l2a_from` int(8) unsigned NOT NULL default '0'
) ENGINE=MEMORY AS 
SELECT a_id as l2a_to,
       pl_from as l2a_from
       FROM pl,
            articles
       WHERE pl_from in
       (
        SELECT lkr_id 
               FROM linkers
       ) and
       pl_to=a_id and
       pl_from!=a_id;

# all links from linkers to main namespace redirects
DROP TABLE IF EXISTS `l2r`;
CREATE TABLE `l2r` (
  `l2r_to` int(8) unsigned NOT NULL default '0',
  `l2r_from` int(8) unsigned NOT NULL default '0',
  KEY (`l2r_to`)
) ENGINE=MEMORY AS 
SELECT rzn_id as l2r_to,
       pl_from as l2r_from
       FROM pl,
            rzn
       WHERE pl_from in
       (
        SELECT lkr_id 
               FROM linkers
       ) and
       pl_to=rzn_id;

# all links from linked main namespace redirects to articles
DROP TABLE IF EXISTS `mnrl`;
CREATE TABLE `mnrl` (
  `mnrl_to` int(8) unsigned NOT NULL default '0',
  `mnrl_from` int(8) unsigned NOT NULL default '0'
) ENGINE=MEMORY AS 
SELECT a_id as mnrl_to,
       pl_from as mnrl_from
       FROM pl,
            articles
       WHERE pl_from in
             (
              SELECT l2r_to
                     FROM l2r
             ) and
             pl_to=a_id;

# articles linked from linkers via a main namespace redirect
DROP TABLE IF EXISTS `l2r2a`;
CREATE TABLE l2r2a (
  `l2r2a_to` int(8) unsigned NOT NULL default '0',
  `l2r2a_from` int(8) unsigned NOT NULL default '0'
) ENGINE=MEMORY AS 
SELECT l2r_from as l2r2a_from,
       mnrl_to as l2r2a_to
       FROM mnrl,
            l2r
       WHERE mnrl_from=l2r_to and
             mnrl_to!=l2r_from;
DROP TABLE mnrl;

# all links from main namespace redirects to articles
DROP TABLE IF EXISTS `rrl`;
CREATE TABLE `rrl` (
  `rrl_to` int(8) unsigned NOT NULL default '0',
  `rrl_from` int(8) unsigned NOT NULL default '0'
) ENGINE=MEMORY AS 
SELECT a_id as rrl_to,
       pl_from as rrl_from
       FROM pl,
            articles
       WHERE pl_from in
       (
        SELECT rzn_id
               FROM rzn
       ) and
       pl_to=a_id;

# all links from linked main namespace redirects to main namespace redirects
# there are a lot of double redirects but here only linked are considered
DROP TABLE IF EXISTS r2r;
CREATE TABLE `r2r` (
  `r2r_to` int(8) unsigned NOT NULL default '0',
  `r2r_from` int(8) unsigned NOT NULL default '0'
) ENGINE=MEMORY AS 
SELECT rzn_id as r2r_to,
       pl_from as r2r_from
       FROM pl,
            rzn
       WHERE pl_from in
       (
        SELECT l2r_to
               FROM l2r
       ) and
       pl_to=rzn_id;
DROP TABLE pl;

# all links from redirects to articles via one more redirect
DROP TABLE IF EXISTS `r2r2a`;
CREATE TABLE r2r2a (
  `r2r2a_to` int(8) unsigned NOT NULL default '0',
# next one is for people who like double redirects resolving
  `r2r2a_via` int(8) unsigned NOT NULL default '0',
  `r2r2a_from` int(8) unsigned NOT NULL default '0'
) ENGINE=MEMORY AS 
SELECT r2r_from as r2r2a_from,
# next one is for people who like double redirects resolving
       r2r_to as r2r2a_via,
       rrl_to as r2r2a_to
       FROM rrl,
            r2r
       WHERE rrl_from=r2r_to;
DROP TABLE rrl;

# DOUBLE REDIRECTS
DROP TABLE IF EXISTS `dr`;
CREATE TABLE dr (
  `dr_from` varchar(255) binary NOT NULL default '',
  `dr_via` varchar(255) binary NOT NULL default '',
  `dr_to` varchar(255) binary NOT NULL default ''
) ENGINE=MEMORY AS
SELECT r1.rzn_title as dr_from,
       r2.rzn_title as dr_via,
       a_title as dr_to
       FROM r2r2a,
            rzn as r1,
            rzn as r2,
            articles
       WHERE r2r2a_from=r1.rzn_id and
             r2r2a_via=r2.rzn_id and
             r2r2a_to=a_id;

CALL outifexists( 'dr', 'double redirects', 'dr.txt', 'dr_from' );

# all links from redirects to articles via one more redirect
DROP TABLE IF EXISTS `l2r2r2a`;
CREATE TABLE l2r2r2a (
  `l2r2r2a_to` int(8) unsigned NOT NULL default '0',
  `l2r2r2a_from` int(8) unsigned NOT NULL default '0'
) ENGINE=MEMORY AS 
SELECT l2r_from as l2r2r2a_from,
       r2r2a_to as l2r2r2a_to
       FROM l2r,
            r2r2a
       WHERE l2r_to=r2r2a_from and
             l2r_from!=r2r2a_to;

# long chain as described by the name of the table
DROP TABLE IF EXISTS `r2r2r2a`;
CREATE TABLE r2r2r2a (
  `r2r2r2a_to` int(8) unsigned NOT NULL default '0',
# next two are for people who like double redirects resolving
  `r2r2r2a_via1` int(8) unsigned NOT NULL default '0',
  `r2r2r2a_via2` int(8) unsigned NOT NULL default '0',
  `r2r2r2a_from` int(8) unsigned NOT NULL default '0'
) ENGINE=MEMORY AS 
SELECT r2r_from as r2r2r2a_from,
# next two are for people who like double redirects resolving
       r2r_to as r2r2r2a_via1,
       r2r2a_via as r2r2r2a_via2,
       r2r2a_to as r2r2r2a_to
       FROM r2r,
            r2r2a
       WHERE r2r_to=r2r2a_from;
DROP TABLE r2r;
DROP TABLE r2r2a;

# TRIPLE REDIRECTS
DROP TABLE IF EXISTS `tr`;
CREATE TABLE tr (
  `tr_from` varchar(255) binary NOT NULL default '',
  `tr_via1` varchar(255) binary NOT NULL default '',
  `tr_via2` varchar(255) binary NOT NULL default '',
  `tr_to` varchar(255) binary NOT NULL default ''
) ENGINE=MEMORY AS
SELECT r1.rzn_title as tr_from,
       r2.rzn_title as tr_via1,
       r3.rzn_title as tr_via2,
       a_title as tr_to
       FROM r2r2r2a,
            rzn as r1,
            rzn as r2,
            rzn as r3,
            articles
       WHERE r2r2r2a_from=r1.rzn_id and
             r2r2r2a_via1=r2.rzn_id and
             r2r2r2a_via2=r3.rzn_id and
             r2r2r2a_to=a_id;
DROP TABLE rzn;

CALL outifexists( 'tr', 'triple redirects', 'tr.txt', 'tr_from' );

# all links from redirects to articles via one more redirect
DROP TABLE IF EXISTS `l2r2r2r2a`;
CREATE TABLE l2r2r2r2a (
  `l2r2r2r2a_to` int(8) unsigned NOT NULL default '0',
  `l2r2r2r2a_from` int(8) unsigned NOT NULL default '0'
) ENGINE=MEMORY AS 
SELECT l2r_from as l2r2r2a_from,
       r2r2r2a_to as l2r2r2r2a_to
       FROM l2r,
            r2r2r2a
       WHERE l2r_to=r2r2r2a_from and
             l2r_from!=r2r2r2a_to;
DROP TABLE l2r;
DROP TABLE r2r2r2a;

# all links to be taken into account
# requires @@max_heap_table_size no less than 268435456;
DROP TABLE IF EXISTS `l`;
CREATE TABLE `l` (
  `l_to` int(8) unsigned NOT NULL default '0',
  `l_from` int(8) unsigned NOT NULL default '0',
  PRIMARY KEY (`l_to`,`l_from`)
) ENGINE=MEMORY;
INSERT IGNORE INTO `l`
       SELECT l2a_to as l_to,
              l2a_from as l_from
              FROM l2a;
DROP TABLE l2a;
INSERT IGNORE INTO `l`
       SELECT l2r2a_to as l_to,
              l2r2a_from as l_from
              FROM l2r2a;
DROP TABLE l2r2a;
INSERT IGNORE INTO `l`
       SELECT l2r2r2a_to as l_to,
              l2r2r2a_from as l_from
              FROM l2r2r2a;
DROP TABLE l2r2r2a;
INSERT IGNORE INTO `l`
       SELECT l2r2r2r2a_to as l_to,
              l2r2r2r2a_from as l_from
              FROM l2r2r2r2a;
DROP TABLE l2r2r2r2a;
INSERT IGNORE INTO `l`
       SELECT ea1_to as l_to,
              ea1_from as l_from
              FROM ea1;
DROP TABLE ea1;
INSERT IGNORE INTO `l`
       SELECT ea2_to as l_to,
              ea2_from as l_from
              FROM ea2;
DROP TABLE ea2;

# Begin the procedure for dead end pages
SELECT ':: echo dead end pages processing:' as title;

# linkers with links to articles
DROP TABLE IF EXISTS `lwl`;
CREATE TABLE `lwl` (
  `lwl_id` int(8) unsigned NOT NULL default '0',
  PRIMARY KEY (`lwl_id`)
) ENGINE=MEMORY AS 
SELECT DISTINCT l_from as lwl_id
       FROM l;

# DEAD-END LINKERS
DROP TABLE IF EXISTS `del`;
CREATE TABLE del (
  `del_id` int(8) unsigned NOT NULL default '0',
  `del_title` varchar(255) binary NOT NULL default '',
  PRIMARY KEY (`del_id`)
) ENGINE=MEMORY AS 
SELECT lkr_id as del_id,
       a_title as del_title
       FROM linkers,
            articles
       WHERE lkr_id NOT IN 
       (
        SELECT lwl_id
               FROM lwl
       ) and
       a_id=lkr_id;
DROP TABLE lwl;
DROP TABLE linkers;

CALL outifexists( 'del', 'total', 'de.info', 'del_title' );

############################################################
delimiter //

DROP FUNCTION IF EXISTS getnsprefix//
CREATE FUNCTION getnsprefix ( ns INT )
  RETURNS VARCHAR(255)
  DETERMINISTIC
  BEGIN
    CASE ns
      WHEN 0
        THEN
          RETURN '';
      WHEN 1
        THEN
          RETURN 'Обсуждение:';
      WHEN 2
        THEN
          RETURN 'Участник:';
      WHEN 3
        THEN
          RETURN 'Обсуждение_участника:';
      WHEN 4
        THEN
          RETURN 'Википедия:';
      WHEN 5
        THEN
          RETURN 'Обсуждение_Википедии:';
      WHEN 6
        THEN
          RETURN 'Изображение:';
      WHEN 7
        THEN
          RETURN 'Обсуждение_изображения:';
      WHEN 8
        THEN
          RETURN 'MediaWiki:';
      WHEN 9
        THEN
          RETURN 'Обсуждение_MediaWiki:';
      WHEN 10
        THEN
          RETURN 'Шаблон:';
      WHEN 11
        THEN
          RETURN 'Обсуждение_шаблона:';
      WHEN 12
        THEN
          RETURN 'Справка:';
      WHEN 13
        THEN
          RETURN 'Обсуждение_справки:';
      WHEN 14
        THEN
          RETURN 'Категория:';
      WHEN 15
        THEN
          RETURN 'Обсуждение_категории:';
      ELSE
        RETURN 'unknownnamespace:';
    END CASE;
  END;
//

delimiter ;
############################################################

# DEAD-END PAGES REGISTERED AT THE MOMENT
DROP TABLE IF EXISTS `cur`;
CREATE TABLE `cur` (
  `id` int(8) unsigned NOT NULL default '0',
  `title` varchar(255) binary NOT NULL default '',
  PRIMARY KEY (`id`)
) ENGINE=MEMORY AS
SELECT cl_from as id,
       CONCAT(getnsprefix(page_namespace), page_title) as title
       FROM ruwiki_p.categorylinks,
            ruwiki_p.page
#                  a category registering deadend articles
       WHERE cl_to='Википедия:Тупиковые_статьи' and
             page_id=cl_from;

DROP TABLE IF EXISTS `delset`;
CREATE TABLE `delset` (
  `del_title` varchar(255) binary NOT NULL default ''
) ENGINE=MEMORY AS
SELECT del_title
       FROM del 
       WHERE del_id NOT IN
             (
              SELECT id
                     FROM cur
             );

CALL outifexists( 'delset', '+', 'deset.txt', 'del_title' );

DROP TABLE IF EXISTS `delrem`;
CREATE TABLE `delrem` (
  `delr_title` varchar(255) binary NOT NULL default ''
) ENGINE=MEMORY AS
SELECT title as delr_title
       FROM cur
       WHERE id NOT IN
             (
              SELECT del_id
                     FROM del
             );
DROP TABLE IF EXISTS cur;

CALL outifexists( 'delrem', '-', 'derem.txt', 'delr_title' );

# END OF DEAD-END LINKERS

############################################################
delimiter //

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

# CORE, DELETION OF HUGE OR LINKED SCC's
DROP PROCEDURE IF EXISTS filterscc//
CREATE PROCEDURE filterscc (IN rank INT)
  BEGIN
    DELETE FROM todelete;
    INSERT INTO todelete
           SELECT id
                  FROM ga
                  WHERE f IN
                        (
                         SELECT DISTINCT rga.f
                                FROM ga,
                                     rga
                                WHERE ga.id=rga.id AND
                                      ga.f>rga.f
                        );
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

      # simple copy of ga, name changed to mftmp
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

# singlets
DROP PROCEDURE IF EXISTS _1//
CREATE PROCEDURE _1 (category VARCHAR(255))
  BEGIN
    INSERT IGNORE INTO isolated
    SELECT a_id as id,
           a_title as title,
           category as cat,
           1 as act
           FROM articles
           WHERE a_id NOT IN
                 (
                  SELECT lc_pid
                         FROM lc
                 );
  END;
//

# orphaned strongly connected components (oscc) of size <= maxsize
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

    DROP TABLE IF EXISTS grp;
    CREATE TABLE grp (
      id int(8) unsigned NOT NULL default '0',
      cnt int(8) unsigned NOT NULL default '0'
    ) ENGINE=MEMORY AS
    SELECT count(*) as cnt,
           f as id
           FROM ga
           GROUP BY f;

    INSERT IGNORE INTO isolated
    SELECT ga.id as id,
           a_title as title,
           CONCAT(upcat,'_',grp.cnt) as cat,
           1 as act
           FROM ga,
                grp,
                articles
           WHERE grp.id=ga.f and
                 ga.id=a_id;
  END;
//

DROP PROCEDURE IF EXISTS isolated_layer//
CREATE PROCEDURE isolated_layer (maxsize INT, upcat VARCHAR(255))
  BEGIN
    # parenting links count for each parented article
    DELETE FROM lc;
    INSERT INTO lc
           SELECT l_to as lc_pid,
                  count( * ) as lc_amnt
                  FROM l
                  GROUP BY l_to;

    IF maxsize>=1
      THEN CALL _1( CONCAT(upcat, '_1') );
    END IF;

    IF maxsize>=2
      THEN CALL oscc( maxsize, upcat );
    END IF;
  END;
//

#
# This procedure may need to be rewritten with a statement prepare
# to avoid running trough all numbers from 1 upto maxsize
#
#
DROP PROCEDURE IF EXISTS forest_walk//
CREATE PROCEDURE forest_walk (maxsize INT, claster_type VARCHAR(255), outprefix VARCHAR(255))
  BEGIN
    DECLARE tmp VARCHAR(255);
    DECLARE rank INT;
    DECLARE cnt INT;
    DECLARE catknown INT;

    CALL isolated_layer(maxsize, claster_type);

    # all found SCC may parent others exclusively
    # search again excluding increasing SCC ranks starting from orphanes
    SET rank=1;
    WHILE rank<=maxsize DO
      SET tmp=CONCAT(claster_type, '_', rank );

      # if any SCC of type tmp found
      SELECT count( * ) INTO cnt
             FROM isolated 
             WHERE cat=tmp;
      IF cnt>0
        THEN
          # report on progress
          SELECT CONCAT( ':: echo ', tmp ) as title;

          SELECT count(*) INTO catknown
                 FROM orcat
                 WHERE coolcat=tmp;

          IF catknown=0
            THEN
              INSERT INTO orcat
              SELECT 0 as uid,
                     CONCAT( 'Википедия:Изолированные_статьи/', tmp ) as cat,
                     tmp as coolcat;
          END IF;


          SELECT CONCAT( ':: out ', @fprefix, 'stat' );
          SELECT CONCAT( outprefix, '[[:Категория:', cat, '|', tmp, ']]: ', cnt )
                 FROM orcat
                 WHERE coolcat=tmp;

          SELECT CONCAT( ':: out ', @fprefix, tmp, '.info' );
          SELECT id,
                 title
                 FROM isolated
                 WHERE cat=tmp
                 ORDER BY title ASC; 

          # mark known ones
          UPDATE IGNORE isolated
                 SET act=0
                 WHERE cat=tmp and
                       id IN
                       (
                        SELECT id
                               FROM oc,
                                    orcat
                               WHERE catid=uid and
                                     coolcat=tmp
                       );

          SELECT count( * ) INTO cnt
                 FROM isolated 
                 WHERE cat=tmp and
                       act=1;
          IF cnt>0
            THEN
              SELECT CONCAT( ':: out ', @fprefix, tmp, '.txt' );
              SELECT title
                     FROM isolated
                     WHERE cat=tmp AND
                           act=1
                     ORDER BY title ASC;
          END IF;

          # prepare deep into the scc forest
          DELETE FROM l
                 WHERE l_from IN
                       (
                        SELECT id
                               FROM isolated
                               WHERE cat=tmp
                       );

          # recursive call
          CALL forest_walk (maxsize, tmp, CONCAT('*', outprefix));
      END IF;
      SET rank=rank+1;
    END WHILE;
  END;
//

# converts human-readable? orcat names to really usefull and clear
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


DROP PROCEDURE IF EXISTS isolated//
CREATE PROCEDURE isolated (maxsize INT)
  BEGIN
    DECLARE tmp VARCHAR(255);
    DECLARE rank INT;
    DECLARE cnt INT;

    SELECT ':: echo isolated processing:' as title;

    # CREATING SOME TABLES FOR OUT AND TEMP

    # list of subcategory names for isolated articles
    DROP TABLE IF EXISTS orcat;
    CREATE TABLE orcat (
      uid int(8) unsigned NOT NULL AUTO_INCREMENT,
      cat varchar(255) binary NOT NULL default '',
      coolcat varchar(255) binary NOT NULL default '',
      PRIMARY KEY (uid),
      KEY( cat )
    ) ENGINE=MEMORY AS
    SELECT page_title as cat,
           convertcat( page_title ) as coolcat
           FROM ruwiki_p.categorylinks,
                ruwiki_p.page
                WHERE cl_to='Википедия:Изолированные_статьи' and
                      page_id=cl_from and
                      page_namespace=14;

    # currently registered isolated articles and their categories
    DROP TABLE IF EXISTS oc;
    CREATE TABLE `oc` (
      id int(8) unsigned NOT NULL default '0',
      title varchar(255) binary NOT NULL default '',
      catid int(8) unsigned NOT NULL default '0',
      PRIMARY KEY (id)
    ) ENGINE=MEMORY AS
      SELECT cl_from as id,
             CONCAT(getnsprefix(page_namespace), page_title) as title,
             uid as catid
             FROM ruwiki_p.categorylinks,
                  ruwiki_p.page,
                  orcat
             WHERE cl_to=cat and
                   page_id=cl_from;

    # main out table
    DROP TABLE IF EXISTS isolated;
    CREATE TABLE isolated (
      id int(8) unsigned NOT NULL default '0',
      title varchar(255) binary NOT NULL default '',
      cat varchar(255) binary NOT NULL default '',
      act int(8) signed NOT NULL default '1',
      PRIMARY KEY (id),
      KEY (cat)
    ) ENGINE=MEMORY; 

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
    
    # from oscc
    DROP TABLE IF EXISTS otl;

    DROP TABLE todelete;
    DROP TABLE lc;

    # ARTICLES TO BE REMOVED FROM THE CURRENT ISOLATED ARTICLES LIST
    DROP TABLE IF EXISTS `orem`;
    CREATE TABLE `orem` (
      `or_title` varchar(255) binary NOT NULL default ''
    ) ENGINE=MEMORY AS
    SELECT title as or_title
           FROM oc
           WHERE id NOT IN
                 (
                  SELECT id
                         FROM isolated
                 );

    DROP TABLE oc;

    CALL outifexists( 'orem', 'linked isolates', 'orem.txt', 'or_title' );
  END;
//

delimiter ;
############################################################

CALL isolated( @max_scc_size );

DROP TABLE l;
DROP TABLE articles;

DROP TABLE IF EXISTS catvolume;
CREATE TABLE catvolume (
  `cv_title` varchar(255) binary NOT NULL default '',
  `cv_count` int(8) unsigned NOT NULL default '0',
  PRIMARY KEY (cv_title)
) ENGINE=MEMORY AS
SELECT cl_to as cv_title,
       count(*) as cv_count
       FROM ruwiki_p.categorylinks,
            ruwiki_p.page
       WHERE page_id=cl_from and
             page_namespace=0
       GROUP BY cl_to;

-- </pre>