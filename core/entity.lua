module( ..., package.seeall )
require( "middleclass.middleclass" )

Entity = class( "Entity" )

function Entity:initialize()
	self.tx = 0
	self.ty = 0
end
