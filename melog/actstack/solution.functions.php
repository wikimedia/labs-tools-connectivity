<?php

/**
 * Checks if global article skip options apply
 * @param string $text	page text
 * @return boolean
 */
function globalSkip( &$text ) {
	global $l10n;
	
	return preg_match('/\(#(REDIRECT|'.$l10n['mwr']['redirect'].')/ui', $text);
}

/**
 * Checks if isolated article skip options apply
 * @param string $text	page text
 * @return boolean
 */
function isolatedSkip ( &$text ) {
	global $l10n;
	
	return preg_match('/(\{\{disambig'.getPregDisambigs($l10n['disamb']).')/ui', $text);
}

/**
 * Checks if non-categorized article skip options apply
 * @param string $text	page text
 * @return boolean
 */
function noncatSkip ( &$text ) {
	global $l10n;
	
	return preg_match('/(\{\{'.$l10n['nca']['template'].'|\[\['.$l10n['nsp'][14]['*'].':'.$l10n['nca'].')/ui', $text);
}

/**
 * Checks if dead-end article skip options apply
 * @param string $text	page text
 * @return boolean
 */
function deadendSkip ( &$text ) {
	global $l10n;
	
	return preg_match('/(\{\{'.$l10n['dea'].'|'.getPregDisambigs($l10n['disamb']).')/ui', $text);
}

/**
 * Searchs for 'redirect' magic word
 * @param array $swarm	array of magic words returned by API
 * @return mixed	returns magic word ID in the array  
 */
function findRedirect_i18n( &$swarm  ) {
	foreach($swarm as $magic => $content) {
		if($content['name'] == 'redirect') {
			return $magic;
		}
	}
	return false;
}


/**
 * Generates piece of preg expression for disambig templates detection
 * @param array $templates	list of template names from MediaWiki:Disambiguationspage
 * @return string	part of preg expression (for parenthesis)
 */
function getPregDisambigs( $templates ) {
	$result = '';
	
	foreach($templates as $template) {
		$result .= '\{\{'.$template.'|';
	}
	return rtrim($result, '|');
}

/**
 * Generates piece of preg expression with all namespaces and aliases included
 * @param mixed		list of namespace IDs to skip or a single ID
 * @return string	part of preg expression (divided with '|')
 */
function getPregNamespaces( $skip = array() ) {
	global $l10n;
	if(is_int($skip))
		$skip = array( $skip );
	$result = '';
	
	foreach($l10n['nsp'] as $id => $data) {
		if(in_array($id, $skip))
			continue;
		$result .= $data['*'].'|'.$data['canonical'].'|';
	}
	foreach($l10n['nspaliases'] as $data) {
		if(in_array($data['id'], $skip))
		$result .= $data['*'].'|';
	}
	
	return rtrim($result, '|');
}

/**
 * Creates a new category for cluster if one doesn't exist
 * @param string $cluster	cluster to set the category name
 * @return void
 */
function checkClusterCategory( $cluster ) {
	global $l10n, $wiki;
	if(empty($cluster))
		$cluster = $l10n['iso']['orphan'].'0';
	
	$title = $l10n['nsp'][14]['*'].':'.$l10n['iso']['category'].'/'.$cluster;
	$text = "__HIDDENCAT__\n\n'''''[[{$l10n['nsp'][4]['*']}:{$l10n['root']}]]'''''\n\n[[{$l10n['nsp'][14]['*']}:{$l10n['iso']['category']}|{{SUBPAGENAME:{{SUBPAGENAME}}}}]]";
	
	$category = new Page( $wiki, $title, null, false );
	
	$category->edit( $text, "Category for cluster {$cluster} created.", false, false, false, null, 'only' );
}

/**
 * {{rq}} editor for Russian Wikipedia
 * @param mixed $arguments	arguments in {{rq}} to delete; may be string or array of strings
 * @param string &$text		contents of the page
 */
function deleteRqArguments( $arguments, &$text ) {
	if($is_array($arguments))
		foreach($arguments as $argument)
			deleteRqArguments($argument, $text);
	
	if(!is_string($arguments))
		return;
	
	// find rq template
	$start = stripos($text, '{{rq');
	if($start === false)
		return;
	
	$end = strpos($text, '}}');
	strtr(substr($text, $start, $end-$start+1), $arguments, '');
}

/**
 * Call language-specifig function from /options
 * @param callback $function	function to call
 * @param unknown_type $lang	language postfix
 * @param unknown_type $arguments	arguments for function to pass
 * @return mixed|boolean	function result or false if callback function doesn't exist
 */
function callLangSpec( $function, $arguments=array() ) {
	if(function_exists($function)) {
		return call_user_func_array($function, $arguments);	
	} else 
		return false;
}
