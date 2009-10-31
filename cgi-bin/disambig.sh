#!/bin/bash

script="disambig"
source ./common

handle_dsglist ()
{
  local line=$1

  if no_sql_error "$line"
  then
    line=( $line )
    local name=${line[0]}
    local volume=${line[1]}
    name=${name//_/ }
    local cname=$( url "$name" )
    echo "<li><a href=\"http://$language.wikipedia.org/w/index.php?title=$cname\" target=\"blank\">$name</a>: $volume <small><a href=\"http://$language.wikipedia.org/wiki/Special:WhatLinksHere/$cname\"><font color=green>[[${linkshere}]]</font></a></small></li>"
  fi
}

paraphrase ()
{
  local l_rate=$1
  local lamnt=$2
  local d_rate=$3
  local drdi=$4

  if no_sql_error "$l_rate $d_rate $drdi"
  then
    echo "$l_rate % ($lamnt) $_of_X_does_ $d_rate % $_of_X.<br /><br />"
    echo "$drdi_text: $drdi %.<br />"
  fi
}

how_actual disambiguator

#
# Standard page header
#
the_header

echo "<h1>$thish1</h1>"

{
  echo SELECT \* \
              FROM drdi\;
} | $( sql ${dbserver} u_${usr}_golem_s${dbserver}_${language} ) 2>&1 | { 
                  while read -r line
                    do paraphrase $line
                  done
                }

echo "<h3>$top1name</h3>"
echo "$whatisit1<br><br>"

shifter
echo "<ol start=$((shift+1))>"
{
  echo SELECT d_title,            \
              d_cnt               \
              FROM disambiguate0  \
              ORDER BY d_cnt DESC \
              LIMIT $((shift)),100\;
} | $( sql ${dbserver} u_${usr}_golem_s${dbserver}_${language} ) 2>&1 | { 
                  while read -r line
                    do handle_dsglist "$line"
                  done
                }
echo "</ol>"
shifter

echo "<br />"
echo "<h3>$top2name</h3>"
echo "$whatisit2<br><br>"

shifter
echo "<ol start=$((shift+1))>"
{
  echo SELECT d_title,            \
              d_cnt               \
              FROM disambigtop0   \
              ORDER BY d_cnt DESC \
              LIMIT $((shift)),100\;
} | $( sql ${dbserver} u_${usr}_golem_s${dbserver}_${language} ) 2>&1 | { 
                  while read -r line
                    do handle_alist "$line"
                  done
                }
echo "</ol>"
shifter

#
# Standard page footer
#
the_footer
