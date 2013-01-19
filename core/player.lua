require "core"


Player = class("Player", AnimatedSprite)
function Player:initialize()
	AnimatedSprite:initialize(self)
	self.health = 100
	self.collision_mask = 1
	self.attack_delay = 1 -- in seconds
	self.attack_damage = 1
end

function Player:onUpdate( params )
	--local r,g,b,a = params.gamerules:colorForHealth(self.health, self.max_health)
	--self.color = {r=r, g=g, b=b, a=a}

	AnimatedSprite.onUpdate(self, params)
end

function Player:respondsToEvent( event_name, params )
	if event_name == "onDraw" and params.gamestate == GAME_STATE_BUILD then
		return false
	else
		return true
	end
end
