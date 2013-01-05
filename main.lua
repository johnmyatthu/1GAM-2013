

require "core"
local logging = core.logging


local CONFIGURATION_FILE = "settings.json"

local config = {}



local player = nil
local gameLogic = nil
local gameRules = nil

local mouse_tile = {x = 0, y = 0}
local target_tile = {x = 0, y = 0}
-- temporary support middle-click drag
local map_drag = {isDragging = false, startX = 0, startY = 0, deltaX = 0, deltaY = 0}

local menu_open = {
	main = false,
	right = false,
	foo = false,
	demo = false
}
local input_data = { text = "" }

function load_config()
	if love.filesystem.exists( CONFIGURATION_FILE ) then
		config = json.decode( love.filesystem.read( CONFIGURATION_FILE ) )

		-- initialize GameRules
		gameRules = core.gamerules.GameRules:new()

		gameRules:warpCameraTo( config.spawn[1], config.spawn[2] )
	end
end

function love.load()
	logging.verbose( "loading configuration: " .. CONFIGURATION_FILE .. "..." )
	load_config()

	logging.verbose( "initializing game: " .. config.game )
	gameLogic = require ( config.game )

	player = gameRules.entity_factory:createClass( "PathFollower" )
	player:loadSprite( "assets/sprites/guy.conf" )
	gameRules.entity_manager:addEntity( player )


	-- gamepad/wiimote testing
	-- core.util.queryJoysticks()

	gameRules:loadMap( config.map )

	core.util.callLogic( gameLogic, "onLoad", {} )


	

	-- assuming this map has a spawn point; we'll set the player spawn
	-- and then center the camera on the player
	local spawn = gameRules.spawn
	--player.tile_x, player.tile_y = spawn.x+1, spawn.y+1
	logging.verbose( "spawn at: " .. spawn.x .. ", " .. spawn.y )

	player.world_x, player.world_y = gameRules:worldCoordinatesFromTileCenter( spawn.x, spawn.y )

	logging.verbose( "world coordinates: " .. player.world_x .. ", " .. player.world_y )
	player.tile_x, player.tile_y = gameRules:tileCoordinatesFromWorld( player.world_x, player.world_y )


	player.current_frame = "downleft"
	--gameRules:snapCameraToPlayer( player )

	logging.verbose( "initialization complete." )

--[[
	-- testing the entity spawner
	local spawnerABC = core.entity.EntitySpawner:new()
	spawnerABC.spawn_class = gameRules.entity_factory:findClass( "AnimatedSprite" )
	gameRules.entity_manager:addEntity( spawnerABC )
	spawnerABC.onSpawn = function ( params )
		gameRules.entity_manager:addEntity( params.entity )
		params.entity.world_x, params.entity.world_y = gameRules:worldCoordinatesFromTileCenter( math.random( 1, 20 ), math.random( 1, 20 ))		
	end
--]]
	--[[
	blah = gameRules.entity_factory:createClass( "PathFollower" )
	logging.verbose( blah )
	if blah then
		blah:loadSprite( "assets/sprites/guy.conf" )
		blah.current_frame = "left"
		gameRules.entity_manager:addEntity( blah )
		blah.world_x, blah.world_y = gameRules:worldCoordinatesFromTileCenter( spawn.x+1, spawn.y+1 )
		blah.tile_x, blah.tile_y = gameRules:tileCoordinatesFromWorld( blah.world_x, blah.world_y )
	end
	--]]
end

function love.draw()
	gameRules:drawWorld()

	-- draw highlighted tile
	highlight_tile( mouse_tile.x, mouse_tile.y, {r=0, g=255, b=0, a=128} )


	highlight_tile( target_tile.x, target_tile.y, {r=255, g=0, b=0, a=128} )

	local nt = player:currentTarget()
	if nt.x < 0 or nt.y < 0 then
	else
		highlight_tile( nt.x, nt.y, {r=0, g=255, b=255, a=128} )
	end

	-- draw entities here
	gameRules:drawEntities()

	-- draw overlay text
	local cx, cy = gameRules:getCameraPosition()
	love.graphics.setColor( 255, 255, 255, 255 )
	love.graphics.print( "total entities: " .. gameRules.entity_manager:entityCount(), 10, 20 )
	--love.graphics.print( "map_translate: ", 10, 50 )
	--love.graphics.print( "x: " .. cx, 20, 70 )
	--love.graphics.print( "y: " .. cy, 20, 90 )
	love.graphics.print( "tx: " .. mouse_tile.x, 20, 110 )
	love.graphics.print( "ty: " .. mouse_tile.y, 20, 130 )

	love.graphics.print( "player: ", 10, 150 )
	love.graphics.print( "x: " .. player.world_x, 20, 170 )
	love.graphics.print( "y: " .. player.world_y, 20, 190 )
	love.graphics.print( "tx: " .. player.tile_x, 20, 210 )
	love.graphics.print( "ty: " .. player.tile_y, 20, 230 )

	local target = player:currentTarget()
	love.graphics.print( "targetx: " .. target.x, 20, 250 )
	love.graphics.print( "targety: " .. target.y, 20, 270 )

	love.graphics.print( "velocity.x: " .. player.velocity.x, 20, 290 )
	love.graphics.print( "velocity.y: " .. player.velocity.y, 20, 310 )

	
end

--function love.run()
--end

function love.quit()
end

function love.update(dt)
	gameRules.entity_manager:eventForEachEntity( "onUpdate", {dt=dt, gameRules=gameRules} )

	if map_drag.isDragging then
		local mx, my = love.mouse.getPosition()
		local cx, cy = gameRules:getCameraPosition()
		map_drag.deltaX = mx - map_drag.startX
		map_drag.deltaY = my - map_drag.startY
		cx = cx + map_drag.deltaX
		cy = cy + map_drag.deltaY
		map_drag.startX = mx
		map_drag.startY = my
		gameRules:warpCameraTo( cx, cy )
	end

	
	cam_x, cam_y = gameRules:getCameraPosition()
	if love.keyboard.isDown("w") then cam_y = cam_y + config.move_speed*dt end
	if love.keyboard.isDown("s") then cam_y = cam_y - config.move_speed*dt end
	if love.keyboard.isDown("a") then cam_x = cam_x + config.move_speed*dt end
	if love.keyboard.isDown("d") then cam_x = cam_x - config.move_speed*dt end
	gameRules:setCameraPosition( cam_x, cam_y )
	

	command = { up=love.keyboard.isDown("up"), down=love.keyboard.isDown("down"), left=love.keyboard.isDown("left"), right=love.keyboard.isDown("right"), move_speed=config.move_speed, dt=dt }
	gameRules:handleMovePlayerCommand( command, player )

	--gameRules:snapCameraToPlayer( player )
	local cx, cy = gameRules:getCameraPosition()
	local mx, my = love.mouse.getPosition()

	local tx, ty = gameRules:tileCoordinatesFromMouse( mx, my )
	local wx, wy = gameRules:worldCoordinatesFromMouse( mx, my )

	mouse_tile.x = tx
	mouse_tile.y = ty

	core.util.callLogic( gameLogic, "onUpdate", {dt=dt} )
end

function highlight_tile( tx, ty, color )
	local wx, wy = gameRules:worldCoordinatesFromTileCenter( tx, ty )
	local drawX, drawY = gameRules:worldToScreen( wx, wy )

	love.graphics.setColor(color.r, color.g, color.b, color.a)
	love.graphics.quad( "fill", 
		drawX - gameRules.map.tileHeight, drawY, -- east
		drawX, drawY - gameRules.map.tileHeight/2,                       -- north
		drawX + gameRules.map.tileHeight, drawY, -- west
		drawX, drawY + gameRules.map.tileHeight/2 -- south
	)
end

function love.keypressed( key, unicode )
	core.util.callLogic( gameLogic, "onKeyPressed", {key=key, unicode=unicode} )
end

function love.keyreleased(key )
	if key == "escape" then
		love.event.push( "quit" )
	elseif key == "f5" then
		print( "refresh" )
		load_config()
	end

	core.util.callLogic( gameLogic, "onKeyReleased", {key=key} )
end

function love.mousepressed( x, y, button )
	if button == "m" then
		-- enter drag mode
		map_drag.startX = x
		map_drag.startY = y
		map_drag.isDragging = true
	end

	core.util.callLogic( gameLogic, "onMousePressed", {x=x, y=y, button=button} )

	if button == "l" then
		player:playAnimation( "attack1" )
		player.is_attacking = true
	end
end

function love.mousereleased( x, y, button )
	if button == "m" then
		map_drag.isDragging = false
	end

	if button == "r" then
		logging.verbose( "right click" )

		-- plot a course to the tile
		logging.verbose( "move to: " .. mouse_tile.x .. ", " .. mouse_tile.y )

		target_tile.x = mouse_tile.x
		target_tile.y = mouse_tile.y

		local path = gameRules:getPath( player.tile_x, player.tile_y, target_tile.x, target_tile.y )
		player:setPath( path )
	end

	core.util.callLogic( gameLogic, "onMouseReleased", {x=x, y=y, button=button} )
	player.is_attacking = false
end


function love.joystickpressed( joystick, button )
	print( "joystick: " .. joystick .. ", button: " .. button )
	core.util.callLogic( gameLogic, "onJoystickPressed", {joystick=joystick, button=button} )
end

function love.joystickreleased( joystick, button )
	print( "joystick: " .. joystick .. ", button: " .. button )	
	core.util.callLogic( gameLogic, "onJoystickReleased", {joystick=joystick, button=button} )
end
