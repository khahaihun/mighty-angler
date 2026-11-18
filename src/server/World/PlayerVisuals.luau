--!strict
-- PlayerVisuals.luau: Overhead Rank Title, Vong Aura phat sang theo Strength/Rebirth & Gan Qua Ta 3D that vao tay khi tap Gym

local Players = game:GetService("Players")
local ReplicatedStorage = game:GetService("ReplicatedStorage")

local Shared = ReplicatedStorage:WaitForChild("Shared")
local Util = require(Shared:WaitForChild("Util"))
local RanksConfig = require(Shared:WaitForChild("Config"):WaitForChild("RanksConfig"))
local IslandsRegistry = require(Shared:WaitForChild("Config"):WaitForChild("Islands"))
local RodAndWeightBuilder = require(Shared:WaitForChild("ModelBuilders"):WaitForChild("RodAndWeightBuilder"))

local DataService = require(script.Parent.Parent.Services.DataService)
local CurrencyService = require(script.Parent.Parent.Services.CurrencyService)
local ShopAndItemsService = require(script.Parent.Parent.Services.ShopAndItemsService)

local PlayerVisuals = {}

local gymWeightClearTicket: { [Player]: number } = {}

local function getHandParts(char: Model): (BasePart?, BasePart?)
	local r = char:FindFirstChild("RightHand") or char:FindFirstChild("Right Arm")
	local l = char:FindFirstChild("LeftHand") or char:FindFirstChild("Left Arm")
	local rPart = if r and r:IsA("BasePart") then r else nil
	local lPart = if l and l:IsA("BasePart") then l else nil
	return lPart, rPart
end

function PlayerVisuals.RefreshRankAndAura(player: Player)
	local profile = DataService.Get(player)
	local char = player.Character
	if not profile or not char then
		return
	end
	local head = char:FindFirstChild("Head")
	local root = char:FindFirstChild("UpperTorso") or char:FindFirstChild("Torso") or char:FindFirstChild("HumanoidRootPart")
	if not (head and head:IsA("BasePart")) or not (root and root:IsA("BasePart")) then
		return
	end

	local hum = char:FindFirstChildOfClass("Humanoid")
	if hum then
		hum.DisplayDistanceType = Enum.HumanoidDisplayDistanceType.None
	end

	local rank = RanksConfig.GetForStrength(profile.strength)

	-- 1. Overhead Rank Title + Rebirth + Strength Billboard
	local bb = head:FindFirstChild("AnglerRankTag") :: BillboardGui?
	if not bb then
		local created = Instance.new("BillboardGui")
		created.Name = "AnglerRankTag"
		created.Size = UDim2.fromOffset(220, 56)
		created.StudsOffset = Vector3.new(0, 2.75, 0)
		created.MaxDistance = 85
		created.Adornee = head
		created.Parent = head
		bb = created

		local rankLbl = Instance.new("TextLabel")
		rankLbl.Name = "RankLine"
		rankLbl.Size = UDim2.new(1, 0, 0, 26)
		rankLbl.BackgroundTransparency = 1
		rankLbl.Font = Enum.Font.FredokaOne
		rankLbl.TextScaled = true
		rankLbl.Parent = created
		local s1 = Instance.new("UIStroke")
		s1.Thickness = 1.8
		s1.Color = Color3.fromRGB(14, 18, 30)
		s1.Parent = rankLbl

		local nameLbl = Instance.new("TextLabel")
		nameLbl.Name = "PlayerLine"
		nameLbl.Size = UDim2.new(1, 0, 0, 22)
		nameLbl.Position = UDim2.fromOffset(0, 27)
		nameLbl.BackgroundTransparency = 1
		nameLbl.Font = Enum.Font.GothamBold
		nameLbl.TextScaled = true
		nameLbl.TextColor3 = Color3.fromRGB(245, 248, 255)
		nameLbl.Parent = created
		local s2 = Instance.new("UIStroke")
		s2.Thickness = 1.5
		s2.Color = Color3.fromRGB(14, 18, 30)
		s2.Parent = nameLbl
	end

	if bb then
		local rLine = bb:FindFirstChild("RankLine")
		local pLine = bb:FindFirstChild("PlayerLine")
		local rebBadge = if profile.rebirths > 0 then string.format(" [★%d]", profile.rebirths) else ""
		if rLine and rLine:IsA("TextLabel") then
			rLine.Text = rank.title .. rebBadge
			rLine.TextColor3 = rank.color
		end
		if pLine and pLine:IsA("TextLabel") then
			pLine.Text = string.format("%s • 💪 %s", player.DisplayName, Util.FormatNumber(profile.strength))
		end
	end

	-- 2. Hào quang Aura hat sang quanh co the theo moc Rank & Rebirth
	local totalRate = rank.auraRate + math.min(24, profile.rebirths * 6)
	local existingAura = root:FindFirstChild("RankAuraEmitter") :: ParticleEmitter?
	if totalRate <= 0 then
		if existingAura then
			existingAura.Enabled = false
		end
		return
	end

	if not existingAura then
		local em = Instance.new("ParticleEmitter")
		em.Name = "RankAuraEmitter"
		em.LightEmission = 1
		em.Size = NumberSequence.new({
			NumberSequenceKeypoint.new(0, 0.25),
			NumberSequenceKeypoint.new(0.5, 0.55),
			NumberSequenceKeypoint.new(1, 0),
		})
		em.Transparency = NumberSequence.new({
			NumberSequenceKeypoint.new(0, 0.25),
			NumberSequenceKeypoint.new(1, 1),
		})
		em.Lifetime = NumberRange.new(0.85, 1.45)
		em.Speed = NumberRange.new(2.2, 4.5)
		em.SpreadAngle = Vector2.new(180, 35)
		em.Parent = root
		existingAura = em
	end
	if existingAura then
		existingAura.Enabled = true
		existingAura.Color = ColorSequence.new(rank.color)
		existingAura.Rate = totalRate
	end
end

function PlayerVisuals.ShowGymWeightsForRep(player: Player, stationType: string)
	local profile = DataService.Get(player)
	local char = player.Character
	if not profile or not char then
		return
	end

	local nextTicket = (gymWeightClearTicket[player] or 0) + 1
	gymWeightClearTicket[player] = nextTicket

	local existing = char:FindFirstChild("ActiveGymWeights")
	local currentKind = if existing then existing:GetAttribute("StationType") else nil

	if not existing or currentKind ~= stationType then
		if existing then
			existing:Destroy()
		end
		local rod = char:FindFirstChild("EquippedFishingRod")
		if rod then
			rod:Destroy()
		end
		local flex = char:FindFirstChild("HeldFlexFish")
		if flex then
			flex:Destroy()
		end

		local lHand, rHand = getHandParts(char)
		local isl = IslandsRegistry.Get(profile.currentIsland)
		local scale = 0.92 + (isl.id - 1) * 0.14

		local holder = Instance.new("Folder")
		holder.Name = "ActiveGymWeights"
		holder:SetAttribute("StationType", stationType)
		holder.Parent = char

		if stationType == "Dumbbells" then
			for _, hand in ipairs({ lHand, rHand }) do
				if hand then
					local db, bar = RodAndWeightBuilder.BuildHandheldDumbbell(isl.theme.accentColor, scale)
					local isR6Arm = (hand.Name == "Right Arm" or hand.Name == "Left Arm")
					local yOffset = if isR6Arm then -0.95 else -0.18
					local targetCf = hand.CFrame * CFrame.new(0, yOffset, 0)
					local inv = bar.CFrame:Inverse()
					for _, d in ipairs(db:GetDescendants()) do
						if d:IsA("BasePart") and d ~= bar then
							d.CFrame = targetCf * (inv * d.CFrame)
						end
					end
					bar.CFrame = targetCf
					db.Parent = holder
					local w = Instance.new("WeldConstraint")
					w.Part0 = hand
					w.Part1 = bar
					w.Parent = bar
				end
			end
		elseif stationType == "BenchPress" then
			local torso = char:FindFirstChild("UpperTorso") or char:FindFirstChild("Torso") or char:FindFirstChild("HumanoidRootPart")
			if torso and torso:IsA("BasePart") then
				local bb, shaft = RodAndWeightBuilder.BuildHandheldBarbell(isl.theme.accentColor, scale)
				local targetCf = torso.CFrame * CFrame.new(0, 0.52, -1.42)
				local inv = shaft.CFrame:Inverse()
				for _, d in ipairs(bb:GetDescendants()) do
					if d:IsA("BasePart") and d ~= shaft then
						d.CFrame = targetCf * (inv * d.CFrame)
					end
				end
				shaft.CFrame = targetCf
				bb.Parent = holder
				local w = Instance.new("WeldConstraint")
				w.Part0 = torso
				w.Part1 = shaft
				w.Parent = shaft
			end
		end
	end

	task.delay(1.85, function()
		if gymWeightClearTicket[player] ~= nextTicket then
			return
		end
		if player.Character then
			local wFolder = player.Character:FindFirstChild("ActiveGymWeights")
			if wFolder then
				wFolder:Destroy()
			end
			ShopAndItemsService.SyncCharacterHandVisuals(player)
		end
	end)
end

function PlayerVisuals.Init()
	local function setupForPlayer(player: Player)
		if player.Character then
			PlayerVisuals.RefreshRankAndAura(player)
		end
		player.CharacterAdded:Connect(function()
			task.wait(0.3)
			PlayerVisuals.RefreshRankAndAura(player)
		end)
	end

	DataService.OnProfileLoaded(function(player: Player)
		setupForPlayer(player)
	end)

	CurrencyService.OnStatIncremented(function(player: Player, statName: string)
		if statName == "strength" then
			PlayerVisuals.RefreshRankAndAura(player)
		end
	end)

	Players.PlayerRemoving:Connect(function(player: Player)
		gymWeightClearTicket[player] = nil
	end)
end

return PlayerVisuals
