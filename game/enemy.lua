require "core"

local E_STATE_CHASE = 0
local E_STATE_BOMB = 1

-- seconds
local SCAN_TIME = 2

Enemy = class( "Enemy", PathFollower )
function Enemy:initialize()
	PathFollower.initialize(self)

	self.target = nil
	self.target_tile = { x=0, y=0 }

	self.hit_color_cooldown_seconds = 0.1
	self.time_until_color_restore = 0

	self.collision_mask = 3
	self.health = 1


	self.view_direction = {x=0, y=1}
	self.view_distance = 460

	self.view_angle = 80

	self.normal_move_speed = 32
	self.persue_multiplier = 2.0
	self.move_speed = self.normal_move_speed
	self.move_multiplier = 1.0

	self.state = E_STATE_CHASE
	self.timeleft = 0
end

function Enemy:onSpawn( params )
	self:loadSprite( "assets/sprites/blocks.conf" )
	self:playAnimation( "1" )

	self.target = params.gamerules.entity_manager:findFirstEntityByName("Player")

	PathFollower.onSpawn( self, params )
end

function Enemy:onDraw( params )
	if self.state == E_STATE_CHASE then
		if self.target then
			local mettx, metty = self.target.world_x - self.world_x, self.target.world_y - self.world_y

			local len = core.util.vector.length( mettx, metty )
			mettx = mettx / len
			metty = metty / len

			self.velocity.x = (mettx) * params.gamerules.data["enemy"].chase_speed
			self.velocity.y = (metty) * params.gamerules.data["enemy"].chase_speed

			self.view_direction.x = mettx
			self.view_direction.y = metty
		end
	elseif self.state == E_STATE_BOMB then

	end
	--self.view_direction.y = math.sin(self.rotation) * self.view_distance

	local startx, starty = params.gamerules:worldToScreen( self.world_x, self.world_y )
	local endx, endy = params.gamerules:worldToScreen( self.world_x+(self.view_direction.x*32), self.world_y+(self.view_direction.y*32) )

	love.graphics.setColor( 255, 0, 0, 255 )
	love.graphics.line( startx, starty, endx, endy )

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
	if params.other == self.target then
		self.target = nil
		self.velocity.x = 0
		self.velocity.y = 0		
		self.timeleft = params.gamerules.data["enemy"].bomb_time
		self.state = E_STATE_BOMB
	end


	PathFollower.collision(self, params)
end

function Enemy:updateDirectionForWorldPosition( world_x, world_y )
	local dx, dy = (world_x - self.world_x), (world_y - self.world_y)

	local length = math.sqrt((dx*dx) + (dy*dy))

	self.view_direction.x = dx/length
	self.view_direction.y = dy/length
end

function Enemy:updateDirectionForWaypoint( target )
	if target == nil then
		return
	end

	self:updateDirectionForWorldPosition( target.world_x, target.world_y )
end



function Enemy:runBoidsRules( params, boids )

	-- Rule #1: Tend towards the center of others
	-- Rule #2: Maintain a minimum distance from others
	-- Rule #3: Boids tr to match velocity with nearby others
	local cm = {x=0, y=0}
	local min_dist = {x = 0, y = 0}
	local cv = {x=0, y=0}

	local vp = {x=0, y=0}
	local player = params.gamerules.entity_manager:findFirstEntityByName( "Player" )

	for _,boid in pairs(boids) do
		if boid ~= self then
			cm.x = cm.x + boid.world_x
			cm.y = cm.y + boid.world_y

			local dx, dy = (boid.world_x - self.world_x), (boid.world_y - self.world_y)
			local distance = math.abs(core.util.vector.length( dx, dy ))
			if distance < 48 then
				min_dist.x = min_dist.x - dx
				min_dist.y = min_dist.y - dy
			end

			cv.x = cv.x + boid.velocity.x
			cv.y = cv.y + boid.velocity.y
		end
	end


	if player then
		cm.x = (player.world_x - self.world_x)
		cm.y = (player.world_y - self.world_y)
	else
		-- compute average position
		cm.x = (cm.x / #boids)
		cm.y = (cm.y / #boids)

		cm.x = cm.x - self.world_x
		cm.y = cm.y - self.world_y		
	end


	cv.x = (cv.x / #boids)
	cv.y = (cv.y / #boids)


	if math.abs(cm.x) < 64 then
		cm.x = 0
	end

	if math.abs(cm.y) < 64 then
		cm.y = 0
	end

	local weight = 0.35

	self.velocity.x = (cm.x * weight) + (min_dist.x) + (cv.x)
	self.velocity.y = (cm.y * weight) + (min_dist.y) + (cv.y)
end


function Enemy:findWaypoint( params, name )
	if name == nil then
		logging.warning( "waypoint name is invalid!" )
	end

	local waypoints = params.gamerules.entity_manager:findAllEntitiesByName( "func_waypoint" )
	for _,wp in pairs(waypoints) do
		if wp.name == name then
			self.waypoint = wp
			return
		end
	end
end

function Enemy:onUpdate( params )
	self.move_speed = self.normal_move_speed * self.move_multiplier


	PathFollower.onUpdate( self, params )
end