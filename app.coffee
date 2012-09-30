process.env.NODE_ENV ?= 'dev'
debug = process.env.NODE_ENV isnt 'production'

util = require 'util'
express = require 'express'
fs = require 'fs'
request = require 'request'
require 'colors'

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

accessLogStream = fs.createWriteStream './access.log',
	flags: 'a'
	encoding: 'utf8'
	mode: 0o0644

app.use express.logger
	format: if debug then 'dev' else 'default'
	stream: accessLogStream

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

contentMap =
	home: "1QxC1VCMlZbQrFYy8Ijr1XvyyYxpj8m9x4zuQgVu1G3w"
	usage: "1Faa0akTtbOgC2k6RRjl_xRamsAYJwzFgzJb6GJ0nb80"

contentCache = {}

app.get '/*', (req, res) ->
	page = req.url.substr(1).split('/')[0]
	if page is '' then page = 'home'
	if page of contentMap
		if page of contentCache and (Date.now()/1000) > contentCache[page].expires
			res.render 'index.jade', version: version, content: contentCache.content
		else
			url = "http://content.dragonsblaze.com/json/" + contentMap[page]
			request {url: url, json: true}, (error, response, body) ->
				if error
					console.error error.red
					content = "Unexpected server error has occured. Raise an alarm!"
				else
					contentCache[page] = body
					contentCache[page].expires = Date.parse(response.headers['Expires']) / 1000
				res.render 'index.jade', version: version, content: body.content
	else
		content = "<noscript>JavaScript is required to view this page.</noscript>"
		res.render 'index.jade', version: version, content: content

io.on 'connection', (socket) ->
	socket.on 'broadcastMessage', (message) ->
		console.log 'broadcastMessage:', message
		io.sockets.emit 'messageReceived', message

app.listen process.env.PORT || 1337, ->
	addr = app.address().address
	port = app.address().port
	util.log "[#{process.env.NODE_ENV}, #{process.pid}] http://#{addr}:#{port}/"

module.exports = app

