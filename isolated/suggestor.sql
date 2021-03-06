 --
 -- Authors: [[:ru:user:Mashiah Davidson]]
 --
 -- Caution: PROCEDUREs defined here may have output designed for handle.sh.
 -- 
 -- Shared procedures: suggestor
 --
 -- <pre>

############################################################
delimiter //

DROP PROCEDURE IF EXISTS suggestor//
CREATE PROCEDURE suggestor ( srv INT )
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

    IF @iwspy!='off'
    THEN
      #
      # For use in "ISOLATES WITH LINKED INTERWIKI".
      #
      CALL inter_langs( srv );
    END IF;

    DROP TABLE nrcatl0;

    DROP TABLE ll_orcat;

    SELECT CONCAT( ':: echo suggestor web tool time: ', TIMEDIFF(now(), @starttime));
  END;
//

delimiter ;
############################################################

-- </pre>
