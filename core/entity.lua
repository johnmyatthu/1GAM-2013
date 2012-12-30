module( ..., package.seeall )
require "middleclass.middleclass"
require "core"
local logging = core.logging

Entity = class( "Entity" )

function Entity:initialize()
	-- current position in the world
	self.world_x = 0
	self.world_y = 0

	-- current tile
	self.tile_x = -1
	self.tile_y = -1	
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
	self.current_frame = "down"
	
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
	local x, y = params.gameRules:worldToScreen( (self.world_x - (self.frame_width/2)), self.world_y - self.frame_height )
	-- local x, y = math.floor(self.world_x + params.screen_x - (self.frame_width/2)), math.floor(self.world_y + params.screen_y - self.frame_height)
	love.graphics.drawq(self.image, self.quads[ self.current_frame ], x, y)
end


EntitySpawner = class( "EntitySpawner", Entity )
function EntitySpawner:initialize()
	Entity.initialize( self )
	self.spawn_time = 1
	self.time_left = self.spawn_time
	self.spawn_class = nil
	self.onSpawn = nil
end


function EntitySpawner:onUpdate( params )
	local dt = params.dt
	self.time_left = self.time_left - dt

	if self.time_left <= 0 then
		self.time_left = self.spawn_time
		local instance = self.spawn_class:new()
		if self.onSpawn then
			self.onSpawn( {entity=instance} )
		end
	end
end


