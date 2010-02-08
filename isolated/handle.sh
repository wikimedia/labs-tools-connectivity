#!/bin/bash
 #
 # Authors: [[:ru:user:Mashiah Davidson]]
 #
 # Purpose: Nice handler for all output coming from various modules
 #          written in different languages.
 #
 # Parameters: External tools like data/statistics upload are always invoked
 #             unless disabled in the command line. The following parameters
 #             are supported:
 #                            nomr   - prevents multiple redirects resolving
 #                            nostat - prevents claster chains statistics upload
 #
 # Use: Just pipe all the output of your script to this handler and form it
 #      in the following format:
 # 
 #      Strings starting with ':: ' are commands.
 #         The following commands are currently supported:
 #         :: echo <something>     - just prints <something> to stdout
 #         :: replag <replag>      - prints <replag> and checks 
 #                                   if replagdependent operations possible
 #         :: out <fn>             - opens file <fn> and switches all output
 #                                   there till the next command came
 #         :: upload <fn> <url>    - resolves multiple redirects given with
 #                                   use of mr.pl and stores data to a 
 #                                   a file as 'out' does
 #         :: stat <curts> <uts>   - uploads latest *.articles.stat file if
 #                                   difference between timestamp is above
 #                                   some threshold
 #         :: s<N> <operation>     - initiates an <operation> on server s<N>
 #                                   the following operations supported:
 #                 call <function> - calls the <function> given
 #                 take <table>    - informs s<N> on table name to put
 #                                   data from 'give' operation, see import.sh
 #                 give <select>   - passes statement <select> to s<N> to
 #                                   send its output to another server with use
 #                                   of import.sh
 #                 valu <val>      - prepares a value for a special call type
 #                                   of call named prlc
 #                 prlc <function> - same as 'call' but in separate thread
 #                                   and a bit special
 #                 done <action>   - reports to s<N> on external <action>
 #                                   completion
 #                 init <script>   - passes file <script> with sql code to
 #                                   server s<N>
 #         :: 7z                   - archives output files (.txt, .info, .stat)
 #
 #      Reports on error if unexpected output occurs. Disables any external
 #      tools in this case.
 #

# set the maximal replication lag value in minutes, which is allowed for apply
# probably, less than script actually works
maxlag=10
# upload stat if replication time difference to the latest upload made
# is greater then statintv minutes
statintv=720

source ./isoinv

extminutes ()
{
  local given=$1
  local hours=''
  minutes=''

  hours=${given%:*}
  minutes=${hours#*:}
  minutes=`expr $minutes + 0`
  hours=${hours%:*}
  hours=`expr $hours + 0`

  minutes=$[$minutes+60*$hours]
}

state=0
out='';
handle ()
{
  local line=$1
  local statlast='';

  if [ "${line:0:3}" = ':: ' ]
  then
    # apply previous command if necessary
    if [ "$state" = '2' ]
    then
      if [ "$do_mr" = "1" ]
      then
        if [ -f no_mr.log ]
        then
          do_mr=0
        else
          elem=${#collection[*]}
          {
            iter=0
            while (($iter < $elem))
            do
              echo ${collection[$iter]}
              iter=$(($iter+1))
            done
            sync
          } | perl mr.pl $language $usr | ./handle.sh $cmdl &
          unset collection
        fi
      fi
    fi

    # now start new command parse
    state=0
    # recognize current command
    if [ "${line:3:5}" = 'echo ' ]
    then
      echo ${line:8}
    else
      if [ "${line:3:7}" = 'replag ' ]
      then
        echo replag: ${line:10}
        if [ "$do_templates" = "1" ]
        then
          extminutes ${line:10}
          if (($minutes >= $maxlag))
          then
            echo replag of $minutes minutes is to big, must be below $maxlag
            echo perishable data will not be applied
            do_templates=0
            echo "$do_templates" > ${language}.no_templates.log
          fi
        fi
        sync
      else
        if [ "${line:3:4}" = 'out ' ]
        then
          out=${line:7}
          state=1 # file output
          if [ ! -f $out ]
          then
            #
            # Put utf-8 "byte-order mask", which is indeed just identifies
            # utf-8 encoding for applications like Notepad.
            #
            echo -ne \\0357\\0273\\0277 > $out
          fi
        else
          if [ "${line:3:7}" = 'upload ' ]
          then
            out=${line:10}
            state=2 # upload and file output
            # need better way for url definition, maybe sql driven
            outpage=${out:15:2}
            if [ ! -f $out ]
            then
              echo -ne \\0357\\0273\\0277 > $out
            fi
          else
            if [ "${line:3:5}" = 'stat ' ]
            then
              stat_up_ts=${line:8:19}
              echo got current upload timestamp as $stat_up_ts
              if [ "$do_stat" = "1" ]
              then
                if [ -f ${language}.no_stat.log ]
                then
                  do_stat=0
                else
                  stats_reply_to=${line:28:1}
                  stats_store=${line:30}
                  # empty @connectivity_project_root should prevent any upload
                  if [ "$stats_store" != '/stat' ]
                  then
                    # cut 3 very first utf-8 bytes and upload the stats
                    tail --bytes=+4 ./*.articles.stat | perl r.pl $stats_store 'stat' $usr "$stat_up_ts" $statintv $stats_reply_to $language | ./handle.sh $cmdl
                  fi
                fi
              fi
              echo -ne \\0357\\0273\\0277 > stats_done.log
            else
              if [ "${line:3:1}" = 's' ]
              then
                params="${line:4:1} u_${usr}_golem_s${line:4:1}_${language_sql}"
                outcommand=${line:6:4}
                case $outcommand in
                'call')
                   {
                     echo "CALL allow_allocation( 4294967296 );"
                     echo "CALL ${line:11}();"
                   } | $( sql $params ) 2>&1 | ./handle.sh $cmdl
                   ;;
                'valu')
                   # get a value for transmission as prlc parameter
                   outvariable=${line:11}
                   if [ "$outvariable" = '' ]
                   then
                     echo "empty outvariable transmission, params: ${params}"
                   fi
                   ;;
                'take')
                   tosqlservernum=${line:4:1}
                   outtable=${line:11}
                   toparams=$params
                   ;;
                'give')
                   echo "${line:11}" | $( sql $params ) 2>&1 | ./import.sh $outtable ${line:4:1} $tosqlservernum $outvariable | $( sql $toparams ) 2>&1 | ./handle.sh $cmdl &
                   outvariable=''
                   ;;
                'prlc')
                   # call in a parallel thread 
                   # with slave and master identifiers as parameters
                   {
                     echo "CALL ${line:11}( ${line:4:1}, '$outvariable' );"
                   } | $( sql $params ) 2>&1 | ./handle.sh $cmdl &
                   outvariable=''
                   ;;
                'done')
                   # update inter-run timing data for a name given
                   {
                     echo "CALL performed_confirmation( '${line:11}' );"
                   } | $( sql $params ) 2>&1 | ./handle.sh $cmdl
                   ;;
                'init')
                   # send a golem's spy given by ${line:11}
                   {
                     #
                     # New language database might have to be created.
                     #
                     echo "create database if not exists u_${usr}_golem_s${line:4:1}_${language_sql};"

                     #
                     # Switch to the database just created.
                     #
                     echo "use u_${usr}_golem_s${line:4:1}_${language_sql};"

                     #
                     # Infecting the database with a script or a set of scripts
                     #
                     cat ${line:11}
                   } | $( sql ${line:4:1} ) 2>&1 | ./handle.sh $cmdl
                   ;;
                'emit')
                   # handle dynamical request from sql job report loading
                   # on a given server
                   {
                     #
                     # New language database may have to be created.
                     #
                     echo "create database if not exists u_${usr}_golem_p;"

                     #
                     # Switch to the database just created.
                     #
                     echo "use u_${usr}_golem_p;"

                     #
                     # Infect with scripts every database should have
                     #
                     cat toolserver.sql
                     cat replag.sql
                     cat projector.sql

                     #
                     # Current replication time and language are stored into
                     # a table readable by everyone.
                     #
                     echo "create table if not exists language_stats ( lang VARCHAR(10) BINARY NOT NULL default '', ts TIMESTAMP(14) NOT NULL, PRIMARY KEY (lang) ) ENGINE=MyISAM;"

                     echo "INSERT INTO language_stats SELECT '$language' as lang, '${line:11}' as ts ON DUPLICATE KEY UPDATE ts='${line:11}';"
                   } | $( sql ${line:4:1} ) 2>&1 | ./handle.sh $cmdl
                   ;;
                'drop')
                   # drop a table by its name
                   {
                     echo "DROP TABLE ${line:11};"
                   } | $( sql $params ) 2>&1 | ./handle.sh $cmdl
                   ;;
                *) ;;
                esac
                state=3 # communicate among servers
              else
                if [ "${line:3:2}" = '7z' ]
                then
                  while [ ! -f stats_done.log ]
                  do
                    sleep 2
                  done

                  # pack templates management info for delivery to AWB host
                  rm -f $language.today.7z
                  7z a $language.today.7z ./*.txt >7z.log 2>&1
                  rm -f ./*.txt

                  rm -f $language.info.7z
                  7z a $language.info.7z ./*.info >>7z.log 2>&1
                  rm -f ./*.info

                  7z a $language.stat.7z ./*.stat >>7z.log 2>&1

                  todos 7z.log
                  chmod 755 *.7z
                else
                  if [ "${line:3:10}" = 'introduce ' ]
                  then
                    distinct_srv=''
                    # for all sql servers we try creating a db and
                    # ask for its hostname
                    for item in ${line:13}
                    do
                      local str=$(
                                   {
                                     #
                                     # New language database may have to be created.
                                     #
                                     echo "create database if not exists u_${usr}_golem_p;"

                                     echo "SELECT @@hostname;"
                                   } | $( sql $item ) 2>&1
                                 )
                      if [ "$str:0:6" != 'ERROR ' ]
                      then
                        repeated=0
                        host[$item]=$str
                        # look if this host was already met
                        for (( bck = 0 ; bck < item ; bck++ ))
                        do
                          if [ "${host[$bck]}" = "${host[$item]}" ]
                          then
                            repeated=1
                          fi
                        done
                        # distinct hosts collection
                        if [ "$repeated" = '0' ]
                        then
                          distinct_srv="${distinct_srv} $item"
                        fi
                      else
                        echo "error connection to sql server s${item}" >> ${language}.debug.log
                      fi
                    done

                    # for all servers representing distinct hosts
                    for item in ${distinct_srv:1}
                    do
                      #
                      # Infect with scripts every database should have
                      #
                      {
                        cat toolserver.sql
                        cat replag.sql
                        cat projector.sql

                        echo "CREATE TABLE IF NOT EXISTS server ( sv_id INT(8) unsigned NOT NULL default '0', host_name VARCHAR(255) binary NOT NULL default '', PRIMARY KEY (sv_id) ) ENGINE=MyISAM;"

                        echo -e "INSERT INTO server VALUES "
                        str=''
                        for bck in ${line:13}
                        do
                          if [ "$str" = '' ]
                          then
                            str="($bck,'${host[$bck]}')"
                          else
                            str="$str,($bck,'${host[$bck]}')"
                          fi
                        done
                        echo "$str ON DUPLICATE KEY UPDATE server.host_name=VALUES(host_name);"

                        echo "SELECT ':: echo s${item} represents ${host[$item]}';"
                      } | $( sql $item u_${usr}_golem_p ) 2>&1 | ./handle.sh $cmdl
                    done
                  else
                    echo command: $line, not recognized >> ${language}.debug.log
                  fi
                fi
              fi
            fi
          fi
        fi
      fi
    fi
  else
    case $state in           # Can't connect to MySQL server on '$dbhost' (111)'
    0) if [ "${line:0:20}" = 'ERROR 2003 (HY000): ' ] || [ "${line:0:20}" = 'ERROR 2013 (HY000): ' ] || [ "${line:0:20}" = 'ERROR 1130 (00000): ' ]
       then
         echo $dbhost is unavailable, now nothing will be applied
       else
         if [ "${line:0:20}" = 'ERROR 1049 (42000): ' ]
         then
           echo user database does not exist for some reason, need to be examined\; nothing will be applied
         else
           if [ "$line" != '' ]
           then
             echo -ne $line\\r\\n >> ${language}.debug.log
           fi
         fi
       fi
       do_templates=0
       do_stat=0
       echo "$do_stat" > ${language}.no_stat.log
       echo "$do_templates" > ${language}.no_templates.log
       ;;
    1) echo -ne $line\\r\\n >> $out
       ;;
    2) echo -ne $line\\r\\n >> $out
       collection[${#collection[*]}]=$line
       ;;
    *) echo state: $state, $line >> ${language}.debug.log
       ;;
    esac
  fi
}

while read -r line
  do handle "$line"
done
