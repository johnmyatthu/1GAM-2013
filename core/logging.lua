module( ..., package.seeall )


function message( message_type, message )
	print( "[" .. message_type:upper() .. "] " .. message )
end

function verbose( msg )
	message( "verbose", tostring(msg) )
end

function warning( msg )
	message( "warning", tostring(msg) )
end