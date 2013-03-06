module( ..., package.seeall )
require "core"
local Pathfinder = require "lib.jumper.jumper.pathfinder"
loader = require "lib.AdvTiledLoader.Loader"
Tile = require "lib.AdvTiledLoader.Tile"
require "lib.luabit.bit"
local SH = require( "lib.broadphase.spatialhash" )
require "core.entityfactory"
require "core.entitymanager"

local MAP_COLLISION_LAYER_NAME = "Collision"
local MAP_GROUND_LAYER_NAME = "Ground"
local MAP_FOG_LAYER_NAME = "Fog"

local LIGHT_RADIUS = 4
local LIGHT_SCALE_FACTOR = 2

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
	self.entity_factory:registerClass( "Bullet", core.Bullet )
	self.entity_factory:registerClass( "Player", core.Player )
	self.entity_factory:registerClass( "Breakable", core.Breakable )
	self.entity_factory:registerClass( "func_light", core.func_light )
	
	self.sounds = {}
	self.sound_data = {}
	self:loadSounds( "assets/sounds/sounds.conf" )

	self.data = {}
	self:loadData( "assets/gamerules.conf" )

	self.target = nil
	self.player = nil
	
	self.last_level = {}

	love.audio.setVolume( 1.0 )

	self.min_chests = 3
	self.num_chests = 3

	self.light_layer = love.graphics.newCanvas()
	self.lightmap = love.graphics.newImage( "assets/sprites/lightmap.png" )
end


function GameRules:loadSounds( path )
	logging.verbose( "Loading sounds..." )
	if love.filesystem.exists( path ) then
		self.sound_data = json.decode( love.filesystem.read( path ) )
		for k,sound_data in pairs(self.sound_data) do
			sd = {}
			for key, value in pairs(sound_data) do
				logging.verbose( "\t'" .. key .. "' -> '" .. tostring(value) .. "'" )
				sd[ key ] = value
			end

			if sd["type"] == "static" then
				self.sounds[ k ] = love.audio.newSource( sd["path"], sd["type"] )
			end
		end
	end
end


function GameRules:originalTotalChests()
	return self.num_chests
end

function GameRules:totalChestsRemaining()
	local chests = self.entity_manager:findAllEntitiesByName( "func_chest" )
	return #chests	
end


function GameRules:createSource( name )
	local sound_data = self.sound_data[ name ]
	return love.audio.newSource( sound_data["path"], sound_data["type"] )
end

function GameRules:playSound( name )
	if self.sounds then
		local source = self.sounds[ name ]
		love.audio.rewind( source )
		love.audio.play( source )
		return source
	end

	return nil
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

function GameRules:preparePlayerForNextWave( player )
	local pd = self:dataForKeyLevel( "Player", self.level+1 )
	if pd then
		player.attack_damage = pd.attack_damage + (self.place_points / (self.point_base+1))
		player.attack_delay = pd.attack_delay - ((self.place_points / 2000) * (self.level/5))
	end
end


function GameRules:prepareForGame()
	local chests = self.entity_manager:findAllEntitiesByName( "func_chest" )
	self.num_chests = 0
	local items_to_remove = {}

	--logging.verbose( "total chests: " .. #chests .. ", num chests: " .. self.num_chests )

	for i=1,#chests do
		local value = math.random()

		if value > 0.5 and self.num_chests > self.min_chests then
			table.insert( items_to_remove, chests[i] )
		else
			self.num_chests = self.num_chests + 1
		end
	end

	for _,v in pairs(items_to_remove) do
		self:removeEntity( v )
	end
end



function GameRules:beatLastWave()
	return self.level >= self.total_waves
end

function GameRules:updateScore( target )
	-- this takes into account the target health and scales the bonus value based on that percentage
	local health_percent = target.health / target.max_health
	self.last_bonus = math.floor(health_percent * self.target_bonus)
	self.total_score = self.total_score + self.last_bonus
	self.place_points = self.place_points + self.wave_enemies
end

function GameRules:dataForKeyLevel( key, level )
	--logging.verbose( "request: " .. key .. " level: " .. level )
	if self.data[ key ] and self.data[ key ][ level ] then
		return self.data[ key ][ level ]
	elseif self.data[ key ] then
		local level = #self.data[ key ]
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
	if self.grid then
		self.grid:addShape( entity )
	end
end

function GameRules:removeCollision( entity )

	if self.collision_layer then
		self.collision_layer:set( entity.tile_x, entity.tile_y, nil )
	end

	if self.grid then
		self.grid:removeShape( entity )
	end
end

function GameRules:updateCollision( params )
	if self.grid then
		local colliding = self.grid:getCollidingPairs( self.entity_manager:allEntities() )
		table.foreach( colliding,
		function(_, v) 
			if (v[1].collision_mask > 0) and (v[2].collision_mask > 0) and (bit.band(v[1].collision_mask,v[2].collision_mask) > 0) then 
				v[1]:onCollide( {gamerules=self, other=v[2]} )	
				v[2]:onCollide( {gamerules=self, other=v[1]} )

			end	end	)
	end
end

function GameRules:updateWalkableMap( )
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
		self.pathfinder = Pathfinder( walkable_map, 0, true )
		self.pathfinder:setMode( "ORTHOGONAL" )
	end
end

function GameRules:loadMap( mapname )
	
	self.entity_manager.entity_list = {}


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


	local game_layer = self.map.layers[ "Game" ]
	if game_layer then
		for x, y, tile in game_layer:iterate() do
			--logging.verbose( "Properties for tile at: " .. x .. ", " .. y )
			properties = {}
			for key,value in pairs( tile.properties ) do
				--logging.verbose( key .. " -> " .. value )
				properties[ key ] = value
			end

			self:spawnEntityAtTileWithProperties( game_layer, x, y, properties )

		end
	end

	self:updateWalkableMap()
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
	if self.map then
		if tile_x < 0 or tile_x > self.map.width-1 then
			return false
		end

		if tile_y < 0 or tile_y > self.map.height-1 then
			return false
		end
	end

	return true
end


function GameRules:getCollisionTile( tx, ty )
	if self.collision_layer then
		return self.collision_layer( tx, ty )
	end

	return nil
end


function GameRules:setPlayer( player )
	self.player = player
end

function GameRules:getPlayer()
	return self.player
end

function GameRules:calculateEntityDistance( e1, e2 )
	local dx, dy = (e2.world_x - e1.world_x), (e2.world_y - e1.world_y)
	return math.sqrt(dx*dx + dy*dy)
end

-- these two functions are identical right now, but this may change...
function GameRules:isTilePlaceable( tile_x, tile_y )
	if not self:isTileWithinMap( tile_x, tile_y ) then
		return false
	end

	if self.place_points == 0 then
		return false
	end

	-- don't let player place tile too close to target
	local dx, dy = self:calculateEntityDistanceToTarget( tile_x, tile_y )
	if math.abs(dx) < 2 and math.abs(dy) < 2 then
		return false
	end

	-- don't let them play past the crappy ui graphics; really bad hack here.
	if tile_y > 14 then
		return false
	end

	-- don't let them place on the spawn point
	if tile_x == self.spawn.x and tile_y == self.spawn.y then
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

				-- remove this tile from the layer
				layer:set( tile_x, tile_y, nil )


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


function GameRules:randomVelocity( max_x, max_y )
	local direction = math.random(100)
	if direction > 50 then
		direction = 1
	else
		direction = -1
	end

	return {x=direction*math.random(max_x), y=math.random(max_y)}
end

function GameRules:drawWorld()

	love.graphics.setCanvas()
	love.graphics.push()
	love.graphics.setColor(255,255,255,255)
	local cx, cy = self:getCameraPosition()
	local ftx, fty = math.floor(cx), math.floor(cy)
	

	love.graphics.translate( ftx, fty )
	if self.map then
		local window_width, window_height = love.graphics.getWidth(), love.graphics.getHeight()
		local tx, ty = self:tileCoordinatesFromWorld( (window_width/2)-cx, (window_height/2)-cy )

		fog = self.map.layers[ MAP_FOG_LAYER_NAME ]
		for x, y, tile in fog:circle( tx, ty, LIGHT_RADIUS, false ) do
			fog:set( x, y, nil )
		end


		self.map:autoDrawRange( ftx, fty, 1, 5 )
		self.map:draw()
	end
	
	-- love.graphics.rectangle("line", self.map:getDrawRange())
	love.graphics.pop()


	love.graphics.setCanvas( self.light_layer )
	love.graphics.setColor( 0, 0, 0, 0 )
	love.graphics.clear()
	love.graphics.setColor(255,255,255, 255)
	
	--love.graphics.rectangle('fill',0,0,100,100)

	local xoffset = (love.graphics.getWidth() / 2) - (self.lightmap:getWidth()/2) * LIGHT_SCALE_FACTOR
	local yoffset = (love.graphics.getHeight() / 2) - (self.lightmap:getHeight()/2) * LIGHT_SCALE_FACTOR	
	love.graphics.draw( self.lightmap, xoffset, yoffset, 0, LIGHT_SCALE_FACTOR, LIGHT_SCALE_FACTOR )

	love.graphics.setCanvas()
	love.graphics.setBlendMode( "multiplicative" )
	love.graphics.setColor( 255, 255, 255, 255 )
	love.graphics.draw( self.light_layer, 0, 0, 0, 1.0, 1.0 )
	love.graphics.setBlendMode( "alpha" )
	
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
	if self.map then
		return (self.map.tileWidth * tile_x) + self.map.tileWidth/2, (self.map.tileHeight * tile_y) + self.map.tileHeight/2
	else
		return 0, 0
	end
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
	if self.map then
		--local ix, iy = self.map:toIso( world_x - (self.map.tileWidth/2), world_y )
		return math.floor(world_x/self.map.tileWidth), math.floor(world_y/self.map.tileHeight)
	else
		return 0, 0
	end
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
	-- get the next world position of the entity
	local nwx, nwy = player.world_x, player.world_y

	if command.up then nwy = player.world_y - (command.move_speed * command.dt) end
	if command.down then nwy = player.world_y + (command.move_speed * command.dt) end
	if command.left then nwx = player.world_x - (command.move_speed * command.dt) end
	if command.right then nwx = player.world_x + (command.move_speed * command.dt) end

	-- could offset by sprite's half bounds to ensure they don't intersect with tiles
	
	-- for now, just collide with tiles that exist on the collision layer.
	if self.map then
		local tile = nil

		-- try the x direction
		local tx, ty = self:tileCoordinatesFromWorld( nwx, player.world_y )
		tile = self:getCollisionTile( tx, ty )
		if not tile then
			player.world_x = nwx -- X direction is clear
		end

		-- try the y direction
		tx, ty = self:tileCoordinatesFromWorld( player.world_x, nwy )
		tile = self:getCollisionTile( tx, ty )
		if not tile then
			player.world_y = nwy -- Y direction is clear
		end
	end
	
	if command.up or command.down or command.left or command.right then
		--player:setDirectionFromMoveCommand( command )
	end

	if self.map then
		player.tile_x, player.tile_y = self:tileCoordinatesFromWorld( player.world_x, player.world_y )
	end
end

