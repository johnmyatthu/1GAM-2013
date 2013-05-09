require "core"

MainMenuScreen = class("MainMenuScreen", Screen )

function MainMenuScreen:initialize( fonts, screencontrol )
	Screen.initialize(self, fonts, screencontrol)


end

function MainMenuScreen:onShow( params )
	self.menu_activate = params.gamerules:playSound("menu_activate", false)
	self.menu_select = params.gamerules:playSound("menu_select", false)
end

function MainMenuScreen:onHide( params )
end

function MainMenuScreen:onDraw( params )
	love.graphics.setFont( self.fonts["text16"] )
	love.graphics.setColor( 255, 255, 255, 255 )
	love.graphics.printf( "MainMenuScreen", 0, 50, love.graphics.getWidth(), "center" )
end

function MainMenuScreen:onUpdate( params )
end

function MainMenuScreen:onKeyPressed( params )
	self.menu_select:rewind()
	self.menu_select:play()
end

function MainMenuScreen:onKeyReleased( params )
end

function MainMenuScreen:onMousePressed( params )
end

function MainMenuScreen:onMouseReleased( params )
end

function MainMenuScreen:onJoystickPressed( params )
end

function MainMenuScreen:onJoystickReleased( params )
end