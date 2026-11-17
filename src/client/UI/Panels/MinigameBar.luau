--!strict
-- MinigameBar.luau: Thanh can nhip bat Ca Hiem / Boss (ho tro Chuot, Phim Space va Nut STRIKE tren Mobile)

local RunService = game:GetService("RunService")
local UserInputService = game:GetService("UserInputService")

local Theme = require(script.Parent.Parent.Theme)

export type MinigameSpec = {
	sessionId: string,
	fishName: string,
	rarity: string,
	mutation: string,
	rounds: number,
	zoneWidth: number,
	speed: number,
}

local MinigameBar = {}

local container: Frame? = nil
local titleLbl: TextLabel? = nil
local progressLbl: TextLabel? = nil
local safeZoneFrame: Frame? = nil
local cursorFrame: Frame? = nil
local renderConn: RBXScriptConnection? = nil
local inputConn: RBXScriptConnection? = nil

local activeSpec: MinigameSpec? = nil
local currentRound = 1
local cursorPos = 0.0
local cursorDir = 1
local zoneCenter = 0.5
local zoneWidth = 0.28
local finishCallback: ((string, boolean) -> ())? = nil

local function randomizeSafeZone(width: number)
	zoneWidth = width
	local margin = width * 0.5 + 0.08
	zoneCenter = margin + math.random() * math.max(0.05, 1.0 - margin * 2)
	if safeZoneFrame then
		safeZoneFrame.Size = UDim2.fromScale(zoneWidth, 1)
		safeZoneFrame.Position = UDim2.fromScale(zoneCenter - zoneWidth * 0.5, 0)
	end
end

local function closeMinigame()
	if renderConn then
		renderConn:Disconnect()
		renderConn = nil
	end
	if inputConn then
		inputConn:Disconnect()
		inputConn = nil
	end
	if container then
		container.Visible = false
	end
	activeSpec = nil
end

local function attemptStrike()
	local spec = activeSpec
	if not spec then
		return
	end

	local half = zoneWidth * 0.52 -- Nhan du nhe cho cam giac bam muot tay
	local hit = math.abs(cursorPos - zoneCenter) <= half

	if not hit then
		local cb = finishCallback
		local sid = spec.sessionId
		closeMinigame()
		if cb then
			cb(sid, false)
		end
		return
	end

	if currentRound >= spec.rounds then
		local cb = finishCallback
		local sid = spec.sessionId
		closeMinigame()
		if cb then
			cb(sid, true)
		end
	else
		currentRound += 1
		if progressLbl then
			progressLbl.Text = string.format("STRIKE %d / %d — HIT GREEN ZONE!", currentRound, spec.rounds)
		end
		randomizeSafeZone(spec.zoneWidth)
	end
end

function MinigameBar.Mount(parentGui: ScreenGui, onComplete: (string, boolean) -> ())
	finishCallback = onComplete

	local frame = Instance.new("Frame")
	frame.Name = "MinigameContainer"
	frame.AnchorPoint = Vector2.new(0.5, 1)
	frame.Position = UDim2.new(0.5, 0, 0.80, 0)
	frame.Size = UDim2.fromOffset(440, 142)
	frame.BackgroundColor3 = Theme.Colors.PanelBg
	frame.Visible = false
	frame.Parent = parentGui
	Theme.AddCorner(frame, 14)
	Theme.AddStroke(frame, Theme.Colors.Gold, 3)
	container = frame

	local header = Instance.new("TextLabel")
	header.Name = "FishHeader"
	header.Size = UDim2.new(1, -20, 0, 30)
	header.Position = UDim2.fromOffset(10, 8)
	header.BackgroundTransparency = 1
	header.Font = Theme.FontTitle
	header.TextSize = 20
	header.TextColor3 = Theme.Colors.Gold
	header.Text = "RARE FISH ON THE HOOK!"
	header.Parent = frame
	Theme.AddTextStroke(header, 2)
	titleLbl = header

	local sub = Instance.new("TextLabel")
	sub.Name = "RoundProgress"
	sub.Size = UDim2.new(1, -20, 0, 20)
	sub.Position = UDim2.fromOffset(10, 36)
	sub.BackgroundTransparency = 1
	sub.Font = Theme.FontBody
	sub.TextSize = 14
	sub.TextColor3 = Theme.Colors.TextMuted
	sub.Text = "STRIKE 1 / 1"
	sub.Parent = frame
	progressLbl = sub

	local track = Instance.new("Frame")
	track.Name = "TrackBar"
	track.AnchorPoint = Vector2.new(0.5, 0)
	track.Position = UDim2.new(0.5, 0, 0, 62)
	track.Size = UDim2.new(1, -36, 0, 26)
	track.BackgroundColor3 = Color3.fromRGB(16, 22, 36)
	track.ClipsDescendants = true
	track.Parent = frame
	Theme.AddCorner(track, 8)
	Theme.AddStroke(track, Theme.Colors.StrokeLight, 2)

	local safe = Instance.new("Frame")
	safe.Name = "GreenSafeZone"
	safe.Size = UDim2.fromScale(0.3, 1)
	safe.Position = UDim2.fromScale(0.35, 0)
	safe.BackgroundColor3 = Theme.Colors.Success
	safe.BorderSizePixel = 0
	safe.Parent = track
	Theme.AddCorner(safe, 6)
	safeZoneFrame = safe

	local cursor = Instance.new("Frame")
	cursor.Name = "CursorNeedle"
	cursor.AnchorPoint = Vector2.new(0.5, 0.5)
	cursor.Size = UDim2.new(0, 8, 1, 8)
	cursor.Position = UDim2.fromScale(0.1, 0.5)
	cursor.BackgroundColor3 = Color3.fromRGB(255, 255, 255)
	cursor.BorderSizePixel = 0
	cursor.Parent = track
	Theme.AddCorner(cursor, 4)
	Theme.AddStroke(cursor, Theme.Colors.StrokeDark, 2)
	cursorFrame = cursor

	Theme.CreateButton(
		frame,
		"StrikeButton",
		"⚡ STRIKE! (SPACE / TAP)",
		UDim2.new(1, -36, 0, 36),
		UDim2.fromOffset(18, 96),
		Theme.Colors.Warning,
		attemptStrike
	)
end

function MinigameBar.Start(spec: MinigameSpec)
	closeMinigame()
	activeSpec = spec
	currentRound = 1
	cursorPos = 0.08
	cursorDir = 1

	if container and titleLbl and progressLbl then
		local rarityColor = Theme.RarityColors[spec.rarity] or Theme.Colors.Gold
		local mutPrefix = if spec.mutation ~= "None" then ("[" .. spec.mutation .. "] ") else ""
		titleLbl.Text = string.format("⚡ %s: %s%s!", string.upper(spec.rarity), mutPrefix, spec.fishName)
		titleLbl.TextColor3 = rarityColor
		progressLbl.Text = string.format("STRIKE 1 / %d — HIT GREEN ZONE!", spec.rounds)
		randomizeSafeZone(spec.zoneWidth)
		container.Visible = true
	end

	renderConn = RunService.RenderStepped:Connect(function(dt: number)
		cursorPos += cursorDir * spec.speed * dt
		if cursorPos >= 0.98 then
			cursorPos = 0.98
			cursorDir = -1
		elseif cursorPos <= 0.02 then
			cursorPos = 0.02
			cursorDir = 1
		end
		if cursorFrame then
			cursorFrame.Position = UDim2.fromScale(cursorPos, 0.5)
		end
	end)

	inputConn = UserInputService.InputBegan:Connect(function(input: InputObject, gameProcessed: boolean)
		if gameProcessed then
			return
		end
		if input.KeyCode == Enum.KeyCode.Space then
			attemptStrike()
		end
	end)
end

function MinigameBar.IsOpen(): boolean
	return activeSpec ~= nil
end

function MinigameBar.ForceClose()
	closeMinigame()
end

return MinigameBar
