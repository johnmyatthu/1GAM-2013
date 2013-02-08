require "core"

Player = class("Player", AnimatedSprite)
function Player:initialize()
	AnimatedSprite:initialize(self)
	self.health = 100
	self.collision_mask = 1
	self.attack_delay = 1 -- in seconds
	self.attack_damage = 1

	self.dir = {x=0, y=0}
	self.aim_magnitude = 10

	self.last_interaction_object = nil
end

function Player:onUpdate( params )
	AnimatedSprite.onUpdate(self, params)

	if self.last_interaction_object ~= nil then

		local distance = params.gamerules:calculateEntityDistance( self, self.last_interaction_object )

		if distance > 22 then
			-- get tile distance from me and my interaction object
			-- if I'm too far away, cancel interaction
			self.last_interaction_object:endInteraction( {} )
			self.last_interaction_object = nil
		end
	end
end

function Player:respondsToEvent( event_name, params )
	return true
end

function Player:onCollide( params )
	AnimatedSprite.onCollide( self, params )

	if params.other and self.last_interaction_object ~= params.other then
		self.last_interaction_object = params.other
	end
end

function Player:onDraw( params )
	local ox, oy = params.gamerules:worldToScreen( self.world_x, self.world_y )
	love.graphics.setColor( 255, 0, 0, 255 )
	love.graphics.line( ox, oy, ox+self.dir.x*self.aim_magnitude, oy+self.dir.y*self.aim_magnitude )
		
	AnimatedSprite.onDraw( self, params )
end
