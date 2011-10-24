<?php

/**
 * Internationalization class
 * @author wizardist
 *
 */
class i18n {
	
	/**
	 * Localization language
	 * @var string
	 */
	private $_srv;

	/**
	 * Localization language
	 * @var string
	 */
	private $_lang;
	
	/**
	 * Storage holding all localization data
	 * @var array
	 */
	private $_storage;
	
	public function __construct($srv, $lang) {
		$this->_srv = $srv;
		$this->_lang = $lang;
		
		$this->_getLocalization();
	}
	
	/**
	 * Gets namespace name
	 * @param int $id		namespace ID
	 * @return string			namespace name
	 */
	public function getNamespaceName($id) {
		return $this->_storage['namespaces'][$id]['*'];
	}
	
	/**
	 * Gets an element from storage
	 * @param string $name	storage element name
	 * @return mixed
	 */
	public function getStorage($name) {
		return $this->_storage[$name];
	}
	
	/**
	 * Gives a preg ready variants of namespaces
	 * @param mixed $skip	which namespace to skip, array may be submitted
	 * @return void|string
	 */
	public function getPregNamespaces( $skip = array() ) {
		if(empty($skip))
			return;
		if(is_int($skip))
			$skip = array( $skip );
		
		$result = '';
		
		foreach($this->getArray('namespaces') as $id => $data) {
			if(in_array($id, $skip))
				continue;
			if($data['*']=='')
				continue;
			$result .= $data['*'].'|'.$data['canonical'].'|';
		}
		foreach($this->getArray('namespacealiases') as $id => $data) {
			if(in_array($id, $skip))
				continue;
			$result .= formPregVariants($data).'|';
		}
		
		return str_replace(' ', '\s', rtrim($result, '|'));
	}
	
	
        /**
	 * Gets mnemonics for isolated article cluster types
	 * @param int $id	1 gets orphan, 2 gets ring, 3 gets cluster, otherwise all three mnemonics in an array
	 * @return multitype:string,array
	 */
	public function getIsolatedMnemonics($id=0) {
		switch($id) {
			case 1: // orphan
				return $this->_storage['isolated']['orphan'];
			case 2: // ring
				return $this->_storage['isolated']['ring'];
			case 3: // cluster
				return $this->_storage['isolated']['cluster'];
			case 0:
			default: // all mnemonics
				return array($this->getIsolatedMnemonics(1), $this->getIsolatedMnemonics(2), $this->getIsolatedMnemonics(3));
		}
	}
	
	/**
	 * Gets an array from storage, array's element or a range of array's elements
	 * @param string $name		storage element name
	 * @param mixed	 $element	sub-element of storage's element to return. If $end is set, then $element is treated as start position
	 * @param int $end		end position for range selection
	 * @return mixed
	 */
	public function getArray($name, $element=0, $end=0) {
		switch(func_num_args()) {
			case 1: // returning whole storage element
				if(!is_array($this->_storage[func_get_arg(0)]))
					pecho('In getArray(): non-array returned, array expected', PECHO_WARN);
				return $this->_storage[func_get_arg(0)];
			case 2: // returning only one piece of storage element
				if(!is_array($this->_storage[func_get_arg(0)])) {
					pecho('In getArray(): array expected to get its element, non-array value returned', PECHO_WARN);
					return $this->_storage[func_get_arg(0)];
				} else {
					if(isset($this->_storage[func_get_arg(0)][func_get_arg(1)]))
						return $this->_storage[func_get_arg(0)][func_get_arg(1)];
					else {
						pecho('In getArray(): ['.func_get_arg(0).']['.func_get_arg(1).'] in storage not found, whole storage element returned', PECHO_WARN);
						return $this->_storage[func_get_arg(0)];
					}
				}
			case 3: // returning range of elements
				if(!is_array($this->_storage[func_get_arg(0)])) {
					pecho('In getArray(): array expected to get a range of elements, non-array value returned', PECHO_WARN);
					return $this->_storage[func_get_arg(0)];
				} else {
					return array_slice($this->_storage[func_get_arg(0)], func_get_arg(1), func_get_arg(2)-func_get_arg(1)+1);
				}
		}
	}
	
	/**
	 * Gets file contents
	 * @param string $name	filename
	 * @return string		file contents
	 */
	private function _retrieveFile($name) {
		$name = $name.'.'.$this->_lang.'.txt';
		pecho("Retrieving resources from {$name}.", PECHO_LOG);
		return file_get_contents(__DIR__ . '/../i18n/'.$name);
	}
	
	/**
	 * Treats given file as array and loads it from given file
	 * @param string $name	file name
	 * @return array		array from file
	 */
	private function _loadArray($name) {
		return unserialize($this->_retrieveFile($name));
	}
	
	/**
	 * Treats given file as string and prepares it for submitting to storage
	 * @param string $name	file name
	 * @return string		file contents prepared
	 */
	private function _loadString($name) {
		return trim($this->_retrieveFile($name));
	}
	
	/**
	 * Formation of l10n storage
	 */
	private function _getLocalization() {
		pecho("Updating localization cache for {$this->_lang}wiki.", PECHO_LOG);
		createI18nCache($this->_srv, $this->_lang);

		pecho("Localization resources loading for {$this->_lang}wiki.", PECHO_LOG);
		// isolated
		$this->_appendStorage('isolated', $this->_loadArray('isolated'));
		
		// dead-end
		$this->_appendStorage('deadend', $this->_loadString('deadend'));
		
		// non-categorized
		$this->_appendStorage('noncategorized', $this->_loadArray('noncat'));
		
		// namespaces and aliases
		$this->_appendStorage('namespaces', $this->_loadArray('namespaces'));
		$this->_appendStorage('namespacealiases', $this->_loadArray('namespacealiases'));
		
		// magicwords
		$this->_appendStorage('magicwords', $this->_loadArray('magicwords'));
		
		// prepare all namespaces, their aliases, and magicwords
		$this->_prepareMWdata();
		
		// project root
		$this->_appendStorage('root', $this->_loadString('root'));
		
		// disambig templates
		$this->_appendStorage('disambigs', $this->_loadArray('disambigs'));
		
		// iwiki prefixes
		$this->_appendStorage('iwiki', $this->_loadArray('iwiki'));
	}
	
	/**
	 * Preparation of MediaWiki i18n data
	 */
	private function _prepareMWdata() { // some Indian code here
		// arrange namespace aliases by namespace id
		$aliases = $this->_storage['namespacealiases'];
		$this->_deleteStorage('namespacealiases');
		
		foreach($aliases as $alias) {
			$namespacealiases[$alias['id']][] = $alias['*'];
		}
		$this->_appendStorage('namespacealiases', $namespacealiases);
		
		// arrange magic words by magic word name
		$mwold = $this->_storage['magicwords'];
		$this->_deleteStorage('magicwords');
		
		foreach($mwold as $magicword) {
			$magicwords[$magicword['name']] = $magicword['aliases'];
		}
		$this->_appendStorage('magicwords', $magicwords);
		
		
	}
	
	/**
	 * Adds data to storage
	 * @param string $name	name of new storage element
	 * @param mixed $data	data to push
	 */
	private function _appendStorage($name, $data) {
		$this->_storage[$name] = $data;
	}
	
	/**
	 * Deletes an element from storage
	 * @param string $name	storage element name
	 */
	private function _deleteStorage($name) {
		unset($this->_storage[$name]);
	}
}