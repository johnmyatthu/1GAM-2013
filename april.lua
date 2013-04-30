require "core"
require "core.actions"
require "game"
require "helpscreen"

local player = nil
local mouse_tile = {x = 0, y = 0}
local target_tile = {x = 0, y = 0}

local EDIT_TILES = 0

-- Game class
Game = class( "Game" )
function Game:initialize( gamerules, config, fonts )
	-- supplied from the main love entry point
	self.gamerules = gamerules
	self.config = config
	self.fonts = fonts

	self.helpscreen = HelpScreen( fonts )


	local action_table = {}
	action_table[ "toggle_collision_layer" ] = {instance=self, action=self.toggleDrawCollisions}
	
	self.actionmap = core.actions.ActionMap( self.config, action_table )

	self.state = GAME_STATE_PLAY
	self.edit_state = EDIT_TILES

	if self.state == GAME_STATE_HELP then
		self.actionmap:set_action( " ", self, self.nextState )
		love.mouse.setVisible( true )
	else
		self:onLoadGame( {gamerules=self.gamerules} )
		self.gamerules:prepareForGame()		
		love.mouse.setVisible( true )
	end


	self.cell_layer = nil
	
	self.ca_interval = 0.1
	self.next_ca = self.ca_interval
end


function Game:nextState()

	if self.actionmap and self.actionmap:get_action( " " ) then
		self.actionmap:set_action(" ", nil, nil)
	end

	if self.state == GAME_STATE_HELP then
		--self.source:stop()
		--self.source:rewind()
		--self.source:play()
		self.state = GAME_STATE_PLAY
		self:onLoadGame( {gamerules=self.gamerules} )
		self.gamerules:prepareForGame()
	elseif self.state == GAME_STATE_WIN then
		--self.source:stop()
		--self.source:rewind()
		--self.source:play()
		self.state = GAME_STATE_PLAY
		self:onLoadGame( {gamerules=self.gamerules} )
		self.gamerules:prepareForGame()
	elseif self.state == GAME_STATE_FAIL then
		--self.source:stop()
		--self.source:rewind()
		--self.source:play()
		self.state = GAME_STATE_PLAY
		self:onLoadGame( {gamerules=self.gamerules} )
		self.gamerules:prepareForGame()
	end
end

function Game:keyForAction( action )
	return self.actionmap:key_for_action( action )
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


function Game:onLoadGame( params )

	-- load the map
	self.gamerules:loadMap( self.config.map )	
	local player = self.gamerules.entity_factory:createClass( "Player" )
	logging.verbose( "creating player" )
	self:warpPlayerToSpawn( player )
	self.gamerules:setPlayer( player )
	self.gamerules:spawnEntity( player, nil, nil, nil )

	self.cellsw = self.gamerules.map.width
	self.cellsh = self.gamerules.map.height


	--self:createEnemy( 100, 200 )
end

function Game:createEnemy( wx, wy )
	local enemy = self.gamerules.entity_factory:createClass( "Enemy" )
	enemy.world_x, enemy.world_y = wx, wy
	self.gamerules:spawnEntity( enemy, nil, nil, nil )

	return enemy
end


function Game:launchBall( x, y, vx, vy )
	local ball = self.gamerules.entity_factory:createClass( "Ball" )
	ball.world_x, ball.world_y = x, y
	ball.velocity.x = vx
	ball.velocity.y = vy
	self.gamerules:spawnEntity( ball, nil, nil, nil )

	return ball	
end

function Game:onLoad( params )
	if not self.helpscreen_loaded and self.state == GAME_STATE_HELP then
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



function Game:onUpdate( params )
	params.gamestate = self.state
	params.gamerules = self.gamerules

	if self.state == GAME_STATE_PLAY then
		local player = self.gamerules:getPlayer()

		self.gamerules:onUpdate( params )

		local cam_x, cam_y = self.gamerules:getCameraPosition()
		if love.keyboard.isDown( self:keyForAction(core.actions.MOVE_MAP_UP) ) then cam_y = cam_y + self.config.move_speed*params.dt end
		if love.keyboard.isDown( self:keyForAction(core.actions.MOVE_MAP_DOWN) ) then cam_y = cam_y - self.config.move_speed*params.dt end
		if love.keyboard.isDown( self:keyForAction(core.actions.MOVE_MAP_LEFT) ) then cam_x = cam_x + self.config.move_speed*params.dt end
		if love.keyboard.isDown( self:keyForAction(core.actions.MOVE_MAP_RIGHT) ) then cam_x = cam_x - self.config.move_speed*params.dt end
		self.gamerules:setCameraPosition( cam_x, cam_y )

		local command = { 
		up=love.keyboard.isDown( self:keyForAction(core.actions.MOVE_PLAYER_UP) ), 
		down=love.keyboard.isDown( self:keyForAction(core.actions.MOVE_PLAYER_DOWN) ), 
		left=love.keyboard.isDown( self:keyForAction(core.actions.MOVE_PLAYER_LEFT) ), 
		right=love.keyboard.isDown( self:keyForAction(core.actions.MOVE_PLAYER_RIGHT) ), 
		move_speed=self.config.move_speed, 
		dt=params.dt }
		
		--self.gamerules:handleMovePlayerCommand( command, player )
		local player_speed = 150
		local direction = { x=0, y=0 }
		if command.up then
			direction.y = -player_speed
		elseif command.down then
			direction.y = player_speed
		end

		if command.left then
			direction.x = -player_speed
		elseif command.right then
			direction.x = player_speed
		end
		self.gamerules:moveEntityInDirection( player, direction, params.dt )

		self.gamerules:snapCameraToPlayer( player )
		self:updatePlayerDirection()
	elseif self.state == GAME_STATE_HELP then
		params.game = self
		self.helpscreen:onUpdate( params )
	elseif self.state == GAME_STATE_EDITOR then

	end
		if self.drag_entity then
			self:snapEntityToGrid(self.drag_entity)
		end
end


function Game:snapEntityToGrid( ent )
	local mx, my = love.mouse.getPosition()
	local gridsize = 16

	ent.world_x = math.ceil(mx/gridsize) * gridsize
	ent.world_y = math.ceil(my/gridsize) * gridsize	
end


function Game:onDraw( params )
	love.graphics.setBackgroundColor( 0, 0, 0, 255 )
	love.graphics.clear()

	local player = self.gamerules:getPlayer()
	params.gamestate = self.state

	if self.state == GAME_STATE_PLAY then
		self.gamerules:drawWorld()
		-- draw entities here
		self.gamerules:drawEntities( params )


		love.graphics.setFont( self.fonts[ "text16" ] )

		-- draw the top overlay bar
		love.graphics.setColor( 0, 0, 0, 64 )
		local height = 32
		love.graphics.rectangle( "fill", 0, 0, love.graphics.getWidth(), height )
		love.graphics.setFont( self.fonts[ "text16" ] )
		love.graphics.setColor( 255, 255, 255, 255 )
		
		--love.graphics.print( "Orbs Collected: " .. tostring(player.loot_collected) .. " / " .. tostring(self.gamerules:totalOrbs()), 540, 5 )	

		--love.graphics.print( "Total Entities: " .. self.gamerules.entity_manager:entityCount(), 10, 50 )
	elseif self.state == GAME_STATE_WIN then
		self.gamerules:drawWorld()
		self.gamerules:drawEntities( params )

		love.graphics.setColor( 0, 0, 0, 64 )
		love.graphics.rectangle( "fill", 0, 0, love.graphics.getWidth(), love.graphics.getHeight() )	

		love.graphics.setFont( self.fonts[ "text32" ] )
		love.graphics.setColor( 255, 255, 255, 255 )

		love.graphics.printf( "You collected all the Orbs without being caught!", 0, 120, love.graphics.getWidth(), "center" )
		love.graphics.printf( "Thanks for playing!", 0, 250, love.graphics.getWidth(), "center" )

		love.graphics.setFont( self.fonts[ "text16" ] )
		love.graphics.printf( "This was created for #1GAM; OneGameAMonth.com March 2013", 0, 400, love.graphics.getWidth(), "center" )
	elseif self.state == GAME_STATE_FAIL then
		self.gamerules:drawWorld()
		self.gamerules:drawEntities( params )

		love.graphics.setColor( 0, 0, 0, 64 )
		love.graphics.rectangle( "fill", 0, 0, love.graphics.getWidth(), love.graphics.getHeight() )	
	

		love.graphics.setFont( self.fonts[ "text32" ] )
		love.graphics.setColor( 255, 0, 0, 255 )

		love.graphics.printf( "You were caught by guards!", 0, 120, love.graphics.getWidth(), "center" )

		love.graphics.setColor( 255, 255, 255, 255 )
		love.graphics.printf( "Press <space> to try again", 0, 250, love.graphics.getWidth(), "center" )
		love.graphics.printf( "Press <esc> to exit", 0, 300, love.graphics.getWidth(), "center" )
	elseif self.state == GAME_STATE_HELP then
		params.game = self
		self.helpscreen:onDraw( params )
	elseif self.state == GAME_STATE_EDITOR then
		self.gamerules:drawEntities( params )
	end
end

function Game:updatePlayerDirection()
	local player = self.gamerules:getPlayer()
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
	if self.actionmap then
		self.actionmap:on_key_pressed( params.key )
	end
end

function Game:onKeyReleased( params )
	if params.key == "m" then
		self.state = GAME_STATE_PLAY
		self:launchBall( 200, 200, -90, 40 )		
	end	
end

function Game:onMousePressed( params )
	if params.button == "l" then
		local mx, my = love.mouse.getPosition()

		-- see if we clicked an entity
		local ent = self.gamerules:findEntityAtMouse()
		if ent then
			self.drag_entity = ent
		else
			-- create a new one
			ent = self:createEnemy( mx, my )
			self:snapEntityToGrid( ent )
		end
	end
end

function Game:onMouseReleased( params )
	if params.button == "l" then
		if self.drag_entity then
			self.drag_entity = nil
		end
	end
end


function Game:onJoystickPressed( params )
end

function Game:onJoystickReleased( params )
end