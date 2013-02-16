require "core"

func_target = class( "func_target", AnimatedSprite )
function func_target:initialize()
	AnimatedSprite.initialize(self)
	self.collision_mask = 3
	self.health = 0

	self.total_unlock_time = 1.5
	self.unlock_time_left = self.total_unlock_time
	self.is_locked = true
	self.unlock_distance = 25

	self.sonar_sound = nil
	self.sonar_interval = 2
	self.next_sonar_time = self.sonar_interval + math.random() -- offset the sonar triggers
	self.sonar_volume = 1
end

function func_target:onSpawn( params )
	AnimatedSprite.onSpawn( self, params )

	self:loadSprite( "assets/sprites/items.conf" )
	self:playAnimation( "chest" )


	self.sonar_sound = params.gamerules:createSource( "sonar" )
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
	if self.is_locked then
		return "unlock chest"
	else
		return nil
	end
end

function func_target:onDraw( params )
	AnimatedSprite.onDraw( self, params )
	
	if self.is_locked then
		self.health = 100*(1.0 - (self.unlock_time_left / self.total_unlock_time))

		if self.health >= 100 then
			self.is_locked = false
			self.health = 100
			self:playAnimation("open")
		end
	else
		self.health = 100
	end

	self:drawHealthBar( params )
end

function func_target:onUpdate( params )

	-- calculate the volume based on the distance from the player
	local sonar_distance = params.gamerules:calculateEntityDistance( self, params.gamerules:getPlayer() )
	self.sonar_volume = (1 - ((sonar_distance)/3000))
	if self.sonar_volume < 0 then
		self.sonar_volume = 0
	end

	if self.next_sonar_time > 0 then
		self.next_sonar_time = self.next_sonar_time - params.dt

		if self.next_sonar_time <= 0 and self.is_locked then
			self.next_sonar_time = self.sonar_interval
			self.sonar_sound:rewind()
			self.sonar_sound:setVolume( self.sonar_volume )
			self.sonar_sound:play()
		end
	end

	AnimatedSprite.onUpdate( self, params )

	if self.is_locked and self.is_unlocking then
		self.unlock_time_left = self.unlock_time_left - params.dt
	end
end

function func_target:canInteractWith( params )
	local distance = params.gamerules:calculateEntityDistance( self, params.other )
	if distance > self.unlock_distance then
		return false
	end

	return true
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