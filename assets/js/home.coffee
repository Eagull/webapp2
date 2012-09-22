blaze.views ?= {}
config = blaze.config ?= {}

INTRO_DOC = "1QxC1VCMlZbQrFYy8Ijr1XvyyYxpj8m9x4zuQgVu1G3w"

blaze.views.HomeView = Backbone.View.extend

	initialize: ->
		console.log "initializing home view" if blaze.debug
		@render()

	render: () ->
		myEl = @$el
		console.log "rendering home view" if blaze.debug
		$.fancybox.showLoading()
		request = $.ajax
			url: "http://content.dragonsblaze.com/json/" + INTRO_DOC
			dataType: 'jsonp'
			jsonpCallback: -> "cb" + Date.now()

		request.done (data) ->
			myEl.html data.content
			console.log "home: painted HTML" if blaze.debug

		request.fail (err) ->
			console.error err
			myEl.html err

		request.always ->
			$.fancybox.hideLoading()
			btn = $('<a>').addClass("btn btn-large btn-success btnRoom").text('Join the conversation!')
			myEl.append btn.attr('x-jid', config.ROOM).attr('href', '/room/' + config.ROOM)
			console.log "home: added button" if blaze.debug

		this

