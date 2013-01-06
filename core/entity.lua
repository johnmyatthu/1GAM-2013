module( ..., package.seeall )
require "core"
local logging = core.logging

Entity = class( "Entity" )
function Entity:initialize()
	-- current position in the world
	self.world_x = 0
	self.world_y = 0

	-- current tile
	self.tile_x = -1
	self.tile_y = -1
end

function Entity:onSpawn( params )
	logging.verbose( "Entity:onSpawn... " .. tostring(self) )

	if self.tile_x < 0 or self.tile_y < 0 then
		logging.verbose( "Entity:onSpawn world location: " .. self.world_x .. ", " .. self.world_y )
		self.tile_x, self.tile_y = params.gameRules:tileCoordinatesFromWorld( self.world_x, self.world_y )
		logging.verbose( "Entity:onSpawn tile location: " .. self.tile_x .. ", " .. self.tile_y )
	end
end

function Entity:onUpdate( params )
end

function Entity:onDraw( params )
end

function Entity:onCollide( params )
end

-- params:
--	attacker: The attacking entity
--	damage: Base damage for the hit
function Entity:onHit( params )
end

-- a base "world" entity that exists in the game world
AnimatedSprite = class( "AnimatedSprite", Entity )

function AnimatedSprite:initialize()
	logging.verbose( "AnimatedSprite initialize" )
	Entity:initialize(self)
	self.is_attacking = false
	self.current_animation = 1
	self.current_direction = "northeast"
	self.animations = nil
	self.spritesheet = nil
	self.animation_index_from_name = {}
	self.frame_width = 0
	self.frame_height = 0
end

function AnimatedSprite:__tostring()
	return "AnimatedSprite at world:[ " .. self.world_x .. ", " .. self.world_y .. " ]"
end

-- I hate the way this works; it's so hacky. So, until I come up with a better way...
function AnimatedSprite:setDirectionFromMoveCommand( command )
	self.current_direction = ""

	if command.up then
		self.current_direction = "north"
	elseif command.down then
		self.current_direction = "south"
	end

	if command.left then
		self.current_direction = self.current_direction .. "east"
	elseif command.right then
		self.current_direction = self.current_direction .. "west"
	end
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


			local directions = { "east", "northeast", "north", "northwest", "west", "southwest", "south", "southeast" }

			for _,animdata in pairs(sprite_config.animations) do
				--logging.verbose( "ANIMATION: " .. animdata.name )

				local anim_index = (#self.animations+1)
				--logging.verbose( "anim_index: " .. anim_index )
				self.animation_index_from_name[ animdata.name ] = anim_index
				self.animations[ anim_index ] = {}

				-- start processing only the first row for now
				for row=1,#directions do
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
	end
end

-- params:
--	dt: the frame delta time
function AnimatedSprite:onUpdate( params )
	if self.animations then
		local animation = self.animations[ self.current_animation ][ self.current_direction ]
		if animation then
			animation:update(params.dt)
		end
	end
end

-- params:
--	gameRules: the instance of the active gamerules class
function AnimatedSprite:onDraw( params )
	if self.animations then
		local x, y = params.gameRules:worldToScreen( (self.world_x - (self.frame_width/2)), self.world_y - (self.frame_height/2) )

		local animation = self.animations[ self.current_animation ][ self.current_direction ]
		if animation then
			animation:draw(x, y)
		end
	end
end


PathFollower = class( "PathFollower", AnimatedSprite )
function PathFollower:initialize()
	logging.verbose( "path follower initialize" )
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
	local TILE_DISTANCE_THRESHOLD = 5
	local command = { up=false, down=false, left=false, right=false }
	command.move_speed = 75
	command.dt = params.dt

	if self.path then
		tile = self.path[ self.current_path_step ]



		local cx, cy = params.gameRules:worldCoordinatesFromTileCenter( tile.x, tile.y )
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
	params.gameRules:handleMovePlayerCommand( command, self )
	--logging.verbose( "rolling... " .. params.dt )
end


func_target = class( "func_target", AnimatedSprite )
function func_target:initialize()
	AnimatedSprite.initialize(self)

	self.health = 100
end

function func_target:onHit( params )
	logging.verbose( "Hit target for " .. params.damage .. " damage!" )

	if self.health > 0 then
		self.health = self.health - params.damage

		if self.health < 0 then
			self.health = 0
		end
	end

end

function func_target:__tostring()
	return "func_target [" .. self.tile_x .. ", " .. self.tile_y .. "] Health: " .. self.health
end

function func_target:onDraw( params )
	AnimatedSprite.onDraw( self, params )

	-- get screen coordinates for this entity
	local sx, sy = params.gameRules:worldToScreen( self.world_x, self.world_y )
	local r,g,b,a = params.gameRules:colorForHealth(self.health)
	local x, y = sx-50, sy-32
	local width = 100
	love.graphics.setColor( 0, 0, 0, 192 )
	love.graphics.rectangle( 'fill', x+10, y, width-20, 14 )
	love.graphics.setColor( r, g, b, a )
	love.graphics.printf( "Health: (" .. math.floor(self.health) .. ")", x, y, width, 'center' )




	love.graphics.setColor( 255, 255, 255, 255 )
end

Enemy = class( "Enemy", PathFollower )
function Enemy:initialize()
	logging.verbose( "Enemy:initialize" )
	PathFollower.initialize(self)

	-- random values to get the ball rolling
	self.attack_damage = 0.5

	self.target = nil
end

function Enemy:onSpawn( params )
	--self.class.super:onSpawn( params )
	PathFollower.onSpawn( self, params )

	logging.verbose( "Enemy: Searching for target..." )
	local target = params.gameRules.entity_manager:findFirstEntityByName( "func_target" )
	if target then
		logging.verbose( "I am setting a course to attack the target!" )
		logging.verbose( "I am at " .. self.tile_x .. ", " .. self.tile_y )
		logging.verbose( "Target is at " .. target.tile_x .. ", " .. target.tile_y )

		local path, cost = params.gameRules:getPath( self.tile_x, self.tile_y, target.tile_x+1, target.tile_y )
		logging.verbose( path )
		logging.verbose( cost )

		self:setPath( path )
		self.target = target
	else
		logging.verbose( "Unable to find target." )
	end
end

function Enemy:onUpdate( params )
	PathFollower.onUpdate( self, params )

	-- calculate distance to target
	local dx, dy = (self.target.tile_x - self.tile_x), (self.target.tile_y - self.tile_y)
	local min_range = 1
	if math.abs(dx) <= min_range and math.abs(dy) <= min_range then
		--logging.verbose( "I am at " .. self.tile_x .. ", " .. self.tile_y )

		-- attack the target
		if self.target and self.target.health > 0 then
			self.target:onHit( {attacker=self, damage=self.attack_damage} )
		end
	end
end



func_spawn = class( "func_spawn", Entity )
function func_spawn:initialize()
	Entity:initialize(self)
	self.gamerules = nil
	self.spawn_time = 1
	self.spawn_class = ""
	self.config = "assets/sprites/guy.conf"

	self.time_left = self.spawn_time

	-- by default, -1 will mean repeatedly spawn
	-- 0 will mean never fire
	self.max_entities = -1
end

function func_spawn:onSpawn( params )
	Entity.onSpawn( self, params )
	logging.verbose( "func_spawn ... reading params!" )

	for key, value in pairs(params.properties) do
		--logging.verbose( key .. " -> " .. value )
		if self[ key ] then
			--logging.verbose( "key exists: " .. key )
			self[ key ] = value
		end
	end

	self.spawn_class = params.gameRules.entity_factory:findClass( self.spawn_class )
	self.gameRules = params.gameRules
end

-- params:
--	entity: the instance of the entity being spawned
function func_spawn:onUpdate( params )
	local dt = params.dt
	self.time_left = self.time_left - dt

	if self.time_left <= 0 and self.max_entities ~= 0  then
		logging.verbose( "spawning entity at " .. self.tile_x .. ", " .. self.tile_y )
		self.time_left = self.spawn_time
		local entity = self.spawn_class:new()
		if entity then
			logging.verbose( "-> entity tile at " .. entity.tile_x .. ", " .. entity.tile_y )
			logging.verbose( "-> entity world at " .. entity.world_x .. ", " .. entity.world_y )
			entity.world_x, entity.world_y = self.gameRules:worldCoordinatesFromTileCenter( self.tile_x, self.tile_y )

			--entity.tile_x, entity.tile_y = self.tile_x, self.tile_y

			logging.verbose( "-> entity world at " .. entity.world_x .. ", " .. entity.world_y )
			entity:loadSprite( self.config )

			logging.verbose( "-> now spawning entity..." )
			entity:onSpawn( {gameRules=self.gameRules, properties=nil} )

			logging.verbose( "-> entity tile at " .. entity.tile_x .. ", " .. entity.tile_y )

			-- manage this entity
			self.gameRules.entity_manager:addEntity( entity )			

			if self.max_entities > 0 then
				self.max_entities = self.max_entities - 1
			end
		end
	end
end

