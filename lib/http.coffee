http = require 'http'
fs = require 'fs'
path = require 'path'
crypto = require 'crypto'
coffee = require 'coffee-script'
querystring = require 'querystring'

class __Session
		constructor: (@cookies)->
			@
		_generate_id: ->
			time = Date.now().toString()
			base64 = crypto.createHash('md5').update(time).digest('base64').replace(/\=/g, '')
			hex = crypto.createHash('md5').update(time).digest('hex')
			p = 'abcdefghijklmnopqrstuvwxyz1234567890'
			random = ->
				return p.charAt Math.floor Math.random() * p.length
			return "#{base64}#{time}#{hex}#{time}".replace /[^a-zA-Z1-9]/g, random()
		start: ->
			@_is_started = yes
			@_cookies = new Object
			@_parse @cookies, ';', no
			unless @_cookies.TZSESSID
				@_cookies.TZSESSID = new @Cookie 'TZSESSID', @_generate_id(), send: yes, save: no
			@id = @_cookies.TZSESSID.value
			@_file = "/tmp/#{@id}"
			fs.openSync(@_file, 'a+') unless path.existsSync @_file
			@_parse fs.readFileSync(@_file).toString(), '\n', save: yes
		Cookie: class
			constructor: (@name, @value, opts = {})->
				for key, value of opts
					@[key] = value
				if @type is 'session'
					@send = no
					@save = yes
				else if @type is 'browser'
					@send = yes
					@save = no
			toString: ->
				r = ["#{@name}=#{@value}"]
				r.push "path=#{@path or tz.attr('baseUrl')}" if @send
				r.push "expires=#{@expires}" if @send and @expires
				r.push "domain=#{@domain}" if @domain and @send
				return r.join ';'
		_parse: (data, separator=';', opts)->
			unless data
				return
			for props in data.split separator
				props = props.split('=')
				name = props.shift().trim()
				value = props.join('=').trim()
				@_cookies[name] =  new @Cookie name, value, opts
		set: (key, value, opt = {})->
			unless key and value
				return false
			if @_cookies[key]
				@_cookies[key].value = value
				for k, v of opt
					@_cookies[key][k] = v
			else
				opt.save = yes unless opt.save?
				@_cookies[key] = new @Cookie key, value, opt
			@save()
			@
		rm: (key)->
			unless key and @_cookies[key]
				return
			
			if @_cookies[key].save
				delete @_cookies[key]
				@save()
			else
				@_cookies[key].send = true
				@_cookies[key].expires = new Date(Date.now() - 24 * 60 * 60 * 1000).toString()
			@
		get: (key)->
			@_cookies[key].value if @_cookies[key]
		output: ->
			_output = new Array
			(_output.push "#{cookie.toString()}" if cookie.send) for name, cookie of @_cookies
			_output
		save: ->
			output = new Array
			(output.push cookie.toString() if cookie.save) for name, cookie of @_cookies
			fs.writeFile @_file, output.join '\n'

http.ServerResponse.prototype.params = (name, value, override = yes, _default)->
			unless name
				return tz._public @_params
			return tz._get @, 'params', name, value, override, _default

http.ServerResponse.prototype.attr = (name, value, override = yes, _default)->
			tz._get @, 'attr', name, value, override, _default

http.ServerResponse.prototype.render = (layout, view, params = {})->
		try
			if (arguments.length is 2 and arguments[1] instanceof Object) or arguments.length is 1
				@writeCode 200, 'text/plain'
				view or= {}
				return @end @template layout, view
			@attr 'view', view
			@attr 'params', params
			fs.readFile tz.view(view), (err, content)=>
				throw err if err
				content = @template content, params
				@writeCode 200
				if layout
					@attr 'layout', layout
					return fs.readFile tz.layout(layout), (err, _content)=>
						throw err if err
						params.__internal_body = content
						@end @template(_content, params), 'utf8'
				else @end(content, 'utf8')
			tz.log "Renedered!"
		catch err
			tz.log("Failed rendering...", err)
			@_500 err
http.ServerResponse.prototype.template = (content, params = {})->
		try
			content += ''
			c = coffee.compile
			r = /<%(=)?(#)?([\s\S]*?)%>/g
			holder = new Array
			__internal = @attr 'internal'
			template = "var #{__internal} = [], yield = function(){return params.__internal_body;}; with(params){#{__internal}.push('" + content
				.replace(/\\/g, '\\\\')
				.replace(/'/g,'\\\'' )
				.replace(/<coffee>([\s\S]+?)<\/coffee>/g, (match, code)->
					code = code.replace(r, (match)->
						return match.replace /\\'/g, '"'
					).replace /\\'/g, '\''
					code = c(code).trim().replace /'/g, '\\\''
					return "<script type=\"text/javascript\">#{code}</script>"
				)
				.replace(r,  (match, print,comment, code, index, all)=>
						code = code.trim().replace /\\'/g,'\''
						if print or comment
							code = c("(->\n\t#{code}).call(this)").trim()
							code = code.substr(0, code.length - 1) if code.charAt(code.length-1) is ';'
							code = "'<!-- ' + #{code} + ' -->'" if comment
							return "', #{code}, '"
						else if code is 'end'
							if holder.length then code = holder.pop() else code = '}'
						else if code.charAt(code.length-1) is ':'
							_fn = (match, code) ->
								holder.push code
								''
							try
								code = c(code.substr(0, code.length-1) + "\n\t#{__internal}\n\t#{__internal}").replace(new RegExp("#{__internal};\\s*#{__internal};([\\s\\S.]*)"), _fn)
							catch err
								code = "}#{code.substr 0, code.length-1}{"
						else 
							code = c(code)
						code = match[1] if ((match = code.match /\(function\(\)\s*{([\s\S]*)}\s*\).call\(this\)\s*;/))
						return "'); #{code} #{__internal}.push('"
				) + "');} return #{__internal}.join('');"
			(new Function 'params', template
				.replace(/\n/g, '')
				.replace(/\t/g, '')
				.replace(/\r/g, '')
				.replace(/\s/g, ' ')
			).call @, params
		catch err
			@_500 err

http.ServerResponse.prototype._404 = (err)->
	@writeHead 404
	@end "<html><head><title>404</title></head><body><center><h2>The page that you are looking for does not exist.</h2>" + (if @attr('debug') and err and err and err.stack then "<pre style='text-align:left;'>#{err.stack}</pre>" else "") + "</center></body><html>"

http.ServerResponse.prototype._500 = (err)->
	@writeHead 500
	@end "<html><head><title>500</title></head><body><center><h2>Internal server error</h2>" + (if @attr('debug') and err and err.stack then "<pre style='text-align:left;'>#{err.stack}</pre>" else "") + "</center></body></html>"

http.ServerResponse.prototype.writeCode = (code, ct='text/html')->
	_headers = new Object
	_headers['Content-Type'] = ct
	if code is 200 and @session._is_started
		output = @session.output()
		if output.length
			_headers['Set-Cookie'] = output
	@writeHead code, _headers

http.ServerResponse.prototype.redirect = (url = {})->
	if typeof url is 'object'
		url = @createUrl url

	unless typeof Url is 'string'
		return off

	@writeHead 302, Location: url
	@end ('')

http.ServerResponse.prototype.createUrl = (obj={})->
		if obj.controller
			obj.action or= 'index'
			url = "#{@attr 'baseUrl'}/#{obj.controller}/#{obj.action}/" 
			url += "#{key}/" + (if value then "#{value}/" else "") for key,value of obj.params if obj.params
			url
		else if obj.type
			return "#{@attr('staticUrl') or @attr('baseUrl') + '/static'}/#{obj.type}/#{obj.file}"
		else
			return baseUrl

http.ServerResponse.prototype.init = (req)->
			tz.log "URL #{req.url} requested!"
			@_attr = new Object
			@_params = new Object
			@method = req.method.toUpperCase()
			@url = req.url
			@headers = req.headers
			@session = new __Session(@headers.cookie)
			@__set_post(req)

http.ServerResponse.prototype.__set_post = (req)->
		if @method in ['POST', 'PUT']
			data = ''
			req.on 'data', (chunk)->
				data += chunk.toString()
			req.on 'end', =>
				for name, value of querystring.parse(data)
					@params name, value
				@match()
		else
			@match()

http.ServerResponse.prototype.match = ->
	try
		url = @url.split('?')[0]
		_urlArray = url.split '/'
		urlArray = new Array
		(urlArray.push v if v) for v in _urlArray
		unless urlArray.length
			return @route()
		if urlArray[0] is 'static'
			filepath = path.join @attr('publicPath'), path.join.apply this, urlArray[1...]
			return @handleStatic filepath
		
		@attr 'controller', tz.ucfirst urlArray.shift()
		@attr('action', urlArray.shift()) if urlArray.length

		while urlArray.length
			@params urlArray.shift(), urlArray.shift(), yes, ''

		@route()
	catch err
		@_404 err

http.ServerResponse.prototype.route = ->
		tz.log "Started routing"
		try
			controllerName = "#{@attr 'controller'}.coffee"
			controllerFolder = @attr 'controllersFolder'
			controllerPath = path.join controllerFolder, controllerName
			controller = new require controllerPath
		catch err
			err = new Error "Controller '#{controllerName}' was not found at '#{controllerFolder}'"
			tz.log("Failed routing", err)
			return @_404 err
		
		try
			beforeAction = @attr 'beforeAction'
			action = @attr 'action'
			controller.initialize.call(@) if controller.initialize
			controller[beforeAction].call(@) if controller[beforeAction]
			
			unless controller[action]
				throw new Error "Controller '#{controllerPath}' does not have an action called '#{action}'"

			controller[action].apply(@)
		catch err
			tz.log("Failed routing", err)
			@_404 err

http.ServerResponse.prototype.handleStatic = (filename)->
		try
			mime = 
				'js': 'application/javascript'
				'css': 'text/css'
				'jpg': 'image/jpeg'
				'png': 'image/png'
				'git': 'image/gif'
			s = fs.createReadStream filename
			@writeHead 200, 'Content-Type': mime[filename.split('.').pop()]
			s.on 'error', -> 
				@writeHead 404
				@end()
			s.pipe(@)
		catch err
			@_404 err