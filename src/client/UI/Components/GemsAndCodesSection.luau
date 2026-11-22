--!strict
-- GemsAndCodesSection.luau: Muc "Gems 💎" trong Shop (5 goi nap Robux) & o nhap Ma Qua Tang trong Settings.
-- Client chi gui yeu cau; Server quyet dinh moi lan cong Gems/phan thuong.

local ReplicatedStorage = game:GetService("ReplicatedStorage")
local Shared = ReplicatedStorage:WaitForChild("Shared")
local Net = require(Shared:WaitForChild("Net"))
local Util = require(Shared:WaitForChild("Util"))
local DevProductsConfig = require(Shared:WaitForChild("Config"):WaitForChild("DevProductsConfig"))

local Theme = require(script.Parent.Parent.Theme)
local ViewportCard = require(script.Parent.ViewportCard)

local GemsAndCodesSection = {}

type HeaderSetter = (string, string, Color3, string?, Color3?, (() -> ())?) -> ()

local MAX_INPUT_CHARS = 32
local selectedKey = DevProductsConfig.List[1].key
local codeDraft = ""
local statusLabel: TextLabel? = nil
local resultHooked = false

local function promptBuy(key: string)
	Net.FireServer(Net.ClientToServer.PromptDevProduct, key)
end

function GemsAndCodesSection.FillShopSpecs(specs: { ViewportCard.CardVisualSpec }, setHeader: HeaderSetter, rerender: () -> ())
	local sel = DevProductsConfig.ByKey[selectedKey] or DevProductsConfig.List[1]
	setHeader(
		string.format("💎 %s — %s Gems (R$ %d)", sel.name, Util.FormatNumber(sel.gems), sel.robuxDisplay),
		"Gems hatch the Gem Egg, roll Enchants & unlock Bounty rods. Gems are added only after your save is confirmed — never lost, never doubled!",
		Theme.Colors.Gems,
		"BUY R$ " .. tostring(sel.robuxDisplay),
		Theme.Colors.Success,
		function() promptBuy(sel.key) end
	)
	for idx, product in ipairs(DevProductsConfig.List) do
		local isSel = product.key == sel.key
		table.insert(specs, {
			key = "gems_" .. product.key, order = idx, title = product.name,
			subtitle = Util.FormatNumber(product.gems) .. " Gems",
			footerText = if isSel then ("BUY R$ " .. tostring(product.robuxDisplay)) else ("R$ " .. tostring(product.robuxDisplay)),
			footerColor = if isSel then Theme.Colors.Success else Theme.Colors.Warning,
			strokeColor = if isSel then Theme.Colors.Gold else product.color,
			bgColor = if isSel then Theme.Colors.CardOwned else Theme.Colors.CardBg,
			topLeftBadge = product.badge or "GEMS", topLeftColor = product.color,
			modelSignature = "Gems_" .. product.key,
			modelSpec = { kind = "Gear", primaryColor = product.color, secondaryColor = Theme.Colors.Gems },
			onActivate = function()
				if selectedKey ~= product.key then
					selectedKey = product.key
					rerender()
				else
					promptBuy(product.key)
				end
			end,
		})
	end
end

local function setStatus(text: string, color: Color3)
	local label = statusLabel
	if label and label.Parent then
		label.Text = text
		label.TextColor3 = color
	end
end

local function hookResults()
	if resultHooked then
		return
	end
	resultHooked = true
	Net.OnClientEvent(Net.ServerToClient.CodeRedeemResult, function(payload: any)
		if type(payload) ~= "table" then
			return
		end
		if payload.ok == true then
			codeDraft = ""
		end
		setStatus(tostring(payload.message or ""), if payload.ok == true then Theme.Colors.Success else Theme.Colors.Danger)
	end)
end

function GemsAndCodesSection.MountCodeBox(body: GuiObject, order: number): Frame
	hookResults()
	local card = Instance.new("Frame")
	card.Name = "RedeemCodeCard"
	card.Size = UDim2.new(1, 0, 0, 100)
	card.BackgroundColor3 = Theme.Colors.CardBg
	card.LayoutOrder = order
	card.ZIndex = 22
	card.Parent = body
	Theme.AddCorner(card, 10)
	Theme.AddStroke(card, Theme.Colors.Gems, 2)

	local title = Instance.new("TextLabel")
	title.Size = UDim2.new(1, -24, 0, 24)
	title.Position = UDim2.fromOffset(12, 6)
	title.BackgroundTransparency = 1
	title.Font = Theme.FontTitle
	title.TextSize = 15
	title.TextXAlignment = Enum.TextXAlignment.Left
	title.TextColor3 = Theme.Colors.Gems
	title.Text = "🎟️ Redeem a Code"
	title.ZIndex = 23
	title.Parent = card
	Theme.AddTextStroke(title, 1.4)

	local box = Instance.new("TextBox")
	box.Name = "CodeInput"
	box.Size = UDim2.new(1, -168, 0, 34)
	box.Position = UDim2.fromOffset(12, 32)
	box.BackgroundColor3 = Theme.Colors.PanelInner
	box.Font = Theme.FontBody
	box.TextSize = 14
	box.TextColor3 = Theme.Colors.TextPrimary
	box.PlaceholderText = "Enter code (e.g. RELEASE)"
	box.PlaceholderColor3 = Theme.Colors.TextMuted
	box.ClearTextOnFocus = false
	box.Text = codeDraft
	box.ZIndex = 23
	box.Parent = card
	Theme.AddCorner(box, 8)
	Theme.AddStroke(box, Theme.Colors.StrokeLight, 1.5)
	box:GetPropertyChangedSignal("Text"):Connect(function()
		if #box.Text > MAX_INPUT_CHARS then
			box.Text = string.sub(box.Text, 1, MAX_INPUT_CHARS)
		end
		codeDraft = box.Text
	end)

	local status = Instance.new("TextLabel")
	status.Name = "CodeStatus"
	status.Size = UDim2.new(1, -24, 0, 24)
	status.Position = UDim2.fromOffset(12, 70)
	status.BackgroundTransparency = 1
	status.Font = Theme.FontBody
	Theme.FitText(status, 13, 13)
	status.TextWrapped = true
	status.TextXAlignment = Enum.TextXAlignment.Left
	status.TextColor3 = Theme.Colors.TextMuted
	status.Text = "Codes are not case-sensitive. Each code works once per player."
	status.ZIndex = 23
	status.Parent = card
	statusLabel = status

	local function submit()
		local text = box.Text
		if (string.gsub(text, "%s+", "")) == "" then
			setStatus("Type a code first!", Theme.Colors.Warning)
			return
		end
		setStatus("Checking code...", Theme.Colors.TextMuted)
		Net.FireServer(Net.ClientToServer.RedeemCode, text)
	end
	box.FocusLost:Connect(function(enterPressed: boolean)
		if enterPressed then submit() end
	end)
	local btn = Theme.CreateButton(card, "RedeemBtn", "REDEEM", UDim2.fromOffset(128, 36), UDim2.new(1, -140, 0, 31), Theme.Colors.Gems, submit)
	btn.TextSize = 14
	btn.ZIndex = 24
	return card
end

return GemsAndCodesSection
