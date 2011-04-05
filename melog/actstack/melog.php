<?php

// language
//$mlLang = $_SERVER['argv'][1];

// check if $lang is worth processing
/*if(!in_array($mlLang, explode("\n", trim(file_get_contents(__DIR__ . '/../wikis.txt')))))
	die($mlLang . ".wikipedia.org is not ready for processing.\n");*/

require_once( __DIR__ .'/get_l10ns.php' );
require_once( __DIR__ . '/melog.class.php' );
require_once( __DIR__ . '/../mwpeachy/Init.php' );

/**
 * Forms a string of variants for preg expression
 * @param array $array
 * @return string
 */
function formPregVariants($array) {
	return str_replace(' ', '\s', implode('|', $array));
}

function prepareShutdown() {
	global $pgLog, $mlLang;
	
	pecho('==============', PECHO_LOG);
	pecho('Writing down log and exiting.', PECHO_LOG);
	
	file_put_contents( __DIR__ . '/../logs/'.$mlLang.'.'.gmdate('YmdHis').'.txt', $pgLog); // write down the log
}

register_shutdown_function('prepareShutdown');

function parseStdInput() {
	pecho('Parsing stdin, retrieving language code and list of articles to process.', PECHO_LOG);
	$task = file_get_contents('php://stdin');
	if(empty($task)) {
		pecho('Task is empty, exiting now.', array(PECHO_LOG, PECHO_FATAL));
		return false;
	}
	
	if(substr($task, 0,3) == pack('CCC',0xef,0xbb,0xbf)) { // cutting BOM identifier
		$task=substr($task, 3);
	} 
	$task = explode("\n", trim($task));
	$mlLang = trim(array_shift($task));
	return array($mlLang, $task);
}

$request = parseStdInput();

// getting credentials from .cnf
$mwcredentials = parse_ini_file('/home/'.get_current_user().'/.'.$request[0].'.cnf');

pecho('Creating Melog instance and starting processing.', PECHO_LOG);
// creating Melog object
$melog = new Melog($request[0], $mwcredentials['login'], $mwcredentials['password']);
$melog->processTask($request[1]);

