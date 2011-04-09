 --
 -- Authors: [[:ru:user:Mashiah Davidson]]
 --
 -- Caution: PROCEDUREs defined here may have output designed for handle.sh.
 --
 -- Shared procedures: inter_langs
 --
 -- <pre>

############################################################
delimiter //

#
# Prepare interwiki based linking suggestions for one language
#
DROP PROCEDURE IF EXISTS inter_lang//
CREATE PROCEDURE inter_lang( dbname VARCHAR(32), language VARCHAR(16), mlang VARCHAR(16) )
  BEGIN
    DECLARE st VARCHAR(255);
    DECLARE prefix VARCHAR(32);
    DECLARE cnt INT;
    DECLARE mlang10 VARCHAR(10);
    DECLARE language10 VARCHAR(10);

    SELECT CONCAT( ':: echo .', language, ' . ' ) INTO prefix;

    SET language10=SUBSTRING( language FROM 1 FOR 10 );

    #
    # How many pages do link interwiki partners of our isolates.
    #
    # Note: Of course, we do not need too much of suggestions, thus
    #       the amount of links selected is limited here by 524'288;
    #
    SET @st=CONCAT( 'INSERT INTO liwl (fr, t) SELECT /* SLOW_OK */ pl_from as fr, id as t FROM ', dbname, ".pagelinks, iwl WHERE pl_title=title and pl_namespace=0 and lang='", language10, "' LIMIT 524288;" );
    PREPARE stmt FROM @st;
    EXECUTE stmt;
    DEALLOCATE PREPARE stmt;

    SELECT count(*) INTO @cnt
           FROM liwl;

    SELECT CONCAT( prefix, @cnt, " links to isolate's interwikis found" );

    IF @cnt>0
      THEN
        SET mlang10=SUBSTRING( mlang FROM 1 FOR 10 );

        SET @st=CONCAT( 'INSERT INTO rinfo (fr, page_is_redirect, page_title, t) SELECT fr, page_is_redirect, page_title, t FROM ', dbname, '.page, liwl WHERE page_id=fr GROUP BY fr;' );
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

        SET @st=CONCAT( 'INSERT INTO liwl (fr, t) SELECT pl_from as fr, t FROM ', dbname, '.pagelinks, rinfo WHERE page_is_redirect=1 and pl_title=page_title and pl_namespace=0;' );
        PREPARE stmt FROM @st;
        EXECUTE stmt;
        DEALLOCATE PREPARE stmt;
 
        SELECT CONCAT( prefix, count(*), " links to isolate's interwikis after redirects seaming" )
               FROM liwl;

        DELETE FROM rinfo;

        CALL collect_disambig( dbname, -1, prefix );

        #
        # No need to suggest disambiguation pages translation.
        #
        DELETE liwl 
               FROM liwl,
                    d
               WHERE fr=d_id;
    
        SELECT CONCAT( prefix, count(*), " links to isolate's interwikis after disambiguations cleanup" )
               FROM liwl;

        DELETE FROM d;

        #
        # Discard all suggestions on linking from non-zero namespace.
        #
        SET @st=CONCAT( 'DELETE liwl FROM liwl, ', dbname, '.page WHERE page_id=fr AND page_namespace!=0;' );
        PREPARE stmt FROM @st;
        EXECUTE stmt;
        DEALLOCATE PREPARE stmt;

        SELECT count(*) INTO @cnt
               FROM liwl;

        SELECT CONCAT( prefix, @cnt, " links to isolate's interwikis from zero namespace" );

        SET @st=CONCAT( "INSERT INTO res (suggestn, id, lang) SELECT /* SLOW_OK */ REPLACE(ll_title,' ','_') as suggestn, t as id, '", language,"' as lang FROM ", dbname, ".langlinks, liwl WHERE fr=ll_from and ll_lang='", mlang10, "';" );
        PREPARE stmt FROM @st;
        EXECUTE stmt;
        DEALLOCATE PREPARE stmt;

        SELECT CONCAT( prefix, count(DISTINCT id), ' isolates could be linked based on interwiki' )
               FROM res
               WHERE lang=language;

        SET @st=CONCAT( 'DELETE liwl FROM ', dbname, ".langlinks, liwl WHERE fr=ll_from and ll_lang='", mlang10, "';" );
        PREPARE stmt FROM @st;
        EXECUTE stmt;
        DEALLOCATE PREPARE stmt;

        SELECT count(*) INTO @cnt
               FROM liwl;

        SELECT CONCAT( prefix, @cnt, " links to isolate's interwikis after exclusion of already translated" );

        SET @st=CONCAT( "INSERT INTO tres (suggestn, id, lang) SELECT page_title as suggestn, t as id, '", language, "' as lang FROM ", dbname, '.page, liwl WHERE page_id=fr and page_namespace=0;' );
        PREPARE stmt FROM @st;
        EXECUTE stmt;
        DEALLOCATE PREPARE stmt;

        DELETE FROM liwl;

        SELECT CONCAT( prefix, count(DISTINCT id), ' isolates could be linked with main namespace pages translation' )
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

    DROP TABLE IF EXISTS d;
    CREATE TABLE d (
      d_id int(8) unsigned not null default '0',
      PRIMARY KEY (d_id)
    ) ENGINE=MEMORY;

    DROP TABLE IF EXISTS res;
    CREATE TABLE res (
      suggestn varchar(255) not null default '',
      id int(8) unsigned not null default '0',
      lang varchar(16) not null default ''
    ) ENGINE=MEMORY;

    DROP TABLE IF EXISTS tres;
    CREATE TABLE tres (
      suggestn varchar(255) not null default '',
      id int(8) unsigned not null default '0',
      lang varchar(16) not null default ''
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
# This procedure is being run on the master-host. It infects slave-hosts
# with its code and tables, initialtes transfer of initial data from master to
# slaves.
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
    DECLARE cur_host VARCHAR(64) DEFAULT '';
    DECLARE cur_sv INT DEFAULT 0;
    DECLARE dsync INT DEFAULT 0;
    DECLARE dcnt INT DEFAULT 0;
    DECLARE st VARCHAR(511);
    DECLARE res VARCHAR(255) DEFAULT '';
    DECLARE cur CURSOR FOR SELECT DISTINCT TRIM(TRAILING '.wikipedia.org' FROM domain), dbname FROM toolserver.wiki, u_mashiah_golem_p.server WHERE family='wikipedia' and is_closed=0 and server=sv_id and host_name=host_for_srv(srv) ORDER BY size DESC;
    DECLARE scur CURSOR FOR SELECT host_name, MIN(server) as sv FROM toolserver.wiki, u_mashiah_golem_p.server WHERE family='wikipedia' and is_closed=0 and sv_id=server and host_name!=host_for_srv(srv) GROUP BY host_name ORDER BY sv ASC;
    DECLARE CONTINUE HANDLER FOR SQLSTATE '02000' SET done = 1;

    SELECT cry_for_memory( 4294967296 ) INTO @res;
    IF @res!=''
      THEN
        SELECT CONCAT( ':: echo ', @res );
    END IF;

    #
    # Infect slave servers with this library code
    # and inform them on who is the master.
    #
    OPEN scur;
    SET done = 0;

    REPEAT
      FETCH scur INTO cur_host, cur_sv;
      IF NOT done
        THEN
          # hope this reduces the amount of mysql connections created
          SELECT CONCAT( ':: s', cur_sv, ' init toolserver.sql memory.sql disambig.sql iwikispy.sql' );
      END IF;
    UNTIL done END REPEAT;

    CLOSE scur;

    #
    # Infect everyone with necessary communication tables.
    #
    OPEN scur;
    SET done = 0;

    REPEAT
      FETCH scur INTO cur_host, cur_sv;
      IF NOT done
        THEN
          SELECT CONCAT( ':: s', cur_sv, ' call inter_langs_ct' );
      END IF;
    UNTIL done END REPEAT;

    CLOSE scur;

    #
    # Self-infection.
    #
    CALL inter_langs_ct();

    #
    # Prepare interwiki links for isolated articles.
    #
    SET @st=CONCAT( 'INSERT INTO iwl (id, title, lang) /* SLOW_OK */ SELECT id, REPLACE(ll_title,', "' ','_'", ') as title, ll_lang as lang FROM ', @dbname, '.langlinks, ruwiki0 WHERE id=ll_from;' );
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
    # Note: master host languages may be left as they are due to no transfer.
    #
    UPDATE iwl 
           SET title=REPLACE (REPLACE( title, '\\', '\\\\\\' ), '"', '\\"')
           WHERE lang IN 
                 (
                   SELECT SUBSTRING( lang FROM 1 FOR 10 )
                          FROM toolserver.wiki,
                               u_mashiah_golem_p.server
                          WHERE family='wikipedia' and
                                is_closed=0 and
                                server=sv_id and
                                host_name!=host_for_srv(srv)
                 );

    #
    # Initiate interwiki transfer to slaves.
    #
    OPEN scur;
    SET done = 0;

    REPEAT
      FETCH scur INTO cur_host, cur_sv;
      IF NOT done
        THEN
          #
          # Table name on the destination slave sever to be filled.
          #
          SELECT CONCAT( ':: s', cur_sv, ' take iwl' );
          #
          # This query will come back to the master server from 
          # the outer handler driving transmission to its finish.
          #
          SELECT CONCAT( ":: s", srv, " give SELECT CONCAT\( '\( \"', id, '\",\"', title, '\",\"', iwl.lang, '\" \)' \) FROM iwl, toolserver.wiki, u_mashiah_golem_p.server WHERE family='wikipedia' and server=sv_id and host_name=host_for_srv\(", cur_sv, "\) and is_closed=0 and iwl.lang=SUBSTRING\(TRIM\(TRAILING \'.wikipedia.org\' FROM domain\) FROM 1 FOR 10\)\;" );
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
      FETCH scur INTO cur_host, cur_sv;
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
      FETCH scur INTO cur_host, cur_sv;
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
    DROP TABLE d;
    DROP TABLE rinfo;
    DROP TABLE iwl;
    DROP TABLE liwl;

    DELETE FROM res
           WHERE suggestn='';

    SELECT CONCAT( ':: echo With use of s', srv, ' ', count(DISTINCT id), ' isolates could be linked based on interwiki' )
           FROM res;

    SELECT CONCAT( ':: echo With use of s', srv, ' ', count(DISTINCT id), ' isolates could be linked with translation' )
           FROM tres;

    #
    # The expected amount of synchonization events from slave processes.
    #
    SELECT 2*(count(DISTINCT host_name)-1) INTO dsync
           FROM toolserver.wiki,
                u_mashiah_golem_p.server
           WHERE family='wikipedia' and
                 is_closed=0 and
                 server=sv_id;

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
      FETCH scur INTO cur_host, cur_sv;
      IF NOT done
        THEN
          SET @st=CONCAT( 'INSERT INTO res (suggestn, id, lang) SELECT suggestn, id, lang FROM res_s', cur_sv, ';' );
          PREPARE stmt FROM @st;
          EXECUTE stmt;
          DEALLOCATE PREPARE stmt;
          SET @st=CONCAT( 'DROP TABLE res_s', cur_sv, ';' );
          PREPARE stmt FROM @st;
          EXECUTE stmt;
          DEALLOCATE PREPARE stmt;

          SELECT CONCAT( ':: s', cur_sv, ' drop res' );

          SET @st=CONCAT( 'INSERT INTO tres (suggestn, id, lang) SELECT suggestn, id, lang FROM tres_s', cur_sv, ';' );
          PREPARE stmt FROM @st;
          EXECUTE stmt;
          DEALLOCATE PREPARE stmt;
          SET @st=CONCAT( 'DROP TABLE tres_s', cur_sv, ';' );
          PREPARE stmt FROM @st;
          EXECUTE stmt;
          DEALLOCATE PREPARE stmt;

          SELECT CONCAT( ':: s', cur_sv, ' drop tres' );
      END IF;
    UNTIL done END REPEAT;

    CLOSE scur;

    SELECT count(*) INTO @dcnt
           FROM res;

    #
    # Discard all suggestions on linking from templated non-articles.
    #
    DELETE res
           FROM res,
                iw_filter
           WHERE name=suggestn;
    DROP TABLE iw_filter;

    #
    # Discard all suggestions on linking from non-zero namespace.
    #
    # Note: Non-ucfirst'ed prefixes in interwiki-links are not recognized yet.
    #
    DELETE res
           FROM res,
                toolserver.namespacename
           WHERE dbname=CONCAT( @target_lang, 'wiki_p') AND
                 ns_id!=0 AND
                 ns_type='primary' AND
                 suggestn like CONCAT( ns_name , ':%' );

    #
    # Exclude self-links from suggestions. May be there for various reasons.
    #
    DELETE res
           FROM res,
                ruwiki0
           WHERE res.id=ruwiki0.id and
                 suggestn=title;

    SELECT CONCAT( ':: echo ', @dcnt-count(*), ' linking suggestions discarded as not forming valid links' )
           FROM res;

    #
    # Report and refresh the web
    #
    SELECT CONCAT( ':: echo Totally, ', count(DISTINCT id), ' isolates could be linked based on interwiki' )
           FROM res;

    SELECT CONCAT( ':: echo Totally, ', count(DISTINCT id), ' isolates could be linked with translation' )
           FROM tres;

    #
    # Languages by articles to improve and isolates those articles could link.
    #
    DROP TABLE IF EXISTS nres;
    CREATE TABLE nres (
      lang varchar(16) not null default '',
      a_amnt int(8) unsigned not null default '0',
      i_amnt int(8) unsigned not null default '0'
    ) ENGINE=MEMORY AS
    SELECT lang,
           count(distinct suggestn) as a_amnt,
           count(distinct id) as i_amnt
           FROM res
           GROUP BY lang;

    SELECT CONCAT( ':: echo Totally, ', count(*), ' languages suggest on linking of isolates' )
           FROM nres;

    ALTER TABLE nres ENGINE=MyiSAM;
    DROP TABLE IF EXISTS nisres;
    RENAME TABLE nres TO nisres;

    #
    # Languages by articles to translate and isolates those articles could link.
    #
    DROP TABLE IF EXISTS ntres;
    CREATE TABLE ntres (
      lang varchar(16) not null default '',
      a_amnt int(8) unsigned not null default '0',
      i_amnt int(8) unsigned not null default '0'
    ) ENGINE=MEMORY AS
    SELECT lang,
           count(distinct suggestn) as a_amnt,
           count(distinct id) as i_amnt
           FROM tres
           GROUP BY lang;

    SELECT CONCAT( ':: echo Totally, ', count(*), ' languages suggest on articles translation for isolates linking' )
           FROM ntres;

    ALTER TABLE ntres ENGINE=MyiSAM;
    DROP TABLE IF EXISTS nistres;
    RENAME TABLE ntres TO nistres;

    CALL categorystats( 'res', 'sglcatvolume' );
    CALL langcategorystats( 'res', 'sglflcatvolume' );

    # suggestor refresh
    ALTER TABLE res ENGINE=MyISAM;
    DROP TABLE IF EXISTS isres;
    RENAME TABLE res TO isres;


    CALL categorystats( 'tres', 'sgtcatvolume' );
    CALL langcategorystats( 'tres', 'sgtflcatvolume' );

    DROP TABLE nrcatl0;

    ALTER TABLE tres ENGINE=MyISAM;
    DROP TABLE IF EXISTS istres;
    RENAME TABLE tres TO istres;

    # categorizer refresh
    DROP TABLE IF EXISTS sglcatvolume0;
    RENAME TABLE sglcatvolume TO sglcatvolume0;
    DROP TABLE IF EXISTS sgtcatvolume0;
    RENAME TABLE sgtcatvolume TO sgtcatvolume0;
    DROP TABLE IF EXISTS sglflcatvolume0;
    RENAME TABLE sglflcatvolume TO sglflcatvolume0;
    DROP TABLE IF EXISTS sgtflcatvolume0;
    RENAME TABLE sgtflcatvolume TO sgtflcatvolume0;

    CALL actuality( 'lsuggestor' );
    CALL actuality( 'tsuggestor' );
  END;
//

#
# Prepare interwiki based linking suggestions for isolated articles linked
# from slave languages and push results to the master server.
#
DROP PROCEDURE IF EXISTS inter_langs_slave//
CREATE PROCEDURE inter_langs_slave( snum INT, mlang VARCHAR(16) )
  BEGIN
    DECLARE mnum INT DEFAULT 0;
    DECLARE done INT DEFAULT 0;
    DECLARE cur_lang VARCHAR(16);
    DECLARE cur_db VARCHAR(32);
    DECLARE ready INT DEFAULT 0;
    DECLARE cur CURSOR FOR SELECT DISTINCT TRIM(TRAILING '.wikipedia.org' FROM domain), dbname FROM toolserver.wiki, u_mashiah_golem_p.server WHERE family='wikipedia' and server=sv_id and host_name=host_for_srv(snum) and is_closed=0 ORDER BY size DESC;
    DECLARE CONTINUE HANDLER FOR SQLSTATE '02000' SET done = 1;

    # Convert master language name to master server number
    SELECT server_num( mlang ) INTO mnum;

    # Looks like an infinite loop, however, a line is to be modified externally
    # when transfer done.
    REPEAT
      # no more than once per second
      SELECT sleep( 1 ) INTO ready;
      SELECT count(*) INTO ready
             FROM communication_exchange;
    UNTIL ready=1 END REPEAT;
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

    DROP TABLE d;
    DROP TABLE rinfo;
    DROP TABLE iwl;
    DROP TABLE liwl;

    DELETE FROM res
           WHERE suggestn='';

    UPDATE res
           SET suggestn=REPLACE( REPLACE( suggestn, '\\', '\\\\\\' ), '"', '\\"');

    UPDATE tres
           SET suggestn=REPLACE( REPLACE( suggestn, '\\', '\\\\\\' ), '"', '\\"');

    SELECT CONCAT( ':: echo With use of s', snum, ' ', count(DISTINCT id), ' isolates could be linked based on interwiki' )
           FROM res;

    SELECT CONCAT( ':: echo With use of s', snum, ' ', count(DISTINCT id), ' isolates could be linked with translation' )
           FROM tres;

    SELECT CONCAT( ':: s', mnum, ' take res_s', snum );
    SELECT CONCAT( ":: s", snum, " give SELECT DISTINCT CONCAT\( '\(\"', suggestn, '\",\"', id, '\",\"', lang, '\"\)' \) FROM res\;" );

    SELECT CONCAT( ':: s', mnum, ' take tres_s', snum );
    SELECT CONCAT( ":: s", snum, " give SELECT DISTINCT CONCAT\( '\(\"', suggestn, '\",\"', id, '\",\"', lang, '\"\)' \) FROM tres\;" );

    SELECT CONCAT( ':: echo all transfer issued from s', snum );
  END;
//

delimiter ;
############################################################

-- </pre>
