require "core"

Screen = class("Screen")

function Screen:initialize( params )
	self.fonts = params.fonts
	self.screencontrol = params.screencontrol
	self.gamerules = params.gamerules
end

function Screen:onShow( params )
end

function Screen:onHide( params )
end

function Screen:onDraw( params )
	love.graphics.setFont( self.fonts["text16"] )
	love.graphics.setColor( 255, 255, 255, 255 )
	love.graphics.printf( "Base Screen", 0, 50, love.graphics.getWidth(), "center" )
end

function Screen:onUpdate( params )
end

function Screen:onKeyPressed( params )
end

function Screen:onKeyReleased( params )
end

function Screen:onMousePressed( params )
end

function Screen:onMouseReleased( params )
end

function Screen:onJoystickPressed( params )
end

function Screen:onJoystickReleased( params )
end