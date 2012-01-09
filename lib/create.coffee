fs = require 'fs'

fn = (name)->	
	fs.mkdir "./#{name}", 0777, ->
		fs.mkdir "./#{name}/app", 0777, ->
			fs.mkdir "./#{name}/app/controllers", 0777, ->
				fs.writeFile "./#{name}/app/controllers/Main.coffee", "Main = \n\tindex: ->\n\t\t@.render 'main', 'index'\n\nmodule.exports = Main"
			fs.mkdir "./#{name}/app/views", 0777, ->
				fs.mkdir "./#{name}/app/views", 0777, ->
					fs.mkdir "./#{name}/app/views/main", 0777, ->
						fs.writeFile "./#{name}/app/views/main/index.html", '<b>Micro Framework for CoffeeScript</b>\n<ul>\n\t<li>application: ' + name + '</li>\n\t<li>baseUrl: <%= @attr(\'baseUrl\') or \'empty\' %></li>\n\t<li>url: <%= @url %></li>\n\t<li>controller: <%= @attr \'controller\' %></li>\n\t<li>action: <%= @attr \'action\'  %></li>\n\t<li>layout: <%= if ((layout = @attr \'layout\')) then @layout(layout) else \'null\' %></li>\n\t<li>view: <%= if (view = @attr \'view\').length then @view(view) else \'null\' %></li>\n\t<li>params:\n\t\t<ul>\n\t\t\t<% x = 0 %>\n\t\t\t<% for key, value of do @params: %>\n\t\t\t\t<% x++ %>\n\t\t\t\t<li><%= key %>: <%= value or \'empty\' %></li>\n\t\t\t<% end %>\n\t\t\t<% unless x: %>\n\t\t\t\t<li>empty</li>\n\t\t\t<% end %>\n\t\t</ul>\n\t</li>\n</ul>'
					fs.mkdir "./#{name}/app/views/layouts", 0777, ->
						fs.writeFile "./#{name}/app/views/layouts/main.html", "<html>\n\t<head>\n\t\t<title>#{name}</title>\n\t<head>\n\t<body>\n\t\t<%= do yield %>\n\t</body>\n</html>"
					fs.mkdir "./#{name}/app/config", 0777, ->
						fs.writeFile "./#{name}/app/config/config.coffee", "config = {\n\tbaseUrl: '' # The baseUrl must be set manually...\n}\n\nmodule.exports = config"
		fs.mkdir "./#{name}/public", 0777

exports.do = fn