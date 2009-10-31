#!/bin/bash

script="lists"
source ./common

handle_rlist ()
{
  local line=$1

  if no_sql_error "$line"
  then
    line=${line//_/ }
    local name=$( url "$line" )
    echo "<li><a href=\"http://$language.wikipedia.org/w/index.php?title=$name&redirect=no&action=edit\" target=\"_blank\">$line</a></li>"
  fi
}

how_actual znswrongredirects

#
# Standard page header
#
the_header

echo "<h1>$thish1</h1>"

echo "<ul class=list>"
echo "<li><a href=\"./suggest.sh?$stdurl&listby=suggest&suggest=disambig\">$fl_disambig</a>"

echo "<li><a href=\"./suggest.sh?$stdurl&listby=suggest&suggest=interlink\">$fl_interlink</a>"

echo "<li><a href=\"./suggest.sh?$stdurl&listby=suggest&suggest=translate\">$fl_translate</a>"

echo "<li><a href=\"./creators.sh?$stdurl&listby=creator&registered=0\">$fl_anonym</a>"

echo "</ul>"

echo "<h3>$fl_wr</h3>"

echo "<br /><font color=red>$fl_wr_desc</font><br />"
echo "<ol>"
{
  echo SELECT wr_title \
              FROM wr0 \
              ORDER BY wr_title ASC\;
} | $( sql ${dbserver} u_${usr}_golem_s${dbserver}_${language} ) 2>&1 | { 
                  while read -r line
                    do handle_rlist "$line"
                  done
                }
echo "</ol>"
echo $listend

#
# Standard page footer
#
the_footer
