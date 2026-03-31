--!strict
-- GameConfig (ModuleScript in ReplicatedStorage)
-- Shared settings for the color pillar game

local GameConfig = {}

GameConfig.MIN_PLAYERS = 1 -- set to 2 for real matches
GameConfig.MAX_ROUNDS = 10
GameConfig.MEMORIZE_TIME = 5
GameConfig.GUESS_TIME = 15

GameConfig.WATER_START_Y = -10
GameConfig.WATER_RISE_PER_ROUND = 14

GameConfig.BASE_PILLAR_HEIGHT = 40
GameConfig.PILLAR_WIDTH = 8
GameConfig.PILLAR_SPACING_RADIUS = 50
GameConfig.STUDS_PER_SCORE_POINT = 2

GameConfig.LOBBY_WAIT = 15

-- Scoring weights (must sum to 1)
GameConfig.HUE_WEIGHT = 0.50
GameConfig.SAT_WEIGHT = 0.25
GameConfig.BRI_WEIGHT = 0.25

return GameConfig
