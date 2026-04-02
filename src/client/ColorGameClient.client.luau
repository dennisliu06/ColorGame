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
	track.BackgroundColor3 = Color3.new(1, 1, 1)
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
