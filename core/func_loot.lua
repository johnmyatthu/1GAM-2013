require "core"
require "core.baseentity"

func_loot = class( "func_loot", AnimatedSprite )
function func_loot:initialize()
	AnimatedSprite:initialize(self)
	self.collision_mask = 0
end

function func_loot:onSpawn( params )
	self:loadSprite( "assets/sprites/items.conf" )
	self:playAnimation( "idle" )

	AnimatedSprite.onSpawn( self, params )

	-- adjust the light
	self.light_scale = 2.0
	self.light_radius = 1.0
end

function func_loot:onDraw( params )
	AnimatedSprite.onDraw( self, params )
end


function func_loot:onRemove( params )
	self.light.intensity = 0
end