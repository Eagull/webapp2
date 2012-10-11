window._gaq or = [];

account = if window.global.debug then 'UA-21159963-7' else 'UA-21159963-8'
window._gaq.push(['_setAccount', account], ['_trackPageview']);

module.exports =
	event: (args...) ->
		eventArr = $.merge ['_trackEvent'], args.slice(0, 3)
		window._gaq.push eventArr

