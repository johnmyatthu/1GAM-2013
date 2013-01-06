

require "core"
local logging = core.logging

local CONFIGURATION_FILE = "settings.json"

local config = {}
local fonts = {}
local gameLogic = nil
local gamerules = nil


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
		for name, data in pairs(config.fonts) do
			logging.verbose( name .. " -> " .. data.path )
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
	core.util.callLogic( gameLogic, "onDraw", {} )
end

--function love.run()
--end

function love.quit()
end

function love.update(dt)
	core.util.callLogic( gameLogic, "onUpdate", {dt=dt} )
end


function love.keypressed( key, unicode )
	core.util.callLogic( gameLogic, "onKeyPressed", {key=key, unicode=unicode} )
end

function love.keyreleased(key )
	if key == "escape" then
		love.event.push( "quit" )
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
