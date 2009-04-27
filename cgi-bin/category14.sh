#!/bin/bash

language="ru"
script="category14"
source ./common

parse_query networkpath
parse_query interface
if [ "$interface" != 'ru' ]
then
  interface='en'
fi

source ./common.$interface
source ./category14.$interface
source ./common2

handle_layer ()
{
  local line=$1

  if no_sql_error "$line"
  then
    line=${line//_/ }
    echo \<li\>\<a href=\"http://ru.wikipedia.org/w/index.php?title=Категория:$line\" target=\"_blank\"\>$line\<\/a\>\<\/li\>
  fi
}

handle_table ()
{
  local line=$1

  if no_sql_error "$line"
  then
    local lname=$( echo $line | sed -e 's/^\(.*\)\s\([1-9][0-9]*\)/\1/g' )
    local amnt=$( echo $line | sed -e 's/^\(.*\)\s\([1-9][0-9]*\)/\2/g' )
    echo "<a href='./category14.sh?interface=$interface&networkpath=$lname'>$lname</a>:&nbsp;$amnt<br />"
  fi
}

handle_rlist ()
{
  local line=$1

  if no_sql_error "$line"
  then
    line=${line//_/ }
    echo \<li\>\<a href=\"http://ru.wikipedia.org/w/index.php?title=Категория:$line\&redirect=no\" target=\"_blank\"\>$line\<\/a\>\<\/li\>
  fi
}

echo Content-type: text/html
echo ""

cat << EOM
﻿<?xml version="1.0" encoding="UTF-8" ?>
<!DOCTYPE html PUBLIC "-//W3C//DTD XHTML 1.0 Transitional//EN"
    "http://www.w3.org/TR/xhtml1/DTD/xhtml1-transitional.dtd">
<html>
 <head>
  <meta http-equiv="Content-Type" content="text/html;charset=utf-8" />
EOM

echo "<title>$pagetitle</title>"

cat << EOM
  <link rel="stylesheet" type="text/css" href="../main.css" media="all" />
 </head>
 <body>
<a href="/"><img id="poweredbyicon" src="../wikimedia-toolserver-button.png" alt="Powered by Wikimedia-Toolserver" /></a>
EOM
how_actual categoryspruce

echo "<h1>$mainh1</h1>"
echo "<table><tr><td width=25% border=10>"

#
# The menu
#
the_menu

echo "</td><td width=75%>"
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
  } | $( sql ${dbserver} u_${usr}_golem_${language} ) 2>&1 | { 
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
} | $( sql ${dbserver} u_${usr}_golem_${language} ) 2>&1 | { 
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
  } | $( sql ${dbserver} u_${usr}_golem_${language} ) 2>&1 | { 
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
  } | $( sql ${dbserver} u_${usr}_golem_${language} ) 2>&1 | { 
                    while read -r line
                      do handle_rlist "$line"
                    done
                  }
  echo "</ol>"
  echo $listend
fi

cat << EOM
</td>
</tr>
</table>

 </body>
</html>
EOM
