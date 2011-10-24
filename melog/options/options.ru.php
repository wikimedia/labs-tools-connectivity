<?php

require( __DIR__ .'/options.php');

class Options_ru extends Options {

	private $_orphanname;
	
	public function __construct($i18n) {
		$this->_l10n = $i18n;
                $this->_orphanname=$this->_l10n->getIsolatedMnemonics(1);
	}

	public function skipGlobal($text) {
		/*$this->_text = $text;
		
		if(Template::testTemplates(strtolower($this->_text), array('к быстрому удалению','ку','к удалению','db','d','delete','del','уд','куд','кбу','deletebecause'))) { // TODO: get delete nominations through i18n
			pecho('Article is nominated for deletion.', PECHO_LOG);
			return true;
		}*/
		return false;
	}
	
	public function fixIsolated($text, $status, $cluster) {
		$this->_text = $text;
		$this->_summary = '';
		
		if($status == -1) {
			$this->_deleteRqArguments( 'linkless' );

			$this->_deleteOrphan();

		} elseif($status == 1) {
			if($cluster != '_1') {
				$this->_deleteRqArguments( 'linkless' );

				$this->_deleteOrphan();
			}
		}

		// process {{rq}}
		$this->_fixLonelyRq();
		return array('text' => $this->_text, 'summary' => $this->_summary);
	}
	
	public function fixNonCategorized($text, $status) {
		$this->_text = $text;
		$this->_summary = '';
		
		if($status == -1)
			$this->_deleteRqArguments('cat');
			
		// process {{rq}}
		$this->_fixLonelyRq();
		return array('text' => $this->_text, 'summary' => $this->_summary);
	}
	
	public function fixDeadend($text, $status) {
		$this->_text = $text;
		$this->_summary = '';
		
		// process {{rq}}
		$this->_fixLonelyRq();
		return array('text' => $this->_text, 'summary' => $this->_summary);
	}
	
	private function _deleteOrphan() {
		/* Removing {{<obsolete name>}} here
      	                   we use a-priori knowledge on
              	           <obsolete name> equal to
                      	   orphan category parameter name. */
		$template = new Template($this->_text, trim($this->_orphanname));
		if($template->name) {
			// delete this template
			$this->_text=$template->deleteTemplate();
			$this->_summary.='un-old-tagged isolated; ';
			pecho("Old isolated template deleted.", PECHO_LOG);
		}
	}

	private function _deleteRqArguments( $arguments ) {
		if(is_array($arguments))
			foreach($arguments as $argument)
				$this->_deleteRqArguments($argument);

		if(!is_string($arguments))
			return;
		
		$template = new Template($this->_text, 'rq');
		if($template->name) {

                        $cntbefore=count($template->fields);

			$template->removeanonfield($arguments);

                        $cntafter=count($template->fields);

			if($cntbefore!=$cntafter) {
				$this->_summary.='{{rq}} parameter '.$arguments.' removed; ';
				pecho("Parameter ".$arguments." removed from {{rq}}.", PECHO_LOG);
			}

			if( empty($template->fields) ) {
				$this->_text=$template->deleteTemplate();
				$this->_summary.='empty {{rq}} deleted; ';
				pecho("Empty {{rq}} deleted.", PECHO_LOG);
			} else {
				$this->_text=$template->wholePage();
			}
		}
	}
	
	private function _fixLonelyRq() {
		$replaceKnown='~\{\{wikify\}\}|\{\{rq\|\s*(wikify|sources|cat|check|cleanup|coord|img|patronomyc|stub|style|taxobox|translate|linkless|refless)\s*\}\}~';

		$replaceRules['patterns'] = array(
			'~\{\{(rq\||)wikify\}\}~iU',
			'~\{\{rq\|sources\}\}~iU',
			'~\{\{rq\|cat\}\}~iU',
			'~\{\{rq\|check\}\}~iU',
			'~\{\{rq\|cleanup\}\}~iU',
			'~\{\{rq\|coord\}\}~iU',
			'~\{\{rq\|img\}\}~iU',
			'~\{\{rq\|patronymic\}\}~iU',
			'~\{\{rq\|stub\}\}~iU',
			'~\{\{rq\|style\}\}~iU',
			'~\{\{rq\|taxobox\}\}~iU',
			'~\{\{rq\|translate\}\}~iU',
			'~\{\{rq\|linkless\}\}~iU',
			'~\{\{rq\|refless\}\}~iU'
		);
		$replaceRules['replacements'] = array(
			'{{викифицировать}}',
			'{{нет ссылок}}',
			'{{нет категорий}}',
			'{{достоверность статьи под сомнением}}',
			'{{чистить}}',
			'{{нет координат}}',
			'{{нет иллюстраций}}',
			'{{отчество}}',
			'{{empty}}',
			'{{стиль статьи}}',
			'{{no taxobox}}',
			'{{translate}}',
			'{{изолированная статья}}',
			'{{нет сносок}}'
		);
		
		if( preg_match($replaceKnown, $this->_text, $match) ) {

			$this->_text = preg_replace($replaceRules['patterns'], $replaceRules['replacements'], $this->_text);
			$this->_summary.=$match[0].' replaced by its analogue; ';
			pecho("Single-param rq replaced by its analogue.", PECHO_LOG);
		}
		return;
	}
}
