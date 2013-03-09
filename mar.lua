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



-- Game class
Game = class( "Game" )
function Game:initialize( gamerules, config, fonts )
	-- supplied from the main love entry point
	self.gamerules = gamerules
	self.config = config
	self.fonts = fonts

	self.helpscreen = HelpScreen( fonts )
	
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



	self.state = GAME_STATE_PLAY

	if self.state == GAME_STATE_HELP then
		self.actions[ " " ] = self.nextState
		love.mouse.setVisible( true )
	else
		love.mouse.setVisible( false )
	end


	self.cell_layer = nil
	
	self.ca_interval = 0.1
	self.next_ca = self.ca_interval
end


function Game:nextState()
	if self.actions[ " " ] then
		self.actions[ " " ] = nil
	end
--[[
	if self.state == GAME_STATE_HELP then
		self.source:stop()
		self.source:rewind()
		self.source:play()
		self.state = GAME_STATE_PLAY
		self:onLoad( {gamerules=self.gamerules} )
		self.gamerules:prepareForGame()
		self.gamerules:getPlayer().visible = true
	elseif self.state == GAME_STATE_WIN then
		self.source:stop()
		self.source:rewind()
		self.source:play()		
		self.state = GAME_STATE_PLAY
		self:onLoad( {gamerules=self.gamerules} )
		self.gamerules:prepareForGame()
		self.gamerules:getPlayer().visible = true
	elseif self.state == GAME_STATE_FAIL then
		self.source:stop()
		self.source:rewind()
		self.source:play()	
		self.state = GAME_STATE_PLAY
		self:onLoad( {gamerules=self.gamerules} )
		self.gamerules:prepareForGame()
		self.gamerules:getPlayer().visible = true
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
	self.gamerules:loadMap( self.config.map )	
	local player = self.gamerules.entity_factory:createClass( "Player" )

	self:warpPlayerToSpawn( player )
	self.gamerules:setPlayer( player )
	self.gamerules:spawnEntity( player, nil, nil, nil )

	if not self.helpscreen_loaded and self.state == GAME_STATE_HELP then
		params.game = self
		params.gamerules = self.gamerules
		self.helpscreen:prepareToShow( params )	
		self.helpscreen_loaded = true
	end


	-- local enemy = self.gamerules.entity_factory:createClass( "Enemy" )
	-- self.gamerules:spawnEntity( enemy, 120, 60, nil )
	-- enemy.velocity.x = 30

	self.cellsw = self.gamerules.map.width
	self.cellsh = self.gamerules.map.height

	self.cell_layer = self.gamerules.map.layers["cells"]
	if self.cell_layer then

		self.cell = self.cell_layer:get(0,0)
		-- empty all grid cells
		-- for x,y, tile in self.cell_layer:iterate() do
		-- 	self.cell_layer:set(x, y, nil)
		-- end

		-- create a snapshot
		self.cell_data = self:clone_data( self.cell_layer )

		local n = self:neighbors( self.cell_data, 4, 4 )
		logging.verbose( "neighbors: " .. #n )

		--self:copy_data( self.cell_data, self.cell_layer )
	end
end


function Game:clone_data( layer )
	local data = {}

	for x = 1, self.cellsw do
		for y = 1, self.cellsh do
			if not data[x] then
				data[x] = {}
			end
			if not data[x][y] then
				data[x][y] = {}
			end

			data[x][y] = nil

			local t = layer:get(x, y)
			if t then
				data[x][y] = 1
			end
		end
	end

--[[
	for x, y, tile in layer:iterate() do
		if not data[x] then
			data[x] = {}
		end
		if not data[x][y] then
			data[x][y] = {}
		end
		logging.verbose( "huzzah!" )
		data[x][y] = 1
	end
--]]

	return data
end



function Game:copy_data( data, layer )
	for x = 1, self.cellsw do
		for y = 1, self.cellsh do
			local cell = nil
			if data[x] and data[x][y] then
				cell = self.cell	
			end

			layer:set( x, y, cell )
		end
	end
end

function Game:inWidthRange(x)
	return x ~= nil and x >= 1 and x < self.cellsw
end

function Game:inHeightRange(x)	
	return y ~= nil and y >= 1 and y < self.cellsh
end

function Game:cell_at( data, x, y )
	if data[x] and data[x][y] then
	--if self:inWidthRange(x) and self.inHeightRange(y) then
		return data[x][y]
	end

	--logging.verbose( "not in range: " .. x .. ", " .. y )

	return nil
end

-- get the 8 neighbors of cell at x, y in data
function Game:neighbors( data, x, y )
	local neighbors = {}
	local n = nil
	-- upper left
		n = self:cell_at(data, x-1, y-1)
		if n then
			table.insert( neighbors, n )
		end

	-- top center
		n = self:cell_at(data, x, y-1)
		if n then
			table.insert( neighbors, n )
		end	

	-- upper right
		n = self:cell_at(data, x+1, y-1)
		if n then
			table.insert( neighbors, n )
		end

	-- left
		n = self:cell_at(data, x-1, y)
		if n then
			table.insert( neighbors, n )
		end	

	-- right
		n = self:cell_at(data, x+1, y)
		if n then
			table.insert( neighbors, n )
		end

	-- lower left
		n = self:cell_at(data, x-1, y+1)
		if n then
			table.insert( neighbors, n )
		end

	-- bottom center
		n = self:cell_at(data, x, y+1)
		if n then
			table.insert( neighbors, n )
		end

	-- lower right
		n = self:cell_at(data, x+1, y+1)
		if n then
			table.insert( neighbors, n )
		end

	return neighbors
end


function Game:evaluate_ca()
	-- make a copy of the data
	local last = core.util.deepcopy( self.cell_data )
	local next_data = core.util.deepcopy( self.cell_data )

	for x = 1, self.cellsw do
		for y = 1, self.cellsh do
			local neighbors = self:neighbors( last, x, y )
			local neighbors_count = #neighbors

			if last[x][y] then -- alive cell
				if neighbors_count < 2 or neighbors_count > 3 then
					-- cell dies due to overcrowding or over-population
					next_data[x][y] = nil
				end
			else -- dead cell
				-- a cell can be born
				if neighbors_count == 3 then
					next_data[x][y] = 1
				end
			end
		end
	end

	self:copy_data( next_data, self.cell_layer )
	self.cell_data = next_data
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
	--[[
	self.next_ca = self.next_ca - params.dt
	if self.next_ca <= 0 then
		self.next_ca = self.ca_interval
		self:evaluate_ca()
	end
	--]]
	

	params.gamestate = self.state

	if self.state == GAME_STATE_PLAY then
		local player = self.gamerules:getPlayer()
		self.gamerules:onUpdate( params )



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
		self.gamerules:snapCameraToPlayer( player )
		self:updatePlayerDirection()
	elseif self.state == GAME_STATE_HELP then
		self.gamerules:onUpdate( params )

		params.game = self
		self.helpscreen:onUpdate( params )
	end

end



function Game:onDraw( params )
	--love.graphics.setBackgroundColor( 39, 82, 93, 255 )
	love.graphics.setBackgroundColor( 36, 56, 53, 255 )
	love.graphics.clear()

	local player = self.gamerules:getPlayer()
	params.gamestate = self.state

	if self.state == GAME_STATE_PLAY then
		self.gamerules:drawWorld()
		-- draw entities here
		self.gamerules:drawEntities( params )
		self.gamerules:drawLightmap( params )


		love.graphics.setFont( self.fonts[ "text16" ] )

		-- draw the top overlay bar
		love.graphics.setColor( 0, 0, 0, 64 )
		local height = 32
		love.graphics.rectangle( "fill", 0, 0, love.graphics.getWidth(), height )
		love.graphics.setFont( self.fonts[ "text16" ] )
		love.graphics.setColor( 255, 255, 255, 255 )
		love.graphics.print( "Light Level: " .. self.gamerules:getPlayer().light_level, 10, 5 )


		--love.graphics.print( "Treasure Saved: " .. tostring(self.gamerules:originalTotalChests()-self.gamerules:totalChestsRemaining()) .. " / " .. tostring(self.gamerules:originalTotalChests()), 540, 5 )	

		--love.graphics.print( "Total Entities: " .. self.gamerules.entity_manager:entityCount(), 10, 50 )
	elseif self.state == GAME_STATE_WIN then
		self.gamerules:drawWorld()
		self.gamerules:drawEntities( params )
		love.graphics.setColor( 0, 0, 0, 64 )
		love.graphics.rectangle( "fill", 0, 0, love.graphics.getWidth(), love.graphics.getHeight() )	

		love.graphics.setFont( self.fonts[ "text32" ] )
		love.graphics.setColor( 255, 255, 255, 255 )

		love.graphics.printf( "You collected all the treasure!", 0, 120, love.graphics.getWidth(), "center" )
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

		love.graphics.printf( "Oh noes! You were eaten by a shark!", 0, 120, love.graphics.getWidth(), "center" )

		love.graphics.setColor( 255, 255, 255, 255 )
		love.graphics.printf( "Press <space> to try again", 0, 250, love.graphics.getWidth(), "center" )
		love.graphics.printf( "Press <esc> to exit", 0, 300, love.graphics.getWidth(), "center" )
	elseif self.state == GAME_STATE_HELP then
		self.gamerules:getPlayer().visible = false
		self.gamerules:drawEntities( params )

		params.game = self
		self.helpscreen:onDraw( params )
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
	if self.actions[ params.key ] then
		self.actions[ params.key ]( self )
	end
end

function Game:onKeyReleased( params )
	--self:evaluate_ca()
end

function Game:onMousePressed( params )
	if params.button == "l" then
		local mx, my = love.mouse.getPosition()
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