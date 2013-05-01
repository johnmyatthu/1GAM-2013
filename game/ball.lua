require "core"

Ball = class( "Ball", AnimatedSprite )
function Ball:initialize()
	AnimatedSprite.initialize(self)

	self.collision_mask = 3

	self.normal_move_speed = 32
	self.persue_multiplier = 2.0
	self.move_speed = self.normal_move_speed
	self.move_multiplier = 1.0
end

function Ball:collision( params )


	local dx = params.dx
	local dy = params.dy

	if params.other then
		self.world_x = self.world_x + dx
		self.world_y = self.world_y + dy
		self.damping.x = 0.99
		self.damping.y = 0.99
	end

	AnimatedSprite.collision( self, params )
end

function Ball:onSpawn( params )
	self:loadSprite( "assets/sprites/blocks.conf" )
	self:playAnimation( "1" )
	AnimatedSprite.onSpawn( self, params )
end

function Ball:onDraw( params )
	AnimatedSprite.onDraw( self, params )
end

function Ball:onUpdate( params )
	self.move_speed = self.normal_move_speed * self.move_multiplier
	AnimatedSprite.onUpdate( self, params )
end