<?php

require( __DIR__ .'/options.php');

class Options_be extends Options {
	
	private $_text;
	
	public function skipGlobal($text) {
		$this->_text = $text;
		
		/*if(Template::testTemplates(strtolower($this->_text), array('delete','выдаліць'))) { // TODO: get delete nominations through i18n
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
	
	public function fixIsolated($text, $status, $chain) {
		$this->_text = $text;
		return $this->_text;
	}
	
	public function fixNonCategorized($text, $status) {
		$this->_text = $text;
		return $this->_text;
	}
	
	public function fixDeadend($text, $status) {
		$this->_text = $text;
		return $this->_text;
	}

}