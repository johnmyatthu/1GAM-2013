require "core"


HelpScreen = class("HelpScreen")

function HelpScreen:initialize( fonts )
	self.fonts = fonts
end


function HelpScreen:prepareToShow( params )
	params.game:spawnFish()


	-- spawn a chest
	local chest = params.gamerules.entity_factory:createClass( "func_chest" )
	chest.world_x = 650
	chest.world_y = 276
	params.gamerules:spawnEntity( chest, nil, nil, nil )
end

function HelpScreen:onDraw( params )

	love.graphics.setColor( 0, 0, 0, 128 )
	love.graphics.rectangle( "fill", 0, 0, love.graphics.getWidth(), love.graphics.getHeight() )

	love.graphics.setFont( self.fonts["text16"] )
	love.graphics.setColor( 255, 255, 255, 255 )
	love.graphics.printf( "HOW TO PLAY", 0, 50, love.graphics.getWidth(), "center" )


	love.graphics.printf( "This is your submarine: ", -250, 200, love.graphics.getWidth(), "right" )
	love.graphics.printf( "Locate and collect these: ", -250, 260, love.graphics.getWidth(), "right" )
end

function HelpScreen:onUpdate( params )
	params.gamerules:getPlayer().world_x = 650
	params.gamerules:getPlayer().world_y = 216
	fish = params.gamerules.entity_manager:findAllEntitiesByName( "func_fish" )

	if #fish < 10 then
		params.game:spawnFish()
	end

end