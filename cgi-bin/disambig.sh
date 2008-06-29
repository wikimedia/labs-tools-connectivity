#!/bin/bash

script="disambig"
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

paraphrase ()
{
  local l_rate=$1
  local d_rate=$2
  local drdi=$3

  if no_sql_error "$l_rate $d_rate $drdi"
  then
    echo "$l_rate % $_of_X_does_ $d_rate % $_of_X.<br /><br />"
    echo "$drdi_text: $drdi %.<br />"
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

#
# The menu
#
the_menu

echo "</td><td width=75%>"

echo "<h1>$thish1</h1>"

echo "$whatisit<br><br>"

{
  echo SELECT \* \
              FROM drdi\;
} | $sql 2>&1 | {
                  while read -r line
                    do paraphrase $line
                  done
                }


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

 </body>
</html>
EOM
