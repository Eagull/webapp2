view = blaze.view
util = blaze.util
config = blaze.config or {}
messages = blaze.messages

delayed = (delay, func) ->
	setTimeout func, delay

config.ROOM = if blaze.debug then 'test@chat.eagull.net' else 'firemoth@chat.eagull.net'

config.nick = localStorage.getItem('nick') or 'Pikachu'

view.clearConsole = ->
	$('#messages').html ''

view.append = (obj) ->
	$('#messages').append obj

view.log = (msg, msgClass) ->
	divMsg = $('<div>').text msg
	divMsg.addClass msgClass if msgClass
	$('#messages').append divMsg
	$('#messages').scrollTop $('#messages').prop('scrollHeight') unless config.sticky

view.postMessage = (msg, nick) ->
	msg = util.linkify msg
	nick or= config.nick
	view.log "<#{nick}> #{msg}", 'muc'

view.postPrivateMessage = (msg, from, to) ->
	msg = util.linkify msg
	view.log "[#{from} -> #{to}] #{msg}", 'private'

view.postStatus = (msg) ->
	view.log msg, 'status'

view.image = (src, alt) ->
	alt or = ''
	img = $('<img>').attr('src', src).attr('alt', alt).attr('title', alt)
	$('#messages').append $('<div>').append img
	img.on 'load', -> $('#messages').scrollTop $('#messages').prop('scrollHeight')

sendMessage = (msg) ->
	msg = $.trim msg
	return if not msg

	if msg[0] is '/'
		args = msg.substr(1).split(' ')
		command = args.shift()
		if commands[command]
			track.event 'command', command, args.join ' '
			return if commands[command].call(undefined, args)

	if msg[0] is '@'
		nick = msg.substr(1).split(' ', 1)[0]
		message = msg.substr(msg.indexOf(' ')).trim()
		if config.joinedRoom
			if xmpp.rooms[config.joinedRoom].roster.indexOf(nick) isnt -1
				xmpp.send config.joinedRoom + '/' + nick, message, type: 'chat'
				view.postPrivateMessage message, config.nick, nick
				track.event 'message', 'chat', 'out'
				return

	if config.currentRoom and config.currentRoom of xmpp.rooms
		xmpp.conn.muc.groupchat config.joinedRoom, msg
	else
		view.postStatus blaze.messages.actionImpossible.random()

commands =
	help: ->
		commandList = []
		$.each commands, (i) ->
			commandList.push "/#{i}"
		view.postStatus "Commands: " + commandList.join(', ')
		true

	pm: ->
		view.postStatus "To PM someone, type @ followed by their nickname, then a space, then the message. Good luck!"
		true

	nick: (args) ->
		newNick = args.shift()
		if not newNick
			view.postStatus "Syntax: /nick {desired nickname}"
			return true
		if not config.joinedRoom
			view.postStatus messages.actionImpossible.random()
			return true
		if not /^[a-zA-Z](\w)*$/.test(newNick)
			view.postStatus messages.invalidInput.random()
			return false
		if newNick.length > 20
			view.postStatus messages.invalidInput.random()
			return false
		else
			xmpp.conn.muc.changeNick config.joinedRoom, newNick
		true

	users: ->
		if not config.joinedRoom
			view.postStatus "You need to be in a room before you ask for the list of occupants."
		else
			view.postStatus "Users: " + xmpp.rooms[config.joinedRoom].roster.join(', ')
		true

	history: ->
		if not config.history
			view.postStatus "I have nothing for you."
			return true
		while config.history.length > 0
			msg = config.history.shift()
			view.postMessage msg.text, msg.nick
		true

	xkcd: (args) ->
		num = args.shift()
		num = if num and not isNaN(num) then num else ''
		if config.xkcdlatest and num and num > config.xkcdlatest
			view.postStatus blaze.messages.invalidInput.random()
			return false
		url = 'http://dynamic.xkcd.com/api-0/jsonp/comic/' + num
		$.ajax
			url: url
			cache: true
			success: (data) ->
				view.postStatus "(#{data.num}) #{data.title}"
				view.image(data.img, data.alt)
				if not num
					config.xkcdlatest = data.num
			error: -> view.postStatus blaze.messages.resultUnavailable.random()
			dataType: 'jsonp'
			jsonpCallback: -> "cb" + Date.now()
		true

$ ->
	$("input.persistent, textarea.persistent").each (index, element) ->
		value = localStorage.getItem 'field-' + (element.name || element.id)
		element.value = value if value

	$("input.persistent, textarea.persistent").change (event) ->
		element = event.target
		if not element.validity.valid
			localStorage.setItem 'field-' + (element.name || element.id), ""
		else
			localStorage.setItem 'field-' + (element.name || element.id), element.value

	$('#messageBox').keydown (e) ->
		if e.which is 9
			e.preventDefault()
			view.postStatus messages.resultUnavailable.random()
		if e.which is 13
			e.preventDefault()
			sendMessage e.target.value, "Me"
			e.target.value = ""

	$('a.ajax').click (e) ->
		e.preventDefault()
		a = e.target
		doc = a.getAttribute('x-doc')
		url = if doc then "http://content.dragonsblaze.com/json/#{doc}" else a.href
		$.fancybox.showLoading()
		$.ajax
			url: url
			success: (data) -> view.lightbox data.content
			error: (err) ->
				console.error err
				view.lightbox err
			dataType: 'jsonp'
			jsonpCallback: -> "cb" + Date.now()

	$('.btnRoom').click (e) ->
		e.preventDefault()
		$('.btnRoom').removeClass 'selected'
		$(e.target).addClass 'selected'
		room = e.target.getAttribute 'x-jid'
		if not room then room = config.ROOM
		if room not of xmpp.rooms then xmpp.join room, config.nick
		config.currentRoom = room

	$('.btnRoomContent').click (e) ->
		e.preventDefault()
		$('.btnRoomContent').removeClass 'green'
		$(e.target).addClass 'green'
		type = e.target.getAttribute('x-type')
		template = $('#content-' + type).html()
		$('#roomContent').empty().append(template) if template

	$('#btnLogin').click ->
		view.lightbox $('#frmXmppConfig'),
			title: "XMPP Configuration"
			afterShow: -> $('#txtXmppId').focus()

	$(document).click 'a', (e) ->
		e.target.target = '_blank'

	$('form').submit (e) ->
		e.preventDefault()

	window.onbeforeunload = ->
		xmpp.conn.disconnect()
		return

	$(window).resize ->
		view.cache or= {}
		view.cache.messagesTop or= $('#messages').offset().top
		view.cache.messageBoxHeight or= $('#messageBox').outerHeight()
		$('.scrollPanel').height(window.innerHeight - view.cache.messagesTop - view.cache.messageBoxHeight - 5)
	$(window).resize()

	repositionCycleButton = ->
		$('#btnCycleSize').css
			left: $('#messages').offset().left + $('#messages').outerWidth() + 1
			top: $('#messages').offset().top

	repositionCycleButton()
	config.viewMode = 0

	$('#btnCycleSize').click ->
		$('#btnCycleSize').hide()
		delayed 700, ->
			repositionCycleButton()
			$('#btnCycleSize').fadeIn()

		if config.viewMode is 0
			$('#rightPanel').switchClass('six', 'four', 500)
			delayed 10, ->
				$('#leftPanel').switchClass('six', 'eight', 500)
			$('#btnCycleSize').text '<'
			config.viewMode++
		else
			$('#leftPanel').switchClass 'eight', 'six', 500
			delayed 10, ->
				$('#rightPanel').switchClass 'four', 'six', 500
			$('#btnCycleSize').text '>'
			config.viewMode = 0

	xmpp.connect $('#txtXmppId').val(), $('#txtXmppPasswd').val()

#	if not $('#txtNickname').val() then view.lightbox $('#frmNickname')

	$('#messageBox').focus()

$(xmpp).bind 'connecting error authenticating authfail connected connfail disconnecting disconnected', (event) ->
	track.event 'XMPP', event.type

$(xmpp).bind 'error authfail connfail disconnected', (event) ->
	view.postStatus "Connection Status: " + event.type
	view.append $('<button>').text("Reconnect").click ->
		view.clearConsole()
		xmpp.connect $('#txtXmppId').val(), $('#txtXmppPasswd').val()

$(xmpp).bind 'connecting disconnecting', (event) ->
	view.postStatus event.type + "..."

$(xmpp).bind 'connected', (event) ->
	view.clearConsole()
	view.postStatus "Connected to the chat server. Please join one of our awesome rooms."

$(xmpp).bind 'groupMessage', (event, data) ->
	msg = $.trim(data.text)
	return if not msg
	config.history or = []
	config.history.push data
	if config.history.length > 10
		config.history.shift()

	view.postMessage msg, data.nick
	
	track.event 'message', 'groupchat', if data.nick is config.nick then 'out' else 'in'
	if data.nick isnt config.nick and msg.toLowerCase().indexOf(config.nick.toLowerCase()) isnt -1
		view.notification
			title: data.nick
			body: msg
	true

$(xmpp).bind 'privateMessage', (event, data) ->
	msg = $.trim(data.text)
	return if not msg
	view.postPrivateMessage msg, data.nick, config.nick
	view.notification
		title: data.nick
		body: msg
	track.event 'message', 'chat', 'in'

$(xmpp).bind 'joined', (event, data) ->
	if data.nick is config.nick
		config.joinedRoom = data.room
	else
		view.postStatus messages.joined.random().replace '{nick}', data.nick

$(xmpp).bind 'parted', (event, data) ->
	return if config.joinedRoom isnt data.room
	if data.nick is config.nick
		delete config.joinedRoom
	else
		view.postStatus messages.parted.random().replace '{nick}', data.nick

$(xmpp).bind 'kicked', (event, data) ->
	if data.nick is config.nick
		delete config.joinedRoom
		msg = messages.meKicked.random()
		msg += " (reason: #{data.reason})" if data.reason
		view.postStatus msg
	else
		msg = messages.userKicked.random().replace '{nick}', data.nick
		msg += " (reason: #{data.reason})" if data.reason
		view.postStatus msg

$(xmpp).bind 'nickChange', (event, data) ->
	if data.nick is config.nick
		config.nick = data.newNick
		localStorage.setItem('nick', data.newNick)
		view.postStatus messages.meNickChanged.random().replace '{nick}', data.newNick
	else
		view.postStatus messages.userNickChanged.random().replace('{nick}', data.nick).replace '{newNick}', data.newNick

