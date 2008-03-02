#!/bin/bash

source ./common

parse_query category
parse_query interface
if [ "$interface" != 'ru' ]
then
  interface='en'
fi

source ./common.$interface
source ./category.$interface
source ./common2

handle_category ()
{
  local line=$1

  if no_sql_error "$line"
  then
    line=${line//_/ }
    echo "<li><a href=\"http://ru.wikipedia.org/w/index.php?title=$line\" target=\"_blank\">$line</a> <small><a href=\"/~mashiah/cgi-bin/suggest.sh?interface=$interface&title=$line\"><font color=green>[[$suggest]]</font></a></small></li>"
  fi
}

handle_catlist ()
{
  local line=$1

  if no_sql_error "$line"
  then
    local name=$( echo $line | sed -e 's/^\([^ ]\+\) \([^ ]\+\) \([^ ]\+\)/\1/g' )
    local volume=$( echo $line | sed -e 's/^\([^ ]\+\) \([^ ]\+\) \([^ ]\+\)/\2/g' )
    local percent=$( echo $line | sed -e 's/^\([^ ]\+\) \([^ ]\+\) \([^ ]\+\)/\3/g' )
    name=${name//_/ }
    echo "<li><a href=\"/~mashiah/cgi-bin/category.sh?interface=$interface&category=$name\">$name</a>: $volume ($percent%)</li>"
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
  
  <link rel="stylesheet" type="text/css" href="/~mashiah/main.css" media="all" /><style type="text/css">
  
  </style>
 </head>
 <body>
<a href="/"><img id="poweredbyicon" src="/~mashiah/wikimedia-toolserver-button.png" alt="Powered by Wikimedia-Toolserver" /></a>
EOM

echo "<h1>$mainh1</h1>"
echo "<table><tr><td width=25% border=10>"
echo -ne "<h1>"
if [ "$interface" = 'ru' ]
then
  echo -ne "<a href=\"/~mashiah/cgi-bin/category.sh?interface=en&category=$category\">[[en:]]</a> [[ru:]]"
else
  echo -ne "[[en:]] <a href=\"/~mashiah/cgi-bin/category.sh?interface=ru&category=$category\">[[ru:]]</a>"
fi
echo "</h1>"
echo -ne "<b><a href=\"/~mashiah/index"
if [ "$interface" = 'ru' ]
then
  echo -ne "ru"
fi
echo ".html\">1) $motivation</a></b><br />"
echo "<br />"
echo "<b>2) <a href=\"http://ru.wikipedia.org/w/index.php?title=$isourl\">$isolatedarticles</a></b><br />"
echo "<ul>"
if [ "$category" = '' ]
then
  echo "<li><b><font color=red>$bycategory</font></b></li>"
else
  echo "<li><b><a href=\"/~mashiah/cgi-bin/category.sh?interface=$interface\">$bycategory</a></b></li>"
fi
echo "<ul>"
if [ "$category" != '' ]
then
  echo "<li><font color=red>${catns}:$category</font></li>"
fi
echo "<li><a href=\"/~mashiah/cgi-bin/suggest.sh?interface=$interface\">$allsuggestions</a></li>"
echo "<ul>"
echo "<li><a href=\"/~mashiah/cgi-bin/suggest.sh?interface=$interface&listby=disambigcat\">$resolvedisambigs</a></li>"
if [ "$category" != '' ]
then
  echo "<ul><li><a id=seealso href=\"/~mashiah/cgi-bin/suggest.sh?interface=$interface&category=$category&suggest=disambig\">${catns}:$category</a></li></ul>"
fi
echo "<li>$justlink</li>"
echo "<ul>"
echo "<li><a href=\"/~mashiah/cgi-bin/suggest.sh?interface=$interface&listby=interlinkcat\">$parttranslate</a></li>"
if [ "$category" != '' ]
then
  echo "<ul><li><a id=seealso href=\"/~mashiah/cgi-bin/suggest.sh?interface=$interface&category=$category&suggest=interlink\">${catns}:$category</a></li></ul>"
fi
echo "<li><a href=\"/~mashiah/cgi-bin/suggest.sh?interface=$interface&listby=translatecat\">$translatenlink</a></li>"
if [ "$category" != '' ]
then
  echo "<ul><li><a id=seealso href=\"/~mashiah/cgi-bin/suggest.sh?interface=$interface&category=$category&suggest=translate\">${catns}:$category</a></li></ul>"
fi
echo "</ul>"
echo "</ul>"
echo "</ul>"
echo -ne "<li><b><a href=\"/~mashiah/lists"
if [ "$interface" = 'ru' ]
then
  echo -ne "ru"
fi
echo ".html\">$wholelist</a></b></li>"
echo "<li><b><a href=\"http://ru.wikipedia.org/w/index.php?title=$prjurl/bytypes\">$byclastertype</a></b></li>"
echo "<ul><li><a href=\"http://ru.wikipedia.org/w/index.php?title=$orphurl\">$orphanes</a></li></ul>"
echo "<li><b><a href=\"/~mashiah/cgi-bin/creators.sh?interface=$interface\">$bycreator</a></b></li>"
echo "<li><b><a href=\"http://ru.wikipedia.org/w/index.php?title=$prjurl/cltgdata\">$graphdata</a></b></li>"
echo "</ul>"
echo "<br />"
echo "<b>3) <a href=\"http://ru.wikipedia.org/w/index.php?title=$deadendurl\">$deadend</a></b><br />"
echo "<br />"
echo "<b>4) <a href=\"/~mashiah/cgi-bin/disambig.sh?interface=$interface\">$disambig</a></b><br />"
echo "<br />"
echo "<b>5) <a href=\"/~mashiah/cgi-bin/category14.sh?interface=$interface\">$cattreecon</a></b><br />"
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
echo "$howoften<br><br>"
echo $example
echo "<FORM action=\"/~mashiah/cgi-bin/category.sh\" method=\"get\">"
echo "<INPUT type=hidden name=\"interface\" value=\"$interface\">"
echo "<P><font color=red>$catnamereq: <INPUT name=category type=\"text\"> $catnamedo</font></P>"
echo "</FORM>"

categoryurl=${category//\"/\%22}
categorysql=${category//\"/\"\'\"\'\"}

if [ "$category" != '' ]
then
  echo "<br />$submenudesc <a href=\"http://ru.wikipedia.org/w/index.php?title=Category:$categoryurl\">$category</a>"
  convertedcat=$( echo $categorysql | sed -e 's/ /_/g' )

  echo "<ol>"
  {
    echo SELECT title                                \
                FROM ruwiki_p.categorylinks,         \
                     ruwiki0                         \
                     WHERE id=cl_from and            \
                           cl_to=\"${convertedcat}\" \
                     ORDER BY title ASC\;
  } | $sql 2>&1 | { 
                    while read -r line
                      do handle_category "$line"
                    done
                  }
  echo "</ol>"
  echo $listend
else
  echo "<h4>$top1name</h4>"

  echo "<ol>"
  {
    echo SELECT cv_title,                 \
                cv_isocount,              \
                100\*cv_isocount/cv_count \
                FROM catvolume0           \
                ORDER BY cv_isocount DESC \
                LIMIT 100\;
  } | $sql 2>&1 | { 
                    while read -r line
                      do handle_catlist "$line"
                    done
                  }
  echo "</ol>"
  echo $listend

  echo "<h4>$top2name</h4>"

  echo "<ol>"
  {
    echo SELECT cv_title,                            \
                cv_isocount,                         \
                100\*cv_isocount/cv_count as pcnt    \
                FROM catvolume0                      \
                ORDER BY pcnt DESC, cv_isocount DESC \
                LIMIT 100\;
  } | $sql 2>&1 | { 
                    while read -r line
                      do handle_catlist "$line"
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
