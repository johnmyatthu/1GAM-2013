require "core"

Player = class("Player", AnimatedSprite)
function Player:initialize()
	AnimatedSprite.initialize(self)
	self.health = 100
	self.collision_mask = 1

	self.dir = {x=0, y=0}

	self.visible = true
end

function Player:onSpawn( params )
	self:loadSprite( "assets/sprites/blocks.conf" )
	self:playAnimation( "1" )
	AnimatedSprite.onSpawn( self, params )
end

function Player:onUpdate( params )
	AnimatedSprite.onUpdate(self, params)
end

function Player:postFrameUpdate(params)
	AnimatedSprite.postFrameUpdate(self, params)
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


function Player:canPickupItem( gamerules, entity )
	if not entity then return end
	if entity == self then return end
	return gamerules:calculateEntityDistance(entity, self) < 48
end

function Player:onDraw( params )
	if self.visible then
		AnimatedSprite.onDraw( self, params )
	end

end