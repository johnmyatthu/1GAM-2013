module( ..., package.seeall )
init_path = init_path or ({...})[1]:gsub("[%.\\/]init$", "") .. '.'

require (init_path .. "help")
require (init_path .. "mainmenu")
require (init_path .. "logo")
