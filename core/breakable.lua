require "core"
require "core.baseentity"

Breakable = class( "Breakable", AnimatedSprite )
function Breakable:initialize()
	AnimatedSprite:initialize(self)
	self.collision_mask = 2
	self.break_sound = "break1"
end

function Breakable:onDraw( params )
	if params.gamestate == GAME_STATE_DEFEND then
		AnimatedSprite.drawHealthBar( self, params )
	end
	AnimatedSprite.onDraw( self, params )
end

function Breakable:onHit( params )
	if self.health > 0 then
		self.health = self.health - params.attack_damage
		self.time_since_last_hit = 0
		if self.health < 0 then
			self.health = 0
		end
	end

	if self.health == 0 then
		params.gamerules:playSound( self.break_sound )
		local cl = params.gamerules.collision_layer
		if cl then
			cl:set( self.tile_x, self.tile_y, nil )
		end
		params.gamerules:removeEntity( self )
	end
end