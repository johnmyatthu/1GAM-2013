require "core"

ScreenControl = class("ScreenControl")

function ScreenControl:initialize()
	self.screens = {}
	self.active_screen = nil
	self.last_screen = nil
end

function ScreenControl:addScreen( name, instance )
	logging.verbose( "adding screen: " .. name )
	self.screens[ name ] = instance
	instance.name = name
end

function ScreenControl:findScreen( name )
	return self.screens[ name ]
end

function ScreenControl:screenCount()
	return #self.screens
end

function ScreenControl:setActiveScreen( name, params )
	local screen = self:findScreen(name)
	if not screen then
		logging.warning( "Unable to find screen named '" .. name .. "'!" )
		return self.active_screen
	end

	local previous_active_screen = self.active_screen
	if previous_active_screen then
		previous_active_screen:onHide( params )
	end
	
	screen:onShow( params )
	self.active_screen = screen
	return previous_active_screen
end

function ScreenControl:getActiveScreen()
	return self.active_screen
end