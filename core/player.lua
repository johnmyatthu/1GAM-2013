require "core"

local LIGHT_LEVEL_DIVISOR = 100

Player = class("Player", AnimatedSprite)
function Player:initialize()
	AnimatedSprite.initialize(self)
	self.health = 100
	self.collision_mask = 1
	self.attack_delay = 1 -- in seconds
	self.attack_damage = 1

	self.dir = {x=0, y=0}

	self.visible = true
	self.light_scale = 0.5
	self.light_intensity = 0 --0.15

	self.light_level = 0

	self.is_tagged = false -- tagged by an enemy
end

function Player:onSpawn( params )
	self:loadSprite( "assets/sprites/player.conf" )
	self:playAnimation( "left" )
	AnimatedSprite.onSpawn( self, params )
end

function Player:onUpdate( params )
	local nwx = self.world_x + self.velocity.x * params.dt
	local nwy = self.world_y + self.velocity.y * params.dt

	-- could offset by sprite's half bounds to ensure they don't intersect with tiles
	local tx, ty = params.gamerules:tileCoordinatesFromWorld( nwx, nwy )
	local tile = params.gamerules:getCollisionTile( tx, ty )
	
	-- could offset by sprite's half bounds to ensure they don't intersect with tiles
	local tile = nil
	local tx, ty = params.gamerules:tileCoordinatesFromWorld( nwx, nwy )
	tile = params.gamerules:getCollisionTile( tx, ty )

	-- for now, just collide with tiles that exist on the collision layer.
	if tile or not params.gamerules:isTileWithinMap(tx, ty) then
		self.velocity.x = 0
		self.velocity.y = 0
	end


	local lights = params.gamerules.entity_manager:findAllEntitiesByName( "func_light" )

	local min = 99999999

	for _, light in pairs(lights) do
		if light ~= self.light then
			local dist = params.gamerules:calculateEntityDistance( light, self ) / light.radius
			if dist < min then
				min = dist
			end
		end	
	end

	self.light_level = 1.0 - (min/LIGHT_LEVEL_DIVISOR)
	self.light_level = math.max( self.light_level, 0 )
	self.light_level = math.min( self.light_level, 1 )

	AnimatedSprite.onUpdate(self, params)
end

function Player:respondsToEvent( event_name, params )
	return true
end

function Player:onCollide( params )
	AnimatedSprite.onCollide( self, params )
end

function Player:onDraw( params )
	if self.visible then
		AnimatedSprite.onDraw( self, params )
	end
end