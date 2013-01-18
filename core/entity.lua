module( ..., package.seeall )
require "core"
local logging = core.logging
require "lib.luabit.bit"
local GAME_STATE_BUILD = core.GAME_STATE_BUILD
local GAME_STATE_DEFEND = core.GAME_STATE_DEFEND

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
	self.health = 0
end

-- this can be overridden in order to skip drawing, for example.
function Entity:respondsToEvent( event_name )
	return true
end

function Entity:size()
	return self.frame_width, self.frame_height
end

function Entity:drawHealthBar( params )
	-- get screen coordinates for this entity
	local sx, sy = params.gamerules:worldToScreen( self.world_x, self.world_y )
	local r,g,b,a = params.gamerules:colorForHealth(self.health)
	local width = 32
	local x, y = sx-(width/2), sy-self.frame_height
	local height = 4
	love.graphics.setColor( 0, 0, 0, 192 )
	love.graphics.rectangle( 'fill', x, y, width, height )

	love.graphics.setColor( r, g, b, a )
	love.graphics.rectangle( 'fill', x, y, ((self.health*.01)*width), height )

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
end

function Entity:__tostring()
	return "class " .. self.class.name .. " at [ " .. self.tile_x .. ", " .. self.tile_y .. " ] | World [ " .. self.world_x .. ", " .. self.world_y .. " ]"
end

function Entity:onDraw( params )
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

-- a base "world" entity that exists in the game world
AnimatedSprite = class( "AnimatedSprite", Entity )

function AnimatedSprite:initialize()
	Entity:initialize(self)
	self.is_attacking = false
	self.current_animation = 1
	self.current_direction = "east"
	self.animations = nil
	self.spritesheet = nil
	self.animation_index_from_name = {}
end


-- I hate the way this works; it's so hacky. So, until I come up with a better way...
function AnimatedSprite:setDirectionFromMoveCommand( command )
	self.current_direction = ""

	if command.up then
		self.current_direction = "north"
	elseif command.down then
		self.current_direction = "south"
	elseif command.left then
		self.current_direction = "east"
	elseif command.right then
		self.current_direction = "west"
	end

	-- for isometric animations, split north/south and east/west into two separate ifs instead of if elseif.
	-- then concat the directions to form: "northeast" or "southwest"

end

function AnimatedSprite:loadSprite( config_file )
	if love.filesystem.exists( config_file ) then
		local sprite_config = json.decode( love.filesystem.read( config_file ) )
		--logging.verbose( "loadSprite: image '" .. sprite_config.image .. "'" )

		if sprite_config.frame_width and sprite_config.frame_height then
			self.frame_width = sprite_config.frame_width
			self.frame_height = sprite_config.frame_height
		else
			logging.warning( "loadSprite: Sprite config does not specify frame dimensions! Aborting." )
			return
		end

		-- load the image for this sprite
		self.image = love.graphics.newImage( sprite_config.image )
		if self.image then
			--logging.verbose( "loadSprite: loaded image w x h = " .. self.image:getWidth() .. " x " .. self.image:getHeight() )

			-- create a spritesheet and load animations
			self.spritesheet = core.SpriteSheet.new( self.image, self.frame_width, self.frame_height )
			self.animations = {}

			-- this makes some assumptions about our animation sprite sheet.
			-- * The sprite sheet can contain any number of animations across columns (horizontally).
			-- * The sprite sheet uses each row (vertical axis) for different directions

			local total_rows = self.image:getWidth() / self.frame_width
			local total_cols = self.image:getHeight() / self.frame_height
			--logging.verbose( "total_rows: " .. total_rows )
			--logging.verbose( "total_cols: " .. total_cols )

			-- isometric
			--local directions = { "east", "northeast", "north", "northwest", "west", "southwest", "south", "southeast" }
			local directions = { "east", "north", "west", "south" }

			self.total_directions = #directions

			if total_cols < #directions then
				self.total_directions = total_cols
			end

			for _,animdata in pairs(sprite_config.animations) do
				--logging.verbose( "ANIMATION: " .. animdata.name )

				local anim_index = (#self.animations+1)
				--logging.verbose( "anim_index: " .. anim_index )
				self.animation_index_from_name[ animdata.name ] = anim_index
				self.animations[ anim_index ] = {}

				-- start processing only the first row for now
				for row=1,#directions do
					if row > total_cols then
						break
					end
					local direction = directions[ row ]
					local animation = self.spritesheet:createAnimation()

					--logging.verbose( "-> row: " .. row )
					--logging.verbose( "-> direction: " .. direction )

					-- if specified, update the animation delay.
					if animdata.delay_seconds then
						animation:setDelay( animdata.delay_seconds )
					end

					-- add frames of the animation
					for col = animdata.column_start, (animdata.column_start+animdata.num_frames-1) do
						animation:addFrame( col, row )
					end

					self.animations[ anim_index ][ direction ] = animation

					-- make sure this renders as the first frame
					animation.currentFrame = 1
				end
			end

			--logging.verbose( "loadSprite: animations loaded: " .. (#self.animations) )
		else
			logging.warning( "loadSprite: Could not load image: '" .. sprite_config.image .. "'" )
		end

	else
		logging.warning( "loadSprite: No file named " .. config_file .. " found!" )
	end
end


function AnimatedSprite:playAnimation( name )
	self.current_animation = 1
	if self.animation_index_from_name[ name ] then
		self.current_animation = self.animation_index_from_name[ name ]
	else
		logging.verbose( "Unable to find animation: " .. name )
	end
end

-- params:
--	dt: the frame delta time
function AnimatedSprite:onUpdate( params )
	if self.animations then
		-- constrain the animation to the first direction if this one is invalid
		if self.animations[ self.current_animation ][ self.current_direction ] == nil then
			self.current_direction = "east"
		end
		local animation = self.animations[ self.current_animation ][ self.current_direction ]
		if animation then
			animation:update(params.dt)
		end
	end

	Entity.onUpdate( self, params )
end

-- params:
--	gamerules: the instance of the active gamerules class
function AnimatedSprite:onDraw( params )
	Entity.onDraw(self, params)

	love.graphics.setColor( self.color.r, self.color.g, self.color.b, self.color.a )
	if self.animations then
		local x, y = params.gamerules:worldToScreen( (self.world_x - (self.frame_width/2)), self.world_y - (self.frame_height/2) )

		local animation = self.animations[ self.current_animation ][ self.current_direction ]
		if animation then
			animation:draw(x, y)
		end
	end

	love.graphics.setColor( 255, 255, 255, 255 )
end


PathFollower = class( "PathFollower", AnimatedSprite )
function PathFollower:initialize()
	AnimatedSprite:initialize(self)

	self.path = nil
	self.current_path_step = 1

	self.velocity = { x=0, y=0 }
end

function PathFollower:setPath( path )
	if path then
		self.path = path
		self.current_path_step = 1
	else
		logging.warning( "PathFollower: path is invalid, ignoring!" )
	end
end

function PathFollower:currentTarget()
	if self.path and self.current_path_step < #self.path then
		return self.path[ self.current_path_step ]
	else
		return {x=-1, y=-1}
	end
end

function PathFollower:onUpdate( params )
	--AnimatedSprite:onUpdate( params )

	-- the minimum number of units the sprite can be to a tile's center before it is considered "close enough"
	local TILE_DISTANCE_THRESHOLD = 2
	local command = { up=false, down=false, left=false, right=false }
	command.move_speed = 75
	command.dt = params.dt

	if self.path then
		tile = self.path[ self.current_path_step ]



		local cx, cy = params.gamerules:worldCoordinatesFromTileCenter( tile.x, tile.y )
		--logging.verbose( "tile.x: " .. tile.x .. ", tile.y: " .. tile.y )

		self.velocity.x = cx - self.world_x
		self.velocity.y = cy - self.world_y


		--logging.verbose( "c.x: " .. cx .. ", c.y: " .. cy )
		--logging.verbose( "w.x: " .. self.world_x .. ", w.y: " .. self.world_y )
		--logging.verbose( "v.x: " .. self.velocity.x .. ", v.y: " .. self.velocity.y )
		-- determine absolute distance
		--logging.verbose( "velocity: " .. self.velocity.x .. ", " .. self.velocity.y )
		local dx, dy = math.abs(self.velocity.x), math.abs(self.velocity.y)

		-- check x and y separately, snap these in place if they're within the threshold
		if dx < TILE_DISTANCE_THRESHOLD then
			self.world_x = cx
			self.velocity.x = 0
		end

		if dy < TILE_DISTANCE_THRESHOLD then
			self.world_y = cy
			self.velocity.y = 0
		end

		if self.tile_x == tile.x and self.tile_y == tile.y and dx < TILE_DISTANCE_THRESHOLD and dy < TILE_DISTANCE_THRESHOLD then
			--logging.verbose( "dx: " .. dx .. ", dy: " .. dy )
			self.world_x = cx
			self.world_y = cy

			if self.current_path_step == #self.path then
				--logging.verbose( "ended path at " .. self.current_path_step )
				self.path = nil
				return			
			end

			
			self.current_path_step = self.current_path_step + 1
			--logging.verbose( "next path step ... " .. self.current_path_step )

			return
		end


		-- this mess should be refactored and put into gamerules to use collision.
		local min_vel = command.move_speed
		
		local mx = 0
		local my = 0
		if self.velocity.x ~= 0 then
			if self.velocity.x > 0 then mx = command.move_speed else mx = -command.move_speed end
		end
		if self.velocity.y ~= 0 then
			if self.velocity.y > 0 then my = command.move_speed else my = -command.move_speed end
		end

		local vertical_speed = my
		if mx ~= 0 and my ~= 0 then
			vertical_speed = my * 0.5
		end

		if self.velocity.x > 0 then
			command.right = true
		elseif self.velocity.x < 0 then
			command.left = true
		end

		if self.velocity.y > 0 then
			command.down = true
		elseif self.velocity.y < 0 then
			command.up = true
		end

		self.world_x = self.world_x + (mx * params.dt)
		self.world_y = self.world_y + (vertical_speed * params.dt)
		--logging.verbose( "up: " .. tostring(command.up) .. ", down: " .. tostring(command.down) .. ", left: " .. tostring(command.left) .. ", right: " .. tostring(command.right) )
	end

	command.move_speed = 0
	params.gamerules:handleMovePlayerCommand( command, self )

	AnimatedSprite.onUpdate(self, params)
end


func_target = class( "func_target", AnimatedSprite )
function func_target:initialize()
	AnimatedSprite:initialize(self)

	self.health = 100
	self.collision_mask = 10
end

function func_target:onSpawn( params )
	self:loadSprite( "assets/sprites/target.conf" )
	self:playAnimation( "one" )
	AnimatedSprite.onSpawn( self, params )
end

function func_target:onHit( params )
	--logging.verbose( "Hit target for " .. tostring(params.attack_damage) .. " damage!" )

	if self.health > 0 then
		self.health = self.health - params.attack_damage
		if self.health < 0 then
			self.health = 0
		end
	end

	if self.health == 0 then
		params.gamerules:removeEntity( self )
	end
end

function func_target:__tostring()
	return AnimatedSprite.__tostring(self) .. ", Health: " .. self.health
end

function func_target:onDraw( params )
	AnimatedSprite.onDraw( self, params )

	self:drawHealthBar( params )
end

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
	self.health = 100
end

function Enemy:onCollide( params )
	if params.other and params.other.class.name == "Bullet" then
		self.color = {r=255, g=0, b=0, a=255}
		params.gamerules:removeEntity( params.other )
		self.time_until_color_restore = self.hit_color_cooldown_seconds

		self.health = self.health - params.other.attack_damage
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
		params.gamerules:removeEntity( self )
	end

	PathFollower.onUpdate( self, params )
end


function Enemy:onDraw( params )
	PathFollower.onDraw( self, params )
	self:drawHealthBar( params )
end


func_spawn = class( "func_spawn", Entity )
function func_spawn:initialize()
	Entity:initialize(self)
	self.gamerules = nil
	self.spawn_time = 1
	self.spawn_class = ""

	self.time_left = self.spawn_time

	-- by default, -1 will mean repeatedly spawn
	-- 0 will mean never fire
	self.max_entities = -1
end

function func_spawn:onSpawn( params )
	Entity.onSpawn( self, params )

	self.spawn_class = params.gamerules.entity_factory:findClass( self.spawn_class )
	self.gamerules = params.gamerules
end

-- params:
--	entity: the instance of the entity being spawned
function func_spawn:onUpdate( params )
	if params.gamestate == GAME_STATE_DEFEND then
		local dt = params.dt
		self.time_left = self.time_left - dt

		if self.time_left <= 0 and self.max_entities ~= 0  then
			--logging.verbose( "spawning entity at " .. self.tile_x .. ", " .. self.tile_y )
			self.time_left = self.spawn_time
			local entity = self.spawn_class:new()
			if entity then
				--logging.verbose( "-> entity tile at " .. entity.tile_x .. ", " .. entity.tile_y )
				--logging.verbose( "-> entity world at " .. entity.world_x .. ", " .. entity.world_y )
				entity.world_x, entity.world_y = self.gamerules:worldCoordinatesFromTileCenter( self.tile_x, self.tile_y )

				--entity.tile_x, entity.tile_y = self.tile_x, self.tile_y

				--logging.verbose( "-> entity world at " .. entity.world_x .. ", " .. entity.world_y )

				--logging.verbose( "-> now spawning entity..." )
				entity:onSpawn( {gamerules=self.gamerules, properties=nil} )

				--logging.verbose( "-> entity tile at " .. entity.tile_x .. ", " .. entity.tile_y )

				-- manage this entity
				self.gamerules.entity_manager:addEntity( entity )			

				if self.max_entities > 0 then
					self.max_entities = self.max_entities - 1
				end
			end
		end
	end

	Entity.onUpdate( self, params )
end

Player = class("Player", AnimatedSprite)
function Player:initialize()
	self.health = 100
	self.collision_mask = 1
	self.attack_delay = 1 -- in seconds
	self.attack_damage = 1	
end

function Player:onUpdate( params )
	--local r,g,b,a = params.gamerules:colorForHealth(self.health)
	--self.color = {r=r, g=g, b=b, a=a}
	AnimatedSprite.onUpdate(self, params)
end

Bullet = class("Bullet", AnimatedSprite)
function Bullet:initialize()
	AnimatedSprite:initialize(self)

	self.velocity = { x=0, y=0 }

	self.collision_mask = 2
	self.attack_damage = 0
	self.bullet_speed = 250
end

function Bullet:onSpawn( params )
	self:loadSprite( "assets/sprites/projectiles.conf" )
	self:playAnimation( "one" )
	AnimatedSprite.onSpawn( self, params )
end

function Bullet:onCollide( params )
	if params.other == nil then
		-- bullet hit a wall; play wallhit sound
	end

	Entity.onCollide( self, params )
end

function Bullet:onHit( params )
	logging.verbose( "bullet hit something!" )
end

function Bullet:onUpdate( params )
	self.world_x = self.world_x + self.velocity.x * params.dt * self.bullet_speed
	self.world_y = self.world_y + self.velocity.y * params.dt * self.bullet_speed
	AnimatedSprite.onUpdate( self, params )

	if not params.gamerules:isTileWalkable( self.tile_x, self.tile_y ) then
		--self:onCollide( {gamerules=params.gamerules, other=nil} )
		params.gamerules:playSound( "bullet_wall_hit" )
		params.gamerules:removeEntity( self )
	end
end


