module( ..., package.seeall )
require "core"
logging = core.logging
GameRules = class( "GameRules" )

local MAP_COLLISION_LAYER_NAME = "Collision"

function GameRules:initialize()
	self.camera_x = 0
	self.camera_y = 0
	self.map = nil
	self.collision_layer = nil
	self.spawn = {x=0, y=0}
	self.entity_factory = EntityFactory:new()

	-- need to register all entity classes somewhere; this is not the best spot :/
	self.entity_factory:registerClass( "WorldEntity", core.entity.WorldEntity )
end

function GameRules:loadMap( mapname )
	print( "loading gamerules map" )


	-- cache collision layer and disable rendering
	self.collision_layer = self.map.layers[ MAP_COLLISION_LAYER_NAME ]
	if self.collision_layer then
		--self.collision_layer.visible = false
	end
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

function GameRules:handleTileProperty( layer, tile_x, tile_y, property_key, property_value )
	-- very crude handling of this until I implement a better way
	if property_key == "classname" then
		if property_value == "func_spawn" then
			self.spawn = { x = tile_x, y = tile_y }
			--layer:set( tile_x, tile_y, nil )
		end
	end
end

function GameRules:snapCameraToPlayer( player )
	local window_width, window_height = love.graphics.getWidth(), love.graphics.getHeight()
	self:warpCameraTo( -(player.world_x-(window_width/2)), -(player.world_y-(window_height/2)) )
end

function GameRules:getCollisionTile( tx, ty )
	if self.collision_layer then
		return self.collision_layer( tx, ty )
	end

	return nil
end


function GameRules:drawWorld()
	love.graphics.push()
	love.graphics.setColor(255,255,255,255)
	local cx, cy = self:getCameraPosition()
	local ftx, fty = math.floor(cx), math.floor(cy)
	love.graphics.translate(ftx, fty)

	self.map:autoDrawRange( ftx, fty, 1, 50 )

	self.map:draw()
	--love.graphics.rectangle("line", global.map:getDrawRange())
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
end

function sortDescendingDepth(a,b)
	return a.world_y < b.world_y
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
	end

	return instance
end


