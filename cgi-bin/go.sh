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
} | $( sql ${dbserver} u_${usr}_golem_p ) 2>&1 | {
  read -r wiknspref
  if [ "$string" != "$noudb" ]
  then
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
  else
    errorstring=$noudb
  fi

  #
  # Standard page header
  #
  the_header

#
# For debugging
#
#  echo "<br>$anysrv"
#  echo "<br>$dbserver"
#  echo "<br>$wiknspref"
#  echo "<br>$catnspref"
#  echo "<br>$project_page"
#  echo "<br>$isolated_category"
#  echo "<br>$orphan_param"
#  echo "<br>$deadend_category"
#  echo "<br>$nca_category"
#  echo "<br>$template_doc"
#  echo "<br>$disambiguating_templates"

  if [ "$neverrun" = '' ]
  then
    if [ "$listby" = 'categoryspruce' ] || [ $disambiguating_templates -gt 0 ]
    then
      if [ "$listby" != 'disambig,template' ] || [ "$template_doc" != '' ]
      then
        the_content
      else
        echo "<h2><font color=red>$templatedoc_improperly_configured <a href='http://$language.wikipedia.org/wiki/${wiknspref}${prjp}/TemplateDoc'>[[${wiknspref}${prjp}/TemplateDoc]]</a>.</font></h2>"
      fi
    else
      echo "<h2><font color=red>$disambiguationspage_improperly_configured</font></h2>"
    fi
  else
    echo "<h2><font color=red>$neverrun</font></h2>"
  fi

  #
  # Standard page footer
  #              
  the_footer
}
