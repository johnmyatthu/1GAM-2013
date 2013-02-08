require "core"

func_target = class( "func_target", AnimatedSprite )
function func_target:initialize()
	AnimatedSprite:initialize(self)
	self.collision_mask = 3
	self.health = 0

	self.total_unlock_time = 1.5
	self.unlock_time_left = self.total_unlock_time
	self.is_locked = true
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
	
	if self.is_locked then
		self.health = 100*(1.0 - (self.unlock_time_left / self.total_unlock_time))

		if self.health >= 100 then
			self.is_locked = false
			self.health = 100
		end
	else
		self.health = 100
	end

	self:drawHealthBar( params )
end

function func_target:onUpdate( params )
	AnimatedSprite.onUpdate( self, params )

	if self.is_locked and self.is_unlocking then
		self.unlock_time_left = self.unlock_time_left - params.dt
	end
end

function func_target:startInteraction( params )
	self.is_unlocking = true
end

function func_target:endInteraction( params )
	if self.is_locked then
		self.is_unlocking = false
		self.unlock_time_left = self.total_unlock_time
	end
end