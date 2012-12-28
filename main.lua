require "json4lua.trunk.json.json"
loader = require "AdvTiledLoader.Loader"
require "core"

local CONFIGURATION_FILE = "settings.json"


global = {}
global.map = nil
global.conf = {}

local gameLogic = nil
local gameRules = nil

-- temporary support middle-click drag
local map_drag = {isDragging = false, startX = 0, startY = 0, deltaX = 0, deltaY = 0}
local highlight = nil

local tileLayer = nil
local menu_open = {
	main = false,
	right = false,
	foo = false,
	demo = false
}
local input_data = { text = "" }

function load_config()
	if love.filesystem.exists( CONFIGURATION_FILE ) then
		global.conf = json.decode( love.filesystem.read( CONFIGURATION_FILE ) )

		-- initialize GameRules
		gameRules = core.gamerules.GameRules:new()

		gameRules:warpCameraTo( global.conf.spawn[1], global.conf.spawn[2] )
	end
end

function love.load()
	load_config()

	gameLogic = require ( global.conf.game )
	
	-- gamepad/wiimote testing
	core.util.queryJoysticks()

	-- set maps path
	loader.path = "maps/" .. global.conf.game .. "/"
	global.map = loader.load( global.conf.map )
	global.map.drawObjects = false

	-- this crashes on a retina mbp if true; perhaps something to do with the GPUs switching?
	global.map.useSpriteBatch = false

	tileLayer = global.map.layers[0]

	--print( "Tile Width: " .. global.map.tileWidth )
	--print( "Tile Height: " .. global.map.tileHeight )

	print( core.util )
	--core.util.callLogic( gameLogic, "onLoad", {} )
end



function love.draw()
	love.graphics.push()
	love.graphics.setColor(255,255,255,255)
	local cx, cy = gameRules:getCameraPosition()
	local ftx, fty = math.floor(cx), math.floor(cy)
	love.graphics.translate(ftx, fty)
	
	global.map:autoDrawRange( ftx, fty, 1, 50 )
	--global.map.offsetX = ftx
	--global.map.offsetY = fty
	global.map:draw()
	love.graphics.rectangle("line", global.map:getDrawRange())
	love.graphics.pop()

	--love.graphics.setColor(255,128,0,255)
	--love.graphics.print('Hello World!', 400, 300)

	if highlight then
		love.graphics.setColor(0,255,0,128)
		--love.graphics.rectangle( "line", highlight.x, highlight.y, highlight.w, highlight.h )
		love.graphics.quad( "fill", 
			highlight.x - highlight.w, highlight.y + highlight.h/2, -- top left
			highlight.x, highlight.y, 			-- top right
			highlight.x + highlight.w, highlight.y + highlight.h/2, -- bottom right
			highlight.x, highlight.y + highlight.h -- bottom left
			)
	end

	love.graphics.setColor( 255, 255, 255, 255 )
	love.graphics.print( "map_translate: ", 10, 50 )
	love.graphics.print( "x: " .. cx, 20, 70 )
	love.graphics.print( "y: " .. cy, 20, 90 )
end

--function love.run()
--end

function love.quit()
end

function love.update(dt)
	if map_drag.isDragging then
		local mx, my = love.mouse.getPosition()
		local cx, cy = gameRules:getCameraPosition()
		map_drag.deltaX = mx - map_drag.startX
		map_drag.deltaY = my - map_drag.startY
		cx = cx + map_drag.deltaX
		cy = cy + map_drag.deltaY
		map_drag.startX = mx
		map_drag.startY = my
		gameRules:warpCameraTo( cx, cy )
	end

	cam_x, cam_y = gameRules:getCameraPosition()

	if love.keyboard.isDown("up") then cam_y = cam_y + global.conf.move_speed*dt end
	if love.keyboard.isDown("down") then cam_y = cam_y - global.conf.move_speed*dt end
	if love.keyboard.isDown("left") then cam_x = cam_x + global.conf.move_speed*dt end
	if love.keyboard.isDown("right") then cam_x = cam_x - global.conf.move_speed*dt end

	gameRules:setCameraPosition( cam_x, cam_y )

	if tileLayer ~= nil then
		local cx, cy = gameRules:getCameraPosition()

		local mx, my = love.mouse.getPosition()
		--print( "mouseX: " .. mx .. ", mouseY: " .. my )

		local ix, iy = global.map:toIso( mx-cx, my-cy )
		--print( "IsoX: " .. ix .. ", IsoY: " .. iy )

		local tx, ty = math.floor(ix/32), math.floor(iy/32)
		--print( "tileX: " .. tx .. ", tileY: " .. ty )

		local tile = tileLayer( tx, ty )
		highlight = nil
		if tile then
			local drawX, drawY = core.util.IsoTileToScreen( global.map, cx, cy, tx, ty )
			highlight = { x=drawX, y=drawY, w=global.map.tileHeight, h=global.map.tileHeight }
		end
	end

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
	if button == "m" then
		-- enter drag mode
		map_drag.startX = x
		map_drag.startY = y
		map_drag.isDragging = true
	end

	core.util.callLogic( gameLogic, "onMousePressed", {x=x, y=y, button=button} )
end

function love.mousereleased( x, y, button )
	if button == "m" then
		map_drag.isDragging = false
	end

	core.util.callLogic( gameLogic, "onMouseReleased", {x=x, y=y, button=button} )
end


function love.joystickpressed( joystick, button )
	print( "joystick: " .. joystick .. ", button: " .. button )
	core.util.callLogic( gameLogic, "onJoystickPressed", {joystick=joystick, button=button} )
end

function love.joystickreleased( joystick, button )
	print( "joystick: " .. joystick .. ", button: " .. button )	
	core.util.callLogic( gameLogic, "onJoystickReleased", {joystick=joystick, button=button} )
end
