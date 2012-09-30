blaze.views ?= {}

blaze.views.HomeView = Backbone.View.extend

	el: '#content'

	initialize: (@docId, @callback) ->
		console.log "initializing home view" if blaze.debug
		@render()

	render: () ->
		myEl = @$el
		console.log "rendering home view" if blaze.debug
		$.fancybox.showLoading()
		request = $.ajax
			url: "http://content.dragonsblaze.com/json/" + @docId
			dataType: 'jsonp'
			jsonpCallback: -> "cb" + Date.now()

		request.done (data) =>
			myEl.html data.content
			console.log "home: painted HTML" if blaze.debug
			@callback?(null, data)
			return

		request.fail (err) =>
			console.error err
			myEl.html err
			@callback?(err)

		request.always ->
			$.fancybox.hideLoading()

		this

