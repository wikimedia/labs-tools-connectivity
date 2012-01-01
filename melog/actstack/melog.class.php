<?php

class Melog {
	
	/**
	 * Wikipedia sql server to work with
	 * @var string
	 */
	private $_srv;

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
	 * Article contents
	 * @var string
	 */
	private $_originaltext;

	/**
	 * Edit summary
	 * @var string
	 */
	private $_summary;
	
	/**
	 * Edit fail counter
	 * @var int
	 */
	private $_editFailCount;
	
	/**
	 * Edit fail counter
	 * @var int
	 */
	private $_maxeditFailCount;

	/**
	 * Edit fail counter
	 * @var int
	 */
	private $_iwikiList;

	/**
	 * Melog class constructor
	 * @param string $lang		language to work with
	 * @param string $login		login for API
	 * @param string $password	password for API
	 */
	public function __construct( $srv, $lang, $login, $password ) {
		$this->_srv = $srv;
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
		
                $this->_iwikiList=formPregVariants($this->_l10n->getArray('iwiki'));

		$this->_wiki = Peachy::newWiki( null, $login, $password, 'http://'.$this->_lang.'.wikipedia.org/w/api.php' );
		$this->_editFailCount = 0; // resetting fail counter
		$this->_maxeditFailCount = 3;
	}
	
	/**
	 * Initiates task file processing
	 */
	public function processTask($task) { // method wrap left for compatibility reasons
		$this->_processTask($task);
	}
	
	/**
	 * Returns the language bot is working with
	 * @return string
	 */
	public function getLanguage() {
		return $this->_lang;
	}
	
	/**
	 * Returns the mysql server bot is working with
	 * @return string
	 */
	public function getSrv() {
		return $this->_srv;
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
		
		return new i18n($this->getSrv(), $this->getLanguage());
	}
	
	/**
	 * Processes task records one at a time
	 * @param array $tasks	list of records
	 */
	private function _processTask($tasks=array()) {
		foreach($tasks as $task) {
			$this->_editFailCount = 0;

			list($title, $ncaact, $deact, $isoact, $cluster) = explode(" ", $task);
			
			while(($this->_editFailCount++) < $this->_maxeditFailCount) {
				if($this->_processArticle(trim($title), trim($ncaact), trim($deact), trim($isoact), trim($cluster)))
					break;
			}
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
		pecho("== {$title} ==", PECHO_LOG);
		
		// Avoiding non-existent pages creating
		if(!$page->get_id()) {
			pecho("Page does not exist. Skipping.", PECHO_LOG);
			return true;
		}
		pecho("Page ID: ".$page->get_id(), PECHO_LOG);
		
		$this->_text = $page->get_text();
		$this->_originaltext = $this->text;
		$this->_summary = '';
		
		if($this->_skipGlobal()) { // global skip rules
			unset($page);
			pecho("Global skip options went off, skipping article.", PECHO_LOG);
			return true;
		}
		
		// preventing from editing empty pages
		if(trim($this->_text) == '') {
			pecho('Empty article, leaving it unprocessed.', array(PECHO_WARN, PECHO_LOG));
			unset($page);
			return true; // it's not true indeed, but trying more makes no sense
		}

		$this->_fixIsolated($iso, $cluster);
		$this->_fixNoncategorized($noncat);
		$this->_fixDeadend($deadend);
		
		// preventing from wiping pages
		if(trim($this->_text) == '') {
			pecho('All contents are to be deleted, leaving the article unprocessed.', array(PECHO_WARN, PECHO_LOG));
			unset($page);
			return true; // it's not true indeed, but trying more makes no sense
		}
		
		// preventing from dummy edits
		if(trim($this->_text) == trim($this->_originaltext)) {
			pecho('No changes to content, leaving the article unprocessed.', array(PECHO_WARN, PECHO_LOG));
			unset($page);
			return true; // it's not true indeed, but trying more makes no sense
		}

		if($this->_summary != '') {
			$this->_finishSummary();
		
			$this->_text = preg_replace('~\n{3,}~', "\n\n", $this->_text); // deleting excessive line breaks
#pecho("start".$this->_summary."end", PECHO_LOG);
#pecho("start".$this->_text."end", PECHO_LOG);
			try {
				# parameters: text, summary, minor, bot, force, pend, create
				$rev = $page->edit(trim($this->_text), $this->_summary, false, true, false, false, 'never');
			}
			catch( EditError $e ) {
				if($e->getMessage() == 'Edit Error: Nobots (The page has a nobots template)') {
					pecho("No editing due to Nobots protection.", PECHO_LOG);
					return true;
				} else {
					pecho( "Error: $e\n\n", PECHO_FATAL );
				}
			}

			unset($page);
			if(is_int($rev)) {
				pecho("Article revision {$rev} commited. The article is processed now.", PECHO_LOG);
				return true;
			} else {
				pecho("Article was not commited due to unrevealed problems.", PECHO_LOG);
				return false;
			}
		} else {
			pecho("Near dummy edits only, no reason to commit.", PECHO_LOG);
			return true;
		}
	}
	
	/**
	 * Fixes page according to isolated status
	 * @param int $status	isolated status
	 * @param string $chain		cluster chain
	 */
	private function _fixIsolated($status, $cluster) {
		if(!$status)
			return;
		
		$param_found='';
		$param_given='';

		if($status == 1) {
			if(!empty($cluster)) {
				$chain = (($cluster=='_1')?'':'|'.$this->_decodeChain($cluster));
				$chain = str_replace(array('orphan', 'ring', 'cluster'), $this->_l10n->getIsolatedMnemonics(), $chain);
				pecho("Cluster given. Resolving {$cluster} into ".(($chain=='')? $this->_l10n->getIsolatedMnemonics(1).'0' : ltrim($chain, '|') ).'.', PECHO_LOG);
			} else {
				$chain = '';
				pecho('No cluster given. Using orphan0 instead.', array(PECHO_LOG, PEACHO_WARN));
			}
			$param_given=( ($chain=='')? $this->_l10n->getIsolatedMnemonics(1).'0' : ltrim($chain, '|') );
		}

		$this->_extractJustInCaseFromComments($this->_l10n->getArray('isolated', 'template').$chain, 'Existent');

		$template = new Template($this->_text, trim($this->_l10n->getArray('isolated', 'template')));
		if($template->name) {
			if($template->fields[1]) {
				$param_found=$template->fields[1];
			} else {
				$param_found=$this->_l10n->getIsolatedMnemonics(1).'0';
			}

			if($status == 1) {
				if( $param_found==$param_given ) {
					pecho("Isolated cluster chain replacement is not required.", PECHO_LOG);
				}
			}

			// Delete this template if exists, no exclusions
			$this->_text=$template->deleteTemplate();

			if($status == -1) {
				$this->_appendSummary('untagged isolated');
				pecho("Isolated template deleted.", PECHO_LOG);
			}
		} elseif($status == -1) {
			pecho("Isolated template not detected.", PECHO_LOG);
		}

		if($status == 1) {
			if($this->_skipIsolated()) {
				pecho("Isolated skip options went off, skipping isolated fix actions.", PECHO_LOG);
				return;	
			}
			
			# For chain change the old one should have been removed
			$this->_appendTextProperly($this->_l10n->getArray('isolated', 'template').$chain);

			if($param_found!='') {
				if($param_found!=$param_given) {
					$this->_appendSummary('isolated cluster '.$param_found.' replaced by '.$param_given );
					pecho("Isolated cluster chain ".$param_found." replaced with ".$param_given.".", PECHO_LOG);
				}
			} else {
				$this->_appendSummary('tagged isolated of cluster '.$param_given);
				pecho("Isolated template set with cluster chain ".$param_given.".", PECHO_LOG);
			}

			if( $param_found==$param_given ) {
				$this->_extractJustInCaseFromComments($this->_l10n->getArray('isolated', 'template').$chain, '');
			} else {
				$this->_extractJustInCaseFromComments($this->_l10n->getArray('isolated', 'template').$chain, 'Added');
			}
		}

		$opt=$this->_options->fixIsolated($this->_text, $status, $cluster);
		$this->_text=$opt['text'];
		if( $opt['summary'] != '' ) {
			$this->_summary.=$opt['summary'];
		}
	}
	
	/**
	 * Fixes page according to non-categorized status
	 * @param int $status	non-categorized status
	 */
	private function _fixNoncategorized($status) {
		if(!$status)
			return;

		$this->_extractJustInCaseFromComments($this->_l10n->getArray('noncategorized', 'template'), 'Existent');

		$template = new Template($this->_text, trim($this->_l10n->getArray('noncategorized', 'template')));
		if($template->name) {
			if($status == -1) {
				// delete this template
				$this->_text=$template->deleteTemplate();
				$this->_appendSummary('untagged non-categorized');
				pecho("Non-categorized template deleted.", PECHO_LOG);
			} elseif($status == 1) {
				pecho("Non-categorized template is already set.", PECHO_LOG);
                        }

		} elseif($status == -1) {
			pecho("Non-categorized template not detected.", PECHO_LOG);
		}

		if($status == -1) {
			if(preg_match('/\[\['.$this->_l10n->getNamespaceName(14).':'.$this->_l10n->getArray('noncategorized', 'category').'\]\]\n*/ui', $this->_text )) {
				$this->_text = preg_replace('/\[\['.$this->_l10n->getNamespaceName(14).':'.$this->_l10n->getArray('noncategorized', 'category').'\]\]\n*/ui', '', $this->_text, 1);
 
				$this->_appendSummary('non-categorized category removed');
				pecho("Non-categorized category removed.", PECHO_LOG);
			}
		} elseif($status == 1) {
			if($this->_skipNoncategorized()) {
				pecho('Non-categorized skip options went off, skipping non-categorized fix actions.', PECHO_LOG);
				return;
			}

			$this->_appendTextProperly($this->_l10n->getArray('noncategorized', 'template'));

			$this->_appendSummary('tagged non-categorized');
			pecho('Non-categorized template set.', PECHO_LOG);

			$this->_extractJustInCaseFromComments(trim($this->_l10n->getArray('noncategorized', 'template')), 'Added');
			
		}
		$opt=$this->_options->fixNoncategorized($this->_text, $status);
		$this->_text=$opt['text'];
		if( $opt['summary'] != '' ) {
			$this->_summary.=$opt['summary'];
		}
	}
	
	/**
	 * Fixes page according to dead-end status
	 * @param int $status	dead-end status
	 */
	private function _fixDeadend($status) {
		if(!$status)
			return;

		$foundsuchatemplate=0;

		$this->_extractJustInCaseFromComments($this->_l10n->getStorage('deadend'), 'Existent');

		$template = new Template($this->_text, trim($this->_l10n->getStorage('deadend')));
		if($template->name) {
			if($status == -1) {
				// delete this template
				$this->_text=$template->deleteTemplate();
				$this->_appendSummary('untagged dead-end');
				pecho("Dead-end template deleted.", PECHO_LOG);
			} elseif($status == 1) {
				pecho("Dead-end template is already set.", PECHO_LOG);
				$foundsuchatemplate=1;
			}

		} elseif($status == -1) {
			pecho("Dead-end template not detected.", PECHO_LOG);
		}

		if($status == 1) {
			if($this->_skipDeadend()) {
				pecho('Dead-end skip options went off, skipping dead-end fix actions.', PECHO_LOG);
				return;
			}

			if(!$foundsuchatemplate) {
				$this->_text='{{'.$this->_l10n->getStorage('deadend')."}}\n".$this->_text;
			
				$this->_appendSummary('tagged dead-end');
				pecho('Dead-end template set.', PECHO_LOG);
			}
		}
		$opt=$this->_options->fixDeadend($this->_text, $status);
		$this->_text=$opt['text'];
		if( $opt['summary'] != '' ) {
			$this->_summary.=$opt['summary'];
		}
	}
	
	private function _skipGlobal() {
		return preg_match('/(^|\}[\s\t]*)('.formPregVariants($this->_l10n->getArray('magicwords', 'redirect')).')/mui', $this->_text) || $this->_options->skipGlobal($this->_text);
	}
	
	private function _skipIsolated() {
		if(formPregVariants($this->_l10n->getArray('disambigs'))){
			return preg_match('/\{\{('.formPregVariants($this->_l10n->getArray('disambigs')).')/ui', $this->_text) || $this->_options->skipIsolated($this->_text);
		} else {
			return $this->_options->skipIsolated($this->_text);
		}
	}
	
	private function _skipNoncategorized() {
		return preg_match('/\{\{('.$this->_l10n->getArray('noncategorized', 'template').'|\[\['.$this->_l10n->getNamespaceName(14).':'.$this->_l10n->getArray('noncategorized', 'category').')/ui', $this->_text) || $this->_options->skipNoncategorized($this->_text);
	}
	
	private function _skipDeadend() {
		if(formPregVariants($this->_l10n->getArray('disambigs'))){
			return preg_match('/\{\{('.$this->_l10n->getStorage('deadend').'|'.formPregVariants($this->_l10n->getArray('disambigs')).')/ui', $this->_text) || $this->_options->skipDeadend($this->_text);
		} else {
			return preg_match('/\{\{('.$this->_l10n->getStorage('deadend').')/ui', $this->_text) || $this->_options->skipDeadend($this->_text);
		}
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

	/**
	 * Appends to the text but before interwiki and categories
	 */
	private function _appendTextProperly($insert) {

		$this->_text = preg_replace('/\n*(\[\['.$this->_l10n->getNamespaceName(14).'|\[\[('.$this->_iwikiList.'):|$)/ui', "\n\n{{".$insert."}}\n\n\\1", $this->_text, 1);
	}

	/**
	 * Extracts given template from comments if required
	 */
	private function _extractJustInCaseFromComments($insert, $kind) {

		if(preg_match( '/\<![ \r\n\t]*--([^\-\{]|[\r\n]|-[^\-]|\{(?!\{'.str_replace(' ', '\s', $insert).'))*\{\{'.str_replace(' ', '\s', $insert).'\}\}([^\-]|[\r\n]|-[^\-])*--[ \r\n\t]*\>/us', $this->_text )) {
			// moving up
			$this->_text = preg_replace('/(\<![ \r\n\t]*--)(([^\-\{\r\n]|[\r\n](?![\r\n]*\{\{'.str_replace(' ', '\s', $insert).')|-[^\-]|\{(?!\{'.str_replace(' ', '\s', $insert).'))*)[\n\r]*\{\{'.str_replace(' ', '\s', $insert).'\}\}[\n\r]*(([^\-]|[\r\n]|-[^\-])*)(--[ \r\n\t]*\>)/', "{{".$insert."}}\n\n\\1\\2\\4\\6", $this->_text, 1);

			if( $kind != '' ) {
				if( $kind != 'Added' ) {
					$this->_appendSummary($kind.' {{'.$insert.'}} uncommented');
				}
				pecho($kind." template {{".$insert."}} moved out of comment.", PECHO_LOG);
			}

			return true;
		} else {
			return false;
		}
	}
}
