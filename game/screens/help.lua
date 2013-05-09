require "core"


HelpScreen = class("HelpScreen")

function HelpScreen:initialize( params )
	Screen.initialize(self, params)

	self.keys = love.graphics.newImage( "assets/help.png" )

	self.player = nil
end


function HelpScreen:onShow( params )
	self.player = params.gamerules.entity_factory:createClass( "Player" )
	self.player.world_x = 650
	self.player.world_y = 176
	self.player:onSpawn( params )
end

function HelpScreen:onHide( params )
end


function HelpScreen:onDraw( params )

	if self.player then
		self.player:onDraw( params )
	end

	love.graphics.setColor( 0, 0, 0, 128 )
	love.graphics.rectangle( "fill", 0, 0, love.graphics.getWidth(), love.graphics.getHeight() )


	love.graphics.setFont( self.fonts["text16"] )
	love.graphics.setColor( 255, 255, 255, 255 )
	love.graphics.printf( "HOW TO PLAY", 0, 50, love.graphics.getWidth(), "center" )

	love.graphics.printf( "This is you: ", -200, 165, love.graphics.getWidth(), "right" )

	love.graphics.printf( "Clear all blocks to win.", -200, 215, love.graphics.getWidth(), "right" )	

	love.graphics.printf( "Blocks can be destroyed\nwith another block of\nthe same color.", -200, 245, love.graphics.getWidth(), "right" )

	love.graphics.printf( "A block can change color\nif it touches a block\n with a different color.", -200, 335, love.graphics.getWidth(), "right" )	

	love.graphics.printf( "You will lose if the moving\nblock runs out of energy.\nHit blocks with matching\ncolors to restore energy.", -200, 425, love.graphics.getWidth(), "right" )	

	love.graphics.printf( "Press <space> to begin!", -200, 560, love.graphics.getWidth(), "right" )	

	love.graphics.print( "Movement", 75, 220 )

	love.graphics.print( "Quit",105, 340 )
	love.graphics.draw( self.keys, 30, 100, 0, 1, 1, 0, 0 )
end

function HelpScreen:onUpdate( params )
end