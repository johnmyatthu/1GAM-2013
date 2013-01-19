-- build time before a wave
GAME_STATE_BUILD = 0

-- defend state, where most of the playing happens
GAME_STATE_DEFEND = 1

-- transition state between build and defend
GAME_STATE_PRE_DEFEND = 2

-- player won this round
GAME_STATE_ROUND_WIN = 3

-- player failed this round
GAME_STATE_ROUND_FAIL = 4