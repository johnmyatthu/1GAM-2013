require "core"

Player = class("Player", AnimatedSprite)
function Player:initialize()
	AnimatedSprite.initialize(self)
	self.health = 100
	self.collision_mask = 1

	self.dir = {x=0, y=0}

	self.visible = true

	self.underBlocks = {}
end

function Player:onSpawn( params )
	self:loadSprite( "assets/sprites/blocks.conf" )
	self:playAnimation( "1" )
	AnimatedSprite.onSpawn( self, params )
end

function Player:onUpdate( params )
	-- self.world_x = self.world_x + self.velocity.x * params.dt
	-- self.world_y = self.world_y + self.velocity.y * params.dt

	if not self:isOnGround() then
		self.velocity.y = self.velocity.y + 9.8
	end

	AnimatedSprite.onUpdate(self, params)
end

function Player:respondsToEvent( event_name, params )
	return true
end

function Player:collision( params )
	if params.dx ~= 0 or params.dy ~= 0 then
		if params.dy < 0 then
			self.underBlocks[ params.other ] = true
		end
	else
		logging.verbose( "wtf" )
	end
end

function Player:endCollision( entity )
	self.underBlocks[ entity ] = nil
end

function Player:isOnGround()
	return #self.underBlocks > 0
end

function Player:onDraw( params )
	if self.visible then
		AnimatedSprite.onDraw( self, params )
	end
end