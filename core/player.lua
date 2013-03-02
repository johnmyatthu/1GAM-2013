require "core"

Player = class("Player", AnimatedSprite)
function Player:initialize()
	AnimatedSprite.initialize(self)
	self.health = 100
	self.collision_mask = 1
	self.attack_delay = 1 -- in seconds
	self.attack_damage = 1

	self.dir = {x=0, y=0}

	self.visible = true
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

	if self.velocity.x > 0 then
		self:playAnimation( "right" )
	else
		self:playAnimation( "left" )
	end	

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