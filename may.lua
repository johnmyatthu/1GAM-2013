require "core"
require "core.actions"
require "game"
require "game.screens.help"

InputState = class("InputState")
function InputState:initialize()
	self.mouse = {}
	self.mouse.prev = {x=0,y=0}
	self.mouse.curr = {x=0,y=0}
	self.mouse.delta = {x=0,y=0}
end

function InputState:update(dt)
	self.mouse.prev.x, self.mouse.prev.y = self.mouse.curr.x, self.mouse.curr.y
	self.mouse.curr.x, self.mouse.curr.y = love.mouse.getPosition() 

	self.mouse.delta.x, self.mouse.delta.y = (self.mouse.curr.x-self.mouse.prev.x), (self.mouse.curr.y-self.mouse.prev.y)
end


local player = nil

local INVENTORY_MAX_SLOTS = 4
local INVENTORY_SLOT_SIZE = 32

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
	action_table[ "next_inventory_item" ] = {instance=self, action=self.nextItem}
	action_table[ "prev_inventory_item" ] = {instance=self, action=self.prevItem}
	
	self.actionmap = core.actions.ActionMap( self.config, action_table )

	self.state = GAME_STATE_PLAY

	self:onLoadGame( {gamerules=self.gamerules} )	
	love.mouse.setVisible( true )


	self.input = InputState()
	self.highlighted_item = nil

	self.inventory = {0, 0, 0, 0}
	self.selected_item = 1

end


function Game:nextItem()
	self.selected_item = self.selected_item + 1
	if self.selected_item > INVENTORY_MAX_SLOTS then
		self.selected_item = 1
	end
end

function Game:prevItem()
	self.selected_item = self.selected_item - 1
	if self.selected_item < 1 then
		self.selected_item = INVENTORY_MAX_SLOTS
	end	
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

	self.input:update(params.dt)

	if self.state == GAME_STATE_PLAY then
		local player = self.gamerules:getPlayer()

		--local sx, sy = self.gamerules:worldToScreen(self.mouse.curr.x, self.mouse.curr.y)
		self.highlighted_item = self.gamerules:findEntityAtMouse( false )

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


		--player.damping = {x=0.8, y=0.8}
		self.velocity = direction
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


function Game:snapCoordinatesToGrid( x, y, gridsize )
	x = math.ceil(x/gridsize) * gridsize
	y = math.ceil(y/gridsize) * gridsize
	return x, y
end

function Game:snapEntityToGrid( ent )
	local mx, my = love.mouse.getPosition()
	local gridsize = 32

	ent.world_x = math.ceil(mx/gridsize) * gridsize
	ent.world_y = math.ceil(my/gridsize) * gridsize	
end


function Game:drawTopBar( params )
	love.graphics.setFont( self.fonts[ "text16" ] )
	love.graphics.setColor( 255, 255, 255, 255 )
	love.graphics.print( "Score: " .. tostring(params.gamerules.score), 20, 5 )	
end

function Game:drawInventory( params )
	local inventory_width = (INVENTORY_MAX_SLOTS * INVENTORY_SLOT_SIZE)
	local x = (love.graphics.getWidth()/2) - (inventory_width/2)
	local y = love.graphics.getHeight()-INVENTORY_SLOT_SIZE
	love.graphics.setColor(32, 32, 32, 192)
	love.graphics.rectangle("fill", x, y, inventory_width, INVENTORY_SLOT_SIZE)

	love.graphics.setColor(0,0,0,255)
	--love.graphics.rectangle("line", x, y, inventory_width, INVENTORY_SLOT_SIZE)
	for i=1, INVENTORY_MAX_SLOTS do
		local item = self.inventory[i]


		if item ~= 0 then
			local wx, wy = item.world_x, item.world_y
			local tx, ty = params.gamerules:screenToWorld(x, y)
			item.world_x, item.world_y = tx+16, ty+16
			item.visible = true
			item:onDraw( params )
			item.visible = false
			item.world_x, item.world_y = wx, wy
		end

		if self.selected_item == i then
			love.graphics.setColor(255, 255, 255, 128)
			love.graphics.rectangle("line", x, y, INVENTORY_SLOT_SIZE, INVENTORY_SLOT_SIZE)
		end		

		x = x + INVENTORY_SLOT_SIZE		
	end
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
		
		self:drawTopBar( params )

		--love.graphics.print( "Player is on ground? " .. tostring(player:isOnGround()), 10, 200 )

		--love.graphics.print( "Total Entities: " .. self.gamerules.entity_manager:entityCount(), 10, 50 )


		if self.highlighted_item and (self.highlighted_item ~= player) then
			local x,y = self.highlighted_item.world_x, self.highlighted_item.world_y

			if player:canPickupItem(self.gamerules, self.highlighted_item) then
				love.graphics.setColor( 0, 255, 32, 255 )
			else
				love.graphics.setColor( 192, 0, 0, 255 )
			end
			
			love.graphics.rectangle("line", x-16, y-16, 32, 32)
		else
			local mx, my = love.mouse.getPosition()
			local x,y = self.gamerules:screenToWorld(mx, my)
			x,y = self:snapCoordinatesToGrid(x,y, 32)
			love.graphics.setColor( 0, 128, 255, 255 )
			love.graphics.rectangle("line", x-32, y-32, 32, 32)
		end


		self:drawInventory( params )

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


function Game:inventoryUsedSlots(params)
	local used_slots = 0
	for _,i in pairs(self.inventory) do
		if i ~= 0 then
			used_slots = used_slots + 1
		end
	end

	return used_slots
end

function Game:inventoryFindUnusedSlot()
	for index,i in ipairs(self.inventory) do
		if i == 0 then
			return index
		end
	end
	return -1
end

function Game:onMousePressed( params )
	if params.button == "l" then
		local player = self.gamerules:getPlayer()
		local item = self.gamerules:findEntityAtMouse()
		if item then
			local used_slots = self:inventoryUsedSlots(params)
			if player:canPickupItem(self.gamerules, item) and (used_slots < INVENTORY_MAX_SLOTS) then
				local target_slot = self:inventoryFindUnusedSlot()
				if target_slot > 0 then
					self.inventory[ target_slot ] = item
					self.gamerules:removeCollision(item)
					item.visible = false
				end
			end
		else
			-- place item from inventory
			item = self.inventory[self.selected_item]

			if item ~= 0 then
				local mx, my = love.mouse.getPosition()
				item.world_x, item.world_y = self.gamerules:screenToWorld(mx, my)
				--self:snapEntityToGrid(item)
				item.world_x, item.world_y = self:snapCoordinatesToGrid(item.world_x, item.world_y, 32)
				item.world_x = item.world_x - 16
				item.world_y = item.world_y - 16

				item.visible = true
				self.gamerules:addCollision(item)
				self.inventory[self.selected_item] = 0
			end
		end
	elseif params.button == "m" then

	end
end

function Game:onMouseReleased( params )
end

function Game:onJoystickPressed( params )
--	logging.verbose( "on joy stick pressed: " .. params.joystick .. ", button: " .. params.button )

end

function Game:onJoystickReleased( params )
end