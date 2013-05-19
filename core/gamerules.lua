module( ..., package.seeall )
require "core"
require "game"
local Pathfinder = require "lib.jumper.jumper.pathfinder"
loader = require "lib.AdvTiledLoader.Loader"
Tile = require "lib.AdvTiledLoader.Tile"
require "lib.luabit.bit"

require "core.entityfactory"
require "core.entitymanager"

local bump = require "lib.bump.bump"


local MAP_COLLISION_LAYER_NAME = "Collision"
local MAP_GROUND_LAYER_NAME = "Ground"


local LIGHT_RADIUS = 4
local LIGHT_SCALE_FACTOR = 2

GameRules = class( "GameRules" )

local s_gamerules = nil


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
	self.entity_factory:registerClass( "WorldEntity", core.WorldEntity )
	self.entity_factory:registerClass( "AnimatedSprite", core.AnimatedSprite )
	self.entity_factory:registerClass( "PathFollower", core.PathFollower )
	self.entity_factory:registerClass( "CollisionTile", core.CollisionTile )

	self.entity_factory:registerClass( "Enemy", game.Enemy )
	self.entity_factory:registerClass( "Player", game.Player )
	self.entity_factory:registerClass( "Ball", game.Ball )
	self.entity_factory:registerClass( "Scorebox", game.Scorebox )

	self.sounds = {}
	self.sound_data = {}
	self:loadSounds( "assets/sounds/sounds.conf" )

	self.data = {}
	self:loadData( "assets/gamerules.conf" )

	self.target = nil
	self.player = nil
	
	self.last_level = {}

	love.audio.setVolume( 1.0 )

	self.light_layer = love.graphics.newCanvas()
	self.score = 0
	self.lights = {}	

	s_gamerules = self
end

function GameRules.getGameRules()
	return s_gamerules
end

function bump.collision(item1, item2, dx, dy)
	-- print(item1.name, "collision with", item2.name, "displacement vector:", dx, dy)
	item1:collision( {gamerules=s_gamerules, other=item2, dx=dx, dy=dy} )
	item2:collision( {gamerules=s_gamerules, other=item1, dx=-dx, dy=-dy})
end

function bump.endCollision(item1, item2)
	-- print(item1.name, "stopped colliding with", item2.name)
	item2:endCollision(item1)
	item1:endCollision(item2)  
end

-- for compatability with bump
function bump.getBBox(entity)
	-- world_x, world_y is the center of the entity
	-- bump assumes the parameters: left, top, width, height
	local w,h = entity:size()
	return entity.world_x-(w/2), entity.world_y-(h/2), w, h
end


function bump.shouldCollide(item1, item2)
  return true -- we could add certain conditions here - for example, make objects of the same group not collide
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


function GameRules:createSource( name )
	local sound_data = self.sound_data[ name ]
	return love.audio.newSource( sound_data["path"], sound_data["type"] )
end

function GameRules:playSound( name, play_sound )
	if self.sounds then
		local source = self.sounds[ name ]
		love.audio.rewind( source )
		
		if play_sound then
			love.audio.play( source )
		end
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







function GameRules:initCollision()
	-- local grid_width = self.map.width
	-- local grid_height = self.map.height
	-- self.grid = SH:new( grid_width, grid_height, 64 )
	self.bump = bump
	bump.initialize(64)
end

function GameRules:addCollision( entity )
	-- if self.grid then
	-- 	self.grid:addShape( entity )
	-- end
	bump.add(entity)
end

function GameRules:removeCollision( entity )

	--if self.collision_layer then
	--	self.collision_layer:set( entity.tile_x, entity.tile_y, nil )
	--end

	-- if self.grid then
	-- 	self.grid:removeShape( entity )
	-- end
	bump.remove(entity)
end


function GameRules:actOnCollidingPairs( colliding, params )
-- 	if self.grid then
-- 		table.foreach( colliding,
-- 		function(_, v) 
-- 			if (v[1].collision_mask > 0) and (v[2].collision_mask > 0) and (bit.band(v[1].collision_mask,v[2].collision_mask) > 0) then
-- 				local vec = {x=0,y=0}
-- 				local normal = {x=0, y=0}

-- 				local w1, h1 = v[1]:size()
-- 				local w2, h2 = v[2]:size()

-- 				vec.x = v[2].world_x - v[1].world_x
-- 				vec.y = v[2].world_y - v[1].world_y


-- 				if vec.x > 0 then
-- 					normal.x = 1
-- 				end

-- 				if vec.y > 0 then
-- 					normal.y = 1
-- 				end

-- 				v[1]:onCollide( {gamerules=self, other=v[2], v=vec, normal=normal} )	
-- --[[
-- 				normal.x = 0
-- 				normal.y = 0

-- 				vec.x = v[1].world_x - (w2/2) - v[2].world_x - (w1/2)
-- 				vec.y = v[1].world_y - (h2/2) - v[2].world_y - (h1/2)

-- 				if vec.x < vec.y then
-- 					normal.x = 1
-- 				else
-- 					normal.y = 1
-- 				end
-- 				--]]	
-- 				v[2]:onCollide( {gamerules=self, other=v[1], v=vec, normal=normal} )

-- 			end	end	)
-- 	end
end

function GameRules:updateCollision( params )
	-- if self.grid then
	-- 	local colliding = self.grid:getCollidingPairs( self.entity_manager:allEntities() )
	-- 	--self:actOnCollidingPairs( colliding, params )
	-- end

  -- local updateEntity = function(entity) entity:update(dt, maxdt) end

  -- bump.each(updateEntity, l,t,w,h)
  -- bump.collide(l,t,w,h)	

  bump.collide()
end




function GameRules:findEntityAtMouse( find_invisible )
	local mx, my = love.mouse.getPosition()

	mx, my = self:screenToWorld(mx, my)

	for _,e in pairs(self.entity_manager:allEntities()) do
		local dx, dy = (mx-e.world_x), (my-e.world_y)
		local dist = math.sqrt(dx*dx + dy*dy)
		if dist < 16 then
			if find_invisible then
				return e
			elseif e.visible then
				return e		
			end
		end
	end

	return nil
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
	self.lights = {}
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

	local hw = self.map.tileWidth/2
	local hh = self.map.tileHeight/2
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


	for x, y, tile in self.collision_layer:iterate() do
		local ct = self.entity_factory:createClass("CollisionTile")
		--self:spawnEntity(ct, nil, nil, nil)
		ct:setPosition(x*self.map.tileWidth+hw, y*self.map.tileHeight+hh)
		ct:setSize(self.map.tileWidth, self.map.tileHeight)
		bump.addStatic(ct)
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

	local object_layer = self.map.layers["Objects"]
	if object_layer then
		for k,v in pairs(object_layer.objects) do
			properties = {}
			for key,value in pairs( v.properties ) do
				properties[ key ] = value
			end

			-- bundle these values in with the properties
			properties[ "name" ] = v.name
			properties[ "type" ] = v.type

			-- the spawn function accepts tile coordinates, but the objects are in "map" (world) coordinates
			-- so just convert these

			-- for whatever reason, tiled exports these objects off by one tile in the Y direction
			v.y = v.y - 32
			local tx, ty = self:tileCoordinatesFromWorld( v.x, v.y )

			self:spawnEntityAtTileWithProperties( nil, tx, ty, properties )
		end
	else
		logging.verbose( "No 'Objects' layer found" )
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

function GameRules:collisionTrace( wx, wy, wx2, wy2 )
	local x, y, hit = wx2, wy2, 0

	-- if hit == 0 then we hit our target with no obstructions
		-- returns wx2, wy2
	-- else we hit a collision tile
		-- returns the world space point where we hit the tile
	local tile_width = self.map.tileWidth
	local tile_height = self.map.tileHeight

	local tiles_w = math.floor( (wx2-wx) / tile_width )
	local tiles_h = math.floor( (wy2-wy) / tile_height )

	local dir_x = 0
	if tiles_w < 0 then
		dir_x = -1
	elseif tiles_w > 0 then
		dir_x = 1
	end

	local dir_y = 0
	if tiles_h < 0 then
		dir_y = -1
	elseif tiles_h > 0 then
		dir_y = 1
	end

	-- I'm using repeat loops here because the for x=1, m, z do ... loops were
	-- getting stuck in an infinite loop; apparently it doesn't check the conditional after executing it once?
	local tilestart_x, tilestart_y = self:tileCoordinatesFromWorld( wx, wy )
	found_collision = false
	tx = 0
	repeat
		ty = 0
		repeat
			local tile = self.collision_layer:get( tilestart_x + tx, tilestart_y + ty )
			if tile ~= nil then
				x, y = self:worldCoordinatesFromTileCenter( tilestart_x + tx, tilestart_y + ty )
				x = x + ((tile_width/2) * -dir_x)
				hit = 1

				-- early out -- hit a tile
				found_collision = true
				break
			end
			ty = ty + dir_y
		until ty == tiles_h or found_collision

		tx = tx + dir_x
	until tx == tiles_w or found_collision

	return x, y, hit
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

			--logging.verbose("spawn is at: " .. tile_x .. ", " .. tile_y )

			if layer then
				layer:set( tile_x, tile_y, nil )
			end
		else
			local entity = self.entity_factory:createClass( classname )
			if entity then
				-- remove this tile from the layer
				if layer then
					layer:set( tile_x, tile_y, nil )
				end

					-- set the world position for the entity from the tile coordinates
				entity.world_x, entity.world_y = self:worldCoordinatesFromTileCenter( tile_x, tile_y )

				if classname == "func_light" then
					self:addLight( entity )
				end

				self:spawnEntity( entity, entity.world_x, entity.world_y, properties )




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
	local camx, camy = self:getCameraPosition()

	local map_w, map_h = self.map.width*self.map.tileWidth, self.map.height*self.map.tileHeight

	local cx = -(player.world_x - (window_width/2))
	if cx >= 0 then
		cx = 0
	elseif cx + map_w < window_width then
		cx = -(map_w - window_width)
	end

	local cy = -(player.world_y - (window_height/2))
	if cy >= 0 then
		cy = 0
	elseif cy + map_h < window_height then
		cy = -(map_h - window_height)
	end

	-- logging.verbose( "map_h: " .. tostring(map_h) )
	-- logging.verbose( "cy: " .. tostring(cy) )
	-- logging.verbose( "window_height: " .. tostring(window_height))
	self:warpCameraTo(cx, cy)
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


function GameRules:drawLights()
	for _, light in pairs(self.lights) do
		light:onDraw( {gamerules = self, lightpass=1} )
	end
end

function GameRules:addLight( light )
	light.id = #self.lights
	table.insert( self.lights, light )
end

function GameRules:drawWorld()

	love.graphics.setCanvas()
	--love.graphics.push()
	love.graphics.setColor(255,255,255,255)
	local cx, cy = self:getCameraPosition()
	local ftx, fty = math.floor(cx), math.floor(cy)
	
	love.graphics.push()
	love.graphics.translate( ftx, fty )
	if self.map then
		local window_width, window_height = love.graphics.getWidth(), love.graphics.getHeight()
		local tx, ty = self:tileCoordinatesFromWorld( (window_width/2)-cx, (window_height/2)-cy )

		fog = self.map.layers[ MAP_FOG_LAYER_NAME ]
		if fog then
			for x, y, tile in fog:circle( tx, ty, LIGHT_RADIUS, false ) do
				fog:set( x, y, nil )
			end
		end

		self.map:autoDrawRange( ftx, fty, 1, 5 )
		self.map:draw()
	end

	love.graphics.pop()
end


function GameRules:drawLightmap( params )
	local cx, cy = self:getCameraPosition()
	local ftx, fty = math.floor(cx), math.floor(cy)
	
	love.graphics.translate( ftx, fty )

	love.graphics.setCanvas( self.light_layer )
	love.graphics.setColor( 0, 0, 0, 0 )
	love.graphics.clear()

	-- draw lights
	self:drawLights()

	love.graphics.setCanvas()
	love.graphics.setBlendMode( "multiplicative" )
	love.graphics.setColor( 255, 255, 255, 192 )
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


	-- self.entity_manager:eventForEachEntity( "resetMoves", params )
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
	entity:onRemove( {gamerules=self} )
	self.entity_manager:removeEntity( entity )
	self:removeCollision(entity)
end


function GameRules:onUpdate(params)
	params.gamerules = self

	-- call update on all entities
	self.entity_manager:eventForEachEntity( "onUpdate", params )

	-- run collision callbacks on entities to resolve intersections
	self:updateCollision(params)

	self.entity_manager:eventForEachEntity( "postFrameUpdate", params )
end

function GameRules:findMinimumDisplacementVector( a, b )
	-- get direction from this entity to the other
	local dx = b.world_x - a.world_x
	local dy = b.world_y - a.world_y
	return -dx, -dy
end

function reconcilePenetration( _, v )
	-- logging.verbose( v[1] )
	-- logging.verbose( v[2] )
	local dx, dy = v[2].world_x - v[1].world_x, v[2].world_y - v[1].world_y
	local d = GameRules.calculateEntityDistance( nil, v[1], v[2])
	if d < 32 then
		-- normalize
		local len = core.util.vector.length(dx, dy)
		local nx = dx/len
		local ny = dy/len

		local nd = (32-d)
		dx = nx * nd
		dy = ny * nd
		v[2].world_x = v[2].world_x + dx
		v[2].world_y = v[2].world_y + dy
	end
end

function GameRules:moveEntityInDirection( entity, direction, dt )
	-- get the next world position of the entity
	local nwx, nwy = entity.world_x, entity.world_y
	local old_world_x, old_world_y = entity.world_x, entity.world_y
	local w,h = entity:size()
	local sxo = 0
	local syo = 0

	-- offset based on entity size (bounds)
	if direction.x > 0 then
		sxo = (w/2)
	elseif direction.x < 0 then
		sxo = -(w/2)
	end

	if direction.y > 0 then
		syo = (h/2)
	elseif direction.y < 0 then
		syo = -(h/2)
	end

	nwx = entity.world_x + (direction.x * dt)
	nwy = entity.world_y + (direction.y * dt)


	local tile = nil
	local dx = 0
	local dy = 0
	-- for now, just collide with tiles that exist on the collision layer.
	if self.map then
		-- try the x direction
		local tx, ty = self:tileCoordinatesFromWorld( nwx+sxo, entity.world_y )
		local tileX = self:getCollisionTile( tx, ty )
		if not tileX then			
			entity.world_x = nwx -- X direction is clear
		else
			dx = (tx*self.map.tileWidth) - entity.world_x
		end

		-- try the y direction
		tx, ty = self:tileCoordinatesFromWorld( entity.world_x, nwy+syo )
		local tileY = self:getCollisionTile( tx, ty )
		if not tileY then
			entity.world_y = nwy -- Y direction is clear
		else
			dy = (ty*self.map.tileHeight) - entity.world_y
		end

		tile = tileX or tileY
	end
	
	if nwx ~= entity.world_x and nwy ~= entity.world_y then
		--entity:setDirectionFromMoveCommand( command )
	end

	if tile then
		entity:collision( {gamerules=self, other=nil, dx=dx*0.5, dy=dy*0.5} )
	end

	return tile
end

function GameRules:handleMovePlayerCommand( command, player )
	-- get the next world position of the entity
	local nwx, nwy = player.world_x, player.world_y

	if command.up then nwy = player.world_y - (command.move_speed * command.dt) end
	if command.down then nwy = player.world_y + (command.move_speed * command.dt) end
	if command.left then nwx = player.world_x - (command.move_speed * command.dt) end
	if command.right then nwx = player.world_x + (command.move_speed * command.dt) end

	-- could offset by sprite's half bounds to ensure they don't intersect with tiles
	
	-- wrap around window edges
	if nwx < 0 then
		nwx = love.graphics.getWidth() - nwx
	elseif nwx > love.graphics.getWidth() then
		nwx = nwx - love.graphics.getWidth()
	end
	if nwy < 0 then
		nwy = love.graphics.getHeight() - nwy
	elseif nwy > love.graphics.getHeight() then
		nwy = nwy - love.graphics.getHeight()
	end

	player.world_x = nwx
	player.world_y = nwy
	
	if command.up or command.down or command.left or command.right then
		player:setDirectionFromMoveCommand( command )
	end

	if self.map then
		player.tile_x, player.tile_y = self:tileCoordinatesFromWorld( player.world_x, player.world_y )
	end
end

