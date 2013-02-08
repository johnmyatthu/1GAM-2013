require "core"

local HEALTH_BAR_WIDTH = 28

Entity = class( "Entity" )
function Entity:initialize()
	-- current position in the world
	self.world_x = 0
	self.world_y = 0

	-- current tile
	self.tile_x = -1
	self.tile_y = -1

	self.frame_width = 32
	self.frame_height = 32

	self.color = { r=255, g=255, b=255, a=255 }
	self.collision_mask = 0

	self.health = 100 -- current health for this entity
	self.max_health = 100 -- maximum health for this entity
	self.health_regen_rate = 0 -- the rate (hit points per second) at which this entity will regenerate health
	self.time_since_last_hit = 0 -- the amount of time in seconds since this entity was last hit
	self.time_until_health_regen = 1 -- how much time is needed since last hit to start regenerating health
end

-- this can be overridden in order to skip drawing, for example.
function Entity:respondsToEvent( event_name, params )
	return true
end

function Entity:size()
	return self.frame_width, self.frame_height
end

function Entity:drawHealthBar( params )
	-- get screen coordinates for this entity
	local sx, sy = params.gamerules:worldToScreen( self.world_x, self.world_y )
	local r,g,b,a = params.gamerules:colorForHealth( self.health, self.max_health )

	local x, y = sx-(HEALTH_BAR_WIDTH/2), sy+(self.frame_height/2)
	local height = 4
	if self.health < 0 then
		self.health = 0
	end
	local health_percent = (self.health / self.max_health)
	love.graphics.setColor( 0, 0, 0, 192 )
	love.graphics.rectangle( 'fill', x, y, HEALTH_BAR_WIDTH, height )

	love.graphics.setColor( r, g, b, a )
	love.graphics.rectangle( 'fill', x, y, ((health_percent)*HEALTH_BAR_WIDTH), height )

	love.graphics.setColor( 255, 255, 255, 255 )	
end

function Entity:loadProperties( properties )
	if properties then
		for key, value in pairs(properties) do
			-- only load variables we expect or have previously declared in our initializer
			if self[ key ] then
				self[ key ] = value
			end
		end	
	end	
end

function Entity:onSpawn( params )
	-- load properties into instance vars;
	self:loadProperties( params.properties )

	if self.tile_x < 0 or self.tile_y < 0 then
		self.tile_x, self.tile_y = params.gamerules:tileCoordinatesFromWorld( self.world_x, self.world_y )
	end

	params.gamerules:addCollision(self)
end

function Entity:onUpdate( params )
	self.tile_x, self.tile_y = params.gamerules:tileCoordinatesFromWorld( self.world_x, self.world_y )

	self.time_since_last_hit = self.time_since_last_hit + params.dt
	if params.gamestate == core.GAME_STATE_DEFEND then
		-- don't allow health regen if in win/fail conditions
		if self.health < self.max_health and self.time_since_last_hit >= self.time_until_health_regen then
			self.health = self.health + (self.health_regen_rate * params.dt)
		end
	end
end

function Entity:__tostring()
	return "class " .. self.class.name .. " at [ " .. self.tile_x .. ", " .. self.tile_y .. " ] | World [ " .. self.world_x .. ", " .. self.world_y .. " ]"
end

function Entity:onDraw( params )
	-- uncomment this to draw collision bounds
	--[[
	local color = {r=255, g=0, b=0, a=128}
	love.graphics.setColor(color.r, color.g, color.b, color.a)
	a,b,c,d = self:getAABB()

	local sx, sy = params.gamerules:worldToScreen(a,b)
	local sw, sh = params.gamerules:worldToScreen(c,d)

	love.graphics.rectangle( "line", sx, sy, sw-sx, d-b )

	love.graphics.setColor(255, 255, 255, 255)
	--]]
end

function Entity:onCollide( params )
end

function Entity:onHit( params )
end

function Entity:canInteractWith( params )
	local distance = params.gamerules:calculateEntityDistance( self, params.other )
	if distance > 25 then
		return false
	end

	return true
end

function Entity:startInteraction( params )
end

function Entity:endInteraction( params )
end

function Entity:useActionString()
	return "do nothing"
end

-- for compatibility with spatialhash
function Entity:getAABB()
	local w,h = self:size()
	return self.world_x-(w/2), self.world_y-(h/2), self.world_x+(w/2), self.world_y+(h/2)
end