#!/bin/bash
 #
 # Authors: [[:ru:user:Mashiah Davidson]]
 #          [[:ru:user:Lvova]]
 #

script="zns"
source ./common

parse_query resume

source ./common.$interface
source ./$script.$interface
source ./common2

articles_flexies ()
{
  local articles=$1
  local voice=$2

  __articles=$_articles1

  if [ "$interface" = 'en' ]
  then
    if [ "$articles" != '1' ]
    then
      __articles=$_articles
    fi
  else
    if [ "$voice" = 'active' ]
    then
      __articles=$_articles1_do
    fi
    if [ "${articles:(-1)}" = '5' ] ||
       [ "${articles:(-1)}" = '6' ] ||
       [ "${articles:(-1)}" = '7' ] ||
       [ "${articles:(-1)}" = '8' ] ||
       [ "${articles:(-1)}" = '9' ] ||
       [ "${articles:(-1)}" = '0' ] ||
       [ "${articles:(-2)}" = '11' ] ||
       [ "${articles:(-2)}" = '12' ] ||
       [ "${articles:(-2)}" = '13' ] ||
       [ "${articles:(-2)}" = '14' ]
    then
      __articles=$_articles5678901234
    else
      if [ "${articles:(-1)}" = '2' ] ||
         [ "${articles:(-1)}" = '3' ] ||
         [ "${articles:(-1)}" = '4' ]
      then
        __articles=$_articles234
      fi
    fi
  fi
}

pages_flexies ()
{
  local pages=$1

  __pages=$_pages1

  if [ "$interface" = 'en' ]
  then
    if [ "$pages" != '1' ]
    then
      __pages=$_pages
    fi
  else
    if [ "${pages:(-1)}" = '5' ] ||
       [ "${pages:(-1)}" = '6' ] ||
       [ "${pages:(-1)}" = '7' ] ||
       [ "${pages:(-1)}" = '8' ] ||
       [ "${pages:(-1)}" = '9' ] ||
       [ "${pages:(-1)}" = '0' ] ||
       [ "${pages:(-2)}" = '11' ] ||
       [ "${pages:(-2)}" = '12' ] ||
       [ "${pages:(-2)}" = '13' ] ||
       [ "${pages:(-2)}" = '14' ]
    then
      __pages=$_pages5678901234
    else
      if [ "${pages:(-1)}" = '2' ] ||
         [ "${pages:(-1)}" = '3' ] ||
         [ "${pages:(-1)}" = '4' ]
      then
        __pages=$_pages234
      fi
    fi
  fi
}

lists_flexies ()
{
  local lists=$1

  __lists=$_lists1

  if [ "$interface" = 'en' ]
  then
    if [ "$lists" != '1' ]
    then
      __lists=$_lists
    fi
  else
    if [ "${lists:(-1)}" = '5' ] ||
       [ "${lists:(-1)}" = '6' ] ||
       [ "${lists:(-1)}" = '7' ] ||
       [ "${lists:(-1)}" = '8' ] ||
       [ "${lists:(-1)}" = '9' ] ||
       [ "${lists:(-1)}" = '0' ] ||
       [ "${lists:(-2)}" = '11' ] ||
       [ "${lists:(-2)}" = '12' ] ||
       [ "${lists:(-2)}" = '13' ] ||
       [ "${lists:(-2)}" = '14' ]
    then
      __lists=$_lists5678901234
    else
      if [ "${lists:(-1)}" = '2' ] ||
         [ "${lists:(-1)}" = '3' ] ||
         [ "${lists:(-1)}" = '4' ]
      then
        __lists=$_lists234
      fi
    fi
  fi
}

zns ()
{
  local articles=$1
  local chrono=$2
  local disambigs=$3
  local cllt=$4

  if no_sql_error "$articles $chron $disambigs $cllt"
  then
    articles_flexies $articles passive
    echo "$zns_contains_ $articles $__articles<br />"

    echo "($chrono $_of_them_crono),<br />"

    pages_flexies $disambigs
    lists_flexies $cllt
    if [ "$interface" = 'en' ]
    then
      echo "$disambigs $_disambigs $__pages $_and_ $cllt $_cllt $__lists."
    else
      echo "$disambigs $__pages $_disambigs $_and_ $cllt $__lists $_cllt."
    fi
  fi
}

fromchrono ()
{
  local clinks=$1
  local alinks=$2

  if no_sql_error "$clinks $alinks"
  then
    articles_flexies $clinks passive
    echo "$avg_chrono_links_ $clinks $__articles.<br />"

    articles_flexies $alinks passive
    echo "$other_links_ $alinks $__articles."
  fi
}

tochrono ()
{
  local clratio=$1
  local linksc=$2

  if no_sql_error "$clratio $linksc"
  then
    echo "$clratio % $_of_links_are_to_chrono.<br />"

    articles_flexies $linksc active
    echo "$avg_chrono_is_linked_by_ $linksc $__articles."
  fi
}

resume ()
{
  local resume=$1

  case $resume in
   'zns')
    {
      echo SELECT \* \
                  FROM zns\;
    } | $( sql ${dbserver} u_${usr}_golem_${language} ) 2>&1 | { 
                      while read -r line
                        do zns $line
                      done
                    }
    ;;
   'fromchrono')
    {
      echo SELECT \* \
                  FROM fch\;
    } | $( sql ${dbserver} u_${usr}_golem_${language} ) 2>&1 | { 
                      while read -r line
                        do fromchrono $line
                      done
                    }
    ;;
   'tochrono')
    {
      echo SELECT \* \
                  FROM tch\;
    } | $( sql ${dbserver} u_${usr}_golem_${language} ) 2>&1 | { 
                      while read -r line
                        do tochrono $line
                      done
                    }
    ;;
   *)
    ;;
  esac
}

if [ "$resume" != '' ]
then
  resume $resume
else

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

  #
  # Actuality data at the top left of the page
  #
  how_actual isolatedbycategory

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

  echo "<A name=\"scope\"></A>"
  echo "<h1>$scope</h1>"

  echo "<p>$par1</p>"

  echo "<p>$par2</p>"

  ####################################################################
  #                                                                  #
  #            Main namespace consists of 268267 articles            # 
  #            (4466 of them are chronological articles),            # 
  #      21636 disambiguation pages and 1571 collaborative lists.    # 
  #                                                                  #
  ####################################################################
  echo '<center><div style="align: center; border: 1px solid black; padding: 3px;">'
  resume 'zns'
  echo '</div></center>'

  echo "<p>$par3</p>"

  ####################################################################
  #                                                                  #
  #    Average chronological article links 114 distinct articles.    #
  #         Other articles link in average just 35 articles.         #
  #                                                                  #
  ####################################################################
  echo '<center><div style="align: center; border: 1px solid black; padding: 3px;">'
  resume 'fromchrono'
  echo '</div></center>'

  echo "<p>$par4</p>"

  ####################################################################
  #                                                                  #
  #  16.75% of links between articles are links to chrono articles.  #
  #        Average chrono article is linked from 368 articles.       #
  #                                                                  #
  ####################################################################
  echo '<center><div style="align: center; border: 1px solid black; padding: 3px;">'
  resume 'tochrono'
  echo '</div></center>'

  #
  # Additional static sections for this page
  #
  cat zns1.$interface

  cat << EOM
</td>
</tr>
</table>

 </body>
</html>
EOM

fi
