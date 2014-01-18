module.exports = xmpp = {}

DEFAULT_BOSH_SERVICE = 'http://xmpp.eagull.net:5280/http-bind'
DEFAULT_USER = 'anon.eagull.net'

xmpp.rooms = {}
joinQueue = {}

xmpp.send = (to, msg, attr) ->
	attr = attr or {}
	attr.to = to
	attr.type = attr.type or 'groupchat'
	xmpp.conn.send($msg(attr).c('body', null, msg))

xmpp.join = (jid, nick) ->
	if not xmpp.conn.connected
		joinQueue[jid] = nick: nick
		return
	xmpp.conn.send $pres({from: xmpp.conn.jid, to: jid + '/' + nick}).c('x', {xmlns: Strophe.NS.MUC })
	xmpp.rooms[jid] =
		nick: nick
		roster: []

$(xmpp).bind 'connected', ->
	if not xmpp.conn.connected
		return console.error "XMPP 'connected' triggered while `xmpp.conn.connected` is false"

	for jid, room of xmpp.rooms
		if not room.joined
			joinQueue[jid] = nick: room.nick

	xmpp.join jid, room.nick for jid, room of joinQueue
	joinQueue = {}

$(xmpp).bind 'error connfail disconnected', -> room.joined = false for jid, room of xmpp.rooms

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
		subject = Strophe.getText(subjectTags[0])
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
			text: Strophe.getText(bodyTags[0])
			self: nick is xmpp.rooms[room].nick
		return true

	$(xmpp).triggerHandler 'groupMessage',
		to: msg.getAttribute 'to'
		nick: nick
		room: room
		text: Strophe.getText(bodyTags[0])
		delay: delay
		self: nick is xmpp.rooms[room].nick

	true

xmpp.mucPresenceHandler = (p) ->

	room = Strophe.getBareJidFromJid p.getAttribute 'from'
	nick = Strophe.getResourceFromJid p.getAttribute 'from'
	type = p.getAttribute('type')

	if type is 'error'
		errorElem = p.getElementsByTagName('error')[0]
		errorType = errorElem.childNodes[0].nodeName
		desc = "An unexpected error has occured. Please try again or contact support@eagull.net."
		changeNick = false
		goHome = true
		if not xmpp.rooms[room]?.joined then switch errorType
			when 'not-authorized'
				desc = "This room requires a password. Try using an XMPP client to join it."
			when 'forbidden'
				desc = "You are banned from this room."
			when 'item-not-found'
				desc = "The room does not exist."
			when 'not-allowed'
				desc = "Room creation is restricted."
			when 'not-acceptable'
				desc = "The reserved nickname must be used."
				changeNick = true
				goHome = false
			when 'registration-required'
				desc = "You are not on the member list."
			when 'conflict'
				desc = "Your desired nickname is in use or registered by another user."
				changeNick = true
			when 'service-unavailable'
				desc = "Manimum number of users has been reached for this room."
		else switch errorType
			when 'forbidden'
				desc = "Whatever you just tried is not allowed. Please try something else."
				goHome = false
			when 'conflict'
				desc = "Your desired nickname is in use or registered by another user."
				goHome = false

		$(xmpp).triggerHandler 'presenceError',
			room: room
			code: errorElem.getAttribute('code')
			type: errorType
			desc: desc
			goHome: goHome
			changeNick: changeNick

		return

	return true if room not of xmpp.rooms

	statusElems = p.getElementsByTagName('status')
	statusCodes = (parseInt(s.getAttribute('code')) for s in statusElems)

	selfPresence = statusCodes.indexOf(110) >= 0

	if selfPresence and type isnt 'unavailable'
		xmpp.rooms[room].joined = true
		xmpp.rooms[room].nick = nick
	else if not xmpp.rooms[room].joined
		xmpp.rooms[room].roster.push nick
		return true

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
				self: nick is xmpp.rooms[room].nick
			delete xmpp.rooms[room] if xmpp.rooms[room].nick is nick

		else if statusCodes.indexOf(301) >= 0
			reasonElems = p.getElementsByTagName('reason')
			if reasonElems.length > 0
				reason = Strophe.getText(reasonElems[0])
			$(xmpp).triggerHandler 'banned',
				room: room
				nick: nick
				reason: reason or ""
				self: nick is xmpp.rooms[room].nick
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

xmpp.connect = (id, passwd, service, resource = "webapp2-#{parseInt(Date.now()/1000)}") ->
	if xmpp.conn and (xmpp.conn.connecting or xmpp.conn.connected)
		xmpp.conn.disconnect()

	service or = DEFAULT_BOSH_SERVICE
	xmpp.conn = new Strophe.Connection service

	id or= DEFAULT_USER
	id = Strophe.getBareJidFromJid(id) + '/' + resource
	passwd or= ''
	xmpp.conn.connect id, passwd, onConnect

	if localStorage and localStorage.getItem('xmpp-debug')
		xmpp.conn.rawInput = (data) ->
			console.debug "RECV: " + data
		xmpp.conn.rawOutput = (data) ->
			console.debug "SENT: " + data

