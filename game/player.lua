require "core"

Player = class("Player", AnimatedSprite)
function Player:initialize()
	AnimatedSprite.initialize(self)
	self.health = 100
	self.collision_mask = 1

	self.dir = {x=0, y=0}

	self.visible = true
	self.last_y = self.world_y
	self.last_delta_y = 1
end

function Player:onSpawn( params )
	self:loadSprite( "assets/sprites/blocks.conf" )
	self:playAnimation( "1" )
	AnimatedSprite.onSpawn( self, params )
end

function Player:onUpdate( params )
	-- self.world_x = self.world_x + self.velocity.x * params.dt
	-- self.world_y = self.world_y + self.velocity.y * params.dt

	-- if not self:isOnGround() then
	-- 	self.velocity.y = self.velocity.y + (400 * params.dt)
	-- 	self.last_delta_y = 1
	-- end
	-- self.last_y = self.world_y
	AnimatedSprite.onUpdate(self, params)
end

function Player:postFrameUpdate(params)
	self.last_delta_y = (self.world_y - self.last_y)
end

function Player:respondsToEvent( event_name, params )
	return true
end

function Player:collision( params )
	if params.other then
		if params.dx ~= 0 or params.dy ~= 0 then
			self.world_x, self.world_y = self.world_x + params.dx, self.world_y + params.dy
		end
	end
end

function Player:endCollision( entity )
end

function Player:jump()
	if self:isOnGround() then
		self.velocity.y = self.velocity.y - 300
		self.world_y = self.world_y - 10
	end
end

function Player:isOnGround()
	return self.last_delta_y == 0
	-- return #self.underBlocks > 0
end

function Player:onDraw( params )
	if self.visible then
		AnimatedSprite.onDraw( self, params )
	end

end