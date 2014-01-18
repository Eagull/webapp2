util = require './util'
messages = require './messages'
xmpp = require './xmpp'
track = require './track'
MessageBackbone = require './messageBackbone'
ContentView = require './contentView'
RosterView = require './rosterView'

Message = MessageBackbone.Model

debug = window.global.debug

config = {}
messageView = {}
messageBin = {}
rosterViews = {}

config.ROOM = if debug then 'test@chat.eagull.net' else 'firemoth@chat.eagull.net'
config.RESOURCE = "#{util.getClientTag()}-#{window.global.version}-#{util.getClientId()}-#{util.getSessionId()}"

if debug
	config.RESOURCE += "-dev"
	window.xmpp = xmpp
	window.config = config

setTopic = (topic) ->
	if not topic and config.currentRoom of xmpp.rooms
		topic = xmpp.rooms[config.currentRoom].subject
	if topic
		topic = util.linkify topic
	$('#topic').html topic or config.currentRoom
	$('#topicContainer').slideDown(-> $(window).resize())

showNicknameForm = (onSuccess) ->
	config.frmNickname ?= $('#frmNickname')
	util.lightbox config.frmNickname,
		modal: false
		closeBtn: true
		afterShow: ->
			$txtNick = $('#txtNickname')
			originalNick = $txtNick.val().trim()
			$('.btnSaveNickname').unbind()
			$('.btnSaveNickname').click ->
				nick = $txtNick.val().trim()
				if nick and /^[a-z0-9]+$/i.test(nick)
					onSuccess?(nick, originalNick isnt nick)
					$.fancybox.close()
				else
					$txtNick.val('').focus()
			$txtNick.focus()

checkNickAndJoinRoom = (room) ->
	$txtNick = $('#txtNickname')
	if $txtNick.val()
		nick = $txtNick.val().trim()
		if nick and /^[a-z0-9]+$/i.test(nick)
			console.log "Joining", room
			joinRoom room, nick
			return

	showNicknameForm (nick) ->
		console.log "Joining", room
		joinRoom room, nick

joinRoom = (room, nick = $('#txtNickname').val()) ->
	if room not of messageBin
		messageBin[room] = new MessageBackbone.Collection()
	if room not of xmpp.rooms or not xmpp.rooms[room].joined
		messageBin[room].reset()
		xmpp.join room, nick
		$.fancybox.showLoading()
	else
		switchRoom room

switchRoom = (room) ->
	return if room not of xmpp.rooms
	roster = rosterViews[room] ?= new RosterView(room)
	$('#roster').empty().append(roster.el)
	$.fancybox.hideLoading()
	$('li.active').removeClass 'active'
	$(".btnRoom[x-jid='#{room}']").parent().addClass 'active'
	config.currentRoom = room
	messageView.setCollection(messageBin[room])
	setTopic()
	$('#messageTypingBar').fadeIn()
	$('#messageBox').focus()

sendMessage = (msg) ->
	msg = $.trim msg
	return if not msg

	if msg[0] is '/'
		args = msg.substr(1).split(' ')
		commandName = args.shift()
		for cmd of commands
			if cmd.toLowerCase() is commandName.toLowerCase()
				command = commands[cmd]
				break
		if command
			track.event 'command', command, args.join ' '
			command.call(undefined, args)
			return

	if msg[0] is '@'
		nick = msg.substr(1).split(' ', 1)[0]
		if msg.indexOf(' ') is -1
			messageView.postStatus messages.invalidInput.random()
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
		track.event 'message', 'groupchat', 'out'
	else
		messageView.postStatus messages.actionImpossible.random()

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

	sendButton: ->
		$('#btnSend').fadeToggle()

appRouter = null

AppRouter = Backbone.Router.extend
	routes:
		'': 'home'
		'home': 'home'
		'room/:jid': 'room'
		':docKey':  'doc'
		'*path': 'home'

	home: ->
		config.currentRoom = null
		$('.messageView').fadeOut(-> $('.contentView').fadeIn())
		homeView = new ContentView window.global.docMap['home'], ->
			btn = $('<a>').addClass("btn btn-large btn-success btnRoom").text('Join the conversation!')
			homeView.$el.append btn.attr('href', '/room/' + config.ROOM)
			img = $('#homeImage').hide()
			if not img.length
				img = $('<img>').attr('src', '/logo.png').attr('id', 'homeImage')
				img.load -> img.fadeIn -> $(window).resize()
			homeView.$el.append img
			$(window).resize()

	room: (jid) ->
		$('.contentView').fadeOut -> $('.messageView').fadeIn -> $(window).resize()
		$ -> checkNickAndJoinRoom(jid)
		return true

	doc: (docKey) =>
		console.log "Routing to:", docKey
		if docKey not of window.global.docMap
			return @home()

		config.currentRoom = null
		$('.messageView').fadeOut(-> $('.contentView').fadeIn())
		new ContentView(window.global.docMap[docKey])

$ ->
	if $.browser.mozilla then document.body.style.fontSize = "14px"

	if $.browser.chrome and chrome.webstore and not chrome.app.isInstalled
		$('.btnChromeInstall').fadeIn()

$ ->
	messageView = new MessageBackbone.View()
	$('.messageView').hide()

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
		config.frmNickname ?= $('#frmNickname')
		showNicknameForm (nick) ->
			xmpp.conn.muc.changeNick(config.currentRoom, nick) if config.currentRoom

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
		util.lightbox $('#frmXmppConfig'),
			title: "XMPP Configuration"
			afterShow: -> $('#txtXmppId').focus()

$ ->
	if typeof webkitNotifications is 'undefined' or not webkitNotifications
		$('.toggleNotifications').parent().remove()

	updateNotificationOption = ->
		if config.notifications
			$('.toggleNotifications').text 'disable notifications'
		else
			$('.toggleNotifications').text 'enable notifications'

	$('.btnChromeInstall').click ->
		onSuccess = -> $('.btnChromeInstall').fadeOut()
		onFailure = (err) -> console.error err
		chrome.webstore.install(undefined, onSuccess, onFailure)

	$('.toggleNotifications').click ->
		if not config.notifications
			config.notifications = util.requestNotificationPermission ->
				if util.notificationHavePermission()
					config.notifications = true
					updateNotificationOption()
		else
			config.notifications = false

		localStorage.setItem 'config-notifications', if config.notifications then '1' else ''
		updateNotificationOption()

	notificationConfig = localStorage.getItem('config-notifications')
	if notificationConfig is null and util.notificationHavePermission()
		notificationConfig = true
	config.notifications = !!notificationConfig
	updateNotificationOption()

$ ->
	$(document).on 'click', 'a', (e) ->
		if e.target.host is document.location.host
			appRouter.navigate e.target.pathname,
				trigger: true
			e.preventDefault()
		else
			e.target.target = '_blank'

	$('form').submit (e) ->
		e.preventDefault()

	$('button, a').click (e) -> track.event 'ui', e.target.id or e.target.name, e.type

	window.onbeforeunload = ->
		xmpp.conn.disconnect()
		xmpp.conn.flush()
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

		track.event 'ui', 'window', 'resize', "#{window.innerHeight}x#{window.innerWidth}"

	$(window).resize()

	xmpp.connect $('#txtXmppId').val(), $('#txtXmppPasswd').val(), null, config.RESOURCE

$ ->
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
	messageView.append $('<button>').addClass("btn btn-large btn-warning").text("Reconnect").click ->
		messageView.empty()
		xmpp.connect $('#txtXmppId').val(), $('#txtXmppPasswd').val(), null, config.RESOURCE
		messageView.postStatus "Reconnecting..."

$(xmpp).bind 'subject', (event, data) ->
	messageBin[data.room].add new Message
		type: 'status'
		text: "Topic: #{data.subject} (set by #{data.nick})"
	if data.room is config.currentRoom
		setTopic data.subject

$(xmpp).bind 'presenceError', (event, data) ->
	util.lightbox "<h2>Error</h2><p>#{data.desc}</p>",
		afterClose: ->
			if data.changeNick then showNicknameForm (nick, changed) ->
				if changed
					joinRoom data.room
				else if data.goHome then appRouter.navigate '/', trigger: true
			else if data.goHome then appRouter.navigate '/', trigger: true

$(xmpp).bind 'groupMessage', (event, data) ->
	msg = $.trim(data.text)
	return if not msg

	messageBin[data.room].add new Message
		type: 'muc'
		text: msg
		from: data.nick
		timestamp: data.delay

	nick = xmpp.rooms[data.room].nick
	if not data.self and not data.delay
		track.event 'message', 'groupchat', 'in'
	if config.notifications and not data.self and not data.delay
		if msg.toLowerCase().indexOf(nick.toLowerCase()) isnt -1
			if msg.substr(0,4) is '/me ' then msg = "*#{msg.substr(4)}*"
			util.notification
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
		util.notification
			title: "#{data.nick} (#{data.room})"
			body: msg
			force: data.room isnt config.currentRoom
			callback: -> switchRoom data.room
	track.event 'message', 'chat', 'in'

$(xmpp).bind 'joined', (event, data) ->
	if data.self
		switchRoom data.room
		track.event 'XMPP', event.type, data.room, data.nick
	else
		messageBin[data.room].add new Message
			type: 'status'
			text: messages.joined.random().replace '{nick}', data.nick

$(xmpp).bind 'parted', (event, data) ->
	if data.self
		config.currentRoom = null
		msg = "You have left #{data.room}."
		msg += " (#{data.status})" if data.status
		track.event 'XMPP', event.type, data.room, data.nick
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
		track.event 'XMPP', event.type, data.room, data.nick
	else
		msg = messages.userKicked.random().replace '{nick}', data.nick
		msg += " (reason: #{data.reason})" if data.reason

	messageBin[data.room].add new Message
		type: 'status'
		text: msg

	if data.self and config.notifications
		util.notification
			title: "Kicked out of #{data.room}"
			body: data.reason
			force: true
			callback: -> switchRoom data.room

$(xmpp).bind 'banned', (event, data) ->
	if data.self
		config.currentRoom = null
		msg = "You have been banned from this room."
		msg += " (reason: #{data.reason})" if data.reason
		track.event 'XMPP', event.type, data.room, data.nick
	else
		msg = "#{data.nick} has been banned from this room."
		msg += " (reason: #{data.reason})" if data.reason

	messageBin[data.room].add new Message
		type: 'status'
		text: msg

	if data.self and config.notifications
		util.notification
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
		track.event 'XMPP', event.type, data.room, data.newNick
	else
		messageBin[data.room].add new Message
			type: 'status'
			text: messages.userNickChanged.random().replace('{nick}', data.nick).replace '{newNick}', data.newNick

