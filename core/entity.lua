module( ..., package.seeall )
require "middleclass.middleclass"
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
end

function Entity:onUpdate( params )
end

function Entity:onDraw( params )
end

-- a base "world" entity that exists in the game world
WorldEntity = class( "WorldEntity", Entity )
function WorldEntity:initialize()
	self.current_animation = 1

	-- directions will be each row
	-- frames of the animation will be each column
	
	self.is_moving = false

	-- the frame size of this animation
	self.frame_width = 32
	self.frame_height = 64

	-- The image
	self.image = love.graphics.newImage("images/guy.png")

	self.spritesheet = core.SpriteSheet.new( self.image, self.frame_width, self.frame_height )
	self.animations = {}


	local image_width = self.image:getWidth()
	local image_height = self.image:getHeight()

	logging.verbose( "image_width: " .. image_width )
	logging.verbose( "image_height: " .. image_height )

	-- calculate rows and columns
	local total_rows = (self.image:getHeight() / self.frame_height)
	local total_cols = (self.image:getWidth() / self.frame_width)
	
	logging.verbose( "total_rows: " .. total_rows )
	logging.verbose( "total_cols: " .. total_cols )

	for row=1,total_rows do
		local a = self.spritesheet:createAnimation()
		a:setDelay( 0.25 )
		for col=1,total_cols do
			a:addFrame( col, row )
		end
		logging.verbose( "adding animation: " .. (#self.animations+1) )
		self.animations[#self.animations+1] = a

		-- make sure this renders as the first frame
		a.currentFrame = 1
	end
end

function WorldEntity:__tostring()
	return "WorldEntity at world:[ " .. self.world_x .. ", " .. self.world_y .. " ]"
end

-- params:
--	dt: the frame delta time
function WorldEntity:onUpdate( params )
	local animation = self.animations[ self.current_animation ]
	if animation and self.is_moving then
		animation:update(params.dt)
	end
end

-- params:
--	gameRules: the instance of the active gamerules class
function WorldEntity:onDraw( params )
	local x, y = params.gameRules:worldToScreen( (self.world_x - (self.frame_width/2)), self.world_y - self.frame_height )

	local animation = self.animations[ self.current_animation ]
	if animation then
		animation:draw(x, y)
	end
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


