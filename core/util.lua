module( ..., package.seeall )

function callLogic( logic, function_name, param_table )
	if logic then
		logic[ function_name ]( logic, param_table )
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


function printTable( tbl )
	if tbl == nil then
		return
	end

	for index, item in pairs(tbl) do
		if type(item) == "table" then
			print( "index: " .. index .. " (TABLE)" )
			printTable(item)
		else
			print( "index: " .. index .. " -> " .. item )
		end
	end
end

function shallowcopy(orig)
    local orig_type = type(orig)
    local copy
    if orig_type == 'table' then
        copy = {}
        for orig_key, orig_value in pairs(orig) do
            copy[orig_key] = orig_value
        end
    else -- number, string, boolean, etc
        copy = orig
    end
    return copy
end

-- http://snippets.luacode.org/snippets/Deep_copy_of_a_Lua_Table_2
function deepcopy(t)
	if type(t) ~= 'table' then 
		return t
	end

	local mt = getmetatable(t)
	local res = {}
	for k,v in pairs(t) do
		if type(v) == 'table' then
			v = deepcopy(v)
		end
		res[k] = v
	end
	setmetatable(res,mt)
	return res
end


vector = {}

function vector.dot( x1, y1, x2, y2 )
	return (x1 * x2) + (y1 * y2)
end

function vector.length( x, y )
	return math.sqrt( vector.dot( x, y, x, y ) )
end

function vector.angle( x1, y1, x2, y2 )
	return math.acos( vector.dot(x1, y1, x2, y2) / (vector.length(x1, y1) * vector.length(x2, y2)) )
end