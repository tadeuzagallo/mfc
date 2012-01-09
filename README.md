#MFC - Micro Framework for CoffeeScript#

		$ git clone git@github.com:tadeuzagallo/mfc
		$ cd mfc
		$ sudo ./install.sh

		# To create a new application
		
	  	$ mfc app example

		# Tu run the server on port 4000 is just you execute the mfc on the project root folder
		
	  	$ cd example
		$ mfc

##Http ServerResponse Prototype Added##

###Class###

- **\_\_Session**: Every instance of http.ServerResponse receives one instance of this class

###Methods###

- **params ([Key, Value, Override, Default(value|expressionToEvaluate)])**: With no arguments returns all params setted by post and get, with just a key, search the stored params for that key, with key and value set one new parameter.
- **attr(Key, [Value, Override, Default])**: Same arguments of params, but on this you cannot get all the attrs. Properties set on the config file should be retrieved through this method.
- **render (LayoutName, ViewName, [Params])**: render one view file inside the specified layout. LayoutName is mandatory, but might be set as null to render just the view file.
- **template (Context, [Params])**: Implements a template system to the rendered files. the tags are '<%' for evaluate, '<%=' to print and '<%#' to comments, the expression should be written in coffee-script. also provide an "html" tag, coffee, that compiles the script inside and sends to browser. 
	Obs: At this moment multiline scripts are not supported, suggestions about how to fix it are welcome!
- **_404 ([ErrorObject])**: Closes the socket with Page Not Found. if debug is on, an ErrorObject is passed and it has an stack property prints the stack.
- **_500 ([ErrorObject])**: Exactly the same as 404, but on this one, obviously, the error page says Internal Server Error. same process with the ErrorObject.
- **writeCode (code, [ContentType])**: The default Content-Type is 'text/html'. this function should be used instead of writeHead defaults function, because checks the session, cookies and other headers before call the writeHead
- **createUrl(JsonObject)**: The object passed must have either type or controller set, otherwise the baseUrl will be returned.
- **redirect (Url)**: if the Url is an object, makes the url with the createUrl method (above). If Url is an string redirects to the page.
- **init (ServerRequest)**: initialize some ServerResponse properties.
- **__set_post (ServerRequest)**: *Internal use only*. Checks for posted data and process it.
- **match ()**: Checks what is the url pointing for, if its static file or a controller reference. Shows 404 page on any error.
- **route ()**: This method is called when the url points to an controller, find the controller and executes initialize, beforeAction and the action requested, on this order. the beforeAction property may be changed on the config file, and the controller might not have initialize and beforeAction,
they are just called if the controller has them.
- **handleStatic ()**: Serve static files.

###Properties###

- **_attr**: *Internal use only*. Stores the properties set by the attr method. In case of the property is undefined, tries on the default properties.
- **_params**: *Internal use only*. Stores the properties set by the params method and the GET and POST variables.
- **url**: The url requested.
- **method**: The request method, it is always uppercase.
- **headers**: Headers sent by the client.
- **session**: Instance of __Session (properties and methods will be listed below).

##class __Session##

###Class###

- **Cookie**: Every cookie set by session is one instance of this class

###Methods###

- **constructor (Cookies)**: Receive and stores the cookies sent by the client.
- **_generate_id ()**: *Internal use only*. Generates the session.id
- **start ()**: Initiate the session to that request. This method is not called by default, should be called before do anything with the session instance.
- **_parse (Data, [Separator, Options])**: *Internal use only*. Create the new cookies provided by the string.
- **set (Key, Value, [Options])**: Create or update cookie. It can stores the data as browser's cookie or session's cookie, depending on the options (the options will be listed below). The cookies will be found after by this Key.
- **rm (Key)**: Erase the cookie.
- **get (Key)**: Returns the cookie that has the Key.
- **output ()**: *Internal use only*. Returns the cookies that should be sent as an array of strings.
- **save ()**: *Internal use only*. Save the session's cookie to the file.

##class Cookie##

###Methods###

- **constructor (Key, Value, [Options])**: Create a new cookie where Key=Value. The options available are:
	- **expires**: Date timestamp to the expire date of the cookie.
	- **domain**: Domain where the cookie is valid.
	- **path**: Path where the cookie is valid.
	- **type**: 'session' or 'browser'. session save the cookie, but does not send it, browser does the opposite.
	- **send**: Boolean to send or not the cookie to the browser.
	- **save**: Boolean to save or not the cookie to session file.
- **toString ()**: Returns the cookie as a string with all properties set.

###Properties###

The mandatory properties are Key and Value, but any other property set on the Options object will be stored on the instance. The properties that will be used by the engine are listed above, under the construction method.

##Object TZ##

###Methods###

- **_get (Object, Key, [Value, Override, Default])**: *Internal use only*. Used by the functions params and attr. You DO NOT need to call this method directly.
- **attr (name)**: *Internal use only*. It is just used outside of the request, just can access the defaultOptions. You SHOULD NOT call this method as well, The attr method should called from an ServerResponse instance, and just inside the request. Everything that you think you need set outside of the request, or on the global scope should bu put on the config file.
- **view (ViewName)**: Finds the path to ViewName.
- **layout (LayoutName)**: Finds the path to LayoutName.
- **log (Message, [Error])**: Logs the Message and StackTrace provided by the Error, if you pass an ErrorObject and it has the stack property. If the debug is off, this method just does nothing.
- **ucfirst (string)**: Returns the string with the first letter uppercase.
- **\_\_set_default (Key, Value)**: Internal user only. Adds or update the default value (Key), with the value (Value). All the properties on the Object provided by the config file will be added this way.

###Properties###

- **\_\_defaults**: Object that contains the default values for some variables. Variables set on the config file will be added here using __set_default.