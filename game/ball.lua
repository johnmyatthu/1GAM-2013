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

function Ball:onCollide( params )

	--logging.verbose( params.other.class )

	AnimatedSprite.onCollide( self, params )
end

function Ball:onSpawn( params )
	self:loadSprite( "assets/sprites/items.conf" )
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