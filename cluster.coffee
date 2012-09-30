cluster = require 'cluster'

if not cluster.isMaster then return require './app'

util = require 'util'
express = require 'express'
gitpull = require 'gitpull'
gitsha = require 'gitsha'
require 'colors'

numCPUs = require('os').cpus().length
cluster.fork() for i in [0...numCPUs]
cluster.on 'exit', (worker, code, signal) ->
	if worker.suicide
		console.log "Worker killed: pid: #{worker.process.pid}, code #{code}, signal #{signal}"
	else
		console.error "Worker died: pid: #{worker.process.pid}, code #{code}, signal #{signal}".red
		cluster.fork()

controller = express.createServer()

controller.post '/update', (req, res) ->
	gitsha '.', (error, output) ->
		if error then return console.error output
		initChecksum = output
		console.log "initial checksum: #{output}"
		console.log "gitpull'ing...".cyan
		gitpull '.', (error, output) ->
			if error then return console.error output
			console.log "gitpull success"
			gitsha '.', (error, output) ->
				if error then return console.error output
				console.log "final checksum: #{output}"
				if output is initChecksum
					return console.log "No updates found!".red
				console.log "Update found, restarting workers!".green
				worker.disconnect() for id, worker of cluster.workers
				cluster.fork() for i in [0...numCPUs]
	res.send 'roger'

controller.get '*', (req, res) ->
	res.send '404 Not Found', 404

controller.post '*', (req, res) ->
	res.send '404 Not Found', 404

controller.listen process.env.CONTROLLER_PORT or 0, ->
	addr = controller.address().address
	port = controller.address().port
	util.log "[#{process.env.NODE_ENV}, #{process.pid}] Controller: http://#{addr}:#{port}/"

