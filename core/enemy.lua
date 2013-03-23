require "core"

local E_STATE_WAYPOINT = 0
local E_STATE_SCAN = 1
local E_STATE_INVESTIGATE = 2
local E_STATE_FIND_WAYPOINT = 3

-- seconds
local SCAN_TIME = 2
local MIN_PLAYER_LIGHT_LEVEL = 0.03

Enemy = class( "Enemy", PathFollower )
function Enemy:initialize()
	PathFollower.initialize(self)

	-- random values to get the ball rolling
	self.attack_damage = 2

	self.target = nil
	self.target_tile = { x=0, y=0 }

	-- time between attacks
	self.attack_delay = 0.5

	self.next_attack_time = 0

	self.hit_color_cooldown_seconds = 0.1
	self.time_until_color_restore = 0

	self.collision_mask = 0
	self.health = 1

	self.obstruction = nil

	self.view_direction = {x=0, y=1}
	self.view_distance = 460

	self.view_angle = 100
	self.rotation = 0

	self.light_scale = 0.5
	self.light_radius = 0.4
	self.light_intensity = 0.75

	self.normal_move_speed = 32
	self.persue_multiplier = 2.0
	self.move_speed = self.normal_move_speed
	self.move_multiplier = 1.0

	self.waypoint = nil
	self.first_waypoint = 0

	self.state = E_STATE_WAYPOINT -- can be 'waypoint' or 'scan'
	-- waypoint state will be actively moving towards a waypoint
	-- scan state will be paused at a waypoint looking around

	self.scan_time = SCAN_TIME
	self.saw_player = 0
	self.trace_end = nil

end

function Enemy:onCollide( params )
	Entity.onCollide( self, params )
end

function Enemy:onSpawn( params )
	self:loadSprite( "assets/sprites/critters.conf" )
	self:playAnimation( "one" )
	PathFollower.onSpawn( self, params )

	local target = params.gamerules.entity_manager:findFirstEntityByName( "Player" )
	if target and target.light_level > 0.2 then
		local path, cost = params.gamerules:getPath( self.tile_x, self.tile_y, target.tile_x, target.tile_y )
		self:setPath( path )
		self.target = target
		self.target_tile = {x=target.tile_x, y=target.tile_y}
	else
		logging.verbose( "Unable to find target." )
	end
end

function Enemy:onDraw( params )

	if self.saw_player > 0 then
		self.color = {r=255, g=0, b=0, a=255}
	else
		self.color = {r=255, g=255, b=255, a=255}
	end

	AnimatedSprite.onDraw( self, params )

	--self.view_direction.x = math.cos(self.rotation) * self.view_distance
	--self.view_direction.y = math.sin(self.rotation) * self.view_distance

	local startx, starty = params.gamerules:worldToScreen( self.world_x, self.world_y )
	local endx, endy = params.gamerules:worldToScreen( self.world_x+(self.view_direction.x*32), self.world_y+(self.view_direction.y*32) )

	love.graphics.setColor( 255, 0, 0, 255 )
	love.graphics.line( startx, starty, endx, endy )

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

	--logging.verbose( "Unable to find waypoint: " .. name )
end

function Enemy:onUpdate( params )
	
	-- if params.gamestate ~= core.GAME_STATE_DEFEND then
	-- 	return
	-- end
	if not self.waypoint then
		-- first task: find a waypoint
		self:findWaypoint( params, self.first_waypoint )
		self:updateDirectionForWaypoint( self.waypoint )
	end

	if self.saw_player > 0 then
		self.saw_player = self.saw_player - params.dt
		if self.saw_player <= 0 then
			self.saw_player = 0

		end
	end

	-- move towards waypoint
	if self.waypoint and self.state == E_STATE_WAYPOINT then
		local dist = params.gamerules:calculateEntityDistance( self.waypoint, self )
		if dist < 32 then
			-- enter scan state
			self.state = E_STATE_SCAN

			-- find the next waypoint here
			self:findWaypoint( params, self.waypoint.next_waypoint )

			-- update scan time
			self.scan_time = SCAN_TIME
			self.move_multiplier = 1.0			
		end
	elseif self.state == E_STATE_SCAN then
		self.scan_time = self.scan_time - params.dt

		if self.scan_time <= 0 then
			local tx, ty, hit = params.gamerules:collisionTrace( self.world_x, self.world_y, self.waypoint.world_x, self.waypoint.world_y )
			self.move_multiplier = 1.0
			if hit == 0 then
				-- hit nothing
				self.state = E_STATE_WAYPOINT
				self:updateDirectionForWaypoint( self.waypoint )
			elseif self.path == nil then
				-- find a path to the waypoint
				self.path = params.gamerules:getPath( self.tile_x, self.tile_y, self.waypoint.tile_x, self.waypoint.tile_y )
				self.state = E_STATE_FIND_WAYPOINT
			end
		end
	elseif self.state == E_STATE_INVESTIGATE then
		local dist = core.util.vector.length( self.world_x-self.trace_end.x, self.world_y-self.trace_end.y )
		self.move_multiplier = self.persue_multiplier
		if dist < 16 then
			local target = params.gamerules.entity_manager:findFirstEntityByName( "Player" )
			if target and not target.is_tagged then
				target.is_tagged = true
			end
			self.state = E_STATE_SCAN
			self:findWaypoint( params, self.waypoint.next_waypoint )
			self.scan_time = SCAN_TIME
		end
	elseif self.state == E_STATE_FIND_WAYPOINT then
		if self.path then
			local tile = self.path[ self.current_path_step ]
			if tile then
				-- update view direction for this tile
				local world_x, world_y = params.gamerules:worldCoordinatesFromTileCenter( tile.x, tile.y )
				self:updateDirectionForWorldPosition( world_x, world_y )
			end
		else
			self.state = E_STATE_SCAN
			self.scan_time = SCAN_TIME
			self:findWaypoint( params, self.waypoint.next_waypoint )
		end
	end

	self.time_until_color_restore = self.time_until_color_restore - params.dt
	if self.time_until_color_restore <= 0 then
		self.color = { r=255, g=255, b=255, a=255 }
	end

	self.next_attack_time = self.next_attack_time - params.dt

	local target = params.gamerules.entity_manager:findFirstEntityByName( "Player" )
	if target then
		-- get a vector from me to the target
		local dx, dy = (target.world_x - self.world_x), (target.world_y - self.world_y)
		--logging.verbose( "dx: " .. dx .. ", dy: " ..  dy )
		--local len = math.sqrt( (dx*dx) + (dy*dy) )
		local distance = core.util.vector.length( dx, dy )
		local x = dx/distance
		local y = dy/distance

		--logging.verbose( "x: " .. x .. ", y: " ..  y )

		-- so now we dot the vector we have with the view_diraction of the enemy
		dx, dy = (x - self.view_direction.x), (y - self.view_direction.y)
		local dp = (x * self.view_direction.x) + (y * self.view_direction.y)
		local delta_len = core.util.vector.length( dx, dy )
		if dp > 0 then
			local angle = math.deg(core.util.vector.angle( x, y, self.view_direction.x, self.view_direction.y) )
			if distance < self.view_distance and angle < self.view_angle and target.light_level > MIN_PLAYER_LIGHT_LEVEL then
				--self.saw_player = 2

				-- we have to perform a trace from wx, wy to wx2, wy2
				-- if any collision tiles are present, we must ignore it
				
				local tx, ty, hit = params.gamerules:collisionTrace( self.world_x, self.world_y, target.world_x, target.world_y )
				if hit == 0 then
					self.saw_player = 2
					self.state = E_STATE_INVESTIGATE
					self.path = nil
					-- update view direction to follow the last seen point
					self.view_direction.x = x
					self.view_direction.y = y
					self.trace_end = {x=tx, y=ty}
				end
				
			end
		end
	end



	dir = {x = 0, y = 0}
	if not self.path and self.waypoint and self.state ~= E_STATE_SCAN then
		dir.x = self.view_direction.x * self.move_speed * self.move_multiplier
		dir.y = self.view_direction.y * self.move_speed * self.move_multiplier
	elseif self.path then
		if self.velocity.x ~= 0 then
			if self.velocity.x > 0 then
				dir.x = self.move_speed
			else
				dir.x = -self.move_speed
			end
		end
		if self.velocity.y ~= 0 then
			if self.velocity.y > 0 then
				dir.y = self.move_speed
			else
				dir.y = -self.move_speed
			end
		end
	else
		dir.x = 0
		dir.y = 0
	end

	if params.gamerules:moveEntityInDirection( self, dir, params.dt ) then
		self.velocity.x = 0
		self.velocity.y = 0
		--logging.verbose( "hit tile: " .. dir.x .. ", " .. dir.y )
		self.state = E_STATE_SCAN
		self:findWaypoint( params, self.waypoint.next_waypoint )
		self.scan_time = SCAN_TIME
	else


	end


	PathFollower.onUpdate( self, params )
end

--[[
function Enemy:onDraw( params )
	PathFollower.onDraw( self, params )
	self:drawHealthBar( params )
end
--]]