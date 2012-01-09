global.tz =
	_defaults:
		_before_action: 'beforeAction'
		_controller: 'Main'
		_action: 'index'
		_extension: 'html'
		_host: 'localhost'
		_port: 4000
		_internal: '_tz_internal_' + Math.round Date.now() * Math.random()
		_debug: true
		_debug_level: 'high'
		_base_url: ''
	_get: (obj, key, name, value, override, _default)->
		key = @_private key
		name = @_private name if name
		if (override  or not obj[key][name]) and (value or _default?)
			if not value and _default and (match = _default.match /^eval:(.*)$/)
				_default = eval match[1]
			obj[key][name] = value or _default
		return if value? then obj else (if obj[key][name]? then  obj[key][name] else (if key is '_attr' then @_defaults[name] else undefined))
	attr: (name)->
		unless name
			return false
		return @_defaults[@_private name]
	log: (txt, err)->
		if @attr 'debug'
			console.log "#{(new Date).toString()}: #{txt}" if @attr('debugLevel') is 'high'
			console.log err.stack if err and err.stack
		@
	
	ucfirst: (str)->
		"#{str.substr(0,1).toUpperCase()}#{str.substr(1)}"
	
	_private: (prop)->
		('_' + prop.replace /([A-Z]+)/g, '_$1').toLowerCase()
	
	_public: (prop)->
		if typeof prop is 'object'
			_obj = {}
			_obj[arguments.callee(name)] = value for name, value of prop
			return _obj
		prop.substr(1).replace /_([a-z])/g, (match, letter, index)-> letter.toUpperCase()
	
	__set_default: (name, value)->
		name = @_private name
		@_defaults[name] = value
		@