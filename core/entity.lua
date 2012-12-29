module( ..., package.seeall )
require "middleclass.middleclass"
require "core"
local logging = core.logging

Entity = class( "Entity" )

function Entity:initialize()
end

function Entity:onSpawn( params )
end

function Entity:onUpdate( params )
end

function Entity:onDraw( params )
end

-- a base "world" entity that exists in the game world
WorldEntity = class( "WorldEntity", Entity )
function WorldEntity:initialize()
	-- current position in the world
	self.world_x = 100
	self.world_y = 100

	-- current tile
	self.tile_x = -1
	self.tile_y = -1

	
	self.frame_width = 32
	self.frame_height = 64

	self.quads = {				-- The frames of the image
		down = 		love.graphics.newQuad(0,0,32,64,256,64),
		downright = love.graphics.newQuad(32,0,32,64,256,64),
		right = 	love.graphics.newQuad(64,0,32,64,256,64),
		upright = 	love.graphics.newQuad(96,0,32,64,256,64),
		up = 		love.graphics.newQuad(128,0,32,64,256,64),
		upleft = 	love.graphics.newQuad(160,0,32,64,256,64),
		left = 		love.graphics.newQuad(192,0,32,64,256,64),
		downleft = 	love.graphics.newQuad(224,0,32,64,256,64),
	}
	-- The image
	self.image = love.graphics.newImage("images/guy.png")

end

function WorldEntity:__tostring()
	return "WorldEntity at world:[ " .. self.world_x .. ", " .. self.world_y .. " ]"
end

function WorldEntity:onUpdate( params )
end

function WorldEntity:onDraw( params )
	local x, y = math.floor(self.world_x + params.screen_x - (self.frame_width/2)), math.floor(self.world_y + params.screen_y - self.frame_height)
	love.graphics.drawq(self.image, self.quads["left"], x, y)

	
end