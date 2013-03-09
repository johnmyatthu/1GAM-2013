require "core"

func_waypoint = class( "func_waypoint", Entity )

function func_waypoint:initialize()
	Entity:initialize(self)

	self.name = "<name>"
	self.next_waypoint = 0
end

function func_waypoint:onDraw( params )
	Entity.onDraw( self, params )
end