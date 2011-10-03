 --
 -- Authors: [[:ru:user:Mashiah Davidson]]
 --
 -- Caution: PROCEDUREs defined here obtain connectivity project settings.
 -- 
 -- Shared procedures: obtain_project_settings
 --
 -- <pre>

############################################################
delimiter //

#
# This procedure obtains connecitity project root page name from
# a templated named {{Connectivity project root}} and stores it in
# @connectivity_project_root variable.
#
DROP PROCEDURE IF EXISTS get_connectivity_project_root//
CREATE PROCEDURE get_connectivity_project_root (targetlang VARCHAR(32))
  BEGIN
    DECLARE st VARCHAR(511);

    SET @connectivity_project_root='';

    #
    # SELECT CONCAT( getnsprefix( pl_namespace, 
    #                             '<targetlang>'
    #                           ), pl_title ) INTO @connectivity_project_root
    #        FROM <dbname>.page, 
    #             <dbname>.pagelinks
    #        WHERE pl_from=page_id and
    #              page_namespace=10 and
    #              page_title="Connectivity_project_root"
    #        LIMIT 1;
    #
    SET @st=CONCAT( 'SELECT CONCAT( getnsprefix( pl_namespace, "', targetlang, '" ), pl_title ) INTO @connectivity_project_root FROM ', dbname_for_lang( targetlang ), '.page, ', dbname_for_lang( targetlang ), '.pagelinks WHERE pl_from=page_id and page_namespace=10 and page_title="Connectivity_project_root" LIMIT 1;' );
    PREPARE stmt FROM @st;
    EXECUTE stmt;
    DEALLOCATE PREPARE stmt;

    IF @connectivity_project_root IS NULL
      THEN
        SET @connectivity_project_root='';
    END IF;
  END;
//

#
# This function reads content of the language configuration page and
# intializes the following global variables:
#
# @isolated_category_name      - category containing just isolated subcategories
# @orphan_param_name           - prefix for cluster chains of size 1
# @isolated_ring_param_name    - prefix for clusters of size 2
# @isolated_cluster_param_name - prefix for clusters of size larger than 2
# @old_orphan_category         - optional, just in case it existed
#
DROP PROCEDURE IF EXISTS get_isolated_category_names//
CREATE PROCEDURE get_isolated_category_names (targetlang VARCHAR(32))
  BEGIN
    DECLARE st VARCHAR(511);
    DECLARE stln INT;
    DECLARE dbname VARCHAR(32);

    SELECT dbname_for_lang( targetlang ) INTO dbname;

    SET @isolated_category_name='';
    SET @orphan_param_name='';
    SET @isolated_ring_param_name='';
    SET @isolated_cluster_param_name='';
    SET @old_orphan_category='';

    #
    # Meta-category name for isolated articles.
    #
    SET @st=CONCAT( 'SELECT pl_title INTO @isolated_category_name FROM ', dbname, '.page, ', dbname, '.pagelinks WHERE pl_namespace=14 and page_id=pl_from and page_namespace=4 and page_title="', @i18n_page, '/IsolatedArticles" ORDER BY pl_title ASC LIMIT 1;' );
    PREPARE stmt FROM @st;
    EXECUTE stmt;
    DEALLOCATE PREPARE stmt;

    IF @isolated_category_name IS NULL
      THEN
        SET @isolated_category_name='';
    END IF;

    IF @isolated_category_name!=''
      THEN
        SET stln=2+LENGTH( @isolated_category_name );

        #
        # Sub-category prefix for orphaned articles.
        #
        SET @st=CONCAT( 'SELECT cl_to INTO @orphan_param_name FROM ', dbname, '.page, ', dbname, '.categorylinks WHERE cl_sortkey_prefix="_1" and page_id=cl_from and page_namespace=4 and page_title="', @i18n_page, '/IsolatedArticles" ORDER BY cl_to ASC LIMIT 1;' );
        PREPARE stmt FROM @st;
        EXECUTE stmt;
        DEALLOCATE PREPARE stmt;

        IF @orphan_param_name IS NULL
          THEN
            SET @orphan_param_name='';
        END IF;

        IF @orphan_param_name!=''
          THEN
            SET @orphan_param_name=SUBSTRING( @orphan_param_name FROM stln );
        END IF;

        #
        # Sub-category prefix for isolated pair.
        #
        SET @st=CONCAT( 'SELECT cl_to INTO @isolated_ring_param_name FROM ', dbname, '.page, ', dbname, '.categorylinks WHERE cl_sortkey_prefix="_2" and page_id=cl_from and page_namespace=4 and page_title="', @i18n_page, '/IsolatedArticles" ORDER BY cl_to ASC LIMIT 1;' );
        PREPARE stmt FROM @st;
        EXECUTE stmt;
        DEALLOCATE PREPARE stmt;

        IF @isolated_ring_param_name IS NULL
          THEN
            SET @isolated_ring_param_name='';
        END IF;

        IF @isolated_ring_param_name!=''
          THEN
            SET @isolated_ring_param_name=SUBSTRING( @isolated_ring_param_name FROM stln );
        END IF;

        #
        # Sub-category prefix for isolated clusters of size above 2.
        #
        SET @st=CONCAT( 'SELECT cl_to INTO @isolated_cluster_param_name FROM ', dbname, '.page, ', dbname, '.categorylinks WHERE cl_sortkey_prefix="_N" and page_id=cl_from and page_namespace=4 and page_title="', @i18n_page, '/IsolatedArticles" ORDER BY cl_to ASC LIMIT 1;' );
        PREPARE stmt FROM @st;
        EXECUTE stmt;
        DEALLOCATE PREPARE stmt;

        IF @isolated_cluster_param_name IS NULL
          THEN
            SET @isolated_cluster_param_name='';
        END IF;

        IF @isolated_cluster_param_name!=''
          THEN
            SET @isolated_cluster_param_name=SUBSTRING( @isolated_cluster_param_name FROM stln );
        END IF;

        #
        # Old-style category name for orphaned articles.
        #
        SET @st=CONCAT( 'SELECT cl_to INTO @old_orphan_category FROM ', dbname, '.page, ', dbname, '.categorylinks WHERE cl_sortkey_prefix="old" and page_id=cl_from and page_namespace=4 and page_title="', @i18n_page, '/IsolatedArticles" ORDER BY cl_to ASC LIMIT 1;' );
        PREPARE stmt FROM @st;
        EXECUTE stmt;
        DEALLOCATE PREPARE stmt;

        IF @old_orphan_category IS NULL
          THEN
            SET @old_orphan_category='';
        END IF;

        IF @old_orphan_category!=''
          THEN
            SET @old_orphan_category=SUBSTRING( @old_orphan_category FROM stln );
        END IF;
    END IF;
  END;
//

#
# This function reads content of the language configuration page and
# intializes the following global variables:
#
# @deadend_category_name      - category containing all deadend articles
#
DROP PROCEDURE IF EXISTS get_deadend_category_name//
CREATE PROCEDURE get_deadend_category_name (targetlang VARCHAR(32))
  BEGIN
    DECLARE st VARCHAR(511);

    SET @deadend_category_name='';

    #
    # Meta-category name for deadend articles.
    #
    SET @st=CONCAT( 'SELECT DISTINCT pl_title INTO @deadend_category_name FROM ', dbname_for_lang( targetlang ), '.page, ', dbname_for_lang( targetlang ), '.pagelinks WHERE pl_namespace=14 and page_id=pl_from and page_namespace=4 and page_title="', @i18n_page, '/DeadEndArticles" ORDER BY pl_title ASC LIMIT 1;' );
    PREPARE stmt FROM @st;
    EXECUTE stmt;
    DEALLOCATE PREPARE stmt;

    IF @deadend_category_name IS NULL
      THEN
        SET @deadend_category_name='';
    END IF;
  END;
//

#
# This function reads content of the language configuration page and
# intializes the following global variables:
#
# @non_categorized_articles_category - category containing all articles with no
#                                      regular categories
#
DROP PROCEDURE IF EXISTS get_nca_category_name//
CREATE PROCEDURE get_nca_category_name (targetlang VARCHAR(32))
  BEGIN
    DECLARE st VARCHAR(511);

    SET @non_categorized_articles_category='';

    #
    # Meta-category name for deadend articles.
    #
    SET @st=CONCAT( 'SELECT pl_title INTO @non_categorized_articles_category FROM ', dbname_for_lang(targetlang), '.page, ', dbname_for_lang(targetlang), '.pagelinks WHERE pl_namespace=14 and page_id=pl_from and page_namespace=4 and page_title="', @i18n_page, '/NonCategorizedArticles" LIMIT 1;' );
    PREPARE stmt FROM @st;
    EXECUTE stmt;
    DEALLOCATE PREPARE stmt;

    IF @non_categorized_articles_category IS NULL
      THEN
        SET @non_categorized_articles_category='';
    END IF;
  END;
//

#
# This function reads content of the language configuration page and
# intializes the following global variables:
#
# @template_documentation_subpage_name
#
DROP PROCEDURE IF EXISTS get_template_documentation_subpage_name//
CREATE PROCEDURE get_template_documentation_subpage_name (targetlang VARCHAR(32))
  BEGIN
    DECLARE st VARCHAR(511);
    DECLARE stln INT;
    DECLARE dbname VARCHAR(32);

    SELECT dbname_for_lang( targetlang ) INTO dbname;

    SET @template_documentation_subpage_name='';

    #
    # Meta-category name for isolated articles.
    #
    SET @st=CONCAT( 'SELECT pl_title INTO @template_documentation_subpage_name FROM ', dbname, '.page, ', dbname, '.pagelinks WHERE pl_title LIKE CONCAT( @i18n_page, "/TemplateDoc/%" ) and pl_namespace=4 and page_id=pl_from and page_namespace=4 and page_title="', @i18n_page, '/TemplateDoc" ORDER BY pl_title ASC LIMIT 1;' );
    PREPARE stmt FROM @st;
    EXECUTE stmt;
    DEALLOCATE PREPARE stmt;

    IF @template_documentation_subpage_name IS NULL
      THEN
        SET @template_documentation_subpage_name='';
    END IF;

    IF @template_documentation_subpage_name!=''
      THEN
        SET stln=2+LENGTH( CONCAT( @i18n_page, '/TemplateDoc' ) );

        SET @template_documentation_subpage_name=SUBSTRING( @template_documentation_subpage_name FROM stln );
    END IF;
  END;
//

#
# Extracts the amount of disambiguation templates from 
# [[MediaWiki:Disambiguationspage]] assuming each is represented there
# as a link to a corresponding template namespace page.
#
DROP PROCEDURE IF EXISTS count_disambiguation_templates//
CREATE PROCEDURE count_disambiguation_templates (targetlang VARCHAR(32))
  BEGIN
    DECLARE st VARCHAR(511);
    DECLARE dbname VARCHAR(32);

    SELECT dbname_for_lang( targetlang ) INTO dbname;

    SET @disambiguation_templates_initialized=0;

    SET @st=CONCAT( 'SELECT count(DISTINCT pl_title) INTO @disambiguation_templates_initialized FROM ', dbname, '.page, ', dbname, '.pagelinks WHERE page_namespace=8 AND page_title="Disambiguationspage" AND pl_from=page_id AND pl_namespace=10' );
    PREPARE stmt FROM @st;
    EXECUTE stmt;
    DEALLOCATE PREPARE stmt;

    IF @disambiguation_templates_initialized IS NULL
      THEN
        SET @disambiguation_templates_initialized=0;
    END IF;
  END;
//

#
# All project settings, which may be configured on wiki pages are being
# collected here.
#
DROP PROCEDURE IF EXISTS obtain_project_settings//
CREATE PROCEDURE obtain_project_settings(targetlang VARCHAR(32))
  BEGIN
    #
    # Connectivity project root page is used for statistics upload and
    # could be also accomodated for other purposes.
    #
    CALL get_connectivity_project_root( targetlang );

    #
    # Isolated analysis is being run for different target sets,
    # so we have to initialize it once before any processing
    #
    # Localized isolated category name and subcategories naming rules
    # are initialized here as defined at @i18n_page/IsolatedArticles
    #
    CALL get_isolated_category_names( targetlang );
  
    #
    # Category name for deadend articles.
    #
    # Derived from @i18n_page/DeadEndArticles.
    #
    CALL get_deadend_category_name( targetlang );

    #
    # Categoryname for non-categorized articles.
    #
    # Derived from @i18n_page/NonCategorizedArticles
    # 
    CALL get_nca_category_name( targetlang );

    #
    # Standard subpage name for template documentation.
    #
    CALL get_template_documentation_subpage_name( targetlang );

    #
    # Amount of links from [[MediaWiki:Disambiguationspage]] to template ns.
    #
    CALL count_disambiguation_templates( targetlang );
  END;
//

DROP PROCEDURE IF EXISTS out_project_settings//
CREATE PROCEDURE out_project_settings()
  BEGIN
    SELECT CONCAT( ':: echo connectivity_project_root: "', @connectivity_project_root, '"' );
    SELECT CONCAT( ':: echo isolated_category_name: "', @isolated_category_name, '"' );
    SELECT CONCAT( ':: echo orphan_param_name: "', @orphan_param_name, '"' );
    SELECT CONCAT( ':: echo isolated_ring_param_name: "', @isolated_ring_param_name, '"' );
    SELECT CONCAT( ':: echo isolated_cluster_param_name: "', @isolated_cluster_param_name, '"' );
    SELECT CONCAT( ':: echo old_orphan_category: "', @old_orphan_category, '"' );
    SELECT CONCAT( ':: echo deadend_category_name: "', @deadend_category_name, '"' );
    SELECT CONCAT( ':: echo non_categorized_articles_category: "', @non_categorized_articles_category, '"' );
    SELECT CONCAT( ':: echo template_documentation_subpage_name: "', @template_documentation_subpage_name, '"' );
    SELECT CONCAT( ':: echo disambiguation_templates_initialized: "', @disambiguation_templates_initialized, '"' );
  END;
//

delimiter ;
############################################################

-- </pre>
