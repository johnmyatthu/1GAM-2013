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
	screencontrol:addScreen( "logo", LogoScreen(fonts, screencontrol) )
	screencontrol:addScreen( "help", HelpScreen(fonts, screencontrol) )
	screencontrol:addScreen( "mainmenu", MainMenuScreen(fonts, screencontrol) )

	-- load the game specified in the config
	logging.verbose( "initializing game: " .. config.game )
	require ( config.game )
	gameLogic = Game:new( gamerules, config, fonts, screencontrol )

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
	core.util.callLogic( gameLogic, "onMousePressed", {gamerules = gamerules, x=x, y=y, button=button} )
end

function love.mousereleased( x, y, button )
	core.util.callLogic( gameLogic, "onMouseReleased", {gamerules = gamerules, x=x, y=y, button=button} )
end

function love.joystickpressed( joystick, button )
	core.util.callLogic( gameLogic, "onJoystickPressed", {gamerules = gamerules, joystick=joystick, button=button} )
end

function love.joystickreleased( joystick, button )
	core.util.callLogic( gameLogic, "onJoystickReleased", {gamerules = gamerules, joystick=joystick, button=button} )
end
