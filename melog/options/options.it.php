<?php

require( __DIR__ .'/options.php');

class Options_it extends Options {
	
	public function skipGlobal($text) {
		/*$this->_text = $text;
		
		if(Template::testTemplates(strtolower($this->_text), array('delete','Cancella subito','WIP'))) { // TODO: get nominations through i18n
			pecho('Article is nominated for deletion.', PECHO_LOG);
			return true;
		}*/
		return false;
	}
}
