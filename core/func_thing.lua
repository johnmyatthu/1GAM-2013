require "core"

func_thing = class( "func_thing", AnimatedSprite )
function func_thing:initialize()
	AnimatedSprite.initialize(self)
	self.collision_mask = 3
	self.health = 0

	self.pv = { x=0, y=0 }
end

function func_thing:onSpawn( params )
	AnimatedSprite.onSpawn( self, params )

	self:loadSprite( "assets/sprites/items.conf" )
	self:playAnimation( "chest" )	
end

function func_thing:onHit( params )
	if self.health > 0 then
		self.health = self.health - params.attack_damage
		self.time_since_last_hit = 0
		if self.health < 0 then
			self.health = 0
		end
	end
end

function func_thing:__tostring()
	return AnimatedSprite.__tostring(self) .. ", Health: " .. self.health
end

function func_thing:useActionString()
	return nil
end

function func_thing:onDraw( params )
	AnimatedSprite.onDraw( self, params )
end

function func_thing:onUpdate( params )
	self.velocity.x = self.pv.x
	self.velocity.y = self.pv.y

	if not params.gamerules:isTileWithinMap( self.tile_x, self.tile_y ) then
		params.gamerules:removeEntity( self )
	end

	local dist = params.gamerules:calculateEntityDistance( self, params.gamerules.player )
	if dist >= 750 then
		--logging.verbose( "Too far from player, removing" )
		params.gamerules:removeEntity(self)
	end

	AnimatedSprite.onUpdate( self, params )
end

function func_thing:startInteraction( params )
end

function func_thing:endInteraction( params )
end