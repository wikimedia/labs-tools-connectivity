<?php

require( __DIR__ .'/options.php');

class Options_ru extends Options {
	
	private $_text;
	
	public function skipGlobal($text) {
		$this->_text = $text;
		
		/*if(Template::testTemplates(strtolower($this->_text), array('к быстрому удалению','ку','к удалению','db','d','delete','del','уд','куд','кбу','deletebecause'))) { // TODO: get delete nominations through i18n
			pecho('Article is nominated for deletion.', PECHO_LOG);
			return true;
		}*/
		return false;
	}
	
	public function skipIsolated($text) {
		$this->_text = $text;
		return false;
	}
	
	public function skipNoncategorized($text) {
		$this->_text = $text;
		return false;
	}
	
	public function skipDeadend($text) {
		$this->_text = $text;
		return false;
	}
	
	public function fixIsolated($text, $status, $cluster) {
		$this->_text = $text;
		
		if($status == -1) {
			$this->_deleteRqArguments( 'linkless' );
		} elseif($status == 1) {
			if($cluster != '_1')
				$this->_deleteRqArguments( 'linkless' );
		}
		return $this->_text;
	}
	
	public function fixNonCategorized($text, $status) {
		$this->_text = $text;
		
		if($status == -1)
			$this->_deleteRqArguments('cat');
		return $this->_text;
	}
	
	public function fixDeadend($text, $status) {
		$this->_text = $text;
		return $this->_text;
	}
	
	private function _deleteRqArguments( $arguments ) {
		if(is_array($arguments))
			foreach($arguments as $argument)
				deleteRqArguments($argument);
		
		if(!is_string($arguments))
			return;
		
		$template = new Template($this->_text, 'rq');
		if($template) {
			$template->removeanonfield($arguments);
			// delete {{rq}} if there are no arguments for it left
			$this->_text = (empty($template->fields))? $template->deleteTemplate() : $template->wholePage();
		}
	}
}