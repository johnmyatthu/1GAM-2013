require "core"


HelpScreen = class("HelpScreen")

function HelpScreen:initialize( fonts )
	self.fonts = fonts

	self.keys = love.graphics.newImage( "assets/help.png" )

	self.player = nil
	self.orb = nil
	self.enemy = nil
end


function HelpScreen:prepareToShow( params )

end


function HelpScreen:onDraw( params )

	love.graphics.setColor( 0, 0, 0, 128 )
	love.graphics.rectangle( "fill", 0, 0, love.graphics.getWidth(), love.graphics.getHeight() )


	love.graphics.setFont( self.fonts["text16"] )
	love.graphics.setColor( 255, 255, 255, 255 )
	love.graphics.printf( "HOW TO PLAY", 0, 50, love.graphics.getWidth(), "center" )

	love.graphics.printf( "Press <space> to begin!", -200, 400, love.graphics.getWidth(), "right" )	

	love.graphics.print( "Movement", 75, 220 )

	love.graphics.print( "Quit",105, 340 )
	love.graphics.draw( self.keys, 30, 100, 0, 1, 1, 0, 0 )
end

function HelpScreen:onUpdate( params )
end