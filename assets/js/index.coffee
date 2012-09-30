view = blaze.view
util = blaze.util
config = blaze.config ?= {}
messages = blaze.messages

delayed = (delay, func) ->
	setTimeout func, delay

config.ROOM = if blaze.debug then 'test@chat.eagull.net' else 'firemoth@chat.eagull.net'

messageView = {}
messageBin = {}
rosterViews = {}
Message = blaze.models.Message

view.topic = (topic) ->
	if not topic and config.currentRoom of xmpp.rooms
		topic = xmpp.rooms[config.currentRoom].subject
	$('#topic').text topic or config.currentRoom
	$('#topicContainer').slideDown(-> $(window).resize())

checkNickAndJoinRoom = (room) ->
	$txtNick = $('#txtNickname')
	if $txtNick.val()
		nick = $txtNick.val().trim()
		if nick and /^[a-z0-9]+$/i.test(nick)
			console.log "Joining", room
			joinRoom room, nick
			return

	view.lightbox $('#frmNickname'),
		afterShow: ->
			$('.btnSaveNickname').unbind()
			$('.btnSaveNickname').click ->
				nick = $txtNick.val().trim()
				if nick and /^[a-z0-9]+$/i.test(nick)
					console.log "Joining", room
					joinRoom room, nick
					$.fancybox.close()
				else
					$txtNick.val('').focus()
			$txtNick.focus()

joinRoom = (room, nick) ->
	if room not of messageBin
		messageBin[room] = new blaze.collections.Messages()
	if room not of xmpp.rooms
		messageBin[room].reset()
		xmpp.join room, nick
		$.fancybox.showLoading()
	else
		switchRoom room

switchRoom = (room) ->
	return if room not of xmpp.rooms
	roster = rosterViews[room] ?= new blaze.views.RosterView(room)
	$('#roster').empty().append(roster.el)
	$.fancybox.hideLoading()
	$('li.active').removeClass 'active'
	$(".btnRoom[x-jid='#{room}']").parent().addClass 'active'
	config.currentRoom = room
	messageView.setCollection(messageBin[room])
	view.topic()
	$('#messageTypingBar').fadeIn()
	$('#messageBox').focus()

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
		if msg.indexOf(' ') is -1
			messageView.postStatus blaze.messages.invalidInput.random()
			return
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

tabComplete = (word) ->
	if not config.currentRoom of xmpp.rooms then return
	roster = xmpp.rooms[config.currentRoom].roster
	if not $.isArray roster then return
	word = word.toLowerCase()

	if word.indexOf('@') is 0
		word = word.substr(1)

	if word.indexOf('/') is 0
		matches = []
		word = word.substr(1)
		$.each commands, (command) ->
			if command.indexOf(word) is 0 then matches.push command
	else
		matches = roster.filter (nick, i) -> nick.toLowerCase().indexOf(word) is 0

	if matches.length is 1
		return matches[0].substr(word.length)
	else if matches.length > 1
		messageView.postStatus "Possible matches: " + matches.join(', ')
	else
		messageView.postStatus messages.actionImpossible.random()
	return false

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
			$('#txtNickname').val(newNick).change()
			messageView.postStatus messages.actionImpossible.random()
			return true
		if not /^[a-z][a-z0-9]*$/i.test(newNick)
			messageView.postStatus messages.invalidInput.random()
			return false
		if newNick.length > 20
			messageView.postStatus messages.invalidInput.random()
			return false
		else
			xmpp.conn.muc.changeNick config.currentRoom, newNick
			$('#txtNickname').val(newNick).change()
		true

	users: ->
		if not config.currentRoom
			messageView.postStatus "You need to be in a room before you ask for the list of occupants."
		else
			messageView.postStatus "Users: " + xmpp.rooms[config.currentRoom].roster.join(', ')
		true

AppRouter = Backbone.Router.extend
	routes:
		'': 'home'
		'room/:jid': 'room'
		'usage': 'usage'
		'*path':  'home'

	home: ->
		config.currentRoom = null
		$('.messageView').fadeOut(-> $('.contentView').fadeIn())
		homeView = new blaze.views.HomeView "1QxC1VCMlZbQrFYy8Ijr1XvyyYxpj8m9x4zuQgVu1G3w", ->
			btn = $('<a>').addClass("btn btn-large btn-success btnRoom").text('Join the conversation!')
			homeView.$el.append btn.attr('href', '/room/' + config.ROOM)
			img = $('#homeImage').hide()
			if not img.length
				img = $('<img>').attr('src', '/logo.png').attr('id', 'homeImage')
				img.load -> img.fadeIn -> $(window).resize()
			homeView.$el.append img
			$(window).resize()

	usage: ->
		config.currentRoom = null
		$('.messageView').fadeOut(-> $('.contentView').fadeIn())
		usageView = new blaze.views.HomeView("1Faa0akTtbOgC2k6RRjl_xRamsAYJwzFgzJb6GJ0nb80")

	room: (jid) ->
		$('.contentView').fadeOut -> $('.messageView').fadeIn -> $(window).resize()
		checkNickAndJoinRoom(jid)
		return true

$ ->
	messageView = new blaze.views.MessageView()

	$('.messageView').hide()

	if $.browser.mozilla then document.body.style.fontSize = "14px"

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
			text = e.target.value
			lastWord = text.substr(text.lastIndexOf(' ') + 1)
			result = tabComplete(lastWord, text)
			e.target.value += result if result
			if result isnt false
				if text.indexOf(' ') is -1 and text.indexOf('/') isnt 0 and text.indexOf('@') isnt 0
					e.target.value += ': '
				else
					e.target.value += ' '
		if e.which is 13
			e.preventDefault()
			sendMessage e.target.value
			e.target.value = ""

	$('#btnSend').click ->
		$msgBox = $('#messageBox')
		sendMessage $msgBox.val()
		$msgBox.val ''
		$msgBox.focus()

	$('.dropdown-menu a').click -> $('.dropdown.open .dropdown-toggle').dropdown('toggle');

	$('a.changeNickname').click ->
		view.lightbox $('#frmNickname'),
			afterShow: ->
				$txtNick = $('#txtNickname')
				$('.btnSaveNickname').unbind()
				$('.btnSaveNickname').click ->
					nick = $txtNick.val().trim()
					if nick and /^[a-z0-9]+$/i.test(nick)
						xmpp.conn.muc.changeNick(config.currentRoom, nick) if config.currentRoom
						$.fancybox.close()
					else
						$txtNick.val('').focus()
				$txtNick.focus()

	$('.btnRoomContent').click (e) ->
		e.preventDefault()
		$('#leftPanel').switchClass('span12', 'span8', 500)
		delayed 510, ->
			$('#rightPanel').fadeIn()
		type = e.target.getAttribute('x-type')
		switch type
			when 'roster'
				if config.currentRoom of rosterViews
					$('#contentPanel #roster').empty().append(rosterViews[config.currentRoom].el)
				else
					$('#contentPanel #roster').text('Join a room!')
		true

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

	$(document).on 'click', 'a', (e) ->
		if e.target.host is document.location.host
			appRouter.navigate e.target.pathname,
				trigger: true
			e.preventDefault()
		else
			e.target.target = '_blank'

	$('form').submit (e) ->
		e.preventDefault()

	window.onbeforeunload = ->
		xmpp.conn.disconnect()
		return

	$(window).resize ->

		if $('.messageView').is(':visible')
			$leftPanel = $('#leftPanel')
			messagesTop = $leftPanel.offset().top
			if $('#messageTypingBar').css('display') is 'none'
				messageBoxHeight = 0
			else
				messageBoxHeight = $('#messageBox').outerHeight()
			scrollBottom = $leftPanel.scrollTop()  + $leftPanel.height()
			$('.scrollPanel').height(window.innerHeight - messagesTop - messageBoxHeight - 10)
			$leftPanel.scrollTop(scrollBottom - $leftPanel.height())

		if $('#homeImage').is(':visible')
			height = window.innerHeight - $('#content').position().top - $('#content').height()
			$('#homeImage').animate
				height: height

	$(window).resize()

	xmpp.connect $('#txtXmppId').val(), $('#txtXmppPasswd').val()

	appRouter = new AppRouter();
	Backbone.history.start
		pushState: true

$(xmpp).bind 'connecting error authenticating authfail connected connfail disconnecting disconnected', (event) ->
	track.event 'XMPP', event.type
	console.log "XMPP:", event.type

$(xmpp).bind 'error authfail connfail disconnected', (event) ->
	switch event.type
		when 'error'
			messageView.postStatus "A connection error has occured. Please try again."
		when 'authfail'
			messageView.postStatus "Authentication has failed. Please check your username and password."
		when 'connfail'
			messageView.postStatus "Connection has failed. Please try again."
		when 'disconnected'
			messageView.postStatus "Disconnected from the server."
	view.status $('<button>').text("Reconnect").click ->
		messageView.empty()
		xmpp.connect $('#txtXmppId').val(), $('#txtXmppPasswd').val()

$(xmpp).bind 'subject', (event, data) ->
	messageBin[data.room].add new Message
		type: 'status'
		text: "Topic: #{data.subject} (set by #{data.nick})"
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
			if msg.substr(0,4) is '/me ' then msg = "*#{msg.substr(4)}*"
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

