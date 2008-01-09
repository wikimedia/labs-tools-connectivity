#!/bin/bash

# Mashiah Davidson: # Thanks a lot to Chris F.A. Johnson for my time saved.
# This function copied as is from 
# http://www.unixreview.com/documents/s=10116/ur0701i/parse-query.sh.txt
parse_query() #@ USAGE: parse_query var ...                                                                 
{
    local var val
    local IFS='&'
    vars="&$*&"
    [ "$REQUEST_METHOD" = "POST" ] && read QUERY_STRING
    set -f
    for item in $QUERY_STRING
    do
      var=${item%%=*}
      val=${item#*=}
      val=${val//+/ }
      case $vars in
          *"&$var&"* )
              case $val in
                  *%[0-9a-fA-F][0-9a-fA-F]*)
                       val=$( printf "%b" "${val//\%/\\x}." )
                       val=${val%.}
              esac
              eval "$var=\$val"
              ;;
      esac
    done
    set +f
}

handle_catlist ()
{
  local line=$1
  local suggest=$2
  local name=$( echo $line | sed -e 's/^\([^ ]\+\) \([^ ]\+\)/\1/g' )
  local volume=$( echo $line | sed -e 's/^\([^ ]\+\) \([^ ]\+\)/\2/g' )
  name=${name//_/ }
  local cname=${name//\?/\%3F}
  cname=${cname//\&/\%26}
  cname=${cname//\"/\%22}
  echo "<li><a href=\"/~mashiah/cgi-bin/suggest.sh?category=$name&suggest=$suggest\">$name</a>: $volume</li>"
}

handle_dsmbg ()
{
  local line=$1
  local test=$( echo $line | sed -e 's/^\:\:\([^\:].*\)$/\1/' )
  local article=$( echo $line | sed -e 's/^\:\:\:\(.*\)$/\1/' )

  if [ "${test:0:2}" != '::' ]
  then
    test=${test//_/ }
    local ctest=${test//\?/\%3F}
    ctest=${ctest//\&/\%26}
    ctest=${ctest//\"/\%22}
    echo "<li><b><a href=\"http://ru.wikipedia.org/w/index.php?title=$ctest\" target=\"_blank\">$test</a></b></link>"
  else
    article=${article//_/ }
    local carticle=${article//\?/\%3F}
    carticle=${carticle//\&/\%26}
    carticle=${carticle//\"/\%22}
    echo "<li>&nbsp;&nbsp;&nbsp;<a href=\"http://ru.wikipedia.org/w/index.php?title=$carticle\" target=\"_blank\">$article</a></link>"
  fi
}

handle_lnk ()
{
  local line=$1
  local test=$( echo $line | sed -e 's/^\:\:\([^\:].*\)$/\1/' )
  local article=$( echo $line | sed -e 's/^\:\:\:\(.*\)$/\1/' )

  if [ "${test:0:2}" != '::' ]
  then
    echo "<li><b><a href=\"http://$test.wikipedia.org\" target=\"_blank\">$test</a></b></li>"
  else
    article=${article//_/ }
    local carticle=${article//\?/\%3F}
    carticle=${carticle//\&/\%26}
    carticle=${carticle//\"/\%22}
    echo "<li>&nbsp;&nbsp;&nbsp;<a href=\"http://ru.wikipedia.org/w/index.php?title=$carticle\" target=\"_blank\">$article</a></li>"
  fi
}

handle_trns ()
{
  local line=$1
  local test=$( echo $line | sed -e 's/^\:\:\([^\:].*\)$/\1/' )
  local article=$( echo $line | sed -e 's/^\:\:\:\(.*\)$/\1/' )

  if [ "${test:0:2}" != '::' ]
  then
    lang=$test;
    echo "<li><b><a href=\"http://${lang}.wikipedia.org\" target=\"_blank\">$lang</a></b></li>"
  else
    article=${article//_/ }
    local carticle=${article//\?/\%3F}
    carticle=${carticle//\&/\%26}
    carticle=${carticle//\"/\%22}
    echo "<li>&nbsp;&nbsp;&nbsp;<a href=\"http://${lang}.wikipedia.org/w/index.php?title=$carticle\" target=\"_blank\">$article</a></li>"
  fi
}

handle_category ()
{
  local line=$1
  line=${line//_/ }
  local lineurl=${line//\?/\%3F}
  lineurl=${lineurl//\&/\%26}
  lineurl=${lineurl//\"/\%22}
  echo "<li><a href=\"/~mashiah/cgi-bin/suggest.sh?title=$lineurl\"\>$line</a></li>"
}

echo Content-type: text/html
echo ""

cat << EOM
﻿<?xml version="1.0" encoding="UTF-8" ?>
<!DOCTYPE html PUBLIC "-//W3C//DTD XHTML 1.0 Transitional//EN"
    "http://www.w3.org/TR/xhtml1/DTD/xhtml1-transitional.dtd">
<html>
 <head>
  <title>Suggest a link for isolated articles</title><link rel="stylesheet" type="text/css" href="/~mashiah/main.css" media="all" /><style type="text/css">
  
  </style>
 </head>
 <body>
  <a href="/"><img id="poweredbyicon" src="/~mashiah/wikimedia-toolserver-button.png" alt="Powered by
    Wikimedia-Toolserver" /></a>
  <h1><a href="/~mashiah">Mashiah's Projects</a></h1>

<h2>contact</h2>
<ul>
<li>see <a href="http://ru.wikipedia.org/wiki/User:Mashiah_Davidson">my russian userpage</a>, <a href="http://ru.wikipedia.org/wiki/User:Голем">my bot's page</a> and <a href="http://ru.wikipedia.org/wiki/User Talk:Голем">our shared discussion</a></li>
<li>look for me (nick: mashiah) in <a href="irc://irc.freenode.net/wikimedia-toolserver">#wikimedia-toolserver</a> on freenode</li>
</ul>


<h2>suggest a link for isolated articles (ruwiki)</h2>
<FORM action=""/~mashiah/cgi-bin/suggest.sh"" method="post">
<P><font color=red>Enter your isolated article name: <INPUT name=title type="text"> and hit Enter</font></P>
</FORM>
EOM

usr=$( cat ~/.my.cnf | grep 'user ' | sed 's/^user = \([a-z]*\)$/\1/' )
pwd=$( cat ~/.my.cnf | grep 'password ' | sed 's/^password = \"\([^\"]*\)\"$/\1/' )
sql="mysql --host=sql-s3 -A --user=${usr} --password=${pwd} --database=u_${usr} -N"

parse_query title
parse_query listby
parse_query shift
parse_query category
parse_query suggest

shiftnext=$((shift+100))
shiftprev=$((shift-100))

case $listby in
'')
  if [ "$title" = '' ]
  then
    if [ "$category" = '' ]
    then
      echo "<h3>Suggestions by article categories for</h4>"
      echo "<h4><a href=\"/~mashiah/cgi-bin/suggest.sh?listby=disambigcat\">disambiguation links resolving</a></h4>"
      echo "<h4><a href=\"/~mashiah/cgi-bin/suggest.sh?listby=interlinkcat\">linking based on interwiki</a></h4>"
      echo "<h4><a href=\"/~mashiah/cgi-bin/suggest.sh?listby=translatecat\">translation and linking</a></h4>"
      echo "<h4>all above operations</h4>"
      echo "<font color=red>Not yet implemented.</font>"

      echo "<h3>List all articles with suggestions for</h4>"
      echo "<h4><a href=\"/~mashiah/cgi-bin/suggest.sh?listby=disambig\">disambiguation links resolving</a></h4>"
      echo "<h4><a href=\"/~mashiah/cgi-bin/suggest.sh?listby=interlink\">linking based on interwiki</a></h4>"
      echo "<h4><a href=\"/~mashiah/cgi-bin/suggest.sh?listby=translate\">translation and linking</a></h4>"
    else
      case $suggest in
      'disambig')
        echo "<h4>$category</h4>"
        echo "this is a list of isolated articles <b>linked from linked disambiguation pages</b>,<br />"
        echo "see also:"
        echo "<ul>"
        echo "<li><a href='/~mashiah/cgi-bin/suggest.sh?category=$category&suggest=interlink'>list of isolated articles <b>with linking suggestions</b></a></li>"
        echo "<li><a href='/~mashiah/cgi-bin/suggest.sh?category=$category&suggest=translate'>list of isolated articles <b>with translation suggestions</b></a></li>"
        echo "<li><b><a href='/~mashiah/cgi-bin/category.sh?category=$category'>list of all isolated articles for this category</a></b></li>"
        echo "</ul>"
        convertedcat=$( echo $category | sed -e 's/ /_/g' )

        echo "<ol>"
        {
          echo SELECT DISTINCT title                           \
                      FROM ruwiki_p.categorylinks,             \
                           ruwiki0,                            \
                           a2i                                 \
                           WHERE id=cl_from and                \
                                 cl_to=\'${convertedcat}\' and \
                                 a2i_to=title                  \
                           ORDER BY title ASC\;
        } | $sql 2>&1 | { 
                          while read -r line
                            do handle_category "$line"
                          done
                        }
        echo "</ol>"
        echo "end of the list"
        ;;
      'interlink')
        echo "<h4>$category</h4>"
        echo "this is a list of isolated articles with <b>linking suggestions</b>,<br />"
        echo "see also:"
        echo "<ul>"
        echo "<li><a href='/~mashiah/cgi-bin/suggest.sh?category=$category&suggest=disambig'>list of isolated articles <b>linked from linked disambiguation pages</b></a></li>"
        echo "<li><a href='/~mashiah/cgi-bin/suggest.sh?category=$category&suggest=translate'>list of isolated articles <b>with translation suggestions</b></a></li>"
        echo "<li><b><a href='/~mashiah/cgi-bin/category.sh?category=$category'>list of all isolated articles for this category</a></b></li>"
        echo "</ul>"
        convertedcat=$( echo $category | sed -e 's/ /_/g' )

        echo "<ol>"
        {
          echo SELECT DISTINCT title                           \
                      FROM ruwiki_p.categorylinks,             \
                           ruwiki0,                            \
                           res                                 \
                           WHERE id=cl_from and                \
                                 cl_to=\'${convertedcat}\' and \
                                 isolated=id                   \
                           ORDER BY title ASC\;
        } | $sql 2>&1 | { 
                          while read -r line
                            do handle_category "$line"
                          done
                        }
        echo "</ol>"
        echo "end of the list"
        ;;
      'translate')
        echo "<h4>$category</h4>"
        echo "this is a list of isolated articles with <b>translation suggestions</b>,<br />"
        echo "see also:"
        echo "<ul>"
        echo "<li><a href='/~mashiah/cgi-bin/suggest.sh?category=$category&suggest=disambig'>list of isolated articles <b>linked from linked disambiguation pages</b></a></li>"
        echo "<li><a href='/~mashiah/cgi-bin/suggest.sh?category=$category&suggest=interlink'>list of isolated articles <b>with linking suggestions</b></a></li>"
        echo "<li><b><a href='/~mashiah/cgi-bin/category.sh?category=$category'>list of all isolated articles for this category</a></b></li>"
        echo "</ul>"
        convertedcat=$( echo $category | sed -e 's/ /_/g' )

        echo "<ol>"
        {
          echo SELECT DISTINCT title                           \
                      FROM ruwiki_p.categorylinks,             \
                           ruwiki0,                            \
                           tres                                \
                           WHERE id=cl_from and                \
                                 cl_to=\'${convertedcat}\' and \
                                 isolated=id                   \
                           ORDER BY title ASC\;
        } | $sql 2>&1 | { 
                          while read -r line
                            do handle_category "$line"
                          done
                        }
        echo "</ol>"
        echo "end of the list"
        ;;
      *) ;;
      esac
    fi
  else
    titleurl=${title//\"/\%22}
    titlesql=${title//\"/\"\'\"\'\"}

    convertedtitle=$( echo $titleurl | sed -e 's/?/\%3F/g' )
    convertedtitle=$( echo $convertedtitle | sed -e 's/&/\%26/g' )
    echo "<h4><a href=\"http://ru.wikipedia.org/wiki/$convertedtitle\">$title</a></h4>"
    echo "<h5>may have linked through disambiguation page</h5>"
    echo "Based on disambiguation links analysis, this isolated article may become linked from the following articles:<br />"

    echo "<font color=red>"
    echo "Note that chronological articles and collaborative list do not form valid links.<br />"
    echo "They can be considered for links pointing disambiguation pages cleanup.<br />"
    echo "</font>"

    convertedtitle=$( echo $titlesql | sed -e 's/ /_/g' )
    echo "<ul>"
    {
      echo CALL dsuggest\(\"$convertedtitle\"\)\;
    } | $sql 2>&1 | {
                      while read -r line
                        do handle_dsmbg "$line"
                      done
                    }
    echo "</ul>"
    echo "end of the list"

    echo "<h5>other languages based suggestion for linking</h5>"
    echo "Interwiki analysis shows that interlinked articles are linked in their language sections, and the foreign linkers also have interwiki to ru:<br />"

    echo "<font color=red>"
    echo "Note that chronological articles and collaborative list do not form valid links.<br />"
    echo "</font>"

    echo "<ul>"
    {
      echo CALL interwiki_suggest\(\"$convertedtitle\"\)\;
    } | $sql 2>&1 | {
                      while read -r line
                        do handle_lnk "$line"
                      done
                    }
    echo "</ul>"
    echo "end of the list"

    echo "<h5>suggestion for translation</h5>"
    echo "Interwiki analysis shows that interlinked articles are linked in their language sections, so linking pages can be translated:<br />"

    echo "<font color=red>"
    echo "Note that chronological articles and collaborative list do not form valid links.<br />"
    echo "</font>"

    echo "<ul>"
    {
      echo CALL interwiki_suggest_translate\(\"$convertedtitle\"\)\;
    } | $sql 2>&1 | { 
                      lang=''
                      while read -r line
                        do handle_trns "$line"
                      done
                    }
    echo "</ul>"
    echo "end of the list"
  fi;;
'disambig')
  echo "<h3>List all articles with suggestions for</h4>"
  echo "<h4>disambiguation links resolving</h4>"
  echo "<h4><a href=\"/~mashiah/cgi-bin/suggest.sh?listby=interlink\">linking based on interwiki</a></h4>"
  echo "<h4><a href=\"/~mashiah/cgi-bin/suggest.sh?listby=translate\">translation and linking</a></h4>"
  echo "Isolated articles below are linked from disambiguation pages, which are also linked from regular articles.<br />"
  echo "This is a chance for both, making isolated articles linked, or making disambiguation pages not linked from articles directly.<br />"

  echo "<ol>"
  {
    echo SELECT DISTINCT a2i_to \
                FROM a2i        \
                ORDER BY a2i_to ASC\;
  } | $sql 2>&1 | {
                    while read -r line
                      do handle_category "$line"
                    done
                  } 
  echo "</ol>"
  echo "end of the list"

  echo "<h3>Suggestions by article categories for</h4>"
  echo "<h4><a href=\"/~mashiah/cgi-bin/suggest.sh?listby=disambigcat\">disambiguation links resolving</a></h4>"
  echo "<h4><a href=\"/~mashiah/cgi-bin/suggest.sh?listby=interlinkcat\">linking based on interwiki</a></h4>"
  echo "<h4><a href=\"/~mashiah/cgi-bin/suggest.sh?listby=translatecat\">translation and linking</a></h4>"
  echo "<h4><a href=\"/~mashiah/cgi-bin/suggest.sh\">all above operations</a></h4>"
  ;;
'disambigcat')
  echo "<h3>Suggestions by article categories for</h4>"
  echo "<h4>disambiguation links resolving</h4>"
  echo "<h4><a href=\"/~mashiah/cgi-bin/suggest.sh?listby=interlinkcat\">linking based on interwiki</a></h4>"
  echo "<h4><a href=\"/~mashiah/cgi-bin/suggest.sh?listby=translatecat\">translation and linking</a></h4>"
  echo "<h4><a href=\"/~mashiah/cgi-bin/suggest.sh\">all above operations</a></h4>"
  echo "Categories below are ordered by amount of isolated articles having links from disambiguations, which are also linked from other articles.<br />"

  echo "<br />"
  if [ $((shift)) -gt 0 ]
  then
    echo "<a href=\"/~mashiah/cgi-bin/suggest.sh?listby=disambigcat&shift=$shiftprev\">previous 100</a> "
  fi
  echo "<a href=\"/~mashiah/cgi-bin/suggest.sh?listby=disambigcat&shift=$shiftnext\">next 100</a>"
  echo "<ol start=$((shift+1))>"
  {
    echo SELECT cv_title,                 \
                cv_dsgcount               \
                FROM catvolume            \
                ORDER BY cv_dsgcount DESC \
                LIMIT $((shift)),100\;
  } | $sql 2>&1 | { 
                    while read -r line
                      do handle_catlist "$line" 'disambig'
                    done
                  }
  echo "</ol>"
  if [ $((shift)) -gt 0 ]
  then
    echo "<a href=\"/~mashiah/cgi-bin/suggest.sh?listby=disambigcat&shift=$shiftprev\">previous 100</a> "
  fi
  echo "<a href=\"/~mashiah/cgi-bin/suggest.sh?listby=disambigcat&shift=$shiftnext\">next 100</a>"

  echo "<h3>List all articles with suggestions for</h4>"
  echo "<h4><a href=\"/~mashiah/cgi-bin/suggest.sh?listby=disambig\">disambiguation links resolving</a></h4>"
  echo "<h4><a href=\"/~mashiah/cgi-bin/suggest.sh?listby=interlink\">linking based on interwiki</a></h4>"
  echo "<h4><a href=\"/~mashiah/cgi-bin/suggest.sh?listby=translate\">translation and linking</a></h4>"
  ;;
'interlink')
  echo "<h3>List all articles with suggestions for</h4>"
  echo "<h4><a href=\"/~mashiah/cgi-bin/suggest.sh?listby=disambig\">disambiguation links resolving</a></h4>"
  echo "<h4>linking based on interwik</h4>"
  echo "<h4><a href=\"/~mashiah/cgi-bin/suggest.sh?listby=translate\">translation and linking</a></h4>"
  echo "<h4><a href=\"/~mashiah/cgi-bin/suggest.sh\">all above operations</a></h4>"
  echo "<ol>"
  {
    echo SELECT DISTINCT title    \
                FROM res,         \
                     ruwiki0      \
                WHERE id=isolated \
                ORDER BY title ASC\;
  } | $sql 2>&1 | {
                    while read -r line
                      do handle_category "$line"
                    done
                  }
  echo "</ol>"
  echo "end of the list"

  echo "<h3>Suggestions by article categories for</h4>"
  echo "<h4><a href=\"/~mashiah/cgi-bin/suggest.sh?listby=disambigcat\">disambiguation links resolving</a></h4>"
  echo "<h4><a href=\"/~mashiah/cgi-bin/suggest.sh?listby=interlinkcat\">linking based on interwiki</a></h4>"
  echo "<h4><a href=\"/~mashiah/cgi-bin/suggest.sh?listby=translatecat\">translation and linking</a></h4>"
  echo "<h4><a href=\"/~mashiah/cgi-bin/suggest.sh\">all above operations</a></h4>"
  ;;
'interlinkcat')
  echo "<h3>Suggestions by article categories for</h4>"
  echo "<h4><a href=\"/~mashiah/cgi-bin/suggest.sh?listby=disambigcat\">disambiguation links resolving</a></h4>"
  echo "<h4>linking based on interwiki</h4>"
  echo "<h4><a href=\"/~mashiah/cgi-bin/suggest.sh?listby=translatecat\">translation and linking</a></h4>"
  echo "<h4><a href=\"/~mashiah/cgi-bin/suggest.sh\">all above operations</a></h4>"
  echo "Categories below are ordered by amount of isolated articles, which may have linked, because some of interwiki links for that articles point to linked pages and linking articles also have backward intewiki links.<br />"

  echo "<br />"
  if [ $((shift)) -gt 0 ]
  then
    echo "<a href=\"/~mashiah/cgi-bin/suggest.sh?listby=disambigcat&shift=$shiftprev\">previous 100</a> "
  fi
  echo "<a href=\"/~mashiah/cgi-bin/suggest.sh?listby=disambigcat&shift=$shiftnext\">next 100</a>"
  echo "<ol start=$((shift+1))>"
  {
    echo SELECT cv_title,                 \
                cv_ilscount               \
                FROM catvolume            \
                ORDER BY cv_ilscount DESC \
                LIMIT $((shift)),100\;
  } | $sql 2>&1 | { 
                    while read -r line
                      do handle_catlist "$line" 'interlink'
                    done
                  }
  echo "</ol>"
  if [ $((shift)) -gt 0 ]
  then
    echo "<a href=\"/~mashiah/cgi-bin/suggest.sh?listby=disambigcat&shift=$shiftprev\">previous 100</a> "
  fi
  echo "<a href=\"/~mashiah/cgi-bin/suggest.sh?listby=disambigcat&shift=$shiftnext\">next 100</a>"

  echo "<h3>List all articles with suggestions for</h4>"
  echo "<h4><a href=\"/~mashiah/cgi-bin/suggest.sh?listby=disambig\">disambiguation links resolving</a></h4>"
  echo "<h4><a href=\"/~mashiah/cgi-bin/suggest.sh?listby=interlink\">linking based on interwiki</a></h4>"
  echo "<h4><a href=\"/~mashiah/cgi-bin/suggest.sh?listby=translate\">translation and linking</a></h4>"
  ;;
'translate')
  echo "<h3>List all articles with suggestions for</h4>"
  echo "<h4><a href=\"/~mashiah/cgi-bin/suggest.sh?listby=disambig\">disambiguation links resolving</a></h4>"
  echo "<h4><a href=\"/~mashiah/cgi-bin/suggest.sh?listby=interlink\">linking based on interwiki</a></h4>"
  echo "<h4>translation and linking</h4>"
  echo "<h4><a href=\"/~mashiah/cgi-bin/suggest.sh\">all above operations</a></h4>"
  echo "<ol>"
  {
    echo SELECT DISTINCT title    \
                FROM tres,        \
                     ruwiki0      \
                WHERE id=isolated \
                ORDER BY title ASC\;
  } | $sql 2>&1 | {
                    while read -r line
                      do handle_category "$line"
                    done
                  }
  echo "</ol>"
  echo "end of the list"

  echo "<h3>Suggestions by article categories for</h4>"
  echo "<h4><a href=\"/~mashiah/cgi-bin/suggest.sh?listby=disambigcat\">disambiguation links resolving</a></h4>"
  echo "<h4><a href=\"/~mashiah/cgi-bin/suggest.sh?listby=interlinkcat\">linking based on interwiki</a></h4>"
  echo "<h4><a href=\"/~mashiah/cgi-bin/suggest.sh?listby=translatecat\">translation and linking</a></h4>"
  echo "<h4><a href=\"/~mashiah/cgi-bin/suggest.sh\">all above operations</a></h4>"
  ;;
'translatecat')
  echo "<h3>Suggestions by article categories for</h4>"
  echo "<h4><a href=\"/~mashiah/cgi-bin/suggest.sh?listby=disambigcat\">disambiguation links resolving</a></h4>"
  echo "<h4><a href=\"/~mashiah/cgi-bin/suggest.sh?listby=translatecat\">linking based on interwiki</a></h4>"
  echo "<h4>translation and linking</h4>"
  echo "<h4><a href=\"/~mashiah/cgi-bin/suggest.sh\">all above operations</a></h4>"
  echo "Categories below are ordered by amount of isolated articles, which may have linked after translation of some other articles.<br />"

  echo "<br />"
  if [ $((shift)) -gt 0 ]
  then
    echo "<a href=\"/~mashiah/cgi-bin/suggest.sh?listby=disambigcat&shift=$shiftprev\">previous 100</a> "
  fi
  echo "<a href=\"/~mashiah/cgi-bin/suggest.sh?listby=disambigcat&shift=$shiftnext\">next 100</a>"
  echo "<ol start=$((shift+1))>"
  {
    echo SELECT cv_title,                 \
                cv_tlscount               \
                FROM catvolume            \
                ORDER BY cv_tlscount DESC \
                LIMIT $((shift)),100\;
  } | $sql 2>&1 | { 
                    while read -r line
                      do handle_catlist "$line" 'translate'
                    done
                  }
  echo "</ol>"
  if [ $((shift)) -gt 0 ]
  then
    echo "<a href=\"/~mashiah/cgi-bin/suggest.sh?listby=disambigcat&shift=$shiftprev\">previous 100</a> "
  fi
  echo "<a href=\"/~mashiah/cgi-bin/suggest.sh?listby=disambigcat&shift=$shiftnext\">next 100</a>"

  echo "<h3>List all articles with suggestions for</h4>"
  echo "<h4><a href=\"/~mashiah/cgi-bin/suggest.sh?listby=disambig\">disambiguation links resolving</a></h4>"
  echo "<h4><a href=\"/~mashiah/cgi-bin/suggest.sh?listby=interlink\">linking based on interwiki</a></h4>"
  echo "<h4><a href=\"/~mashiah/cgi-bin/suggest.sh?listby=translate\">translation and linking</a></h4>"
  ;;
*) ;;
esac

cat << EOM

<h2><a href="./category.sh">isolated articles for a particular category (ruwiki)</a></h2>
<h2><a href="./category14.sh">categorytree connectivity (ruwiki)</a></h2>
<h2><a href="./creators.sh">isolated articles creators (ruwiki)</a></h2>

 <body>
</html>
EOM
