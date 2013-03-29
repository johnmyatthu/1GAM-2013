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
	self.player = params.gamerules.entity_factory:createClass( "Player" )
	self.player.world_x = 650
	self.player.world_y = 176
	self.player:onSpawn( params )

	self.orb = params.gamerules.entity_factory:createClass( "func_loot" )
	self.orb.world_x = 650
	self.orb.world_y = 256
	self.orb:onSpawn( params )

	self.enemy = params.gamerules.entity_factory:createClass( "Enemy" )
	self.enemy.world_x = 650
	self.enemy.world_y = 336
	self.enemy:onSpawn( params )
end


function HelpScreen:onDraw( params )

	if self.player then
		self.player:onDraw( params )
	end

	if self.orb then
		self.orb:onDraw( params )
	end

	if self.enemy then
		self.enemy:onDraw( params )
	end

	love.graphics.setColor( 0, 0, 0, 128 )
	love.graphics.rectangle( "fill", 0, 0, love.graphics.getWidth(), love.graphics.getHeight() )


	love.graphics.setFont( self.fonts["text16"] )
	love.graphics.setColor( 255, 255, 255, 255 )
	love.graphics.printf( "HOW TO PLAY", 0, 50, love.graphics.getWidth(), "center" )

	love.graphics.printf( "This is you: ", -200, 165, love.graphics.getWidth(), "right" )

	love.graphics.printf( "Collect these orbs: ", -200, 245, love.graphics.getWidth(), "right" )

	love.graphics.printf( "Guards can see you in the light\nSo stay in the darkness", -200, 335, love.graphics.getWidth(), "right" )	

	love.graphics.printf( "Press <space> to begin!", -200, 460, love.graphics.getWidth(), "right" )	

	love.graphics.print( "Movement", 75, 220 )

	love.graphics.print( "Quit",105, 340 )
	love.graphics.draw( self.keys, 30, 100, 0, 1, 1, 0, 0 )
end

function HelpScreen:onUpdate( params )
end