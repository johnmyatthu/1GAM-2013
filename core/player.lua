require "core"

Player = class("Player", AnimatedSprite)
function Player:initialize()
	AnimatedSprite.initialize(self)
	self.health = 100
	self.collision_mask = 1
	self.attack_delay = 1 -- in seconds
	self.attack_damage = 1

	self.dir = {x=0, y=0}
	self.aim_magnitude = 10

	self.last_interaction_object = nil
	self.is_using = false
	self.was_using_lastframe = false
end

function Player:onSpawn( params )
	self:loadSprite( "assets/sprites/player.conf" )
	self:playAnimation( "idle" )
	AnimatedSprite.onSpawn( self, params )
end

function Player:onUpdate( params )
	-- pretend there is some buoyancy
	--if self.world_y > 10 then
	--	self.velocity.y = self.velocity.y - (0.25 * (self.world_y/500))
	--end


	AnimatedSprite.onUpdate(self, params)

	if self.last_interaction_object ~= nil then
		if not self:canInteractWith( {gamerules=params.gamerules, other=self.last_interaction_object} ) then
			-- get tile distance from me and my interaction object
			-- if I'm too far away, cancel interaction
			self.last_interaction_object:endInteraction( {} )
			self.last_interaction_object = nil
		end
	end

	if self.last_interaction_object then
		if not self.was_using_lastframe and self.is_using then
			self.last_interaction_object:startInteraction( {} )
		elseif self.was_using_lastframe and not self.is_using then
			self.last_interaction_object:endInteraction( {} )
		end	
	end

	self.was_using_lastframe = self.is_using
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
