request = require 'request'
{EventEmitter} = require 'events'
{Envelope} = require './Envelope'
async = require 'async'
winston = require 'winston'
_ = require 'lodash'
uuid = require 'uuid'

class Guerrillamail extends EventEmitter
	constructor: (email_addr = null, request_defaults = {}, @refresh_rate = 10000, @user_agent = 'Mozilla/5.0 (Windows NT 6.3; Win64; x64) AppleWebKit/537.36 (KHTML, like Gecko) Chrome/37.0.2049.0 Safari/537.36') ->
		@cookies = require('request').jar()
		request_defaults = _.extend request_defaults, ({ headers: { 'User-Agent': @user_agent } })

		request = request.defaults(request_defaults)

		@out = async.queue (item, next) =>
			defaults =
				f: item.fn
				ip: @ip
				agent: @user_agent

			if @sid_token
				defaults.sid_token = @sid_token 

			if @_domain
				defaults.domain = @_domain

			if @seq
				defaults.seq = @seq

			item.qs = _.extend item.qs, defaults
			winston.debug('Guerrillamail[' + item.method + '] => ' + (JSON.stringify item.qs))

			request
				jar: @cookies
				url: 'http://api.guerrillamail.com/ajax.php'
				qs: item.qs
				method: item.method
				body: item.body
			,next

		@out.pause()

		request
			url: 'http://monip.org'
		,(e,r,b) =>
			if e 
				@emit 'error', e
			else
				@ip = b.split('IP : ').pop().split('<').shift().trim()
				@out.resume()

		new_address = (data) =>
			@email_addr = data.email_addr
			@emit 'email_addr', @email_addr
			@get_email_list()
			if @interval_lock
				clearInterval @interval_lock

			@interval_lock = setInterval(() =>
				@check_email()
			,@refresh_rate)

		@.on 'get_email_address', new_address
		@.on 'set_email_user', new_address

		parse_messages = (data) =>
			@out.pause()
			async.mapSeries data.list,(_message, $next) =>
				@seq = _message.mail_id
				envelope = new Envelope @, _message
				envelope.get (e, envelope) =>
					envelope.Mailbox.emit('message', envelope)
					
					async.each (Object.keys(envelope.message)), (key, _next) =>
						if key.indexOf('mail_') isnt -1
							envelope.Mailbox.emit (key.replace('mail_', '')) + ':' + envelope.message[key], envelope.message
						
						_next()
					,(e) =>
						$next e, envelope
			,(error, mailbox) =>
				@out.resume()
				@emit 'refresh', mailbox
				@mailbox = mailbox

		@.on 'get_email_list', parse_messages
		@.on 'check_email', parse_messages

		@.on 'error', winston.error

		if email_addr
			@.once 'email_addr', (data) =>
				@set_email_user email_addr
		
		@get_email_address()

	build_request: (fn, qs, callback, method = "GET", body = null, do_emit = true) -> 
		@out.push
			fn: fn
			qs: qs
			method: method
			body: body
		,(err, res, body) =>
			if err
				@emit 'error', err
				if callback
					callback(err)
			else 
				try 
					data = JSON.parse body
					@sid_token = data.sid_token

					if do_emit
						@.emit(fn, data)

					if callback
						callback null, data
				catch error
					if callback
						callback error
		
	get_email_address: (callback, lang = 'en', @_domain) ->
		@build_request 'get_email_address', { lang: lang }, callback

	set_email_user: (email_user, callback, lang = 'en') ->
		@build_request 'set_email_user', { email_user: email_user, lang: lang }, callback

	check_email: (callback) ->
		@build_request 'check_email', {  }, callback

	get_email_list: (callback, offset = 0) ->
		@build_request 'get_email_list', { offset: offset.toString() }, callback

	fetch_email: (envelope, callback) ->
		if envelope and ((typeof envelope is 'string') or typeof(envelope) is 'number')
			envelope = new Envelope( @, { mail_id: envelope } )

		@build_request 'fetch_email', { email_id: envelope.message.mail_id }, (error, data) =>
			if data
				envelope.message = _.extend(envelope.message, data)
				@.emit('fetch_email', envelope)
				callback null, envelope
			else 
				@.emit('fetch_email', envelope)
				callback error, envelope
		, 'GET', null, false

	forget_me: (callback) ->
		@build_request 'forget_me', { email_addr: @email_addr }, callback

	del_email: (callback, messages...) ->
		messages = messages.each (x) ->
			if x instanceof Envelope
				return x.mail_id
			else 
				return x

		@build_request 'del_email', { email_ids: messages }, callback

	get_older_list: (limit, callback) ->
		@build_request 'get_older_list', { limit: limit }, callback

module.exports.Guerrillamail = Guerrillamail
