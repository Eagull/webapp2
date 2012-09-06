blaze.models = {}
blaze.collections = {}
blaze.views = {}

blaze.models.Message = Backbone.Model.extend
	defaults:
		type: 'muc'
		text: ''
		from: ''
		to: ''

blaze.collections.Messages = Backbone.Collection.extend
	Model: blaze.models.Message
	url: "#"

blaze.views.MessageView = Backbone.View.extend
	el: '#messages'

	tpl: {}

	initialize: ->
		@tpl.message = $('#tplMessage').html();
		@tpl.privateMessage = $('#tplPrivateMessage').html();
		@tpl.action = $('#tplAction').html();
		@$leftPanel = @$el.parent()
		@nickColorMap = {}
		@render() if @collection
		this

	setCollection: (collection) ->
		@collection.off('add', this.post, this) if @collection
		@collection = collection
		@collection.on 'add', this.post, this
		@render()

	render: () ->
		@$el.empty()
		console.log "cleared message view" if blaze.debug
		# TODO: don't scroll too often in append() when calling it several times
		@collection.forEach ((message) -> @post message), this
		console.log "loaded message collection" if blaze.debug
		this

	empty: ->
		@$el.empty()
		this

	append: (msg, msgClass) ->
		divMsg = $('<div>')
		if typeof msg is 'string'
			divMsg.text msg
		else
			divMsg.append msg
		divMsg.addClass msgClass if msgClass
		# auto-scroll if panel is scrolled up by up to SCROLL_MARGIN pixels
		SCROLL_MARGIN = 100
		doScroll = (@$leftPanel.prop('scrollHeight') - @$leftPanel.scrollTop() - @$leftPanel.height() < SCROLL_MARGIN)
		@$el.append divMsg
		@$leftPanel.scrollTop(@$leftPanel.prop('scrollHeight')) if doScroll
		this

	post: (message) ->
		msgObj = message.toJSON()
		switch msgObj.type
			when 'muc'
				@postMucMessage msgObj.text, msgObj.from, msgObj.timestamp
			when 'private'
				@postPrivateMessage msgObj.text, msgObj.from, msgObj.to, msgObj.timestamp
			when 'status'
				@postStatus msgObj.text
			else
				console.error "Invalid type, message:", msgObj
		this

	postMucMessage: (msgText, nick, timestamp) ->
		msgText = msgText.trim()
		return if not msgText
		
		if msgText.substr(0,4) is '/me '
			msgText = msgText.substr(4)
			message = $('<span>').html @tpl.action
		else
			message = $('<span>').html @tpl.message
		if nick not of @nickColorMap
			@nickColorMap[nick] = blaze.util.randomColor(192)
		$('.nick', message).text(nick).css('color', @nickColorMap[nick])
		$('.message', message).html blaze.util.linkify msgText

		date = if timestamp then new Date(timestamp) else new Date()
		timeElem = $('.timestamp', message).attr
			title: date.toLocaleTimeString()
			datetime: date.toISOString()
		timeElem.timeago()

		@append message, 'muc'
		this

	postPrivateMessage: (msgText, nickFrom, nickTo, timestamp) ->
		message = $('<span>').html @tpl.privateMessage
		if nickFrom not of @nickColorMap
			@nickColorMap[nickFrom] = blaze.util.randomColor(192)
		if nickTo not of @nickColorMap
			@nickColorMap[nickTo] = blaze.util.randomColor(192)

		$('.nickFrom', message).text(nickFrom).css('color', @nickColorMap[nickFrom])
		$('.nickTo', message).text(nickTo).css('color', @nickColorMap[nickTo])
		$('.message', message).html blaze.util.linkify msgText

		date = if timestamp then new Date(timestamp) else new Date()
		timeElem = $('.timestamp', message).attr
			title: date.toLocaleTimeString()
			datetime: date.toISOString()
		timeElem.timeago()

		@append message, 'muc'
		this

	postStatus: (msg) ->
		msgEl = $('<span>').html msg
		msgEl.attr 'title', new Date().toLocaleTimeString()
		@append msgEl, 'status'
		this

