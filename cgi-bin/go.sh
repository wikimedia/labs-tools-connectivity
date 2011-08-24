#!/bin/bash

source ./allyouneed

{
  echo "SET @i18n_page='$prjp';"
  echo "CALL obtain_project_settings( '$language' );"

  echo "SELECT getnsprefix(4, '$language');"
  echo "SELECT getnsprefix(14, '$language');"
  echo "SELECT @connectivity_project_root;"
  echo "SELECT @isolated_category_name;"
  echo "SELECT @orphan_param_name;"
  echo "SELECT @deadend_category_name;"
  echo "SELECT @non_categorized_articles_category;"
  echo "SELECT @template_documentation_subpage_name;"
  echo "SELECT @disambiguation_templates_initialized;"

  echo "CALL langwiki2();"
} | $( sql ${dbserver} u_${usr}_golem_p ) 2>&1 | {
  read -r wiknspref

  case "${wiknspref:0:20}" in
  'ERROR 2005 (HY000): ' )
    errorstring="$nodata:<br>${wiknspref:20}"
    ;;
  'ERROR 2003 (HY000): ' )
    errorstring="$dbhost $nohost"
    ;;
  'ERROR 2013 (HY000): ' )
    errorstring="$dbhost $nohost"
    ;;
  'ERROR 1049 (42000): ' )
    errorstring="$noudb"
    ;;
  'ERROR 1045 (28000): ' )
    errorstring="$hostisnotallowed"
    ;;
  'ERROR 1130 (00000): ' )
    errorstring="$hostisnotallowed"
    ;;
  'ERROR 1146 (42S02) a')
    errorstring="$dbjustcreated"
    ;;
  'ERROR 1054 (42S22) a')
    errorstring="$dbjustcreated"
    ;;
  'ERROR 1129 (HY000): ')
    errorstring="$dbhostblocked"
    ;;
  *)
    read -r catnspref
    read -r project_page
    read -r isolated_category
    read -r orphan_param
    read -r deadend_category
    read -r nca_category
    read -r template_doc
    read -r disambiguating_templates

    isolated_category="${catnspref}${isolated_category}"
    deadend_category="${catnspref}${deadend_category}"
    nca_category="${catnspref}${nca_category}"

    read -r languages1
    read -r languages2
    read -r languages3
    read -r languages4
    read -r avgupd4missconf
    ;;
  esac


  #
  # Standard page header
  #
  the_header

#
# For debugging output a variable here
#
#  echo "<br>$anysrv"
#  echo "<br>$wiknspref"

  if [ "$errorstring" = '' ]
  then
    if [ "$language" = '' ]
    then
      the_content
    else
      if [ "$neverrun" = '' ]
      then
        if [ "$listby" = 'categoryspruce' ] || [ $disambiguating_templates -gt 0 ]
        then
          if [ "$listby" != 'disambig,template' ] || [ "$template_doc" != '' ]
          then
            the_content
          else
            echo "<h2><font color=\"red\">$templatedoc_improperly_configured <a href='http://$language.wikipedia.org/wiki/${wiknspref}${prjp}/TemplateDoc'>[[${wiknspref}${prjp}/TemplateDoc]]</a>.</font></h2>"
          fi
        else
          echo "<h2><font color=\"red\">$disambiguationspage_improperly_configured</font></h2>"
        fi
      else
        echo "<h2><font color=\"red\">$neverrun</font></h2>"
      fi
    fi
  else
    echo "<h2><font color=\"red\">$errorstring</font></h2>"
  fi

  #
  # Standard page footer
  #              
  the_footer
}
