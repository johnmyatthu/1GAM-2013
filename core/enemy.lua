require "core"

local E_STATE_WAYPOINT = 0
local E_STATE_SCAN = 1


-- seconds
local SCAN_TIME = 2
local MIN_PLAYER_LIGHT_LEVEL = 0.25

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
	self.view_distance = 256
	self.view_angle = 60
	self.rotation = 0

	self.light_scale = 0.5
	self.light_radius = 0.4
	self.light_intensity = 0.75

	self.move_speed = 32

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
	if params.other and params.other.class.name == "Bullet" then
		self.color = {r=255, g=0, b=0, a=255}
		params.gamerules:removeEntity( params.other )
		self.time_until_color_restore = self.hit_color_cooldown_seconds

		self.health = self.health - params.other.attack_damage
		self.time_since_last_hit = 0
		params.gamerules:playSound( "bullet_enemy_hit" )
	elseif params.other.health > 0 and (self.class.name ~= params.other.class.name) then

		-- this entity is probably in our way...
		if self.next_attack_time <= 0 then
			self.next_attack_time = self.attack_delay
			params.other:onHit( {attack_damage=self.attack_damage, gamerules=params.gamerules} )
			
			if params.other.health > 0 then
				self.follow_path = false
				self.obstruction = params.other
			else
				self.follow_path = true
			end
		end

		-- stop, we found our target
		if params.other == self.target then
			self.follow_path = false
		end		
	end

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

function Enemy:updateDirectionForWaypoint( target )
	if target == nil then
		return
	end

	local dx, dy = (target.world_x - self.world_x), (target.world_y - self.world_y)

	local length = math.sqrt((dx*dx) + (dy*dy))

	self.view_direction.x = dx/length
	self.view_direction.y = dy/length

	--logging.verbose( "x: " .. self.view_direction.x .. ", y: " .. self.view_direction.y )
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
		end
	elseif self.state == E_STATE_SCAN then
		self.scan_time = self.scan_time - params.dt
		if self.scan_time <= 0 then
			self.state = E_STATE_WAYPOINT
			self:updateDirectionForWaypoint( self.waypoint )
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

		if dp > 0 then
			local angle = math.deg(core.util.vector.angle( x, y, self.view_direction.x, self.view_direction.y) )
			if distance < self.view_distance and angle < self.view_angle and target.light_level > MIN_PLAYER_LIGHT_LEVEL then
				--self.saw_player = 2

				-- we have to perform a trace from wx, wy to wx2, wy2
				-- if any collision tiles are present, we must ignore it
				
				local x, y, hit = params.gamerules:collisionTrace( self.world_x, self.world_y, target.world_x, target.world_y )
				if hit == 0 then
					self.saw_player = 2
				end
				self.trace_end = {x=x, y=y}
			end
		end
	end

	if self.waypoint and self.state == E_STATE_WAYPOINT then
		self.velocity.x = self.view_direction.x * self.move_speed
		self.velocity.y = self.view_direction.y * self.move_speed
	else
		self.velocity.x = 0
		self.velocity.y = 0
	end

	--params.gamerules:handleMovePlayerCommand

	if self.target then
		-- calculate distance to target
		local dx, dy = (self.target.tile_x - self.tile_x), (self.target.tile_y - self.tile_y)
		local min_range = 1
		if math.abs(dx) <= min_range and math.abs(dy) <= min_range then		
			if self.next_attack_time <= 0 then
				self.next_attack_time = self.attack_delay

				-- attack the target
				if self.target then
					if self.target.health > 0 then
						self.target:onHit( {gamerules=params.gamerules, attacker=self, attack_damage=self.attack_damage} )
					end
				end
			end
		end
	end

	if self.health <= 0 then
		params.gamerules:playSound( "enemy_killed" )
		params.gamerules:onEnemyDestroyed( self )
		params.gamerules:removeEntity( self )
	end

	if self.obstruction then
		if self.obstruction.health <= 0 then
			self.follow_path = true
			self.obstruction = nil
		end
	end

	PathFollower.onUpdate( self, params )
end

--[[
function Enemy:onDraw( params )
	PathFollower.onDraw( self, params )
	self:drawHealthBar( params )
end
--]]