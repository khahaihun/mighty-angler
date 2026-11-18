--!strict
local Players = game:GetService("Players")
local ReplicatedStorage = game:GetService("ReplicatedStorage")
local Shared = ReplicatedStorage:WaitForChild("Shared")
local Net = require(Shared:WaitForChild("Net"))
local GamepassesConfig = require(Shared:WaitForChild("Config"):WaitForChild("GamepassesConfig"))
local Theme = require(script.Parent.Parent.UI.Theme)
local PurchaseOddsController = {}
local provider: ((string) -> { string })? = nil
local liveProvider: ((string) -> { string })? = nil
local liveText: TextLabel? = nil
local gui: ScreenGui? = nil

function PurchaseOddsController.SetLiveProvider(callback: () -> { string })
	liveProvider = function(_key: string) return callback() end
	if liveText and liveText.Parent then liveText.Text = table.concat(callback(), "\n") end
end

function PurchaseOddsController.Close()
	if gui then gui:Destroy(); gui = nil end
	liveText = nil
end

function PurchaseOddsController.SetProvider(callback: (string) -> { string })
	provider = callback
end

function PurchaseOddsController.Show(key: string)
	local viewingLive = key == "Live"
	if not viewingLive and key ~= "AutoFish" and key ~= "ExclusiveDragonRod" then
		Net.FireServer(Net.ClientToServer.PromptGamepass, key)
		return
	end
	local build: ((string) -> { string })? = provider
	if viewingLive then build = liveProvider end
	if not build then return end -- no purchase while the full initial snapshot is unavailable
	PurchaseOddsController.Close()
	local screen = Instance.new("ScreenGui")
	screen.Name = "PurchaseOddsPreview"
	screen.DisplayOrder = 100
	screen.ResetOnSpawn = false
	screen.Parent = Players.LocalPlayer:WaitForChild("PlayerGui")
	gui = screen
	local backdrop = Instance.new("TextButton")
	backdrop.Text = ""
	backdrop.Size = UDim2.fromScale(1, 1)
	backdrop.BackgroundColor3 = Color3.new(0, 0, 0)
	backdrop.BackgroundTransparency = 0.25
	backdrop.Modal = true
	backdrop.Parent = screen
	local panel = Instance.new("Frame")
	panel.AnchorPoint = Vector2.new(0.5, 0.5)
	panel.Position = UDim2.fromScale(0.5, 0.5)
	panel.Size = UDim2.fromScale(0.9, 0.82)
	panel.BackgroundColor3 = Theme.Colors.PanelBg
	panel.Parent = screen
	Theme.AddCorner(panel, 12)
	local title = Instance.new("TextLabel")
	title.Size = UDim2.new(1, -20, 0, 42)
	title.Position = UDim2.fromOffset(10, 0)
	title.Text = if viewingLive then "Fishing odds — current state" else GamepassesConfig.ByKey[key].name .. " — Result odds"
	title.TextColor3 = Theme.Colors.TextPrimary
	title.BackgroundTransparency = 1
	title.Font = Theme.FontTitle
	title.TextSize = 17
	title.Parent = panel
	local scroll = Instance.new("ScrollingFrame")
	scroll.Position = UDim2.fromOffset(10, 44)
	scroll.Size = UDim2.new(1, -20, 1, -104)
	scroll.BackgroundTransparency = 1
	scroll.AutomaticCanvasSize = Enum.AutomaticSize.Y
	scroll.CanvasSize = UDim2.new()
	scroll.Parent = panel
	local text = Instance.new("TextLabel")
	text.Name = "OddsText"
	text.Size = UDim2.new(1, -16, 0, 0)
	text.AutomaticSize = Enum.AutomaticSize.Y
	text.Text = table.concat(build(key), "\n")
	text.TextColor3 = Theme.Colors.TextPrimary
	text.BackgroundTransparency = 1
	text.TextWrapped = true
	text.TextXAlignment = Enum.TextXAlignment.Left
	text.TextYAlignment = Enum.TextYAlignment.Top
	text.Font = Theme.FontBody
	text.TextSize = 13
	text.Parent = scroll
	if viewingLive then liveText = text end
	Theme.CreateButton(panel, "Cancel", "Back", UDim2.new(0.30, 0, 0, 38), UDim2.new(0.02, 0, 1, -48), Theme.Colors.CardBg, PurchaseOddsController.Close)
	if viewingLive then return end
	Theme.CreateButton(panel, "Continue", "Continue to purchase", UDim2.new(0.64, 0, 0, 38), UDim2.new(0.34, 0, 1, -48), Theme.Colors.Success, function()
		screen:Destroy(); gui = nil
		Net.FireServer(Net.ClientToServer.PromptGamepass, key)
	end)
end

function PurchaseOddsController.ShowLive()
	PurchaseOddsController.Show("Live")
end

return PurchaseOddsController
