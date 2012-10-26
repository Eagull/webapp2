process.env.NODE_ENV ?= 'dev'
debug = process.env.NODE_ENV isnt 'production'

util = require 'util'
express = require 'express'
fs = require 'fs'
browserify = require 'browserify'
jade = require 'jade'
stylus = require 'stylus'
request = require 'request'
require 'colors'

version = "unknown"
gitsha = require 'gitsha'
gitsha __dirname, (error, output) ->
	if error then return console.error output
	version = output
	util.log "[#{process.pid}] env: #{process.env.NODE_ENV.magenta}, version: #{output.magenta}"

bundle = browserify
	mount: "/app.js"
	watch: debug
	debug: debug
	filter: if debug then String else require 'uglify-js'

jadeRuntime = require('fs').readFileSync(__dirname+"/node_modules/jade/runtime.js", 'utf8')
bundle.prepend jadeRuntime
bundle.register '.jade', (body) ->
	templateFn = jade.compile body,
		"client": true
		"compileDebug": false
	template = "module.exports = " + templateFn.toString() + ";"
bundle.addEntry __dirname + "/client/index.coffee"

app = express.createServer()
io = require('socket.io').listen(app)

app.set 'views', __dirname + '/views'
app.set 'view options', layout: false

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
	app.use (req, res, next) ->
		if not res.getHeader 'Cache-Control'
			maxAge = 86400 # seconds in one day
			res.setHeader 'Cache-Control', 'public, max-age=' + maxAge
		next()

app.configure ->
	app.use express.responseTime()
	app.use bundle
	app.use stylus.middleware
		src: __dirname + '/views'
		dest: __dirname + '/public'
	app.use express.static __dirname + '/public'

contentMap =
	home: "1QxC1VCMlZbQrFYy8Ijr1XvyyYxpj8m9x4zuQgVu1G3w"
	usage: "1Faa0akTtbOgC2k6RRjl_xRamsAYJwzFgzJb6GJ0nb80"
	terms: "1-TwAcDexcW7a1PakgQJRrHr07ZXJf_ovF1KbTPzvHns"
	privacy: "1sYF5bq56pj12Q8E9md5Y_0hFQu0vRmpdMtyzHa0qEL8"

appPages = ['room']
contentCache = {}

app.get '/*', (req, res) ->
	page = req.url.substr(1).split('/')[0]
	if page is '' then page = 'home'

	viewParams =
		docMap: JSON.stringify contentMap
		version: version
		devMode: debug

	if page of contentMap
		if page of contentCache and (Date.now()/1000) > contentCache[page].expires
			viewParams['content'] = contentCache.content
			res.render 'index.jade', viewParams
		else
			url = "http://content.dragonsblaze.com/json/" + contentMap[page]
			request {url: url, json: true, timeout: 1000}, (error, response, body) ->
				if error
					console.error error.red
					viewParams['content'] = "Unexpected server error has occured. Raise an alarm, or attempt to <a href='/room/firemoth@chat.eagull.net'>Join the Conversation!</a>"
				else
					contentCache[page] = body
					contentCache[page].expires = Date.parse(response.headers['Expires']) / 1000
					viewParams['content'] = body.content
				res.render 'index.jade', viewParams
	else if page in appPages
		viewParams['content'] = "<noscript>JavaScript is required to view this page.</noscript>"
		res.render 'index.jade', viewParams
	else
		res.send "404 Not Found", 404

io.on 'connection', (socket) ->
	socket.on 'broadcastMessage', (message) ->
		console.log 'broadcastMessage:', message
		io.sockets.emit 'messageReceived', message

app.listen process.env.PORT || 1337, ->
	addr = app.address().address
	port = app.address().port
	util.log "[#{process.pid}] http://#{addr}:#{port}/"

module.exports = app

