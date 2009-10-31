#!/bin/bash

script="category14"
source ./common

handle_layer ()
{
  local line=$1

  if no_sql_error "$line"
  then
    line=${line//_/ }
    echo \<li\>\<a href=\"http://$language.wikipedia.org/w/index.php?title=Category:$line\" target=\"_blank\"\>$line\<\/a\>\<\/li\>
  fi
}

handle_table ()
{
  local line=$1

  if no_sql_error "$line"
  then
    line=( $line )
    local lname=${line[0]}
    local amnt=${line[1]}

    echo "<a href='./category14.sh?$stdurl&listby=categoryspruce&networkpath=$lname'>$lname</a>:&nbsp;$amnt<br />"
  fi
}

handle_rlist ()
{
  local line=$1

  if no_sql_error "$line"
  then
    line=${line//_/ }
    local name=$( url "$line" )
    echo \<li\>\<a href=\"http://$language.wikipedia.org/w/index.php?title=Category:$name\&redirect=no\" target=\"_blank\"\>$line\<\/a\>\<\/li\>
  fi
}

how_actual categoryspruce

#
# Standard page header
#
the_header

echo "<h1>$thish1</h1>"

echo $actualnote1
echo $actualnote2

if [ "$networkpath" != '' ]
then
  echo "<h4>$networkpath</h4>"

  if [ "$networkpath" = '_1' ]
  then
    echo "<font color=red>"
    echo $rootcatnote1
    echo $rootcatnote2
    echo "</font>"
  fi

  if [[ "$networkpath" =~ '^.*\_([1-9][1-90]+|[2-9])$' ]]
  then
    echo "<font color=red>"
    echo "$clsizenote1 ${BASH_REMATCH[1]}.<br />"
    echo $clsizenote2
    echo "</font>"
  fi

  echo "<ol>"
  {
    echo SELECT title                           \
                FROM ruwiki14                   \
                     WHERE cat=\'$networkpath\' \
                     ORDER BY title ASC\;
  } | $( sql ${dbserver} u_${usr}_golem_s${dbserver}_${language} ) 2>&1 | { 
                    while read -r line
                      do handle_layer "$line"
                    done
                  }
  echo "</ol>"
  echo $listend
else
  echo $cattreedesc1
  echo $cattreedesc2
  echo $cattreedesc3
  echo $cattreedesc4
fi

echo "<center><table border=0><tr><th>$struchead</th></tr><tr><td align=center><small>"
{
  echo SELECT coolcat,            \
              count\(cat\) as cnt \
              FROM orcat14,       \
                   ruwiki14       \
              WHERE coolcat=cat   \
              GROUP BY cat        \
              ORDER BY REPLACE\(coolcat,\'_\',\'\+\'\) ASC\;
} | $( sql ${dbserver} u_${usr}_golem_s${dbserver}_${language} ) 2>&1 | { 
                  while read -r line
                    do handle_table "$line"
                  done
                }
echo "</small></td></tr></table></center>"

if [ "$networkpath" = '' ]
then
  echo "<h4>$queryname1</h4>"
  echo "<font color=red>"
  echo $query1note1
  echo $query1note2
  echo "</font>"
  
  echo "<ol>"
  {
    echo SELECT r_title  \
                FROM r14 \
                ORDER BY r_title ASC\;
  } | $( sql ${dbserver} u_${usr}_golem_s${dbserver}_${language} ) 2>&1 | { 
                    while read -r line
                      do handle_rlist "$line"
                    done
                  }
  echo "</ol>"
  echo $listend

  echo "<h4>$queryname2</h4>"
  echo "<font color=red>"
  echo $query2note1
  echo "<ul>"
  echo "<li>$query2note2</li>"
  echo "<li>$query2note3</li>"
  echo "</ul>"
  echo "</font>"
  
  echo "<ol>"
  {
    echo SELECT wr_title  \
                FROM wr14 \
                ORDER BY wr_title ASC\;
  } | $( sql ${dbserver} u_${usr}_golem_s${dbserver}_${language} ) 2>&1 | { 
                    while read -r line
                      do handle_rlist "$line"
                    done
                  }
  echo "</ol>"
  echo $listend
fi

#
# Standard page footer
#
the_footer
