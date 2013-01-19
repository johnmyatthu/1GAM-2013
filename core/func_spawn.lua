require "core"

func_spawn = class( "func_spawn", Entity )
function func_spawn:initialize()
	Entity:initialize(self)
	self.gamerules = nil
	self.spawn_time = 1
	self.spawn_class = ""

	self.time_left = self.spawn_time

	-- by default, -1 will mean repeatedly spawn
	-- 0 will mean never fire
	self.max_entities = -1
end

function func_spawn:onSpawn( params )
	Entity.onSpawn( self, params )

	self.spawn_class = params.gamerules.entity_factory:findClass( self.spawn_class )
	self.gamerules = params.gamerules
end

-- params:
--	entity: the instance of the entity being spawned
function func_spawn:onUpdate( params )
	if params.gamestate == core.GAME_STATE_DEFEND then
		local dt = params.dt
		self.time_left = self.time_left - dt

		if self.time_left <= 0 and self.max_entities ~= 0  then
			--logging.verbose( "spawning entity at " .. self.tile_x .. ", " .. self.tile_y )
			self.time_left = self.spawn_time
			local entity = self.spawn_class:new()
			if entity then
				--logging.verbose( "-> entity tile at " .. entity.tile_x .. ", " .. entity.tile_y )
				--logging.verbose( "-> entity world at " .. entity.world_x .. ", " .. entity.world_y )
				entity.world_x, entity.world_y = self.gamerules:worldCoordinatesFromTileCenter( self.tile_x, self.tile_y )

				-- use gamerules to spawn this entity
				params.gamerules:spawnEntity( entity, nil, nil, nil )

				if self.max_entities > 0 then
					self.max_entities = self.max_entities - 1
				end
			end
		end
	end

	Entity.onUpdate( self, params )
end