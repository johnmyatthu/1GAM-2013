require "core"

local player = nil
local mouse_tile = {x = 0, y = 0}
local target_tile = {x = 0, y = 0}

local ACTION_MOVE_MAP_LEFT = "move_map_left"
local ACTION_MOVE_MAP_RIGHT = "move_map_right"
local ACTION_MOVE_MAP_UP = "move_map_up"
local ACTION_MOVE_MAP_DOWN = "move_map_down"
local ACTION_MOVE_PLAYER_LEFT = "move_player_left"
local ACTION_MOVE_PLAYER_RIGHT = "move_player_right"
local ACTION_MOVE_PLAYER_UP = "move_player_up"
local ACTION_MOVE_PLAYER_DOWN = "move_player_down"
local ACTION_USE = "use"

-- the amount of build time given before each wave
local GAME_BUILD_TIME = 30

-- amount of time in seconds before defend round starts after build round ends
local GAME_BUILD_DEFEND_TRANSITION_TIME = 2

-- Game class
Game = class( "Game" )
function Game:initialize( gamerules, config, fonts )
	-- supplied from the main love entry point
	self.gamerules = gamerules
	self.config = config
	self.fonts = fonts

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

	self.key_for_action[ ACTION_USE ] = "e"

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

	self.state = GAME_STATE_BUILD
	self.timer = GAME_BUILD_TIME

	if self.state == GAME_STATE_BUILD then
		self.actions[ " " ] = self.nextState
		love.mouse.setVisible( true )
	else
		love.mouse.setVisible( false )
	end

	self.source = nil
end


function Game:nextState()
	--[[
	if self.actions[ " " ] then
		self.actions[ " " ] = nil
	end

	if self.state == GAME_STATE_BUILD then
		self.state = GAME_STATE_PRE_DEFEND
		self.timer = GAME_BUILD_DEFEND_TRANSITION_TIME
		self:preparePlayerForNextWave( player )
		
		self.gamerules:updateWalkableMap()
		love.mouse.setVisible( false )
	elseif self.state == GAME_STATE_PRE_DEFEND then
		self.state = GAME_STATE_DEFEND
		self.timer = 0
		love.mouse.setVisible( false )
		self.gamerules:playSound( "round_begin" )
	elseif self.state == GAME_STATE_ROUND_WIN then
		self.state = GAME_STATE_BUILD
		self.timer = GAME_BUILD_TIME
		self.actions[ " " ] = self.nextState
		self.gamerules:prepareForNextWave()
	end
	--]]
end

function Game:keyForAction( action )
	return self.key_for_action[ action ]
end

function Game:toggleDrawCollisions()
	if self.gamerules.collision_layer then
		self.gamerules.collision_layer.visible = not self.gamerules.collision_layer.visible
	end
end

function Game:warpPlayerToSpawn( player )
	local spawn = self.gamerules.spawn
	player.world_x, player.world_y = self.gamerules:worldCoordinatesFromTileCenter( spawn.x, spawn.y )
	player.tile_x, player.tile_y = self.gamerules:tileCoordinatesFromWorld( player.world_x, player.world_y )
end

function Game:onLoad( params )
	-- load the map
	--self.gamerules:loadMap( self.config.map )

	player = self.gamerules.entity_factory:createClass( "Player" )

	-- assuming this map has a spawn point; we'll set the player spawn
	-- and then center the camera on the player
	--self:warpPlayerToSpawn( player )

	player.tile_x = 0
	player.tile_y = 0
	self.gamerules:spawnEntity( player, 10, 10, nil )

	-- setup cursor
	--[[
	self.cursor_sprite = self.gamerules.entity_factory:createClass( "AnimatedSprite" )
	self.cursor_sprite:loadSprite( "assets/sprites/cursors.conf" )
	self.cursor_sprite:playAnimation("one")
	self.cursor_sprite.color = {r=0, g=255, b=255, a=255}

	-- don't draw this automatically; let's draw this ourselves.
	self.cursor_sprite.respondsToEvent = function (self, name) return (name ~= "onDraw") end
	self.gamerules:spawnEntity( self.cursor_sprite, -1, -1, nil )
	--]]

	logging.verbose( "Initialization complete." )
	--self.source = self.gamerules:playSound( "pulse" )
end


function Game:onUpdate( params )

	params.gamestate = self.state
	self.gamerules:onUpdate( params )

	--self.gamerules:snapCameraToPlayer( player )

	self:updatePlayerDirection()


	local cam_x, cam_y = self.gamerules:getCameraPosition()
	if love.keyboard.isDown( self:keyForAction(ACTION_MOVE_MAP_UP) ) then cam_y = cam_y + self.config.move_speed*params.dt end
	if love.keyboard.isDown( self:keyForAction(ACTION_MOVE_MAP_DOWN) ) then cam_y = cam_y - self.config.move_speed*params.dt end
	if love.keyboard.isDown( self:keyForAction(ACTION_MOVE_MAP_LEFT) ) then cam_x = cam_x + self.config.move_speed*params.dt end
	if love.keyboard.isDown( self:keyForAction(ACTION_MOVE_MAP_RIGHT) ) then cam_x = cam_x - self.config.move_speed*params.dt end
	self.gamerules:setCameraPosition( cam_x, cam_y )

	local command = { 
	up=love.keyboard.isDown( self:keyForAction(ACTION_MOVE_PLAYER_UP) ), 
	down=love.keyboard.isDown( self:keyForAction(ACTION_MOVE_PLAYER_DOWN) ), 
	left=love.keyboard.isDown( self:keyForAction(ACTION_MOVE_PLAYER_LEFT) ), 
	right=love.keyboard.isDown( self:keyForAction(ACTION_MOVE_PLAYER_RIGHT) ), 
	move_speed=self.config.move_speed, 
	dt=params.dt }
	self.gamerules:handleMovePlayerCommand( command, player )

	player.is_using = love.keyboard.isDown( self:keyForAction(ACTION_USE) )


	local mx, my = love.mouse.getPosition()



--[[
	local pitch = (mx / 800)

	if self.source then
		self.source:setPitch( pitch )
	end
--]]

--[[
	if self.source then
		local vx, vy = (mx - 400)/400, (my - 300)/300
		logging.verbose( "vx: " .. vx .. ", vy: " .. vy )
		self.source:setVelocity( vx, vy, 0 )
	end

--]]

	if self.source then
		--self.source:setVolume( (mx)/800 )
		--self.source:setPitch( (300+my)/600 )
	end
end




function Game:onDraw( params )
	love.graphics.setBackgroundColor( 39, 82, 93, 255 )
	love.graphics.clear()
	--self.gamerules:drawWorld()

	-- draw entities here
	params.gamestate = self.state
	self.gamerules:drawEntities( params )

	--
	-- HUD rendering







	love.graphics.setFont( self.fonts[ "text2" ] )
	love.graphics.setColor( 255, 255, 255, 255 )
	if player.last_interaction_object ~= nil and player:canInteractWith({gamerules=self.gamerules, other=player.last_interaction_object} ) then
		local action = player.last_interaction_object:useActionString()
		if action then
			love.graphics.printf( "press <key> to " .. action, 0, 500, love.graphics.getWidth(), "center" )
		end
	end

--[[
	local depth = 255 * ((player.world_y/64) / 100)
	if depth > 255 then
		depth = 255
	end
	love.graphics.setColor( 0, 0, 0, depth )
	love.graphics.rectangle( "fill", 0, 0, love.graphics.getWidth(), love.graphics.getHeight() )


	-- draw the top overlay bar
	love.graphics.setColor( 0, 0, 0, 64 )
	local height = 32
	love.graphics.rectangle( "fill", 0, 0, love.graphics.getWidth(), height )
	love.graphics.setFont( self.fonts[ "text2" ] )
	love.graphics.setColor( 255, 255, 255, 255 )
	love.graphics.print( "Depth: " .. tostring(player.world_y/64) .. " meters", 10, 5 )	
--]]
end

function Game:updatePlayerDirection()
		-- get a vector from player to mouse cursor
	local mx, my = love.mouse.getPosition()
	local wx, wy = self.gamerules:worldCoordinatesFromMouse( mx, my )
	local dirx = wx - player.world_x
	local diry = wy - player.world_y

	local magnitude = math.sqrt(dirx * dirx + diry * diry)
	dirx = dirx / magnitude
	diry = diry / magnitude
	player.dir.x = dirx
	player.dir.y = diry
end

function Game:onKeyPressed( params )
	if self.actions[ params.key ] then
		self.actions[ params.key ]( self )
	end
end

function Game:onKeyReleased( params )

end

function Game:onMousePressed( params )
	if self.state == GAME_STATE_DEFEND then

		if params.button == "l" then
			self.fire = true
		end
	end
end

function Game:onMouseReleased( params )
	if params.button == "l" then
		self.fire = false
	end
end

function Game:onJoystickPressed( params )
end

function Game:onJoystickReleased( params )
end