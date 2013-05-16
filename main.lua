require "core"
require "game"

local CONFIGURATION_FILE = "settings.json"

local KERNEL_STATE_LOGO = 0
local KERNEL_STATE_MENU = 1
local KERNEL_STATE_RUN = 2

local config = {}
local fonts = {}
local gameLogic = nil
local gamerules = nil
local game_state = KERNEL_STATE_RUN

require "game.screens"

local screencontrol = ScreenControl()

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


	-- load all screens
	local params = {
		fonts = fonts,
		screencontrol = screencontrol,
		gamerules = gamerules
	}
	screencontrol:addScreen( "logo", LogoScreen( params ) )
	screencontrol:addScreen( "help", HelpScreen( params ) )
	screencontrol:addScreen( "mainmenu", MainMenuScreen( params ) )

	-- load the game specified in the config
	logging.verbose( "initializing game: " .. config.game )
	require ( config.game )
	gameLogic = Game:new( gamerules, config, fonts, screencontrol )

	screencontrol:addScreen( "game", gameLogic )

	-- pass control to the logic
	core.util.callLogic( gameLogic, "onLoad", { gamerules = gamerules } )


	screencontrol:setActiveScreen("mainmenu", {gamerules=gamerules, game=gameLogic})
end

function love.draw()
	local active_screen = screencontrol:getActiveScreen()
	if active_screen then
		core.util.callLogic( active_screen, "onDraw", { gamerules = gamerules } )
	end
end

function love.update(dt)

	for i=1, love.joystick.getNumJoysticks() do
		for j=1, love.joystick.getNumHats(i) do

			local direction = love.joystick.getHat( i, 1 )
			if direction ~= "c" then
				logging.verbose( "hat " .. j .. ", direction: " .. direction )
			end

		end
	end

	local active_screen = screencontrol:getActiveScreen()
	if active_screen then	
		core.util.callLogic( active_screen, "onUpdate", {gamerules = gamerules, dt=dt} )
	end
end

function love.keypressed( key, unicode )
	local active_screen = screencontrol:getActiveScreen()
	if active_screen then	
		core.util.callLogic( active_screen, "onKeyPressed", {gamerules = gamerules, key=key, unicode=unicode} )
	end
end

function love.keyreleased(key )
	local active_screen = screencontrol:getActiveScreen()
	if active_screen then	
		core.util.callLogic( active_screen, "onKeyReleased", {gamerules = gamerules, key=key} )
	end
end

function love.mousepressed( x, y, button )
	local active_screen = screencontrol:getActiveScreen()
	if active_screen then	
		core.util.callLogic( active_screen, "onMousePressed", {gamerules = gamerules, x=x, y=y, button=button} )
	end
end

function love.mousereleased( x, y, button )
	local active_screen = screencontrol:getActiveScreen()
	if active_screen then	
		core.util.callLogic( active_screen, "onMouseReleased", {gamerules = gamerules, x=x, y=y, button=button} )
	end		
end

function love.joystickpressed( joystick, button )
	local active_screen = screencontrol:getActiveScreen()
	if active_screen then	
		core.util.callLogic( active_screen, "onJoystickPressed", {gamerules = gamerules, joystick=joystick, button=button} )
	end
end

function love.joystickreleased( joystick, button )
	local active_screen = screencontrol:getActiveScreen()
	if active_screen then	
		core.util.callLogic( active_screen, "onJoystickReleased", {gamerules = gamerules, joystick=joystick, button=button} )
	end
end
