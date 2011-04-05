<?php 

abstract class Options {
	
	private $_l10n;
	
	public function __construct($i18n) {
		$this->_l10n = $i18n;
		
	}

	public function __call($name, $arguments) {
		if(strpos($name, 'skip')===0)
			return false;
	}
	
	abstract public function skipGlobal($text); 
	
	abstract public function fixIsolated($text, $status, $chain);
	
	abstract public function fixNonCategorized($text, $status);
	
	abstract public function fixDeadend($text, $status);
}