--!strict
-- PlaytimeAndSettingsModal.luau: Hop Qua Online 9 Moc (cong don ngay UTC) & Bang Settings (Auto-Lock, Low GFX, Mute SFX)

local ReplicatedStorage = game:GetService("ReplicatedStorage")
local Shared = ReplicatedStorage:WaitForChild("Shared")
local Net = require(Shared:WaitForChild("Net"))
local Util = require(Shared:WaitForChild("Util"))
local GameConfig = require(Shared:WaitForChild("Config"):WaitForChild("GameConfig"))

local Theme = require(script.Parent.Parent.Theme)
local WindowFrame = require(script.Parent.Parent.Components.WindowFrame)

local PlaytimeAndSettingsModal = {}

local win: WindowFrame.BuiltWindow? = nil
local currentTab = "Gifts"

local playtimeSec = 0
local claimedMap: { [string]: boolean } = {}
local autoLockRare = true
local autoLockMutated = true
local lowGfx = false
local muteSfx = false

local function clearBody(body: ScrollingFrame)
	for _, ch in ipairs(body:GetChildren()) do
		if ch:IsA("GuiObject") then
			ch:Destroy()
		end
	end
end

local function makeCard(body: ScrollingFrame, order: number, title: string, sub: string, col: Color3, bg: Color3): Frame
	local card = Instance.new("Frame")
	card.Size = UDim2.new(1, 0, 0, 68)
	card.BackgroundColor3 = bg
	card.LayoutOrder = order
	card.ZIndex = 22
	card.Parent = body
	Theme.AddCorner(card, 10)
	Theme.AddStroke(card, col, 2)

	local t = Instance.new("TextLabel")
	t.Size = UDim2.new(0.68, 0, 0, 24)
	t.Position = UDim2.fromOffset(12, 6)
	t.BackgroundTransparency = 1
	t.Font = Theme.FontTitle
	t.TextSize = 15
	t.TextXAlignment = Enum.TextXAlignment.Left
	t.TextColor3 = col
	t.Text = title
	t.ZIndex = 23
	t.Parent = card
	Theme.AddTextStroke(t, 1.4)

	local s = Instance.new("TextLabel")
	s.Size = UDim2.new(1, -168, 0, 34) -- Chua cho nut 128 ben phai; du 2 dong co 13.
	s.Position = UDim2.fromOffset(12, 30)
	s.BackgroundTransparency = 1
	s.Font = Theme.FontBody
	Theme.FitText(s, 13, 12)
	s.TextWrapped = true
	s.TextXAlignment = Enum.TextXAlignment.Left
	s.TextColor3 = Theme.Colors.TextMuted
	s.Text = sub
	s.ZIndex = 23
	s.Parent = card
	return card
end

function PlaytimeAndSettingsModal.Render()
	local w = win
	if not w then
		return
	end
	clearBody(w.body)

	if currentTab == "Gifts" then
		makeCard(
			w.body,
			0,
			string.format("⏱️ Today's Cumulative Playtime (UTC): %s", Util.FormatDuration(playtimeSec)),
			"Progress is saved across sessions all day UTC! Claim all 9 daily milestones!",
			Theme.Colors.Gold,
			Theme.Colors.CardOwned
		)

		for idx, gDef in ipairs(GameConfig.PlaytimeGifts) do
			local key = tostring(gDef.slot)
			local isClaimed = claimedMap[key] == true
			local ready = (playtimeSec >= gDef.reqSec)
			local rem = math.max(0, gDef.reqSec - playtimeSec)
			local row = makeCard(
				w.body,
				idx,
				string.format("🎁 Gift #%d: %s", gDef.slot, gDef.label),
				if isClaimed then "Claimed today ✅" elseif ready then "Ready to claim now!" else ("Unlocks in " .. Util.FormatDuration(rem)),
				if isClaimed then Theme.Colors.Primary elseif ready then Theme.Colors.Success else Theme.Colors.TextPrimary,
				if isClaimed then Theme.Colors.CardOwned else Theme.Colors.CardBg
			)

			local btn = Theme.CreateButton(
				row,
				"ClaimBtn",
				if isClaimed then "CLAIMED" elseif ready then "CLAIM!" else Util.FormatDuration(rem),
				UDim2.fromOffset(128, 36),
				UDim2.new(1, -140, 0.5, -18),
				if isClaimed then Theme.Colors.Primary elseif ready then Theme.Colors.Success else Color3.fromRGB(68, 78, 102),
				function()
					if ready and not isClaimed then
						Net.FireServer(Net.ClientToServer.ClaimPlaytimeGift, gDef.slot)
					end
				end
			)
			btn.TextSize = 13
			btn.ZIndex = 24
		end
	else
		local toggles = {
			{ key = "autoLockRare", title = "🔒 Auto-Lock Legendary & Boss Fish", sub = "Automatically locks Legendary, Boss & Titanic catches against accidental sale.", val = autoLockRare },
			{ key = "autoLockMutated", title = "✨ Auto-Lock Mutated Fish", sub = "Automatically locks Shiny, Golden & Cosmic catches when reeled in.", val = autoLockMutated },
			{ key = "lowGfx", title = "⚡ Low GFX Performance Mode", sub = "Disables dynamic shadows, bloom & distant particles for smoother FPS on Mobile.", val = lowGfx },
			{ key = "muteSfx", title = "🔇 Mute Sound Effects", sub = "Silences UI clicks, splash & reel sound effects.", val = muteSfx },
		}

		for idx, item in ipairs(toggles) do
			local row = makeCard(w.body, idx, item.title, item.sub, if item.val then Theme.Colors.Success else Theme.Colors.TextPrimary, Theme.Colors.CardBg)
			local tBtn = Theme.CreateButton(
				row,
				"Toggle_" .. item.key,
				if item.val then "ON ✅" else "OFF",
				UDim2.fromOffset(118, 36),
				UDim2.new(1, -130, 0.5, -18),
				if item.val then Theme.Colors.Success else Color3.fromRGB(78, 86, 108),
				function()
					local patch: { [string]: boolean } = {}
					patch[item.key] = not item.val
					Net.FireServer(Net.ClientToServer.UpdateSettings, patch)
				end
			)
			tBtn.TextSize = 14
			tBtn.ZIndex = 24
		end
	end
end

function PlaytimeAndSettingsModal.Mount(rootGui: ScreenGui): WindowFrame.BuiltWindow
	local built = WindowFrame.Create(rootGui, "PlaytimeAndSettingsWindow", "🎁 PLAYTIME GIFTS & SETTINGS", UDim2.fromOffset(600, 435), Color3.fromRGB(82, 206, 134))
	win = built
	local gTab = built.AddTab("Gifts (9)", function() currentTab = "Gifts"; PlaytimeAndSettingsModal.Render() end)
	built.AddTab("Settings ⚙️", function() currentTab = "Settings"; PlaytimeAndSettingsModal.Render() end)
	built.SetActiveTab(gTab)
	return built
end

function PlaytimeAndSettingsModal.SyncPlaytime(sec: number, claimed: any)
	playtimeSec = sec
	if type(claimed) == "table" then
		claimedMap = claimed
	end
	if win and win.IsVisible() and currentTab == "Gifts" then
		PlaytimeAndSettingsModal.Render()
	end
end

function PlaytimeAndSettingsModal.SyncSettings(lockRare: boolean, lockMut: boolean, low: boolean, mute: boolean)
	autoLockRare = lockRare
	autoLockMutated = lockMut
	lowGfx = low
	muteSfx = mute
	if win and win.IsVisible() and currentTab == "Settings" then
		PlaytimeAndSettingsModal.Render()
	end
end

return PlaytimeAndSettingsModal
