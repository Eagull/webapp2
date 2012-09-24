blaze.views ?= {}
config = blaze.config ?= {}

blaze.views.HomeView = Backbone.View.extend

	initialize: (docId) ->
		console.log "initializing home view" if blaze.debug
		@render(docId)

	render: (docId) ->
		myEl = @$el
		console.log "rendering home view" if blaze.debug
		$.fancybox.showLoading()
		request = $.ajax
			url: "http://content.dragonsblaze.com/json/" + docId
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

		this

