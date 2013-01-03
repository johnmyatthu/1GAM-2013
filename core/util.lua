module( ..., package.seeall )

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