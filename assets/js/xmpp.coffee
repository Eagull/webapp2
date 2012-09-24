xmpp = window.xmpp or = {}
blaze = window.blaze

DEFAULT_BOSH_SERVICE = 'http://xmpp.eagull.net:5280/http-bind'
DEFAULT_USER = 'anon.eagull.net'
RESOURCE = "webapp-#{blaze.version}-#{parseInt(Date.now()/1000)}"

xmpp.rooms = {}
joinQueue = []

xmpp.send = (to, msg, attr) ->
	attr = attr or {}
	attr.to = to
	attr.type = attr.type or 'groupchat'
	xmpp.conn.send($msg(attr).c('body', null, msg))

xmpp.join = (room, nick) ->
	if not xmpp.conn.connected
		joinQueue.push
			room: room
			nick: nick
		return
	xmpp.conn.send $pres({from: xmpp.conn.jid, to: room + '/' + nick}).c('x', {xmlns: Strophe.NS.MUC })
	xmpp.rooms[room] =
		nick: nick
		roster: []

$(xmpp).bind 'connected', ->
	if not xmpp.conn.connected
		return console.error "XMPP 'connected' triggered while `xmpp.conn.connected` is false"
	joinQueueCopy = $.merge [], joinQueue
	joinQueue = []
	for roomObj in joinQueueCopy
		xmpp.join roomObj.room, roomObj.nick

xmpp.part = (room, msg) ->
	p = $pres
		to: room
		type: 'unavailable'
	p.c('x', {xmlns: Strophe.NS.MUC }).up()
	p.c('status', null, msg) if msg
	xmpp.conn.send p

xmpp.messageHandlerProxy = (msg) ->
	try
		xmpp.messageHandler(msg)
	catch error
		console.error error.stack
	return true

xmpp.mucPresenceHandlerProxy = (p) ->
	try
		xmpp.mucPresenceHandler(p)
	catch error
		console.error error.stack
	return true

xmpp.messageHandler = (msg) ->
	room = Strophe.getBareJidFromJid(msg.getAttribute 'from')
	return if not room of xmpp.rooms

	bodyTags = msg.getElementsByTagName 'body'
	if bodyTags.length == 0
		subjectTags = msg.getElementsByTagName('subject')
		if subjectTags.length == 0
			return true
		subject = $('<div>').html(Strophe.getText(subjectTags[0])).text()
		if room of xmpp.rooms
			xmpp.rooms[room].subject = subject
		$(xmpp).triggerHandler 'subject',
			room: room
			subject: subject
			nick: Strophe.getResourceFromJid msg.getAttribute 'from'
		return true

	delayTags = msg.getElementsByTagName('delay')
	delay = if delayTags.length then delayTags[0].getAttribute('stamp') else false

	nick = Strophe.getResourceFromJid(msg.getAttribute 'from')
	type = msg.getAttribute 'type'
	if type is 'chat'
		$(xmpp).triggerHandler 'privateMessage',
			to: xmpp.rooms[room].nick
			nick: nick
			room: room
			text: $('<div>').html(Strophe.getText(bodyTags[0])).text()
			self: nick is xmpp.rooms[room].nick
		return true

	$(xmpp).triggerHandler 'groupMessage',
		to: msg.getAttribute 'to'
		nick: nick
		room: room
		text: $('<div>').html(Strophe.getText(bodyTags[0])).text()
		delay: delay
		self: nick is xmpp.rooms[room].nick

	true

xmpp.mucPresenceHandler = (p) ->

	room = Strophe.getBareJidFromJid p.getAttribute 'from'
	nick = Strophe.getResourceFromJid p.getAttribute 'from'

	return true if room not of xmpp.rooms

	type = p.getAttribute('type')
	statusElems = p.getElementsByTagName('status')
	statusCodes = (parseInt(s.getAttribute('code')) for s in statusElems)
	
	selfPresence = statusCodes.indexOf(110) >= 0

	if selfPresence and type isnt 'unavailable'
		xmpp.rooms[room].joined = true
		xmpp.rooms[room].nick = nick
	else if not xmpp.rooms[room].joined
		xmpp.rooms[room].roster.push nick
		console.log "InitJoined: #{nick}, Roster:", xmpp.rooms[room].roster.toString()
		return true

	if type is 'error'
		console.error p

	if type is 'unavailable'
		i = xmpp.rooms[room].roster.indexOf nick
		xmpp.rooms[room].roster.splice(i, 1) if i isnt -1

		if statusCodes.indexOf(307) >= 0
			reasonElems = p.getElementsByTagName('reason')
			if reasonElems.length > 0
				reason = Strophe.getText(reasonElems[0])
			$(xmpp).triggerHandler 'kicked',
				room: room
				nick: nick
				reason: reason or ""
				self: selfPresence
			delete xmpp.rooms[room] if xmpp.rooms[room].nick is nick

		else if statusCodes.indexOf(301) >= 0
			reasonElems = p.getElementsByTagName('reason')
			if reasonElems.length > 0
				reason = Strophe.getText(reasonElems[0])
			$(xmpp).triggerHandler 'banned',
				room: room
				nick: nick
				reason: reason or ""
				self: selfPresence
			delete xmpp.rooms[room] if xmpp.rooms[room].nick is nick

		else if statusCodes.indexOf(303) >= 0
			itemElem = p.getElementsByTagName('item')[0]
			newNick = itemElem.getAttribute('nick')
			$(xmpp).triggerHandler 'nickChange',
				room: room
				nick: nick
				newNick: newNick
				self: selfPresence

		else
			status = Strophe.getText(statusElems[0]) if statusElems.length > 0
			$(xmpp).triggerHandler 'parted',
				room: room
				nick: nick
				status: status or ""
				self: selfPresence
			delete xmpp.rooms[room] if xmpp.rooms[room].nick is nick


	else if xmpp.rooms[room].roster.indexOf(nick) is -1
		xmpp.rooms[room].roster.push nick
		$(xmpp).triggerHandler 'joined',
			room: room
			nick: nick
			self: selfPresence

	true

onConnect = (status) ->
	switch status
		when Strophe.Status.ERROR
			$(xmpp).triggerHandler 'error'
			console.error 'Strophe encountered an error.'

		when Strophe.Status.CONNECTING
			$(xmpp).triggerHandler 'connecting'
			console.log 'Strophe is connecting.'

		when Strophe.Status.CONNFAIL
			$(xmpp).triggerHandler 'connfail'
			console.error 'Strophe failed to connect.'

		when Strophe.Status.AUTHENTICATING
			$(xmpp).triggerHandler 'authenticating'
			console.log 'Strophe is authenticating.'

		when Strophe.Status.AUTHFAIL
			$(xmpp).triggerHandler 'authfail'
			console.error 'Strophe failed to authenticate.'

		when Strophe.Status.CONNECTED
			console.log 'Strophe is connected.'
			xmpp.conn.addHandler xmpp.messageHandlerProxy, null, 'message'
			xmpp.conn.addHandler xmpp.mucPresenceHandlerProxy, null, 'presence'
			xmpp.conn.send $pres().tree()
			$(xmpp).triggerHandler 'connected'

		when Strophe.Status.DISCONNECTED
			$(xmpp).triggerHandler 'disconnected'
			console.log 'Strophe is disconnected.'

		when Strophe.Status.DISCONNECTING
			$(xmpp).triggerHandler 'disconnecting'
			console.log 'Strophe is disconnecting.'

		when Strophe.Status.ATTACHED
			$(xmpp).triggerHandler 'attached'
			console.log 'Strophe attached the connection.'

	true

xmpp.connect = (id, passwd, service) ->
	if xmpp.conn and (xmpp.conn.connecting or xmpp.conn.connected)
		xmpp.conn.disconnect()

	service or = DEFAULT_BOSH_SERVICE
	xmpp.conn = new Strophe.Connection service

	id or= DEFAULT_USER
	id = Strophe.getBareJidFromJid(id) + '/' + RESOURCE
	passwd or= ''
	xmpp.conn.connect id, passwd, onConnect

	if localStorage and localStorage.getItem('xmpp-debug')
		xmpp.conn.rawInput = (data) ->
			console.debug "RECV: " + data
		xmpp.conn.rawOutput = (data) ->
			console.debug "SENT: " + data
