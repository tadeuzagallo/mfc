Main = 
	test: ->
		tz.render 'testeee!'
	index: ->
		tz.render null, 'index', user: 'Tadeu'

module.exports = Main