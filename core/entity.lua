module( ..., package.seeall )
require "core"
local logging = core.logging

Entity = class( "Entity" )

function Entity:initialize()
	-- current position in the world
	self.world_x = 0
	self.world_y = 0

	-- current tile
	self.tile_x = 1
	self.tile_y = 1
end

function Entity:onSpawn( params )
end

function Entity:onUpdate( params )
end

function Entity:onDraw( params )
end

-- a base "world" entity that exists in the game world
AnimatedSprite = class( "AnimatedSprite", Entity )

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
		logging.verbose( "loadSprite: image '" .. sprite_config.image .. "'" )

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
			logging.verbose( "loadSprite: loaded image w x h = " .. self.image:getWidth() .. " x " .. self.image:getHeight() )

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

			logging.verbose( "loadSprite: animations loaded: " .. (#self.animations) )
		else
			logging.warning( "loadSprite: Could not load image: '" .. sprite_config.image .. "'" )
		end

	else
		logging.warning( "loadSprite: No file named " .. config_file .. " found!" )
	end
end


function AnimatedSprite:initialize()
	Entity.initialize(self)
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
	AnimatedSprite.initialize(self)

	self.path = nil
	self.current_path_step = 1

	self.velocity = { x=0, y=0 }
end

function PathFollower:setPath( path )
	self.path = path
	self.current_path_step = 2
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

	local command = { up=false, down=false, left=false, right=false }
	command.move_speed = 150
	command.dt = params.dt

	if self.path then
		tile = self.path[ self.current_path_step ]



		local cx, cy = params.gameRules:worldCoordinatesFromTileCenter( tile.x, tile.y )
		self.velocity.x = cx - self.world_x
		self.velocity.y = cy - self.world_y

		-- determine absolute distance
		--logging.verbose( "velocity: " .. self.velocity.x .. ", " .. self.velocity.y )
		local dx, dy = math.abs(self.velocity.x), math.abs(self.velocity.y)
		if dx < 2 and dy < 2 then
			self.world_x = cx
			self.world_y = cy

			if self.current_path_step == #self.path then
				logging.verbose( "ended path at " .. self.current_path_step )
				self.path = nil
				return			
			end

			logging.verbose( "dx: " .. dx .. ", dy: " .. dy )
			self.current_path_step = self.current_path_step + 1
			logging.verbose( "next path step ... " .. self.current_path_step )

			return
		end

		--logging.verbose( "tile.x: " .. tile.x .. ", tile.y: " .. tile.y )

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



		self.world_x = self.world_x + (mx * params.dt)
		self.world_y = self.world_y + (vertical_speed * params.dt)
		--logging.verbose( "up: " .. tostring(command.up) .. ", down: " .. tostring(command.down) .. ", left: " .. tostring(command.left) .. ", right: " .. tostring(command.right) )
	end

	--params.gameRules:handleMovePlayerCommand( command, self )
	--logging.verbose( "rolling... " .. params.dt )
end





EntitySpawner = class( "EntitySpawner", Entity )
function EntitySpawner:initialize()
	Entity.initialize( self )
	self.spawn_time = 1
	self.time_left = self.spawn_time
	self.spawn_class = nil
	self.onSpawn = nil
end

-- params:
--	entity: the instance of the entity being spawned
function EntitySpawner:onUpdate( params )
	local dt = params.dt
	self.time_left = self.time_left - dt

	if self.time_left <= 0 then
		self.time_left = self.spawn_time
		local instance = self.spawn_class:new()
		if self.onSpawn then
			self.onSpawn( {entity=instance} )
		end
	end
end


