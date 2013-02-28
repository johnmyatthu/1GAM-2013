require "core"

func_chest = class( "func_chest", AnimatedSprite )
function func_chest:initialize()
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


	self.fade_in_time = 0.5
	self.is_fading = false
	self.fadetime = self.fade_in_time
end

function func_chest:onSpawn( params )
	AnimatedSprite.onSpawn( self, params )

	self:loadSprite( "assets/sprites/items.conf" )
	self:playAnimation( "chest" )


	self.sonar_sound = params.gamerules:createSource( "sonar" )
end

function func_chest:onHit( params )
	if self.health > 0 then
		self.health = self.health - params.attack_damage
		self.time_since_last_hit = 0
		if self.health < 0 then
			self.health = 0
		end
	end
end

function func_chest:__tostring()
	return AnimatedSprite.__tostring(self) .. ", Health: " .. self.health
end

function func_chest:useActionString()
	if self.is_locked then
		return "unlock chest"
	else
		return nil
	end
end

function func_chest:fadeout()
	if not self.is_fading then
		self.is_fading = true
		self.fade_in_time = self.fadetime
	end
end

function func_chest:onDraw( params )
	self.color.a = (self.fade_in_time / self.fadetime) * 255
	AnimatedSprite.onDraw( self, params )
end

function func_chest:onUpdate( params )

	if self.is_fading then
		self.fade_in_time = self.fade_in_time - params.dt
		if self.fade_in_time <= 0 then
			self.fade_in_time = 0
			self.is_fading = false
			params.gamerules:removeEntity( self )
		end
	end

	-- calculate the volume based on the distance from the player
	local sonar_distance = params.gamerules:calculateEntityDistance( self, params.gamerules:getPlayer() )
	self.sonar_volume = (1 - ((sonar_distance)/GAME_SONAR_DIVISOR))
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
end

function func_chest:canInteractWith( params )
	return true
end
