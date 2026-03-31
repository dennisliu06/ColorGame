--!strict
-- PillarManager (ModuleScript in ServerScriptService)
-- Creates, raises, and removes player pillars

local ReplicatedStorage = game:GetService("ReplicatedStorage")
local GameConfig = require(ReplicatedStorage:WaitForChild("GameConfig"))

local PillarManager = {}

--------------------------------------------------------------
-- STATE
--------------------------------------------------------------
local activePillars: { [Player]: BasePart } = {}
local pillarHeights: { [Player]: number } = {}
local pillarsFolder: Folder = nil :: any

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
-- CREATE A SINGLE PILLAR
--------------------------------------------------------------
local function createPillar(player: Player, position: Vector3): BasePart
	local pillar = Instance.new("Part")
	pillar.Name = "Pillar_" .. player.Name
	pillar.Size = Vector3.new(
		GameConfig.PILLAR_WIDTH,
		GameConfig.BASE_PILLAR_HEIGHT,
		GameConfig.PILLAR_WIDTH
	)
	pillar.Position = position
	pillar.Anchored = true
	pillar.CanCollide = true
	pillar.Material = Enum.Material.SmoothPlastic
	pillar.Color = Color3.fromRGB(200, 200, 210)
	pillar.TopSurface = Enum.SurfaceType.Smooth
	pillar.BottomSurface = Enum.SurfaceType.Smooth

	-- Name label on the front face
	local surfGui = Instance.new("SurfaceGui")
	surfGui.Face = Enum.NormalId.Front
	surfGui.Parent = pillar

	local nameLabel = Instance.new("TextLabel")
	nameLabel.Name = "PlayerName"
	nameLabel.Size = UDim2.new(1, 0, 0.12, 0)
	nameLabel.Position = UDim2.new(0, 0, 0.02, 0)
	nameLabel.BackgroundTransparency = 1
	nameLabel.Text = player.DisplayName
	nameLabel.TextScaled = true
	nameLabel.TextColor3 = Color3.new(1, 1, 1)
	nameLabel.Font = Enum.Font.GothamBold
	nameLabel.Parent = surfGui

	pillar.Parent = pillarsFolder
	return pillar
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

		local pillar = createPillar(player, Vector3.new(x, y, z))
		activePillars[player] = pillar
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
				hum.JumpPower = 0
			end
		end
	end
end

--------------------------------------------------------------
-- RAISE A PLAYER'S PILLAR BASED ON SCORE
--------------------------------------------------------------
function PillarManager.RaisePillar(player: Player, score: number)
	local pillar = activePillars[player]
	if not pillar then return end

	local addedHeight = score * GameConfig.STUDS_PER_SCORE_POINT
	pillarHeights[player] = pillarHeights[player] + addedHeight

	local newHeight = pillarHeights[player]
	pillar.Size = Vector3.new(GameConfig.PILLAR_WIDTH, newHeight, GameConfig.PILLAR_WIDTH)
	pillar.Position = Vector3.new(pillar.Position.X, newHeight / 2, pillar.Position.Z)

	-- Move player to top
	local char = player.Character
	if char then
		local hrp = char:FindFirstChild("HumanoidRootPart") :: BasePart
		if hrp then
			hrp.CFrame = CFrame.new(pillar.Position.X, newHeight + 4, pillar.Position.Z)
		end
	end
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
	local pillar = activePillars[player]
	if pillar then
		pillar:Destroy()
	end
	activePillars[player] = nil
	pillarHeights[player] = nil
end

--------------------------------------------------------------
-- CLEAR ALL
--------------------------------------------------------------
function PillarManager.ClearAll()
	for _, pillar in pairs(activePillars) do
		pillar:Destroy()
	end
	activePillars = {}
	pillarHeights = {}
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
