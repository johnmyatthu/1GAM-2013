require "core"
require "core.actions"
require "game"
require "game.screens.help"

local player = nil


-- Game class
Game = class( "Game", Screen )
function Game:initialize( gamerules, config, fonts, screencontrol )
	-- supplied from the main love entry point
	Screen.initialize(self, {gamerules=gamerules, fonts=fonts, screencontrol=screencontrol} )
	self.config = config

	self.helpscreen = screencontrol:findScreen("help")

	local action_table = {}
	action_table[ "toggle_collision_layer" ] = {instance=self, action=self.toggleDrawCollisions}
	action_table[ "show_ingame_menu" ] = {instance=self, action=self.showInGameMenu}
	
	self.actionmap = core.actions.ActionMap( self.config, action_table )

	self.state = GAME_STATE_PLAY

	self:onLoadGame( {gamerules=self.gamerules} )	
	love.mouse.setVisible( true )
end


function Game:showInGameMenu()
	-- local params = {
	-- 	gamerules = self.gamerules
	-- }
	-- local active_screen = self.screencontrol:getActiveScreen()
	-- logging.verbose(active_screen.name)
	-- if active_screen.name == "game" then
	-- 	self.screencontrol:setActiveScreen("mainmenu", params)
	-- else
	-- 	self.screencontrol:setActiveScreen("game", params)
	-- end
	love.event.push("quit")
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

function sign( x )
	if x > 0 then
		return 1
	elseif x < 0 then
		return -1
	end
end

function Game:onShow( params )
end

function Game:onHide( params )
end


function Game:onLoadGame( params )

	-- load the map
	self.gamerules:loadMap( self.config.map )	
	local player = self.gamerules.entity_factory:createClass( "Player" )
	player.name = "Player"
	self:warpPlayerToSpawn( player )
	self.gamerules:setPlayer( player )
	self.gamerules:spawnEntity( player, nil, nil, nil )


	-- set camera to static position such that the map is centered
	self.gamerules:setCameraPosition( 0, 0 )

	self.cellsw = self.gamerules.map.width
	self.cellsh = self.gamerules.map.height


	-- player.velocity.x = -50
	-- player.velocity.y = -70
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
	-- if not self.helpscreen_loaded and self.state == GAME_STATE_HELP then
	-- 	params.game = self
	-- 	params.gamerules = self.gamerules
	-- 	self.helpscreen_loaded = true

	-- 	self.screencontrol:setActiveScreen( "help", params )
	-- end
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

		

		--local cam_x, cam_y = self.gamerules:getCameraPosition()
		-- if love.keyboard.isDown( self:keyForAction(core.actions.MOVE_MAP_UP) ) then cam_y = cam_y + self.config.move_speed*params.dt end
		-- if love.keyboard.isDown( self:keyForAction(core.actions.MOVE_MAP_DOWN) ) then cam_y = cam_y - self.config.move_speed*params.dt end
		-- if love.keyboard.isDown( self:keyForAction(core.actions.MOVE_MAP_LEFT) ) then cam_x = cam_x + self.config.move_speed*params.dt end
		-- if love.keyboard.isDown( self:keyForAction(core.actions.MOVE_MAP_RIGHT) ) then cam_x = cam_x - self.config.move_speed*params.dt end
		--cam_y = cam_y + (32 * params.dt);
		--self.gamerules:setCameraPosition( cam_x, cam_y )

		local command = { 
		up=love.keyboard.isDown( self:keyForAction(core.actions.MOVE_PLAYER_UP) ), 
		down=love.keyboard.isDown( self:keyForAction(core.actions.MOVE_PLAYER_DOWN) ), 
		left=love.keyboard.isDown( self:keyForAction(core.actions.MOVE_PLAYER_LEFT) ), 
		right=love.keyboard.isDown( self:keyForAction(core.actions.MOVE_PLAYER_RIGHT) ), 
		move_speed=self.config.move_speed, 
		dt=params.dt }
		
		--self.gamerules:handleMovePlayerCommand( command, player )
		local player_speed = self.gamerules.data["player"].base_move_speed
		local direction = { x=0, y=0 }
		local maximum_speed = 160
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


		player.damping = {x=0.8, y=0.8}
		self.gamerules:moveEntityInDirection( player, direction, params.dt )

		--self.gamerules:snapCameraToPlayer( player )

		-- self:updatePlayerDirection()

		-- local numboxes = self.gamerules.entity_manager:findAllEntitiesByName("Scorebox")
		-- if numboxes == 0 then
		-- 	self.state = GAME_STATE_WIN
		-- elseif self.ball and self.ball.bounces_left <= 0 then
		-- 	self.state = GAME_STATE_FAIL
		-- end

		self.gamerules:onUpdate( params )
		
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


function Game:drawTopBar( params )
	love.graphics.setFont( self.fonts[ "text16" ] )
	love.graphics.setColor( 255, 255, 255, 255 )
	love.graphics.print( "Score: " .. tostring(params.gamerules.score), 20, 5 )	
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
		
		self:drawTopBar(params)

		--love.graphics.print( "Total Entities: " .. self.gamerules.entity_manager:entityCount(), 10, 50 )
	elseif self.state == GAME_STATE_WIN then
		self.gamerules:drawWorld()
		self.gamerules:drawEntities( params )

		love.graphics.setColor( 0, 0, 0, 64 )
		love.graphics.rectangle( "fill", 0, 0, love.graphics.getWidth(), love.graphics.getHeight() )	

		self:drawTopBar(params)

		love.graphics.setFont( self.fonts[ "text32" ] )
		love.graphics.setColor( 255, 255, 255, 255 )

		love.graphics.printf( "You cleared the level!", 0, 120, love.graphics.getWidth(), "center" )
		love.graphics.printf( "Thanks for playing!", 0, 250, love.graphics.getWidth(), "center" )

		love.graphics.setFont( self.fonts[ "text16" ] )
		love.graphics.printf( "This was created for #1GAM; OneGameAMonth.com May 2013", 0, 400, love.graphics.getWidth(), "center" )
	elseif self.state == GAME_STATE_FAIL then
		self.gamerules:drawWorld()
		self.gamerules:drawEntities( params )

		love.graphics.setColor( 0, 0, 0, 64 )
		love.graphics.rectangle( "fill", 0, 0, love.graphics.getWidth(), love.graphics.getHeight() )	

		love.graphics.setFont( self.fonts[ "text32" ] )
		love.graphics.setColor( 255, 0, 0, 255 )

		love.graphics.printf( "You ran out of energy!", 0, 120, love.graphics.getWidth(), "center" )

		love.graphics.setColor( 255, 255, 255, 255 )
		-- love.graphics.printf( "Press <space> to try again", 0, 250, love.graphics.getWidth(), "center" )
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
end

function Game:onMousePressed( params )
end

function Game:onMouseReleased( params )
end

function Game:onJoystickPressed( params )
--	logging.verbose( "on joy stick pressed: " .. params.joystick .. ", button: " .. params.button )

end

function Game:onJoystickReleased( params )
end