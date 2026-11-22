--!strict
-- Canh bao quyen luu rieng, khong bi dong su kien/buff ghi de.
local Banner = {}
local label: TextLabel? = nil
local readOnly, loading, retrying, version = true, true, false, -1

local function render()
	if not label then return end
	label.Visible = readOnly or loading
	label.Text = if loading and retrying then "Your save is not ready yet (your last server may still be saving it).\nRetrying automatically — please stay, no need to rejoin."
		elseif loading then "Loading your save... Actions are locked until loading finishes."
		else "SAVE PROTECTED — READ-ONLY MODE\nSpending, trading and leaderboard writes are disabled. Rejoin to retry."
end

function Banner.Mount(root: ScreenGui, theme: any)
	local warning = Instance.new("TextLabel")
	warning.Name = "ProfileAccessWarning"
	warning.AnchorPoint = Vector2.new(0.5, 0)
	warning.Position = UDim2.new(0.5, 0, 0, 94)
	warning.Size = UDim2.new(1, -28, 0, 40)
	warning.AutomaticSize = Enum.AutomaticSize.Y
	warning.BackgroundColor3 = theme.Colors.Danger
	warning.BackgroundTransparency = 0.15
	warning.Font = theme.FontBody
	warning.TextSize = 13
	warning.TextWrapped = true
	warning.TextColor3 = Color3.fromRGB(255, 238, 238)
	warning.ZIndex = 20
	warning.Parent = root
	theme.AddCorner(warning, 8)
	label = warning
	render()
end

function Banner.Update(safeReadOnly: boolean, isLoading: boolean, incomingVersion: number, isRetrying: boolean?)
	if incomingVersion < version then return end
	version, readOnly, loading, retrying = incomingVersion, safeReadOnly, isLoading, isRetrying == true
	render()
end

return Banner
