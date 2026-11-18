--!strict
-- MinigameBar.luau: Thanh Minigame Song Tam Giac Tat Dinh (Per-Strike Server Verification + Countdown chong ket AFK)

local ReplicatedStorage = game:GetService("ReplicatedStorage")
local RunService = game:GetService("RunService")
local UserInputService = game:GetService("UserInputService")

local Shared = ReplicatedStorage:WaitForChild("Shared")
local Util = require(Shared:WaitForChild("Util"))

local Theme = require(script.Parent.Parent.Theme)

export type MinigameSpec = {
	sessionId: string,
	fishName: string,
	rarity: string,
	mutation: string,
	rounds: number,
	zoneWidth: number,
	zoneCenters: { number },
	speed: number,
	timeoutSec: number,
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
local startClock = 0.0
local currentRound = 1
local strikeCooldownUntil = 0.0
local strikeCallback: ((string, number, number) -> ())? = nil
local openStateChangedCallback: ((boolean) -> ())? = nil

local function applyRoundZone(spec: MinigameSpec, roundIdx: number)
	local center = spec.zoneCenters[roundIdx] or 0.52
	if safeZoneFrame then
		safeZoneFrame.Size = UDim2.fromScale(spec.zoneWidth, 1)
		safeZoneFrame.Position = UDim2.fromScale(center - spec.zoneWidth * 0.5, 0)
	end
end

local function closeMinigame()
	local wasOpen = (activeSpec ~= nil)
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
	if wasOpen and openStateChangedCallback then
		openStateChangedCallback(false)
	end
end

local function attemptStrike()
	local spec = activeSpec
	if not spec or os.clock() < strikeCooldownUntil then
		return
	end
	strikeCooldownUntil = os.clock() + 0.12
	local elapsed = math.max(0.01, os.clock() - startClock)
	if elapsed > spec.timeoutSec then
		closeMinigame()
		return
	end

	local roundSent = currentRound
	local needlePos = Util.TriangleBounce(0.08, spec.speed, elapsed)
	local targetCenter = spec.zoneCenters[roundSent] or 0.52
	local hitLocal = math.abs(needlePos - targetCenter) <= (spec.zoneWidth * 0.52 + 0.05)

	if strikeCallback then
		strikeCallback(spec.sessionId, roundSent, elapsed)
	end

	if not hitLocal then
		closeMinigame()
		return
	end

	if currentRound >= spec.rounds then
		closeMinigame()
	else
		currentRound += 1
		applyRoundZone(spec, currentRound)
	end
end

function MinigameBar.OnOpenStateChanged(cb: (boolean) -> ())
	openStateChangedCallback = cb
end

function MinigameBar.Mount(parentGui: ScreenGui, onStrike: (string, number, number) -> ())
	strikeCallback = onStrike

	local frame = Instance.new("Frame")
	frame.Name = "MinigameContainer"
	frame.AnchorPoint = Vector2.new(0.5, 1)
	frame.Position = UDim2.new(0.5, 0, 0.77, 0)
	frame.Size = UDim2.fromOffset(456, 146)
	frame.BackgroundColor3 = Theme.Colors.PanelBg
	frame.Visible = false
	frame.ZIndex = 36
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
	header.ZIndex = 37
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
	sub.ZIndex = 37
	sub.Parent = frame
	progressLbl = sub

	local track = Instance.new("Frame")
	track.Name = "TrackBar"
	track.AnchorPoint = Vector2.new(0.5, 0)
	track.Position = UDim2.new(0.5, 0, 0, 62)
	track.Size = UDim2.new(1, -36, 0, 26)
	track.BackgroundColor3 = Color3.fromRGB(16, 22, 36)
	track.ClipsDescendants = true
	track.ZIndex = 37
	track.Parent = frame
	Theme.AddCorner(track, 8)
	Theme.AddStroke(track, Theme.Colors.StrokeLight, 2)

	local safe = Instance.new("Frame")
	safe.Name = "GreenSafeZone"
	safe.Size = UDim2.fromScale(0.3, 1)
	safe.Position = UDim2.fromScale(0.35, 0)
	safe.BackgroundColor3 = Theme.Colors.Success
	safe.BorderSizePixel = 0
	safe.ZIndex = 38
	safe.Parent = track
	Theme.AddCorner(safe, 6)
	safeZoneFrame = safe

	local cursor = Instance.new("Frame")
	cursor.Name = "CursorNeedle"
	cursor.AnchorPoint = Vector2.new(0.5, 0.5)
	cursor.Size = UDim2.new(0, 8, 1, 8)
	cursor.Position = UDim2.fromScale(0.08, 0.5)
	cursor.BackgroundColor3 = Color3.fromRGB(255, 255, 255)
	cursor.BorderSizePixel = 0
	cursor.ZIndex = 39
	cursor.Parent = track
	Theme.AddCorner(cursor, 4)
	Theme.AddStroke(cursor, Theme.Colors.StrokeDark, 2)
	cursorFrame = cursor

	local btn = Theme.CreateButton(
		frame,
		"StrikeButton",
		"⚡ STRIKE! (CLICK / SPACE / TAP)",
		UDim2.new(1, -36, 0, 38),
		UDim2.fromOffset(18, 98),
		Theme.Colors.Warning,
		attemptStrike
	)
	btn.ZIndex = 38
end

function MinigameBar.Start(spec: MinigameSpec)
	closeMinigame()
	activeSpec = spec
	startClock = os.clock()
	currentRound = 1
	strikeCooldownUntil = 0

	if container and titleLbl and progressLbl then
		local rarityColor = Theme.RarityColors[spec.rarity] or Theme.Colors.Gold
		local mutPrefix = if spec.mutation ~= "None" then ("[" .. spec.mutation .. "] ") else ""
		titleLbl.Text = string.format("❗ %s: %s%s!", string.upper(spec.rarity), mutPrefix, spec.fishName)
		titleLbl.TextColor3 = rarityColor
		applyRoundZone(spec, 1)
		container.Visible = true
	end
	if openStateChangedCallback then
		openStateChangedCallback(true)
	end

	renderConn = RunService.RenderStepped:Connect(function()
		local cur = activeSpec
		if not cur then
			return
		end
		local elapsed = os.clock() - startClock
		if elapsed >= cur.timeoutSec then
			closeMinigame()
			return
		end
		local pos = Util.TriangleBounce(0.08, cur.speed, elapsed)
		if cursorFrame then
			cursorFrame.Position = UDim2.fromScale(pos, 0.5)
		end
		if progressLbl then
			local rem = math.max(0, cur.timeoutSec - elapsed)
			progressLbl.Text = string.format("STRIKE %d / %d  •  ⏱️ %.1fs LEFT", currentRound, cur.rounds, rem)
		end
	end)

	inputConn = UserInputService.InputBegan:Connect(function(input: InputObject, gameProcessed: boolean)
		if gameProcessed then
			return
		end
		if input.KeyCode == Enum.KeyCode.Space or input.UserInputType == Enum.UserInputType.MouseButton1 then
			attemptStrike()
		end
	end)
end

function MinigameBar.SyncRoundFromServer(sessionId: string, nextRound: number)
	if activeSpec and activeSpec.sessionId == sessionId and nextRound > currentRound then
		currentRound = nextRound
		applyRoundZone(activeSpec, currentRound)
	end
end

function MinigameBar.IsOpen(): boolean
	return activeSpec ~= nil
end

function MinigameBar.ForceClose()
	closeMinigame()
end

return MinigameBar
