view = blaze.view
util = blaze.util
config = blaze.config or {}
messages = blaze.messages

delayed = (delay, func) ->
	setTimeout func, delay

config.ROOM = if blaze.debug then 'test@chat.eagull.net' else 'firemoth@chat.eagull.net'
NICK_LIST = ["Abra", "Charmander", "Jigglypuff", "Metapod", "Pikachu", "Psyduck", "Squirtle"]

messageView = {}
messageBin = {}
Message = blaze.models.Message

view.topic = (topic) ->
	if not topic and config.currentRoom of xmpp.rooms
		topic = xmpp.rooms[config.currentRoom].subject
	$('#topic').text topic or config.currentRoom
	$('#topicContainer').slideDown(-> $(window).resize())

joinRoom = (room, nick) ->
	if room not of messageBin
		messageBin[room] = new blaze.collections.Messages()
	if room not of xmpp.rooms
		messageBin[room].reset()
		xmpp.join room, nick or localStorage.getItem('nick') or NICK_LIST.random()
		$.fancybox.showLoading()
	else
		switchRoom room

switchRoom = (room) ->
	return if room not of xmpp.rooms
	$.fancybox.hideLoading()
	$('li.active').removeClass 'active'
	$(".btnRoom[x-jid='#{room}']").parent().addClass 'active'
	config.currentRoom = room
	messageView.setCollection(messageBin[room])
	view.topic()

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
		if config.currentRoom
			if xmpp.rooms[config.currentRoom].roster.indexOf(nick) isnt -1
				xmpp.send config.currentRoom + '/' + nick, message, type: 'chat'
				messageBin[config.currentRoom].add new Message
					type: 'private'
					text: message
					from: xmpp.rooms[config.currentRoom].nick
					to: nick
				track.event 'message', 'chat', 'out'
				return

	if config.currentRoom and config.currentRoom of xmpp.rooms
		xmpp.conn.muc.groupchat config.currentRoom, msg
	else
		messageView.postStatus blaze.messages.actionImpossible.random()

commands =
	help: ->
		commandList = []
		$.each commands, (i) ->
			commandList.push "/#{i}"
		messageView.postStatus "Commands: " + commandList.join(', ')
		true

	pm: ->
		messageView.postStatus "To PM someone, type @ followed by their nickname, then a space, then the message. Good luck!"
		true

	nick: (args) ->
		newNick = args.shift()
		if not newNick
			messageView.postStatus "Syntax: /nick {desired nickname}"
			return true
		if not config.currentRoom
			messageView.postStatus messages.actionImpossible.random()
			return true
		if not /^[a-zA-Z](\w)*$/.test(newNick)
			messageView.postStatus messages.invalidInput.random()
			return false
		if newNick.length > 20
			messageView.postStatus messages.invalidInput.random()
			return false
		else
			xmpp.conn.muc.changeNick config.currentRoom, newNick
		true

	users: ->
		if not config.currentRoom
			messageView.postStatus "You need to be in a room before you ask for the list of occupants."
		else
			messageView.postStatus "Users: " + xmpp.rooms[config.currentRoom].roster.join(', ')
		true

$ ->
	messageView = new blaze.views.MessageView()

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
			messageView.postStatus messages.resultUnavailable.random()
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

	$('.btnRoom[x-jid="DEFAULT"]').attr 'x-jid', config.ROOM

	$('.btnRoom').click (e) ->
		e.preventDefault()
		room = e.target.getAttribute 'x-jid'
		joinRoom room

	$('.dropdown-menu a').click -> $('.dropdown.open .dropdown-toggle').dropdown('toggle');

	$('.btnRoomContent').click (e) ->
		e.preventDefault()
		$('#leftPanel').switchClass('span12', 'span8', 500)
		delayed 510, ->
			$('#rightPanel').fadeIn()
		type = e.target.getAttribute('x-type')
		template = $('#content-' + type).html()
		$('#contentPanel').empty().append(template) if template

	$('#btnCollapseContent').click ->
		$('#rightPanel').fadeOut(500)
		delayed 510, ->
			$('#leftPanel').switchClass('span8', 'span12')

	$('#btnLogin').click ->
		view.lightbox $('#frmXmppConfig'),
			title: "XMPP Configuration"
			afterShow: -> $('#txtXmppId').focus()

	if typeof webkitNotifications is 'undefined' or not webkitNotifications
		$('.toggleNotifications').parent().remove()

	updateNotificationOption = ->
		if config.notifications
			$('.toggleNotifications').text 'disable notifications'
		else
			$('.toggleNotifications').text 'enable notifications'

	$('.toggleNotifications').click ->
		if not config.notifications
			config.notifications = view.requestNotificationPermission ->
				return if typeof webkitNotifications is 'undefined' or not webkitNotifications
				if webkitNotifications.checkPermission() is 0
					config.notifications = true
					updateNotificationOption()
		else
			config.notifications = false

		localStorage.setItem 'config-notifications', if config.notifications then '1' else ''
		updateNotificationOption()

	config.notifications = !!localStorage.getItem('config-notifications')
	updateNotificationOption()

	$(document).click 'a', (e) ->
		e.target.target = '_blank'

	$('form').submit (e) ->
		e.preventDefault()

	window.onbeforeunload = ->
		xmpp.conn.disconnect()
		return

	$(window).resize ->
		view.cache or= {}
		messagesTop = $('#leftPanel').offset().top
		view.cache.messageBoxHeight or= $('#messageBox').outerHeight()
		$leftPanel = $('#leftPanel')
		scrollBottom = $leftPanel.scrollTop()  + $leftPanel.height()
		$('.scrollPanel').height(window.innerHeight - messagesTop - view.cache.messageBoxHeight - 10)
		$leftPanel.scrollTop(scrollBottom - $leftPanel.height())
	$(window).resize()

	xmpp.connect $('#txtXmppId').val(), $('#txtXmppPasswd').val()

#	if not $('#txtNickname').val() then view.lightbox $('#frmNickname')

	$('#messageBox').focus()

$(xmpp).bind 'connecting error authenticating authfail connected connfail disconnecting disconnected', (event) ->
	track.event 'XMPP', event.type

$(xmpp).bind 'error authfail connfail disconnected', (event) ->
	messageView.postStatus "Connection Status: " + event.type
	view.status $('<button>').text("Reconnect").click ->
		messageView.empty()
		xmpp.connect $('#txtXmppId').val(), $('#txtXmppPasswd').val()

$(xmpp).bind 'connecting disconnecting', (event) ->
	messageView.postStatus event.type + "..."

$(xmpp).bind 'connected', (event) ->
	messageView.postStatus "Connected. Entering #{config.ROOM}"
	joinRoom config.ROOM

$(xmpp).bind 'subject', (event, data) ->
	if data.room is config.currentRoom
		view.topic data.subject

$(xmpp).bind 'groupMessage', (event, data) ->
	msg = $.trim(data.text)
	return if not msg

	messageBin[data.room].add new Message
		type: 'muc'
		text: msg
		from: data.nick
		timestamp: data.delay

	nick = xmpp.rooms[data.room].nick
	track.event 'message', 'groupchat', if data.nick is nick then 'out' else 'in'
	if config.notifications and not data.self and not data.delay
		if msg.toLowerCase().indexOf(nick.toLowerCase()) isnt -1
			view.notification
				title: "#{data.nick} (#{data.room})"
				body: msg
				force: data.room isnt config.currentRoom
				callback: -> switchRoom data.room
	true

$(xmpp).bind 'privateMessage', (event, data) ->
	msg = $.trim(data.text)
	return if not msg
	messageBin[data.room].add new Message
		type: 'private'
		text: msg
		from: data.nick
		to: data.to
		timestamp: data.delay
	if config.notifications
		view.notification
			title: "#{data.nick} (#{data.room})"
			body: msg
			force: data.room isnt config.currentRoom
			callback: -> switchRoom data.room
	track.event 'message', 'chat', 'in'

$(xmpp).bind 'joined', (event, data) ->
	if data.nick is xmpp.rooms[data.room].nick
		switchRoom data.room
	else
		messageBin[data.room].add new Message
			type: 'status'
			text: messages.joined.random().replace '{nick}', data.nick

$(xmpp).bind 'parted', (event, data) ->
	if data.self
		config.currentRoom = null
		msg = "You have left #{data.room}."
		msg += " (#{data.status})" if data.status
	else
		msg = messages.parted.random().replace '{nick}', data.nick
		msg += " (#{data.status})" if data.status

	messageBin[data.room].add new Message
		type: 'status'
		text: msg

$(xmpp).bind 'kicked', (event, data) ->
	if data.self
		config.currentRoom = null
		msg = messages.meKicked.random()
		msg += " (reason: #{data.reason})" if data.reason
	else
		msg = messages.userKicked.random().replace '{nick}', data.nick
		msg += " (reason: #{data.reason})" if data.reason

	messageBin[data.room].add new Message
		type: 'status'
		text: msg

	if data.self and config.notifications
		view.notification
			title: "Kicked out of #{data.room}"
			body: data.reason
			force: true
			callback: -> switchRoom data.room

$(xmpp).bind 'banned', (event, data) ->
	if data.self
		config.currentRoom = null
		msg = "You have been banned from this room."
		msg += " (reason: #{data.reason})" if data.reason
	else
		msg = "#{nick} has been banned from this room."
		msg += " (reason: #{data.reason})" if data.reason

	messageBin[data.room].add new Message
		type: 'status'
		text: msg

	if data.self and config.notifications
		view.notification
			title: "Banned from #{data.room}"
			body: data.reason
			force: true
			callback: -> switchRoom data.room

$(xmpp).bind 'nickChange', (event, data) ->
	if data.self
		localStorage.setItem('nick', data.newNick)
		messageBin[data.room].add new Message
			type: 'status'
			text: messages.meNickChanged.random().replace '{nick}', data.newNick
	else
		messageBin[data.room].add new Message
			type: 'status'
			text: messages.userNickChanged.random().replace('{nick}', data.nick).replace '{newNick}', data.newNick

