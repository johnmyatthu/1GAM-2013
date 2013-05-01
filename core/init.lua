module( ..., package.seeall )
init_path = init_path or ({...})[1]:gsub("[%.\\/]init$", "") .. '.'

require "lib.json4lua.trunk.json.json"
require "lib.middleclass.middleclass"
require (init_path .. "gamestates")
require (init_path .. "logging")
require (init_path .. "entity")
require (init_path .. "gamerules")
require (init_path .. "util")
require (init_path .. "spritesheet")
require (init_path .. "actions")