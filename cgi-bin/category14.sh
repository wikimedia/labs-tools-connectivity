#!/bin/bash

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
  <link rel="stylesheet" type="text/css" href="../main.css" media="all" /><style type="text/css">
  
  </style>
 </head>
 <body>
<a href="/"><img id="poweredbyicon" src="../wikimedia-toolserver-button.png" alt="Powered by Wikimedia-Toolserver" /></a>
EOM

echo "<h1>$mainh1</h1>"
echo "<table><tr><td width=25% border=10>"
echo -ne "<h1>"
if [ "$interface" = 'ru' ]
then
  echo -ne "<a href=\"./category14.sh?interface=en&networkpath=$networkpath\">[[en:]]</a> [[ru:]]"
else
  echo -ne "[[en:]] <a href=\"./category14.sh?interface=ru&networkpath=$networkpath\">[[ru:]]</a>"
fi
echo "</h1>"
echo -ne "<b><a href=\"../index"
if [ "$interface" = 'ru' ]
then
  echo -ne "ru"
fi
echo ".html\">1) $motivation</a></b><br />"
echo "<br />"
echo "<b>2) <a href=\"http://ru.wikipedia.org/w/index.php?title=$isourl\">$isolatedarticles</a></b><br />"
echo "<ul>"
echo "<li><b><a href=\"./category.sh?interface=$interface\">$bycategory</a></b></li>"
echo "<ul>"
echo "<li><a href=\"./suggest.sh?interface=$interface\">$allsuggestions</a></li>"
echo "<ul>"
echo "<li><a href=\"./suggest.sh?interface=$interface&listby=disambigcat\">$resolvedisambigs</a></li>"
echo "<li>$justlink</li>"
echo "<ul>"
echo "<li><a href=\"./suggest.sh?interface=$interface&listby=interlinkcat\">$parttranslate</a></li>"
echo "<li><a href=\"./suggest.sh?interface=$interface&listby=translatecat\">$translatenlink</a></li>"
echo "</ul>"
echo "</ul>"
echo "</ul>"
echo -ne "<li><b><a href=\"../lists"
if [ "$interface" = 'ru' ]
then
  echo -ne "ru"
fi
echo ".html\">$wholelist</a></b></li>"
echo "<li><b><a href=\"http://ru.wikipedia.org/w/index.php?title=$prjurl/bytypes\">$byclastertype</a></b></li>"
echo "<ul><li><a href=\"http://ru.wikipedia.org/w/index.php?title=$orphurl\">$orphanes</a></li></ul>"
echo "<li><b><a href=\"./creators.sh?interface=$interface\">$bycreator</a></b></li>"
echo "<li><b><a href=\"http://ru.wikipedia.org/w/index.php?title=$prjurl/cltgdata\">$graphdata</a></b></li>"
echo "</ul>"
echo "<br />"
echo "<b>3) <a href=\"http://ru.wikipedia.org/w/index.php?title=$deadendurl\">$deadend</a></b><br />"
echo "<br />"
echo "<b>4) <a href=\"./disambig.sh?interface=$interface\">$disambig</a></b><br />"
echo "<br />"
if [ "$networkpath" = '' ]
then
  echo "<b><font color=red>5) $cattreecon</font></b><br />"
else
  echo "<b>5) <a href=\"./category14.sh?interface=$interface\">$cattreecon</a></b><br />"
  echo "<ul>"
  echo "<li><font color=red><small>$networkpath</small></font></li>"
  echo "</ul>"
fi
echo "<br />"
echo "<b>6) $contactme</b><br />"
echo "<ul>"
echo "<li><a href=\"http://ru.wikipedia.org/wiki/User:Mashiah_Davidson\">$mywikipage</a></li>"
echo "<li><a href=\"http://ru.wikipedia.org/wiki/User:%D0%93%D0%BE%D0%BB%D0%B5%D0%BC\">$botwikipage</a></li>"
echo "<li><a href=\"http://ru.wikipedia.org/wiki/User Talk:%D0%93%D0%BE%D0%BB%D0%B5%D0%BC\">$commondisc</a></li>"
echo "<li>mashiah $attext <a href="irc://irc.freenode.net/$ircchan">#$ircchan</a></li>"
echo "</ul>"
echo "<p align=justify>$srclocation <a href="http://fisheye.ts.wikimedia.org/browse/mashiah">toolserver fisheye</a>.</p>"
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
  } | $sql 2>&1 | { 
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

how_actual categoryspruce
echo "<center><table border=0><tr><th>$struchead</th></tr><tr><td align=center><small>"
{
  echo SELECT coolcat,            \
              count\(cat\) as cnt \
              FROM orcat14,       \
                   ruwiki14       \
              WHERE coolcat=cat   \
              GROUP BY cat        \
              ORDER BY REPLACE\(coolcat,\'_\',\'\+\'\) ASC\;
} | $sql 2>&1 | { 
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
  } | $sql 2>&1 | { 
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
  } | $sql 2>&1 | { 
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

 <body>
</html>
EOM
