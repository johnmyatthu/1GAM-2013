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


function escape_hit()
	-- skip past the intro if user hits escape
	local screen = screencontrol:getActiveScreen()

	-- if screen and screen.name == "logo" then
	-- 	logo_intro.finished = true
	-- else
	-- 	love.event.push( "quit" )
	-- end

	if game_state == KERNEL_STATE_LOGO then
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

	-- load all screens
	screencontrol:addScreen( "logo", LogoScreen(fonts) )
	screencontrol:addScreen( "help", HelpScreen(fonts) )
	screencontrol:addScreen( "mainmenu", MainMenuScreen(fonts) )



	-- load the game specified in the config
	logging.verbose( "initializing game: " .. config.game )
	require ( config.game )
	gameLogic = Game:new( gamerules, config, fonts, screencontrol )

	-- pass control to the logic
	core.util.callLogic( gameLogic, "onLoad", { gamerules = gamerules } )

	if game_state == KERNEL_STATE_LOGO then
		gamerules:playSound( "menu_intro" )
	end
end

function love.draw()
	if game_state == KERNEL_STATE_RUN then
		core.util.callLogic( gameLogic, "onDraw", { gamerules = gamerules } )
	elseif game_state == KERNEL_STATE_LOGO then
		logo_intro:draw()
	end
end

function love.update(dt)
	if game_state == KERNEL_STATE_RUN then
		core.util.callLogic( gameLogic, "onUpdate", {dt=dt} )
	elseif game_state == KERNEL_STATE_LOGO then
		logo_intro:update(dt)
		if logo_intro.finished then
			game_state = KERNEL_STATE_RUN
		end
	end
end

function love.keypressed( key, unicode )
	if game_state == KERNEL_STATE_RUN then
		core.util.callLogic( gameLogic, "onKeyPressed", {key=key, unicode=unicode} )
	end
end

function love.keyreleased(key )
	if key == "escape" then
		escape_hit()
		return
	elseif key == " " and game_state == KERNEL_STATE_LOGO then
		escape_hit()
		return
	end

	core.util.callLogic( gameLogic, "onKeyReleased", {key=key} )
end

function love.mousepressed( x, y, button )
	if game_state == KERNEL_STATE_RUN then	
		core.util.callLogic( gameLogic, "onMousePressed", {x=x, y=y, button=button} )
	end		
end

function love.mousereleased( x, y, button )
	if game_state == KERNEL_STATE_RUN then	
		core.util.callLogic( gameLogic, "onMouseReleased", {x=x, y=y, button=button} )	
	end		
end


function love.joystickpressed( joystick, button )
	if game_state == KERNEL_STATE_RUN then	
		core.util.callLogic( gameLogic, "onJoystickPressed", {joystick=joystick, button=button} )
	end		
end

function love.joystickreleased( joystick, button )
	if game_state == KERNEL_STATE_RUN then	
		core.util.callLogic( gameLogic, "onJoystickReleased", {joystick=joystick, button=button} )
	end		
end
