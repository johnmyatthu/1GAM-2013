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
	--AnimatedSprite:onUpdate( params )
	if self.follow_path then

		-- the minimum number of units the sprite can be to a tile's center before it is considered "close enough"
		local TILE_DISTANCE_THRESHOLD = 2
		local command = { up=false, down=false, left=false, right=false }
		command.move_speed = 75
		command.dt = params.dt

		if self.path then
			tile = self.path[ self.current_path_step ]



			local cx, cy = params.gamerules:worldCoordinatesFromTileCenter( tile.x, tile.y )
			--logging.verbose( "tile.x: " .. tile.x .. ", tile.y: " .. tile.y )

			self.velocity.x = cx - self.world_x
			self.velocity.y = cy - self.world_y


			--logging.verbose( "c.x: " .. cx .. ", c.y: " .. cy )
			--logging.verbose( "w.x: " .. self.world_x .. ", w.y: " .. self.world_y )
			--logging.verbose( "v.x: " .. self.velocity.x .. ", v.y: " .. self.velocity.y )
			-- determine absolute distance
			--logging.verbose( "velocity: " .. self.velocity.x .. ", " .. self.velocity.y )
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
				--logging.verbose( "dx: " .. dx .. ", dy: " .. dy )
				self.world_x = cx
				self.world_y = cy

				if self.current_path_step == #self.path then
					--logging.verbose( "ended path at " .. self.current_path_step )
					self.path = nil
					return			
				end

				
				self.current_path_step = self.current_path_step + 1
				--logging.verbose( "next path step ... " .. self.current_path_step )

				return
			end


			-- this mess should be refactored and put into gamerules to use collision.
			local min_vel = command.move_speed
			
			local mx = 0
			local my = 0
			if self.velocity.x ~= 0 then
				if self.velocity.x > 0 then mx = command.move_speed else mx = -command.move_speed end
			end
			if self.velocity.y ~= 0 then
				if self.velocity.y > 0 then my = command.move_speed else my = -command.move_speed end
			end

			local vertical_speed = my
			if mx ~= 0 and my ~= 0 then
				vertical_speed = my * 0.5
			end

			if self.velocity.x > 0 then
				command.right = true
			elseif self.velocity.x < 0 then
				command.left = true
			end

			if self.velocity.y > 0 then
				command.down = true
			elseif self.velocity.y < 0 then
				command.up = true
			end

			self.world_x = self.world_x + (mx * params.dt)
			self.world_y = self.world_y + (vertical_speed * params.dt)
			--logging.verbose( "up: " .. tostring(command.up) .. ", down: " .. tostring(command.down) .. ", left: " .. tostring(command.left) .. ", right: " .. tostring(command.right) )
		end

		command.move_speed = 0
		params.gamerules:handleMovePlayerCommand( command, self )
	end

	AnimatedSprite.onUpdate(self, params)
end