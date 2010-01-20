 --
 -- Authors: [[:ru:user:Mashiah Davidson]]
 --
 -- Caution: PROCEDUREs defined here may have output designed for handle.sh.
 -- 
 -- Shared procedures: allow_allocation
 --
 -- <pre>

 --
 -- Significant speedup
 --

SET SESSION TRANSACTION ISOLATION LEVEL READ UNCOMMITTED;


############################################################
delimiter //

#
# This module allows avoiding default limits on heap table size, 
# however some reasonable limitations should exist.
#
SET @heap_size_upper_limit=64*@@max_heap_table_size;

#
# Requests change for memory table size limit if required/allowed.
#
DROP PROCEDURE IF EXISTS allow_allocation//
CREATE PROCEDURE allow_allocation ( size VARCHAR(64) )
  BEGIN
    DECLARE srv INT;

    IF size<@heap_size_upper_limit
      THEN
        IF size>@@max_heap_table_size
          THEN
            WHILE @@max_heap_table_size<size DO
              SET @@max_heap_table_size=2*@@max_heap_table_size;
            END WHILE;
            IF @@max_heap_table_size<1024
              THEN
                SELECT CONCAT( ':: echo ... memory table size limit set to ', @@max_heap_table_size, ' bytes' );
              ELSE
                IF @@max_heap_table_size<1048576
                  THEN
                    SELECT CONCAT( ':: echo ... memory table size limit set to ', CEIL(@@max_heap_table_size/1024), ' kB' );
                  ELSE
                    IF @@max_heap_table_size<1073741824
                      THEN
                        SELECT CONCAT( ':: echo ... memory table size limit set to ', CEIL(@@max_heap_table_size/1048576), ' MB' );
                      ELSE
                        SELECT CONCAT( ':: echo ... memory table size limit set to ', CEIL(@@max_heap_table_size/1073741824), ' GB' );
                    END IF;
                END IF;
            END IF;
        END IF;
      ELSE
        SELECT CONCAT( ':: echo ... memory table size limit does not allow size of ', size, ' bytes' );
    END IF;
  END;
//

delimiter ;
############################################################

-- </pre>
