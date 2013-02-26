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


	self.speed = 0.5
	self.prey = nil
end

function func_shark:onSpawn( params )
	AnimatedSprite.onSpawn( self, params )
	self:loadSprite( "assets/sprites/shark.conf" )
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

function func_shark:onUpdate( params )
	if self.prey then
		local player = params.gamerules:getPlayer()

		-- calculate velocity in the direction of the player
		local dx = (player.world_x - self.world_x)
		local dy = (player.world_y - self.world_y)

		self.velocity.x = dx * self.speed
		self.velocity.y = dy * self.speed

		if math.abs(dy) < 24 and math.abs(dx) < 64 then
			logging.verbose( "SHARK HAS EATEN YOU" )
			player.health = 0
			player.visible = false
		end

		--local prey_distance = params.gamerules:calculateEntityDistance( self, self.prey )
	else
		local distance = params.gamerules:calculateEntityDistance( self, params.gamerules:getPlayer() )
		-- if the player gets too close to the shark; the shark will follow

		if distance < 75 then
			logging.verbose( "a shark has spotted you" )
			self.speed = 1.25
			self.prey = params.gamerules:getPlayer()
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

	AnimatedSprite.onUpdate( self, params )
end