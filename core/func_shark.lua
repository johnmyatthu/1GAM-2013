require "core"

func_shark = class( "func_shark", AnimatedSprite )
function func_shark:initialize()
	AnimatedSprite.initialize(self)
	self.collision_mask = 3
	self.health = 0

	self.fadetime = 0.5 + math.random(2.0)
	self.fade_in_time = self.fadetime

	self.color.r = math.random(255)
	self.color.g = math.random(255)
	self.color.b = math.random(255)

	self.sonar_sound = nil
	self.sonar_interval = 2
	self.next_sonar_time = math.random() -- offset the sonar triggers
	self.sonar_volume = 1

	self.speed = 0.5
	self.prey = nil
end

function func_shark:onSpawn( params )
	AnimatedSprite.onSpawn( self, params )
	self:loadSprite( "assets/sprites/shark.conf" )

	self.sonar_sound = params.gamerules:createSource( "sonar" )
end

function func_shark:onHit( params )
end

function func_shark:__tostring()
	return AnimatedSprite.__tostring(self) .. ", Health: " .. self.health
end

function func_shark:useActionString()
	return nil
end

function func_shark:onDraw( params )
	self.color.a = (1 - (self.fade_in_time / self.fadetime)) * 255
	AnimatedSprite.onDraw( self, params )
end

function func_shark:lurk( params )
	self.prey = nil
	self.velocity = params.gamerules:randomVelocity( 100, 50 )
end

function func_shark:onUpdate( params )
	if self.prey then
		local player = params.gamerules:getPlayer()

		-- calculate velocity in the direction of the player
		local dx = (player.world_x - self.world_x)
		local dy = (player.world_y - self.world_y)

		self.velocity.x = dx * self.speed
		self.velocity.y = dy * self.speed

		if math.abs(dy) < 24 and math.abs(dx) < 64 then
			if player.health > 0 then
				player.health = 0
				player.visible = false
				params.gamerules:playSound( "sharkchomp" )
				self:lurk( params )
			end
		end

		if self.prey then
			local prey_distance = params.gamerules:calculateEntityDistance( self, self.prey )
			if prey_distance > 400 then
				self:lurk( params )
			end
		end
	else
		local distance = params.gamerules:calculateEntityDistance( self, params.gamerules:getPlayer() )
		-- if the player gets too close to the shark; the shark will follow

		local player = params.gamerules:getPlayer()
		if distance < 200 and player.health > 0 then
			self.speed = 1.25
			self.prey = player
		end
	end



	if self.fade_in_time > 0 then
		self.fade_in_time = self.fade_in_time - params.dt
		if self.fade_in_time <= 0 then
			self.fade_in_time = 0
		end
	end

	if self.velocity.x > 0 then
		self:playAnimation( "right" )
	else
		self:playAnimation( "left" )
	end

	if not params.gamerules:isTileWithinMap( self.tile_x, self.tile_y ) then
		params.gamerules:removeEntity( self )
	end


	-- calculate the volume based on the distance from the player
	local sonar_distance = params.gamerules:calculateEntityDistance( self, params.gamerules:getPlayer() )
	self.sonar_volume = (1 - ((sonar_distance)/3000))
	if self.sonar_volume < 0 then
		self.sonar_volume = 0
	end

	if self.next_sonar_time > 0 then
		self.next_sonar_time = self.next_sonar_time - params.dt

		if self.next_sonar_time <= 0 then
			self.next_sonar_time = self.sonar_interval
			self.sonar_sound:rewind()
			self.sonar_sound:setVolume( self.sonar_volume )
			self.sonar_sound:play()
		end
	end	

	AnimatedSprite.onUpdate( self, params )
end