module( ..., package.seeall )
require "core"
Jumper = require "lib.jumper.jumper"
loader = require "lib.AdvTiledLoader.Loader"
require "lib.luabit.bit"
local SH = require( "lib.broadphase.spatialhash" )

local MAP_COLLISION_LAYER_NAME = "Collision"


GameRules = class( "GameRules" )
function GameRules:initialize()
	self.camera_x = 0
	self.camera_y = 0
	self.map = nil
	self.collision_layer = nil
	self.spawn = {x=0, y=0}
	self.entity_factory = EntityFactory:new()
	self.entity_manager = EntityManager:new()
	self.pathfinder = nil

	-- the current wave level
	self.level = 0
	self.total_waves = 0

	-- total number of enemies this level
	self.wave_enemies = 0
	self.enemies_destroyed = 0
	self.last_bonus = 0
	self.total_score = 0

	-- need to register all entity classes somewhere; this is not the best spot :/
	self.entity_factory:registerClass( "WorldEntity", core.WorldEntity )
	self.entity_factory:registerClass( "AnimatedSprite", core.AnimatedSprite )
	self.entity_factory:registerClass( "PathFollower", core.PathFollower )
	self.entity_factory:registerClass( "func_spawn", core.func_spawn )
	self.entity_factory:registerClass( "Enemy", core.Enemy )
	self.entity_factory:registerClass( "func_target", core.func_target )
	self.entity_factory:registerClass( "Bullet", core.Bullet )
	self.entity_factory:registerClass( "Player", core.Player )

	self.sounds = {}
	self:loadSounds( "assets/sounds/sounds.conf" )

	self.data = {}
	self:loadData( "assets/gamerules.conf" )
end

function GameRules:loadSounds( path )
	logging.verbose( "Loading sounds..." )
	if love.filesystem.exists( path ) then
		local sounds = json.decode( love.filesystem.read( path ) )
		for k,v in pairs(sounds) do
			logging.verbose( "\t'" .. k .. "' -> '" .. tostring(v) .. "'" )
			self.sounds[ k ] = love.audio.newSource( v, "static" )
		end
	end
end

function GameRules:playSound( name )
	if self.sounds then
		local source = self.sounds[ name ]
		love.audio.rewind( source )
		love.audio.play( source )
	end
end

function GameRules:loadData( path )
	logging.verbose( "Loading entity rules..." )
	if love.filesystem.exists( path ) then
		self.data = json.decode( love.filesystem.read( path ) )
		for k,v in pairs(self.data) do
			logging.verbose( "\tloaded '" .. k .. "'" )
		end
	end
end

function GameRules:prepareForNextWave()
	self.level = self.level + 1
	self.enemies_destroyed = 0

	--logging.verbose( "Preparing for wave: " .. self.level )
	
	if self.data[ "waves" ] and self.data[ "waves" ][ self.level ] then
		local wave_data = self.data[ "waves" ][ self.level ]
		self.wave_enemies = wave_data.wave_enemies
		self.total_waves = #self.data[ "waves" ]
		self.current_enemy_value = wave_data.enemy_value
		self.target_bonus = wave_data.target_bonus
	else
		logging.warning( "Unable to load data for wave '" .. self.level .. "'" )
	end

	-- update func_spawn entities
	local fs = self.entity_manager:findFirstEntityByName( "func_spawn" )
	if fs then
		fs.max_entities = self.wave_enemies
	end
end

function GameRules:beatLastWave()
	return self.level >= self.total_waves
end

function GameRules:updateScore( target )
	-- this takes into account the target health and scales the bonus value based on that percentage
	local health_percent = target.health / target.max_health
	self.last_bonus = health_percent * self.target_bonus
	self.total_score = self.total_score + self.last_bonus
end

function GameRules:dataForKeyLevel( key, level )
	if self.data[ key ] and self.data[ key ][ level ] then
		return self.data[ key ][ level ]
	end

	return nil
end

function GameRules:onEnemyDestroyed( entity )
	self.enemies_destroyed = self.enemies_destroyed + 1
	self.total_score = self.total_score + self.current_enemy_value
end






function GameRules:initCollision()
	local grid_width = self.map.width
	local grid_height = self.map.height
	self.grid = SH:new( grid_width, grid_height, 64 )
end

function GameRules:addCollision( entity )
	self.grid:addShape( entity )
end

function GameRules:removeCollision( entity )
	self.grid:removeShape( entity )
end

function GameRules:updateCollision( params )
	local colliding = self.grid:getCollidingPairs( self.entity_manager:allEntities() )
	--logging.verbose( "colliders: " .. #colliding)

	table.foreach( colliding,
	function(_, v) 
		if (v[1].collision_mask > 0) and (v[2].collision_mask > 0) and (bit.band(v[1].collision_mask,v[2].collision_mask) > 0) then 
			
			--logging.verbose( self.collision_mask .. " vs " .. params.other.collision_mask )
			v[1]:onCollide( {gamerules=self, other=v[2]} )	
			v[2]:onCollide( {gamerules=self, other=v[1]} )
		end	end	)
end



function GameRules:loadMap( mapname )
	loader.path = "assets/maps/"

	-- try and load the map...
	self.map = loader.load( mapname )
	self.map.drawObjects = false

	-- setup collision stuff
	self:initCollision()

	-- this crashes on a retina mbp if true; perhaps something to do with the GPUs switching?
	self.map.useSpriteBatch = false


	-- cache collision layer and disable rendering
	self.collision_layer = self.map.layers[ MAP_COLLISION_LAYER_NAME ]


	self.basic_collision_tile = nil


	-- use collision map for path finding
	for y=1, self.map.height do
		local row = {}
		for x=1, self.map.width do
			local tile = self.collision_layer( x, y )
			if tile then
				self.basic_collision_tile = tile
				break
			end
		end
	end	

	-- scan through map properties
	class_tiles = {}
	for id, tile in pairs(self.map.tiles) do
		for key, value in pairs(tile.properties) do
			--logging.verbose( key .. " -> " .. value .. "; tile: " .. tile.id )
			if not class_tiles[ tile.id ] then
				class_tiles[ tile.id ] = {}
			end

			class_tiles[ tile.id ][ key ] = value
		end
	end

	-- iterate through all layers
	for name, layer in pairs(self.map.layers) do
		--logging.verbose( "Searching in layer: " .. name )
		for x, y, tile in layer:iterate() do
			if tile then
				if class_tiles[ tile.id ] then
					--logging.verbose( "Properties for tile at: " .. x .. ", " .. y )
					--for key,value in pairs( class_tiles[ tile.id ] ) do
					--	logging.verbose( key .. " -> " .. value )
					--end

					self:spawnEntityAtTileWithProperties( layer, x, y, class_tiles[ tile.id ] )
				end
			end
		end
	end

	local walkable_map = {}
	if self.collision_layer then
		-- hide collision layer by default
		self.collision_layer.visible = false

		-- use collision map for path finding
		for y=1, self.map.height do
			local row = {}
			for x=1, self.map.width do
				local tile = self.collision_layer( x, y )


				local is_blocked = 0
				if tile then
					is_blocked = 1

					if tile.properties then
						--for key, value in pairs(tile.properties) do
						--	logging.verbose( key .. " -> " .. tostring(value) )
						--end
						if tile.properties.walkable then
							is_blocked = 0
						end
					end
				end

				-- insert the value into this row
				table.insert( row, is_blocked )			
			end
			-- insert this row into the grid
			table.insert( walkable_map, row )		
		end
	end




	if #walkable_map > 0 then
		self.pathfinder = Jumper( walkable_map, 0, true )
		--self.pathfinder:setHeuristic( "DIAGONAL" )
		self.pathfinder:setMode( "ORTHOGONAL" )
	end
	
	--self.pathfinder:setAutoFill( true )

	--[[
	local path, cost = self.pathfinder:getPath( 1, 1, 23, 23 )

	-- print out all steps in the path
	if path and cost then
		for a, b in pairs(path) do
			--logging.verbose( "i: " .. a .. " -> " .. b )
			logging.verbose( "step " .. a .. " ( " .. b.x .. ", " .. b.y .. " )" )
		end
	end
	--]]

	

end

function GameRules:colorForHealth( health, max_health )
	local health_percent = (health/max_health) * 100
	if health_percent > 75 then
		return 0, 255, 0, 255
	elseif health_percent > 49 then
		return 255, 255, 0, 255
	elseif health_percent > 29 then
		return 255, 128, 0, 255
	else	
		return 255, 0, 0, 255
	end
end

function GameRules:colorForTimer( timeleft )
	if timeleft >= 10 then
		return 255, 255, 255, 255
	else
		return 255, 0, 0, 255
	end
end


-- determine if a tile is within the map and is valid
function GameRules:isTileWithinMap( tile_x, tile_y )
	if tile_x < 0 or tile_x > self.map.width then
		return false
	end

	if tile_y < 0 or tile_y > self.map.height then
		return false
	end

	return true
end


function GameRules:getCollisionTile( tx, ty )
	if self.collision_layer then
		return self.collision_layer( tx, ty )
	end

	return nil
end

-- these two functions are identical right now, but this may change...
function GameRules:isTilePlaceable( tile_x, tile_y )
	if not self:isTileWithinMap( tile_x, tile_y ) then
		return false
	end

	return self:getCollisionTile( tile_x, tile_y ) == nil
end

function GameRules:isTileWalkable( tile_x, tile_y )
	if not self:isTileWithinMap( tile_x, tile_y ) then
		return false
	end

	return self:getCollisionTile( tile_x, tile_y ) == nil	
end

-- returns path and cost or nil, nil if there is no path
function GameRules:getPath( start_x, start_y, end_x, end_y )
	-- verify target tiles are correct
	if not self:isTileWalkable( start_x, start_y ) then
		logging.warning( "start node is out of map bounds" )
		return nil, nil
	end

	if not self:isTileWalkable( end_x, end_y) then
		logging.warning( "end node is out of map bounds" )
		return nil, nil
	end

	return self.pathfinder:getPath( start_x, start_y, end_x, end_y )
end

function GameRules:__tostring()
	return "GameRules[]"
end

function GameRules:warpCameraTo( x, y )
	self.camera_x = x
	self.camera_y = y
end

function GameRules:getCameraPosition()
	return self.camera_x, self.camera_y
end

function GameRules:setCameraPosition( camera_x, camera_y )
	self.camera_x = camera_x
	self.camera_y = camera_y
end

function GameRules:spawnEntity( entity, world_x, world_y, properties )
	if world_x then
		entity.world_x = world_x
	end

	if world_y then
		entity.world_y = world_y
	end

	if properties == nil then
		properties = {}
	end

	-- make sure our entity is spawned properly
	entity:onSpawn( {gamerules=self, properties=properties} )

	-- load entity properties based on the level
	local data = self:dataForKeyLevel( entity.class.name, self.level )

	-- as a fail-safe, if this level doesn't explicitly exist, let's just use the first one we have.
	if not data then
		data = self:dataForKeyLevel( entity.class.name, 1 )
	end

	if data then
		entity:loadProperties( data )
	else
		--logging.warning( "could not find properties for class '" .. entity.class.name .. "' at level " .. self.level )
	end

	-- this entity is now managed.
	self.entity_manager:addEntity( entity )
end

function GameRules:spawnEntityAtTileWithProperties( layer, tile_x, tile_y, properties )
	local classname = properties[ "classname" ]
	if classname then
		properties[ "classname" ] = nil
		--logging.verbose( "GameRules: spawning entity '" .. classname .. "' at " .. tile_x .. ", " .. tile_y )

		if classname == "info_player_spawn" then
			-- yadda, yadda, yadda; make this not a HACK
			self.spawn = { x = tile_x, y = tile_y }
			layer:set( tile_x, tile_y, nil )
		else
			local entity = self.entity_factory:createClass( classname )
			if entity then
					-- set the world position for the entity from the tile coordinates
				entity.world_x, entity.world_y = self:worldCoordinatesFromTileCenter( tile_x, tile_y )

				self:spawnEntity( entity, entity.world_x, entity.world_y, properties )

				--logging.verbose( "-> entity '" .. classname .. "' is at " .. entity.world_x .. ", " .. entity.world_y )
				--logging.verbose( "-> entity tile at " .. entity.tile_x .. ", " .. entity.tile_y )

				-- remove this tile from the layer
				layer:set( tile_x, tile_y, nil )

				-- if an entity spawns with a valid collision mask
				-- make sure we place a collision tile at its location
				if entity.collision_mask > 0 then
					self.collision_layer:set( tile_x, tile_y, self.basic_collision_tile )
				end
			end
		end
	else
		logging.warning( "'classname' is required to spawn an entity! Ignoring tile at " .. tile_x .. ", " .. tile_y )
	end
end

function GameRules:snapCameraToPlayer( player )
	local window_width, window_height = love.graphics.getWidth(), love.graphics.getHeight()
	self:warpCameraTo( -(player.world_x-(window_width/2)), -(player.world_y-(window_height/2)) )
end



function GameRules:drawWorld()
	love.graphics.push()
	love.graphics.setColor(255,255,255,255)
	local cx, cy = self:getCameraPosition()
	local ftx, fty = math.floor(cx), math.floor(cy)
	love.graphics.translate(ftx, fty)

	self.map:autoDrawRange( ftx, fty, 1, 50 )

	self.map:draw()
	--love.graphics.rectangle("line", self.map:getDrawRange())
	love.graphics.pop()	
end

function GameRules:drawEntities( params )
	self.entity_manager:sortForDrawing()

	love.graphics.push()
	love.graphics.setColor( 255, 255, 255, 255 )
	params.gamerules = self
	self.entity_manager:eventForEachEntity( "onDraw", params )
	love.graphics.pop()	
end

-- -------------------------------------------------------------
-- there are three coordinate systems:
-- tile coordinates: A 1-based coordinate pair referring to a tile in the map: (1, 3)
-- world coordinates: The actual pixels converted tile coordinates. This need not align anywhere to a tile for smooth world movements. This is offset by tileWidth/2 in the x direction.
-- screen coordinates: The actual pixels mapped to the window. These values should be floored for best drawing quality

-- coordinate system functions
function GameRules:worldCoordinatesFromTileCenter( tile_x, tile_y )

	--[[
	-- ISOMETRIC
	-- input tile coordinates are 1-based, so decrement these
	local tx, ty = tile_x, tile_y

	-- we need to further offset the returned value by half the entire map's width to get the correct value
	local drawX = ((self.map.width * self.map.tileWidth) / 2) + math.floor(self.map.tileWidth/2 * (tx - ty))
	local drawY = math.floor(self.map.tileHeight/2 * (tx + ty)) + (self.map.tileHeight/2)
	return drawX, drawY
	--]]


	return (self.map.tileWidth * tile_x) + self.map.tileWidth/2, (self.map.tileHeight * tile_y) + self.map.tileHeight/2
end

-- worldToScreen conversion
function GameRules:worldToScreen( world_x, world_y )
	return math.floor(world_x + self.camera_x), math.floor(world_y + self.camera_y)
end

function GameRules:screenToWorld( screen_x, screen_y )
	return (screen_x - self.camera_x), (screen_y - self.camera_y)
end

function GameRules:tileGridFromWorld( world_x, world_y )
	local ix, iy = self.map:fromIso( world_x, world_y )
	return ix, iy
	--return math.floor(ix/self.map.tileHeight), math.floor(iy/self.map.tileHeight)	
end

function GameRules:tileCoordinatesFromWorld( world_x, world_y )
	--local ix, iy = self.map:toIso( world_x - (self.map.tileWidth/2), world_y )
	return math.floor(world_x/self.map.tileWidth), math.floor(world_y/self.map.tileHeight)
end

function GameRules:tileCoordinatesFromMouse( mouse_x, mouse_y )
	local wx, wy = self:screenToWorld( mouse_x, mouse_y )
	return self:tileCoordinatesFromWorld( wx, wy )
end

function GameRules:worldCoordinatesFromMouse( mouse_x, mouse_y )
	return self:screenToWorld( mouse_x, mouse_y )
end


function GameRules:removeEntity(entity)
	self.entity_manager:removeEntity( entity )
	self:removeCollision(entity)
end

function GameRules:onUpdate(params)
	params.gamerules = self
	self.entity_manager:eventForEachEntity( "onUpdate", params )


	self:updateCollision(params)
end

function GameRules:findMinimumDisplacementVector( a, b )
	-- get direction from this entity to the other
	local dx = b.world_x - a.world_x
	local dy = b.world_y - a.world_y
	return -dx, -dy
end

function GameRules:handleMovePlayerCommand( command, player )
	-- determine if the sprite is moving diagonally
	-- if so, tweak their speed so it doesn't look strange
	--[[
	--> ISOMETRIC ONLY
	local is_diagonal = false
	local is_ns = command.up or command.down
	local is_ew = command.left or command.right

	is_diagonal = is_ns and is_ew
	local move_speed = command.move_speed
	if is_diagonal then
		move_speed = command.move_speed * 0.5
	end
	--]]
	local move_speed = command.move_speed

	-- see what other shapes are in the way...

	local colliding = {}
	--local colliding = self.grid:getCollidingPairs( {player} )
	--table.foreach(colliding,
	--function(_,v) print(( "Shape(%d) collides with Shape(%d)"):format(v[1].id, v[2].id)) end)

	local closest_shape = nil
	local min_dist = 10000
	local dirx, diry
	local minx = move_speed
	local miny = move_speed


	for _, v in pairs(colliding) do
		local other = v[2]

		-- get direction from this entity to the other
		local dx = other.world_x - player.world_x
		local dy = other.world_y - player.world_y
		local len = math.sqrt( dx*dx + dy*dy )
		if len < min_dist then
			min_dist = len
			closest_shape = other
			dirx = dx / len
			diry = dy / len
			minx = dx
			miny = dy
			--minx, miny = self:findMinimumDisplacementVector(player, other)
		end
	end



	-- get the next world position of the entity
	local nwx, nwy = player.world_x, player.world_y

	if command.up then nwy = player.world_y - (miny * command.dt) end
	if command.down then nwy = player.world_y + (miny * command.dt) end
	if command.left then nwx = player.world_x - (minx * command.dt) end
	if command.right then nwx = player.world_x + (minx * command.dt) end

	if closest_shape then
		logging.verbose( "Closest shape is: " .. tostring(closest_shape))
		logging.verbose( "Dir: " .. tostring(dirx) .. ", " .. tostring(diry) )
	end

	-- could offset by sprite's half bounds to ensure they don't intersect with tiles
	local tx, ty = self:tileCoordinatesFromWorld( nwx, nwy )
	local tile = self:getCollisionTile( tx, ty )

	-- for now, just collide with tiles that exist on the collision layer.
	if not tile then

		player.world_x, player.world_y = nwx, nwy
	end
	
	if command.up or command.down or command.left or command.right then
		player:setDirectionFromMoveCommand( command )
		--player:playAnimation( "run" )
		player.is_attacking = false
	elseif not player.is_attacking then
		--player:playAnimation( "idle" )
	end

	
	player.tile_x, player.tile_y = self:tileCoordinatesFromWorld( player.world_x, player.world_y )
end

-- -------------------------------------------------------------
-- EntityManager
-- Encapsulate common functions with entities; manage a list of them, call events, etc.
EntityManager = class( "EntityManager" )

function EntityManager:initialize()
	self.entity_list = {}
end

function EntityManager:addEntity( e )
	table.insert( self.entity_list, e )
	e.id = #self.entity_list
end

function sortDescendingDepth(a,b)
	return a.world_y < b.world_y
end

function EntityManager:entityCount()
	return # self.entity_list
end

function EntityManager:removeEntity( e )
	-- when sorting normal tables in lua, we can't maintain the association of keys to values
	-- instead, we'll just do a linear search
	for index=1, #self.entity_list do
		if self.entity_list[ index ] == e then
			table.remove( self.entity_list, index )
			break
		end
	end
end

function EntityManager:findFirstEntityByName( name )
	for index, entity in pairs(self.entity_list) do
		if entity.class.name == name then
			return entity
		end
	end

	return nil
end

function EntityManager:allEntities()
	return self.entity_list
end

-- sort the entities in descending depth order such that lower objects in the screen are drawn in front
function EntityManager:sortForDrawing()
	table.sort( self.entity_list, sortDescendingDepth )
end

function EntityManager:eventForEachEntity( event_name, params )
	--logging.verbose( "iterating through for event: " .. event_name )
	for index, entity in pairs(self.entity_list) do
		local fn = entity[ event_name ]
		if fn ~= nil and entity:respondsToEvent( event_name, params ) then
			-- call this with the instance, then parameters table
			fn( entity, params )
		end
	end
end

-- -------------------------------------------------------------
-- EntityFactory
-- Factory pattern for registering and creating game entities
EntityFactory = class( "EntityFactory" )
function EntityFactory:initialize()
	self.class_by_name = {}
end

function EntityFactory:registerClass( class_name, creator )
	self.class_by_name[ class_name ] = creator
end

function EntityFactory:findClass( class_name )
	if self.class_by_name[ class_name ] then 
		return self.class_by_name[ class_name ]
	end

	
	return nil
end

function EntityFactory:createClass( class_name )
	local instance = nil

	if self.class_by_name[ class_name ] then
		local create_class = self.class_by_name[ class_name ]
		instance = create_class:new()
	else
		logging.warning( "Unable to find class named '" .. class_name .. "'!" )
	end

	return instance
end


