

require "core"
local logging = core.logging

local CONFIGURATION_FILE = "settings.json"

local GAME_STATE_RUN = 0
local GAME_STATE_MENU = 1
local GAME_STATE_LOGO = 2

local config = {}
local fonts = {}
local gameLogic = nil
local gamerules = nil
local game_state = GAME_STATE_LOGO



local logo_intro = {
	icon = love.graphics.newImage( "assets/logos/icon.png" ),
	logo = love.graphics.newImage( "assets/logos/logo.png" ),

	fade_states = {
		{ time=2, alpha=255 }, -- fade in seconds
		{ time=1, alpha=255 }, -- fade transition seconds		
		{ time=2, alpha=0 }, -- fade out seconds
	},

	fade_state = 1,
	fade_time = 0,

	current_alpha = 0,

	finished = false
}

function logo_intro:draw_image( img, width, height )
	local sx = img:getWidth()
	local sy = img:getHeight()

	local xo = (love.graphics.getWidth() / 2) - (sx/2)
	if width ~= nil then
		xo = width
	end

	local yo = (love.graphics.getHeight() / 2) - (sy/2)
	if height ~= nil then
		yo = height
	end
	love.graphics.draw( img, xo, yo, 0, 1, 1, 0, 0 )
end

function logo_intro:draw()
	love.graphics.setColor( 255, 255, 255, self.current_alpha )
	self:draw_image( self.icon, 20, 200 )
	self:draw_image( self.logo, nil, nil )
end

function logo_intro:update( timedelta )
	if self.fade_state > #self.fade_states then
		return
	end

	self.fade_time = self.fade_time + timedelta
	local state = self.fade_states[ self.fade_state ]

	-- interpolate states
	self.current_alpha = self.current_alpha + (state.alpha-self.current_alpha) * (self.fade_time/state.time)
	
	if self.fade_time >= state.time then
		self.current_alpha = state.alpha
		if self.fade_state < #self.fade_states then
			self.fade_state = self.fade_state + 1
			self.fade_time = 0
		else
			self.finished = true
		end
	end
end


function escape_hit()
	-- skip past the intro if user hits escape
	if game_state == GAME_STATE_LOGO then
		logo_intro.finished = true
	else
		love.event.push( "quit" )
	end
end



function load_config()
	if love.filesystem.exists( CONFIGURATION_FILE ) then
		config = json.decode( love.filesystem.read( CONFIGURATION_FILE ) )

		-- initialize GameRules
		gamerules = core.gamerules.GameRules:new()

		gamerules:warpCameraTo( config.spawn[1], config.spawn[2] )
	end
end

function love.load()
	logging.verbose( "" )
	logging.verbose( "---------------------------------------------------------" )
	logging.verbose( "" )
	logging.verbose( "loading configuration: " .. CONFIGURATION_FILE .. "..." )
	load_config()

	if config.fonts then
		logging.verbose( "Loading fonts..." )
		for name, data in pairs(config.fonts) do
			logging.verbose( "\t'" .. name .. "' -> '" .. data.path .. "'" )
			fonts[ name ] = love.graphics.newFont( data.path, data.size )
		end
	end

	-- load the game specified in the config
	logging.verbose( "initializing game: " .. config.game )
	require ( config.game )
	gameLogic = Game:new( gamerules, config, fonts )


	-- pass control to the logic
	core.util.callLogic( gameLogic, "onLoad", {} )
end

function love.draw()
	if game_state == GAME_STATE_RUN then
		core.util.callLogic( gameLogic, "onDraw", {} )
	elseif game_state == GAME_STATE_LOGO then
		logo_intro:draw()
	end
end


function love.update(dt)
	if game_state == GAME_STATE_RUN then
		core.util.callLogic( gameLogic, "onUpdate", {dt=dt} )
	elseif game_state == GAME_STATE_LOGO then
		logo_intro:update(dt)
		if logo_intro.finished then
			game_state = GAME_STATE_RUN
		end
	end
end


function love.keypressed( key, unicode )
	core.util.callLogic( gameLogic, "onKeyPressed", {key=key, unicode=unicode} )
end

function love.keyreleased(key )
	if key == "escape" then
		escape_hit()
		return
	elseif key == " " and game_state == GAME_STATE_LOGO then
		escape_hit()
		return
	elseif key == "f5" then
		print( "refresh" )
		load_config()
	end

	core.util.callLogic( gameLogic, "onKeyReleased", {key=key} )
end

function love.mousepressed( x, y, button )
	core.util.callLogic( gameLogic, "onMousePressed", {x=x, y=y, button=button} )
end

function love.mousereleased( x, y, button )
	core.util.callLogic( gameLogic, "onMouseReleased", {x=x, y=y, button=button} )	
end


function love.joystickpressed( joystick, button )
	--print( "joystick: " .. joystick .. ", button: " .. button )
	core.util.callLogic( gameLogic, "onJoystickPressed", {joystick=joystick, button=button} )
end

function love.joystickreleased( joystick, button )
	--print( "joystick: " .. joystick .. ", button: " .. button )	
	core.util.callLogic( gameLogic, "onJoystickReleased", {joystick=joystick, button=button} )
end
