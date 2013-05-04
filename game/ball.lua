require "core"

Ball = class( "Ball", AnimatedSprite )
function Ball:initialize()
	AnimatedSprite.initialize(self)


	self.color_index = 4

	self.color_table = {
		{r=255, g=0, b=0, a=255},
		{r=0, g=255, b=0, a=255},
		{r=0, g=0, b=255, a=255},
		{r=255, g=0, b=255, a=255}
	}

	self.bounces_left = 10

end

function Ball:collision( params )
	if params.other then
		if params.other.class.name ~= "Scorebox" or (params.other.class.name == "Scorebox" and self.color_index ~= params.other.color_index) then
			self.bounces_left = self.bounces_left - 1
			self.color_index = self.color_index + 1
			if self.color_index > #self.color_table then
				self.color_index = 1
			end
		elseif params.other.class.name == "Scorebox" then
			self.bounces_left = 10
		end
	end

	if params.dx ~= 0 then
		self.velocity.x = -self.velocity.x
	end

	if params.dy ~= 0 then
		self.velocity.y = -self.velocity.y
	end

	AnimatedSprite.collision( self, params )
end

function Ball:onSpawn( params )
	self:loadSprite( "assets/sprites/blocks.conf" )
	self:playAnimation( "1" )
	AnimatedSprite.onSpawn( self, params )
end

function Ball:onDraw( params )
	self.color = self.color_table[ self.color_index ]
	AnimatedSprite.onDraw( self, params )
end

function Ball:onUpdate( params )
	AnimatedSprite.onUpdate( self, params )
end