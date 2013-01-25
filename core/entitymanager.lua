require "core"

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

function EntityManager:findAllEntitiesByName( name )
	local entities = {}
	for index, entity in pairs(self.entity_list) do
		if entity.class.name == name then
			table.insert( entities, entity )
		end
	end

	return entities
end

function EntityManager:allEntities()
	return self.entity_list
end

-- sort the entities in descending depth order such that lower objects in the screen are drawn in front
function EntityManager:sortForDrawing()
	table.sort( self.entity_list, sortDescendingDepth )
end

function EntityManager:eventForEachEntity( event_name, params )
	for index, entity in pairs(self.entity_list) do
		local fn = entity[ event_name ]
		if fn ~= nil and entity:respondsToEvent( event_name, params ) then
			-- call this with the instance, then parameters table
			fn( entity, params )
		end
	end
end

