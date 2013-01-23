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
			--logging.verbose( "'" .. key .. "' to '" .. value .. "'" )
			-- only load variables we expect
			if self[ key ] then
				self[ key ] = value
				--logging.verbose( "set '" .. key .. "' to '" .. value .. "'" )
			end
		end	
	end	
end

function Entity:onSpawn( params )
	--logging.verbose( "Entity:onSpawn... " .. tostring(self) )

	-- load properties into instance vars;
	self:loadProperties( params.properties )

	if self.tile_x < 0 or self.tile_y < 0 then
		--logging.verbose( "Entity:onSpawn world location: " .. self.world_x .. ", " .. self.world_y )
		self.tile_x, self.tile_y = params.gamerules:tileCoordinatesFromWorld( self.world_x, self.world_y )
		--logging.verbose( "Entity:onSpawn tile location: " .. self.tile_x .. ", " .. self.tile_y )
	end

	params.gamerules:addCollision(self)
end

function Entity:onUpdate( params )
	self.tile_x, self.tile_y = params.gamerules:tileCoordinatesFromWorld( self.world_x, self.world_y )

	self.time_since_last_hit = self.time_since_last_hit + params.dt
	if self.health < self.max_health and self.time_since_last_hit >= self.time_until_health_regen then
		self.health = self.health + (self.health_regen_rate * params.dt)
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
	if params.other then
		--logging.verbose( tostring(self) .. " COLLIDES WITH " .. tostring(params.other) )
		--logging.verbose( self.collision_mask .. " vs " .. params.other.collision_mask )
	end
end

-- params:
--	attacker: The attacking entity
--	damage: Base damage for the hit
function Entity:onHit( params )
end


-- for compatibility with spatialhash
function Entity:getAABB()
	local w,h = self:size()
	return self.world_x-(w/2), self.world_y-(h/2), self.world_x+(w/2), self.world_y+(h/2)
end