module( ..., package.seeall )
require( "middleclass.middleclass" )

GameRules = class( "GameRules" )

function GameRules:initialize()
	self.value = 10
	self.camera_x = 0
	self.camera_y = 0
end

function GameRules:loadMap( mapname )
	print( "loading gamerules map" )
end

function GameRules:getValue()
	return self.value
end

function GameRules:__tostring()
	return "wft"
end

function GameRules:warpCameraTo( x, y )
	self.camera_x = x
	self.camera_y = y
end

function GameRules:getCameraPosition()
	return self.camera_x, self.camera_y
end

function GameRules:setCameraPosition( camera_x, camera_y )
	self.camera_x = camera_x
	self.camera_y = camera_y
end