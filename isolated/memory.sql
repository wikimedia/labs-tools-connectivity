 --
 -- Authors: [[:ru:user:Mashiah Davidson]]
 --
 -- Caution: PROCEDUREs defined here may have output designed for handle.sh.
 -- 
 -- Shared procedures: cry_for_memory
 --
 -- <pre>

############################################################
delimiter //

#SET @memory_table_capacity=8589934592;
SET @memory_table_capacity=134217728;
#SET @memory_table_capacity=67108864;

DROP PROCEDURE IF EXISTS adjust_memory_capacity//
CREATE PROCEDURE adjust_memory_capacity ()
  BEGIN
    DECLARE ctrl INT;
    DECLARE capacity INT;

    SET @capacity=@@max_heap_table_size;

    WHILE @@max_heap_table_size<@memory_table_capacity DO
      SET @ctrl=2*@@max_heap_table_size;
      SET @@max_heap_table_size=@ctrl;
      #
      # I know, it's crazy to check whether the value is assigned,
      # however the system variable can be limited in its ability
      # to increase above a limit set in mySQL configuration.
      #
      IF @@max_heap_table_size!=@ctrl
        THEN
          SET @@max_heap_table_size=@memory_table_capacity;

          #
          # and once again in case not power of two is initially set
          #
          IF @@max_heap_table_size!=@memory_table_capacity
            THEN
              #
              # internal bound to be in sync with real MySQL configuration
              #
              SET @memory_table_capacity=@@max_heap_table_size;
          END IF;
      END IF;
    END WHILE;

    #
    # Memory table size limit to initial value just in case.
    #
    SET @@max_heap_table_size=@capacity;
  END;
//

CALL adjust_memory_capacity()//

#
# Requests change for memory table size limit if required/allowed.
#
DROP FUNCTION IF EXISTS cry_for_memory//
CREATE FUNCTION cry_for_memory ( size VARCHAR(64) )
  RETURNS VARCHAR(255)
  DETERMINISTIC
  BEGIN
    DECLARE srv INT;
    DECLARE ctrl INT;
    DECLARE res VARCHAR(255) DEFAULT '';
    DECLARE capacity INT;

    #
    # This module allows avoiding default limits on heap table size, 
    # however some reasonable limitations should exist.
    #
    SET @capacity=@memory_table_capacity;

    IF size>@@max_heap_table_size
      THEN
        #
        # Loop ends up with successful memory allocation or exits with error
        # 
        WHILE @@max_heap_table_size<size DO
          SET @ctrl=2*@@max_heap_table_size;
          SET @@max_heap_table_size=@ctrl;
          #
          # I know, it's crazy to check whether the value is assigned,
          # however the system variable can be limited in its ability
          # to increase above a limit set in mySQL configuration.
          #
          IF @@max_heap_table_size!=@ctrl
            THEN
              #
              # Golem's upper bound on memory for future tables.
              #
              SET @@max_heap_table_size=@capacity;
              RETURN CONCAT( '... ... cannot allocate ', size, ' bytes in memory for operation; set to ', @capacity );
          END IF;
        END WHILE;

        #
        # Note: memory allocation succesfully allowed here, errors are exited
        #
        # Even successful allocations should be bounded in memory consumption
        #
        IF size<=@capacity
          THEN
            IF @@max_heap_table_size<1024
              THEN
                RETURN CONCAT( '... memory table size limit set to ', @@max_heap_table_size, ' bytes' );
              ELSE
                IF @@max_heap_table_size<1048576
                  THEN
                    RETURN CONCAT( '... memory table size limit set to ', CEIL(@@max_heap_table_size/1024), ' kB' );
                  ELSE
                    IF @@max_heap_table_size<1073741824
                      THEN
                        RETURN CONCAT( '... memory table size limit set to ', CEIL(@@max_heap_table_size/1048576), ' MB' );
                      ELSE
                        RETURN CONCAT( '... memory table size limit set to ', CEIL(@@max_heap_table_size/1073741824), ' GB' );
                    END IF;
                END IF;
            END IF;
          ELSE
            #
            # Golem's upper bound on memory for future tables.
            #
            SET @@max_heap_table_size=@capacity;
            RETURN CONCAT( '... ... memory table size limit does not allow size of ', size, ' bytes; set to ', @capacity );
        END IF;
    END IF;

    RETURN '';
  END;
//

delimiter ;
############################################################

-- </pre>
