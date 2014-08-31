{Guerrillamail} = require './Guerrillamail'

# Uses mikeal/request for HTTP Requests
# Set defaults as the second argument

request_defaults = {  }

# Can use a custom username, however must not already be in use or it will default to a random one
username = 'this-is-a-test-user'

# Create our mailbox
mailbox = new Guerrillamail#username, request_defaults

# This event fires whenever the email address has been registered on the site
mailbox.on 'email_addr', (email_address) =>
	console.log "send mail to '" + email_address + "'"

# This event fires everytime a message comes in
mailbox.on 'message', (envelope) =>
	console.log envelope.message

# Filters can be set on all of the 'mail_' fields
mailbox.on 'from:filter-can-be-set-here@example.com', (envelope) =>
	console.log envelope.message

