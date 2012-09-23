blaze.views ?= {}

blaze.models.User = Backbone.Model.extend
	defaults:
		nick: ''
		room: ''
		fullJid: ''
		role: ''
		affiliation: ''

blaze.collections.Users = Backbone.Collection.extend
	Model: blaze.models.Users
	url: "#"

blaze.views.RosterView = Backbone.View.extend
	tagName: 'ul'

	className: 'roster'

	room: ''

	initialize: (room) ->
		self = this
		@room = room
		@render()

		$(xmpp).bind 'joined', (event, data) ->
			if data.room is room
				self.$el.append $('<li>').text(data.nick).attr('x-nick', data.nick)

		$(xmpp).bind 'parted kicked banned nickChange', (event, data) ->
			self.$el.find("[x-nick='#{data.nick}']").remove()

	render: ->
		@$el.empty()
		for nick in xmpp.rooms[@room].roster
			@$el.append $('<li>').text(nick).attr('x-nick', nick)
		this

