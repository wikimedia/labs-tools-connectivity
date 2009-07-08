#!/bin/bash

script="lists"
source ./common

source ./common.$interface
source ./$script.$interface
source ./common2

echo Content-type: text/html
echo ""

handle_rlist ()
{
  local line=$1

  if no_sql_error "$line"
  then
    line=${line//_/ }
    local name=${line//\?/\%3F}
    name=${name//\&/\%26}
    name=${name//\"/\%22}
    echo "<li><a href=\"http://$language.wikipedia.org/w/index.php?title=$name&redirect=no&action=edit\" target=\"_blank\">$line</a></li>"
  fi
}

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
how_actual znswrongredirects

#
# Switching between interface languages at the top right
#
if_lang

#
# The page header at the center
#
the_page_header

echo "<table><tr><td width=25% border=10>"

#
# The menu
#
the_menu

echo "</td><td width=75%>"
echo "<h1>$thish1</h1>"

echo "<ul class=list>"
echo "<li><a href=\"./suggest.sh?language=$language&interface=$interface&listby=disambig\">$fl_disambig</a>"

echo "<li><a href=\"./suggest.sh?language=$language&interface=$interface&listby=interlink\">$fl_interlink</a>"

echo "<li><a href=\"./suggest.sh?language=$language&interface=$interface&listby=translate\">$fl_translate</a>"

echo "<li><a href=\"./creators.sh?language=$language&interface=$interface&registered=0\">$fl_anonym</a>"

echo "</ul>"

echo "<h3>$fl_wr</h3>"

echo "<br /><font color=red>$fl_wr_desc</font><br />"
echo "<ol>"
{
  echo SELECT wr_title \
              FROM wr0 \
              ORDER BY wr_title ASC\;
} | $( sql ${dbserver} u_${usr}_golem_${language} ) 2>&1 | { 
                  while read -r line
                    do handle_rlist "$line"
                  done
                }
echo "</ol>"
echo $listend

cat << EOM
</td>
</tr>
</table>

 </body>
</html>
EOM
