module.exports = Backbone.View.extend

	el: '#content'

	initialize: (@docId, @callback) ->
		@render()

	render: () ->
		myEl = @$el
		$.fancybox.showLoading()
		request = $.ajax
			url: "http://content.dragonsblaze.com/json/" + @docId
			dataType: 'jsonp'
			jsonpCallback: -> "cb" + Date.now()

		request.done (data) =>
			myEl.html data.content
			@callback?(null, data)
			return

		request.fail (err) =>
			console.error err
			myEl.html err
			@callback?(err)

		request.always ->
			$.fancybox.hideLoading()

		this

