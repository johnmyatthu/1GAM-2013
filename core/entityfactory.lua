require "core"

-- -------------------------------------------------------------
-- EntityFactory
-- Factory pattern for registering and creating game entities
EntityFactory = class( "EntityFactory" )
function EntityFactory:initialize()
	self.class_by_name = {}
end

function EntityFactory:registerClass( class_name, creator )
	self.class_by_name[ class_name ] = creator
end

function EntityFactory:findClass( class_name )
	if self.class_by_name[ class_name ] then 
		return self.class_by_name[ class_name ]
	end

	return nil
end

function EntityFactory:createClass( class_name )
	local instance = nil

	if self.class_by_name[ class_name ] then
		local create_class = self.class_by_name[ class_name ]
		instance = create_class:new()
	else
		logging.warning( "Unable to find class named '" .. class_name .. "'!" )
	end

	return instance
end