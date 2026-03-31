# 🎨 Color Pillar Game — Complete Rojo Build Guide

---

## PHASE 1: INSTALL EVERYTHING

### 1A — Install Tools

| Tool | Where to get it |
|------|----------------|
| **Rojo v7** | https://github.com/rojo-rbx/rojo/releases (download binary for your OS) |
| **VS Code** | https://code.visualstudio.com |
| **Git** | https://git-scm.com |
| **Rojo VS Code Extension** | Search "Rojo - Roblox Studio Sync" in VS Code extensions |
| **Roblox LSP** | Search "Roblox LSP" in VS Code extensions (for autocomplete) |
| **Selene** | Search "Selene" in VS Code extensions (catches Lua mistakes) |
| **Roblox Studio** | You still need this for building the 3D arena + testing |

### 1B — Install the Rojo Plugin in Studio

1. Open Roblox Studio
2. Go to **Plugins** tab → **Manage Plugins**
3. Search for **"Rojo"** and install it (or get it from the Rojo GitHub releases page as a `.rbxm` file and drop it into your Studio plugins folder)

### 1C — Verify Rojo Works

Open a terminal and run:
```bash
rojo --version
```
You should see something like `rojo 7.x.x`. If not, make sure the Rojo binary is in your system PATH.

---

## PHASE 2: CREATE THE PROJECT

### 2A — Initialize

```bash
mkdir color-pillar-game
cd color-pillar-game
rojo init
```

### 2B — Set Up Git

```bash
git init
```

Create a `.gitignore` file:
```
*.rbxl
*.rbxlx
*.rbxm
*.rbxmx
```

### 2C — Create the Folder Structure

Delete everything inside `src/` that Rojo generated, then create this structure:

```
color-pillar-game/
├── default.project.json
├── .gitignore
├── src/
│   ├── server/
│   │   ├── GameManager.server.luau
│   │   └── PillarManager.luau
│   ├── client/
│   │   └── ColorGameClient.client.luau
│   └── shared/
│       └── GameConfig.luau
```

> **Naming rules:**
> - `.server.luau` → becomes a **Script** (runs on server)
> - `.client.luau` → becomes a **LocalScript** (runs on client)
> - `.luau` → becomes a **ModuleScript**

### 2D — Edit `default.project.json`

Replace the entire contents with:

```json
{
  "name": "ColorPillarGame",
  "tree": {
    "$className": "DataModel",

    "ServerScriptService": {
      "$className": "ServerScriptService",
      "$path": "src/server"
    },

    "StarterPlayer": {
      "$className": "StarterPlayer",
      "StarterPlayerScripts": {
        "$className": "StarterPlayerScripts",
        "$path": "src/client"
      }
    },

    "ReplicatedStorage": {
      "$className": "ReplicatedStorage",
      "$path": "src/shared"
    }
  }
}
```

> **Note:** The GUI and arena are built in Studio manually — Rojo handles the code.

---

## PHASE 3: WRITE THE CODE

### File 1 — `src/shared/GameConfig.luau`

This shared config is readable by both server and client.

```lua
--!strict
-- GameConfig (ModuleScript in ReplicatedStorage)
-- Shared settings for the color pillar game

local GameConfig = {}

GameConfig.MIN_PLAYERS = 2
GameConfig.MAX_ROUNDS = 10
GameConfig.MEMORIZE_TIME = 5
GameConfig.GUESS_TIME = 15

GameConfig.WATER_START_Y = -10
GameConfig.WATER_RISE_PER_ROUND = 6

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
```

---

### File 2 — `src/server/PillarManager.luau`

```lua
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

		-- Teleport player on top
		local char = player.Character
		if char then
			local hrp = char:FindFirstChild("HumanoidRootPart") :: BasePart
			if hrp then
				hrp.CFrame = CFrame.new(x, GameConfig.BASE_PILLAR_HEIGHT + 4, z)
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
```

---

### File 3 — `src/server/GameManager.server.luau`

```lua
--!strict
-- GameManager (Script in ServerScriptService)
-- Main server game loop: lobby → rounds → elimination → winner

local Players = game:GetService("Players")
local ReplicatedStorage = game:GetService("ReplicatedStorage")
local TweenService = game:GetService("TweenService")

local GameConfig = require(ReplicatedStorage:WaitForChild("GameConfig"))
local PillarManager = require(script.Parent:WaitForChild("PillarManager"))

--------------------------------------------------------------
-- CREATE REMOTE EVENTS
--------------------------------------------------------------
local eventsFolder = Instance.new("Folder")
eventsFolder.Name = "Events"
eventsFolder.Parent = ReplicatedStorage

local function makeRemote(name: string): RemoteEvent
	local r = Instance.new("RemoteEvent")
	r.Name = name
	r.Parent = eventsFolder
	return r
end

local ShowColor        = makeRemote("ShowColor")
local StartGuessing    = makeRemote("StartGuessing")
local SubmitGuess      = makeRemote("SubmitGuess")
local RoundResult      = makeRemote("RoundResult")
local PlayerEliminated = makeRemote("PlayerEliminated")
local GameOverEvent    = makeRemote("GameOver")
local WaterLevel       = makeRemote("WaterLevel")
local LobbyTimer       = makeRemote("LobbyTimer")

--------------------------------------------------------------
-- ARENA REFERENCES (built in Studio — see Phase 4)
--------------------------------------------------------------
local arena = workspace:WaitForChild("Arena")
local waterPart = arena:WaitForChild("WaterPart") :: BasePart
local colorScreen = arena:WaitForChild("ColorScreen") :: BasePart
local colorScreenGui = colorScreen:FindFirstChildWhichIsA("SurfaceGui")
local colorFrame = colorScreenGui and colorScreenGui:WaitForChild("ColorFrame") :: Frame
local screenTimer = colorScreenGui and colorScreenGui:FindFirstChild("TimerText") :: TextLabel
local screenRound = colorScreenGui and colorScreenGui:FindFirstChild("RoundText") :: TextLabel

--------------------------------------------------------------
-- UTILITY
--------------------------------------------------------------
local function hsvToColor3(h: number, s: number, v: number): Color3
	return Color3.fromHSV(h % 1, math.clamp(s, 0, 1), math.clamp(v, 0, 1))
end

local function calculateScore(tH: number, tS: number, tV: number, gH: number, gS: number, gV: number): number
	local hueDiff = math.abs(tH - gH)
	if hueDiff > 0.5 then hueDiff = 1 - hueDiff end
	hueDiff = hueDiff * 2 -- normalize to 0–1 range

	local satDiff = math.abs(tS - gS)
	local briDiff = math.abs(tV - gV)

	local totalDiff = (hueDiff * GameConfig.HUE_WEIGHT)
		+ (satDiff * GameConfig.SAT_WEIGHT)
		+ (briDiff * GameConfig.BRI_WEIGHT)

	return math.clamp(math.round((1 - totalDiff) * 10), 0, 10)
end

--------------------------------------------------------------
-- WATER CONTROL
--------------------------------------------------------------
local function setWaterLevel(targetY: number, duration: number?)
	local tweenInfo = TweenInfo.new(duration or 3, Enum.EasingStyle.Sine, Enum.EasingDirection.InOut)
	local tween = TweenService:Create(waterPart, tweenInfo, {
		Position = Vector3.new(waterPart.Position.X, targetY, waterPart.Position.Z),
	})
	tween:Play()

	-- Tell all clients so they can see/hear it
	for _, p in ipairs(Players:GetPlayers()) do
		WaterLevel:FireClient(p, targetY)
	end

	tween.Completed:Wait()
end

--------------------------------------------------------------
-- ELIMINATION CHECK
--------------------------------------------------------------
local function checkEliminations(waterY: number): number
	local alive = PillarManager.GetActivePlayers()
	local eliminated: { Player } = {}

	for _, player in ipairs(alive) do
		local topY = PillarManager.GetPillarTopY(player)
		if topY <= waterY + 1 then
			table.insert(eliminated, player)
		end
	end

	for _, player in ipairs(eliminated) do
		PillarManager.RemovePillar(player)

		-- Notify everyone
		for _, p in ipairs(Players:GetPlayers()) do
			PlayerEliminated:FireClient(p, player.DisplayName)
		end

		-- Move eliminated player to spectate position
		local char = player.Character
		if char then
			local hrp = char:FindFirstChild("HumanoidRootPart") :: BasePart
			if hrp then
				hrp.CFrame = CFrame.new(0, 120, -80)
			end
		end
	end

	return #PillarManager.GetActivePlayers()
end

--------------------------------------------------------------
-- SINGLE ROUND
--------------------------------------------------------------
local function playRound(roundNum: number, alivePlayers: { Player }): number
	-- Generate random target color (avoid very dull / dark colors)
	local tH = math.random()
	local tS = math.random() * 0.6 + 0.4
	local tV = math.random() * 0.6 + 0.4
	local targetColor = hsvToColor3(tH, tS, tV)

	-- ── PHASE 1: SHOW COLOR ──
	if colorFrame then
		colorFrame.BackgroundColor3 = targetColor
	end
	if screenRound then
		screenRound.Text = "Round " .. roundNum .. "/" .. GameConfig.MAX_ROUNDS
	end

	for _, player in ipairs(alivePlayers) do
		ShowColor:FireClient(player, tH, tS, tV, roundNum, GameConfig.MAX_ROUNDS)
	end

	-- Countdown on the big screen
	for t = GameConfig.MEMORIZE_TIME, 1, -1 do
		if screenTimer then screenTimer.Text = tostring(t) end
		task.wait(1)
	end
	if screenTimer then screenTimer.Text = "" end

	-- Hide the color on the big screen
	if colorFrame then
		colorFrame.BackgroundColor3 = Color3.fromRGB(30, 30, 30)
	end

	-- ── PHASE 2: GUESSING ──
	local guesses: { [Player]: { h: number, s: number, v: number } } = {}

	local conn = SubmitGuess.OnServerEvent:Connect(function(player, h, s, v)
		if typeof(h) == "number" and typeof(s) == "number" and typeof(v) == "number" then
			if not guesses[player] then
				guesses[player] = { h = h, s = s, v = v }
			end
		end
	end)

	for _, player in ipairs(alivePlayers) do
		StartGuessing:FireClient(player, GameConfig.GUESS_TIME)
	end

	-- Wait for all guesses or timeout
	local startTime = tick()
	while tick() - startTime < GameConfig.GUESS_TIME do
		local allIn = true
		for _, player in ipairs(alivePlayers) do
			if not guesses[player] then
				allIn = false
				break
			end
		end
		if allIn then break end
		task.wait(0.5)
	end

	conn:Disconnect()

	-- ── PHASE 3: SCORE + RAISE PILLARS ──
	for _, player in ipairs(alivePlayers) do
		local guess = guesses[player]
		local score = 0

		if guess then
			score = calculateScore(tH, tS, tV, guess.h, guess.s, guess.v)
		end

		PillarManager.RaisePillar(player, score)
		RoundResult:FireClient(player, score, tH, tS, tV)
	end

	task.wait(3)

	-- ── PHASE 4: RAISE WATER ──
	local newWaterY = GameConfig.WATER_START_Y + (roundNum * GameConfig.WATER_RISE_PER_ROUND)
	setWaterLevel(newWaterY, 3)

	task.wait(1.5)

	-- ── PHASE 5: ELIMINATIONS ──
	local remaining = checkEliminations(newWaterY)
	task.wait(2)

	return remaining
end

--------------------------------------------------------------
-- MAIN GAME LOOP
--------------------------------------------------------------
local function runGame()
	PillarManager.Init()

	while true do
		-- Reset water
		waterPart.Position = Vector3.new(0, GameConfig.WATER_START_Y, 0)
		if colorFrame then
			colorFrame.BackgroundColor3 = Color3.fromRGB(30, 30, 30)
		end
		if screenTimer then screenTimer.Text = "" end
		if screenRound then screenRound.Text = "Waiting for players..." end

		-- ── LOBBY: Wait for enough players ──
		repeat
			task.wait(2)
		until #Players:GetPlayers() >= GameConfig.MIN_PLAYERS

		-- Lobby countdown
		for t = GameConfig.LOBBY_WAIT, 1, -1 do
			if screenTimer then screenTimer.Text = tostring(t) end
			if screenRound then screenRound.Text = "Game starting soon..." end
			for _, p in ipairs(Players:GetPlayers()) do
				LobbyTimer:FireClient(p, t)
			end
			task.wait(1)
		end
		if screenTimer then screenTimer.Text = "" end

		-- ── SPAWN PILLARS ──
		local playersInGame = Players:GetPlayers()
		PillarManager.SpawnPillars(playersInGame)
		task.wait(3)

		-- ── PLAY ROUNDS ──
		local round = 0
		local remaining = #playersInGame

		while round < GameConfig.MAX_ROUNDS and remaining > 1 do
			round += 1
			local alivePlayers = PillarManager.GetActivePlayers()
			remaining = playRound(round, alivePlayers)
		end

		-- ── GAME OVER ──
		local winners = PillarManager.GetActivePlayers()
		local winnerName = "Nobody"
		if #winners > 0 then
			winnerName = winners[1].DisplayName
			if #winners > 1 then
				winnerName = winnerName .. " + " .. (#winners - 1) .. " others"
			end
		end

		for _, player in ipairs(Players:GetPlayers()) do
			GameOverEvent:FireClient(player, winnerName)
		end

		if screenRound then screenRound.Text = winnerName .. " WINS!" end
		if screenTimer then screenTimer.Text = "🏆" end

		task.wait(10)

		-- Cleanup for next round
		PillarManager.ClearAll()
		setWaterLevel(GameConfig.WATER_START_Y, 2)
		task.wait(5)
	end
end

runGame()
```

---

### File 4 — `src/client/ColorGameClient.client.luau`

```lua
--!strict
-- ColorGameClient (LocalScript in StarterPlayerScripts)
-- Handles the slider UI, color preview, and communicates guesses to the server

local Players = game:GetService("Players")
local UserInputService = game:GetService("UserInputService")
local TweenService = game:GetService("TweenService")
local ReplicatedStorage = game:GetService("ReplicatedStorage")

local player = Players.LocalPlayer
local playerGui = player:WaitForChild("PlayerGui")

local Events = ReplicatedStorage:WaitForChild("Events")
local ShowColor       = Events:WaitForChild("ShowColor") :: RemoteEvent
local StartGuessing   = Events:WaitForChild("StartGuessing") :: RemoteEvent
local SubmitGuessEvt  = Events:WaitForChild("SubmitGuess") :: RemoteEvent
local RoundResult     = Events:WaitForChild("RoundResult") :: RemoteEvent
local PlayerElim      = Events:WaitForChild("PlayerEliminated") :: RemoteEvent
local GameOverEvt     = Events:WaitForChild("GameOver") :: RemoteEvent
local LobbyTimerEvt   = Events:WaitForChild("LobbyTimer") :: RemoteEvent

--------------------------------------------------------------
-- BUILD THE ENTIRE GUI FROM CODE (no Studio GUI needed)
--------------------------------------------------------------
local screenGui = Instance.new("ScreenGui")
screenGui.Name = "ColorGameGui"
screenGui.ResetOnSpawn = false
screenGui.ZIndexBehavior = Enum.ZIndexBehavior.Sibling
screenGui.Parent = playerGui

-- Main card background
local card = Instance.new("Frame")
card.Name = "Card"
card.Size = UDim2.new(0, 500, 0, 380)
card.Position = UDim2.new(0.5, -250, 0.5, -190)
card.BackgroundColor3 = Color3.fromRGB(160, 60, 200)
card.BorderSizePixel = 0
card.Visible = false
card.Parent = screenGui

local cardCorner = Instance.new("UICorner")
cardCorner.CornerRadius = UDim.new(0, 20)
cardCorner.Parent = card

local cardStroke = Instance.new("UIStroke")
cardStroke.Color = Color3.fromRGB(130, 40, 170)
cardStroke.Thickness = 3
cardStroke.Parent = card

-- Round label (top left)
local roundLabel = Instance.new("TextLabel")
roundLabel.Name = "RoundLabel"
roundLabel.Size = UDim2.new(0, 60, 0, 30)
roundLabel.Position = UDim2.new(0, 20, 0, 15)
roundLabel.BackgroundColor3 = Color3.fromRGB(140, 50, 180)
roundLabel.Text = "1/10"
roundLabel.TextColor3 = Color3.new(1, 1, 1)
roundLabel.TextSize = 16
roundLabel.Font = Enum.Font.GothamBold
roundLabel.BorderSizePixel = 0
roundLabel.Parent = card
Instance.new("UICorner", roundLabel).CornerRadius = UDim.new(0, 12)

-- Instruction label
local instructionLabel = Instance.new("TextLabel")
instructionLabel.Name = "Instruction"
instructionLabel.Size = UDim2.new(0, 350, 0, 40)
instructionLabel.Position = UDim2.new(0, 120, 0, 50)
instructionLabel.BackgroundTransparency = 1
instructionLabel.Text = "Memorize this color!"
instructionLabel.TextColor3 = Color3.new(1, 1, 1)
instructionLabel.TextSize = 20
instructionLabel.Font = Enum.Font.GothamMedium
instructionLabel.TextXAlignment = Enum.TextXAlignment.Left
instructionLabel.TextWrapped = true
instructionLabel.Parent = card

-- Timer label (big number)
local timerLabel = Instance.new("TextLabel")
timerLabel.Name = "Timer"
timerLabel.Size = UDim2.new(0, 80, 0, 60)
timerLabel.Position = UDim2.new(1, -90, 0, 10)
timerLabel.BackgroundTransparency = 1
timerLabel.Text = ""
timerLabel.TextColor3 = Color3.new(1, 1, 1)
timerLabel.TextSize = 48
timerLabel.Font = Enum.Font.GothamBold
timerLabel.Parent = card

-- Target color display (big square)
local colorDisplay = Instance.new("Frame")
colorDisplay.Name = "ColorDisplay"
colorDisplay.Size = UDim2.new(0, 160, 0, 160)
colorDisplay.Position = UDim2.new(0, 170, 0, 110)
colorDisplay.BackgroundColor3 = Color3.new(1, 1, 1)
colorDisplay.BorderSizePixel = 0
colorDisplay.Visible = false
colorDisplay.Parent = card
Instance.new("UICorner", colorDisplay).CornerRadius = UDim.new(0, 16)

-- Player guess color display (smaller square)
local playerColorDisplay = Instance.new("Frame")
playerColorDisplay.Name = "PlayerColor"
playerColorDisplay.Size = UDim2.new(0, 100, 0, 100)
playerColorDisplay.Position = UDim2.new(0, 360, 0, 140)
playerColorDisplay.BackgroundColor3 = Color3.fromHSV(0.5, 0.5, 0.5)
playerColorDisplay.BorderSizePixel = 0
playerColorDisplay.Visible = false
playerColorDisplay.Parent = card
Instance.new("UICorner", playerColorDisplay).CornerRadius = UDim.new(0, 12)

-- Score label
local scoreLabel = Instance.new("TextLabel")
scoreLabel.Name = "Score"
scoreLabel.Size = UDim2.new(0, 200, 0, 40)
scoreLabel.Position = UDim2.new(0, 170, 0, 290)
scoreLabel.BackgroundTransparency = 1
scoreLabel.Text = ""
scoreLabel.TextColor3 = Color3.new(1, 1, 1)
scoreLabel.TextSize = 28
scoreLabel.Font = Enum.Font.GothamBold
scoreLabel.Parent = card

-- Submit button
local submitButton = Instance.new("TextButton")
submitButton.Name = "SubmitBtn"
submitButton.Size = UDim2.new(0, 80, 0, 36)
submitButton.Position = UDim2.new(1, -100, 1, -50)
submitButton.BackgroundColor3 = Color3.fromRGB(245, 240, 235)
submitButton.Text = "OK"
submitButton.TextColor3 = Color3.fromRGB(30, 30, 30)
submitButton.TextSize = 18
submitButton.Font = Enum.Font.GothamBold
submitButton.BorderSizePixel = 0
submitButton.Visible = false
submitButton.Parent = card
Instance.new("UICorner", submitButton).CornerRadius = UDim.new(0, 18)

--------------------------------------------------------------
-- BUILD SLIDERS (Hue, Sat, Brightness)
--------------------------------------------------------------
local sliderValues = { hue = 0.5, sat = 0.5, bri = 0.5 }
local sliderFrames: { [string]: { frame: Frame, track: Frame, knob: TextButton } } = {}

local sliderDefs = {
	{ key = "hue", x = 20,  label = "H" },
	{ key = "sat", x = 55,  label = "S" },
	{ key = "bri", x = 90,  label = "B" },
}

for _, def in ipairs(sliderDefs) do
	local frame = Instance.new("Frame")
	frame.Name = def.key .. "Slider"
	frame.Size = UDim2.new(0, 24, 0, 240)
	frame.Position = UDim2.new(0, def.x, 0, 100)
	frame.BackgroundTransparency = 1
	frame.Visible = false
	frame.Parent = card

	-- Label above slider
	local label = Instance.new("TextLabel")
	label.Size = UDim2.new(1, 0, 0, 16)
	label.Position = UDim2.new(0, 0, 0, -18)
	label.BackgroundTransparency = 1
	label.Text = def.label
	label.TextColor3 = Color3.new(1, 1, 1)
	label.TextSize = 12
	label.Font = Enum.Font.GothamBold
	label.Parent = frame

	local track = Instance.new("Frame")
	track.Name = "Track"
	track.Size = UDim2.new(1, 0, 1, 0)
	track.BackgroundColor3 = Color3.fromRGB(60, 60, 60)
	track.BorderSizePixel = 0
	track.Parent = frame
	Instance.new("UICorner", track).CornerRadius = UDim.new(0, 12)

	local knob = Instance.new("TextButton")
	knob.Name = "Knob"
	knob.Size = UDim2.new(0, 32, 0, 14)
	knob.Position = UDim2.new(0.5, -16, 0.5, -7)
	knob.BackgroundColor3 = Color3.new(1, 1, 1)
	knob.Text = ""
	knob.BorderSizePixel = 0
	knob.ZIndex = 5
	knob.Parent = frame
	Instance.new("UICorner", knob).CornerRadius = UDim.new(0, 7)

	local knobStroke = Instance.new("UIStroke")
	knobStroke.Color = Color3.fromRGB(180, 180, 180)
	knobStroke.Thickness = 1
	knobStroke.Parent = knob

	sliderFrames[def.key] = { frame = frame, track = track, knob = knob }
end

--------------------------------------------------------------
-- GRADIENT MANAGEMENT
--------------------------------------------------------------
local function clearGradients(parent: Instance)
	for _, child in parent:GetChildren() do
		if child:IsA("UIGradient") then child:Destroy() end
	end
end

local function setupHueGradient()
	local track = sliderFrames.hue.track
	clearGradients(track)
	local grad = Instance.new("UIGradient")
	grad.Rotation = 90
	local keypoints = {}
	for i = 0, 12 do
		local t = i / 12
		table.insert(keypoints, ColorSequenceKeypoint.new(t, Color3.fromHSV(t, 1, 1)))
	end
	grad.Color = ColorSequence.new(keypoints)
	grad.Parent = track
end

local function updateSatBriGradients()
	local h = sliderValues.hue

	-- Saturation: white → full color
	local satTrack = sliderFrames.sat.track
	clearGradients(satTrack)
	local sg = Instance.new("UIGradient")
	sg.Rotation = 90
	sg.Color = ColorSequence.new({
		ColorSequenceKeypoint.new(0, Color3.fromHSV(h, 0, 1)),
		ColorSequenceKeypoint.new(1, Color3.fromHSV(h, 1, 1)),
	})
	sg.Parent = satTrack

	-- Brightness: black → full color
	local briTrack = sliderFrames.bri.track
	clearGradients(briTrack)
	local bg = Instance.new("UIGradient")
	bg.Rotation = 90
	bg.Color = ColorSequence.new({
		ColorSequenceKeypoint.new(0, Color3.fromHSV(h, sliderValues.sat, 0)),
		ColorSequenceKeypoint.new(1, Color3.fromHSV(h, sliderValues.sat, 1)),
	})
	bg.Parent = briTrack
end

--------------------------------------------------------------
-- UPDATE PLAYER COLOR PREVIEW
--------------------------------------------------------------
local function updatePlayerColor()
	playerColorDisplay.BackgroundColor3 = Color3.fromHSV(
		sliderValues.hue % 1,
		math.clamp(sliderValues.sat, 0, 1),
		math.clamp(sliderValues.bri, 0, 1)
	)
end

--------------------------------------------------------------
-- SLIDER DRAG LOGIC
--------------------------------------------------------------
local function setupSliderDrag(key: string, onChanged: () -> ())
	local data = sliderFrames[key]
	local track = data.track
	local knob = data.knob
	local dragging = false

	local function updateFromY(inputY: number)
		local tPos = track.AbsolutePosition.Y
		local tSize = track.AbsoluteSize.Y
		local rel = math.clamp((inputY - tPos) / tSize, 0, 1)
		sliderValues[key] = rel
		knob.Position = UDim2.new(0.5, -16, rel, -7)
		onChanged()
	end

	knob.InputBegan:Connect(function(input)
		if input.UserInputType == Enum.UserInputType.MouseButton1
			or input.UserInputType == Enum.UserInputType.Touch then
			dragging = true
		end
	end)

	track.InputBegan:Connect(function(input)
		if input.UserInputType == Enum.UserInputType.MouseButton1
			or input.UserInputType == Enum.UserInputType.Touch then
			dragging = true
			updateFromY(input.Position.Y)
		end
	end)

	UserInputService.InputChanged:Connect(function(input)
		if dragging and (input.UserInputType == Enum.UserInputType.MouseMovement
			or input.UserInputType == Enum.UserInputType.Touch) then
			updateFromY(input.Position.Y)
		end
	end)

	UserInputService.InputEnded:Connect(function(input)
		if input.UserInputType == Enum.UserInputType.MouseButton1
			or input.UserInputType == Enum.UserInputType.Touch then
			dragging = false
		end
	end)
end

--------------------------------------------------------------
-- INITIALIZE SLIDERS
--------------------------------------------------------------
setupHueGradient()

setupSliderDrag("hue", function()
	updatePlayerColor()
	updateSatBriGradients()
end)

setupSliderDrag("sat", function()
	updatePlayerColor()
	updateSatBriGradients()
end)

setupSliderDrag("bri", function()
	updatePlayerColor()
end)

--------------------------------------------------------------
-- SHOW / HIDE HELPERS
--------------------------------------------------------------
local function setSlidersVisible(visible: boolean)
	for _, data in pairs(sliderFrames) do
		data.frame.Visible = visible
	end
	submitButton.Visible = visible
	playerColorDisplay.Visible = visible
end

local function resetSliders()
	sliderValues.hue = 0.5
	sliderValues.sat = 0.5
	sliderValues.bri = 0.5
	for _, data in pairs(sliderFrames) do
		data.knob.Position = UDim2.new(0.5, -16, 0.5, -7)
	end
	updatePlayerColor()
	updateSatBriGradients()
end

--------------------------------------------------------------
-- SUBMIT
--------------------------------------------------------------
local hasSubmitted = false

submitButton.MouseButton1Click:Connect(function()
	if hasSubmitted then return end
	hasSubmitted = true
	SubmitGuessEvt:FireServer(sliderValues.hue, sliderValues.sat, sliderValues.bri)
	submitButton.Text = "Sent!"
	submitButton.BackgroundColor3 = Color3.fromRGB(100, 220, 100)
end)

--------------------------------------------------------------
-- EVENT: Show Color (memorize phase)
--------------------------------------------------------------
ShowColor.OnClientEvent:Connect(function(h: number, s: number, v: number, roundNum: number, maxRounds: number)
	card.Visible = true
	hasSubmitted = false
	submitButton.Text = "OK"
	submitButton.BackgroundColor3 = Color3.fromRGB(245, 240, 235)

	roundLabel.Text = roundNum .. "/" .. maxRounds
	scoreLabel.Text = ""
	instructionLabel.Text = "Memorize this color!"

	colorDisplay.Visible = true
	colorDisplay.BackgroundColor3 = Color3.fromHSV(h, s, v)
	setSlidersVisible(false)

	-- Client-side countdown display
	for t = 5, 1, -1 do
		timerLabel.Text = tostring(t)
		task.wait(1)
	end
	timerLabel.Text = ""
	colorDisplay.Visible = false
end)

--------------------------------------------------------------
-- EVENT: Start Guessing
--------------------------------------------------------------
StartGuessing.OnClientEvent:Connect(function(guessTime: number)
	instructionLabel.Text = "Recreate the color!"
	setSlidersVisible(true)
	resetSliders()

	-- Guess countdown
	for t = guessTime, 1, -1 do
		timerLabel.Text = tostring(t)
		task.wait(1)
		if hasSubmitted then break end
	end
	timerLabel.Text = ""

	-- Auto-submit if they didn't press OK
	if not hasSubmitted then
		hasSubmitted = true
		SubmitGuessEvt:FireServer(sliderValues.hue, sliderValues.sat, sliderValues.bri)
	end
end)

--------------------------------------------------------------
-- EVENT: Round Result
--------------------------------------------------------------
RoundResult.OnClientEvent:Connect(function(score: number, tH: number, tS: number, tV: number)
	setSlidersVisible(false)

	-- Show both colors for comparison
	colorDisplay.Visible = true
	colorDisplay.BackgroundColor3 = Color3.fromHSV(tH, tS, tV)
	playerColorDisplay.Visible = true

	instructionLabel.Text = "Your guess vs the original"
	scoreLabel.Text = "Score: " .. score .. "/10"

	if score >= 8 then
		scoreLabel.TextColor3 = Color3.fromRGB(50, 255, 50)
	elseif score >= 5 then
		scoreLabel.TextColor3 = Color3.fromRGB(255, 255, 50)
	else
		scoreLabel.TextColor3 = Color3.fromRGB(255, 80, 80)
	end

	task.wait(3)
	card.Visible = false
end)

--------------------------------------------------------------
-- EVENT: Player Eliminated
--------------------------------------------------------------
PlayerElim.OnClientEvent:Connect(function(eliminatedName: string)
	if eliminatedName then
		card.Visible = true
		setSlidersVisible(false)
		colorDisplay.Visible = false
		playerColorDisplay.Visible = false
		scoreLabel.Text = ""
		instructionLabel.Text = "💀 " .. eliminatedName .. " was eliminated!"

		if eliminatedName == player.DisplayName then
			instructionLabel.Text = "💀 You were eliminated!"
			card.BackgroundColor3 = Color3.fromRGB(80, 30, 30)
		end

		task.wait(2.5)
		card.Visible = false
		card.BackgroundColor3 = Color3.fromRGB(160, 60, 200) -- reset color
	end
end)

--------------------------------------------------------------
-- EVENT: Game Over
--------------------------------------------------------------
GameOverEvt.OnClientEvent:Connect(function(winnerName: string)
	card.Visible = true
	setSlidersVisible(false)
	colorDisplay.Visible = false
	playerColorDisplay.Visible = false

	card.BackgroundColor3 = Color3.fromRGB(40, 40, 60)
	instructionLabel.Text = "GAME OVER"
	scoreLabel.Text = "🏆 " .. winnerName .. " WINS!"
	scoreLabel.TextColor3 = Color3.fromRGB(255, 215, 0)
	timerLabel.Text = ""
end)

--------------------------------------------------------------
-- EVENT: Lobby Timer
--------------------------------------------------------------
LobbyTimerEvt.OnClientEvent:Connect(function(t: number)
	card.Visible = true
	card.BackgroundColor3 = Color3.fromRGB(40, 40, 60)
	setSlidersVisible(false)
	colorDisplay.Visible = false
	playerColorDisplay.Visible = false
	scoreLabel.Text = ""
	instructionLabel.Text = "Game starting in " .. t .. "..."
	timerLabel.Text = tostring(t)

	if t <= 1 then
		task.wait(1.5)
		card.BackgroundColor3 = Color3.fromRGB(160, 60, 200)
		card.Visible = false
	end
end)
```

---

## PHASE 4: BUILD THE ARENA IN STUDIO

You need to build these parts **manually in Roblox Studio** because they're 3D objects (Rojo handles code, Studio handles the physical world).

### 4A — Connect Rojo

1. Open a terminal in your project folder:
   ```bash
   rojo serve
   ```
2. Open Roblox Studio, create a **new Baseplate** place
3. Click the **Rojo plugin** → **Connect**
4. You should see your scripts appear in the Explorer under ServerScriptService, StarterPlayerScripts, and ReplicatedStorage

### 4B — Build the Arena Folder

1. In Explorer, inside `Workspace`, create a **Folder** named `Arena`

### 4C — Build the Water

1. Inside `Arena`, create a **Part** named `WaterPart`
2. Properties:
   - **Size** = `512, 2, 512`
   - **Position** = `0, -10, 0`
   - **Anchored** = ✅
   - **CanCollide** = false
   - **Material** = Water
   - **Color** = `(0, 120, 210)`
   - **Transparency** = 0.3

### 4D — Build the Color Screen

1. Inside `Arena`, create a **Part** named `ColorScreen`
2. Properties:
   - **Size** = `50, 30, 2`
   - **Position** = `0, 55, -90`
   - **Anchored** = ✅
   - **Color** = `(20, 20, 20)`
   - **Material** = SmoothPlastic

3. Add a **SurfaceGui** child (set **Face** = Front):

   Inside the SurfaceGui, add:

   | Object      | Name         | Size               | Position            | Properties                                           |
   |-------------|--------------|---------------------|---------------------|------------------------------------------------------|
   | **Frame**   | `ColorFrame` | `{0.85,0,0.7,0}`   | `{0.075,0,0.05,0}`  | BackgroundColor3 = `(30,30,30)`, UICorner radius 24  |
   | **TextLabel** | `TimerText`  | `{0.3,0,0.15,0}`   | `{0.35,0,0.75,0}`   | TextScaled=true, TextColor3=white, BgTransparency=1  |
   | **TextLabel** | `RoundText`  | `{0.8,0,0.1,0}`    | `{0.1,0,0.02,0}`    | TextScaled=true, TextColor3=white, BgTransparency=1  |

### 4E — Build the Pillars Folder

1. Inside `Arena`, create a **Folder** named `Pillars` (the script auto-creates pillars here)

### 4F — Optional: Spectator Platform

1. Add a transparent platform at `Position = 0, 115, -80` for eliminated players to stand on

### 4G — Save the Place

1. **File → Save to File** as `game.rbxl` in your project folder
2. Add `*.rbxl` to your `.gitignore` (already done)

> **Important:** Every time you open this project, you'll open `game.rbxl` in Studio, then connect Rojo. The arena stays in the `.rbxl` file, the code syncs from your files.

---

## PHASE 5: PUBLISH TO GITHUB

### 5A — First Commit

```bash
git add .
git commit -m "initial color pillar game with Rojo"
```

### 5B — Create GitHub Repo

1. Go to https://github.com/new
2. Create a repo called `color-pillar-game`
3. **Don't** add a README (you already have files)

```bash
git remote add origin https://github.com/YOUR_USERNAME/color-pillar-game.git
git branch -M main
git push -u origin main
```

### 5C — Add Your Friend

1. On GitHub, go to your repo → **Settings → Collaborators**
2. Click **Add people** → enter your friend's GitHub username
3. They accept the invite, then clone:

```bash
git clone https://github.com/YOUR_USERNAME/color-pillar-game.git
cd color-pillar-game
```

### 5D — Share the Place File

Since `game.rbxl` is in `.gitignore` (it's binary, bad for Git), share it with your friend via:
- **Publish the game to Roblox** (privately) and both edit from there
- Or send the `.rbxl` file via Discord / Google Drive once as a starting point

---

## PHASE 6: DAILY WORKFLOW

### Working on Features

```bash
# Pull latest code
git pull

# Create a branch for your feature
git checkout -b add-splash-effects

# Edit files in VS Code...
# When done:
git add .
git commit -m "add splash effect on elimination"
git push -u origin add-splash-effects

# Go to GitHub → open a Pull Request
# Your friend reviews → Merge
```

### Testing

1. Open terminal: `rojo serve`
2. Open `game.rbxl` in Studio
3. Connect Rojo plugin
4. Press **F5** to play-test (set `MIN_PLAYERS = 1` in GameConfig for solo testing)
5. For multiplayer: use **Test → Start** with 2+ local clients

### Your Friend's Workflow (Identical)

```bash
git pull
git checkout -b improve-slider-ui
# edit, commit, push, pull request
```

---

## PHASE 7: TUNING CHEAT SHEET

All tuning is in `src/shared/GameConfig.luau` — one file, both sides read it:

| Setting               | Default | What to tweak                             |
|------------------------|---------|-------------------------------------------|
| `MIN_PLAYERS`          | 2       | Set to 1 for solo testing                 |
| `MAX_ROUNDS`           | 10      | Shorter = faster games                    |
| `MEMORIZE_TIME`        | 5       | Harder = lower this                       |
| `GUESS_TIME`           | 15      | Pressure = lower this                     |
| `WATER_RISE_PER_ROUND` | 6       | Higher = more eliminations                |
| `STUDS_PER_SCORE_POINT`| 2       | Higher = bigger reward for good guesses   |
| `BASE_PILLAR_HEIGHT`   | 40      | Starting safety margin                    |
| `HUE_WEIGHT`           | 0.50    | How much hue matters for scoring          |

---

## TROUBLESHOOTING

| Problem | Fix |
|---------|-----|
| Rojo won't connect | Make sure `rojo serve` is running and the plugin is installed in Studio |
| Scripts don't appear | Check `default.project.json` paths match your folder names exactly |
| "Arena not found" error | You haven't built the Arena folder + WaterPart + ColorScreen in Studio yet |
| Friend can't see code changes | They need to `git pull`, then `rojo serve` + connect in their own Studio |
| Water doesn't move | Verify `WaterPart` is **Anchored** and named exactly `WaterPart` inside `Arena` |
| Sliders don't drag | Make sure the client script loaded — check Output for errors |
| Testing alone | Set `MIN_PLAYERS = 1` in GameConfig.luau |
