require "core"


CollisionTile = class( "CollisionTile", Entity )
function CollisionTile:initialize()
	Entity.initialize(self)
end

function CollisionTile:draw( params )
	love.graphics.setColor(0, 255,255,128)
	love.graphics.rectangle( "line", self.world_x-(self.frame_width/2), self.world_y-(self.frame_height/2), self.frame_width, self.frame_height )	
	Entity.onDraw( self, params )
	logging.verbose( "drawing" )
end