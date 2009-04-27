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
CREATE PROCEDURE inter_lang( dbname VARCHAR(32), language VARCHAR(10), mlang VARCHAR(10) )
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

        SET @st=CONCAT( "INSERT INTO res SELECT REPLACE(ll_title,' ','_') as suggestn, t as id, '", language,"' as lang FROM ", dbname, ".langlinks, liwl WHERE fr=ll_from and ll_lang='", mlang, "';" );
        PREPARE stmt FROM @st;
        EXECUTE stmt;
        DEALLOCATE PREPARE stmt;

        SELECT CONCAT( prefix, count(DISTINCT id), ' isolates can be linked based on interwiki' )
               FROM res
               WHERE lang=language;

        SET @st=CONCAT( 'DELETE liwl FROM ', dbname, ".langlinks, liwl WHERE fr=ll_from and ll_lang='", mlang, "';" );
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
    # The table just for one row for single value named state.
    #
    # During any transfer the receiver state is being updated by the sender.
    #
    DROP TABLE IF EXISTS communication_exchange;
    CREATE TABLE communication_exchange (
      state int(8) unsigned not null default '0'
    ) ENGINE=MEMORY;
  END;
//

#
# This procedure is being run on the master-host (s3). It insects slave-hosts
# with its code and tables, initialtes transfer of initial data from master to
# slaves
# 
#
# Prepare interwiki based linking suggestions for isolated articles.
#
DROP PROCEDURE IF EXISTS inter_langs//
CREATE PROCEDURE inter_langs( srv INT )
  BEGIN
    DECLARE done INT DEFAULT 0;
    DECLARE cur_lang VARCHAR(16);
    DECLARE cur_db VARCHAR(32);
    DECLARE ready INT DEFAULT 0;
    DECLARE cur_sv INT DEFAULT 0;
    DECLARE dsync INT DEFAULT 0;
    DECLARE st VARCHAR(511);
    DECLARE cur CURSOR FOR SELECT DISTINCT lang, dbname FROM toolserver.wiki WHERE family='wikipedia' and server=srv ORDER BY size DESC;
    DECLARE scur CURSOR FOR SELECT DISTINCT server FROM toolserver.wiki WHERE family='wikipedia' and server!=srv ORDER BY server ASC;
    DECLARE CONTINUE HANDLER FOR SQLSTATE '02000' SET done = 1;

    #
    # Insect slave servers with this library code 
    # and inform them on who is the master.
    #
    OPEN scur;
    SET done = 0;

    REPEAT
      FETCH scur INTO cur_sv;
      IF NOT done
        THEN
          SELECT CONCAT( ':: s', cur_sv, ' init iwikispy.sql' );
      END IF;
    UNTIL done END REPEAT;

    CLOSE scur;

    #
    # Insect everyone with necessary communication tables.
    #
    OPEN scur;
    SET done = 0;

    REPEAT
      FETCH scur INTO cur_sv;
      IF NOT done
        THEN
          SELECT CONCAT( ':: s', cur_sv, ' call inter_langs_ct' );
      END IF;
    UNTIL done END REPEAT;

    CLOSE scur;

    CALL inter_langs_ct();

    #
    # Prepare interwiki links for isolated articles.
    #
    SET @st=CONCAT( 'INSERT INTO iwl SELECT id, REPLACE(ll_title,', "' ','_'", ') as title, ll_lang as lang FROM ', @target_lang, 'wiki_p.langlinks, ruwiki0 WHERE id=ll_from;' );
    PREPARE stmt FROM @st;
    EXECUTE stmt;
    DEALLOCATE PREPARE stmt;

    DELETE FROM iwl
           WHERE title='';

    SELECT CONCAT( ':: echo ', count(*), ' interwiki links for isolated articles found' )
           FROM iwl;

    #
    # Prior to any transfer we need to escape quote marks.
    #
    # Note: master host languages may be left not updated due to no transfer.
    #
    UPDATE iwl 
           SET title=REPLACE (title, '"', '\\"')
           WHERE lang IN 
                 (
                   SELECT lang 
                          FROM toolserver.wiki
                          WHERE family='wikipedia' and
                                server!=srv
                 );

    #
    # Initiate interwiki transfer to slaves.
    #
    OPEN scur;
    SET done = 0;

    REPEAT
      FETCH scur INTO cur_sv;
      IF NOT done
        THEN
          SELECT CONCAT( ':: s', cur_sv, ' take iwl' );
          SELECT CONCAT( ":: s", srv, " give SELECT CONCAT\( '\( \"', id, '\",\"', title, '\",\"', iwl.lang, '\" \)' \) FROM iwl, toolserver.wiki WHERE family='wikipedia' and server=", cur_sv, " and iwl.lang=toolserver.wiki.lang\;" );
      END IF;
    UNTIL done END REPEAT;

    CLOSE scur;

    #
    # Exclusion of disambiguation pages requires the categoryname.
    # We can obtain it from interwiki links for the local disambiguations
    # category.
    #
    SET @st=CONCAT( 'INSERT INTO d_i18n SELECT ll_lang as lang, REPLACE(SUBSTRING(ll_title,LOCATE(', "':'", ',ll_title)+1), ', "' ', '_'", ') as dn FROM ', @target_lang, 'wiki_p.langlinks, ', @target_lang, 'wiki_p.page WHERE page_title=', "'", 'Многозначные_термины', "'", ' and page_namespace=14 and ll_from=page_id;' );
    PREPARE stmt FROM @st;
    EXECUTE stmt;
    DEALLOCATE PREPARE stmt;

    #
    # Initiate distribution of translated disambig categoryname.
    #
    OPEN scur;
    SET done = 0;

    REPEAT
      FETCH scur INTO cur_sv;
      IF NOT done
        THEN
          SELECT CONCAT( ':: s', cur_sv, ' take d_i18n' );
          SELECT CONCAT( ":: s", srv, " give SELECT CONCAT\( '\( \"', d_i18n.lang, '\",\"', dn, '\" \)' \) FROM d_i18n, toolserver.wiki WHERE family='wikipedia' and server=", cur_sv, " and d_i18n.lang=toolserver.wiki.lang\;" );
      END IF;
    UNTIL done END REPEAT;

    CLOSE scur;

    SELECT CONCAT( ':: echo all transfer issued from s', srv );

    #
    # Create output tables for res and tres from slaves.
    #
    OPEN scur;
    SET done = 0;

    REPEAT
      FETCH scur INTO cur_sv;
      IF NOT done
        THEN
          SET @st=CONCAT( "DROP TABLE IF EXISTS res_s", cur_sv, ";" );
          PREPARE stmt FROM @st;
          EXECUTE stmt;
          DEALLOCATE PREPARE stmt;
          SET @st=CONCAT( "CREATE TABLE res_s", cur_sv, " \( suggestn varchar\(255\) not null default '', id int\(8\) unsigned not null default '0', lang varchar\(10\) not null default '' \) ENGINE=MEMORY\;" );
          PREPARE stmt FROM @st;
          EXECUTE stmt;
          DEALLOCATE PREPARE stmt;

          SET @st=CONCAT( "DROP TABLE IF EXISTS tres_s", cur_sv, ";" );
          PREPARE stmt FROM @st;
          EXECUTE stmt;
          DEALLOCATE PREPARE stmt;
          SET @st=CONCAT( "CREATE TABLE tres_s", cur_sv, " \( suggestn varchar\(255\) not null default '', id int\(8\) unsigned not null default '0', lang varchar\(10\) not null default '' \) ENGINE=MEMORY\;" );
          PREPARE stmt FROM @st;
          EXECUTE stmt;
          DEALLOCATE PREPARE stmt;
      END IF;
    UNTIL done END REPEAT;

    CLOSE scur;

    #
    # Call on slaves in parallel threads.
    #
    # Note: Callee are keeping track on data input sync.
    #
    OPEN scur;
    SET done = 0;

    REPEAT
      FETCH scur INTO cur_sv;
      IF NOT done
        THEN
          SELECT CONCAT( ':: s', cur_sv, ' valu ', @target_lang );
          SELECT CONCAT( ':: s', cur_sv, ' prlc inter_langs_slave' );
      END IF;
    UNTIL done END REPEAT;

    CLOSE scur;

    #
    # Master languages loop
    #
    OPEN cur;
    SET done = 0;

    REPEAT
      FETCH cur INTO cur_lang, cur_db;
      IF NOT done
        THEN
          CALL inter_lang( cur_db, cur_lang, @target_lang );
      END IF;
    UNTIL done END REPEAT;

    CLOSE cur;

    #
    # Deinitialize and report on master results.
    #
    DROP TABLE d_i18n;
    DROP TABLE dinfo;
    DROP TABLE rinfo;
    DROP TABLE iwl;
    DROP TABLE liwl;

    DELETE FROM res
           WHERE suggestn='';

    SELECT CONCAT( ':: echo With use of s', srv, ' ', count(DISTINCT id), ' isolates can be linked based on interwiki' )
           FROM res;

    SELECT CONCAT( ':: echo With use of s', srv, ' ', count(DISTINCT id), ' isolates can be linked with translation' )
           FROM tres;

    #
    # The expected amount of synchonization events from slave processes.
    #
    SELECT 2*(count(DISTINCT server)-1) INTO dsync
           FROM toolserver.wiki
           WHERE family='wikipedia';

    #
    # Looks like an infinite loop, right?
    #
    # Note: Lines are to be added by slaves when their transfer done.
    #
    REPEAT
      # no more than once per second
      SELECT sleep( 1 ) INTO ready;
      SELECT count(*) INTO ready
             FROM communication_exchange;
    UNTIL ready=dsync END REPEAT;
    DROP TABLE communication_exchange;

    #
    # Merging slave results to res and tres
    #
    OPEN scur;
    SET done = 0;

    REPEAT
      FETCH scur INTO cur_sv;
      IF NOT done
        THEN
          SET @st=CONCAT( 'INSERT INTO res SELECT suggestn, id, lang FROM res_s', cur_sv, ';' );
          PREPARE stmt FROM @st;
          EXECUTE stmt;
          DEALLOCATE PREPARE stmt;
          SET @st=CONCAT( 'DROP TABLE res_s', cur_sv, ';' );
          PREPARE stmt FROM @st;
          EXECUTE stmt;
          DEALLOCATE PREPARE stmt;

          SET @st=CONCAT( 'INSERT INTO tres SELECT suggestn, id, lang FROM tres_s', cur_sv, ';' );
          PREPARE stmt FROM @st;
          EXECUTE stmt;
          DEALLOCATE PREPARE stmt;
          SET @st=CONCAT( 'DROP TABLE tres_s', cur_sv, ';' );
          PREPARE stmt FROM @st;
          EXECUTE stmt;
          DEALLOCATE PREPARE stmt;
      END IF;
    UNTIL done END REPEAT;

    CLOSE scur;

    #
    # Report and refresh the web
    #
    SELECT CONCAT( ':: echo Totally, ', count(DISTINCT id), ' isolates can be linked based on interwiki' )
           FROM res;

    SELECT CONCAT( ':: echo Totally, ', count(DISTINCT id), ' isolates can be linked with translation' )
           FROM tres;

    CALL categorystats( 'res', 'sglcatvolume' );

    CALL categorystats( 'tres', 'sgtcatvolume' );

    DROP TABLE nrcatl0;

    # suggestor refresh
    ALTER TABLE res ENGINE=MyISAM;
    DROP TABLE IF EXISTS isres;
    RENAME TABLE res TO isres;
    ALTER TABLE tres ENGINE=MyISAM;
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
# from slave languages and push results to the master server.
#
DROP PROCEDURE IF EXISTS inter_langs_slave//
CREATE PROCEDURE inter_langs_slave( snum INT, mlang VARCHAR(10) )
  BEGIN
    DECLARE mnum INT DEFAULT 0;
    DECLARE done INT DEFAULT 0;
    DECLARE cur_lang VARCHAR(16);
    DECLARE cur_db VARCHAR(32);
    DECLARE ready INT DEFAULT 0;
    DECLARE cur CURSOR FOR SELECT DISTINCT lang, dbname FROM toolserver.wiki WHERE family='wikipedia' and server=snum ORDER BY size DESC;
    DECLARE CONTINUE HANDLER FOR SQLSTATE '02000' SET done = 1;

    # Convert master language name to master server number
    SELECT server INTO mnum
           FROM toolserver.wiki
           WHERE domain=CONCAT( mlang, '.wikipedia.org');

    # Looks like an infinite loop, however, a line is to be modified externally
    # when transfer done.
    REPEAT
      SELECT count(*) INTO ready
             FROM communication_exchange;
    UNTIL ready=2 END REPEAT;
    DROP TABLE communication_exchange;

    # slave languages loop
    OPEN cur;

    REPEAT
      FETCH cur INTO cur_lang, cur_db;
      IF NOT done
        THEN
          CALL inter_lang( cur_db, cur_lang, mlang );
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

    SELECT CONCAT( ':: echo With use of s', snum, ' ', count(DISTINCT id), ' isolates can be linked based on interwiki' )
           FROM res;

    SELECT CONCAT( ':: echo With use of s', snum, ' ', count(DISTINCT id), ' isolates can be linked with translation' )
           FROM tres;

    SELECT CONCAT( ':: s', mnum, ' take res_s', snum );
    SELECT CONCAT( ":: s", snum, " give SELECT CONCAT\( '\(\"', suggestn, '\",\"', id, '\",\"', lang, '\"\)' \) FROM res\;" );

    SELECT CONCAT( ':: s', mnum, ' take tres_s', snum );
    SELECT CONCAT( ":: s", snum, " give SELECT CONCAT\( '\(\"', suggestn, '\",\"', id, '\",\"', lang, '\"\)' \) FROM tres\;" );

    SELECT CONCAT( ':: echo all transfer issued from s', snum );
  END;
//

delimiter ;
############################################################

-- </pre>
