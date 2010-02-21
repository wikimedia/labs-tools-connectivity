#!/bin/bash
 #
 # Works on the Toolserver.
 #
 # Authors: [[:ru:user:Mashiah Davidson]]
 #
 # Purpose: 
 #
 #      [[:en:Connectivity (graph theory)|Connectivity]] analysis script for
 #      [[:ru:|Russian Wikipedia]] and probably others if ready to introduce
 #      some of guidances like
 #            - what is an article, 
 #            - what is a relevant link,
 #            - what is an isolated/orphaned article,
 #            - what is a dead-end article,
 #            - what is a chronological article,
 #            - what is a colloborative list of article names
 #            - what the disambiguation is and so on.
 # 
 # Use: Bash command prompt (or better use with screen)
 #
 # ./isolated.sh <lang> nomr nostat - to run just for analysis
 # ./isolated.sh <lang> nostat      - to enable multiple redirects resolving
 # ./isolated.sh <lang> nomr        - to enable cluster chains statistics upload
 # ./isolated.sh <lang>             - like we do in Ruwiki
 # ./isolated.sh <lang> ... limit=3 - reduces largest allowed claster size down
 #                                    from 20 (default) to 3,
 #                                    zero states for no limit
 #
 # Default output:
 #
 #      1. Useful informative output on stdout
 #      2. Files archieved to <lang>.today.7z at some stage:
 #         - Wrong redirects list                        (<ts>.wr.txt)
 #         - Dead end pages not yet templated            (<ts>.deset.txt) 
 #         - Articles with links still marked as deadend (<ts>.derem.txt)
 #         - Isolated articles not yet templated         (<ts>.<chain>.txt)
 #         - Articles still marked as isolated           (<ts>.orem.txt)
 #      3. Files archieved to <lang>.info.7z at some stage:
 #         - Multiple redirects list                     (<ts>.mr.info)
 #      4. Files archieved to <lang>.stat.7z at some stage:
 #         - Claster chains for zero namespace redirects (<ts>.redirects.stat)
 #         - Claster chains for articles                 (<ts>.articles.stat)
 #         - Claster chains for categories               (<ts>.categories.stat)
 #      5. Redirects in category namespace - if any      (<ts>.r.txt)
 #
 # Error handling:
 #
 #      See <lang>.debug.log if created or the last file modified.
 #
 # <pre>

source ./isoinv

#
# Server for connection depends on the target language
#
server=$( ./toolserver.sh "$language" skip_infecting )

#
# Initialize variables: $dbserver, $dbhost, $usr.
#
# Creates sql( $server ) function.
#
source ../cgi-bin/ts $server

rm -f ./*.info ./*.txt ./*.stat ${language}.debug.log ${language}.no_stat.log ${language}.no_templates.log no_mr.log stats_done.log

time { 
  {
    echo "SET SESSION TRANSACTION ISOLATION LEVEL READ UNCOMMITTED;"

    #
    # New language database might have to be created.
    #
    echo "create database if not exists u_${usr}_golem_s${dbserver}_${language_sql};"

    #
    # Switch to the language database just created.
    #
    echo "use u_${usr}_golem_s${dbserver}_${language_sql};"

    #
    # Configure the target wikipedia language name for analysis
    #
    echo "set @target_lang='$language';"

    #
    # Set master server id
    #
    echo "set @master_server_id=$server;"

    #
    # Root page for various language related configurations
    #
    echo "set @i18n_page='$prjp';"

    cat toolserver.sql

    echo "select dbname_for_lang( '$language' ) into @dbname;"

    cat projector.sql
    cat memory.sql
    cat handle.sql
    cat replag.sql
    cat namespacer.sql
    cat categorizer.sql
    cat redirector.sql
    cat disambig.sql
    cat deadlocktor.sql
    cat templator.sql
    cat isolated.sql
    cat iwikispy.sql
    cat suggestor.sql
    cat creatorizer.sql
    cat cgi.sql

    #
    # real start time
    #
    echo "CALL actual_replag( '$language' );"

    #
    # Categorizer setup, prefetch categories namespace (14)
    # and holds categories list.
    #
    # Creates nr14, r14 and categories.
    #
    echo 'CALL categories();'

    #
    # Choose the right limit for recursion depth allowed.
    # Set the recursion depth to 255 for the first run
    # and then set it e.g. the maximal clusters chain length doubled.
    #
    echo "SET max_sp_recursion_depth=255;"

    #
    # This function collects all the project settings configured on
    # various wiki pages.
    #
    echo "CALL obtain_project_settings( '$language' );"

    #
    # From now on the templates are the subject of our interest.
    #
    # We gonna use them for massive cleanup of links to disambiguation pages
    # as well as for collaborative lists determining (excluding links from
    # templates for more valid computation of links per bytes ratio).
    #
    echo "CALL collect_template_pages( 0 );"

    #
    # Analyze zero namespace connectivity.
    #
    echo "CALL zero_namespace_connectivity( ${claster_limit} );"

    echo "CALL replag( '$language' );"

    #
    # Analyze categorytree namespace connectivity and prepare categoryspruce.
    # No limit on claster size.
    #
    echo 'CALL categorytree_connectivity( 0 );'

    #
    # Isolated by category,
    # Suggestor,
    # Creatorizer.
    #
    echo "CALL zero_namespace_postponed_tools( $server );"

    #
    # New project database may have to be created.
    #
    echo "create database if not exists u_${usr}_golem_p;"

    #
    # Switch to the project database just created.
    #
    echo "use u_${usr}_golem_p;"

    #
    # Prepare a shared log table with actuality data for languages.
    #
    echo "create table if not exists language_stats ( lang VARCHAR(16) BINARY NOT NULL default '', ts TIMESTAMP(14) NOT NULL, PRIMARY KEY (lang) ) ENGINE=MyISAM;"

    #
    # a bugfix for zh-classic problem
    # to be deleted once the problem is finally fixed
    #
    echo "alter table language_stats modify lang varchar (16) binary not null default '';"
    echo "update language_stats set lang='zh-classical', ts=language_stats.ts where lang='zh-classic';"

    #
    # Signed record to the public log on analysis actuality.
    #
    echo "CALL emit_for_everywhere( '$language', '$usr' );"
  } | $( sql $server ) 2>&1 | ./handle.sh $cmdl
}

# </pre>
