module( ..., package.seeall )
require "core"
logging = core.logging
Jumper = require "lib.jumper.jumper"
loader = require "lib.AdvTiledLoader.Loader"

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

	-- need to register all entity classes somewhere; this is not the best spot :/
	self.entity_factory:registerClass( "WorldEntity", core.entity.WorldEntity )
	self.entity_factory:registerClass( "AnimatedSprite", core.entity.AnimatedSprite )
	self.entity_factory:registerClass( "PathFollower", core.entity.PathFollower )
	self.entity_factory:registerClass( "func_spawn", core.entity.func_spawn )
	self.entity_factory:registerClass( "Enemy", core.entity.Enemy )
	self.entity_factory:registerClass( "func_target", core.entity.func_target )

end

function GameRules:loadMap( mapname )
	print( "loading gamerules map" )
	loader.path = "assets/maps/"

	-- create a spatial hash
	self.grid = SH:new( 4000, 4000, 64 )

	self.map = loader.load( mapname )
	self.map.drawObjects = false

	-- this crashes on a retina mbp if true; perhaps something to do with the GPUs switching?
	self.map.useSpriteBatch = false

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
					--for key,value in pairs( class_tiles[ tile.id ] ) do
					--	logging.verbose( key .. " -> " .. value )
					--end

					self:spawnEntityAtTileWithProperties( layer, x, y, class_tiles[ tile.id ] )
				end
			end
		end
	end


	-- cache collision layer and disable rendering
	self.collision_layer = self.map.layers[ MAP_COLLISION_LAYER_NAME ]

	local walkable_map = {}
	if self.collision_layer then
		--self.collision_layer.visible = false

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

	self.pathfinder = Jumper( walkable_map, 0, true )
	self.pathfinder:setHeuristic( "DIAGONAL" )
	--self.pathfinder:setMode( "ORTHOGONAL" )
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

function GameRules:colorForHealth( health )
	if health > 75 then
		return 0, 255, 0, 255
	elseif health > 50 then
		return 255, 255, 0, 255
	elseif health > 25 then
		return 255, 128, 0, 255
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

function GameRules:spawnEntityAtTileWithProperties( layer, tile_x, tile_y, properties )
	local classname = properties[ "classname" ]
	if classname then
		properties[ "classname" ] = nil
		logging.verbose( "GameRules: spawning entity '" .. classname .. "' at " .. tile_x .. ", " .. tile_y )

		if classname == "info_player_spawn" then
			-- yadda, yadda, yadda; make this not a HACK
			self.spawn = { x = tile_x, y = tile_y }
		else
			local entity = self.entity_factory:createClass( classname )
			if entity then
				-- set the world position for the entity from the tile coordinates
				entity.world_x, entity.world_y = self:worldCoordinatesFromTileCenter( tile_x, tile_y )

				-- make sure our entity is spawned properly
				entity:onSpawn( {gamerules=self, properties=properties} )

				logging.verbose( "-> entity '" .. classname .. "' is at " .. entity.world_x .. ", " .. entity.world_y )
				logging.verbose( "-> entity tile at " .. entity.tile_x .. ", " .. entity.tile_y )

				-- this entity is now managed.
				self.entity_manager:addEntity( entity )

				-- remove this tile from the layer
				layer:set( tile_x, tile_y, nil )
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

function GameRules:drawEntities()
	self.entity_manager:sortForDrawing()

	love.graphics.push()
	love.graphics.setColor( 255, 255, 255, 255 )
	self.entity_manager:eventForEachEntity( "onDraw", {gamerules=self} )
	love.graphics.pop()	
end

-- -------------------------------------------------------------
-- there are three coordinate systems:
-- tile coordinates: A 1-based coordinate pair referring to a tile in the map: (1, 3)
-- world coordinates: The actual pixels converted tile coordinates. This need not align anywhere to a tile for smooth world movements. This is offset by tileWidth/2 in the x direction.
-- screen coordinates: The actual pixels mapped to the window. These values should be floored for best drawing quality

-- coordinate system functions
function GameRules:worldCoordinatesFromTileCenter( tile_x, tile_y )
	-- input tile coordinates are 1-based, so decrement these
	local tx, ty = tile_x, tile_y

	-- we need to further offset the returned value by half the entire map's width to get the correct value
	local drawX = ((self.map.width * self.map.tileWidth) / 2) + math.floor(self.map.tileWidth/2 * (tx - ty))
	local drawY = math.floor(self.map.tileHeight/2 * (tx + ty)) + (self.map.tileHeight/2)
	return drawX, drawY
end

-- worldToScreen conversion
function GameRules:worldToScreen( world_x, world_y )
	return math.floor(world_x + self.camera_x) - (self.map.tileWidth/2), math.floor(world_y + self.camera_y)
end

function GameRules:screenToWorld( screen_x, screen_y )
	return (screen_x - self.camera_x) + (self.map.tileWidth/2), (screen_y - self.camera_y)
end

function GameRules:tileGridFromWorld( world_x, world_y )
	local ix, iy = self.map:fromIso( world_x, world_y )
	return ix, iy
	--return math.floor(ix/self.map.tileHeight), math.floor(iy/self.map.tileHeight)	
end

function GameRules:tileCoordinatesFromWorld( world_x, world_y )
	local ix, iy = self.map:toIso( world_x - (self.map.tileWidth/2), world_y )
	return math.floor(ix/self.map.tileHeight), math.floor(iy/self.map.tileHeight)
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
	self.grid:removeShape( entity )
end

function GameRules:handleMovePlayerCommand( command, player )
	-- determine if the sprite is moving diagonally
	-- if so, tweak their speed so it doesn't look strange
	local is_diagonal = false
	local is_ns = command.up or command.down
	local is_ew = command.left or command.right

	is_diagonal = is_ns and is_ew
	local move_speed = command.move_speed
	if is_diagonal then
		move_speed = command.move_speed * 0.5
	end

	-- see what other shapes are in the way...

	local colliding = self.grid:getCollidingPairs( {player} )
	table.foreach(colliding,
		function(_,v) print(( "Shape(%d) collides with Shape(%d)"):format(v[1].id, v[2].id)) end)

	-- get the next world position of the entity
	local nwx, nwy = player.world_x, player.world_y

	if command.up then nwy = player.world_y - (move_speed * command.dt) end
	if command.down then nwy = player.world_y + (move_speed * command.dt) end
	if command.left then nwx = player.world_x - (command.move_speed * command.dt) end
	if command.right then nwx = player.world_x + (command.move_speed * command.dt) end

	-- could offset by sprite's half bounds to ensure they don't intersect with tiles
	local tx, ty = self:tileCoordinatesFromWorld( nwx, nwy )
	local tile = self:getCollisionTile( tx, ty )

	-- for now, just collide with tiles that exist on the collision layer.
	if not tile then
		player.world_x, player.world_y = nwx, nwy
	end
	
	if command.up or command.down or command.left or command.right then
		player:setDirectionFromMoveCommand( command )
		player:playAnimation( "run" )
		player.is_attacking = false
	elseif not player.is_attacking then
		player:playAnimation( "idle" )
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

-- sort the entities in descending depth order such that lower objects in the screen are drawn in front
function EntityManager:sortForDrawing()
	table.sort( self.entity_list, sortDescendingDepth )
end

function EntityManager:eventForEachEntity( event_name, params )
	--logging.verbose( "iterating through for event: " .. event_name )
	for index, entity in pairs(self.entity_list) do
		local fn = entity[ event_name ]
		if fn ~= nil then
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


