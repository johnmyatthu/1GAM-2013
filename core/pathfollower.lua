require "core"

PathFollower = class( "PathFollower", AnimatedSprite )
function PathFollower:initialize()
	AnimatedSprite:initialize(self)
	self.path = nil
	self.current_path_step = 1
	self.velocity = { x=0, y=0 }
	self.follow_path = true
end

function PathFollower:setPath( path )
	if path then
		self.path = path
		self.current_path_step = 1
	else
		logging.warning( "PathFollower: path is invalid, ignoring!" )
	end
end

function PathFollower:currentTarget()
	if self.path and self.current_path_step < #self.path then
		return self.path[ self.current_path_step ]
	else
		return {x=-1, y=-1}
	end
end

function PathFollower:onUpdate( params )
	if self.follow_path then

		-- the minimum number of units the sprite can be to a tile's center before it is considered "close enough"
		local TILE_DISTANCE_THRESHOLD = 1.1
		local command = { up=false, down=false, left=false, right=false }

		if self.path then
			local tile = self.path[ self.current_path_step ]
			if tile then
				local cx, cy = params.gamerules:worldCoordinatesFromTileCenter( tile.x, tile.y )
				self.velocity.x = cx - self.world_x
				self.velocity.y = cy - self.world_y

				local dx, dy = math.abs(self.velocity.x), math.abs(self.velocity.y)

				-- check x and y separately, snap these in place if they're within the threshold
				if dx < TILE_DISTANCE_THRESHOLD then
					self.world_x = cx
					self.velocity.x = 0
				end

				if dy < TILE_DISTANCE_THRESHOLD then
					self.world_y = cy
					self.velocity.y = 0
				end

				if self.tile_x == tile.x and self.tile_y == tile.y and dx < TILE_DISTANCE_THRESHOLD and dy < TILE_DISTANCE_THRESHOLD then
					self.world_x = cx
					self.world_y = cy

					if self.current_path_step == #self.path then
						logging.verbose( "reached the last step of the path. stopping here." )
						self.path = nil
						return			
					end
				
					self.current_path_step = self.current_path_step + 1
					logging.verbose( "reached step in the path" )
					return
				end

				dir = {x = 0, y = 0}
				if self.velocity.x ~= 0 then
					if self.velocity.x > 0 then
						dir.x = self.move_speed
					else
						dir.x = -self.move_speed
					end
					self.velocity.x = 0
				end
				if self.velocity.y ~= 0 then
					if self.velocity.y > 0 then
						dir.y = self.move_speed
					else
						dir.y = -self.move_speed
					end
					self.velocity.y = 0
				end
			
				params.gamerules:moveEntityInDirection(self, dir, params.dt)
			end
		end

		--command.move_speed = 0
		--params.gamerules:handleMovePlayerCommand( command, self )
	end

	AnimatedSprite.onUpdate(self, params)
end