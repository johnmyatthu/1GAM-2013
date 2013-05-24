require "core"

local E_STATE_CHASE = 0
local E_STATE_BOMB = 1
local E_STATE_EXPLODE = 2
local E_STATE_REMOVE = 3
local E_STATE_REPEL = 4
local E_STATE_SIT = 5
-- seconds
local SCAN_TIME = 2

Enemy = class( "Enemy", AnimatedSprite )
function Enemy:initialize()
	AnimatedSprite.initialize(self)

	self.target = nil
	self.target_tile = { x=0, y=0 }

	self.hit_color_cooldown_seconds = 0.1
	self.time_until_color_restore = 0

	self.collision_mask = 0
	self.health = 1


	self.view_direction = {x=0, y=1}
	self.view_distance = 460

	self.view_angle = 80
end

function Enemy:onSpawn( params )
	self:loadSprite( "assets/sprites/player.conf" )

	AnimatedSprite.onSpawn( self, params )
end

function Enemy:onDraw( params )


	--self.view_direction.y = math.sin(self.rotation) * self.view_distance

	local startx, starty = params.gamerules:worldToScreen( self.world_x, self.world_y )
	local endx, endy = params.gamerules:worldToScreen( self.world_x+(self.view_direction.x*32), self.world_y+(self.view_direction.y*32) )

	--love.graphics.setColor( 255, 0, 0, 255 )
	--love.graphics.line( startx, starty, endx, endy )

	--[[
	startx, starty = params.gamerules:worldToScreen( self.world_x, self.world_y )
	if self.waypoint then
		-- draw line to next waypoint
		endx, endy = params.gamerules:worldToScreen( self.waypoint.world_x, self.waypoint.world_y )
		love.graphics.setColor( 128, 128, 255, 128 )
		love.graphics.line( startx, starty, endx, endy )

	end

	if self.trace_end ~= nil then
		endx, endy = params.gamerules:worldToScreen( self.trace_end.x, self.trace_end.y )
		love.graphics.setColor( 255, 0, 255, 255 )
		love.graphics.line( startx, starty, endx, endy )	
	end
	--]]


	--[[
	-- get my position in screen space
	local x, y = params.gamerules:worldToScreen( self.world_x, self.world_y )
	y = y - 64
	x = x - 50

	love.graphics.setColor( 255, 255, 255, 255 )
	love.graphics.print( "self.path = " .. tostring(self.path), x, y )	

	y = y - 24
	love.graphics.print( "self.state = " .. tostring(self.state), x, y )
	--]]
	AnimatedSprite.onDraw( self, params )
end


function Enemy:collision( params )

	AnimatedSprite.collision(self, params)
end

function Enemy:updateDirectionForWorldPosition( world_x, world_y )
	local dx, dy = (world_x - self.world_x), (world_y - self.world_y)

	local length = math.sqrt((dx*dx) + (dy*dy))

	self.view_direction.x = dx/length
	self.view_direction.y = dy/length
end

function Enemy:onUpdate( params )
	AnimatedSprite.onUpdate( self, params )
end