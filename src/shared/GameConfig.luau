--!strict
-- GameConfig (ModuleScript in ReplicatedStorage)
-- Shared settings for the color pillar game

local GameConfig = {}

GameConfig.MIN_PLAYERS = 1 -- set to 2 for real matches
GameConfig.MAX_ROUNDS = 10
GameConfig.MEMORIZE_TIME = 5
GameConfig.GUESS_TIME = 15

GameConfig.WATER_START_Y = 10
GameConfig.WATER_RISE_PER_ROUND = 25   -- base studs added each round
GameConfig.WATER_ACCEL_FACTOR = 3   -- extra studs added per round² (quadratic acceleration)

GameConfig.BASE_PILLAR_HEIGHT = 40
GameConfig.PILLAR_WIDTH = 8
GameConfig.PILLAR_SPACING_RADIUS = 50
GameConfig.STUDS_PER_SCORE_POINT = 5
GameConfig.PILLAR_LAYER_HEIGHT = 4        -- studs per visual layer segment
GameConfig.PILLAR_LAYER_ANIM_DELAY = 0.18 -- seconds between each layer appearing on raise
GameConfig.SCORE_DISPLAY_DELAY = 2.5      -- seconds players see their score before pillars rise

GameConfig.LOBBY_WAIT = 15

-- Sound IDs (replace with your preferred asset IDs)
GameConfig.PILLAR_RISE_SOUND_ID = "rbxassetid://6042053626" -- whoosh/rise sound

-- Scoring weights (must sum to 1)
GameConfig.HUE_WEIGHT = 0.50
GameConfig.SAT_WEIGHT = 0.25
GameConfig.BRI_WEIGHT = 0.25

return GameConfig
