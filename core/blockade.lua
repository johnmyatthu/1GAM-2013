require "core"
require "core.baseentity"


Blockade = class( "Blockade", AnimatedSprite )



function Blockade:initialize()
	AnimatedSprite:initialize(self)

	self.collision_mask = 2
	self.frame_width = 32
	self.frame_height = 32
end


function Blockade:onDraw( params )
	if params.gamestate == GAME_STATE_DEFEND then
		AnimatedSprite.drawHealthBar( self, params )
	end
	AnimatedSprite.onDraw( self, params )
end

function Blockade:onHit( params )
	--logging.verbose( "Hit target for " .. tostring(params.attack_damage) .. " damage!" )

	if self.health > 0 then
		self.health = self.health - params.attack_damage
		self.time_since_last_hit = 0
		if self.health < 0 then
			self.health = 0
		end
	end

	if self.health == 0 then
		params.gamerules:removeEntity( self )
	end
end