--!strict
-- TutorialController.luau: Huong dan Tan thu 4 buoc nhe nhang & Goi y mo Cong Dao ke tiep khi du Gold

local ReplicatedStorage = game:GetService("ReplicatedStorage")
local Shared = ReplicatedStorage:WaitForChild("Shared")
local Net = require(Shared:WaitForChild("Net"))
local Util = require(Shared:WaitForChild("Util"))
local IslandsRegistry = require(Shared:WaitForChild("Config"):WaitForChild("Islands"))

local Theme = require(script.Parent.Parent.UI.Theme)

local WindowFrame = require(script.Parent.Parent.UI.Components.WindowFrame)

local TutorialController = {}

local guideLabel: TextLabel? = nil
local curGold = 0
local curStrength = 0
local fishCaught = 0
local ownedBamboo = false
local unlockedIslands: { [string]: boolean } = { ["1"] = true }

local function refreshBanner()
	local lbl = guideLabel
	if not lbl then
		return
	end

	-- Chuoi 4 buoc Tan thu (tu an vinh vien ngay khi mua xong Bamboo Rod hoac mo Dao 2)
	if not ownedBamboo and not unlockedIslands["2"] then
		lbl.Visible = true
		if fishCaught == 0 then
			lbl.Text = "💡 Step 1/4: Equip Rod [1], walk onto the Pier & Hold + Release on Ocean Water!"
		elseif curGold == 0 then
			lbl.Text = "💡 Step 2/4: Talk to Captain Barnaby at Fish Market (or open [🎒 Bag]) to Sell Fish!"
		elseif curStrength < 1500 then
			lbl.Text = string.format("💡 Step 3/4: Stand on a Gym Pad & Click to reach 1.5K Strength (%s / 1.5K)!", Util.FormatNumber(curStrength))
		else
			lbl.Text = "💡 Step 4/4: Open [🛒 Shop] and buy the Bamboo Rod (500 Gold)!"
		end
		return
	end

	-- Goi y mo khoa Dao tiep theo khi nguoi choi da tich du Gold
	for _, isl in ipairs(IslandsRegistry.List) do
		if isl.id > 1 and not unlockedIslands[tostring(isl.id)] then
			if curGold >= isl.unlockCostGold then
				lbl.Visible = true
				lbl.Text = string.format("🗺️ Ready to Advance! Open [Islands] or visit the North Portal to unlock %s!", isl.name)
				return
			end
			break
		end
	end

	lbl.Visible = false
end

function TutorialController.Init(rootGui: ScreenGui)
	local banner = Instance.new("TextLabel")
	banner.Name = "OnboardingHint"
	banner.AnchorPoint = Vector2.new(0.5, 1)
	banner.Position = UDim2.new(0.5, 0, 1, -122)
	banner.Size = UDim2.new(1, 0, 1, 0)
	banner.TextWrapped = true
	local limit = Instance.new("UISizeConstraint")
	limit.MaxSize = Vector2.new(600, 36)
	limit.Parent = banner
	banner.BackgroundColor3 = Color3.fromRGB(26, 44, 68)
	banner.BackgroundTransparency = 0.12
	banner.Font = Theme.FontBody
	banner.TextSize = 14
	banner.TextColor3 = Color3.fromRGB(132, 244, 255)
	banner.Text = ""
	banner.Visible = false
	local slot = Instance.new("Frame")
	slot.BackgroundTransparency = 1
	slot.Parent = rootGui
	WindowFrame.BindLayout(rootGui, slot, "OnboardingHint")
	banner.AnchorPoint = Vector2.zero
	banner.Position = UDim2.fromScale(0, 0)
	banner.Parent = slot
	Theme.AddCorner(banner, 8)
	Theme.AddStroke(banner, Color3.fromRGB(82, 212, 255), 1.8)
	Theme.AddTextStroke(banner, 1.4)
	guideLabel = banner

	Net.OnClientEvent(Net.ServerToClient.StateSnapshot, function(snap: any)
		if type(snap) ~= "table" or type(snap.profile) ~= "table" then
			return
		end
		local p = snap.profile
		curGold = tonumber(p.gold) or 0
		curStrength = tonumber(p.strength) or 0
		if type(p.stats) == "table" then
			fishCaught = tonumber(p.stats.fishCaught) or 0
		end
		if type(p.ownedRods) == "table" then
			ownedBamboo = (p.ownedRods["Bamboo"] == true)
		end
		if type(p.unlockedIslands) == "table" then
			unlockedIslands = p.unlockedIslands
		end
		refreshBanner()
	end)

	Net.OnClientEvent(Net.ServerToClient.CurrencyUpdated, function(payload: any)
		if type(payload) == "table" then
			curGold = tonumber(payload.gold) or curGold
			curStrength = tonumber(payload.strength) or curStrength
			refreshBanner()
		end
	end)

	Net.OnClientEvent(Net.ServerToClient.FishingCatchResult, function(payload: any)
		if type(payload) == "table" and payload.success == true then
			fishCaught += 1
			refreshBanner()
		end
	end)

	Net.OnClientEvent(Net.ServerToClient.InventoryUpdated, function(payload: any)
		if type(payload) == "table" and type(payload.ownedRods) == "table" then
			ownedBamboo = (payload.ownedRods["Bamboo"] == true)
			refreshBanner()
		end
	end)

	Net.OnClientEvent(Net.ServerToClient.IslandChanged, function(payload: any)
		if type(payload) == "table" and type(payload.unlockedIslands) == "table" then
			unlockedIslands = payload.unlockedIslands
			refreshBanner()
		end
	end)
end

return TutorialController
