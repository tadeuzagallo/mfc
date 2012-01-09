cluster = require 'cluster'

process.on 'uncaughtException', (err)->
	tz.log 'uncaughtException', err

port = tz.attr 'port'

if cluster.isMaster
	cluster.fork() for [1..2]
	cluster.on 'death', => cluster.fork()
	tz.log "Server running at port #{port}"
else
	require "#{LIB_PATH}/http"
	http = require 'http'

	http.Server((req, res)->
		res.init req
	).listen port