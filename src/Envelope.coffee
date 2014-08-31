request = require 'request'
{EventEmitter} = require 'events'
async = require 'async'
winston = require 'winston'
_ = require 'lodash'
uuid = require 'uuid'

class Envelope extends EventEmitter
	constructor: (@Mailbox, @message) ->
		@id = @message.mail_id

	get: (callback) ->
		if @message.mail_id
			@Mailbox.fetch_email @, callback

	del: (callback) ->
		if @message.mail_id
			@Mailbox.del_email @, callback

module.exports.Envelope = Envelope