require "json4lua.trunk.json.json"
loader = require "AdvTiledLoader.Loader"
require "core"
local logging = core.logging


local CONFIGURATION_FILE = "settings.json"

global = {}
global.map = nil
global.conf = {}



local player = core.entity.WorldEntity:new()

local em = core.gamerules.EntityManager:new()

em:addEntity( player )

local gameLogic = nil
local gameRules = nil

local mouse_tile = {x = 0, y = 0}
local player_tile = {x = 0, y = 0}

-- temporary support middle-click drag
local map_drag = {isDragging = false, startX = 0, startY = 0, deltaX = 0, deltaY = 0}
local highlight = nil

local tileLayer = nil
local menu_open = {
	main = false,
	right = false,
	foo = false,
	demo = false
}
local input_data = { text = "" }

function load_config()
	if love.filesystem.exists( CONFIGURATION_FILE ) then
		global.conf = json.decode( love.filesystem.read( CONFIGURATION_FILE ) )

		-- initialize GameRules
		gameRules = core.gamerules.GameRules:new()

		gameRules:warpCameraTo( global.conf.spawn[1], global.conf.spawn[2] )
	end
end

function love.load()
	logging.verbose( "loading configuration: " .. CONFIGURATION_FILE .. "..." )
	load_config()

	logging.verbose( "initializing game: " .. global.conf.game )
	gameLogic = require ( global.conf.game )
	
	-- gamepad/wiimote testing
	-- core.util.queryJoysticks()

	-- set maps path
	loader.path = "maps/" .. global.conf.game .. "/"
	global.map = loader.load( global.conf.map )
	gameRules.map = global.map
	gameRules.loadMap( global.conf.map )

	--logging.verbose( "map width: " .. global.map.width .. " -> " .. (global.map.width * 64) )
	--logging.verbose( "map height: " .. global.map.height .. " -> " .. (global.map.height * 32) )	

	global.map.drawObjects = false

	-- this crashes on a retina mbp if true; perhaps something to do with the GPUs switching?
	global.map.useSpriteBatch = false

	-- scan through map properties
	prop_name_map = {}
	class_tiles = {}
	for id, tile in pairs(global.map.tiles) do
		for key, value in pairs(tile.properties) do
			logging.verbose( key .. " -> " .. value .. "; tile: " .. tile.id )
			class_tiles[ tile.id ] = value
			prop_name_map[ tile.id ] = key
		end
	end

	-- iterate through all layers
	for name, layer in pairs(global.map.layers) do
		logging.verbose( "Searching in layer: " .. name )
		for x, y, tile in layer:iterate() do
			if tile then
				--logging.verbose( x )
				if class_tiles[ tile.id ] then
					logging.verbose( "handle '" .. class_tiles[ tile.id ] .. "' at " .. x .. ", " .. y )
					gameRules:handleTileProperty( layer, x, y, prop_name_map[ tile.id ], class_tiles[ tile.id ] )
				end
			end
		end
	end

	tileLayer = global.map.layers["Ground"]


	core.util.callLogic( gameLogic, "onLoad", {} )


	blah = gameRules.entity_factory:createClass( "WorldEntity" )

	-- assuming this map has a spawn point; we'll set the player spawn
	-- and then center the camera on the player
	local spawn = gameRules.spawn
	player_tile.x, player_tile.y = spawn.x, spawn.y
	player.world_x, player.world_y = gameRules:worldCoordinatesFromTileCenter( spawn.x, spawn.y )
	player.current_frame = "downleft"
	--gameRules:snapCameraToPlayer( player )

	logging.verbose( "initialization complete." )

--[[
	-- testing the entity spawner
	local spawnerABC = core.entity.EntitySpawner:new()
	spawnerABC.spawn_class = gameRules.entity_factory:findClass( "WorldEntity" )
	em:addEntity( spawnerABC )
	spawnerABC.onSpawn = function ( params )
		em:addEntity( params.entity )
		params.entity.world_x, params.entity.world_y = gameRules:worldCoordinatesFromTileCenter( math.random( 1, 20 ), math.random( 1, 20 ))		
	end
--]]
	if blah then
		blah.current_frame = "left"
		em:addEntity( blah )
		blah.world_x, blah.world_y = gameRules:worldCoordinatesFromTileCenter( spawn.x+1, spawn.y-1 )
	end
end

function love.draw()
	love.graphics.push()
	love.graphics.setColor(255,255,255,255)
	local cx, cy = gameRules:getCameraPosition()
	local ftx, fty = math.floor(cx), math.floor(cy)
	love.graphics.translate(ftx, fty)
	
	global.map:autoDrawRange( ftx, fty, 1, 50 )

	global.map:draw()
	love.graphics.rectangle("line", global.map:getDrawRange())
	love.graphics.pop()

	--love.graphics.setColor(255,128,0,255)
	--love.graphics.print('Hello World!', 400, 300)

	if highlight then
		love.graphics.setColor(0,255,0,128)
		--love.graphics.rectangle( "line", highlight.x, highlight.y, highlight.w, highlight.h )
		love.graphics.quad( "fill", 
			highlight.x - highlight.w, highlight.y + highlight.h/2, -- top left
			highlight.x, highlight.y, 			-- top right
			highlight.x + highlight.w, highlight.y + highlight.h/2, -- bottom right
			highlight.x, highlight.y + highlight.h -- bottom left
			)
	end


	-- draw entities here
	local cx, cy = gameRules:getCameraPosition()

	love.graphics.push()
	love.graphics.setColor( 255, 255, 255, 255 )
	em:sortForDrawing()
	em:eventForEachEntity( "onDraw", {screen_x=cx, screen_y=cy, gameRules=gameRules} )
	love.graphics.pop()

	love.graphics.setColor( 255, 255, 255, 255 )
	love.graphics.print( "map_translate: ", 10, 50 )
	love.graphics.print( "x: " .. cx, 20, 70 )
	love.graphics.print( "y: " .. cy, 20, 90 )
	love.graphics.print( "tx: " .. mouse_tile.x, 20, 110 )
	love.graphics.print( "ty: " .. mouse_tile.y, 20, 130 )


	love.graphics.print( "player: ", 10, 150 )
	love.graphics.print( "x: " .. player.world_x, 20, 170 )
	love.graphics.print( "y: " .. player.world_y, 20, 190 )
	love.graphics.print( "tx: " .. player_tile.x, 20, 210 )
	love.graphics.print( "ty: " .. player_tile.y, 20, 230 )	
end

--function love.run()
--end

function love.quit()
end

function love.update(dt)

	em:eventForEachEntity( "onUpdate", {dt=dt} )


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
	if love.keyboard.isDown("w") then cam_y = cam_y + global.conf.move_speed*dt end
	if love.keyboard.isDown("s") then cam_y = cam_y - global.conf.move_speed*dt end
	if love.keyboard.isDown("a") then cam_x = cam_x + global.conf.move_speed*dt end
	if love.keyboard.isDown("d") then cam_x = cam_x - global.conf.move_speed*dt end
	gameRules:setCameraPosition( cam_x, cam_y )
	

	command = { up=love.keyboard.isDown("up"), down=love.keyboard.isDown("down"), left=love.keyboard.isDown("left"), right=love.keyboard.isDown("right"), move_speed=global.conf.move_speed, dt=dt }

	gameRules:handleMovePlayerCommand( command, player )

	--gameRules:snapCameraToPlayer( player )


	if tileLayer ~= nil then
		local cx, cy = gameRules:getCameraPosition()

		local mx, my = love.mouse.getPosition()
		--print( "mouseX: " .. mx .. ", mouseY: " .. my )

		--local ix, iy = global.map:toIso( mx-cx, my-cy )
		local tx, ty = gameRules:tileCoordinatesFromMouse( mx, my )
		--print( "IsoX: " .. ix .. ", IsoY: " .. iy )

		-- for debug purposes, place the player at the analog position of the highlighted tile
		--player.world_x, player.world_y = gameRules:worldCoordinatesFromTileCenter( tx, ty )
		--player.world_x, player.world_y = gameRules:worldCoordinatesFromTile( tx, ty )

		--local tx, ty = math.floor(ix/global.map.tileHeight), math.floor(iy/global.map.tileHeight)
		--print( "tileX: " .. tx .. ", tileY: " .. ty )



		local tile = tileLayer( tx, ty )
		highlight = nil
		if tile then
			mouse_tile.x = tx+1
			mouse_tile.y = ty+1
			local drawX, drawY = core.util.IsoTileToScreen( global.map, cx, cy, tx, ty )
			highlight = { x=drawX, y=drawY, w=global.map.tileHeight, h=global.map.tileHeight }
		else
			mouse_tile = {x = 'nil', y = 'nil'}
		end

		player_tile.x, player_tile.y = gameRules:tileCoordinatesFromWorld( player.world_x, player.world_y )
		player_tile.x = player_tile.x+1
		player_tile.y = player_tile.y+1
	end



	core.util.callLogic( gameLogic, "onUpdate", {dt=dt} )
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
end

function love.mousereleased( x, y, button )
	if button == "m" then
		map_drag.isDragging = false
	end

	core.util.callLogic( gameLogic, "onMouseReleased", {x=x, y=y, button=button} )
end


function love.joystickpressed( joystick, button )
	print( "joystick: " .. joystick .. ", button: " .. button )
	core.util.callLogic( gameLogic, "onJoystickPressed", {joystick=joystick, button=button} )
end

function love.joystickreleased( joystick, button )
	print( "joystick: " .. joystick .. ", button: " .. button )	
	core.util.callLogic( gameLogic, "onJoystickReleased", {joystick=joystick, button=button} )
end
