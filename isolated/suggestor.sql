 --
 -- Authors: [[:ru:user:Mashiah Davidson]], still alone
 --
 -- <pre>

 --
 -- Significant speedup
 --

SET SESSION TRANSACTION ISOLATION LEVEL READ UNCOMMITTED;

############################################################
delimiter //

DROP PROCEDURE IF EXISTS suggestor//
CREATE PROCEDURE suggestor ()
  BEGIN
    SET @starttime=now();

    #
    # For use in "ISOLATES LINKED BY DISAMBIGUATIONS LINKED BY ARTICLES".
    #

    #
    # Takes ruwiki0, dl and ld as inputs.
    #
    # Produces a2i table, containing links from articles to isolates
    # through disambiguations (as if they are just redirects).
    #
    # Also updates catvolume table for categorizer.
    #
    CALL disambigs_as_fusy_redirects();

    CALL disambiguator_unload();

    #
    # For use in "ISOLATES WITH LINKED INTERWIKI".
    #
    # Note: postponed because takes too much time.
    CALL inter_langs();

    DROP TABLE ll_orcat;

    SELECT CONCAT( ':: echo suggestor web tool time: ', timediff(now(), @starttime));
  END;
//

delimiter ;
############################################################

-- </pre>
