require "core"

func_target = class( "func_target", AnimatedSprite )
function func_target:initialize()
	AnimatedSprite:initialize(self)
	self.collision_mask = 3
	self.health = 100
end

function func_target:onSpawn( params )
	self:loadSprite( "assets/sprites/items.conf" )
	self:playAnimation( "chest" )
	AnimatedSprite.onSpawn( self, params )
end

function func_target:onHit( params )
	if self.health > 0 then
		self.health = self.health - params.attack_damage
		self.time_since_last_hit = 0
		if self.health < 0 then
			self.health = 0
		end
	end
end

function func_target:__tostring()
	return AnimatedSprite.__tostring(self) .. ", Health: " .. self.health
end

function func_target:useActionString()
	return "unlock chest"
end

function func_target:onDraw( params )
	AnimatedSprite.onDraw( self, params )
	self:drawHealthBar( params )
end