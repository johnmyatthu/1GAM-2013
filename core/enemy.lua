require "core"

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

	self.collision_mask = 2
	self.health = 1

	self.obstruction = nil

	self.view_direction = {x=0, y=1}
	self.view_distance = 30
	self.rotation = 45

	self.light_radius = 0.5
	self.light_intensity = 0.75
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
	AnimatedSprite.onDraw( self, params )

	self.view_direction.x = math.cos(self.rotation) * self.view_distance
	self.view_direction.y = math.sin(self.rotation) * self.view_distance

	local startx, starty = params.gamerules:worldToScreen( self.world_x, self.world_y )
	local endx, endy = params.gamerules:worldToScreen( self.world_x+self.view_direction.x, self.world_y+self.view_direction.y )

	love.graphics.setColor( 255, 0, 0, 255 )
	love.graphics.line( startx, starty, endx, endy )
end

function Enemy:onUpdate( params )
	
	-- if params.gamestate ~= core.GAME_STATE_DEFEND then
	-- 	return
	-- end
	self.time_until_color_restore = self.time_until_color_restore - params.dt
	if self.time_until_color_restore <= 0 then
		self.color = { r=255, g=255, b=255, a=255 }
	end

	self.next_attack_time = self.next_attack_time - params.dt

	local target = params.gamerules.entity_manager:findFirstEntityByName( "Player" )
	if target then
		-- get a vector from me to the target
		local dx, dy = (target.world_x - self.world_x), (target.world_y - self.world_y)

	end

	--self.velocity.x = self.view_direction.x * 1
	--self.velocity.y = self.view_direction.y * 1

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