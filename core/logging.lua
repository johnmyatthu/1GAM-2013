require "core"

logging = class("logging")
function logging.message( message_type, message )
	print( "[" .. message_type:upper() .. "] " .. message )
end

function logging.verbose( msg )
	logging.message( "verbose", tostring(msg) )
end

function logging.warning( msg )
	logging.message( "warning", tostring(msg) )
end