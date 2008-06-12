 --
 -- Authors: [[:ru:user:Mashiah Davidson]], still alone
 --
 -- Caution: PROCEDUREs defined here may have output designed for handle.sh.
 --
 -- Shared procedures: inter_langs
 --
 -- <pre>

 --
 -- Significant speedup
 --

SET SESSION TRANSACTION ISOLATION LEVEL READ UNCOMMITTED;


############################################################
delimiter //

#
# Prepare interwiki based linking suggestions for one language
#
DROP PROCEDURE IF EXISTS inter_lang//
CREATE PROCEDURE inter_lang( dbname VARCHAR(32), language VARCHAR(10) )
  BEGIN
    DECLARE st VARCHAR(255);
    DECLARE prefix VARCHAR(32);
    DECLARE cnt INT;

    SELECT CONCAT( ':: echo .', language, ' . ' ) INTO prefix;

    #
    # How many pages do link interwiki partners of our isolates.
    #
    SET @st=CONCAT( 'INSERT INTO liwl SELECT /* SLOW_OK */ pl_from as fr, id as t FROM ', dbname, ".pagelinks, iwl WHERE pl_title=title and pl_namespace=0 and lang='", language, "';" );
    PREPARE stmt FROM @st;
    EXECUTE stmt;
    DEALLOCATE PREPARE stmt;

    SELECT count(*) INTO cnt
           FROM liwl;

    SELECT CONCAT( prefix, cnt, " links to isolate's interwikis found" );

    IF cnt>0
      THEN
        SET @st=CONCAT( 'INSERT INTO rinfo SELECT fr, page_is_redirect, page_title, t FROM ', dbname, '.page, liwl WHERE page_id=fr GROUP BY fr;' );
        PREPARE stmt FROM @st;
        EXECUTE stmt;
        DEALLOCATE PREPARE stmt;

        SELECT CONCAT( prefix, count(*), ' existent pages link interwiki partners' )
               FROM rinfo;

        #
        # We need no interwikified redirects for suggestion tool.
        #
        DELETE liwl
               FROM liwl,
                    rinfo
               WHERE page_is_redirect=1 and
                     rinfo.fr=liwl.fr;

        SELECT CONCAT( prefix, count(*), " links to isolate's interwikis after redirects cleanup" )
               FROM liwl;

        SET @st=CONCAT( 'INSERT INTO liwl SELECT pl_from as fr, t FROM ', dbname, '.pagelinks, rinfo WHERE page_is_redirect=1 and pl_title=page_title and pl_namespace=0;' );
        PREPARE stmt FROM @st;
        EXECUTE stmt;
        DEALLOCATE PREPARE stmt;
 
        SELECT CONCAT( prefix, count(*), " links to isolate's interwikis after redirects throwing" )
               FROM liwl;

        DELETE FROM rinfo;

        SET @st=CONCAT( 'INSERT INTO dinfo SELECT cl_from FROM d_i18n, ', dbname, ".categorylinks WHERE lang='", language, "' and cl_to=dn;" );
        PREPARE stmt FROM @st;
        EXECUTE stmt;
        DEALLOCATE PREPARE stmt;

        SELECT CONCAT( prefix, count(*), ' disambiguation pages found' )
               FROM dinfo;

        #
        # No need to suggest disambiguation pages translation.
        #
        DELETE liwl 
               FROM liwl,
                    dinfo 
               WHERE fr=did;
    
        SELECT CONCAT( prefix, count(*), " links to isolate's interwikis after disambiguations cleanup" )
               FROM liwl;

        DELETE FROM dinfo;

        SET @st=CONCAT( "INSERT INTO res SELECT REPLACE(ll_title,' ','_') as suggestn, t as id, '", language,"' as lang FROM ", dbname, ".langlinks, liwl WHERE fr=ll_from and ll_lang='ru';" );
        PREPARE stmt FROM @st;
        EXECUTE stmt;
        DEALLOCATE PREPARE stmt;

        SELECT CONCAT( prefix, count(DISTINCT id), ' isolates can be linked based on interwiki' )
               FROM res
               WHERE lang=language;

        SET @st=CONCAT( 'DELETE liwl FROM ', dbname, ".langlinks, liwl WHERE fr=ll_from and ll_lang='ru';" );
        PREPARE stmt FROM @st;
        EXECUTE stmt;
        DEALLOCATE PREPARE stmt;

        SELECT CONCAT( prefix, count(*), " links to isolate's interwikis after exclusion of already translated" )
               FROM liwl;

        SET @st=CONCAT( "INSERT INTO tres SELECT page_title as suggestn, t as id, '", language, "' as lang FROM ", dbname, '.page, liwl WHERE page_id=fr and page_namespace=0;' );
        PREPARE stmt FROM @st;
        EXECUTE stmt;
        DEALLOCATE PREPARE stmt;

        DELETE FROM liwl;

        SELECT CONCAT( prefix, count(DISTINCT id), ' isolates can be linked with main namespace pages translation' )
               FROM tres
               WHERE lang=language;
    END IF;
  END;
//

#
# Creates temporary and output tables for interwiki links analysis
#
DROP PROCEDURE IF EXISTS inter_langs_ct//
CREATE PROCEDURE inter_langs_ct()
  BEGIN
    DROP TABLE IF EXISTS iwl;
    CREATE TABLE iwl (
      id int(8) unsigned not null default '0',
      title varchar(255) not null default '',
      lang varchar(10) not null default '',
      KEY (title)
    ) ENGINE=MEMORY;

    DROP TABLE IF EXISTS d_i18n;
    CREATE TABLE d_i18n (
      lang varchar(10) binary NOT NULL default '',
      dn varchar(255) binary NOT NULL default ''
    ) ENGINE=MEMORY;

    DROP TABLE IF EXISTS liwl;
    CREATE TABLE liwl (
      fr int(8) unsigned not null default '0',
      t int(8) unsigned not null default '0',
      KEY (fr)
    ) ENGINE=MEMORY;

    DROP TABLE IF EXISTS rinfo;
    CREATE TABLE rinfo (
      fr int(8) unsigned not null default '0',
      page_is_redirect tinyint(1) unsigned not null default '0',
      page_title varchar(255) not null default '',
      t int(8) unsigned not null default '0',
      KEY (page_is_redirect, page_title)
    ) ENGINE=MEMORY;

    DROP TABLE IF EXISTS dinfo;
    CREATE TABLE dinfo (
      did int(8) unsigned not null default '0',
      PRIMARY KEY (did)
    ) ENGINE=MEMORY;

    DROP TABLE IF EXISTS res;
    CREATE TABLE res (
      suggestn varchar(255) not null default '',
      id int(8) unsigned not null default '0',
      lang varchar(10) not null default ''
    ) ENGINE=MEMORY;

    DROP TABLE IF EXISTS tres;
    CREATE TABLE tres (
      suggestn varchar(255) not null default '',
      id int(8) unsigned not null default '0',
      lang varchar(10) not null default ''
    ) ENGINE=MEMORY;

    #
    # The table just for one row with single value.
    # state is 0 when the process is running on both s2 and s3
    # state is set externally to 1 when s2 is finished and data uploaded to s3
    #
    DROP TABLE IF EXISTS communication_exchange;
    CREATE TABLE communication_exchange (
      state int(8) unsigned not null default '0'
    ) ENGINE=MEMORY;
  END;
//

#
# Prepare interwiki based linking suggestions for isolated articles.
#
DROP PROCEDURE IF EXISTS inter_langs//
CREATE PROCEDURE inter_langs()
  BEGIN
    DECLARE done INT DEFAULT 0;
    DECLARE cur_lang VARCHAR(16);
    DECLARE cur_db VARCHAR(32);
    DECLARE ready INT DEFAULT 0;
    DECLARE cur CURSOR FOR SELECT DISTINCT lang, dbname FROM toolserver.wiki WHERE family='wikipedia' and server!=2 ORDER BY size DESC;
    DECLARE CONTINUE HANDLER FOR SQLSTATE '02000' SET done = 1;

    SELECT ':: s2 init iwikispy.sql';

    SELECT ':: s2 call inter_langs_ct';
    CALL inter_langs_ct();

    #
    # Prepare interwiki links for isolated articles.
    #
    INSERT INTO iwl
    SELECT id,
           REPLACE(ll_title,' ','_') as title,
           ll_lang as lang
           FROM ruwiki_p.langlinks, 
                ruwiki0 
           WHERE id=ll_from;

    DELETE FROM iwl
           WHERE title='';

    SELECT CONCAT( ':: echo ', count(*), ' interwiki links for isolated articles found' )
           FROM iwl;

    # for transfer need to escape all quote marks
    UPDATE iwl 
           SET title=REPLACE (title, '"', '\\"')
           WHERE lang IN 
                 (
                   SELECT lang 
                          FROM toolserver.wiki
                          WHERE family='wikipedia' and
                                server=2
                 );

    #
    # Initiate interwiki transfer to s2.
    #
    SELECT ':: s2 take iwl';
    SELECT ":: s3 give SELECT CONCAT\( '\( \"', id, '\",\"', title, '\",\"', iwl.lang, '\" \)' \) FROM iwl, toolserver.wiki WHERE family='wikipedia' and server=2 and iwl.lang=toolserver.wiki.lang\;";

    #
    # Exclusion of disambiguation pages requires the categoryname.
    # We can obtain it from interwiki links fir the local disambiguations
    # category.
    #
    INSERT INTO d_i18n
    SELECT ll_lang as lang,
           REPLACE(SUBSTRING(ll_title,LOCATE(':',ll_title)+1), ' ', '_') as dn
           FROM ruwiki_p.langlinks,
                ruwiki_p.page
           WHERE page_title='Многозначные_термины' and
                 page_namespace=14 and
                 ll_from=page_id;

    #
    # Initiate the categoryname for disambigs translated to s2.
    #
    SELECT ':: s2 take d_i18n';
    SELECT ":: s3 give SELECT CONCAT\( '\( \"', d_i18n.lang, '\",\"', dn, '\" \)' \) FROM d_i18n, toolserver.wiki WHERE family='wikipedia' and server=2 and d_i18n.lang=toolserver.wiki.lang\;";

    SELECT ':: echo all transfer issued from s3';

    DROP TABLE IF EXISTS res_s2;
    CREATE TABLE res_s2 (
      suggestn varchar(255) not null default '',
      id int(8) unsigned not null default '0',
      lang varchar(10) not null default ''
    ) ENGINE=MEMORY;

    DROP TABLE IF EXISTS tres_s2;
    CREATE TABLE tres_s2 (
      suggestn varchar(255) not null default '',
      id int(8) unsigned not null default '0',
      lang varchar(10) not null default ''
    ) ENGINE=MEMORY;

    #
    # Call on s2 in parallel thread.
    # It is keeping track on data input sync.
    #
    SELECT ':: s2 prlc inter_langs_s2';

    # s1 and s3 languages loop
    OPEN cur;

    REPEAT
      FETCH cur INTO cur_lang, cur_db;
      IF NOT done
        THEN
          CALL inter_lang( cur_db, cur_lang );
      END IF;
    UNTIL done END REPEAT;

    CLOSE cur;

    DROP TABLE d_i18n;
    DROP TABLE dinfo;
    DROP TABLE rinfo;
    DROP TABLE iwl;
    DROP TABLE liwl;

    DELETE FROM res
           WHERE suggestn='';

    SELECT CONCAT( ':: echo With use of s3 ', count(DISTINCT id), ' isolates can be linked based on interwiki' )
           FROM res;

    SELECT CONCAT( ':: echo With use of s3 ', count(DISTINCT id), ' isolates can be linked with translation' )
           FROM tres;

    # Looks like an infinite loop, however, a line is to be modified externally
    # when transfer done.
    REPEAT
      # no more than once per second
      SELECT sleep( 1 ) INTO ready;
      SELECT count(*) INTO ready
             FROM communication_exchange;
    UNTIL ready=2 END REPEAT;
    DROP TABLE communication_exchange;

    # merging s2 and s3 results
    INSERT into res
    SELECT suggestn,
           id,
           lang
           FROM res_s2;
    DROP TABLE res_s2;

    INSERT into tres
    SELECT suggestn,
           id,
           lang
           FROM tres_s2;
    DROP TABLE tres_s2;

    SELECT CONCAT( ':: echo Totally, ', count(DISTINCT id), ' isolates can be linked based on interwiki' )
           FROM res;

    SELECT CONCAT( ':: echo Totally, ', count(DISTINCT id), ' isolates can be linked with translation' )
           FROM tres;

    CALL categorystats( 'res', 'sglcatvolume' );

    CALL categorystats( 'tres', 'sgtcatvolume' );

    DROP TABLE nrcatl0;

    # suggestor refresh
    DROP TABLE IF EXISTS isres;
    RENAME TABLE res TO isres;
    DROP TABLE IF EXISTS istres;
    RENAME TABLE tres TO istres;

    # categorizer refresh
    DROP TABLE IF EXISTS sglcatvolume0;
    RENAME TABLE sglcatvolume TO sglcatvolume0;
    DROP TABLE IF EXISTS sgtcatvolume0;
    RENAME TABLE sgtcatvolume TO sgtcatvolume0;

    CALL actuality( 'lsuggestor' );
    CALL actuality( 'tsuggestor' );
  END;
//

#
# Prepare interwiki based linking suggestions for isolated articles linked
# from s2 languages.
#
DROP PROCEDURE IF EXISTS inter_langs_s2//
CREATE PROCEDURE inter_langs_s2()
  BEGIN
    DECLARE done INT DEFAULT 0;
    DECLARE cur_lang VARCHAR(16);
    DECLARE cur_db VARCHAR(32);
    DECLARE ready INT DEFAULT 0;
    DECLARE cur CURSOR FOR SELECT DISTINCT lang, dbname FROM toolserver.wiki WHERE family='wikipedia' and server=2 ORDER BY size DESC;
    DECLARE CONTINUE HANDLER FOR SQLSTATE '02000' SET done = 1;

    # Looks like an infinite loop, however, a line is to be modified externally
    # when transfer done.
    REPEAT
      SELECT count(*) INTO ready
             FROM communication_exchange;
    UNTIL ready=2 END REPEAT;
    DROP TABLE communication_exchange;

    # s2 languages loop
    OPEN cur;

    REPEAT
      FETCH cur INTO cur_lang, cur_db;
      IF NOT done
        THEN
          CALL inter_lang( cur_db, cur_lang );
      END IF;
    UNTIL done END REPEAT;

    CLOSE cur;

    DROP TABLE d_i18n;
    DROP TABLE dinfo;
    DROP TABLE rinfo;
    DROP TABLE iwl;
    DROP TABLE liwl;

    DELETE FROM res
           WHERE suggestn='';

    UPDATE res
           SET suggestn=REPLACE( suggestn, '"', '\\"');

    UPDATE tres
           SET suggestn=REPLACE( suggestn, '"', '\\"');

    SELECT CONCAT( ':: echo With use of s2 ', count(DISTINCT id), ' isolates can be linked based on interwiki' )
           FROM res;

    SELECT CONCAT( ':: echo With use of s2 ', count(DISTINCT id), ' isolates can be linked with translation' )
           FROM tres;

    SELECT ':: s3 take res_s2';
    SELECT ":: s2 give SELECT CONCAT\( '\(\"', suggestn, '\",\"', id, '\",\"', lang, '\"\)' \) FROM res\;";

    SELECT ':: s3 take tres_s2';
    SELECT ":: s2 give SELECT CONCAT\( '\(\"', suggestn, '\",\"', id, '\",\"', lang, '\"\)' \) FROM tres\;";

    SELECT ':: echo all transfer issued from s2';
  END;
//

delimiter ;
############################################################

-- </pre>
