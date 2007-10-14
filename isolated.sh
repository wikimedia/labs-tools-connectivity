 # 
 # Handler for 
 # '''[[:ru:User:Mashiah_Davidson/toolserver/isolated.sql|isolated.sql]]'''.
 # 
 # Works on the Toolserver and outputs the processing results into a set
 # of files being switched by some API calls from '''isolated.sql'''.
 #
 # <pre>

#!/bin/bash

# debug level enable
debugmode=
debugshift=0
if [ "$1" != "" ]
then
  # not yet work, to debug look at lines around 1159 in isolated.sql
  debugmode="-v -v -v"
  debugshift=2
fi

dbhost="sql-s3"
usr=$( cat ~/.my.cnf | grep 'user ' | sed 's/^user = \([a-z]*\)$/\1/' )
pwd=$( cat ~/.my.cnf | grep 'password ' | sed 's/^password = \"\([^\"]*\)\"$/\1/' )
sql="mysql --host=$dbhost -A --user=${usr} --password=${pwd} --database=u_${usr} -n"

rm -f ./*.info ./*.txt ./*.stat debug.log

out='';
handle ()
{
  local line=$1

  if [ "${line:$debugshift:3}" = ':: ' ]
  then
    if [ "${line:$debugshift+3:5}" = 'echo ' ]
    then
      echo ${line:$debugshift+8}
    else
      if [ "${line:$debugshift+3:4}" = 'out ' ]
      then
        out=${line:$debugshift+7}
        state=1
        if [ ! -f $out ]
        then
          echo -ne \\0357\\0273\\0277 > $out
        fi
      fi
    fi
  else
    case $state in           # Can't connect to MySQL server on '$dbhost' (111)'
    0) if [ "${line:0:20}" = 'ERROR 2003 (HY000): ' ]
       then
         echo $dbhost is unavailable
       else
         if [ "$line" != '' ]
         then
           echo -ne $line\\r\\n >> debug.log
         fi
       fi;;
    1) if [ "$line" = '' ]
       then
         state=0
         echo -ne \\r\\n >> debug.log
       else
         echo -ne $line\\r\\n >> $out
       fi;;
    *) echo $line;;
    esac
  fi
}

time { 
  $sql -N $debugmode <isolated.sql 2>&1 | { state=0; while read -r line ; do handle "$line" ; done }

  rm -f today.7z
  7z a today.7z ./*.txt >7z.log 2>&1
  rm -f ./*.txt

  rm -f info.7z
  7z a info.7z ./*.info >>7z.log 2>&1
  rm -f ./*.info

  7z a stat.7z ./*.stat >>7z.log 2>&1

  todos 7z.log
}

# </pre>