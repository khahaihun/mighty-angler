--!strict
-- PetAndFishVisuals.luau: Ca 3D Chi Tiet Cao vang len khi cau dinh & Ca cam tren 2 tay khoe khap dao (dung FishModelBuilder)

local Debris = game:GetService("Debris")
local ReplicatedStorage = game:GetService("ReplicatedStorage")
local Workspace = game:GetService("Workspace")

local Shared = ReplicatedStorage:WaitForChild("Shared")
local Types = require(Shared:WaitForChild("Types"))
local Util = require(Shared:WaitForChild("Util"))
local GameConfig = require(Shared:WaitForChild("Config"):WaitForChild("GameConfig"))
local IslandsRegistry = require(Shared:WaitForChild("Config"):WaitForChild("Islands"))
local FishModelBuilder = require(Shared:WaitForChild("ModelBuilders"):WaitForChild("FishModelBuilder"))

local PetAndFishVisuals = {}

local fishLookup: { [string]: Types.FishDef } = {}
for _, isl in ipairs(IslandsRegistry.List) do
	for _, f in ipairs(isl.fishPool) do
		fishLookup[f.id] = f
	end
end

function PetAndFishVisuals.SpawnCaughtFishLeap(
	player: Player,
	startPos: Vector3,
	fishDef: Types.FishDef,
	mutation: Types.MutationName
)
	local character = player.Character
	local root = if character then character:FindFirstChild("HumanoidRootPart") else nil
	if not (root and root:IsA("BasePart")) then
		return
	end

	local fishModel = FishModelBuilder.BuildFish(fishDef, mutation, false)
	local sc = math.clamp(fishDef.scale, 0.75, 2.35)
	FishModelBuilder.PositionOrScaleModel(fishModel, CFrame.new(startPos), sc, nil)
	fishModel.Parent = Workspace

	local primary = fishModel.PrimaryPart
	local relOffsets: { [BasePart]: CFrame } = {}
	if primary then
		local inv = primary.CFrame:Inverse()
		for _, d in ipairs(fishModel:GetDescendants()) do
			if d:IsA("BasePart") and d ~= primary then
				relOffsets[d] = inv * d.CFrame
			end
		end
	end

	task.spawn(function()
		local duration = 0.72
		local elapsed = 0
		while elapsed < duration and fishModel.Parent ~= nil and primary ~= nil do
			local dt = task.wait()
			elapsed += dt
			local alpha = math.clamp(elapsed / duration, 0, 1)
			local endPos = if root.Parent then (root.Position + Vector3.new(0, 2.5, 0)) else (startPos + Vector3.new(0, 4, 0))
			local curPos = startPos:Lerp(endPos, alpha) + Vector3.new(0, math.sin(alpha * math.pi) * 7.8, 0)
			local spinCf = CFrame.lookAt(curPos, endPos + Vector3.new(0, 0.5, 0)) * CFrame.Angles(math.rad(alpha * 360), 0, 0)
			primary.CFrame = spinCf
			for part, rel in pairs(relOffsets) do
				if part.Parent then
					part.CFrame = spinCf * rel
				end
			end
		end
		if fishModel.Parent then
			fishModel:Destroy()
		end
	end)
	Debris:AddItem(fishModel, 1.5)
end

function PetAndFishVisuals.EquipHeldFishOnCharacter(player: Player, entry: Types.CaughtFish?)
	local char = player.Character
	if not char then
		return
	end
	local old = char:FindFirstChild("HeldFlexFish")
	if old then
		old:Destroy()
	end
	char:SetAttribute("HoldingFlexFish", entry ~= nil)
	if not entry then
		return
	end

	local oldWeights = char:FindFirstChild("ActiveGymWeights")
	if oldWeights then
		oldWeights:Destroy()
	end

	local def = fishLookup[entry.fishId]
	local torso = char:FindFirstChild("UpperTorso") or char:FindFirstChild("Torso") or char:FindFirstChild("HumanoidRootPart")
	if not def or not (torso and torso:IsA("BasePart")) then
		return
	end

	local tierScale = 1.0
	for _, st in ipairs(GameConfig.SizeTiers) do
		if st.name == entry.sizeTier then
			tierScale = st.scaleMult
			break
		end
	end
	local sc = math.clamp(def.scale * tierScale, 0.82, 3.85)
	local m = FishModelBuilder.BuildFish(def, entry.mutation, false)
	m.Name = "HeldFlexFish"
	local centerCf = torso.CFrame * CFrame.new(0, 0.52, -(1.38 + sc * 0.42)) * CFrame.Angles(0, math.rad(90), 0)
	FishModelBuilder.PositionOrScaleModel(m, centerCf, sc, torso)
	m.Parent = char

	if m.PrimaryPart then
		local bb = Instance.new("BillboardGui")
		bb.Size = UDim2.fromOffset(195, 38)
		bb.StudsOffset = Vector3.new(0, 1.15 + sc * 0.55, 0)
		bb.MaxDistance = 52
		bb.Adornee = m.PrimaryPart
		bb.Parent = m.PrimaryPart

		local lbl = Instance.new("TextLabel")
		lbl.Size = UDim2.fromScale(1, 1)
		lbl.BackgroundTransparency = 1
		lbl.Font = Enum.Font.FredokaOne
		lbl.TextScaled = true
		local mutTag = if entry.mutation ~= "None" then ("[" .. entry.mutation .. "] ") else ""
		local tierTag = if entry.sizeTier ~= "Normal" then (entry.sizeTier .. " ") else ""
		local trophyTag = if entry.soulbound then "🏆 " else ""
		lbl.Text = string.format("%s%s%s%s (%s)", trophyTag, mutTag, tierTag, def.name, Util.FormatWeight(entry.weight))
		lbl.TextColor3 = GameConfig.RarityColors[def.rarity] or Color3.fromRGB(255, 255, 255)
		lbl.Parent = bb

		local stroke = Instance.new("UIStroke")
		stroke.Thickness = 1.6
		stroke.Color = Color3.fromRGB(14, 18, 30)
		stroke.Parent = lbl
	end
end

function PetAndFishVisuals.InitFollowLoop()
	-- Da chuyen 100% dien hoat Pet sang ClientPetRenderer de toi uu FPS & bang thong!
end

return PetAndFishVisuals
