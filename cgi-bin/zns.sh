#!/bin/bash

script="zns"
source ./common

parse_query interface
parse_query resume
if [ "$interface" != 'ru' ]
then
  interface='en'
fi

source ./common.$interface
source ./zns.$interface
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

echo Content-type: text/html
echo ""

case $resume in
 'zns')
  {
    echo SELECT \* \
                FROM zns\;
  } | $sql 2>&1 | {
                    while read -r line
                      do zns $line
                    done
                  }
  ;;
 'fromchrono')
  {
    echo SELECT \* \
                FROM fch\;
  } | $sql 2>&1 | {
                    while read -r line
                      do fromchrono $line
                    done
                  }
  ;;
 'tochrono')
  {
    echo SELECT \* \
                FROM tch\;
  } | $sql 2>&1 | {
                    while read -r line
                      do tochrono $line
                    done
                  }
  ;;
 'timestamp')
    how_actual isolatedbycategory
  ;;
 *)
  ;;
esac
