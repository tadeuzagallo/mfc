http = require 'http'
fs = require 'fs'
path = require 'path'
crypto = require 'crypto'
coffee = require 'coffee-script'
querystring = require 'querystring'

formparser = (data, contentType)->
	parsename = (stack, name, value)->
		if ((_name = /^(\w+)\[(\w*)?\](\[\])?$/.exec(name)))
			unless stack[_name[1]]?
				if _name[2]
					stack[_name[1]] = {}
				else
					stack[_name[1]] = []
			
			unless _name[2]?
				stack[_name[1]].push value

			else if _name[3]?
				unless stack[_name[1]][_name[2]]?
					stack[_name[1]][_name[2]] = []
				
				stack[_name[1]][_name[2]].push(value)
			else 
				stack[_name[1]][_name[2]] = value
		else
			stack[name] = value

	
	if contentType is 'application/x-www-form-urlencoded'
		unless querystring
			querystring = require 'querystring'
		return querystring.parse data
		
	else if ((boundary = /boundary=(.*)$/.exec(contentType)))?
		data = data.split boundary[1]
		result = {}
		for line in data
			if ((prop = /name="([^"]*)"\r\n\r\n([^\r]*)\r\n--/.exec(line)))?
				name = prop[1]
				value = prop[2]
				parsename(result, name, value)
			else if ((prop = /name="([^"]*)"; filename="([^"]*)"\r\nContent-Type: ([^\r]+)\r\n\r\n([\s\S]*)?\r\n--/.exec(line)))
				name = prop[1]
				value = 
					filename: prop[2]
					contentType: prop[3]
					content: prop[4]
				parsename(result, name, value)
		return result
	else 
		return data


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
			@_cookies = {}
			@_parse @cookies, ';', no
			unless @_cookies.TZSESSID
				@_cookies.TZSESSID = new @Cookie 'TZSESSID', @_generate_id(), send: yes, save: no
			@id = @_cookies.TZSESSID.value
			@_file = "/tmp/#{@id}"

			unless path.existsSync @_file
				fd = fs.openSync(@_file, 'a+')
				fs.close(fd)

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
				r.push "path=#{@path or tz.attr('baseUrl') or '/'}" if @send
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
			
			if @_cookies[key].save is true
				delete @_cookies[key]
				@save()
			else
				@_cookies[key].send = true
				@_cookies[key].expires = new Date(Date.now() - 24 * 60 * 60 * 1000).toString()
			return @
		get: (key)->
			@_cookies[key].value if @_cookies[key]
		output: ->
			_output = []
			(_output.push "#{cookie.toString()}" if cookie.send) for name, cookie of @_cookies
			_output
		save: ->
			output = (cookie.toString() for name, cookie of @_cookies when cookie and cookie.save)
			fs.writeFileSync @_file, output.join '\n'

http.ServerResponse.prototype.params = (name, value, override = yes, _default)->
			unless name
				return tz._public @_params
			else if typeof name is 'object' and Object.prototype.toString.call(name) is '[object Object]'
				@params(key, value) for key, value of name
				return @
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
			@attr 'layout', layout
			fs.readFile @view(view), (err, content)=>
				throw err if err
				content = @template content, params
				@writeCode 200
				if layout
					return fs.readFile @layout(layout), (err, _content)=>
						throw err if err
						params.__internal_body = content
						@end @template(_content, params), 'utf8'
				else @end(content, 'utf8')
			tz.log "Renedered!"
		catch err
			tz.log("Failed rendering...", err)
			@_500 err
http.ServerResponse.prototype.template = (content, params = {})->
		spaceStringify = (string)->
			unless string
				return ''
			
			string.replace(/\r/g, '\\r').replace(/\t/g, '\\t').replace(/\n/g, '\\n')
		multiline = (space, code)->
			space = spaceStringify(space.split('\n').pop())
			temp = (l for l in code.split('\n') when l)
			code = []
			for line, index in temp
				line = line.replace new RegExp("^#{space}", 'g'), ''
				if index is 0
					line = line.replace /^(\s*)(.*)/, (match, _space, nospace)->
						_space = spaceStringify _space
						
						if _space.length > 0
							space = space + _space
						
						return nospace
				code.push line
			code.join '\n'
		try
			content += ''
			c = coffee.compile
			r = /(\s*)<%(=)?(#)?([\s\S]*?)%>/g
			holder = []
			__internal = @attr 'internal'
			template = "var #{__internal} = [], yield = function(){return params.__internal_body;}, print = function () { #{__internal}.concat(arguments); }; with(params){#{__internal}.push('" + content
				.replace(/\\/g, '\\\\')
				.replace(/'/g,'\\\'' )
				.replace(/(\s*)<coffee>([\s\S]+?)<\/coffee>/g, (match, space, code)->
					code = code.replace(r, (match)->
						return match.replace /\\'/g, '"'
					).replace /\\'/g, '\''
					code = multiline(space, code)
					try
						code = c(code).trim().replace /'/g, '\\\''
					catch err
						tz.log "Failed compiling coffee tag, piece of code: #{code}", err
						throw err

					return "#{space}<script type=\"text/javascript\">#{code}</script>"
				)
				.replace(r,  (match, space, print, comment, code, index, all)=>
						code = code.trim().replace /\\'/g,'\''
						code = multiline space, code
						if print or comment
							try
								code = c("(->\n\t#{code}).call(this)").trim()
							catch err
								tz.log "Failed compiling print code, piece of code: #{code}", err
								throw err

							code = code.substr(0, code.length - 1) if code.charAt(code.length-1) is ';'
							code = "'<!-- ' + #{code} + ' -->'" if comment
							return "', '#{space}', #{code}, '"
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
							try
								code = c(code)
							catch err
								tz.log "Failed compiling eval code, piece of code: #{code}", err
						code = match[1] if ((match = code.match /\(function\(\)\s*{([\s\S]*)}\s*\).call\(this\)\s*;/))
						return "'); #{code} #{__internal}.push('"
				) + "');} return #{__internal}.join('');"
			(new Function 'params', template
				.replace(/\n/g, '')
				.replace(/\t/g, '')
				.replace(/\r/g, '')
				.replace(/\s+/g, ' ')
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
	_headers = {}
	_headers['Content-Type'] = ct
	if code is 200 and @session._is_started
		output = @session.output()
		if output.length
			_headers['Set-Cookie'] = output
	@writeHead code, _headers

http.ServerResponse.prototype.redirect = (url = {})->
	if typeof url is 'object'
		url = @createUrl url

	unless typeof url is 'string'
		@_500()

	@writeHead 302, Location: url
	@end ('')

http.ServerResponse.prototype.createUrl = (obj={})->
		if obj.controller
			obj.action or= 'index'
			url = "#{@attr 'baseUrl'}/#{obj.controller}/#{obj.action}/" 
			url += "#{key}/" + (if value then "#{value}/" else "") for key,value of obj.params if obj.params
			url = url.replace /\/$/, ''
			if ((ext = @attr 'urlExtension'))
				url += ".#{ext}"
			url
		else if obj.type
			return "#{@attr('staticUrl') or @attr('baseUrl') + '/static'}/#{obj.type}/#{obj.file}.#{obj.type}"
		else
			return baseUrl

http.ServerResponse.prototype.init = (request)->
			@_attr = {}
			@_params = {}

			if request.url is '/favicon.ico' and @attr 'ignoreFavicon'
				return

			tz.log "URL #{request.url} requested!"
			@method = request.method.toUpperCase()
			@url = request.url
			@headers = request.headers
			@session = new __Session(@headers.cookie)

			@__set_post(request)

http.ServerResponse.prototype.__set_post = (request)->
		start = @attr('initialize') or ->
		if @method in ['POST', 'PUT']
			data = ''
			request.on 'data', (chunk)->
				data += chunk.toString()
			request.on 'end', =>
				@params formparser data, @headers['content-type']
				start.call(@, request)
				@match()
		else
			start.call(@, request)
			@match()

http.ServerResponse.prototype.match = ->
	try
		url = @url.split('?')[0]
		if ((ext = @attr 'urlExtension'))
			url = url.replace new RegExp(".#{ext}$"), ''
		_urlArray = url.split '/'
		urlArray = []
		(urlArray.push v if v) for v in _urlArray
		unless urlArray.length
			return @route()
		if urlArray[0] is 'static'
			filepath = path.join @attr('publicPath'), path.join.apply this, urlArray[1...]
			return @handleStatic filepath
		
		@attr('controller', tz.ucfirst urlArray.shift()) if urlArray.length
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
			tz.log("Failed routing", err)
			
			if ((action = @attr 'controllerNotFound'))
				action.call(@);
			else
				err = new Error "Controller '#{controllerName}' was not found at '#{controllerFolder}'"
				return @_404 err
		
		try
			beforeAction = @attr 'beforeAction'
			action = @attr 'action'
			controller.initialize.call(@) if controller.initialize
			controller[beforeAction].call(@) if controller[beforeAction]
			
			unless controller[action]
				throw new Error "Controller '#{controllerPath}' does not have an action called '#{action}'"

			controller[action].call(@)
		catch err
			tz.log("Failed routing", err)
			
			if ((action = @attr 'actionNotFound'))
				action.call(@);
			else
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
			s.on 'error', => 
				@writeHead 404
				@end()
			s.pipe(@)
		catch err
			@_404 err

http.ServerResponse.prototype.view = (view)->
		"#{@attr 'viewsFolder'}/#{@attr('controller').toLowerCase()}/#{view}.#{@attr 'extension'}"
	
http.ServerResponse.prototype.layout = (layout)->
	"#{@attr 'layoutsFolder'}/#{layout}.#{@attr 'extension'}"
	