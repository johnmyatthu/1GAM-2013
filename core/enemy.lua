require "core"

Enemy = class( "Enemy", PathFollower )
function Enemy:initialize()
	PathFollower.initialize(self)

	-- random values to get the ball rolling
	self.attack_damage = 2

	self.target = nil
	self.target_tile = { x=0, y=0 }

	-- time between attacks
	self.attack_cooldown_seconds = 0.5

	self.next_attack_time = 0

	self.hit_color_cooldown_seconds = 0.1
	self.time_until_color_restore = 0

	self.collision_mask = 2
	self.health = 1
end

function Enemy:onCollide( params )
	if params.other and params.other.class.name == "Bullet" then
		self.color = {r=255, g=0, b=0, a=255}
		params.gamerules:removeEntity( params.other )
		self.time_until_color_restore = self.hit_color_cooldown_seconds

		self.health = self.health - params.other.attack_damage
		self.time_since_last_hit = 0
		params.gamerules:playSound( "bullet_enemy_hit" )
	end

	Entity.onCollide( self, params )
end

function Enemy:onSpawn( params )

	self:loadSprite( "assets/sprites/critters.conf" )
	self:playAnimation( "two" )
	--self.class.super:onSpawn( params )
	PathFollower.onSpawn( self, params )

	--logging.verbose( "Enemy: Searching for target..." )
	local target = params.gamerules.entity_manager:findFirstEntityByName( "func_target" )
	if target then
		--logging.verbose( "I am setting a course to attack the target!" )
		--logging.verbose( "I am at " .. self.tile_x .. ", " .. self.tile_y )
		--logging.verbose( "Target is at " .. target.tile_x .. ", " .. target.tile_y )

		local path, cost = params.gamerules:getPath( self.tile_x, self.tile_y, target.tile_x+1, target.tile_y )
		--logging.verbose( path )
		--logging.verbose( cost )
		self:setPath( path )
		self.target = target
		self.target_tile = {x=target.tile_x, y=target.tile_y}
	else
		logging.verbose( "Unable to find target." )
	end
end

function Enemy:onUpdate( params )
	
	self.time_until_color_restore = self.time_until_color_restore - params.dt
	if self.time_until_color_restore <= 0 then
		self.color = { r=255, g=255, b=255, a=255 }
	end

	if self.target then
		-- calculate distance to target
		local dx, dy = (self.target.tile_x - self.tile_x), (self.target.tile_y - self.tile_y)
		local min_range = 1
		if math.abs(dx) <= min_range and math.abs(dy) <= min_range then
			--logging.verbose( "I am at " .. self.tile_x .. ", " .. self.tile_y )
			-- within range to attack

			self.next_attack_time = self.next_attack_time - params.dt
			if self.next_attack_time <= 0 then
				self.next_attack_time = self.attack_cooldown_seconds

				-- attack the target
				if self.target then
					if self.target.health > 0 then
						self.target:onHit( {gamerules=params.gamerules, attacker=self, attack_damage=self.attack_damage} )
					end
				end
			end
		end
	end

	if self.target and false then
		if self.target_tile.x ~= self.target.tile_x or self.target_tile.y ~= self.target.tile_y then
			logging.verbose( "plotting a new course: " .. self.target_tile.x .. ", " .. self.target_tile.y )
			logging.verbose( "course: " .. self.target.tile_x .. ", " .. self.target.tile_y )
			-- plot a new course
			local path, cost = params.gamerules:getPath( self.tile_x, self.tile_y, self.target.tile_x+1, self.target.tile_y )
			self:setPath( path )
			self.target_tile = {x=self.target.tile_x, y=self.target.tile_y}
		end
	end

	if self.health <= 0 then
		params.gamerules:playSound( "enemy_killed" )
		params.gamerules.enemies_destroyed = params.gamerules.enemies_destroyed + 1
		params.gamerules:removeEntity( self )
	end

	PathFollower.onUpdate( self, params )
end


function Enemy:onDraw( params )
	PathFollower.onDraw( self, params )
	self:drawHealthBar( params )
end