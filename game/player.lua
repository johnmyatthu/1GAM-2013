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

function Player:jump()
	if self:isOnGround() then
		self.velocity.y = -50
	else
		logging.verbose( "not on the ground" )
	end
end

function Player:collision( params )
	if params.other then
		self.world_x, self.world_y = self.world_x + params.dx, self.world_y + params.dy
		if params.dy ~= 0 then
			self.velocity.y = 0
		end

		if params.dy < 0 then
			self.underBlocks[ params.other ] = true
		end
	end
end

function Player:endCollision( entity )
	self.underBlocks[ entity ] = nil
end

function Player:isOnGround()

	for _,_ in pairs(self.underBlocks) do
		return true
	end

	return false

	-- return #self.underBlocks > 0
end

function Player:onDraw( params )
	if self.visible then
		AnimatedSprite.onDraw( self, params )
	end
end