require "json4lua.trunk.json.json"
loader = require "AdvTiledLoader.Loader"
require "gamerules"

local fonts = setmetatable( {}, {__index = function(t,k)
	local f = love.graphics.newFont( k )
	rawset( t, k, f )
	return f
end })

local CONFIGURATION_FILE = "settings.json"

global = {}
global.tx = 0
global.ty = 0
global.map = nil
global.conf = {}


local gameRules = nil
local map_drag = {isDragging = false, startX = 0, startY = 0, deltaX = 0, deltaY = 0}
local highlight = nil

function load_config()
	if love.filesystem.exists( CONFIGURATION_FILE ) then
		global.conf = json.decode( love.filesystem.read( CONFIGURATION_FILE ) )

		-- initialize GameRules
		gameRules = gamerules.GameRules:new()

		gameRules:warpCameraTo( global.conf.spawn[1], global.conf.spawn[2] )
	end
end

local util = {}

function util.IsoTileToScreen( map, offset_x, offset_y, tile_x, tile_y )
	-- this accepts the camera offset x and y and factors that into the coordinates

	-- we need to further offset the returned value by half the entire map's width to get the correct value
	local render_offset_x = ((map.width * map.tileWidth) / 2)

	local tx, ty = tile_x, tile_y-1

	local drawX = offset_x + render_offset_x + math.floor(map.tileWidth/2 * (tx - ty-2))
	local drawY = offset_y + math.floor(map.tileHeight/2 * (tx + ty+2))
	drawY = drawY - (map.tileHeight/2)
	return drawX, drawY
end


local tileLayer = nil

function query_joysticks()
	local numJoysticks = love.joystick.getNumJoysticks()
	
	if numJoysticks > 0 then
		print( "numJoysticks: " .. numJoysticks )

		for j = 1, numJoysticks do
			local joystickName = love.joystick.getName( 1 )
			print( "joystickName: " .. joystickName )

			local numAxes = love.joystick.getNumAxes( 1 )
			print( "numAxes: " .. numAxes )

			for i = 1, numAxes do
				local direction = love.joystick.getAxis( 1, i )
				print( "axis: " .. i .. ", direction: " .. tostring(direction) )
				print( direction )
			end

			local numBalls = love.joystick.getNumBalls( 1 )
			print( "numBalls: " .. numBalls )
		end
	end
end


function love.load()
	load_config()

	-- gamepad/wiimote testing
	--query_joysticks()

	-- set maps path
	loader.path = "maps/"
	global.map = loader.load( global.conf.map )
	global.map.drawObjects = false

	-- this crashes on a retina mbp if true; perhaps something to do with the GPUs switching?
	global.map.useSpriteBatch = false

	tileLayer = global.map.layers["Ground"]

	love.graphics.setFont( fonts[12] )

	print( "Tile Width: " .. global.map.tileWidth )
	print( "Tile Height: " .. global.map.tileHeight )
end



local menu_open = {
	main = false,
	right = false,
	foo = false,
	demo = false
}

local input_data = { text = "" }

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
			local drawX, drawY = util.IsoTileToScreen( global.map, cx, cy, tx, ty )
			highlight = { x=drawX, y=drawY, w=global.map.tileHeight, h=global.map.tileHeight }
		end
	end

end



function love.keypressed( key, unicode )
end

function love.keyreleased(key )
	if key == "escape" then
		love.event.push( "quit" )
	elseif key == "f5" then
		print( "refresh" )
		load_config()
	end
end

function love.mousepressed( x, y, button )
	if button == "m" then
		-- enter drag mode
		map_drag.startX = x
		map_drag.startY = y
		map_drag.isDragging = true
	end
end

function love.mousereleased( x, y, button )
	if button == "m" then
		map_drag.isDragging = false
	end
end


function love.joystickpressed( joystick, button )
	print( "joystick: " .. joystick .. ", button: " .. button )
end
