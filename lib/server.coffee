cluster = require 'cluster'

process.on 'uncaughtException', (err)->
	tz.log 'uncaughtException', err

port = tz.attr 'port'

if cluster.isMaster
	cluster.fork() for [1..3]
	cluster.on 'death', (worker)-> 
		console.log 'worker dead...', worker
		cluster.fork()
	tz.log "Server running at port #{port}"
else
	require "#{LIB_PATH}/http"
	http = require 'http'
	fs = require 'fs'
	path = require 'path'

	server = http.Server((request, response)->
		response.init request
	).listen port

	watch = []
	
	getFiles = (_path)->
		files = fs.readdirSync _path
		for file in files
			file = path.join _path, file
			stat = fs.statSync file
			if stat.isDirectory()
				getFiles file
			else
				watch.push file
	
	getFiles tz.attr 'basePath'

	for file in watch
		fs.watchFile file, (current, previous)->
			if Number(current.mtime) isnt Number(previous.mtime)
				delete cluster