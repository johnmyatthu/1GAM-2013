module( ..., package.seeall )
init_path = init_path or ({...})[1]:gsub("[%.\\/]init$", "") .. '.'

require "lib.json4lua.trunk.json.json"
require "lib.middleclass.middleclass"

GAME_STATE_BUILD = 0
GAME_STATE_DEFEND = 1
GAME_STATE_PRE_DEFEND = 2

GAME_STATE_ROUND_WIN = 3
GAME_STATE_ROUND_FAIL = 4

return {
	require (init_path .. "logging"),
	require (init_path .. "gamerules"),
	require (init_path .. "entity"),
	require (init_path .. "util"),
	require (init_path .. "spritesheet"),
}