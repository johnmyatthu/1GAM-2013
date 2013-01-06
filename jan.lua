require "core"
local logging = core.logging



local player = nil
local map_target = nil
local mouse_tile = {x = 0, y = 0}
local target_tile = {x = 0, y = 0}

-- temporary support middle-click drag
local map_drag = {isDragging = false, startX = 0, startY = 0, deltaX = 0, deltaY = 0}




-- Game class
Game = class( "Game" )
function Game:initialize( gamerules, config, fonts )
	self.gamerules = gamerules
	self.config = config
	self.fonts = fonts
end

function Game:onLoad( params )
	--logging.verbose( "Game onload" )

	-- gamepad/wiimote testing
	-- core.util.queryJoysticks()


	player = self.gamerules.entity_factory:createClass( "PathFollower" )
	player:loadSprite( "assets/sprites/guy.conf" )
	self.gamerules.entity_manager:addEntity( player )

	-- load the map
	self.gamerules:loadMap( self.config.map )

	-- map has been loaded, get a reference to the map's target
	map_target = self.gamerules.entity_manager:findFirstEntityByName( "func_target" )


	-- assuming this map has a spawn point; we'll set the player spawn
	-- and then center the camera on the player
	local spawn = self.gamerules.spawn
	--player.tile_x, player.tile_y = spawn.x+1, spawn.y+1
	logging.verbose( "spawn at: " .. spawn.x .. ", " .. spawn.y )

	player.world_x, player.world_y = self.gamerules:worldCoordinatesFromTileCenter( spawn.x, spawn.y )

	logging.verbose( "world coordinates: " .. player.world_x .. ", " .. player.world_y )
	player.tile_x, player.tile_y = self.gamerules:tileCoordinatesFromWorld( player.world_x, player.world_y )


	player.current_frame = "downleft"
	--self.gamerules:snapCameraToPlayer( player )

	logging.verbose( "initialization complete." )

--[[
	-- testing the entity spawner
	local spawnerABC = core.entity.EntitySpawner:new()
	spawnerABC.spawn_class = self.gamerules.entity_factory:findClass( "AnimatedSprite" )
	self.gamerules.entity_manager:addEntity( spawnerABC )
	spawnerABC.onSpawn = function ( params )
		self.gamerules.entity_manager:addEntity( params.entity )
		params.entity.world_x, params.entity.world_y = self.gamerules:worldCoordinatesFromTileCenter( math.random( 1, 20 ), math.random( 1, 20 ))		
	end
--]]
	--[[
	blah = self.gamerules.entity_factory:createClass( "PathFollower" )
	logging.verbose( blah )
	if blah then
		blah:loadSprite( "assets/sprites/guy.conf" )
		blah.current_frame = "left"
		self.gamerules.entity_manager:addEntity( blah )
		blah.world_x, blah.world_y = self.gamerules:worldCoordinatesFromTileCenter( spawn.x+1, spawn.y+1 )
		blah.tile_x, blah.tile_y = self.gamerules:tileCoordinatesFromWorld( blah.world_x, blah.world_y )
	end
	--]]	
end

function Game:highlight_tile( tx, ty, color )
	local wx, wy = self.gamerules:worldCoordinatesFromTileCenter( tx, ty )
	local drawX, drawY = self.gamerules:worldToScreen( wx, wy )

	love.graphics.setColor(color.r, color.g, color.b, color.a)
	love.graphics.quad( "fill", 
		drawX - self.gamerules.map.tileHeight, drawY, -- east
		drawX, drawY - self.gamerules.map.tileHeight/2,                       -- north
		drawX + self.gamerules.map.tileHeight, drawY, -- west
		drawX, drawY + self.gamerules.map.tileHeight/2 -- south
	)
end

function Game:onDraw( params )
	self.gamerules:drawWorld()

	-- draw highlighted tile
	self:highlight_tile( mouse_tile.x, mouse_tile.y, {r=0, g=255, b=0, a=128} )


	self:highlight_tile( target_tile.x, target_tile.y, {r=255, g=0, b=0, a=128} )

	local nt = player:currentTarget()
	if nt.x < 0 or nt.y < 0 then
	else
		self:highlight_tile( nt.x, nt.y, {r=0, g=255, b=255, a=128} )
	end

	-- draw entities here
	self.gamerules:drawEntities()

	-- draw overlay text
	local cx, cy = self.gamerules:getCameraPosition()
	love.graphics.setFont( self.fonts[ "text" ] )
	love.graphics.setColor( 255, 255, 255, 255 )
	love.graphics.print( "total entities: " .. self.gamerules.entity_manager:entityCount(), 10, 4 )
	--love.graphics.print( "map_translate: ", 10, 50 )
	--love.graphics.print( "x: " .. cx, 20, 70 )
	--love.graphics.print( "y: " .. cy, 20, 90 )
	--love.graphics.print( "tx: " .. mouse_tile.x, 20, 110 )
	--love.graphics.print( "ty: " .. mouse_tile.y, 20, 130 )

	--love.graphics.print( "player: ", 10, 150 )
	--love.graphics.print( "x: " .. player.world_x, 20, 170 )
	--love.graphics.print( "y: " .. player.world_y, 20, 190 )
	--love.graphics.print( "tx: " .. player.tile_x, 20, 210 )
	--love.graphics.print( "ty: " .. player.tile_y, 20, 230 )

	--local target = player:currentTarget()
	--love.graphics.print( "targetx: " .. target.x, 20, 250 )
	--love.graphics.print( "targety: " .. target.y, 20, 270 )

	--love.graphics.print( "velocity.x: " .. player.velocity.x, 20, 290 )
	--love.graphics.print( "velocity.y: " .. player.velocity.y, 20, 310 )

	if map_target then
		love.graphics.print( tostring(map_target), 10, 14 )
	end
end

function Game:onUpdate( params )
	--logging.verbose( "Game onUpdate" )

	self.gamerules.entity_manager:eventForEachEntity( "onUpdate", {dt=params.dt, gamerules=self.gamerules} )

	if map_drag.isDragging then
		local mx, my = love.mouse.getPosition()
		local cx, cy = self.gamerules:getCameraPosition()
		map_drag.deltaX = mx - map_drag.startX
		map_drag.deltaY = my - map_drag.startY
		cx = cx + map_drag.deltaX
		cy = cy + map_drag.deltaY
		map_drag.startX = mx
		map_drag.startY = my
		self.gamerules:warpCameraTo( cx, cy )
	end

	
	cam_x, cam_y = self.gamerules:getCameraPosition()
	if love.keyboard.isDown("w") then cam_y = cam_y + self.config.move_speed*dt end
	if love.keyboard.isDown("s") then cam_y = cam_y - self.config.move_speed*dt end
	if love.keyboard.isDown("a") then cam_x = cam_x + self.config.move_speed*dt end
	if love.keyboard.isDown("d") then cam_x = cam_x - self.config.move_speed*dt end
	self.gamerules:setCameraPosition( cam_x, cam_y )
	

	command = { up=love.keyboard.isDown("up"), down=love.keyboard.isDown("down"), left=love.keyboard.isDown("left"), right=love.keyboard.isDown("right"), move_speed=self.config.move_speed, dt=params.dt }
	self.gamerules:handleMovePlayerCommand( command, player )

	--self.gamerules:snapCameraToPlayer( player )
	local cx, cy = self.gamerules:getCameraPosition()
	local mx, my = love.mouse.getPosition()

	local tx, ty = self.gamerules:tileCoordinatesFromMouse( mx, my )
	local wx, wy = self.gamerules:worldCoordinatesFromMouse( mx, my )

	mouse_tile.x = tx
	mouse_tile.y = ty	
end

function Game:onKeyPressed( params )
	--logging.verbose( "Game onKeyPressed" )
end

function Game:onKeyReleased( params )
	--logging.verbose( "Game onKeyReleased" )
end

function Game:onMousePressed( params )
	--logging.verbose( "Game onMousePressed" )

	if params.button == "m" then
		-- enter drag mode
		map_drag.startX = params.x
		map_drag.startY = params.y
		map_drag.isDragging = true
	end

	if params.button == "l" then
		player:playAnimation( "attack1" )
		player.is_attacking = true
	end	
end

function Game:onMouseReleased( params )
	--logging.verbose( "Game onMouseReleased" )

	if params.button == "m" then
		map_drag.isDragging = false
	end

	if params.button == "r" then
		logging.verbose( "right click" )

		-- plot a course to the tile
		logging.verbose( "move from: " .. player.tile_x .. ", " .. player.tile_y )
		logging.verbose( "move to: " .. mouse_tile.x .. ", " .. mouse_tile.y )

		target_tile.x = mouse_tile.x
		target_tile.y = mouse_tile.y

		local path = self.gamerules:getPath( player.tile_x, player.tile_y, target_tile.x, target_tile.y )
		player:setPath( path )
	end

	player.is_attacking = false

end

function Game:onJoystickPressed( params )
	--logging.verbose( "Game onJoystickPressed" )
end

function Game:onJoystickReleased( params )
	--logging.verbose( "Game onJoystickReleased" )
end