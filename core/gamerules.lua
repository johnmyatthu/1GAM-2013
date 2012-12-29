module( ..., package.seeall )
require( "middleclass.middleclass" )

GameRules = class( "GameRules" )

function GameRules:initialize()
	self.value = 10
	self.camera_x = 0
	self.camera_y = 0
	self.map = nil
	self.spawn = {x=0, y=0}
end

function GameRules:loadMap( mapname )
	print( "loading gamerules map" )
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
			self.spawn = {x = tile_x, y = tile_y }
			layer:set( tile_x, tile_y, nil )
		end
	end
end


function GameRules:worldCoordinatesFromTile( tile_x, tile_y )
	-- this accepts the camera offset x and y and factors that into the coordinates

	-- we need to further offset the returned value by half the entire map's width to get the correct value
	local render_offset_x = ((self.map.width * self.map.tileWidth) / 2)

	local tx, ty = tile_x, tile_y-1

	local drawX = self.camera_x + render_offset_x + math.floor(self.map.tileWidth/2 * (tx - ty-2))
	local drawY = self.camera_y + math.floor(self.map.tileHeight/2 * (tx + ty+2))
	drawY = drawY - (self.map.tileHeight/2)
	return drawX, drawY + (self.map.tileHeight/2)
end

function GameRules:worldCoordinatesFromTileCenter( tile_x, tile_y )
	local wx, wy = self.map:fromIso( tile_x, tile_y )
	return wx, wy + (self.map.tileHeight/2)
end

function GameRules:tileCoordinatesFromWorld( world_x, world_y )
	local ix, iy = self.map:toIso( world_x, world_y )
	return math.floor(ix/self.map.tileHeight), math.floor(iy/self.map.tileHeight)
end

function GameRules:tileCoordinatesFromMouse( mouse_x, mouse_y )
	local ix, iy = self.map:toIso( mouse_x-self.camera_x, mouse_y-self.camera_y )
	return math.floor(ix/self.map.tileHeight), math.floor(iy/self.map.tileHeight)
end


-- EntityManager
-- Encapsulate common functions with entities; manage a list of them, call events, etc.
EntityManager = class( "EntityManager" )

function EntityManager:initialize()
	self.entList = {}
end

function EntityManager:addEntity( e )
	table.insert( self.entList, e )
end

function EntityManager:eventForEachEntity( event_name, params )
	--logging.verbose( "iterating through for event: " .. event_name )
	for index, entity in pairs(self.entList) do
		local fn = entity[ event_name ]
		if fn ~= nil then
			-- call this with the instance, then parameters table
			fn( entity, params )
		end
	end
end