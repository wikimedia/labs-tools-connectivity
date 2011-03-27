<?php

// language
$mlLang = $_SERVER['argv'][1];

// check if $lang is worth processing
if(!in_array($mlLang, explode("\n", trim(file_get_contents(__DIR__ . '/../wikis.txt')))))
	die($mlLang . ".wikipedia.org is not ready for processing.\n");


// getting credentials from .cnf
$mwcredentials = parse_ini_file('/home/'.get_current_user().'/.'.$mlLang.'.cnf');

// require_once( __DIR__ . '/melog.db.php');
require_once( __DIR__ . '/melog.class.php');
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

pecho('Creating Melog instance and starting processing.', PECHO_LOG);
// creating Melog object
$melog = new Melog($mlLang, $mwcredentials['login'], $mwcredentials['password']);
$melog->processTask();

