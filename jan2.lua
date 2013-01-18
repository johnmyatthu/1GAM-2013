require "core"
local logging = core.logging

-- bloom shader, by slime
--require "bloom"
--be = CreateBloomEffect( 400, 300)

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


local GAME_STATE_BUILD = core.GAME_STATE_BUILD
local GAME_STATE_DEFEND = core.GAME_STATE_DEFEND
local GAME_STATE_PRE_DEFEND = core.GAME_STATE_PRE_DEFEND
local GAME_STATE_ROUND_WIN = core.GAME_STATE_ROUND_WIN
local GAME_STATE_ROUND_FAIL = core.GAME_STATE_ROUND_FAIL


-- Game class
Game = class( "Game" )
function Game:initialize( gamerules, config, fonts )

	

	-- supplied from the main love entry point
	self.gamerules = gamerules
	self.config = config
	self.fonts = fonts

	-- internal vars
	

	self.preview_tile = {x=0, y=0}
	self.selected_tile = {x=0, y=0}

	self.fire = false
	self.next_attack_time = 0

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
	logging.verbose( "Mapping keys to actions..." )
	for key, action in pairs(config.keys) do
		--self.actions[ "d_togglecollisions" ] = self.toggleDrawCollisions
		logging.verbose( "\t'" .. key .. "' -> '" .. action .. "'" )

		if self.actionmap[ action ] then
			self.actions[ key ] = self.actionmap[ action ]
		elseif self.key_for_action[ action ] then -- override default keys
			self.key_for_action[ action ] = key
		else
			logging.warning( "Unknown action '" .. action .. "', unable to map key: " .. key )
		end
	end
	self.actions["escape"] = self.escape_hit
	self.actions[" "] = self.escape_hit

	self.cursor = {x=0, y=0}

	self.state = GAME_STATE_BUILD

	self.build_time = 300
	self.timer = self.build_time


	if self.state == GAME_STATE_BUILD then
		love.mouse.setVisible( true )
	else
		love.mouse.setVisible( false )
	end
end


function Game:nextState()
	if self.state == GAME_STATE_BUILD then
		self.state = GAME_STATE_PRE_DEFEND
		self.timer = 2
		love.mouse.setVisible( false )
	elseif self.state == GAME_STATE_PRE_DEFEND then
		self.state = GAME_STATE_DEFEND
		self.timer = 0
		love.mouse.setVisible( false )
	end
end


function Game:keyForAction( action )
	return self.key_for_action[ action ]
end

function Game:toggleDrawCollisions()
	if self.gamerules.collision_layer then
		self.gamerules.collision_layer.visible = not self.gamerules.collision_layer.visible
	end
end


function Game:loadEntityAtLevel( entity, level )
	local data = self.gamerules:dataForKeyLevel( entity.class.name, level )
	if data then
		entity:loadProperties( data )
	else
		logging.warning( "ERROR: could not find properties for class '" .. entity.class.name .. "' at level " .. level )
	end
end

function Game:onLoad( params )
	--logging.verbose( "Game onload" )

	-- gamepad/wiimote testing
	-- core.util.queryJoysticks()




	-- load the map
	self.gamerules:loadMap( self.config.map )

	self.target = self.gamerules.entity_manager:findFirstEntityByName( "func_target" )

	player = self.gamerules.entity_factory:createClass( "Player" )
	player:loadSprite( "assets/sprites/player.conf" )
	self.gamerules.entity_manager:addEntity( player )
	self.gamerules:addCollision( player )
	-- assuming this map has a spawn point; we'll set the player spawn
	-- and then center the camera on the player

	local spawn = self.gamerules.spawn
	player.world_x, player.world_y = self.gamerules:worldCoordinatesFromTileCenter( spawn.x, spawn.y )
	player.tile_x, player.tile_y = self.gamerules:tileCoordinatesFromWorld( player.world_x, player.world_y )

	self:loadEntityAtLevel( player, 1 )

	player.current_frame = "east"
	--self.gamerules:snapCameraToPlayer( player )

	logging.verbose( "initialization complete." )

	-- setup cursor
	self.cursor_sprite = self.gamerules.entity_factory:createClass( "AnimatedSprite" )
	self.cursor_sprite:loadSprite( "assets/sprites/cursors.conf" )
	self.cursor_sprite:playAnimation("one")
	self.cursor_sprite.color = {r=0, g=255, b=255, a=255}
	-- don't draw this automatically; let's draw this ourselves.
	self.cursor_sprite.respondsToEvent = function (self, name) return (name ~= "onDraw") end
	self.gamerules:spawnEntity( self.cursor_sprite, 1, 1, nil )
end

-- arr; this be for isometric tile only, matey.
function Game:highlight_iso_tile( mode, tx, ty, color )
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

function Game:highlight_tile( mode, tx, ty, color )
	local wx, wy = self.gamerules:worldCoordinatesFromTileCenter( tx, ty )
	local drawX, drawY = self.gamerules:worldToScreen( wx, wy )

	local hw = self.gamerules.map.tileWidth/2
	local hh = self.gamerules.map.tileHeight/2

	love.graphics.setColor(color.r, color.g, color.b, color.a)
	love.graphics.quad( mode, 
		drawX - hw, drawY - hh, -- upper left
		drawX + hw, drawY - hh, -- upper right
		drawX + hw, drawY + hh, -- lower right
		drawX - hw, drawY + hh -- lower left
	)
end


function Game:onUpdate( params )
	params.gamestate = self.state
	self.gamerules:onUpdate( params )


	if self.state == GAME_STATE_BUILD or self.state == GAME_STATE_PRE_DEFEND then
		self.timer = self.timer - params.dt
		if self.timer <= 0 then
			self:nextState()
		end
	elseif self.state == GAME_STATE_DEFEND then
		self.next_attack_time = self.next_attack_time - params.dt
		if self.next_attack_time <= 0 then

			if self.fire then
				self:playerAttack( params )
				self.next_attack_time = player.attack_delay
			end
		end


		--logging.verbose( "Game onUpdate" )
		local mx, my = love.mouse.getPosition()
		self.cursor_sprite.world_x, self.cursor_sprite.world_y = self.gamerules:worldCoordinatesFromMouse( mx, my )
	end

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

	if self.target and self.target.health <= 0 then
		self.timer = 8
		self.state = GAME_STATE_ROUND_FAIL
	end
end




function Game:onDraw( params )


	self.gamerules:drawWorld()

	-- draw highlighted tile
	if self.state == GAME_STATE_BUILD then
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

--[[
	local nt = player:currentTarget()
	if nt.x < 0 or nt.y < 0 then
	else
		self:highlight_tile( "line", nt.x, nt.y, {r=0, g=255, b=255, a=128} )
	end
--]]

	-- draw entities here
	self.gamerules:drawEntities()

	-- draw overlay text
	local cx, cy = self.gamerules:getCameraPosition()
	love.graphics.setFont( self.fonts[ "text" ] )
	love.graphics.setColor( 255, 255, 255, 255 )
	love.graphics.print( "total entities: " .. self.gamerules.entity_manager:entityCount(), 10, 4 )

	love.graphics.print( ("gamestate: " .. tostring(self.state)), 10, 50 )

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

	--local mx, my = love.mouse.getPosition()
	--love.graphics.print( "mx: " .. mx, 20, 90 )
	--love.graphics.print( "my: " .. my, 20, 110 )
	--local target = player:currentTarget()
	--love.graphics.print( "targetx: " .. target.x, 20, 250 )
	--love.graphics.print( "targety: " .. target.y, 20, 270 )

	--love.graphics.print( "velocity.x: " .. player.velocity.x, 20, 290 )
	--love.graphics.print( "velocity.y: " .. player.velocity.y, 20, 310 )

	self.cursor_sprite:onDraw( {gamerules=self.gamerules} )


	if self.state == GAME_STATE_BUILD or self.state == GAME_STATE_PRE_DEFEND then
		love.graphics.setColor( 0, 0, 0, 128 )
		local height = love.graphics.getHeight()/5
		love.graphics.rectangle( "fill", 0, love.graphics.getHeight() - height, love.graphics.getWidth(), height )

		love.graphics.setFont( self.fonts[ "text2" ] )
		love.graphics.setColor( 255, 255, 255, 255 )

		if self.state == GAME_STATE_BUILD then
			love.graphics.printf( "BUILD YOUR DEFENSES", 0, 490, love.graphics.getWidth(), "center" )

			local r,g,b,a = self.gamerules:colorForTimer(math.floor(self.timer))
			love.graphics.setColor( r, g, b, a )
			love.graphics.printf( math.floor(self.timer), 0, 540, love.graphics.getWidth(), "center" )
			--love.graphics.print( math.floor(self.timer), 380, 540 )
		else
			love.graphics.printf( "GET READY", 0, 510, love.graphics.getWidth(), "center" )
		end
		love.graphics.setColor( 255, 255, 255, 255 )


	elseif self.state == GAME_STATE_ROUND_FAIL then
		love.graphics.setColor( 0, 0, 0, 128 )
		local height = love.graphics.getHeight()/5
		love.graphics.rectangle( "fill", 0, love.graphics.getHeight() - height, love.graphics.getWidth(), height )

		love.graphics.setFont( self.fonts[ "text2" ] )
		love.graphics.setColor( 255, 0, 0, 255 )

		love.graphics.printf( "YOU FAILED", 0, 510, love.graphics.getWidth(), "center" )

		love.graphics.setColor( 255, 255, 255, 255 )

	end

--[[
	-- bloom
	--be:setIntensity(2,2)
	be:setThreshold( 0.2 )
	be:predraw()
	be:enabledrawtobloom()

	self.gamerules:drawEntities()
	self.cursor_sprite:onDraw( {gamerules=self.gamerules} )
	be:postdraw()
--]]
end

function Game:playerAttack( params )
	--player:playAnimation( "attack1" )
	--player.is_attacking = true
	local mx, my = love.mouse.getPosition()

	if false then	
		local tx, ty = self.gamerules:tileCoordinatesFromMouse( mx, my )
		if self.gamerules:isTilePlaceable( tx, ty ) then
			self.selected_tile.x = tx
			self.selected_tile.y = ty
		end
	else
		local bullet = self.gamerules.entity_factory:createClass( "Bullet" )
		self.gamerules:spawnEntity( bullet, player.world_x, player.world_y, nil )


		-- get a vector from player to mouse cursor
		local wx, wy = self.gamerules:worldCoordinatesFromMouse( mx, my )
		local dirx = wx - player.world_x
		local diry = wy - player.world_y

		local magnitude = math.sqrt(dirx * dirx + diry * diry)
		dirx = dirx / magnitude
		diry = diry / magnitude
		bullet.velocity.x = dirx
		bullet.velocity.y = diry
		bullet.attack_damage = player.attack_damage
		self.gamerules:playSound( "fire2" )
	end	
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
		self.fire = true
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

	if params.button == "l" then
		self.fire = false
	end

	player.is_attacking = false

end

function Game:onJoystickPressed( params )
	--logging.verbose( "Game onJoystickPressed" )
end

function Game:onJoystickReleased( params )
	--logging.verbose( "Game onJoystickReleased" )
end