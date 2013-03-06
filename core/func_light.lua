require "core"

func_light = class( "func_light", Entity )

function func_light:initialize()
	Entity:initialize(self)

	self.enabled = true

	self.scale_factor = 2
	self.lightmap = love.graphics.newImage( "assets/sprites/lightmap.png" )
	self.color.a = 32
end

function func_light:onSpawn( params )
	Entity.onSpawn( self, params )
end

function func_light:onDraw( params )
	love.graphics.setColor(self.color.r, self.color.g, self.color.b, self.color.a )

	local sx, sy = params.gamerules:worldToScreen( self.world_x, self.world_y )
	local cx, cy = 0,0 --(love.graphics.getWidth() / 2), (love.graphics.getHeight() / 2)

	local xoffset = sx + cx - ((self.lightmap:getWidth()/2) * self.scale_factor)
	local yoffset = sy + cy - ((self.lightmap:getHeight()/2) * self.scale_factor)	
	love.graphics.draw( self.lightmap, xoffset, yoffset, 0, self.scale_factor, self.scale_factor )
end