require "core"

func_thing = class( "func_thing", AnimatedSprite )
function func_thing:initialize()
	AnimatedSprite.initialize(self)
	self.collision_mask = 3
	self.health = 0

	self.pv = { x=0, y=0 }

	self.direction_switch_time = 2
	self.fadetime = 0.5 + math.random(2.0)
	self.fade_in_time = self.fadetime
	self.time_until_direction_switch = self.direction_switch_time

	self.color.r = math.random(255)
	self.color.g = math.random(255)
	self.color.b = math.random(255)
end

function func_thing:onSpawn( params )
	AnimatedSprite.onSpawn( self, params )
	self:loadSprite( "assets/sprites/critters.conf" )
end

function func_thing:onHit( params )
	if self.health > 0 then
		self.health = self.health - params.attack_damage
		self.time_since_last_hit = 0
		if self.health < 0 then
			self.health = 0
		end
	end
end

function func_thing:__tostring()
	return AnimatedSprite.__tostring(self) .. ", Health: " .. self.health
end

function func_thing:useActionString()
	return nil
end

function func_thing:onDraw( params )
	self.color.a = (1 - (self.fade_in_time / self.fadetime)) * 255
	AnimatedSprite.onDraw( self, params )
end


function func_thing:updateDirection()
	local direction = math.random(100)
	if direction < 50 then
		direction = 1
	else
		direction = -1
	end
	self.pv = {x=direction*math.random(100), y=math.random(25)}
end

function func_thing:onUpdate( params )

	if self.fade_in_time > 0 then
		self.fade_in_time = self.fade_in_time - params.dt
		if self.fade_in_time <= 0 then
			self.fade_in_time = 0
		end
	end

	if self.time_until_direction_switch > 0 then
		self.time_until_direction_switch = self.time_until_direction_switch - params.dt
		if self.time_until_direction_switch <= 0 then
			self.time_until_direction_switch = math.random(10)
			self:updateDirection()
		end
	end

	self.velocity.x = self.pv.x
	self.velocity.y = self.pv.y

	if self.velocity.x > 0 then
		self:playAnimation( "right" )
	else
		self:playAnimation( "left" )
	end

	if not params.gamerules:isTileWithinMap( self.tile_x, self.tile_y ) then
		params.gamerules:removeEntity( self )
	end

	local dist = params.gamerules:calculateEntityDistance( self, params.gamerules.player )
	if dist >= 750 then
		--logging.verbose( "Too far from player, removing" )
		params.gamerules:removeEntity(self)
	end

	AnimatedSprite.onUpdate( self, params )
end

function func_thing:startInteraction( params )
end

function func_thing:endInteraction( params )
end