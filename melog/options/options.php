<?php 

abstract class Options {
	
	private $_l10n;
	
	protected $_text;

	protected $_summary;

	public function __construct($i18n) {
		$this->_l10n = $i18n;
	}

	public function __call($name, $arguments) {
		if(strpos($name, 'skip')===0)
			return false;
	}
	
	public function skipGlobal($text) {
		return false;
	}
	
	public function skipIsolated($text) {
		return false;
	}
	
	public function skipNoncategorized($text) {
		return false;
	}
	
	public function skipDeadend($text) {
		return false;
	}

	public function fixIsolated($text, $status, $chain) {
		return array('text' => $text, 'summary' => '');
	}
	
	public function fixNonCategorized($text, $status) {
		return array('text' => $text, 'summary' => '');
	}
	
	public function fixDeadend($text, $status) {
		return array('text' => $text, 'summary' => '');
	}
}
