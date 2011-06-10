<?php

class Melog {
	
	/**
	 * Wikipedia language to work with
	 * @var string
	 */
	private $_lang;
	
	/**
	 * Language-specifig options object
	 * @var Options
	 */
	private $_options;
	
	/**
	 * Localization-specific data
	 * @var array
	 */
	private $_l10n;
	
	/**
	 * MwPeachy object for interacting with MW API
	 * @var Wiki
	 */
	private $_wiki;
	
	/**
	 * Article contents
	 * @var string
	 */
	private $_text;
	
	/**
	 * Edit summary
	 * @var string
	 */
	private $_summary;
	
	/**
	 * Melog class constructor
	 * @param string $lang		language to work with
	 * @param string $login		login for API
	 * @param string $password	password for API
	 */
	public function __construct( $lang, $login, $password ) {
		$this->_lang = $lang;
		$this->_l10n = $this->_loadL10n();
		
		// importing language-specifig class
		if(file_exists(__DIR__ . '/../options/options.'.$this->_lang.'.php')) {
			include( __DIR__ . '/../options/options.'.$this->_lang.'.php' );
			$optclassname = 'Options_'.strtr($this->_lang, '-', '_');
			$this->_options = new $optclassname($this->_l10n);
		} else {
			include( __DIR__ . '/../options/options.blank.php');
			$this->_options = new Options_blank($this->_l10n); // dummy options
		}
		
		$this->_wiki = Peachy::newWiki( null, $login, $password, 'http://'.$this->_lang.'.wikipedia.org/w/api.php' );
	}
	
	/**
	 * Initiates task file processing
	 */
	public function processTask($task) { // method wrap left for compatibility reasons
		$this->_processTask($task);
	}
	
	/*public function processTask() {
		$task = file_get_contents( __DIR__ . '/../task.'.$this->_lang.'.txt' );
		if(!$task) {
			pecho('Task file not found or empty.', array(PECHO_LOG, PECHO_FATAL));
			return false;
		}
		
		// deleting BOM if found
		if(substr($task, 0,3) == pack('CCC',0xef,0xbb,0xbf)) { 
	        $task=substr($task, 3); 
	    } 
		
		$task = explode( "\n", trim($task) );
		
		$this->_processTask($task);
		return true;
	}*/
	
	/**
	 * Returns the language bot is working with
	 * @return string
	 */
	public function getLanguage() {
		return $this->_lang;
	}
	
	/**
	 * Docodes cluster chain of _n_m_o_p_r kind to a human-readable one
	 * @param string $chain		chain to decode
	 * @return string
	 */
	private function _decodeChain($chain)
	{
		$chain = explode('_', trim($chain));
		$result = '';
		
		array_shift($chain); // deleting empty item
		
		$orphan = 0;
		for($i=0;$i<sizeof($chain);$i++) {
			if($chain[$i]>1) {
				if($orphan>0) {
		        	$result .= "orphan".($orphan-1);
					$orphan = 0;
				}
				switch($chain[$i]){
					case 2: $result.="ring2"; break;
					default: $result.="cluster{$chain[$i]}"; break;
				}
			} else
				$orphan++;
		}
		if($orphan>0)
			$result .= "orphan".($orphan-1);

		return $result;
	}
	
	/**
	 * Loads localization-specific data
	 * @return array	localizations
	 */
	private function _loadL10n() {
		require_once(__DIR__ . '/melog.i18n.php');
		
		return new i18n($this->getLanguage());
	}
	
	/**
	 * Processes task records one at a time
	 * @param array $tasks	list of records
	 */
	private function _processTask($tasks=array()) {
		foreach($tasks as $task) {
			list($title, $ncaact, $deact, $isoact, $cluster) = explode(" ", $task);
			$this->_processArticle(trim($title), trim($ncaact), trim($deact), trim($isoact), trim($cluster));
		}
	}

	/**
	 * Processes page according to given statuses
	 * @param string $title		article title
	 * @param int $noncat	non-categorized status
	 * @param int $deadend	dead-end status
	 * @param intger $iso		isolated status
	 * @param string $cluster	isolated cluster chain
	 */
	private function _processArticle($title, $noncat, $deadend, $iso, $cluster='') {
		$page = new Page($this->_wiki, $title, null, false, true);
		$this->_text = $page->get_text();
		$this->_summary = '';
		pecho("== {$title} ==", PECHO_LOG);
		
		if($this->_skipGlobal()) { // global skip rules
			unset($page);
			pecho("Global skip options went off, skipping article.", PECHO_LOG);
			return;
		}
		
		$this->_fixIsolated($iso, $cluster);
		$this->_fixNoncategorized($noncat);
		$this->_fixDeadend($deadend);
		
		// preventing from wiping pages
		if(trim($this->_text) == '') {
			pecho('All contents are deleted, leaving the article unprocessed.', array(PECHO_WARN, PECHO_LOG));
			unset($page);
			return;
		}
		
		$this->_finishSummary();
		
		$this->_text = preg_replace('~\n{3,}~', '\n\n', $this->_text); // deleting excessive line breaks
		$rev = $page->edit(trim($this->_text), $this->_summary, true, true, null, 'never');
		if(is_int($rev)) {
			pecho("Article revision {$rev} commited. The article is processed now.", PECHO_LOG);
		} else {
			pecho("Article was not commited due to unrevealed problems.", PECHO_LOG);
		}
		unset($page);
	}
	
	/**
	 * Fixes page according to isolated status
	 * @param int $status	isolated status
	 * @param string $chain		cluster chain
	 */
	private function _fixIsolated($status, $cluster) {
		if(!$status)
			return;
		
		$this->_text = preg_replace('/\{\{'.$this->_l10n->getArray('isolated', 'template') .'(\|(\S+\d{1,3})*)?\}\}\n*/ui', '', $this->_text);
		if($status == -1) {
			$this->_appendSummary('untagged isolated');
			pecho("Isolated template deleted.", PECHO_LOG);
		} elseif($status == 1) {
			if($this->_skipIsolated()) {
				pecho("Isolated skip options went off, skipping isolated fix actions.", PECHO_LOG);
				return;	
			}
			
			if(!empty($cluster)) {
				$chain = (($cluster=='_1')?'':'|'.$this->_decodeChain($cluster));
				$chain = str_replace(array('orphan', 'ring', 'cluster'), $this->_l10n->getIsolatedMnemonics(), $chain);
				pecho("Cluster given. Resolving {$cluster} into ".(($chain=='')? $this->_l10n->getIsolatedMnemonics(1).'0' : ltrim($chain, '|') ).'.', PECHO_LOG);
			} else {
				$chain = '';
				pecho('No cluster given. Using orphan0 instead.', array(PECHO_LOG, PEACHO_WARN));
			}
			
			if(preg_match('/(\[\['.$this->_l10n->getNamespaceName(14).':|\[\[[a-z\-]{2,8}:)/ui', $this->_text)) {
				$this->_text = preg_replace('/\n*(\[\['.$this->_l10n->getNamespaceName(14).'|\[\[(?!'.$this->_l10n->getPregNamespaces(14).')[a-z\-]{2,9}:)/ui', "\n\n{{".$this->_l10n->getArray('isolated', 'template').$chain."}}\n\n\\1", $this->_text, 1);
			} else {
				$this->_text .= "\n{{".$this->_l10n->getArray('isolated', 'template').$chain."}}";
			}
			$this->_appendSummary('tagged isolated of cluster '. (($chain=='')? $this->_l10n->getIsolatedMnemonics(1).'0' : ltrim($chain, '|') ));
			pecho("Isolated template set with cluster chain ".(($chain=='')? $this->_l10n->getIsolatedMnemonics(1).'0' : ltrim($chain, '|') ).".", PECHO_LOG);
		}
		$this->_text = $this->_options->fixIsolated($this->_text, $status, $cluster);
	}
	
	/**
	 * Fixes page according to non-categorized status
	 * @param int $status	non-categorized status
	 */
	private function _fixNoncategorized($status) {
		if(!$status)
			return;

		if($status == -1) {
			$this->_text = preg_replace('/\[\['.$this->_l10n->getNamespaceName(14).':'.$this->_l10n->getArray('noncategorized', 'category').'\]\]\n/i', '', $this->_text);
			$this->_text = preg_replace('/\{\{'.$this->_l10n->getArray('noncategorized', 'template').'\}\}(\n{1,2})*/i', '', $this->_text);
			
			$this->_appendSummary('untagged non-categorized');
			pecho("Non-categorized template deleted.", PECHO_LOG);
		} elseif($status == 1) {
			if($this->_skipNoncategorized()) {
				pecho('Non-categorized skip options went off, skipping non-categorized fix actions.', PECHO_LOG);
				return;
			}
			$this->_text = preg_replace('/(\[\['.$this->_l10n->getNamespaceName(14).'|\[\[(?!'.$this->_l10n->getPregNamespaces(14).')[a-z\-]{2,9}:|$)/ui', '{{'.$this->_l10n->getArray('noncategorized', 'template')."}}\n\\1", $this->_text, 1);
			
			$this->_appendSummary('tagged non-categorized');
			pecho('Non-categorized template set.', PECHO_LOG);
		}
		$this->_text = $this->_options->fixNoncategorized($this->_text, $status);
		
	}
	
	/**
	 * Fixes page according to dead-end status
	 * @param int $status	dead-end status
	 */
	private function _fixDeadend($status) {
		if(!$status)
			return;

		if($status == -1) {
			$this->_text = preg_replace('/\{\{'.$this->_l10n->getStorage('deadend').'\}\}(\n{1,2})/i', '', $this->_text);
			
			$this->_appendSummary('untagged dead-end');
			pecho("Dead-end template deleted.", PECHO_LOG);
		} elseif($status == 1) {
			if($this->_skipDeadend()) {
				pecho('Dead-end skip options went off, skipping dead-end fix actions.', PECHO_LOG);
				return;
			}
			
			// As opposed to other templates, this one is prepended, so no meta section searching is needed.
			$this->_text = '{{'.$this->_l10n->getStorage('deadend')."}}\n" . $this->_text;
			
			$this->_appendSummary('tagged dead-end');
			pecho('Dead-end template set.', PECHO_LOG);
		}
		$this->_text = $this->_options->fixDeadend($this->_text, $status);
	}
	
	private function _skipGlobal() {
		return preg_match('/('.formPregVariants($this->_l10n->getArray('magicwords', 'redirect')).')/ui', $this->_text) || $this->_options->skipGlobal($this->_text);
	}
	
	private function _skipIsolated() {
		return preg_match('/\{\{('.formPregVariants($this->_l10n->getArray('disambigs')).')/ui', $this->_text) || $this->_options->skipIsolated($this->_text);
	}
	
	private function _skipNoncategorized() {
		return preg_match('/\{\{('.$this->_l10n->getArray('noncategorized', 'template').'|\[\['.$this->_l10n->getNamespaceName(14).':'.$this->_l10n->getArray('noncategorized', 'category').')/ui', $this->_text) || $this->_options->skipNoncategorized($this->_text);
	}
	
	private function _skipDeadend() {
		return preg_match('/\{\{('.$this->_l10n->getStorage('deadend').'|'.formPregVariants($this->_l10n->getArray('disambigs')).')/ui', $this->_text) || $this->_options->skipDeadend($this->_text);
	}
	
	/**
	 * Appends a string to summary
	 * @param string $append	string to append
	 */
	private function _appendSummary($append) {
		$this->_summary .= $append . '; ';
	}
	
	/**
	 * Finalizes summary for submission
	 */
	private function _finishSummary() {
		$this->_summary = substr($this->_summary, 0, -2).'.';
	}
	
}