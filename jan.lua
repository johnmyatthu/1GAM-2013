require "core"
local logging = core.logging



local player = nil

local mouse_tile = {x = 0, y = 0}
local target_tile = {x = 0, y = 0}

-- temporary support middle-click drag
local map_drag = {isDragging = false, startX = 0, startY = 0, deltaX = 0, deltaY = 0}

local ACTION_MOVE_MAP_LEFT = "move_map_left"
local ACTION_MOVE_MAP_RIGHT = "move_map_right"
local ACTION_MOVE_MAP_UP = "move_map_up"
local ACTION_MOVE_MAP_DOWN = "move_map_down"
local ACTION_MOVE_PLAYER_LEFT = "move_player_left"
local ACTION_MOVE_PLAYER_RIGHT = "move_player_right"
local ACTION_MOVE_PLAYER_UP = "move_player_up"
local ACTION_MOVE_PLAYER_DOWN = "move_player_down"

-- Game class
Game = class( "Game" )
function Game:initialize( gamerules, config, fonts )
	-- supplied from the main love entry point
	self.gamerules = gamerules
	self.config = config
	self.fonts = fonts

	-- internal vars
	self.state = 0 -- 0: defend, 1: build
	love.mouse.setVisible( false )

	self.preview_tile = {x=0, y=0}
	self.selected_tile = {x=0, y=0}


	self.key_for_action = {}
	self.key_for_action[ ACTION_MOVE_MAP_LEFT ] = "left"
	self.key_for_action[ ACTION_MOVE_MAP_RIGHT ] = "right"
	self.key_for_action[ ACTION_MOVE_MAP_UP ] = "up"
	self.key_for_action[ ACTION_MOVE_MAP_DOWN ] = "down"

	self.key_for_action[ ACTION_MOVE_PLAYER_LEFT ] = "a"
	self.key_for_action[ ACTION_MOVE_PLAYER_RIGHT ] = "d"
	self.key_for_action[ ACTION_MOVE_PLAYER_UP ] = "w"
	self.key_for_action[ ACTION_MOVE_PLAYER_DOWN ] = "s"

	self.actionmap = {}
	self.actionmap[ "toggle_collision_layer" ] = self.toggleDrawCollisions

	self.actions = {}
	logging.verbose( "mapping keys to actions..." )
	for key, action in pairs(config.keys) do
		--self.actions[ "d_togglecollisions" ] = self.toggleDrawCollisions
		logging.verbose( key .. " -> '" .. action .. "'")

		if self.actionmap[ action ] then
			self.actions[ key ] = self.actionmap[ action ]
		elseif self.key_for_action[ action ] then -- override default keys
			self.key_for_action[ action ] = key
		else
			logging.warning( "Unknown action '" .. action .. "', unable to map key: " .. key )
		end
	end

	self.cursor = {x=0, y=0}
end

function Game:keyForAction( action )
	return self.key_for_action[ action ]
end

function Game:toggleDrawCollisions()
	if self.gamerules.collision_layer then
		self.gamerules.collision_layer.visible = not self.gamerules.collision_layer.visible
	end
end

function Game:onLoad( params )
	--logging.verbose( "Game onload" )

	-- gamepad/wiimote testing
	-- core.util.queryJoysticks()




	-- load the map
	self.gamerules:loadMap( self.config.map )


	player = self.gamerules.entity_factory:createClass( "PathFollower" )
	player:loadSprite( "assets/sprites/arrow.conf" )
	self.gamerules.entity_manager:addEntity( player )

	self.gamerules.grid:addShape( player )
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
		blah:loadSprite( "assets/sprites/arrow.conf" )
		blah.current_frame = "left"
		self.gamerules.entity_manager:addEntity( blah )
		blah.world_x, blah.world_y = self.gamerules:worldCoordinatesFromTileCenter( spawn.x+1, spawn.y+1 )
		blah.tile_x, blah.tile_y = self.gamerules:tileCoordinatesFromWorld( blah.world_x, blah.world_y )
	end
	--]]

	self.cursor_sprite = self.gamerules.entity_factory:createClass( "AnimatedSprite" )
	self.cursor_sprite:loadSprite( "assets/sprites/cursors.conf" )
	self.cursor_sprite:playAnimation("one")
	self.cursor_sprite.color = {r=0, g=255, b=255, a=255}
	-- don't draw this automatically; let's draw this ourselves.
	self.cursor_sprite.respondsToEvent = function (self, name) return (name ~= "onDraw") end
	self.gamerules:spawnEntity( self.cursor_sprite, 1, 1, nil )
end

function Game:highlight_tile( mode, tx, ty, color )
	local wx, wy = self.gamerules:worldCoordinatesFromTileCenter( tx, ty )
	local drawX, drawY = self.gamerules:worldToScreen( wx, wy )

	love.graphics.setColor(color.r, color.g, color.b, color.a)
	love.graphics.quad( mode, 
		drawX - self.gamerules.map.tileHeight, drawY, -- east
		drawX, drawY - self.gamerules.map.tileHeight/2,                       -- north
		drawX + self.gamerules.map.tileHeight, drawY, -- west
		drawX, drawY + self.gamerules.map.tileHeight/2 -- south
	)
end

function Game:onDraw( params )
	self.gamerules:drawWorld()

	-- draw highlighted tile
	if self.state == 1 then
		self:highlight_tile( "line", self.selected_tile.x, self.selected_tile.y, {r=0, g=255, b=0, a=255} )
		
		local color = {r=0, g=0, b=0, a=128}
		if self.gamerules:isTilePlaceable( self.preview_tile.x, self.preview_tile.y ) then
			color.g = 255
		else
			color.r = 255
		end

		self:highlight_tile( "line", self.preview_tile.x, self.preview_tile.y, color )
	end


	self:highlight_tile( "line", target_tile.x, target_tile.y, {r=255, g=0, b=0, a=128} )

	local nt = player:currentTarget()
	if nt.x < 0 or nt.y < 0 then
	else
		self:highlight_tile( "line", nt.x, nt.y, {r=0, g=255, b=255, a=128} )
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

	self.cursor_sprite:onDraw( {gamerules=self.gamerules} )
end

function Game:onUpdate( params )
	--logging.verbose( "Game onUpdate" )
	local mx, my = love.mouse.getPosition()
	self.cursor_sprite.world_x, self.cursor_sprite.world_y = self.gamerules:worldCoordinatesFromMouse( mx, my )
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
	if love.keyboard.isDown( self:keyForAction(ACTION_MOVE_MAP_UP) ) then cam_y = cam_y + self.config.move_speed*params.dt end
	if love.keyboard.isDown( self:keyForAction(ACTION_MOVE_MAP_DOWN) ) then cam_y = cam_y - self.config.move_speed*params.dt end
	if love.keyboard.isDown( self:keyForAction(ACTION_MOVE_MAP_LEFT) ) then cam_x = cam_x + self.config.move_speed*params.dt end
	if love.keyboard.isDown( self:keyForAction(ACTION_MOVE_MAP_RIGHT) ) then cam_x = cam_x - self.config.move_speed*params.dt end
	self.gamerules:setCameraPosition( cam_x, cam_y )
	

	command = { 
	up=love.keyboard.isDown( self:keyForAction(ACTION_MOVE_PLAYER_UP) ), 
	down=love.keyboard.isDown( self:keyForAction(ACTION_MOVE_PLAYER_DOWN) ), 
	left=love.keyboard.isDown( self:keyForAction(ACTION_MOVE_PLAYER_LEFT) ), 
	right=love.keyboard.isDown( self:keyForAction(ACTION_MOVE_PLAYER_RIGHT) ), 
	move_speed=self.config.move_speed, 
	dt=params.dt }
	self.gamerules:handleMovePlayerCommand( command, player )

	--self.gamerules:snapCameraToPlayer( player )

	local mx, my = love.mouse.getPosition()
	local tx, ty = self.gamerules:tileCoordinatesFromMouse( mx, my )
	self.preview_tile.x = tx
	self.preview_tile.y = ty
end

function Game:onKeyPressed( params )
	--logging.verbose( "Game onKeyPressed" )
	if self.actions[ params.key ] then
		self.actions[ params.key ]( self )
	end
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
		--player:playAnimation( "attack1" )
		--player.is_attacking = true
		local mx, my = love.mouse.getPosition()

		if self.state == 1 then	
			local tx, ty = self.gamerules:tileCoordinatesFromMouse( mx, my )
			if self.gamerules:isTilePlaceable( tx, ty ) then
				self.selected_tile.x = tx
				self.selected_tile.y = ty
			end
		else
			local bullet = self.gamerules.entity_factory:createClass( "Bullet" )
			self.gamerules:spawnEntity( bullet, player.world_x, player.world_y, nil )
			local bullet_speed = 250

			-- get a vector from player to mouse cursor
			local wx, wy = self.gamerules:worldCoordinatesFromMouse( mx, my )
			local dirx = wx - player.world_x
			local diry = wy - player.world_y

			local magnitude = math.sqrt(dirx * dirx + diry * diry)
			dirx = dirx / magnitude
			diry = diry / magnitude
			bullet.velocity.x = dirx * bullet_speed
			bullet.velocity.y = diry * bullet_speed
		end
	end	
end

function Game:onMouseReleased( params )
	--logging.verbose( "Game onMouseReleased" )

	if params.button == "m" then
		map_drag.isDragging = false
	end

	--[[
	if params.button == "r" then
		logging.verbose( "right click" )

		-- plot a course to the tile
		logging.verbose( "move from: " .. player.tile_x .. ", " .. player.tile_y )
		logging.verbose( "move to: " .. mouse_tile.x .. ", " .. mouse_tile.y )

		target_tile.x = self.preview_tile.x
		target_tile.y = self.preview_tile.y

		local path = self.gamerules:getPath( player.tile_x, player.tile_y, target_tile.x, target_tile.y )
		player:setPath( path )
	end
	--]]

	player.is_attacking = false

end

function Game:onJoystickPressed( params )
	--logging.verbose( "Game onJoystickPressed" )
end

function Game:onJoystickReleased( params )
	--logging.verbose( "Game onJoystickReleased" )
end