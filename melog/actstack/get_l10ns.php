<?php

// loading DbSimple
require_once( __DIR__ . '/DbSimple/Generic.php' );

function databaseErrorHandler($message, $info) {
	if (!error_reporting()) return;
	echo "SQL Error: {$message}\n\n"; 
	print_r($info);
	exit();
}

// getting the list of wikis to update l10n
/*$wikis = file_get_contents( __DIR__ . '/../wikis.txt' );
$wikis = explode( "\n", trim( $wikis ) );

foreach($wikis as $lang) {*/
//$lang = $_SERVER['argv'][1];
function createI18nCache($srv, $lang) {
	// loading auth. data
	$dbconf = parse_ini_file("/home/".get_current_user()."/.my.cnf");
	
	$wiki = DbSimple_Generic::connect( 'mysql://' . $dbconf['user'] . ':' . $dbconf['password'] . '@sql-s'.$srv.'/'.strtr( $lang, '-', '_' ).'wiki_p' );
	$wiki->setErrorHandler('databaseErrorHandler');
	
	// get isolated: orphan, ring, cluster
	$isolated = getIsolated( $wiki );
	file_put_contents( __DIR__ . '/../i18n/isolated.'.$lang.'.txt', serialize($isolated) );
	
	// get dead-end
	$deadend = getDeadend( $wiki );
	file_put_contents( __DIR__ . '/../i18n/deadend.'.$lang.'.txt', $deadend );
	
	// get non-categorized
	$noncat = getNoncat( $wiki );
	file_put_contents( __DIR__ . '/../i18n/noncat.'.$lang.'.txt', serialize($noncat) );
	
	// get namespaces from direct api
	$api = curl_init('http://'.$lang.'.wikipedia.org/w/api.php?action=query&meta=siteinfo&siprop=namespaces|namespacealiases|magicwords&format=php');
	curl_setopt($api, CURLOPT_RETURNTRANSFER, 1);
	curl_setopt($api, CURLOPT_USERAGENT, 'Melog i18n crawler/1.0');
	$mwinfo = curl_exec($api); curl_close($api);
	$mwinfo = unserialize($mwinfo);
	file_put_contents( __DIR__ . '/../i18n/namespaces.'.$lang.'.txt', serialize($mwinfo['query']['namespaces']) );
	file_put_contents( __DIR__ . '/../i18n/namespacealiases.'.$lang.'.txt', serialize($mwinfo['query']['namespacealiases']) );
	file_put_contents( __DIR__ . '/../i18n/magicwords.'.$lang.'.txt', serialize($mwinfo['query']['magicwords']) );
	
	// get disambig templates
	$disambigs = getDisambigTemplates( $wiki );
	file_put_contents( __DIR__ . '/../i18n/disambigs.'.$lang.'.txt', serialize($disambigs) );
	
	// get project root
	$root = getProjectRoot( $wiki );
	file_put_contents( __DIR__ . '/../i18n/root.'.$lang.'.txt', $root );

	// get valid iwiki prefixes
	$iwiki=getIwikiPrefixes( $wiki );
	file_put_contents( __DIR__ . '/../i18n/iwiki.'.$lang.'.txt', serialize($iwiki) );
}

function getIsolated(&$db) {
	$query1 = 'SELECT cl_to FROM categorylinks, page WHERE page_id=cl_from AND page_namespace=4 AND page_title="ConnectivityProjectInternationalization/IsolatedArticles" AND ( cl_sortkey_prefix="_1" OR cl_sortkey_prefix="_2" OR cl_sortkey_prefix="_N" ) ORDER BY cl_sortkey_prefix ASC';
	$query2 = 'SELECT pl_title FROM pagelinks, page WHERE pl_from=page_id AND page_namespace=4 AND page_title="ConnectivityProjectInternationalization/IsolatedArticles" AND pl_namespace IN (10, 14) ORDER BY pl_namespace ASC';
		
	$data = $db->selectCol($query1);
	$isolated = $db->selectCol($query2);
	$data = array(
		'orphan'	=> substr($data[0], strrpos($data[0], '/')+1),
		'ring'		=> substr($data[1], strrpos($data[1], '/')+1),
		'cluster'	=> substr($data[2], strrpos($data[2], '/')+1),
		'template'	=> strtr($isolated[0], '_', ' '),
		'category'	=> strtr($isolated[1], '_', ' ')
	);
	
	return $data;
}

function getDeadend(&$db) {
	$query = 'SELECT pl_title FROM pagelinks, page WHERE pl_from=page_id AND page_namespace=4 AND page_title="ConnectivityProjectInternationalization/DeadEndArticles" AND pl_namespace=10 ORDER BY pl_namespace ASC';
	
	return strtr($db->selectCell($query), '_', ' ');
}

function getNoncat(&$db) {
	$query = 'SELECT pl_title FROM pagelinks, page WHERE pl_from=page_id AND page_namespace=4 AND page_title="ConnectivityProjectInternationalization/NonCategorizedArticles" AND pl_namespace IN (10, 14) ORDER BY pl_namespace ASC';
	
	$data = $db->selectCol($query);
	foreach($data as &$item) {
		$item = strtr($item, '_', ' ');
	}
	
	return array('template' => $data[0], 'category' => $data[1]);
}

function getDisambigTemplates(&$db) {
	$query = 'SELECT pl_title FROM pagelinks, page WHERE pl_from=page_id AND page_title="Disambiguationspage" AND page_namespace=8 AND pl_namespace=10';
	
	$data = $db->selectCol($query);
	foreach($data as &$item) {
		$item = strtr($item, '_', ' ');
	}
	return $data;
}

function getProjectRoot(&$db) {
	$query = 'SELECT pl_title FROM pagelinks, page WHERE pl_from=page_id AND page_title="Connectivity_project_root" AND page_namespace=10';
	
	return strtr($db->selectCell($query), '_', ' ');
}

function getIwikiPrefixes(&$db) {
	$query = 'select distinct(ll_lang) from langlinks';
	
	$data=$db->selectCol($query);
	foreach($data as &$item) {
		$item = strtr($item, '_', ' ');
	}
	return $data;
}
