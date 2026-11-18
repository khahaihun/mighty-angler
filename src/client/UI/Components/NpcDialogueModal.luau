--!strict
-- NpcDialogueModal.luau: Khung hoi thoai NPC da lua chon kieu Fisch + hieu ung thu nhe FOV Camera

local ReplicatedStorage = game:GetService("ReplicatedStorage")

local Shared = ReplicatedStorage:WaitForChild("Shared")
local Net = require(Shared:WaitForChild("Net"))

local Theme = require(script.Parent.Parent.Theme)
local CameraFocusController = require(script.Parent.Parent.Parent.Controllers.CameraFocusController)

export type DialogueHandlers = {
	OpenPanel: (panelKey: string) -> (),
	OpenBagSelectMode: (() -> ())?,
	OpenEnchantOrBounty: ((tabName: string) -> ())?,
	SellHeldFish: (() -> ())?,
	AppraiseHeldFish: (() -> ())?,
}

type ChoiceOption = {
	label: string,
	color: Color3,
	onPick: () -> (),
}

local NpcDialogueModal = {}

local rootFrame: Frame? = nil
local speakerLbl: TextLabel? = nil
local speechLbl: TextLabel? = nil
local choicesHolder: Frame? = nil
local handlersRef: DialogueHandlers? = nil

local function setCameraTalkZoom(talking: boolean)
	CameraFocusController.SetTalking(talking)
end

function NpcDialogueModal.Close()
	if rootFrame and rootFrame.Visible then
		rootFrame.Visible = false
		setCameraTalkZoom(false)
	end
end

function NpcDialogueModal.IsOpen(): boolean
	return (rootFrame ~= nil) and rootFrame.Visible
end

local function populateChoices(options: { ChoiceOption })
	local holder = choicesHolder
	if not holder then
		return
	end
	for _, ch in ipairs(holder:GetChildren()) do
		if ch:IsA("GuiObject") then
			ch:Destroy()
		end
	end

	for idx, opt in ipairs(options) do
		local btn = Theme.CreateButton(
			holder,
			"Opt_" .. tostring(idx),
			string.format("[%d]  %s", idx, opt.label),
			UDim2.new(1, 0, 0, 36),
			UDim2.new(),
			opt.color,
			opt.onPick
		)
		btn.LayoutOrder = idx
		btn.TextSize = 15
		btn.TextXAlignment = Enum.TextXAlignment.Left
		btn.ZIndex = 48

		local pad = Instance.new("UIPadding")
		pad.PaddingLeft = UDim.new(0, 14)
		pad.Parent = btn
	end
end

function NpcDialogueModal.OpenForRole(role: string)
	local f = rootFrame
	local h = handlersRef
	if not f or not h or not speakerLbl or not speechLbl then
		return
	end

	if role == "Merchant" then
		speakerLbl.Text = "⚓ Captain Barnaby — Fish Merchant"
		speakerLbl.TextColor3 = Theme.Colors.Gold
		speechLbl.Text = "\"Ahoy angler! Fresh catch from the lagoon? Locked & Trophy fish are always kept safe!\""
		populateChoices({
			{
				label = "💰 Sell all UNLOCKED fish in my Bag",
				color = Theme.Colors.Success,
				onPick = function()
					NpcDialogueModal.Close()
					Net.FireServer(Net.ClientToServer.SellAllFish)
				end,
			},
			{
				label = "✋ Sell the fish I'm holding right now",
				color = Theme.Colors.Gold,
				onPick = function()
					NpcDialogueModal.Close()
					if h.SellHeldFish then
						h.SellHeldFish()
					end
				end,
			},
			{
				label = "☑️ Let me pick specific fish to sell",
				color = Theme.Colors.Primary,
				onPick = function()
					NpcDialogueModal.Close()
					if h.OpenBagSelectMode then
						h.OpenBagSelectMode()
					else
						h.OpenPanel("Bag")
					end
				end,
			},
			{
				label = "👋 Nevermind, keep my fish safe",
				color = Theme.Colors.CardBg,
				onPick = NpcDialogueModal.Close,
			},
		})
	elseif role == "Shop" then
		speakerLbl.Text = "🎣 Master Kaito — Rod & Gear Crafter"
		speakerLbl.TextColor3 = Color3.fromRGB(98, 224, 255)
		speechLbl.Text = "\"A sturdier rod handles heavier titans, faster bites, and steadier lines!\""
		populateChoices({
			{
				label = "🛒 Browse Fishing Rods, Bait & Gym Gear",
				color = Theme.Colors.Warning,
				onPick = function()
					NpcDialogueModal.Close()
					h.OpenPanel("Shop")
				end,
			},
			{
				label = "🔮 Visit Ancient Rod Enchanting Altar (Exclusive Rods)",
				color = Theme.Colors.Gems,
				onPick = function()
					NpcDialogueModal.Close()
					if h.OpenEnchantOrBounty then
						h.OpenEnchantOrBounty("Enchant")
					else
						h.OpenPanel("Shop")
					end
				end,
			},
			{
				label = "👋 See you later",
				color = Theme.Colors.CardBg,
				onPick = NpcDialogueModal.Close,
			},
		})
	elseif role == "Collector" then
		speakerLbl.Text = "🔍 Old Man Finn — Appraiser & Collector"
		speakerLbl.TextColor3 = Color3.fromRGB(122, 255, 186)
		speechLbl.Text = "\"Hold a prized fish in your hands to Appraise its size, or turn in rare catches for Relics & Gems!\""
		populateChoices({
			{
				label = "⚖️ Appraise the fish I'm holding (Reroll Size & Mutation!)",
				color = Theme.Colors.Success,
				onPick = function()
					if h.AppraiseHeldFish then
						h.AppraiseHeldFish()
					end
				end,
			},
			{
				label = "📜 View Fish Bounty Contracts (Trade Fish for Gems & Relics)",
				color = Theme.Colors.Gold,
				onPick = function()
					NpcDialogueModal.Close()
					if h.OpenEnchantOrBounty then
						h.OpenEnchantOrBounty("Bounties")
					else
						h.OpenPanel("Progress")
					end
				end,
			},
			{
				label = "👋 Goodbye",
				color = Theme.Colors.CardBg,
				onPick = NpcDialogueModal.Close,
			},
		})
	else
		speakerLbl.Text = "🏋️ Coach Atlas — Head Gym Trainer"
		speakerLbl.TextColor3 = Theme.Colors.Strength
		speechLbl.Text = "\"Pump iron to wield heavier rods, widen your Catch Bar, and unlock glowing Rank Auras!\""
		populateChoices({
			{
				label = "🥊 Upgrade Gym Gear Multipliers",
				color = Theme.Colors.Strength,
				onPick = function()
					NpcDialogueModal.Close()
					h.OpenPanel("Shop")
				end,
			},
			{
				label = "🏆 View Rebirth & Trophy Milestones",
				color = Theme.Colors.Primary,
				onPick = function()
					NpcDialogueModal.Close()
					h.OpenPanel("Progress")
				end,
			},
			{
				label = "👋 Back to training!",
				color = Theme.Colors.CardBg,
				onPick = NpcDialogueModal.Close,
			},
		})
	end

	f.Visible = true
	setCameraTalkZoom(true)
end

function NpcDialogueModal.Mount(rootGui: ScreenGui, handlers: DialogueHandlers)
	handlersRef = handlers

	local frame = Instance.new("Frame")
	frame.Name = "NpcDialogueModal"
	frame.AnchorPoint = Vector2.new(0.5, 1)
	frame.Position = UDim2.new(0.5, 0, 1, -96)
	frame.Size = UDim2.fromOffset(540, 258)
	frame.BackgroundColor3 = Theme.Colors.PanelBg
	frame.Visible = false
	frame.ZIndex = 45
	frame.Parent = rootGui
	Theme.AddCorner(frame, 16)
	Theme.AddStroke(frame, Theme.Colors.Gold, 3)
	rootFrame = frame

	local spk = Instance.new("TextLabel")
	spk.Size = UDim2.new(1, -64, 0, 28)
	spk.Position = UDim2.fromOffset(16, 10)
	spk.BackgroundTransparency = 1
	spk.Font = Theme.FontTitle
	spk.TextSize = 20
	spk.TextXAlignment = Enum.TextXAlignment.Left
	spk.TextColor3 = Theme.Colors.Gold
	spk.ZIndex = 46
	spk.Parent = frame
	Theme.AddTextStroke(spk, 1.8)
	speakerLbl = spk

	local closeBtn = Theme.CreateButton(frame, "CloseBtn", "X", UDim2.fromOffset(32, 32), UDim2.new(1, -42, 0, 8), Theme.Colors.Danger, NpcDialogueModal.Close)
	closeBtn.ZIndex = 48

	local speech = Instance.new("TextLabel")
	speech.Size = UDim2.new(1, -32, 0, 40)
	speech.Position = UDim2.fromOffset(16, 40)
	speech.BackgroundTransparency = 1
	speech.Font = Theme.FontBody
	speech.TextSize = 14
	speech.TextWrapped = true
	speech.TextXAlignment = Enum.TextXAlignment.Left
	speech.TextColor3 = Theme.Colors.TextPrimary
	speech.ZIndex = 46
	speech.Parent = frame
	speechLbl = speech

	local holder = Instance.new("Frame")
	holder.Size = UDim2.new(1, -32, 1, -94)
	holder.Position = UDim2.fromOffset(16, 84)
	holder.BackgroundTransparency = 1
	holder.ZIndex = 46
	holder.Parent = frame
	choicesHolder = holder

	local layout = Instance.new("UIListLayout")
	layout.Padding = UDim.new(0, 6)
	layout.SortOrder = Enum.SortOrder.LayoutOrder
	layout.Parent = holder
end

return NpcDialogueModal
