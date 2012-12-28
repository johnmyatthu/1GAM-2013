module( ..., package.seeall )

function IsoTileToScreen( map, offset_x, offset_y, tile_x, tile_y )
	-- this accepts the camera offset x and y and factors that into the coordinates

	-- we need to further offset the returned value by half the entire map's width to get the correct value
	local render_offset_x = ((map.width * map.tileWidth) / 2)

	local tx, ty = tile_x, tile_y-1

	local drawX = offset_x + render_offset_x + math.floor(map.tileWidth/2 * (tx - ty-2))
	local drawY = offset_y + math.floor(map.tileHeight/2 * (tx + ty+2))
	drawY = drawY - (map.tileHeight/2)
	return drawX, drawY
end

function callLogic( logic, function_name, param_table )
	if logic then
		logic[ function_name ]( param_table )
	end
end


function queryJoysticks()
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