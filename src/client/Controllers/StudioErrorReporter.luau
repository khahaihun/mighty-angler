--!strict
-- StudioErrorReporter.luau: Tu dong hien bang do tren man hinh Studio neu co loi runtime (khoi mo cua so Output)

local LogService = game:GetService("LogService")
local RunService = game:GetService("RunService")

local Theme = require(script.Parent.Parent.UI.Theme)

local StudioErrorReporter = {}

function StudioErrorReporter.Mount(rootGui: ScreenGui)
	if not RunService:IsStudio() then
		return
	end

	local banner = Instance.new("Frame")
	banner.Name = "StudioErrorBanner"
	banner.AnchorPoint = Vector2.new(0.5, 0)
	banner.Position = UDim2.new(0.5, 0, 0, 58)
	banner.Size = UDim2.fromOffset(560, 56)
	banner.BackgroundColor3 = Color3.fromRGB(148, 28, 36)
	banner.Visible = false
	banner.ZIndex = 90
	banner.Parent = rootGui
	Theme.AddCorner(banner, 10)
	Theme.AddStroke(banner, Color3.fromRGB(255, 118, 118), 2)

	local msgLbl = Instance.new("TextLabel")
	msgLbl.Name = "ErrorText"
	msgLbl.Size = UDim2.new(1, -86, 1, -8)
	msgLbl.Position = UDim2.fromOffset(10, 4)
	msgLbl.BackgroundTransparency = 1
	msgLbl.Font = Theme.FontBody
	msgLbl.TextSize = 13
	msgLbl.TextColor3 = Color3.fromRGB(255, 240, 240)
	msgLbl.TextXAlignment = Enum.TextXAlignment.Left
	msgLbl.TextWrapped = true
	msgLbl.Text = ""
	msgLbl.ZIndex = 91
	msgLbl.Parent = banner

	Theme.CreateButton(
		banner,
		"DismissBtn",
		"HIDE",
		UDim2.fromOffset(62, 34),
		UDim2.new(1, -72, 0.5, -17),
		Color3.fromRGB(88, 22, 28),
		function()
			banner.Visible = false
		end
	).ZIndex = 92

	LogService.MessageOut:Connect(function(message: string, messageType: Enum.MessageType)
		if messageType == Enum.MessageType.MessageError then
			msgLbl.Text = "⚠️ STUDIO ERROR: " .. string.sub(message, 1, 180)
			banner.Visible = true
		end
	end)
end

return StudioErrorReporter
