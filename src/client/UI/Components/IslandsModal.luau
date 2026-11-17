--!strict
-- IslandsModal.luau: Bang ban do 5 Dao Launch cho phep Mo khoa nhanh bang Gold & Dich chuyen 1 cham

local ReplicatedStorage = game:GetService("ReplicatedStorage")
local Shared = ReplicatedStorage:WaitForChild("Shared")
local Net = require(Shared:WaitForChild("Net"))
local Util = require(Shared:WaitForChild("Util"))
local IslandsRegistry = require(Shared:WaitForChild("Config"):WaitForChild("Islands"))

local Theme = require(script.Parent.Parent.Theme)
local WindowFrame = require(script.Parent.WindowFrame)

local IslandsModal = {}

local win: WindowFrame.BuiltWindow? = nil
local curIslandId = 1
local unlockedMap: { [string]: boolean } = { ["1"] = true }

function IslandsModal.Render()
	local w = win
	if not w then
		return
	end
	for _, ch in ipairs(w.body:GetChildren()) do
		if ch:IsA("GuiObject") then
			ch:Destroy()
		end
	end

	for idx, isl in ipairs(IslandsRegistry.List) do
		local isUnlocked = unlockedMap[tostring(isl.id)] == true
		local isHere = (curIslandId == isl.id)

		local card = Instance.new("Frame")
		card.Size = UDim2.new(1, 0, 0, 66)
		card.BackgroundColor3 = if isHere then Theme.Colors.CardOwned else Theme.Colors.CardBg
		card.LayoutOrder = idx
		card.ZIndex = 22
		card.Parent = w.body
		Theme.AddCorner(card, 10)
		Theme.AddStroke(card, isl.theme.accentColor, 2)

		local title = Instance.new("TextLabel")
		title.Size = UDim2.new(0.64, 0, 0, 28)
		title.Position = UDim2.fromOffset(12, 6)
		title.BackgroundTransparency = 1
		title.Font = Theme.FontTitle
		title.TextSize = 18
		title.TextXAlignment = Enum.TextXAlignment.Left
		title.TextColor3 = isl.theme.accentColor
		title.Text = string.format("🏝️ %d. %s", isl.id, isl.name)
		title.ZIndex = 23
		title.Parent = card
		Theme.AddTextStroke(title, 1.5)

		local sub = Instance.new("TextLabel")
		sub.Size = UDim2.new(0.64, 0, 0, 22)
		sub.Position = UDim2.fromOffset(12, 34)
		sub.BackgroundTransparency = 1
		sub.Font = Theme.FontBody
		sub.TextSize = 13
		sub.TextXAlignment = Enum.TextXAlignment.Left
		sub.TextColor3 = Theme.Colors.TextMuted
		sub.Text = string.format("%s • %.1fx Value & Gym", isl.subtitle, isl.economyMultiplier)
		sub.ZIndex = 23
		sub.Parent = card

		local btnLabel = if isHere
			then "CURRENT"
			elseif isUnlocked then "TELEPORT"
			else ("UNLOCK: " .. Util.FormatNumber(isl.unlockCostGold) .. "G")
		local btnCol = if isHere
			then Theme.Colors.Primary
			elseif isUnlocked then Theme.Colors.Success
			else Theme.Colors.Gold

		local btn = Theme.CreateButton(card, "IslBtn", btnLabel, UDim2.fromOffset(152, 38), UDim2.new(1, -164, 0.5, -19), btnCol, function()
			if isHere then
				return
			end
			if isUnlocked then
				Net.FireServer(Net.ClientToServer.TravelIsland, isl.id)
				w.SetVisible(false)
			else
				Net.FireServer(Net.ClientToServer.UnlockIsland, isl.id)
			end
		end)
		btn.TextSize = 14
		btn.ZIndex = 23
	end

	local soon = Instance.new("Frame")
	soon.Size = UDim2.new(1, 0, 0, 52)
	soon.BackgroundColor3 = Color3.fromRGB(38, 34, 66)
	soon.LayoutOrder = 99
	soon.ZIndex = 22
	soon.Parent = w.body
	Theme.AddCorner(soon, 10)
	Theme.AddStroke(soon, Theme.Colors.Gems, 2)

	local soonLbl = Instance.new("TextLabel")
	soonLbl.Size = UDim2.fromScale(1, 1)
	soonLbl.BackgroundTransparency = 1
	soonLbl.Font = Theme.FontTitle
	soonLbl.TextSize = 16
	soonLbl.TextColor3 = Theme.Colors.Gems
	soonLbl.Text = "✨ MORE ISLANDS & BOSSES COMING IN NEXT UPDATE!"
	soonLbl.ZIndex = 23
	soonLbl.Parent = soon
	Theme.AddTextStroke(soonLbl, 1.5)
end

function IslandsModal.Mount(rootGui: ScreenGui): WindowFrame.BuiltWindow
	local built = WindowFrame.Create(rootGui, "IslandsWindow", "🗺️ WORLD ISLANDS", UDim2.fromOffset(560, 420), Color3.fromRGB(56, 212, 196))
	built.tabBar.Visible = false
	built.body.Position = UDim2.fromOffset(10, 62)
	built.body.Size = UDim2.new(1, -20, 1, -72)
	win = built
	IslandsModal.Render()
	return built
end

function IslandsModal.Sync(islandId: number, unlocked: { [string]: boolean })
	curIslandId = islandId
	unlockedMap = unlocked
	if win and win.IsVisible() then
		IslandsModal.Render()
	end
end

return IslandsModal
