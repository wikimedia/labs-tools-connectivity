<?php

$lang = $_SERVER['argv'][1];

require_once( __DIR__ . '/solution.functions.php' );
require_once( __DIR__ . '/../mwpeachy/Init.php' );
if(file_exists(__DIR__ . '/../options/options.'.$lang.'.php'))
	include( __DIR__ . '/../options/options.'.$lang.'.php' );

$l10n = array(
	'iso'	=> unserialize(file_get_contents( __DIR__ . '/../i18n/isolated.'.$lang.'.txt' )),
	'dea'	=> trim(file_get_contents( __DIR__ . '/../i18n/deadend.'.$lang.'.txt' )),
	'nca'	=> unserialize(file_get_contents( __DIR__ . '/../i18n/noncat.'.$lang.'.txt' )),
	'nsp'	=> unserialize(file_get_contents( __DIR__ . '/../i18n/namespaces.'.$lang.'.txt' )),
	'mwr'	=> unserialize(file_get_contents( __DIR__ . '/../i18n/magicwords.'.$lang.'.txt' )),
	'root'	=> trim(file_get_contents( __DIR__ . '/../i18n/root.'.$lang.'.txt' )),
	'disamb'=> unserialize(file_get_contents( __DIR__ . '/../i18n/disambigs.'.$lang.'.txt')),
	'nspaliases'=>	unserialize(file_get_contents( __DIR__ . '/../i18n/namespacealiases.'.$lang.'.txt'))
);
$l10n['mwr']['redirect'] = $l10n['mwr'][findRedirect_i18n($l10n['mwr'])]['aliases'][0];	// localized #REDIRECT magic word


$wiki = Peachy::newWiki( null, 'login', 'password', 'http://'.$lang.'.wikipedia.org/w/api.php' );

$tasks = file_get_contents( __DIR__ . '/../task.'.$lang.'.txt' );
$tasks = explode( "\n", trim($tasks) );

foreach($tasks as $task) {
	list($title, $ncaact, $deact, $isoact, $cluster) = explode(" ", $task);
	
	$page = new Page( $wiki, $title, null, false, true );
	$text = $page->get_text();
	$summary = 'Connectivity works: ';
	
	// global skip conditions
	if(globalSkip($text)) {
		unset($page);
		continue;
	}
	
	if(!empty($cluster)) {
		$hrchain = (($cluster=='_1')?'':'|'.system(__DIR__ . '/chain_parser '.$cluster));	// human-readable chain
		$hrchain = str_replace(array('orphan', 'ring', 'cluster'), array_slice($l10n['iso'], 0, 3), $hrchain); // chain l10n
		
		// creating cluster category if one doesn't exist
		checkClusterCategory( substr($hrchain, 1) );
	}
	
	if($isoact == -1) { // untagging isolated
		callLangSpec('isodeact', array(&$text));
		
		$text = preg_replace('/\{\{'.$l10n['iso']['template'].'(\|(\S+\d{1,3})*)?\}\}/ui', '', $text); // deleting old template
		$summary .= 'untagged isolated; ';
	} elseif($isoact == 1) { // tagging isolated
		if(isolatedSkip($text)) {
			unset($page);
			continue;
		}
		callLangSpec('isoact', array(&$text, substr($hrchain, 1)));
		
		$text = preg_replace('/\{\{'.$l10n['iso']['template'].'(\|(\S+\d{1,3})*)?\}\}/ui', '', $text); // deleting old template
		if(preg_match('/(\[\['.$l10n['nsp'][14]['*'].':|\[\[[a-z\-]{2,8}:)/ui', $text)) {
			$text = preg_replace('/(\[\['.$l10n['nsp'][14]['*'].'|\[\[(?!'.getPregNamespaces(14).')[a-z\-]{2,9}:)/ui', '{{'.$l10n['iso']['template'].$hrchain."}}\n\n\\1", $text, 1);
		} else {
			$text .= "\n{{".$l10n['iso']['template'].$hrchain."}}\n\n";
		}
		$hrchain = ltrim($hrchain, '|');
		if(empty($hrchain))
			$hrchain = $l10n['iso']['orphan'].'0';
		$summary .= 'tagged isolated of cluster '.$hrchain.'; ';
	}
	if($ncaact == -1) { // untagging non-categorized
		callLangSpec('ncadeact', array(&$text));
		
		$text = preg_replace('/\[\['.$l10n['nsp'][14]['*'].':'.$l10n['nca'].'\]\]\n/i', "\n", $text); // deprecated, for earlier versions untagging
		$text = preg_replace('/\{\{'.$l10n['nca']['template'].'\}\}(\n{1,2})/i', '', $text);
		$summary .= 'untagged non-categorized; ';
	} elseif($ncaact == 1) { // tagging non-categorized
		if(noncatSkip($text)) {
			unset($page);
			continue;
		}
		callLangSpec('ncaact', array(&$text));
		
		$text = preg_replace('/(\[\['.$l10n['nsp'][14]['*'].'|\[\[[a-z]{2,9}:|$)/ui', '{{'.$l10n['nca']['template']."}}\n\\1", $text, 1);
		$summary .= 'tagged non-categorized; ';
	}
	if($deact == -1) { // untagging dead-end
		callLangSpec('dedeact', array(&$text));
		
		$text = preg_replace('/\{\{'.$l10n['dea'].'\}\}(\n{1,2})/i', '', $text);
		$summary .= 'untagged dead-end; ';
	} elseif($deact == 1) { // tagging dead-end
		if(deadendSkip($text)) {
			unset($page);
			continue;
		}
		callLangSpec('deact', array(&$text));
		
		$text = preg_replace('/(\[\['.$l10n['nsp'][14]['*'].'|\[\[[a-z]{2,9}:|$)/ui', '{{'.$l10n['dea']."}}\n\n\\1", $text, 1);
		$summary .= 'tagged dead-end; ';
	}
	
	// saving the changes and unsetting the instance of Page
	$page->edit(trim($text), substr($summary, 0, -2).'.', true, true, null, 'never');
	unset($page);
	
}

