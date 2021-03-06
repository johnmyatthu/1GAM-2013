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
	self.visible = true

	self.health = 100 -- current health for this entity
	self.max_health = 100 -- maximum health for this entity
	self.health_regen_rate = 0 -- the rate (hit points per second) at which this entity will regenerate health
	self.time_since_last_hit = 0 -- the amount of time in seconds since this entity was last hit
	self.time_until_health_regen = 1 -- how much time is needed since last hit to start regenerating health

	self.velocity = { x=0, y=0 }
	self.damping = { x=1, y=1 }
	self.scale = { x=1, y=1 }
end

function Entity:onRemove( params )
end

-- this can be overridden in order to skip drawing, for example.
function Entity:respondsToEvent( event_name, params )
	return true
end

function Entity:size()
	return self.frame_width, self.frame_height
end

function Entity:setPosition(x,y)
	self.world_x, self.world_y = x,y
end

function Entity:setSize(w,h)
	self.frame_width, self.frame_height = w,h
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
	params.gamerules:moveEntityInDirection( self, self.velocity, params.dt )
	--self.world_x = self.world_x + self.velocity.x * params.dt
	--self.world_y = self.world_y + self.velocity.y * params.dt
	self.velocity.x = self.velocity.x * self.damping.x
	self.velocity.y = self.velocity.y * self.damping.y

	if params.gamerules.map then
		self.tile_x, self.tile_y = params.gamerules:tileCoordinatesFromWorld( self.world_x, self.world_y )
	end

	self.time_since_last_hit = self.time_since_last_hit + params.dt
	if params.gamestate == core.GAME_STATE_DEFEND then
		-- don't allow health regen if in win/fail conditions
		if self.health < self.max_health and self.time_since_last_hit >= self.time_until_health_regen then
			self.health = self.health + (self.health_regen_rate * params.dt)
		end
	end
end

function Entity:postFrameUpdate(params)
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
	
	-- local cx, cy = params.gamerules:getCameraPosition()
	-- love.graphics.setColor( 255, 0, 0, 255 )
	-- love.graphics.line( cx, cy, cx+self.world_x, cy+self.world_y )
end

function Entity:resetMoves( params )

end

--[[ params:
	gamerules
	other: the other entity we've collided with
	dx: displacement x
	dy: displacement y
	tile: a tile, if collided with a tile
--]]
function Entity:collision( params )
	if params.other then
		local dx = params.dx
		local dy = params.dy		
		self.world_x = self.world_x + dx
		self.world_y = self.world_y + dy
	end	
end

function Entity:endCollision( entity )
end

function Entity:onHit( params )
end

function Entity:canInteractWith( params )
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