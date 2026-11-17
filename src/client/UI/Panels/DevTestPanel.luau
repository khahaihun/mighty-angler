--!strict
-- DevTestPanel.luau: Bang nut [DEV] test nhanh trong Roblox Studio (TU DONG AN 100% KHI PUBLISH)

local ReplicatedStorage = game:GetService("ReplicatedStorage")
local RunService = game:GetService("RunService")

local Shared = ReplicatedStorage:WaitForChild("Shared")
local Net = require(Shared:WaitForChild("Net"))

local Theme = require(script.Parent.Parent.Theme)

local DevTestPanel = {}

function DevTestPanel.Mount(rootGui: ScreenGui)
	if not RunService:IsStudio() then
		return
	end

	local panel = Instance.new("Frame")
	panel.Name = "StudioDevDrawer"
	panel.AnchorPoint = Vector2.new(1, 0)
	panel.Position = UDim2.new(1, -14, 0, 56)
	panel.Size = UDim2.fromOffset(256, 308)
	panel.BackgroundColor3 = Theme.Colors.PanelBg
	panel.Visible = false
	panel.ZIndex = 70
	panel.Parent = rootGui
	Theme.AddCorner(panel, 14)
	Theme.AddStroke(panel, Theme.Colors.Warning, 2.5)

	local header = Instance.new("TextLabel")
	header.Size = UDim2.new(1, -16, 0, 28)
	header.Position = UDim2.fromOffset(8, 6)
	header.BackgroundTransparency = 1
	header.Font = Theme.FontTitle
	header.TextSize = 16
	header.TextColor3 = Theme.Colors.Warning
	header.Text = "🛠️ STUDIO DEV QUICK TEST"
	header.ZIndex = 71
	header.Parent = panel

	local gridHolder = Instance.new("Frame")
	gridHolder.Size = UDim2.new(1, -16, 1, -42)
	gridHolder.Position = UDim2.fromOffset(8, 36)
	gridHolder.BackgroundTransparency = 1
	gridHolder.ZIndex = 71
	gridHolder.Parent = panel

	local grid = Instance.new("UIGridLayout")
	grid.CellSize = UDim2.fromOffset(114, 36)
	grid.CellPadding = UDim2.fromOffset(8, 7)
	grid.SortOrder = Enum.SortOrder.LayoutOrder
	grid.Parent = gridHolder

	local devButtons = {
		{ label = "+10K Gold", act = "AddGold10K", col = Theme.Colors.Gold },
		{ label = "+2M Gold", act = "AddGold2M", col = Theme.Colors.Gold },
		{ label = "+50K Str", act = "AddStrength50K", col = Theme.Colors.Strength },
		{ label = "+5M Str", act = "AddStrength5M", col = Theme.Colors.Strength },
		{ label = "+500 Gems", act = "AddGems500", col = Theme.Colors.Gems },
		{ label = "Force Rare", act = "ForceRare", col = Theme.Colors.Primary },
		{ label = "Force BOSS", act = "ForceBoss", col = Theme.Colors.Danger },
		{ label = "Unlock Map", act = "UnlockAllIslands", col = Theme.Colors.Success },
		{ label = "All Passes", act = "GrantAllPasses", col = Color3.fromRGB(168, 92, 255) },
		{ label = "Lock Sim", act = "ToggleFreeSim", col = Theme.Colors.CardBg },
		{ label = "Start Event", act = "TriggerEvent", col = Theme.Colors.Warning },
		{ label = "Reset Save", act = "ResetSave", col = Color3.fromRGB(132, 42, 48) },
	}

	for idx, item in ipairs(devButtons) do
		local b = Theme.CreateButton(gridHolder, "Dev_" .. item.act, item.label, UDim2.fromOffset(114, 36), UDim2.new(), item.col, function()
			Net.FireServer(Net.ClientToServer.DevAction, item.act)
		end)
		b.LayoutOrder = idx
		b.TextSize = 13
		b.ZIndex = 72
	end

	local toggleBtn = Theme.CreateButton(
		rootGui,
		"StudioDevToggleBtn",
		"🛠️ [DEV]",
		UDim2.fromOffset(92, 36),
		UDim2.new(1, -106, 0, 12),
		Theme.Colors.Warning,
		function()
			panel.Visible = not panel.Visible
		end
	)
	toggleBtn.TextSize = 15
	toggleBtn.ZIndex = 75
end

return DevTestPanel
