blaze = window.blaze or = {}

Array.prototype.random = () -> @[Math.floor((Math.random()*@length))];

blaze.util =
	randomInt: (a, b) ->
		b or= 0
		max = if a > b then a else b
		min = if a > b then b else a
		Math.floor (Math.random() * (max-min) + min)

	normalizeStr: (str) -> str.trim().replace(/\s{2,}/g, ' ').replace(/\./g, '').toLowerCase()

	linkify: (text) ->
		pattern = /(\b(https?):\/\/[-A-Z0-9+&@#\/%?=~_|!:,.;]*[-A-Z0-9+&@#\/%=~_|])/gim
		text.replace pattern, '<a href="$1">$1</a>'

	randomColor: (lightness = 255) ->
		getRandomInt = ->
			randomInt = blaze.util.randomInt(lightness).toString(16)
			if randomInt.length < 2
				randomInt = '0' + randomInt
			randomInt
		'#' + getRandomInt() + getRandomInt() + getRandomInt()

blaze.view =
	notification: (opts) ->
		return false if typeof webkitNotifications is 'undefined' or not webkitNotifications
		return false if webkitNotifications.checkPermission() isnt 0
		return false if document.hasFocus() and not opts.force
		notification = webkitNotifications.createNotification "/logo16.png", opts.title or "", opts.body or ""
		notification.onclick = ->
			window.focus()
			opts.callback() if typeof opts.callback is 'function'
			@cancel()
		notification.show()
		setTimeout (-> notification.cancel()), opts.timeout or 15000, notification

	requestNotificationPermission: (callback) ->
		return false if typeof webkitNotifications is 'undefined' or not webkitNotifications
		return true if webkitNotifications.checkPermission() is 0
		if webkitNotifications.checkPermission() is 1
			if typeof callback is 'function'
				webkitNotifications.requestPermission callback
			else
				webkitNotifications.requestPermission()
		return false

	lightbox: (content, opts) ->
		$.extend opts,
			closeBtn: false
			helpers:
				overlay:
					css:
						position: 'fixed'
						top: '0px'
						right: '0px'
						bottom: '0px'
						left: '0px'
		$.fancybox content, opts

