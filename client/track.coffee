window._gaq or = [];

window._gaq.push(['_setAccount', window.global.debug ? 'UA-21159963-7' : 'UA-21159963-8'], ['_trackPageview']);

module.exports =
	event: (args...) ->
		eventArr = $.merge ['_trackEvent'], args.slice(0, 3)
		window._gaq.push eventArr

