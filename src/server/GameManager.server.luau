--!strict
-- GameManager (Script in ServerScriptService)
-- Main server game loop: lobby → rounds → elimination → winner

print("GameManager loaded!")
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
local DebugEliminate   = makeRemote("DebugEliminate")

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

		-- Move eliminated player to spectate position and restore movement
		local char = player.Character
		if char then
			local hrp = char:FindFirstChild("HumanoidRootPart") :: BasePart
			if hrp then
				hrp.CFrame = CFrame.new(0, 120, -80)
			end
			local hum = char:FindFirstChildOfClass("Humanoid") :: Humanoid
			if hum then
				hum.WalkSpeed = 16
				hum.JumpPower = 50
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

--------------------------------------------------------------
-- DEBUG: Self-Eliminate (testing only)
--------------------------------------------------------------
DebugEliminate.OnServerEvent:Connect(function(player: Player)
	if not table.find(PillarManager.GetActivePlayers(), player) then return end
	PillarManager.RemovePillar(player)
	for _, p in ipairs(Players:GetPlayers()) do
		PlayerEliminated:FireClient(p, player.DisplayName)
	end
	local char = player.Character
	if char then
		local hrp = char:FindFirstChild("HumanoidRootPart") :: BasePart
		if hrp then hrp.CFrame = CFrame.new(0, 120, -80) end
		local hum = char:FindFirstChildOfClass("Humanoid") :: Humanoid
		if hum then
			hum.WalkSpeed = 16
			hum.JumpPower = 50
		end
	end
end)

runGame()
