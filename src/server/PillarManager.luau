--!strict
-- PillarManager (ModuleScript in ServerScriptService)
-- Creates, raises, and removes player pillars (layered appearance)

local ReplicatedStorage = game:GetService("ReplicatedStorage")
local GameConfig = require(ReplicatedStorage:WaitForChild("GameConfig"))

local PillarManager = {}

--------------------------------------------------------------
-- STATE
--------------------------------------------------------------
local activePillars: { [Player]: Model } = {}
local pillarHeights: { [Player]: number } = {}
local pillarBuiltUpTo: { [Player]: number } = {}  -- visual layers built up to this Y
local pillarNextLayer: { [Player]: number } = {}   -- next layer index to assign
local pillarsFolder: Folder = nil :: any

-- Alternating layer colours
local LAYER_COLORS = {
	Color3.fromRGB(200, 200, 210),
	Color3.fromRGB(155, 160, 178),
}
local LAYER_GAP = 0.15  -- gap between visual segments (studs)

--------------------------------------------------------------
-- INIT: Create the Pillars folder in workspace
--------------------------------------------------------------
function PillarManager.Init()
	local arena = workspace:FindFirstChild("Arena")
	if not arena then
		arena = Instance.new("Folder")
		arena.Name = "Arena"
		arena.Parent = workspace
	end

	pillarsFolder = arena:FindFirstChild("Pillars") :: Folder
	if not pillarsFolder then
		pillarsFolder = Instance.new("Folder")
		pillarsFolder.Name = "Pillars"
		pillarsFolder.Parent = arena
	end
end

--------------------------------------------------------------
-- ADD VISUAL LAYER SEGMENTS from fromY to toY
-- Returns the next layer index after the ones created
--------------------------------------------------------------
local function addVisualLayers(
	model: Model,
	xPos: number,
	zPos: number,
	fromY: number,
	toY: number,
	startIdx: number
): number
	local layerH = GameConfig.PILLAR_LAYER_HEIGHT
	local y = fromY
	local i = startIdx

	while y < toY do
		local segH = math.min(layerH, toY - y)
		local visualH = math.max(segH - LAYER_GAP, 0.05)

		local layer = Instance.new("Part")
		layer.Name = "Layer_" .. i
		layer.Size = Vector3.new(GameConfig.PILLAR_WIDTH, visualH, GameConfig.PILLAR_WIDTH)
		layer.CFrame = CFrame.new(xPos, y + segH / 2, zPos)
		layer.Anchored = true
		layer.CanCollide = false  -- collision handled by the transparent Collision part
		layer.Material = Enum.Material.SmoothPlastic
		layer.Color = LAYER_COLORS[((i - 1) % #LAYER_COLORS) + 1]
		layer.TopSurface = Enum.SurfaceType.Smooth
		layer.BottomSurface = Enum.SurfaceType.Smooth
		layer.Parent = model

		y += layerH
		i += 1
	end

	return i
end

--------------------------------------------------------------
-- CREATE A SINGLE PILLAR (returns Model)
--------------------------------------------------------------
local function createPillar(player: Player, position: Vector3): Model
	local xPos = position.X
	local zPos = position.Z
	local totalHeight = GameConfig.BASE_PILLAR_HEIGHT

	local model = Instance.new("Model")
	model.Name = "Pillar_" .. player.Name

	-- Invisible full-height collision part — player stands on this
	local collision = Instance.new("Part")
	collision.Name = "Collision"
	collision.Size = Vector3.new(GameConfig.PILLAR_WIDTH, totalHeight, GameConfig.PILLAR_WIDTH)
	collision.CFrame = CFrame.new(xPos, totalHeight / 2, zPos)
	collision.Anchored = true
	collision.CanCollide = true
	collision.Transparency = 1
	collision.CastShadow = false
	collision.Parent = model
	model.PrimaryPart = collision

	-- Visual layer segments
	local nextIdx = addVisualLayers(model, xPos, zPos, 0, totalHeight, 1)
	pillarBuiltUpTo[player] = totalHeight
	pillarNextLayer[player] = nextIdx

	-- Name label on the lowest visible layer
	local layer1 = model:FindFirstChild("Layer_1") :: BasePart
	if layer1 then
		local surfGui = Instance.new("SurfaceGui")
		surfGui.Face = Enum.NormalId.Front
		surfGui.Parent = layer1

		local nameLabel = Instance.new("TextLabel")
		nameLabel.Name = "PlayerName"
		nameLabel.Size = UDim2.new(1, 0, 0.5, 0)
		nameLabel.Position = UDim2.new(0, 0, 0.25, 0)
		nameLabel.BackgroundTransparency = 1
		nameLabel.Text = player.DisplayName
		nameLabel.TextScaled = true
		nameLabel.TextColor3 = Color3.new(1, 1, 1)
		nameLabel.Font = Enum.Font.GothamBold
		nameLabel.Parent = surfGui
	end

	-- Rise sound on the collision part
	local riseSound = Instance.new("Sound")
	riseSound.Name = "RiseSound"
	riseSound.SoundId = GameConfig.PILLAR_RISE_SOUND_ID
	riseSound.Volume = 0.6
	riseSound.RollOffMaxDistance = 120
	riseSound.Parent = collision

	model.Parent = pillarsFolder
	return model
end

--------------------------------------------------------------
-- SPAWN PILLARS IN A CIRCLE FOR ALL PLAYERS
--------------------------------------------------------------
function PillarManager.SpawnPillars(players: { Player })
	PillarManager.ClearAll()

	local count = #players
	for i, player in ipairs(players) do
		local angle = (i / count) * math.pi * 2
		local x = math.cos(angle) * GameConfig.PILLAR_SPACING_RADIUS
		local z = math.sin(angle) * GameConfig.PILLAR_SPACING_RADIUS
		local y = GameConfig.BASE_PILLAR_HEIGHT / 2

		local pillarModel = createPillar(player, Vector3.new(x, y, z))
		activePillars[player] = pillarModel
		pillarHeights[player] = GameConfig.BASE_PILLAR_HEIGHT

		-- Teleport player on top and lock movement
		local char = player.Character
		if char then
			local hrp = char:FindFirstChild("HumanoidRootPart") :: BasePart
			if hrp then
				hrp.CFrame = CFrame.new(x, GameConfig.BASE_PILLAR_HEIGHT + 4, z)
			end
			local hum = char:FindFirstChildOfClass("Humanoid") :: Humanoid
			if hum then
				hum.WalkSpeed = 0
				hum.JumpPower = 50
			end
		end
	end
end

--------------------------------------------------------------
-- RAISE A PLAYER'S PILLAR BASED ON SCORE (animated)
--------------------------------------------------------------
function PillarManager.RaisePillar(player: Player, score: number)
	local pillarModel = activePillars[player]
	if not pillarModel then return end

	local addedHeight = score * GameConfig.STUDS_PER_SCORE_POINT
	if addedHeight <= 0 then return end

	local prevHeight = pillarHeights[player]
	pillarHeights[player] = prevHeight + addedHeight
	local newHeight = pillarHeights[player]

	local collision = pillarModel:FindFirstChild("Collision") :: BasePart
	if not collision then return end

	local xPos = collision.CFrame.X
	local zPos = collision.CFrame.Z

	-- Play rise sound once at the start
	local riseSound = collision:FindFirstChild("RiseSound") :: Sound
	if riseSound then
		riseSound:Play()
	end

	-- Capture current layer state before spawning
	local fromY = pillarBuiltUpTo[player]
	local layerIdx = pillarNextLayer[player]

	-- Animate: grow collision part and add visual layers one at a time
	task.spawn(function()
		local layerH = GameConfig.PILLAR_LAYER_HEIGHT
		local y = fromY
		local i = layerIdx

		while y < newHeight do
			-- Guard: pillar may have been removed mid-animation (elimination)
			if not pillarModel.Parent then break end

			local segH = math.min(layerH, newHeight - y)
			local stepTopY = y + segH

			-- Grow collision part to this step's height
			collision.Size = Vector3.new(GameConfig.PILLAR_WIDTH, stepTopY, GameConfig.PILLAR_WIDTH)
			collision.CFrame = CFrame.new(xPos, stepTopY / 2, zPos)

			-- Add the visual layer for this step
			local visualH = math.max(segH - LAYER_GAP, 0.05)
			local layer = Instance.new("Part")
			layer.Name = "Layer_" .. i
			layer.Size = Vector3.new(GameConfig.PILLAR_WIDTH, visualH, GameConfig.PILLAR_WIDTH)
			layer.CFrame = CFrame.new(xPos, y + segH / 2, zPos)
			layer.Anchored = true
			layer.CanCollide = false
			layer.Material = Enum.Material.SmoothPlastic
			layer.Color = LAYER_COLORS[((i - 1) % #LAYER_COLORS) + 1]
			layer.TopSurface = Enum.SurfaceType.Smooth
			layer.BottomSurface = Enum.SurfaceType.Smooth
			layer.Parent = pillarModel

			-- Ride the player up with the pillar
			local char = player.Character
			if char then
				local hrp = char:FindFirstChild("HumanoidRootPart") :: BasePart
				if hrp then
					hrp.CFrame = CFrame.new(xPos, stepTopY + 4, zPos)
				end
			end

			y += layerH
			i += 1
			task.wait(GameConfig.PILLAR_LAYER_ANIM_DELAY)
		end

		-- Update state after animation completes
		pillarBuiltUpTo[player] = newHeight
		pillarNextLayer[player] = i

		-- Snap collision to exact final height in case of float imprecision
		if pillarModel.Parent then
			collision.Size = Vector3.new(GameConfig.PILLAR_WIDTH, newHeight, GameConfig.PILLAR_WIDTH)
			collision.CFrame = CFrame.new(xPos, newHeight / 2, zPos)
		end
	end)
end

--------------------------------------------------------------
-- GET PILLAR TOP Y
--------------------------------------------------------------
function PillarManager.GetPillarTopY(player: Player): number
	return pillarHeights[player] or 0
end

--------------------------------------------------------------
-- REMOVE A PLAYER (elimination)
--------------------------------------------------------------
function PillarManager.RemovePillar(player: Player)
	local pillarModel = activePillars[player]
	if pillarModel then
		pillarModel:Destroy()
	end
	activePillars[player] = nil
	pillarHeights[player] = nil
	pillarBuiltUpTo[player] = nil
	pillarNextLayer[player] = nil
end

--------------------------------------------------------------
-- CLEAR ALL
--------------------------------------------------------------
function PillarManager.ClearAll()
	for _, pillarModel in pairs(activePillars) do
		pillarModel:Destroy()
	end
	activePillars = {}
	pillarHeights = {}
	pillarBuiltUpTo = {}
	pillarNextLayer = {}
end

--------------------------------------------------------------
-- GET ALL ALIVE PLAYERS
--------------------------------------------------------------
function PillarManager.GetActivePlayers(): { Player }
	local result = {}
	for player in pairs(activePillars) do
		table.insert(result, player)
	end
	return result
end

return PillarManager
