module( ..., package.seeall )

MOVE_MAP_LEFT = "move_map_left"
MOVE_MAP_RIGHT = "move_map_right"
MOVE_MAP_UP = "move_map_up"
MOVE_MAP_DOWN = "move_map_down"
MOVE_PLAYER_LEFT = "move_player_left"
MOVE_PLAYER_RIGHT = "move_player_right"
MOVE_PLAYER_UP = "move_player_up"
MOVE_PLAYER_DOWN = "move_player_down"
USE = "use"


ActionMap = class( "ActionMap" )

function ActionMap:initialize( config, action_table )
	self.key_to_action_table = {}
	self.key_to_action_table[ core.actions.MOVE_MAP_LEFT ] = "left"
	self.key_to_action_table[ core.actions.MOVE_MAP_RIGHT ] = "right"
	self.key_to_action_table[ core.actions.MOVE_MAP_UP ] = "up"
	self.key_to_action_table[ core.actions.MOVE_MAP_DOWN ] = "down"

	self.key_to_action_table[ core.actions.MOVE_PLAYER_LEFT ] = "a"
	self.key_to_action_table[ core.actions.MOVE_PLAYER_RIGHT ] = "d"
	self.key_to_action_table[ core.actions.MOVE_PLAYER_UP ] = "w"
	self.key_to_action_table[ core.actions.MOVE_PLAYER_DOWN ] = "s"

	self.key_to_action_table[ core.actions.USE ] = "e"

	self.actions = {}
	logging.verbose( "Mapping keys to actions..." )
	for key, action in pairs(config.keys) do
		--self.actions[ "d_togglecollisions" ] = self.toggleDrawCollisions
		logging.verbose( "\t'" .. key .. "' -> '" .. action .. "'" )

		if action_table[ action ] then
			self.actions[ key ] = action_table[ action ]
		elseif self.key_to_action_table[ action ] then -- override default keys
			self.key_to_action_table[ action ] = key
		else
			logging.warning( "Unknown action '" .. action .. "', unable to map key: " .. key )
		end
	end
end

function ActionMap:set_action( key, instance, action )
	self.actions[ key ] = { instance=instance, action=action }
end

function ActionMap:get_action( key )
	return self.actions[ key ]
end

function ActionMap:on_key_pressed( key )
	local info = self.actions[ key ]
	if info and info.action and info.instance then
		info.action( info.instance )
	end	
end


function ActionMap:key_for_action( action )
	return self.key_to_action_table[ action ]
end
