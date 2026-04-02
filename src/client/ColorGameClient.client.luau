--!strict
-- ColorGameClient (LocalScript in StarterPlayerScripts)
-- Handles the slider UI, color preview, and communicates guesses to the server

local Players = game:GetService("Players")
local UserInputService = game:GetService("UserInputService")
local TweenService = game:GetService("TweenService")
local ReplicatedStorage = game:GetService("ReplicatedStorage")

local player = Players.LocalPlayer
local playerGui = player:WaitForChild("PlayerGui")
local colorScreenPart = workspace:WaitForChild("Arena"):WaitForChild("ColorScreen") :: BasePart

local Events = ReplicatedStorage:WaitForChild("Events")
local ShowColor       = Events:WaitForChild("ShowColor") :: RemoteEvent
local StartGuessing   = Events:WaitForChild("StartGuessing") :: RemoteEvent
local SubmitGuessEvt  = Events:WaitForChild("SubmitGuess") :: RemoteEvent
local RoundResult     = Events:WaitForChild("RoundResult") :: RemoteEvent
local PlayerElim      = Events:WaitForChild("PlayerEliminated") :: RemoteEvent
local GameOverEvt     = Events:WaitForChild("GameOver") :: RemoteEvent
local LobbyTimerEvt   = Events:WaitForChild("LobbyTimer") :: RemoteEvent
local DebugElimEvt    = Events:WaitForChild("DebugEliminate") :: RemoteEvent
local BroadcastColorEvt = Events:WaitForChild("BroadcastColor") :: RemoteEvent
local FinalColorEvt     = Events:WaitForChild("FinalColor") :: RemoteEvent
local RoundScoresEvt    = Events:WaitForChild("RoundScores") :: RemoteEvent

--------------------------------------------------------------
-- SCREEN GUI
--------------------------------------------------------------
local screenGui = Instance.new("ScreenGui")
screenGui.Name = "ColorGameGui"
screenGui.ResetOnSpawn = false
screenGui.ZIndexBehavior = Enum.ZIndexBehavior.Sibling
screenGui.Parent = playerGui

--------------------------------------------------------------
-- CARD
--------------------------------------------------------------
local CARD_W, CARD_H = 580, 450
local CARD_REST  = UDim2.new(0.5, -CARD_W / 2, 0.5, -CARD_H / 2)
local CARD_ENTER = UDim2.new(0.5, -CARD_W / 2, 0.62, -CARD_H / 2)

local card = Instance.new("Frame")
card.Name = "Card"
card.Size = UDim2.new(0, CARD_W, 0, CARD_H)
card.Position = CARD_REST
card.BackgroundColor3 = Color3.fromRGB(10, 10, 16)
card.BackgroundTransparency = 0.1
card.BorderSizePixel = 0
card.Visible = false
card.Parent = screenGui
Instance.new("UICorner", card).CornerRadius = UDim.new(0, 24)

-- Subtle top-to-bottom gradient on the card body
local cardGradient = Instance.new("UIGradient")
cardGradient.Rotation = 90
cardGradient.Color = ColorSequence.new({
	ColorSequenceKeypoint.new(0, Color3.fromRGB(28, 28, 44)),
	ColorSequenceKeypoint.new(1, Color3.fromRGB(8, 8, 14)),
})
cardGradient.Parent = card

local cardStroke = Instance.new("UIStroke")
cardStroke.Color = Color3.fromRGB(90, 90, 120)
cardStroke.Thickness = 2
cardStroke.Parent = card

local function showCard()
	card.Position = CARD_ENTER
	card.Visible = true
	TweenService:Create(card, TweenInfo.new(0.35, Enum.EasingStyle.Back, Enum.EasingDirection.Out), {
		Position = CARD_REST,
	}):Play()
end

local function hideCard()
	TweenService:Create(card, TweenInfo.new(0.2, Enum.EasingStyle.Quad, Enum.EasingDirection.In), {
		Position = CARD_ENTER,
	}):Play()
	task.delay(0.22, function()
		card.Visible = false
		card.BackgroundColor3 = Color3.fromRGB(10, 10, 16)
	end)
end

--------------------------------------------------------------
-- TOP ROW
--------------------------------------------------------------
-- Round badge (top-left)
local roundLabel = Instance.new("TextLabel")
roundLabel.Name = "RoundLabel"
roundLabel.Size = UDim2.new(0, 120, 0, 34)
roundLabel.Position = UDim2.new(0, 16, 0, 16)
roundLabel.BackgroundColor3 = Color3.fromRGB(30, 30, 50)
roundLabel.Text = "ROUND 1/10"
roundLabel.TextColor3 = Color3.fromRGB(180, 180, 215)
roundLabel.TextSize = 15
roundLabel.Font = Enum.Font.GothamBold
roundLabel.BorderSizePixel = 0
roundLabel.Parent = card
Instance.new("UICorner", roundLabel).CornerRadius = UDim.new(0, 10)

-- Instruction (left-center, avoids overlapping timer on the right)
local instructionLabel = Instance.new("TextLabel")
instructionLabel.Name = "Instruction"
instructionLabel.Size = UDim2.new(0, 200, 0, 52)
instructionLabel.Position = UDim2.new(0, 138, 0, 8)
instructionLabel.BackgroundTransparency = 1
instructionLabel.Text = "MEMORIZE THE COLOR!"
instructionLabel.TextColor3 = Color3.new(1, 1, 1)
instructionLabel.TextSize = 22
instructionLabel.Font = Enum.Font.GothamBold
instructionLabel.TextXAlignment = Enum.TextXAlignment.Center
instructionLabel.TextWrapped = true
instructionLabel.Parent = card

-- Timer (top-right, huge)
local timerLabel = Instance.new("TextLabel")
timerLabel.Name = "Timer"
timerLabel.Size = UDim2.new(0, 220, 0, 84)
timerLabel.Position = UDim2.new(1, -6, 0, -4)
timerLabel.AnchorPoint = Vector2.new(1, 0)
timerLabel.BackgroundTransparency = 1
timerLabel.Text = ""
timerLabel.TextColor3 = Color3.new(1, 1, 1)
timerLabel.TextScaled = true
timerLabel.Font = Enum.Font.GothamBold
timerLabel.Parent = card

-- UIScale child so pulse works with TextScaled (TextSize is ignored when TextScaled = true)
local timerScale = Instance.new("UIScale")
timerScale.Scale = 1
timerScale.Parent = timerLabel

-- Decimal countdown — updates at 20fps, pulses on whole-second crossings.
-- checkStop: optional callback that returns true to break early.
local function runDecimalCountdown(duration: number, checkStop: (() -> boolean)?)
	local endTime = os.clock() + duration
	local lastWhole = math.ceil(duration) + 1

	while true do
		local remaining = math.max(0, endTime - os.clock())

		if remaining <= 2 then
			timerLabel.TextColor3 = Color3.fromRGB(255, 65, 65)
		elseif remaining <= 4 then
			timerLabel.TextColor3 = Color3.fromRGB(255, 210, 50)
		else
			timerLabel.TextColor3 = Color3.new(1, 1, 1)
		end

		local whole = math.ceil(remaining)
		if whole < lastWhole and whole > 0 then
			lastWhole = whole
			timerScale.Scale = 1.3
			TweenService:Create(timerScale, TweenInfo.new(0.18, Enum.EasingStyle.Quad, Enum.EasingDirection.Out), {
				Scale = 1,
			}):Play()
		end

		timerLabel.Text = string.format("%.2f", remaining)

		if remaining <= 0 then break end
		if checkStop and checkStop() then break end
		task.wait(0.05)
	end

	timerLabel.Text = ""
end

-- Lobby timer is driven by integer server ticks — no decimal needed.
local function pulseTimer(t: number)
	timerLabel.Text = tostring(t)
	if t <= 2 then
		timerLabel.TextColor3 = Color3.fromRGB(255, 65, 65)
	elseif t <= 4 then
		timerLabel.TextColor3 = Color3.fromRGB(255, 210, 50)
	else
		timerLabel.TextColor3 = Color3.new(1, 1, 1)
	end
	timerScale.Scale = 1.3
	TweenService:Create(timerScale, TweenInfo.new(0.18, Enum.EasingStyle.Quad, Enum.EasingDirection.Out), {
		Scale = 1,
	}):Play()
end

--------------------------------------------------------------
-- COLOR DISPLAYS
--------------------------------------------------------------
-- Target color (visible during memorize phase and result)
local colorDisplay = Instance.new("Frame")
colorDisplay.Name = "ColorDisplay"
colorDisplay.Size = UDim2.new(0, 210, 0, 210)
colorDisplay.Position = UDim2.new(0.5, -105, 0, 88) -- centered during memorize
colorDisplay.BackgroundColor3 = Color3.new(1, 1, 1)
colorDisplay.BorderSizePixel = 0
colorDisplay.Visible = false
colorDisplay.Parent = card
Instance.new("UICorner", colorDisplay).CornerRadius = UDim.new(0, 20)
local colorDisplayStroke = Instance.new("UIStroke")
colorDisplayStroke.Color = Color3.fromRGB(255, 255, 255)
colorDisplayStroke.Thickness = 3
colorDisplayStroke.Transparency = 0.55
colorDisplayStroke.Parent = colorDisplay

local targetSubLabel = Instance.new("TextLabel")
targetSubLabel.Size = UDim2.new(1, 0, 0, 24)
targetSubLabel.Position = UDim2.new(0, 0, 1, 10)
targetSubLabel.BackgroundTransparency = 1
targetSubLabel.Text = "TARGET"
targetSubLabel.TextColor3 = Color3.fromRGB(160, 160, 190)
targetSubLabel.TextSize = 15
targetSubLabel.Font = Enum.Font.GothamBold
targetSubLabel.TextXAlignment = Enum.TextXAlignment.Center
targetSubLabel.Parent = colorDisplay

-- Player guess preview (visible during guess phase and result)
local playerColorDisplay = Instance.new("Frame")
playerColorDisplay.Name = "PlayerColor"
playerColorDisplay.Size = UDim2.new(0, 200, 0, 200)
playerColorDisplay.Position = UDim2.new(0, 350, 0, 93)
playerColorDisplay.BackgroundColor3 = Color3.fromHSV(0.5, 0.5, 0.5)
playerColorDisplay.BorderSizePixel = 0
playerColorDisplay.Visible = false
playerColorDisplay.Parent = card
Instance.new("UICorner", playerColorDisplay).CornerRadius = UDim.new(0, 20)
local playerColorStroke = Instance.new("UIStroke")
playerColorStroke.Color = Color3.fromRGB(255, 255, 255)
playerColorStroke.Thickness = 3
playerColorStroke.Transparency = 0.55
playerColorStroke.Parent = playerColorDisplay

local yourGuessSubLabel = Instance.new("TextLabel")
yourGuessSubLabel.Size = UDim2.new(1, 0, 0, 24)
yourGuessSubLabel.Position = UDim2.new(0, 0, 1, 10)
yourGuessSubLabel.BackgroundTransparency = 1
yourGuessSubLabel.Text = "YOUR GUESS"
yourGuessSubLabel.TextColor3 = Color3.fromRGB(160, 160, 190)
yourGuessSubLabel.TextSize = 15
yourGuessSubLabel.Font = Enum.Font.GothamBold
yourGuessSubLabel.TextXAlignment = Enum.TextXAlignment.Center
yourGuessSubLabel.Parent = playerColorDisplay

--------------------------------------------------------------
-- SCORE + RATING
--------------------------------------------------------------
local scoreLabel = Instance.new("TextLabel")
scoreLabel.Name = "Score"
scoreLabel.Size = UDim2.new(0, 360, 0, 62)
scoreLabel.Position = UDim2.new(0.5, -180, 1, -80)
scoreLabel.BackgroundTransparency = 1
scoreLabel.Text = ""
scoreLabel.TextColor3 = Color3.new(1, 1, 1)
scoreLabel.TextSize = 52
scoreLabel.Font = Enum.Font.GothamBold
scoreLabel.TextXAlignment = Enum.TextXAlignment.Center
scoreLabel.Parent = card

local ratingLabel = Instance.new("TextLabel")
ratingLabel.Name = "Rating"
ratingLabel.Size = UDim2.new(0, 360, 0, 30)
ratingLabel.Position = UDim2.new(0.5, -180, 1, -26)
ratingLabel.BackgroundTransparency = 1
ratingLabel.Text = ""
ratingLabel.TextColor3 = Color3.fromRGB(200, 200, 200)
ratingLabel.TextSize = 22
ratingLabel.Font = Enum.Font.GothamMedium
ratingLabel.TextXAlignment = Enum.TextXAlignment.Center
ratingLabel.Parent = card

--------------------------------------------------------------
-- SUBMIT BUTTON
--------------------------------------------------------------
local submitButton = Instance.new("TextButton")
submitButton.Name = "SubmitBtn"
submitButton.Size = UDim2.new(0, 180, 0, 52)
submitButton.Position = UDim2.new(0.5, -90, 1, -66)
submitButton.BackgroundColor3 = Color3.fromRGB(255, 255, 255)
submitButton.Text = "SUBMIT"
submitButton.TextColor3 = Color3.fromRGB(10, 10, 16)
submitButton.TextSize = 22
submitButton.Font = Enum.Font.GothamBold
submitButton.BorderSizePixel = 0
submitButton.Visible = false
submitButton.Parent = card
Instance.new("UICorner", submitButton).CornerRadius = UDim.new(0, 26)

submitButton.MouseEnter:Connect(function()
	TweenService:Create(submitButton, TweenInfo.new(0.12), {
		BackgroundColor3 = Color3.fromRGB(215, 215, 215),
	}):Play()
end)
submitButton.MouseLeave:Connect(function()
	TweenService:Create(submitButton, TweenInfo.new(0.12), {
		BackgroundColor3 = Color3.fromRGB(255, 255, 255),
	}):Play()
end)

--------------------------------------------------------------
-- SLIDERS (Hue, Sat, Brightness)
--------------------------------------------------------------
local sliderValues = { hue = 0.5, sat = 0.5, bri = 0.5 }
local sliderFrames: { [string]: { frame: Frame, track: Frame, knob: TextButton } } = {}

local sliderDefs = {
	{ key = "hue", x = 22,  label = "HUE" },
	{ key = "sat", x = 106, label = "SAT" },
	{ key = "bri", x = 190, label = "BRI" },
}

for _, def in ipairs(sliderDefs) do
	local frame = Instance.new("Frame")
	frame.Name = def.key .. "Slider"
	frame.Size = UDim2.new(0, 60, 0, 250)
	frame.Position = UDim2.new(0, def.x, 0, 95)
	frame.BackgroundTransparency = 1
	frame.Visible = false
	frame.Parent = card

	-- Label above
	local label = Instance.new("TextLabel")
	label.Size = UDim2.new(2, 0, 0, 26)
	label.Position = UDim2.new(-0.5, 0, 0, -30)
	label.BackgroundTransparency = 1
	label.Text = def.label
	label.TextColor3 = Color3.fromRGB(200, 200, 230)
	label.TextSize = 18
	label.Font = Enum.Font.GothamBold
	label.TextXAlignment = Enum.TextXAlignment.Center
	label.Parent = frame

	local track = Instance.new("Frame")
	track.Name = "Track"
	track.Size = UDim2.new(1, 0, 1, 0)
	track.BackgroundColor3 = Color3.new(1, 1, 1)
	track.BorderSizePixel = 0
	track.Parent = frame
	Instance.new("UICorner", track).CornerRadius = UDim.new(0.5, 0)

	local knob = Instance.new("TextButton")
	knob.Name = "Knob"
	knob.Size = UDim2.new(0, 70, 0, 22)
	knob.Position = UDim2.new(0.5, -35, 0.5, -11)
	knob.BackgroundColor3 = Color3.new(1, 1, 1)
	knob.Text = ""
	knob.BorderSizePixel = 0
	knob.ZIndex = 5
	knob.Parent = frame
	Instance.new("UICorner", knob).CornerRadius = UDim.new(0, 11)

	local knobStroke = Instance.new("UIStroke")
	knobStroke.Color = Color3.fromRGB(190, 190, 205)
	knobStroke.Thickness = 2
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

	local satTrack = sliderFrames.sat.track
	clearGradients(satTrack)
	local sg = Instance.new("UIGradient")
	sg.Rotation = 90
	sg.Color = ColorSequence.new({
		ColorSequenceKeypoint.new(0, Color3.fromHSV(h, 0, 1)),
		ColorSequenceKeypoint.new(1, Color3.fromHSV(h, 1, 1)),
	})
	sg.Parent = satTrack

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
-- COLOR PREVIEW
--------------------------------------------------------------
local lastBroadcastTime = 0

local function updatePlayerColor()
	playerColorDisplay.BackgroundColor3 = Color3.fromHSV(
		sliderValues.hue % 1,
		math.clamp(sliderValues.sat, 0, 1),
		math.clamp(sliderValues.bri, 0, 1)
	)
	local now = tick()
	if now - lastBroadcastTime >= 0.1 then
		lastBroadcastTime = now
		BroadcastColorEvt:FireServer(
			sliderValues.hue % 1,
			math.clamp(sliderValues.sat, 0, 1),
			math.clamp(sliderValues.bri, 0, 1)
		)
	end
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
		knob.Position = UDim2.new(0.5, -35, rel, -11)
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
			if dragging then
				FinalColorEvt:FireServer(
					sliderValues.hue % 1,
					math.clamp(sliderValues.sat, 0, 1),
					math.clamp(sliderValues.bri, 0, 1)
				)
			end
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
end

local function resetSliders()
	sliderValues.hue = 0.5
	sliderValues.sat = 0.5
	sliderValues.bri = 0.5
	for _, data in pairs(sliderFrames) do
		data.knob.Position = UDim2.new(0.5, -35, 0.5, -11)
	end
	updatePlayerColor()
	updateSatBriGradients()
end

--------------------------------------------------------------
-- SUBMITTED COLOR PANEL (shown after submit while waiting for results)
--------------------------------------------------------------
local submittedPanel = Instance.new("Frame")
submittedPanel.Name = "SubmittedPanel"
submittedPanel.Size = UDim2.new(0, 390, 0, 90)
submittedPanel.Position = UDim2.new(0.5, -195, 1, -96)
submittedPanel.BackgroundColor3 = Color3.fromRGB(18, 18, 30)
submittedPanel.BackgroundTransparency = 0.08
submittedPanel.BorderSizePixel = 0
submittedPanel.Visible = false
submittedPanel.Parent = screenGui
Instance.new("UICorner", submittedPanel).CornerRadius = UDim.new(0, 18)
local submittedStroke = Instance.new("UIStroke")
submittedStroke.Color = Color3.fromRGB(90, 90, 120)
submittedStroke.Thickness = 1.5
submittedStroke.Parent = submittedPanel

local yourColorLabel = Instance.new("TextLabel")
yourColorLabel.Size = UDim2.new(0, 130, 1, 0)
yourColorLabel.Position = UDim2.new(0, 18, 0, 0)
yourColorLabel.BackgroundTransparency = 1
yourColorLabel.Text = "YOUR COLOR:"
yourColorLabel.TextColor3 = Color3.fromRGB(160, 160, 200)
yourColorLabel.TextSize = 15
yourColorLabel.Font = Enum.Font.GothamBold
yourColorLabel.TextXAlignment = Enum.TextXAlignment.Left
yourColorLabel.TextYAlignment = Enum.TextYAlignment.Center
yourColorLabel.Parent = submittedPanel

local submittedSwatch = Instance.new("Frame")
submittedSwatch.Name = "Swatch"
submittedSwatch.Size = UDim2.new(0, 200, 0, 54)
submittedSwatch.Position = UDim2.new(1, -218, 0.5, -27)
submittedSwatch.BackgroundColor3 = Color3.fromRGB(128, 128, 128)
submittedSwatch.BorderSizePixel = 0
submittedSwatch.Parent = submittedPanel
Instance.new("UICorner", submittedSwatch).CornerRadius = UDim.new(0, 12)
local swatchStroke = Instance.new("UIStroke")
swatchStroke.Color = Color3.fromRGB(200, 200, 230)
swatchStroke.Thickness = 2
swatchStroke.Transparency = 0.45
swatchStroke.Parent = submittedSwatch

local waitingLabel = Instance.new("TextLabel")
waitingLabel.Size = UDim2.new(1, -160, 0, 20)
waitingLabel.Position = UDim2.new(0, 18, 1, -24)
waitingLabel.BackgroundTransparency = 1
waitingLabel.Text = "Waiting for results..."
waitingLabel.TextColor3 = Color3.fromRGB(100, 100, 130)
waitingLabel.TextSize = 13
waitingLabel.Font = Enum.Font.Gotham
waitingLabel.TextXAlignment = Enum.TextXAlignment.Left
waitingLabel.Parent = submittedPanel

local function showSubmittedPanel()
	submittedSwatch.BackgroundColor3 = Color3.fromHSV(
		sliderValues.hue % 1,
		math.clamp(sliderValues.sat, 0, 1),
		math.clamp(sliderValues.bri, 0, 1)
	)
	-- Slide up from off-screen bottom
	submittedPanel.Position = UDim2.new(0.5, -195, 1, 20)
	submittedPanel.Visible = true
	TweenService:Create(submittedPanel, TweenInfo.new(0.35, Enum.EasingStyle.Back, Enum.EasingDirection.Out), {
		Position = UDim2.new(0.5, -195, 1, -110),
	}):Play()
end

--------------------------------------------------------------
-- SUBMIT
--------------------------------------------------------------
local hasSubmitted = false

-- forward-declared; assigned in their respective sections below
local clearAllBillboards: () -> ()
local showPlayerGrid: () -> ()
local hidePlayerGrid: () -> ()

submitButton.MouseButton1Click:Connect(function()
	if hasSubmitted then return end
	hasSubmitted = true
	SubmitGuessEvt:FireServer(sliderValues.hue, sliderValues.sat, sliderValues.bri)
	setSlidersVisible(false)
	playerColorDisplay.Visible = false
	hideCard()
	showSubmittedPanel()
end)

--------------------------------------------------------------
-- EVENT: Show Color (memorize phase)
--------------------------------------------------------------
ShowColor.OnClientEvent:Connect(function(h: number, s: number, v: number, roundNum: number, maxRounds: number)
	hidePlayerGrid()
	showCard()
	hasSubmitted = false
	submitButton.Text = "SUBMIT"
	submitButton.BackgroundColor3 = Color3.fromRGB(255, 255, 255)
	submitButton.TextColor3 = Color3.fromRGB(10, 10, 16)

	roundLabel.Text = "ROUND " .. roundNum .. "/" .. maxRounds
	scoreLabel.Text = ""
	ratingLabel.Text = ""
	instructionLabel.Text = "MEMORIZE THE COLOR!"
	instructionLabel.TextColor3 = Color3.new(1, 1, 1)

	-- Center colorDisplay for memorize phase
	colorDisplay.Position = UDim2.new(0.5, -105, 0, 88)
	colorDisplay.Size = UDim2.new(0, 210, 0, 210)
	colorDisplay.BackgroundColor3 = Color3.fromHSV(h, s, v)
	colorDisplay.Visible = true
	setSlidersVisible(false)
	playerColorDisplay.Visible = false

	runDecimalCountdown(5)
	colorDisplay.Visible = false
end)

--------------------------------------------------------------
-- EVENT: Start Guessing
--------------------------------------------------------------
StartGuessing.OnClientEvent:Connect(function(guessTime: number)
	clearAllBillboards()
	showPlayerGrid()

	instructionLabel.Text = "RECREATE THE COLOR!"
	instructionLabel.TextColor3 = Color3.fromRGB(255, 240, 100)

	-- Position playerColorDisplay on the right during guess phase
	playerColorDisplay.Size = UDim2.new(0, 200, 0, 200)
	playerColorDisplay.Position = UDim2.new(0, 348, 0, 93)
	playerColorDisplay.Visible = true
	submittedPanel.Visible = false

	setSlidersVisible(true)
	resetSliders()

	runDecimalCountdown(guessTime, function() return hasSubmitted end)

	if not hasSubmitted then
		hasSubmitted = true
		SubmitGuessEvt:FireServer(sliderValues.hue, sliderValues.sat, sliderValues.bri)
		setSlidersVisible(false)
		playerColorDisplay.Visible = false
		hideCard()
		showSubmittedPanel()
	end
end)

--------------------------------------------------------------
-- EVENT: Round Result
--------------------------------------------------------------
RoundResult.OnClientEvent:Connect(function(score: number, tH: number, tS: number, tV: number)
	clearAllBillboards()
	setSlidersVisible(false)
	submittedPanel.Visible = false
	card.BackgroundColor3 = Color3.fromRGB(10, 10, 16)

	showCard()

	-- Side-by-side comparison
	colorDisplay.Size = UDim2.new(0, 200, 0, 200)
	colorDisplay.Position = UDim2.new(0, 40, 0, 93)
	colorDisplay.BackgroundColor3 = Color3.fromHSV(tH, tS, tV)
	colorDisplay.Visible = true

	playerColorDisplay.Size = UDim2.new(0, 200, 0, 200)
	playerColorDisplay.Position = UDim2.new(0, 270, 0, 93)
	playerColorDisplay.Visible = true

	instructionLabel.Text = "YOUR GUESS vs TARGET"
	instructionLabel.TextColor3 = Color3.fromRGB(200, 200, 200)

	-- Score reveal animation
	local scoreText = score .. " / 10"
	local rating, ratingColor: Color3
	if score >= 9 then
		rating = "PERFECT ✨"
		ratingColor = Color3.fromRGB(100, 255, 140)
		scoreLabel.TextColor3 = Color3.fromRGB(100, 255, 140)
	elseif score >= 7 then
		rating = "GREAT! 🎯"
		ratingColor = Color3.fromRGB(80, 200, 255)
		scoreLabel.TextColor3 = Color3.fromRGB(80, 200, 255)
	elseif score >= 5 then
		rating = "SO CLOSE"
		ratingColor = Color3.fromRGB(255, 210, 50)
		scoreLabel.TextColor3 = Color3.fromRGB(255, 210, 50)
	else
		rating = "MISSED 😬"
		ratingColor = Color3.fromRGB(255, 80, 80)
		scoreLabel.TextColor3 = Color3.fromRGB(255, 80, 80)
	end

	scoreLabel.TextSize = 24
	scoreLabel.Text = scoreText
	ratingLabel.Text = rating
	ratingLabel.TextColor3 = ratingColor
	TweenService:Create(scoreLabel, TweenInfo.new(0.4, Enum.EasingStyle.Back, Enum.EasingDirection.Out), {
		TextSize = 52,
	}):Play()

	task.wait(3.5)
	hideCard()
end)

--------------------------------------------------------------
-- EVENT: Player Eliminated
--------------------------------------------------------------
PlayerElim.OnClientEvent:Connect(function(eliminatedName: string)
	if not eliminatedName then return end
	clearAllBillboards()
	hidePlayerGrid()

	showCard()
	setSlidersVisible(false)
	colorDisplay.Visible = false
	playerColorDisplay.Visible = false
	scoreLabel.Text = ""
	ratingLabel.Text = ""

	if eliminatedName == player.DisplayName then
		card.BackgroundColor3 = Color3.fromRGB(55, 10, 10)
		instructionLabel.Text = "💀 YOU WERE ELIMINATED"
		instructionLabel.TextColor3 = Color3.fromRGB(255, 80, 80)
		timerLabel.Text = ""
	else
		instructionLabel.Text = "💀 " .. eliminatedName:upper() .. " ELIMINATED"
		instructionLabel.TextColor3 = Color3.fromRGB(255, 160, 60)
		timerLabel.Text = ""
	end

	task.wait(2.5)
	hideCard()
end)

--------------------------------------------------------------
-- EVENT: Game Over
--------------------------------------------------------------
GameOverEvt.OnClientEvent:Connect(function(winnerName: string)
	clearAllBillboards()
	hidePlayerGrid()
	showCard()
	setSlidersVisible(false)
	colorDisplay.Visible = false
	playerColorDisplay.Visible = false
	timerLabel.Text = ""

	instructionLabel.Text = "GAME OVER"
	instructionLabel.TextColor3 = Color3.fromRGB(255, 215, 0)

	scoreLabel.TextSize = 36
	scoreLabel.Text = "🏆 " .. winnerName:upper()
	scoreLabel.TextColor3 = Color3.fromRGB(255, 215, 0)
	TweenService:Create(scoreLabel, TweenInfo.new(0.5, Enum.EasingStyle.Back, Enum.EasingDirection.Out), {
		TextSize = 52,
	}):Play()

	ratingLabel.Text = "WINS THE ROUND!"
	ratingLabel.TextColor3 = Color3.fromRGB(255, 215, 0)
end)

--------------------------------------------------------------
-- EVENT: Lobby Timer
--------------------------------------------------------------
LobbyTimerEvt.OnClientEvent:Connect(function(t: number)
	clearAllBillboards()
	hidePlayerGrid()
	if not card.Visible then
		showCard()
	end
	setSlidersVisible(false)
	colorDisplay.Visible = false
	playerColorDisplay.Visible = false
	scoreLabel.Text = ""
	ratingLabel.Text = ""
	instructionLabel.Text = "GAME STARTING SOON"
	instructionLabel.TextColor3 = Color3.fromRGB(180, 180, 220)
	pulseTimer(t)

	if t <= 1 then
		task.wait(1.5)
		hideCard()
	end
end)

--------------------------------------------------------------
-- DEBUG: Self-Eliminate Button (testing only)
--------------------------------------------------------------
local debugBtn = Instance.new("TextButton")
debugBtn.Name = "DebugElimBtn"
debugBtn.Size = UDim2.new(0, 150, 0, 34)
debugBtn.Position = UDim2.new(1, -160, 0, 10)
debugBtn.BackgroundColor3 = Color3.fromRGB(180, 30, 30)
debugBtn.BackgroundTransparency = 0.15
debugBtn.Text = "☠ Eliminate Me"
debugBtn.TextColor3 = Color3.new(1, 1, 1)
debugBtn.TextSize = 15
debugBtn.Font = Enum.Font.GothamBold
debugBtn.BorderSizePixel = 0
debugBtn.ZIndex = 10
debugBtn.Parent = screenGui
Instance.new("UICorner", debugBtn).CornerRadius = UDim.new(0, 8)

debugBtn.MouseButton1Click:Connect(function()
	DebugElimEvt:FireServer()
end)

--------------------------------------------------------------
-- BILLBOARDS (live color above each player's head)
--------------------------------------------------------------
local activeBillboards: { [string]: BillboardGui } = {}
local avatarCache: { [number]: string } = {}

clearAllBillboards = function()
	for name, billboard in pairs(activeBillboards) do
		if billboard and billboard.Parent then
			billboard:Destroy()
		end
		activeBillboards[name] = nil
	end
end

local function updatePlayerBillboard(playerName: string, h: number, s: number, v: number)
	if playerName == player.Name then return end

	local targetPlayer: Player? = nil
	for _, p in ipairs(Players:GetPlayers()) do
		if p.Name == playerName then
			targetPlayer = p
			break
		end
	end
	if not targetPlayer or not targetPlayer.Character then return end

	local head = targetPlayer.Character:FindFirstChild("Head") :: BasePart
	if not head then return end

	local billboard = activeBillboards[playerName]
	if not billboard or not billboard.Parent then
		billboard = Instance.new("BillboardGui")
		billboard.Name = "ColorPreview"
		billboard.Size = UDim2.new(0, 132, 0, 68)
		billboard.StudsOffset = Vector3.new(0, 2.4, 0)
		billboard.AlwaysOnTop = true
		billboard.Parent = head

		local bg = Instance.new("Frame")
		bg.Name = "BG"
		bg.Size = UDim2.new(1, 0, 1, 0)
		bg.BackgroundColor3 = Color3.fromRGB(12, 12, 18)
		bg.BackgroundTransparency = 0.25
		bg.BorderSizePixel = 0
		bg.Parent = billboard
		Instance.new("UICorner", bg).CornerRadius = UDim.new(0, 12)

		local avatar = Instance.new("ImageLabel")
		avatar.Name = "Avatar"
		avatar.Size = UDim2.new(0, 58, 0, 58)
		avatar.Position = UDim2.new(0, 5, 0.5, -29)
		avatar.BackgroundTransparency = 1
		avatar.Image = ""
		avatar.Parent = bg
		Instance.new("UICorner", avatar).CornerRadius = UDim.new(0, 8)

		local colorBox = Instance.new("Frame")
		colorBox.Name = "ColorBox"
		colorBox.Size = UDim2.new(0, 58, 0, 58)
		colorBox.Position = UDim2.new(0, 68, 0.5, -29)
		colorBox.BackgroundColor3 = Color3.fromHSV(h, s, v)
		colorBox.BorderSizePixel = 0
		colorBox.Parent = bg
		Instance.new("UICorner", colorBox).CornerRadius = UDim.new(0, 8)

		local stroke = Instance.new("UIStroke")
		stroke.Color = Color3.fromRGB(255, 255, 255)
		stroke.Thickness = 2
		stroke.Transparency = 0.45
		stroke.Parent = colorBox

		activeBillboards[playerName] = billboard

		-- Fetch avatar thumbnail asynchronously, cache by UserId
		local userId = targetPlayer.UserId
		task.spawn(function()
			local cachedUrl = avatarCache[userId]
			if not cachedUrl then
				local ok, url = pcall(
					Players.GetUserThumbnailAsync, Players,
					userId,
					Enum.ThumbnailType.HeadShot,
					Enum.ThumbnailSize.Size100x100
				)
				if ok then
					avatarCache[userId] = url
					cachedUrl = url
				end
			end
			if cachedUrl and billboard.Parent then
				local bg2 = billboard:FindFirstChild("BG") :: Frame
				local av = bg2 and bg2:FindFirstChild("Avatar") :: ImageLabel
				if av then av.Image = cachedUrl end
			end
		end)
	end

	local bg = billboard:FindFirstChild("BG") :: Frame
	local colorBox = bg and bg:FindFirstChild("ColorBox") :: Frame
	if colorBox then
		colorBox.BackgroundColor3 = Color3.fromHSV(h, s, v)
	end
end

--------------------------------------------------------------
-- EVENT: Broadcast Color (other players' live guess)
--------------------------------------------------------------
BroadcastColorEvt.OnClientEvent:Connect(function(playerName: string, h: number, s: number, v: number)
	updatePlayerBillboard(playerName, h, s, v)
end)

--------------------------------------------------------------
-- COLORSCREEN PLAYER GRID (updates on slider release only)
--------------------------------------------------------------
local playerGridGui = Instance.new("SurfaceGui")
playerGridGui.Name = "PlayerColorGrid"
playerGridGui.Face = Enum.NormalId.Front
playerGridGui.CanvasSize = Vector2.new(1024, 512)
playerGridGui.ZOffset = 0.05
playerGridGui.Enabled = false
playerGridGui.Parent = colorScreenPart

local gridContainer = Instance.new("Frame")
gridContainer.Name = "GridContainer"
gridContainer.Size = UDim2.new(1, 0, 1, 0)
gridContainer.BackgroundTransparency = 1
gridContainer.Parent = playerGridGui

-- Top zone: featured (highest scorer) — centered, larger card
local featuredSection = Instance.new("Frame")
featuredSection.Name = "Featured"
featuredSection.Size = UDim2.new(1, 0, 0, 240)
featuredSection.Position = UDim2.new(0, 0, 0, 0)
featuredSection.BackgroundTransparency = 1
featuredSection.Parent = gridContainer

-- Bottom zone: all other players in a smaller uniform grid
local restSection = Instance.new("Frame")
restSection.Name = "Rest"
restSection.Size = UDim2.new(1, 0, 1, -240)
restSection.Position = UDim2.new(0, 0, 0, 240)
restSection.BackgroundTransparency = 1
restSection.Parent = gridContainer

local restLayout = Instance.new("UIGridLayout")
restLayout.CellSize = UDim2.new(0, 110, 0, 172)
restLayout.CellPadding = UDim2.new(0, 12, 0, 12)
restLayout.HorizontalAlignment = Enum.HorizontalAlignment.Center
restLayout.VerticalAlignment = Enum.VerticalAlignment.Center
restLayout.SortOrder = Enum.SortOrder.Name
restLayout.Parent = restSection

local restPadding = Instance.new("UIPadding")
restPadding.PaddingTop = UDim.new(0, 10)
restPadding.PaddingBottom = UDim.new(0, 10)
restPadding.PaddingLeft = UDim.new(0, 10)
restPadding.PaddingRight = UDim.new(0, 10)
restPadding.Parent = restSection

-- Sizes used when promoting/demoting cards
local FEATURED_SIZE = UDim2.new(0, 168, 0, 228)
local REST_CELL     = UDim2.new(0, 110, 0, 172) -- matches restLayout.CellSize

local playerCards: { [string]: {
	card: Frame,
	colorFrame: Frame,
	avatarLabel: ImageLabel,
	scoreLabel: TextLabel,
	timeLabel: TextLabel,
} } = {}

-- Cards use scale-based internal layout so they look correct at both sizes
local function createPlayerCard(playerName: string, displayName: string, userId: number)
	local playerCard = Instance.new("Frame")
	playerCard.Name = playerName
	playerCard.BackgroundColor3 = Color3.fromRGB(20, 20, 30)
	playerCard.BackgroundTransparency = 0.1
	playerCard.BorderSizePixel = 0
	playerCard.Parent = restSection   -- starts in the rest grid
	Instance.new("UICorner", playerCard).CornerRadius = UDim.new(0, 12)

	local avatarLabel = Instance.new("ImageLabel")
	avatarLabel.Name = "Avatar"
	avatarLabel.Size = UDim2.new(1, -12, 0.51, -8)
	avatarLabel.Position = UDim2.new(0, 6, 0, 6)
	avatarLabel.BackgroundTransparency = 1
	avatarLabel.Image = ""
	avatarLabel.Parent = playerCard
	Instance.new("UICorner", avatarLabel).CornerRadius = UDim.new(0, 8)

	local colorFrame = Instance.new("Frame")
	colorFrame.Name = "ColorBox"
	colorFrame.Size = UDim2.new(1, -12, 0.17, 0)
	colorFrame.Position = UDim2.new(0, 6, 0.53, 0)
	colorFrame.BackgroundColor3 = Color3.fromRGB(50, 50, 70)
	colorFrame.BorderSizePixel = 0
	colorFrame.Parent = playerCard
	Instance.new("UICorner", colorFrame).CornerRadius = UDim.new(0, 6)

	local nameLabel = Instance.new("TextLabel")
	nameLabel.Size = UDim2.new(1, -4, 0.12, 0)
	nameLabel.Position = UDim2.new(0, 2, 0.71, 0)
	nameLabel.BackgroundTransparency = 1
	nameLabel.Text = displayName
	nameLabel.TextColor3 = Color3.fromRGB(200, 200, 220)
	nameLabel.Font = Enum.Font.GothamBold
	nameLabel.TextScaled = true
	nameLabel.TextTruncate = Enum.TextTruncate.AtEnd
	nameLabel.TextXAlignment = Enum.TextXAlignment.Center
	nameLabel.Parent = playerCard

	local cardScoreLabel = Instance.new("TextLabel")
	cardScoreLabel.Size = UDim2.new(1, -4, 0.11, 0)
	cardScoreLabel.Position = UDim2.new(0, 2, 0.83, 0)
	cardScoreLabel.BackgroundTransparency = 1
	cardScoreLabel.Text = ""
	cardScoreLabel.TextColor3 = Color3.fromRGB(100, 220, 140)
	cardScoreLabel.Font = Enum.Font.GothamBold
	cardScoreLabel.TextScaled = true
	cardScoreLabel.TextXAlignment = Enum.TextXAlignment.Center
	cardScoreLabel.Visible = false
	cardScoreLabel.Parent = playerCard

	local cardTimeLabel = Instance.new("TextLabel")
	cardTimeLabel.Size = UDim2.new(1, -4, 0.09, 0)
	cardTimeLabel.Position = UDim2.new(0, 2, 0.92, 0)
	cardTimeLabel.BackgroundTransparency = 1
	cardTimeLabel.Text = ""
	cardTimeLabel.TextColor3 = Color3.fromRGB(150, 150, 180)
	cardTimeLabel.Font = Enum.Font.GothamMedium
	cardTimeLabel.TextScaled = true
	cardTimeLabel.TextXAlignment = Enum.TextXAlignment.Center
	cardTimeLabel.Visible = false
	cardTimeLabel.Parent = playerCard

	playerCards[playerName] = {
		card = playerCard,
		colorFrame = colorFrame,
		avatarLabel = avatarLabel,
		scoreLabel = cardScoreLabel,
		timeLabel = cardTimeLabel,
	}

	-- Fetch avatar async, share cache with BillboardGui section
	task.spawn(function()
		local cached = avatarCache[userId]
		if not cached then
			local ok, url = pcall(
				Players.GetUserThumbnailAsync, Players,
				userId,
				Enum.ThumbnailType.HeadShot,
				Enum.ThumbnailSize.Size100x100
			)
			if ok then
				avatarCache[userId] = url
				cached = url
			end
		end
		if cached and playerCard.Parent then
			avatarLabel.Image = cached
		end
	end)
end

showPlayerGrid = function()
	for _, child in featuredSection:GetChildren() do
		if child:IsA("Frame") then child:Destroy() end
	end
	for _, child in restSection:GetChildren() do
		if child:IsA("Frame") then child:Destroy() end
	end
	playerCards = {}

	for _, p in ipairs(Players:GetPlayers()) do
		createPlayerCard(p.Name, p.DisplayName, p.UserId)
	end

	playerGridGui.Enabled = true
end

hidePlayerGrid = function()
	playerGridGui.Enabled = false
end

--------------------------------------------------------------
-- EVENT: Final Color (slider released — update ColorScreen card)
--------------------------------------------------------------
FinalColorEvt.OnClientEvent:Connect(function(playerName: string, h: number, s: number, v: number)
	local entry = playerCards[playerName]
	if entry then
		entry.colorFrame.BackgroundColor3 = Color3.fromHSV(h, s, v)
	end
end)

--------------------------------------------------------------
-- EVENT: Round Scores (show score + time; promote top scorer)
--------------------------------------------------------------
RoundScoresEvt.OnClientEvent:Connect(function(allScores: { { name: string, score: number, time: number } })
	-- Rank by time for medal colors
	local sorted = table.clone(allScores)
	table.sort(sorted, function(a, b) return a.time < b.time end)
	local timeRank: { [string]: number } = {}
	for rank, data in ipairs(sorted) do
		timeRank[data.name] = rank
	end

	local medalColors = {
		[1] = Color3.fromRGB(255, 215,  50),
		[2] = Color3.fromRGB(192, 192, 192),
		[3] = Color3.fromRGB(205, 127,  50),
	}

	-- Find the highest scorer
	local topName = ""
	local topScore = -1
	for _, data in ipairs(allScores) do
		if data.score > topScore then
			topScore = data.score
			topName = data.name
		end
	end

	-- Populate all cards
	for _, data in ipairs(allScores) do
		local entry = playerCards[data.name]
		if not entry then continue end

		entry.scoreLabel.Text = string.format("%.2f / 10", data.score)
		entry.timeLabel.Text = string.format("%.1fs", data.time)

		if data.score >= 7 then
			entry.scoreLabel.TextColor3 = Color3.fromRGB(100, 220, 140)
		elseif data.score >= 4 then
			entry.scoreLabel.TextColor3 = Color3.fromRGB(255, 210, 50)
		else
			entry.scoreLabel.TextColor3 = Color3.fromRGB(255, 90, 90)
		end

		entry.timeLabel.TextColor3 = medalColors[timeRank[data.name]]
			or Color3.fromRGB(150, 150, 180)

		entry.scoreLabel.Visible = true
		entry.timeLabel.Visible = true
	end

	-- Promote top scorer to the featured zone
	local winner = playerCards[topName]
	if winner then
		winner.card.Size = FEATURED_SIZE
		winner.card.AnchorPoint = Vector2.new(0.5, 0.5)
		winner.card.Position = UDim2.new(0.5, 0, 0.5, 0)
		winner.card.Parent = featuredSection
	end

	-- Ensure everyone else is in the rest grid at the normal cell size
	for name, entry in pairs(playerCards) do
		if name ~= topName then
			entry.card.Size = REST_CELL
			entry.card.AnchorPoint = Vector2.new(0, 0)
			entry.card.Parent = restSection
		end
	end
end)
