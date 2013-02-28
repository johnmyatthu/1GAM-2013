require "core"
require "helpscreen"

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

-- maximum number of fish alive at once
local MAX_FISH = 125

-- maximum number of sharks
local MAX_SHARKS = 15

-- the depth past which sharks will spawn
local SHARK_DEPTH = 70 --95

-- seconds between shark spawns
local SHARK_SPAWN_COOLDOWN = 5


-- Game class
Game = class( "Game" )
function Game:initialize( gamerules, config, fonts )
	-- supplied from the main love entry point
	self.gamerules = gamerules
	self.config = config
	self.fonts = fonts

	self.fire = false
	self.next_attack_time = 0

	self.fish_spawn = {
		0.25
	}

	self.next_spawn = {
		0
	}

	self.helpscreen = HelpScreen( fonts )
	
	self.shark_spawn_cooldown = SHARK_SPAWN_COOLDOWN
	self.next_shark_spawn = self.shark_spawn_cooldown

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
	self.actionmap[ "spawn_shark"] = self.spawnShark

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



	self.state = GAME_STATE_HELP
	if self.state == GAME_STATE_HELP then
		self.actions[ " " ] = self.nextState
		love.mouse.setVisible( true )
	else
		love.mouse.setVisible( false )
	end

	self.source = self.gamerules:createSource( "sawmill" )
	self.source:setVolume( 0.75 )
	
end


function Game:nextState()
	if self.actions[ " " ] then
		self.actions[ " " ] = nil
	end

	if self.state == GAME_STATE_HELP then
		self.source:stop()
		self.source:rewind()
		self.source:play()
		self.state = GAME_STATE_PLAY
		self:onLoad( {gamerules=self.gamerules} )
	elseif self.state == GAME_STATE_WIN then
		self.source:stop()
		self.source:rewind()
		self.source:play()		
		self.state = GAME_STATE_PLAY
		self:onLoad( {gamerules=self.gamerules} )
	elseif self.state == GAME_STATE_FAIL then
		self.source:stop()
		self.source:rewind()
		self.source:play()	
		self.state = GAME_STATE_PLAY
		self:onLoad( {gamerules=self.gamerules} )
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

function Game:warpPlayerToSpawn( player )
	local spawn = self.gamerules.spawn
	player.world_x, player.world_y = self.gamerules:worldCoordinatesFromTileCenter( spawn.x, spawn.y )
	player.tile_x, player.tile_y = self.gamerules:tileCoordinatesFromWorld( player.world_x, player.world_y )
end

function Game:onLoad( params )
	-- load the map
	self.gamerules:loadMap( self.config.map )
	self.gamerules:prepareForGame()
	player = self.gamerules.entity_factory:createClass( "Player" )

	-- assuming this map has a spawn point; we'll set the player spawn
	-- and then center the camera on the player
	self:warpPlayerToSpawn( player )
	self.gamerules:setPlayer( player )
	self.gamerules:spawnEntity( player, nil, nil, nil )

	if not self.helpscreen_loaded then
		params.game = self
		params.gamerules = self.gamerules
		self.helpscreen:prepareToShow( params )	
		self.helpscreen_loaded = true
	end
end



function Game:randomLocationFromPlayer( player, min_x, min_y )

	if min_x == nil then
		min_x = 0
	end

	if min_y == nil then
		min_y = 0
	end

	local direction = math.random(100)
	if direction > 50 then
		direction = 1
	else
		direction = -1
	end

	target_world_x = player.world_x + (min_x*direction) + (370*math.random()*direction)
	target_world_y = player.world_y + (min_y*direction) + (275*math.random()*direction)

	return target_world_x, target_world_y
end


function Game:spawnShark()

	if #self.gamerules.entity_manager:findAllEntitiesByName("func_shark") >= MAX_SHARKS then
		return
	end

	-- don't spawn too rapidly
	if self.next_shark_spawn > 0 then
		return
	end

	self.next_shark_spawn = self.shark_spawn_cooldown

	local shark = self.gamerules.entity_factory:createClass("func_shark")
	local x, y = self:randomLocationFromPlayer( player, 175, 175 )

	shark:lurk{ gamerules=self.gamerules }

	self.gamerules:spawnEntity( shark, x, y, nil )	
end

function Game:spawnFish()
	if self.gamerules.entity_manager:entityCount() >= MAX_FISH then
		return
	end

	for i=1, 10 do
		local thing = self.gamerules.entity_factory:createClass( "func_fish" )
		thing.tile_x = 0
		thing.tile_y = 0

		local target_x, target_y = self:randomLocationFromPlayer( player, 20, 20 )
		thing.pv = self.gamerules:randomVelocity( 100, 25 )
		
		self.gamerules:spawnEntity( thing, target_x, target_y, nil )
	end
end

function Game:onUpdate( params )
	params.gamestate = self.state

	if self.state == GAME_STATE_PLAY then

		for i,v in ipairs(self.next_spawn) do
			self.next_spawn[i] = self.next_spawn[i] - params.dt
			if v <= 0 then
				self.next_spawn[i] = self.fish_spawn[i]
				self:spawnFish()
			end
		end

		
		self.gamerules:onUpdate( params )

		self.gamerules:snapCameraToPlayer( player )

		self:updatePlayerDirection()

		self.next_shark_spawn = self.next_shark_spawn - params.dt
		if self.next_shark_spawn < 0 then
			self.next_shark_spawn = 0
		end


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
		
		--self.gamerules:handleMovePlayerCommand( command, player )

		player.damping.x = 0.975
		player.damping.y = 0.975

		local move_speed = 10

		if command.right then
			player.velocity.x = player.velocity.x + move_speed
		elseif command.left then
			player.velocity.x = player.velocity.x - move_speed
		end

		if command.up then
			player.velocity.y = player.velocity.y - move_speed
		elseif command.down then
			player.velocity.y = player.velocity.y + move_speed
		end	

		if player.world_y < 0.2 then
			player.world_y = 0.2
		end

		player.is_using = love.keyboard.isDown( self:keyForAction(ACTION_USE) )


		if player:seaDepth() > SHARK_DEPTH then
			--logging.verbose( "You sense something dark approaching..." )
			self:spawnShark()
		end



		-- the rudimentary check for win/fail conditions
		if player.health == 0 then
			self.state = GAME_STATE_FAIL
			self.actions[ " " ] = self.nextState
		elseif self.gamerules:totalChestsRemaining() == 0 then
			self.state = GAME_STATE_WIN
			self.actions[ " " ] = self.nextState
		end
	elseif self.state == GAME_STATE_HELP then
		self.gamerules:onUpdate( params )

		params.game = self
		self.helpscreen:onUpdate( params )
	end

end



function Game:onDraw( params )
	--love.graphics.setBackgroundColor( 39, 82, 93, 255 )
	love.graphics.setBackgroundColor( 29, 72, 83, 255 )
	love.graphics.clear()


	params.gamestate = self.state

	if self.state == GAME_STATE_PLAY then
		self.gamerules:drawWorld()
		-- draw entities here
		
		self.gamerules:drawEntities( params )


		love.graphics.setFont( self.fonts[ "text16" ] )


		local depth = 255 * ((player.world_y/32) / 275)
		if depth > 255 then
			depth = 255
		end
		love.graphics.setColor( 0, 0, 0, depth )
		love.graphics.rectangle( "fill", 0, 0, love.graphics.getWidth(), love.graphics.getHeight() )


		-- draw the top overlay bar
		love.graphics.setColor( 0, 0, 0, 64 )
		local height = 32
		love.graphics.rectangle( "fill", 0, 0, love.graphics.getWidth(), height )
		love.graphics.setFont( self.fonts[ "text16" ] )
		love.graphics.setColor( 255, 255, 255, 255 )
		love.graphics.print( "Depth: " .. tostring(player:seaDepth()) .. " meters", 10, 5 )


		love.graphics.print( "Treasure Saved: " .. tostring(self.gamerules:originalTotalChests()-self.gamerules:totalChestsRemaining()) .. " / " .. tostring(self.gamerules:originalTotalChests()), 550, 5 )	

		love.graphics.print( "Total Entities: " .. self.gamerules.entity_manager:entityCount(), 10, 50 )
	elseif self.state == GAME_STATE_WIN then
		love.graphics.setFont( self.fonts[ "text32" ] )
		love.graphics.setColor( 255, 255, 255, 255 )

		love.graphics.printf( "You collected all the treasure!", 0, 120, love.graphics.getWidth(), "center" )
		love.graphics.printf( "Thanks for playing!", 0, 250, love.graphics.getWidth(), "center" )

		love.graphics.setFont( self.fonts[ "text16" ] )
		love.graphics.printf( "This was created for #1GAM; OneGameAMonth.com February 2013", 0, 400, love.graphics.getWidth(), "center" )
	elseif self.state == GAME_STATE_FAIL then
		love.graphics.setFont( self.fonts[ "text32" ] )
		love.graphics.setColor( 255, 0, 0, 255 )

		love.graphics.printf( "Oh noes! You were eaten by a shark!", 0, 120, love.graphics.getWidth(), "center" )

		love.graphics.setColor( 255, 255, 255, 255 )
		love.graphics.printf( "Press <space> to try again", 0, 250, love.graphics.getWidth(), "center" )
		love.graphics.printf( "Press <esc> to exit", 0, 300, love.graphics.getWidth(), "center" )
	elseif self.state == GAME_STATE_HELP then
		--player.visible = false
		self.gamerules:drawEntities( params )

		params.game = self
		self.helpscreen:onDraw( params )
	end
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
	if params.button == "l" then
		local mx, my = love.mouse.getPosition()
		self:spawnFish()
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