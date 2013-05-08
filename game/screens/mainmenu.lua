require "core"

MainMenuScreen = class("MainMenuScreen", Screen )

function MainMenuScreen:initialize( fonts )
	self.fonts = fonts
end

function MainMenuScreen:onShow( params )
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