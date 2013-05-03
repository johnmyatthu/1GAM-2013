require "core"


CollisionTile = class( "CollisionTile", Entity )
function CollisionTile:initialize()
	Entity.initialize(self)
end

function CollisionTile:onDraw( params )
	local cx, cy = params.gamerules:getCameraPosition()
	local sx, sy = self.world_x+cx, self.world_y+cy
	love.graphics.setColor(0, 255,255,128)
	love.graphics.rectangle( "line", sx-(self.frame_width/2), sy-(self.frame_height/2), self.frame_width, self.frame_height )	
	Entity.onDraw( self, params )
end