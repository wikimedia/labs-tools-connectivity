#!/bin/bash

source ./common

parse_query interface
parse_query shift
if [ "$interface" != 'ru' ]
then
  interface='en'
fi

source ./common.$interface
source ./disambig.$interface
source ./common2

handle_dsglist ()
{
  local line=$1

  if no_sql_error "$line"
  then
    local suggest=$2
    local name=$( echo $line | sed -e 's/^\([^ ]\+\) \([^ ]\+\)/\1/g' )
    local volume=$( echo $line | sed -e 's/^\([^ ]\+\) \([^ ]\+\)/\2/g' )
    name=${name//_/ }
    local cname=${name//\?/\%3F}
    cname=${cname//\&/\%26}
    cname=${cname//\"/\%22}
    echo "<li><a href=\"http://ru.wikipedia.org/w/index.php?title=$name\" target=\"blank\">$name</a>: $volume</li>"
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
how_actual disambiguator

echo "<h1>$mainh1</h1>"
echo "<table><tr><td width=25% border=10>"
echo -ne "<h1>"
if [ "$interface" = 'ru' ]
then
  echo -ne "<a href=\"./disambig.sh?interface=en&shift=$shift\">[[en:]]</a> [[ru:]]"
else
  echo -ne "[[en:]] <a href=\"./disambig.sh?interface=ru&shift=$shift\">[[ru:]]</a>"
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
echo "<b>4) <font color=red>$disambig</font></b><br />"
echo "<br />"
echo "<b>5) <a href=\"./category14.sh?interface=$interface\">$cattreecon</a></b><br />"
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

echo "$whatisit<br><br>"

shiftnext=$((shift+100))
shiftprev=$((shift-100))

echo -ne "<br />$list1expl "
if [ $((shift)) -gt 0 ]
then
  echo "<a href=\"./disambig.sh?shift=$shiftprev&interface=$interface\">$previous 100</a> "
fi
echo "<a href=\"./disambig.sh?shift=$shiftnext&interface=$interface\">$next 100</a>"
echo "<ol start=$((shift+1))>"
{
  echo SELECT d_title,            \
              d_cnt               \
              FROM disambiguate0  \
              ORDER BY d_cnt DESC \
              LIMIT $((shift)),100\;
} | $sql 2>&1 | { 
                  while read -r line
                    do handle_dsglist "$line"
                  done
                }
echo "</ol>"
if [ $((shift)) -gt 0 ]
then
  echo "<a href=\"./disambig.sh?shift=$shiftprev&interface=$interface\">$previous 100</a> "
fi
echo "<a href=\"./disambig.sh?shift=$shiftnext&interface=$interface\">$next 100</a>"

cat << EOM
</td>
</tr>
</table>

 <body>
</html>
EOM
