#!/bin/bash

script="suggest"
source ./common

handle_isotype ()
{
  local line=$1

  if [ "$line" != '' ]
  then
    isotype="$line"
  fi
}

handle_dsmbg ()
{
  local line=$1

  if no_sql_error "$line"
  then
    local test=$( echo $line | sed -e 's/^\:\:\([^\:].*\)$/\1/' )
    local article=$( echo $line | sed -e 's/^\:\:\:\(.*\)$/\1/' )

    if [ "${test:0:2}" != '::' ]
    then
      test=${test//_/ }
      local ctest=$( url "$test" )
      echo "</ol><b><a href=\"http://$language.wikipedia.org/w/index.php?title=$ctest\" target=\"_blank\">$test</a></b> <small><a href=\"http://$language.wikipedia.org/wiki/Special:WhatLinksHere/$ctest\"><font color=green>[[${linkshere}]]</font></a></small></li><ol>"
    else
      article=${article//_/ }
      local carticle=$( url "$article" )
      echo "<li>&nbsp;&nbsp;&nbsp;<a href=\"http://$language.wikipedia.org/w/index.php?title=$carticle\" target=\"_blank\">$article</a></li>"
    fi
  fi
}

handle_lnk ()
{
  local line=$1

  if no_sql_error "$line"
  then
    local test=$( echo $line | sed -e 's/^\:\:\([^\:].*\)$/\1/' )
    local article=$( echo $line | sed -e 's/^\:\:\:\(.*\)$/\1/' )

    if [ "${test:0:2}" != '::' ]
    then
      echo "</ol><b><a href=\"http://$test.wikipedia.org\" target=\"_blank\">$test</a></b><ol>"
    else
      article=${article//_/ }
      local carticle=$( url "$article" )
      echo "<li>&nbsp;&nbsp;&nbsp;<a href=\"http://$language.wikipedia.org/w/index.php?title=$carticle\" target=\"_blank\">$article</a></li>"
    fi
  fi
}

handle_trns ()
{
  local line=$1

  if no_sql_error "$line"
  then
    local test=$( echo $line | sed -e 's/^\:\:\([^\:].*\)$/\1/' )
    local article=$( echo $line | sed -e 's/^\:\:\:\(.*\)$/\1/' )

    if [ "${test:0:2}" != '::' ]
    then
      lang=$test;
      echo "</ol><b><a href=\"http://${lang}.wikipedia.org\" target=\"_blank\">$lang</a></b><ol>"
    else
      article=${article//_/ }
      local carticle=$( url "$article" )
      echo "<li>&nbsp;&nbsp;&nbsp;<a href=\"http://${lang}.wikipedia.org/w/index.php?title=$carticle\" target=\"_blank\">$article</a></li>"
    fi
  fi
}

suggestions ()
{
  echo "<h3>$sggclause0</h3>"
  echo "$sggclause1<br />"
  echo "<font color=red><ul><li>$sggclause2 $sggclause3</li></ul></font>"

  convertedtitle=${titlesql// /_}
  echo "<ol>"
  {
    echo CALL dsuggest\(\"$convertedtitle\"\, \'${language}\'\)\;
  } | $( sql ${dbserver} u_${usr}_golem_s${dbserver}_${language} ) 2>&1 | { 
                    while read -r line
                      do handle_dsmbg "$line"
                    done
                  }
  echo "</ol>"
  echo $listend

  echo "<h3>$sggclause4</h3>"
  echo "$sggclause5<br />"

  echo "<ol>"
  {
    echo CALL interwiki_suggest\(\"$convertedtitle\"\)\;
  } | $( sql ${dbserver} u_${usr}_golem_s${dbserver}_${language} ) 2>&1 | { 
                    while read -r line
                      do handle_lnk "$line"
                    done
                  }
  echo "</ol>"
  echo $listend

  echo "<h3>$sggclause6</h3>"
  echo "$sggclause7<br />"

  echo "<font color=red><ul><li>$sggclause2</li></ul></font>"

  echo "<ol>"
  {
    echo CALL interwiki_suggest_translate\(\"$convertedtitle\"\)\;
  } | $( sql ${dbserver} u_${usr}_golem_s${dbserver}_${language} ) 2>&1 | { 
                    lang=''
                    while read -r line
                      do handle_trns "$line"
                    done
                  }
  echo "</ol>"
  echo $listend
}

case $listby in
'suggest' | 'suggest,category')
  case $suggest in
  'disambig')
    how_actual dsuggestor
    ;;
  'interlink')
    how_actual lsuggestor
    ;;
  'translate')
    how_actual tsuggestor
    ;;
  *)
    how_actual tsuggestor
    ;;
  esac
  ;;
'suggest,foreign' | 'suggest,category,foreign' | 'suggest,foreign,category')
  case $suggest in
  'interlink')
    how_actual lsuggestor
    ;;
  'translate')
    how_actual tsuggestor
    ;;
  *)
    how_actual tsuggestor
    ;;
  esac
  ;;
'suggest,title') 
  how_actual tsuggestor
  ;;
*)
  ;;
esac

#
# Standard page header
#
the_header

echo "<h1>$thish1</h1>"

echo "<FORM action=\"./suggest.sh\" method=\"get\">"
echo "<INPUT type=hidden name=\"interface\" value=\"$interface\">"
echo "<INPUT type=hidden name=\"language\" value=\"$language\">"
echo "<INPUT type=hidden name=\"listby\" value=\"suggest,title\">"
echo "<P><font color=red>$ianamereq: <INPUT name=title type=\"text\"> $activateform</font></P>"
echo "</FORM>"

if [ "$category" != '' ]
then
  #
  # this allows the row passing through all the quotermarks and finaly be
  # delivered in sql as \"
  #
  categorysql=${category//\"/\"\'\\\\\"\'\"}
  categorysqlhere=${category//\"/\"\'\"\'\"}

  convertedcat=${categorysql// /_}
  convertedcathere=${categorysqlhere// /_}
fi


case $listby in
'suggest')
  case $suggest in
  '')
    echo "<br />$clause1<br /><br />"
    echo "<font color=red>$clause2</font><br />"
    echo "<ul><li>$clause3</li><li>$clause4</li></ul>"
    ;;
  'disambig')
    echo "<br />$subclause1<br />"

    echo "<table class=\"sortable infotable\">"
    echo "<tr><th>&#8470;</th><th>$article_title_tr</th><th>$iso_type_tr</th></tr>"
    {
      echo SELECT DISTINCT cat, title       \
                  FROM isdis,               \
                       ruwiki0              \
                  WHERE ruwiki0.id=isdis.id \
                  ORDER BY title ASC\;
    } | $( sql ${dbserver} u_${usr}_golem_s${dbserver}_${language} ) 2>&1 | { 
                      count=0
                      while read -r line
                        do handle_isolates_as_table $((count+1)) "$line"
                        count=$((count+1))
                      done
                    } 
    echo "</table>"
    echo '<script type="text/javascript" src="../sortable.js"></script>'
    ;;
  'interlink')
    echo "<br />$subclause3<br />"

    echo "<table class=\"sortable infotable\">"
    echo "<tr><th>&#8470;</th><th>$article_title_tr</th><th>$iso_type_tr</th></tr>"
    {
      echo SELECT DISTINCT cat, title       \
                  FROM isres,               \
                       ruwiki0              \
                  WHERE ruwiki0.id=isres.id \
                  ORDER BY title ASC\;
    } | $( sql ${dbserver} u_${usr}_golem_s${dbserver}_${language} ) 2>&1 | { 
                      count=0
                      while read -r line
                        do handle_isolates_as_table $((count+1)) "$line"
                        count=$((count+1))
                      done
                    }
    echo "</table>"
    echo '<script type="text/javascript" src="../sortable.js"></script>'
    ;;
  'translate')
    echo "<br />$subclause5<br />"

    echo "<table class=\"sortable infotable\">"
    echo "<tr><th>&#8470;</th><th>$article_title_tr</th><th>$iso_type_tr</th></tr>"
    {
      echo SELECT DISTINCT cat, title        \
                  FROM istres,               \
                       ruwiki0               \
                  WHERE ruwiki0.id=istres.id \
                  ORDER BY title ASC\;
    } | $( sql ${dbserver} u_${usr}_golem_s${dbserver}_${language} ) 2>&1 | { 
                      count=0
                      while read -r line
                        do handle_isolates_as_table $((count+1)) "$line"
                        count=$((count+1))
                      done
                    }
    echo "</table>"
    echo '<script type="text/javascript" src="../sortable.js"></script>'
    ;;
  *) ;;
  esac
  ;;
'suggest,category')
  if [ "$category" != '' ]
  then
    case $suggest in
    'disambig')
      echo "<br />$submenu1desc"

      echo "<table class=\"sortable infotable\">"
      echo "<tr><th>&#8470;</th><th>$article_title_tr</th><th>$iso_type_tr</th></tr>"
      {
        echo CALL isolated_for_category_dsuggestable\(\"$convertedcat\"\, \'${language}\'\)\;
      } | $( sql ${dbserver} u_${usr}_golem_s${dbserver}_${language} ) 2>&1 | { 
                        count=0
                        while read -r line
                          do handle_isolates_as_table $((count+1)) "$line"
                          count=$((count+1))
                        done
                      }
      echo "</table>"
      echo '<script type="text/javascript" src="../sortable.js"></script>'
      ;;
    'interlink')
      echo "<br />$submenu2desc"

      echo "<table class=\"sortable infotable\">"
      echo "<tr><th>&#8470;</th><th>$article_title_tr</th><th>$iso_type_tr</th></tr>"
      {
        echo CALL isolated_for_category_ilsuggestable\(\"$convertedcat\"\, \'${language}\'\)\;
      } | $( sql ${dbserver} u_${usr}_golem_s${dbserver}_${language} ) 2>&1 | { 
                        count=0
                        while read -r line
                          do handle_isolates_as_table $((count+1)) "$line"
                          count=$((count+1))
                        done
                      }
      echo "</table>"
      echo '<script type="text/javascript" src="../sortable.js"></script>'
      ;;
    'translate')
      echo "<br />$submenu3desc"

      echo "<table class=\"sortable infotable\">"
      echo "<tr><th>&#8470;</th><th>$article_title_tr</th><th>$iso_type_tr</th></tr>"
      {
        echo CALL isolated_for_category_itsuggestable\(\"$convertedcat\"\, \'${language}\'\)\;
      } | $( sql ${dbserver} u_${usr}_golem_s${dbserver}_${language} ) 2>&1 | { 
                        count=0
                        while read -r line
                          do handle_isolates_as_table $((count+1)) "$line"
                          count=$((count+1))
                        done
                      }
      echo "</table>"
      echo '<script type="text/javascript" src="../sortable.js"></script>'
      ;;
    *) ;;
    esac
  else
    case "$suggest" in
    'disambig')
      echo "<br />$subclause2<br />"

      echo "<br />"

      shifter
      echo "<ol start=$((shift+1))>"
      {
        echo CALL ordered_cat_list\( \"sgdcatvolume0\", $((shift)) \)\;
      } | $( sql ${dbserver} u_${usr}_golem_s${dbserver}_${language} ) 2>&1 | { 
                        while read -r line
                          do handle_catlist "$line" 'disambig'
                        done
                      }
      echo "</ol>"
      shifter
      ;;
    'interlink')
      echo "<h3>$subclause4name</h3>"
      echo "$subclause4<br /><br />"

      shifter
      echo "<ol start=$((shift+1))>"
      {
        echo CALL ordered_cat_list\( \"sglcatvolume0\", $((shift)) \)\;
      } | $( sql ${dbserver} u_${usr}_golem_s${dbserver}_${language} ) 2>&1 | { 
                        while read -r line
                          do handle_catlist "$line" 'interlink'
                        done
                      }
      echo "</ol>"
      shifter

      ;;
    'translate')
      echo "<br />$subclause6<br />"

      echo "<br />"

      shifter
      echo "<ol start=$((shift+1))>"
      {
        echo CALL ordered_cat_list\( \"sgtcatvolume0\", $((shift)) \)\;
      } | $( sql ${dbserver} u_${usr}_golem_s${dbserver}_${language} ) 2>&1 | { 
                        while read -r line
                          do handle_catlist "$line" 'translate'
                          done
                      }
      echo "</ol>"
      shifter
      ;;
    *) ;;
    esac
  fi
  ;;
'suggest,category,foreign')
  # [ "$category"='' ] && [ "$foreign"!='' ]
  # [ "$suggestn"='interlink' ] || [ "$suggestn"='translate' ]
  # the list of categories for isolates with suggestions for a given language
  
  # list of suggesting foreign languages for a given category containing isolates
  if [ "$category" != '' ]
  then
    if [ "$foreign" = '' ]
    then
      case "$suggest" in
      'interlink')
        echo "<h3>$subclause9name</h3>"
        echo "$subclause9<br /><br />"
        echo "<table class=\"sortable infotable\">"
        echo "<tr><th>$languagename</th><th>$articlestoimprove</th><th>$linkableisolates</th></tr>"
        {
          echo SELECT language.lang,                                   \
                      REPLACE\(english_name,\' \',\'_\'\),             \
                      REPLACE\(native_name,\' \',\'_\'\),              \
                      a_amnt,                                          \
                      i_amnt                                           \
                      FROM sglflcatvolume0,                            \
                           toolserver.language,                        \
                           categories                                  \
                      WHERE sglflcatvolume0.cat=categories.id AND      \
                            categories.title=\"$convertedcathere\" AND \
                            language.lang=sglflcatvolume0.lang         \
                      ORDER BY i_amnt DESC\;
        } | $( sql ${dbserver} u_${usr}_golem_s${dbserver}_${language} ) 2>&1 | { 
                          while read -r line
                            do handle_langlist "$line"
                          done
                        }
        echo "</table>"
        echo '<script type="text/javascript" src="../sortable.js"></script>'
        ;;
      'translate')
        echo "<h3>$subclause10name</h3>"
        echo "$subclause10<br /><br />"
        echo "<table class=\"sortable infotable\">"
        echo "<tr><th>$languagename</th><th>$articlestotranslate</th><th>$linkableisolates</th></tr>"
        {
          echo SELECT language.lang,                                   \
                      REPLACE\(english_name,\' \',\'_\'\),             \
                      REPLACE\(native_name,\' \',\'_\'\),              \
                      a_amnt,                                          \
                      i_amnt                                           \
                      FROM sgtflcatvolume0,                            \
                           toolserver.language,                        \
                           categories                                  \
                      WHERE sgtflcatvolume0.cat=categories.id AND      \
                            categories.title=\"$convertedcathere\" AND \
                            language.lang=sgtflcatvolume0.lang         \
                      ORDER BY i_amnt DESC\;
        } | $( sql ${dbserver} u_${usr}_golem_s${dbserver}_${language} ) 2>&1 | { 
                          while read -r line
                            do handle_langlist "$line"
                          done
                        }
        echo "</table>"
        echo '<script type="text/javascript" src="../sortable.js"></script>'
        ;;
      esac
    else # [ $foreign!='' ]
      echo ""
    fi
  fi
  ;;
'suggest,foreign')
  if [ "$foreign" = '' ]
  then
    case "$suggest" in
    '')
      echo "<h3>$subclause7name</h3>"
      echo "$subclause7<br /><br />"
      echo "<table class=\"sortable infotable\">"
      echo "<tr><th>&#8470;</th><th>$languagename</th><th class=\"linkexistent\">$articlestoimprove</th><th class=\"linkexistent\">$linkableisolates</th><th class=\"translateandlink\">$articlestotranslate</th><th class=\"translateandlink\">$linkableisolates</th></tr>"
      {
        echo SELECT DISTINCT wiki.lang,                       \
                    REPLACE\(english_name,\' \',\'_\'\),      \
                    REPLACE\(native_name,\' \',\'_\'\),       \
                    nisres.a_amnt,                            \
                    nisres.i_amnt,                            \
                    nistres.a_amnt,                           \
                    nistres.i_amnt                            \
                    FROM toolserver.wiki                      \
                         LEFT JOIN toolserver.language        \
                                   ON wiki.lang=language.lang \
                         LEFT JOIN nisres                     \
                                   ON wiki.lang=nisres.lang   \
                         LEFT JOIN nistres                    \
                                   ON wiki.lang=nistres.lang  \
                    WHERE family=\'wikipedia\' AND            \
                          is_closed=0                         \
                    HAVING nisres.i_amnt IS NOT NULL OR       \
                           nistres.i_amnt IS NOT NULL         \
                    ORDER BY size DESC\;
      } | $( sql ${dbserver} u_${usr}_golem_s${dbserver}_${language} ) 2>&1 | { 
                        count=0
                        while read -r line
                          do handle_langlist2 $((count+1)) "$line"
                          count=$((count+1))
                        done
                      }
      echo "</table>"
      echo '<script type="text/javascript" src="../sortable.js"></script>'
      ;;
    'interlink')
      echo "<h3>$subclause7name</h3>"
      echo "$subclause7<br /><br />"
      echo "<table class=\"sortable infotable\">"
      echo "<tr><th>$languagename</th><th>$articlestoimprove</th><th>$linkableisolates</th></tr>"
      {
        echo SELECT nisres.lang,                         \
                    REPLACE\(english_name,\' \',\'_\'\), \
                    REPLACE\(native_name,\' \',\'_\'\),  \
                    a_amnt,                              \
                    i_amnt                               \
                    FROM nisres,                         \
                         toolserver.language             \
                    WHERE language.lang=nisres.lang      \
                    ORDER BY i_amnt DESC\;
      } | $( sql ${dbserver} u_${usr}_golem_s${dbserver}_${language} ) 2>&1 | { 
                        while read -r line
                          do handle_langlist "$line"
                        done
                      }
      echo "</table>"
      echo '<script type="text/javascript" src="../sortable.js"></script>'
      ;;
    'translate')
      echo "<h3>$subclause8name</h3>"
      echo "$subclause8<br /><br />"
      echo "<table class=\"sortable infotable\">"
      echo "<tr><th>$languagename</th><th>$articlestotranslate</th><th>$linkableisolates</th></tr>"
      {
        echo SELECT nistres.lang,                        \
                    REPLACE\(english_name,\' \',\'_\'\), \
                    REPLACE\(native_name,\' \',\'_\'\),  \
                    a_amnt,                              \
                    i_amnt                               \
                    FROM nistres,                        \
                         toolserver.language             \
                    WHERE language.lang=nistres.lang     \
                    ORDER BY i_amnt DESC\;
      } | $( sql ${dbserver} u_${usr}_golem_s${dbserver}_${language} ) 2>&1 | { 
                        while read -r line
                          do handle_langlist "$line"
                        done
                      }
      echo "</table>"
      echo '<script type="text/javascript" src="../sortable.js"></script>'
      ;;
    *) ;;
    esac
  fi
  ;;
'suggest,foreign,category')
  # list of categoris for articles to be translated from the given language.
  
  # one more option:
  ;;
'suggest,title')
  titlesql=${title//\"/\"\'\"\'\"}
  title=${title//_/ }

  echo "<h2><a href=\"http://$language.wikipedia.org/wiki/${title_url}\">$title</a></h2>"

#  # for orphaned and other isolated articles we use different definitions.
#  {
#    echo "SELECT cat FROM ruwiki0 WHERE title=\"${titlesql// /_}\";"
#  } | $( sql ${dbserver} u_${usr}_golem_s${dbserver}_${language} ) 2>&1 | { 
#                    isotype=''
#
#                    while read -r line
#                      do handle_isotype $line
#                    done

   case "$isotype" in
    '')
     echo $r_notrecognized
     ;;
    '_1')
     echo $r_orphaned
     ;;
    *)
     echo "<h4>$isotype</h4>"
     echo $r_isolated
     ;;
   esac
 
   suggestions
#                  }
               
  echo "<h3>$googleonwikipedia</h3>"
  echo "<IFRAME src=\"http://www.google.com/custom?hl=$interface&domains=$language.wikipedia.org&q=${title_url}&sitesearch=$language.wikipedia.org\" width=\"100%\" height=\"1500\" scrolling=\"auto\" frameborder=\"1\">"
  echo "Your user agent does not support frames or is currently configured not to display frames. However, you may <A href=\"http://www.google.com/custom?hl=$interface&domains=$language.wikipedia.org&q=${title_url}&sitesearch=$language.wikipedia.org\">seach with this link</A>."
  echo "</IFRAME>"
  ;;
*) ;;
esac

#
# Standard page footer
#
the_footer
