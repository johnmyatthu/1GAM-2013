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
end

function Player:onUpdate( params )
	AnimatedSprite.onUpdate(self, params)
end

function Player:respondsToEvent( event_name, params )
	if event_name == "onDraw" and params.gamestate == GAME_STATE_BUILD then
		return false
	else
		return true
	end
end

function Player:onDraw( params )
	local ox, oy = params.gamerules:worldToScreen( self.world_x, self.world_y )
	love.graphics.setColor( 255, 0, 0, 255 )
	love.graphics.line( ox, oy, ox+self.dir.x*self.aim_magnitude, oy+self.dir.y*self.aim_magnitude )
		
	AnimatedSprite.onDraw( self, params )
end
