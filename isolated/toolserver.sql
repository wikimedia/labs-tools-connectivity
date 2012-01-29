 --
 -- Authors: [[:ru:user:Mashiah Davidson]],
 --          [[:ru:user:VasilievVV]] aka vvv
 --
 -- Caution: PROCEDUREs defined here may have output designed for handle.sh.
 -- 
 -- <pre>

############################################################
delimiter //

#
# Replication timestamp and replication lag for a language given.
#
DROP FUNCTION IF EXISTS server_num//
CREATE FUNCTION server_num ( language VARCHAR(64) )
  RETURNS INT
  DETERMINISTIC
  BEGIN
    DECLARE srv INT;

    #
    # Extracts sql server name suffux for the language given
    #
    SELECT server INTO srv
           FROM toolserver.wiki
           WHERE family='wikipedia' and
                 domain=CONCAT(language,'.wikipedia.org') and
                 is_closed=0;

    RETURN srv;
  END;
//

DROP FUNCTION IF EXISTS largest_neighbour//
CREATE FUNCTION largest_neighbour ( language VARCHAR(64) )
  RETURNS VARCHAR(64)
  DETERMINISTIC
  BEGIN
    DECLARE res VARCHAR(64);

    SELECT dbname INTO res
           FROM toolserver.wiki
           WHERE server=server_num( language ) and
                 family='wikipedia' and
                 #
                 # just in case, who knows...
                 #
                 is_closed=0
           ORDER BY size DESC
           LIMIT 1;

    RETURN res;
  END;
//

DROP FUNCTION IF EXISTS dbname_for_lang//
CREATE FUNCTION dbname_for_lang ( language VARCHAR(64) )
  RETURNS VARCHAR(64)
  DETERMINISTIC
  BEGIN
    DECLARE res VARCHAR(64);

    SELECT dbname INTO res
           FROM toolserver.wiki
           WHERE family='wikipedia' and
                 is_closed=0 and
                 domain=CONCAT(language,'.wikipedia.org')
           LIMIT 1;

    RETURN res;
  END;
//

DROP FUNCTION IF EXISTS host_for_lang//
CREATE FUNCTION host_for_lang ( language VARCHAR(64) )
  RETURNS VARCHAR(255)
  DETERMINISTIC
  BEGIN
    DECLARE res VARCHAR(64);

    SELECT host_name INTO res
           FROM toolserver.wiki,
                u_mashiah_golem_p.server
           WHERE family='wikipedia' and
                 is_closed=0 and
                 domain=CONCAT(language,'.wikipedia.org') and
                 server=sv_id
           LIMIT 1;

    RETURN res;
  END;
//

DROP FUNCTION IF EXISTS host_for_srv//
CREATE FUNCTION host_for_srv ( srv INT )
  RETURNS VARCHAR(255)
  DETERMINISTIC
  BEGIN
    DECLARE res VARCHAR(64);

    SELECT host_name INTO res
           FROM u_mashiah_golem_p.server
           WHERE sv_id=srv
           LIMIT 1;

    RETURN res;
  END;
//

DROP PROCEDURE IF EXISTS project_for_everywhere//
CREATE PROCEDURE project_for_everywhere ( )
  BEGIN
    DECLARE done INT DEFAULT 0;
    DECLARE ready INT DEFAULT 0;
    DECLARE cur_sv INT DEFAULT 0;
    DECLARE srvlist VARCHAR(20);
    DECLARE scur CURSOR FOR SELECT DISTINCT server FROM toolserver.wiki WHERE family='wikipedia' and is_closed=0 ORDER BY server ASC;
    DECLARE CONTINUE HANDLER FOR SQLSTATE '02000' SET done = 1;

    SET srvlist = '';

    OPEN scur;
    SET done = 0;

    REPEAT
      FETCH scur INTO cur_sv;
      IF NOT done
        THEN
          #
          # Collect subject of interest server list
          #
          SET srvlist=CONCAT( srvlist, ' ', cur_sv );
      END IF;
    UNTIL done END REPEAT;

    CLOSE scur;

    SELECT CONCAT( ':: introduce', srvlist );
  END;
//

DROP PROCEDURE IF EXISTS emit_for_everywhere//
CREATE PROCEDURE emit_for_everywhere ( language VARCHAR(64), usr VARCHAR(64) )
  BEGIN
    DECLARE done INT DEFAULT 0;
    DECLARE ready INT DEFAULT 0;
    DECLARE cur_sv INT DEFAULT 0;
    DECLARE cur_host VARCHAR(255) DEFAULT '';
    DECLARE _dr INT DEFAULT '0';
    DECLARE _ac INT DEFAULT '0';
    DECLARE _chc INT DEFAULT '0';
    DECLARE _dc INT DEFAULT '0';
    DECLARE _iac INT DEFAULT '0';
    DECLARE _dec INT DEFAULT '0';
    DECLARE _ncc INT DEFAULT '0';
    DECLARE _drd REAL(5,3) DEFAULT '0';
    DECLARE _nccc INT DEFAULT '0';
    DECLARE _crc INT DEFAULT '0';
    DECLARE _crtc INT DEFAULT '0';
    DECLARE st VARCHAR(2047);
    DECLARE scur CURSOR FOR SELECT host_name, MIN(server) as sv FROM toolserver.wiki, u_mashiah_golem_p.server WHERE family='wikipedia' and is_closed=0 and sv_id=server and host_name!=host_for_lang(language) GROUP BY host_name ORDER BY sv ASC;
    DECLARE CONTINUE HANDLER FOR SQLSTATE '02000' SET done = 1;

    CALL replag( language );

    SELECT SIGN(@disambiguations_look_recognized) INTO @_dr;

    IF @_dr>0
      THEN
        SELECT articles,
               chrono,
               disambig
               INTO @_ac,
                    @_chc,
                    @_dc
               FROM zns;

        SELECT isolated,
               deadend
               INTO @_iac,
                    @_dec
               FROM inda;

        SELECT @not_categorized_articles_count INTO @_ncc;

        SELECT DRDI INTO @_drd
               FROM drdi;

        SELECT count(DISTINCT user, user_text) INTO @_crtc
               FROM creators0;
    END IF;

    SELECT count(*)-1 INTO @_nccc
           FROM ruwiki14
           WHERE cat='_1';

    SELECT count(cat) INTO @_crc
           FROM orcat14,
                ruwiki14
           WHERE CAST( SUBSTRING_INDEX(coolcat, '_', -1) as UNSIGNED)!=1 AND
                 coolcat=cat;

    IF @_ac IS NULL
      THEN
        SET @_ac=0;
    END IF;

    IF @_chc IS NULL
      THEN
        SET @_chc=0;
    END IF;

    IF @_dc IS NULL
      THEN
        SET @_dc=0;
    END IF;

    IF @_iac IS NULL
      THEN
        SET @_iac=0;
    END IF;

    IF @_dec IS NULL
      THEN
        SET @_dec=0;
    END IF;

    IF @_ncc IS NULL
      THEN
        SET @_ncc=0;
    END IF;

    IF @_drd IS NULL
      THEN
        SET @_drd=0;
    END IF;

    IF @_nccc IS NULL
      THEN
        SET @_nccc=0;
    END IF;

    IF @_crc IS NULL
      THEN
        SET @_crc=0;
    END IF;

    IF @_crtc IS NULL
      THEN
        SET @_crtc=0;
    END IF;

    OPEN scur;
    SET done = 0;

    REPEAT
      FETCH scur INTO cur_host, cur_sv;
      IF NOT done
        THEN
          #
          # Outer handler to distribute good news across sql hosts.
          #
          SELECT CONCAT( ':: s', cur_sv, ' emit ', @_dr, ' ', @_ac, ' ', @_chc, ' ', @_dc, ' ', @_iac, ' ', @_dec, ' ', @_ncc, ' ', @_drd, ' ', @_nccc, ' ', @_crc, ' ', @_crtc, ' ', @rep_time, ' ', @cluster_limit, ' ', @processing_time );
      END IF;
    UNTIL done END REPEAT;

    CLOSE scur;

    #
    # Current host log is updated with no call to the outer handler.
    #
    # INSERT INTO u_', usr, '_golem_p.language_stats (
    #                                                  lang,
    #                                                  ts,
    #                                                  disambig_recognition,
    #                                                  article_count,
    #                                                  chrono_count,
    #                                                  disambig_count,
    #                                                  isolated_count,
    #                                                  creator_count,
    #                                                  deadend_count,
    #                                                  nocat_count,
    #                                                  drdi,
    #                                                  nocatcat_count,
    #                                                  catring_count,
    #                                                  cluster_limit,
    #                                                  proc_time
    #                                                )
    # SELECT "', language, '" as lang,
    #        "', @rep_time, '" as ts,
    #        @_dr as disambig_recognition,
    #        @_ac as article_count,
    #        @_chc as chrono_count,
    #        @_dc as disambig_count,
    #        @_iac as isolated_count,
    #        @_crtc as creator_count,
    #        @_dec as deadend_count,
    #        @_ncc as nocat_count,
    #        @_drd as drdi,
    #        @_nccc as nocatcat_count,
    #        @_crc as catring_count,
    #        @cluster_limit as cluster_limit,
    #        @processing_time as proc_time;
    #
    SET @st=CONCAT( 'INSERT INTO u_', usr, '_golem_p.language_stats (lang, ts, disambig_recognition, article_count, chrono_count, disambig_count, isolated_count, creator_count, deadend_count, nocat_count, drdi, nocatcat_count, catring_count, cluster_limit, proc_time) SELECT "', language, '" as lang, "', @rep_time, '" as ts, @_dr as disambig_recognition, @_ac as article_count, @_chc as chrono_count, @_dc as disambig_count, @_iac as isolated_count, @_crtc as creator_count, @_dec as deadend_count, @_ncc as nocat_count, @_drd as drdi, @_nccc as nocatcat_count, @_crc as catring_count, @cluster_limit as cluster_limit, @processing_time as proc_time;' );
    PREPARE stmt FROM @st;
    EXECUTE stmt;
    DEALLOCATE PREPARE stmt;
  END;
//

#
# This function is useful for former articles moved out from zero namespace.
# Returns namespace prefix by its numerical identifier.
#
DROP FUNCTION IF EXISTS getnsprefix//
CREATE FUNCTION getnsprefix ( ns INT, targetlang VARCHAR(32) )
  RETURNS VARCHAR(255)
  DETERMINISTIC
  BEGIN
    DECLARE wrconstruct VARCHAR(255);

    SELECT ns_name INTO wrconstruct
           FROM toolserver.namespacename
           WHERE dbname=dbname_for_lang(targetlang) and
                 ns_id=ns AND
                 ns_type='primary';

    IF wrconstruct != ''
      THEN
        SET wrconstruct=CONCAT( wrconstruct, ':' );
    END IF;

    RETURN wrconstruct;

  END;
//

DROP PROCEDURE IF EXISTS langwiki2//
CREATE PROCEDURE langwiki2 ()
  BEGIN
    DECLARE done INT DEFAULT 0;
    DECLARE lng VARCHAR(16) DEFAULT '';
    DECLARE lng_str VARCHAR(8192) DEFAULT '';
    DECLARE garbage TIMESTAMP(14);
    DECLARE chrcnt INT DEFAULT 0;
    #DECLARE cur1 CURSOR FOR
    #        SELECT lang,
    #               ts,
    #               chrono_count
    #               FROM language_stats ls
    #                    INNER JOIN (
    #                                 SELECT lang AS _lang,
    #                                        MAX(ts) AS _ts
    #                                        FROM language_stats
    #                                        WHERE ts+interval 1 day>now()
    #                                        GROUP BY lang
    #                               ) _ls
    #                               ON lang = _lang AND
    #                                  ts = _ts
    #               WHERE disambig_recognition=1
    #               ORDER BY ts DESC,
    #                        lang ASC;
    DECLARE cur1 CURSOR FOR SELECT lang, ts, chrono_count FROM language_stats ls INNER JOIN ( SELECT lang AS _lang, MAX(ts) AS _ts FROM language_stats WHERE ts+interval 1 day>now() GROUP BY lang ) _ls ON lang = _lang AND ts = _ts WHERE disambig_recognition=1 ORDER BY ts DESC, lang ASC;
    #DECLARE cur2 CURSOR FOR
    #        SELECT lang,
    #               ts,
    #               chrono_count
    #               FROM language_stats ls
    #                    INNER JOIN (
    #                                 SELECT lang AS _lang,
    #                                        MAX(ts) AS _ts
    #                                        FROM language_stats
    #                                        WHERE ts+interval 2 day>now()
    #                                        GROUP BY lang
    #                                        HAVING _ts+interval 1 day<=now()
    #                               ) _ls
    #                               ON lang = _lang AND
    #                                  ts = _ts
    #               WHERE disambig_recognition=1
    #               ORDER BY ts DESC,
    #                     lang ASC;
    DECLARE cur2 CURSOR FOR SELECT lang, ts, chrono_count FROM language_stats ls INNER JOIN ( SELECT lang AS _lang, MAX(ts) AS _ts FROM language_stats WHERE ts+interval 2 day>now() GROUP BY lang HAVING _ts+interval 1 day<=now() ) _ls ON lang = _lang AND ts = _ts WHERE disambig_recognition=1 ORDER BY ts DESC, lang ASC;
    #DECLARE cur3 CURSOR FOR
    #        SELECT lang,
    #               ts,
    #               chrono_count
    #               FROM language_stats ls
    #                    INNER JOIN (
    #                                 SELECT lang AS _lang,
    #                                        MAX(ts) AS _ts
    #                                        FROM language_stats
    #                                        GROUP BY lang
    #                                        HAVING _ts+interval 2 day<=now()
    #                               ) _ls
    #                               ON lang = _lang AND
    #                                  ts = _ts
    #               WHERE disambig_recognition=1
    #               ORDER BY ts DESC,
    #                        lang ASC;
    DECLARE cur3 CURSOR FOR SELECT lang, ts, chrono_count FROM language_stats ls INNER JOIN ( SELECT lang AS _lang, MAX(ts) AS _ts FROM language_stats GROUP BY lang HAVING _ts+interval 2 day<=now() ) _ls ON lang = _lang AND ts = _ts WHERE disambig_recognition=1 ORDER BY ts DESC, lang ASC;
    #DECLARE cur4 CURSOR FOR
    #        SELECT lang,
    #               ts
    #               FROM language_stats ls
    #                    INNER JOIN (
    #                                 SELECT lang AS _lang,
    #                                        MAX(ts) AS _ts
    #                                        FROM language_stats
    #                                        GROUP BY lang
    #                               ) _ls
    #                               ON lang = _lang AND
    #                                  ts = _ts
    #                    INNER JOIN (
    #                                 SELECT domain,
    #                                        size
    #                                        FROM toolserver.wiki
    #                                        WHERE is_closed=0 and
    #                                              family='wikipedia'
    #                               ) tsw
    #                               ON domain=CONCAT(lang,'.wikipedia.org')
    #               WHERE disambig_recognition=0
    #               ORDER BY size DESC;
    DECLARE cur4 CURSOR FOR SELECT lang, ts FROM language_stats ls INNER JOIN ( SELECT lang AS _lang, MAX(ts) AS _ts FROM language_stats GROUP BY lang ) _ls ON lang = _lang AND ts = _ts INNER JOIN ( SELECT domain, size FROM toolserver.wiki WHERE is_closed=0 and family='wikipedia' ) tsw ON domain=CONCAT(lang,'.wikipedia.org') WHERE disambig_recognition=0 ORDER BY size DESC;
    DECLARE CONTINUE HANDLER FOR SQLSTATE '02000' SET done = 1;

    OPEN cur1;
    SET done = 0;

    REPEAT
      FETCH cur1 INTO lng, garbage, chrcnt;
      IF NOT done
        THEN
          IF chrcnt>0
            THEN
              SELECT CONCAT( lng_str, ' !', lng ) INTO lng_str;
            ELSE
              SELECT CONCAT( lng_str, ' ', lng ) INTO lng_str;
          END IF;
      END IF;
    UNTIL done END REPEAT;

    CLOSE cur1;

    SELECT lng_str;

    SET lng_str='';

    OPEN cur2;
    SET done = 0;

    REPEAT
      FETCH cur2 INTO lng, garbage, chrcnt;
      IF NOT done
        THEN
          IF chrcnt>0
            THEN
              SELECT CONCAT( lng_str, ' !', lng ) INTO lng_str;
            ELSE
              SELECT CONCAT( lng_str, ' ', lng ) INTO lng_str;
          END IF;
      END IF;
    UNTIL done END REPEAT;

    CLOSE cur2;

    SELECT lng_str;

    SET lng_str='';

    OPEN cur3;
    SET done = 0;

    REPEAT
      FETCH cur3 INTO lng, garbage, chrcnt;
      IF NOT done
        THEN
          IF chrcnt>0
            THEN
              SELECT CONCAT( lng_str, ' !', lng ) INTO lng_str;
            ELSE
              SELECT CONCAT( lng_str, ' ', lng ) INTO lng_str;
          END IF;
      END IF;
    UNTIL done END REPEAT;

    CLOSE cur3;

    SELECT lng_str;

    SET lng_str='';

    OPEN cur4;
    SET done = 0;

    REPEAT
      FETCH cur4 INTO lng, garbage;
      IF NOT done
        THEN
          SELECT CONCAT( lng_str, ' ', lng ) INTO lng_str;
      END IF;
    UNTIL done END REPEAT;

    CLOSE cur4;

    SELECT lng_str;

    SELECT REPLACE(MAX(ts),' ','_') FROM language_stats WHERE disambig_recognition=0;
  END;
//

delimiter ;
############################################################

-- </pre>
