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
	--[[
	local normal = params.normal


	logging.verbose( "I hit something. normal : " .. normal.x .. ", " .. normal.y )
	logging.verbose( "I hit something. vec : " .. params.v.x .. ", " .. params.v.y )
	
	
	if normal.x ~= 0 then
		self.world_x = self.world_x + params.v.x
		self.velocity.x = -self.velocity.x
	end

	if normal.y ~= 0 then
		self.world_y = self.world_y + params.v.y
		self.velocity.y = -self.velocity.y
	end
	--]]
	if params.tile then
		if params.normal.x ~= 0 then
			self.velocity.x = -self.velocity.x
		end

		if params.normal.y ~= 0 then
			self.velocity.y = -self.velocity.y
		end
	end

	AnimatedSprite.onCollide( self, params )
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