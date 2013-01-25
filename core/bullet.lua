require "core"

Bullet = class("Bullet", AnimatedSprite)
function Bullet:initialize()
	AnimatedSprite:initialize(self)

	self.velocity = { x=0, y=0 }

	self.collision_mask = 2
	self.attack_damage = 0
	self.bullet_speed = 250
end

function Bullet:onSpawn( params )
	self:loadSprite( "assets/sprites/projectiles.conf" )
	self:playAnimation( "one" )
	AnimatedSprite.onSpawn( self, params )
end

function Bullet:onCollide( params )
	if params.other == nil then
		-- bullet hit a wall; play wallhit sound
	end

	Entity.onCollide( self, params )
end

function Bullet:onHit( params )
end

function Bullet:onUpdate( params )
	self.world_x = self.world_x + self.velocity.x * params.dt * self.bullet_speed
	self.world_y = self.world_y + self.velocity.y * params.dt * self.bullet_speed
	AnimatedSprite.onUpdate( self, params )

	if not params.gamerules:isTileWalkable( self.tile_x, self.tile_y ) then
		params.gamerules:playSound( "bullet_wall_hit" )
		params.gamerules:removeEntity( self )
	end
end