require "core"

Scorebox = class( "Scorebox", AnimatedSprite )
function Scorebox:initialize()
	AnimatedSprite.initialize(self)

	self.collision_mask = 0

	self.color_index = 1

	self.color_table = {
		{r=255, g=0, b=0, a=255},
		{r=0, g=255, b=0, a=255},
		{r=0, g=0, b=255, a=255},
		{r=255, g=0, b=255, a=255}
	}
end

function Scorebox:collision( params )
	if params.other then
		if params.other.class.name == "Ball" then
			if params.other.color_index == self.color_index then
				params.gamerules:removeEntity( self )
			end
		end
	end

	--AnimatedSprite.collision( self, params )
end

function Scorebox:onSpawn( params )
	self:loadSprite( "assets/sprites/blocks.conf" )
	self:playAnimation( "1" )

	AnimatedSprite.onSpawn( self, params )
end

function Scorebox:onDraw( params )
	self.color = self.color_table[ self.color_index ]
	AnimatedSprite.onDraw( self, params )
end

function Scorebox:onUpdate( params )
	AnimatedSprite.onUpdate( self, params )
end