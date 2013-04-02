require "core"
require "core.baseentity"

-- a base "world" entity that exists in the game world
AnimatedSprite = class( "AnimatedSprite", Entity )

function AnimatedSprite:initialize()
	Entity.initialize(self)
	self.is_attacking = false
	self.current_animation = 1
	self.current_direction = "east"
	self.animations = nil
	self.spritesheet = nil
	self.animation_index_from_name = {}
end


-- I hate the way this works; it's so hacky. But - until I come up with a better way...
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
end

function AnimatedSprite:loadSprite( config_file )
	if love.filesystem.exists( config_file ) then
		--logging.verbose( "loadSprite: " .. config_file )
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

function AnimatedSprite:onSpawn( params )
	Entity.onSpawn( self, params )
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

	-- get my position in screen space
	--local x, y = params.gamerules:worldToScreen( self.world_x, self.world_y )
	--y = y + 32
	--x = x - 60
	--love.graphics.setColor( 255, 255, 255, 255 )
	--love.graphics.print( "velocity: " .. self.velocity.x .. ", " .. self.velocity.y, x, y )
end
