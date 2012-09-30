process.env.NODE_ENV ?= 'dev'
debug = process.env.NODE_ENV isnt 'production'

util = require 'util'
express = require 'express'
fs = require 'fs'

version = "unknown"
gitsha = require 'gitsha'
gitsha '.', (error, output) ->
	if error then return console.error output
	version = output
	util.log "[#{process.env.NODE_ENV}, #{process.pid}] version: #{output}"

app = express.createServer()
io = require('socket.io').listen(app)

app.set 'view options',
	layout: false

app.configure 'dev', ->
	io.set 'log level', 2

app.configure 'production', ->
	io.set 'log level', 1
	io.enable 'browser client minification'
	io.enable 'browser client etag'
	io.enable 'browser client gzip'

app.configure ->
	app.use express.responseTime()
	app.use require('connect-assets')()
	app.use express.static(__dirname + '/public')

app.get '/*', (req, res) ->
	res.render 'index.jade', version: version

io.on 'connection', (socket) ->
	socket.on 'broadcastMessage', (message) ->
		console.log 'broadcastMessage:', message
		io.sockets.emit 'messageReceived', message

app.listen process.env.PORT || 1337, ->
	addr = app.address().address
	port = app.address().port
	util.log "[#{process.env.NODE_ENV}, #{process.pid}] http://#{addr}:#{port}/"

module.exports = app

