--!strict
-- NpcBuilder.luau: Dung 4 NPC nguoi that R15 Rig chuan (Humanoid + Animator + Motor6D + WeldConstraint, Zero Server Heartbeat)

local CollectionService = game:GetService("CollectionService")
local ReplicatedStorage = game:GetService("ReplicatedStorage")

local Shared = ReplicatedStorage:WaitForChild("Shared")
local Types = require(Shared:WaitForChild("Types"))
local AssetRegistry = require(Shared:WaitForChild("AssetRegistry"))
local GameConfig = require(Shared:WaitForChild("Config"):WaitForChild("GameConfig"))

local PartFactory = require(script.Parent.PartFactory)
local ManualIslandAdapter = require(script.Parent.ManualIslandAdapter)

export type NpcRole = "Merchant" | "Shop" | "Collector" | "Coach"

local NpcBuilder = {}

local function makeLimb(parent: Instance, name: string, size: Vector3, cf: CFrame, color: Color3): Part
	local p = PartFactory.Block(parent, name, size, cf, color, Enum.Material.SmoothPlastic, false)
	p.Anchored = false
	p.Massless = true
	return p
end

local function makeMotor(parent: BasePart, name: string, part0: BasePart, part1: BasePart): Motor6D
	local m = Instance.new("Motor6D")
	m.Name = name
	m.Part0 = part0
	m.Part1 = part1
	m.C0 = part0.CFrame:ToObjectSpace(part1.CFrame)
	m.C1 = CFrame.new()
	m:SetAttribute("BaseC0", m.C0)
	m.Parent = parent
	return m
end

local function weldAccessory(host: BasePart, acc: BasePart)
	acc.Anchored = false
	acc.CanCollide = false
	acc.Massless = true
	local w = Instance.new("WeldConstraint")
	w.Part0 = host
	w.Part1 = acc
	w.Parent = acc
end

local function createArticulatedNpc(
	parent: Instance,
	role: NpcRole,
	displayName: string,
	subtitle: string,
	rootCf: CFrame,
	shirtCol: Color3,
	pantsCol: Color3,
	hatCol: Color3,
	accentCol: Color3,
	promptAction: string,
	promptKind: string,
	islandId: number
)
	local override = AssetRegistry.TryClone("Npcs", role, "RootOnly")
		or AssetRegistry.TryClone("Props", "Npc_" .. role, "RootOnly")
	if override and override.PrimaryPart then
		override.Name = "Npc_" .. role
		override:PivotTo(rootCf)
		override:SetAttribute("IsAnimatedNpc", true)
		CollectionService:AddTag(override, GameConfig.ANIMATED_NPC_TAG)
		override:SetAttribute("PhaseOffset", math.random() * 6.28)
		override.Parent = parent

		local headPart = override:FindFirstChild("Head")
		local billboardHost: BasePart = if headPart and headPart:IsA("BasePart")
			then headPart
			else override.PrimaryPart
		local torsoPart = override:FindFirstChild("UpperTorso") or override:FindFirstChild("Torso")
		local promptHost: BasePart = if torsoPart and torsoPart:IsA("BasePart")
			then torsoPart
			else override.PrimaryPart

		PartFactory.AddBillboard(billboardHost, displayName, subtitle, accentCol, 3.6)
		PartFactory.AddPrompt(promptHost, promptAction, displayName, 16, promptKind, {
			IslandId = islandId,
			NpcRole = role,
		})
		return
	end

	local m = Instance.new("Model")
	m.Name = "Npc_" .. role
	m:SetAttribute("IsAnimatedNpc", true)
	CollectionService:AddTag(m, GameConfig.ANIMATED_NPC_TAG)
	m:SetAttribute("PhaseOffset", math.random() * 6.28)
	m.Parent = parent

	local hum = Instance.new("Humanoid")
	hum.DisplayDistanceType = Enum.HumanoidDisplayDistanceType.None
	hum.HealthDisplayType = Enum.HumanoidHealthDisplayType.AlwaysOff
	hum.EvaluateStateMachine = false
	hum.RigType = Enum.HumanoidRigType.R15
	hum.Parent = m
	local animator = Instance.new("Animator")
	animator.Parent = hum

	local skin = Color3.fromRGB(255, 214, 176)
	local shoe = Color3.fromRGB(42, 46, 58)

	local hrp = PartFactory.Block(m, "HumanoidRootPart", Vector3.new(2.0, 2.0, 1.0), rootCf * CFrame.new(0, 3.0, 0), skin, Enum.Material.SmoothPlastic, true, 1.0)
	hrp.CanQuery = false
	m.PrimaryPart = hrp

	local lowerTorso = makeLimb(m, "LowerTorso", Vector3.new(2.05, 0.75, 1.15), rootCf * CFrame.new(0, 2.7, 0), pantsCol)
	local torsoWidth = if role == "Coach" then 2.55 else 2.15
	local torsoCf = rootCf * CFrame.new(0, 3.85, 0)
	local upperTorso = makeLimb(m, "UpperTorso", Vector3.new(torsoWidth, 1.75, 1.22), torsoCf, shirtCol)
	upperTorso.CanCollide = true

	makeMotor(lowerTorso, "Root", hrp, lowerTorso)
	makeMotor(upperTorso, "Waist", lowerTorso, upperTorso)

	local vest = PartFactory.Block(m, "VestAccent", Vector3.new(torsoWidth + 0.08, 1.45, 1.28), torsoCf * CFrame.new(0, -0.05, 0), accentCol, Enum.Material.SmoothPlastic, false)
	weldAccessory(upperTorso, vest)

	-- 2 Chan R15 (6 khop Motor6D)
	for _, spec in ipairs({ { prefix = "Left", x = -0.58 }, { prefix = "Right", x = 0.58 } }) do
		local uLeg = makeLimb(m, spec.prefix .. "UpperLeg", Vector3.new(0.95, 1.25, 0.95), rootCf * CFrame.new(spec.x, 1.75, 0), pantsCol)
		local lLeg = makeLimb(m, spec.prefix .. "LowerLeg", Vector3.new(0.88, 1.05, 0.88), rootCf * CFrame.new(spec.x, 0.65, 0), pantsCol)
		local foot = makeLimb(m, spec.prefix .. "Foot", Vector3.new(0.92, 0.42, 1.25), rootCf * CFrame.new(spec.x, 0.21, -0.14), shoe)
		makeMotor(uLeg, spec.prefix .. "Hip", lowerTorso, uLeg)
		makeMotor(lLeg, spec.prefix .. "Knee", uLeg, lLeg)
		makeMotor(foot, spec.prefix .. "Ankle", lLeg, foot)
	end

	-- 2 Tay R15 (6 khop Motor6D)
	local armX = torsoWidth * 0.5 + 0.52
	for _, spec in ipairs({ { prefix = "Left", s = -1 }, { prefix = "Right", s = 1 } }) do
		local x = spec.s * armX
		local uArm = makeLimb(m, spec.prefix .. "UpperArm", Vector3.new(0.86, 1.05, 0.86), rootCf * CFrame.new(x, 4.18, 0), shirtCol)
		local lArm = makeLimb(m, spec.prefix .. "LowerArm", Vector3.new(0.82, 0.85, 0.82), rootCf * CFrame.new(x, 3.28, 0), skin)
		local hand = makeLimb(m, spec.prefix .. "Hand", Vector3.new(0.82, 0.38, 0.82), rootCf * CFrame.new(x, 2.70, 0), skin)
		makeMotor(uArm, spec.prefix .. "Shoulder", upperTorso, uArm)
		makeMotor(lArm, spec.prefix .. "Elbow", uArm, lArm)
		makeMotor(hand, spec.prefix .. "Wrist", lArm, hand)
	end

	-- Dau + Mat + Mu non han chat theo khop Neck
	local headPos = (rootCf * CFrame.new(0, 5.45, 0)).Position
	local head = PartFactory.Ball(m, "Head", 1.85, headPos, skin, Enum.Material.SmoothPlastic, false)
	head.Anchored = false
	head.Massless = true
	makeMotor(head, "Neck", upperTorso, head)

	for _, eyeX in ipairs({ -0.32, 0.32 }) do
		local eye = PartFactory.Ball(m, "Eye", 0.22, (rootCf * CFrame.new(eyeX, 5.55, -0.82)).Position, Color3.fromRGB(24, 28, 38), Enum.Material.SmoothPlastic, false)
		weldAccessory(head, eye)
	end
	local smile = PartFactory.Block(m, "Smile", Vector3.new(0.48, 0.10, 0.12), rootCf * CFrame.new(0, 5.22, -0.84), Color3.fromRGB(168, 72, 68), Enum.Material.SmoothPlastic, false)
	weldAccessory(head, smile)

	if role == "Coach" then
		local hb = PartFactory.VerticalCylinder(m, "Headband", 0.32, 1.92, rootCf * CFrame.new(0, 5.78, 0), hatCol, Enum.Material.SmoothPlastic, false)
		weldAccessory(head, hb)
	else
		local brim = PartFactory.VerticalCylinder(m, "HatBrim", 0.24, 3.1, rootCf * CFrame.new(0, 6.18, 0), hatCol, Enum.Material.SmoothPlastic, false)
		local crown = PartFactory.VerticalCylinder(m, "HatCrown", 0.95, 1.92, rootCf * CFrame.new(0, 6.68, 0), hatCol, Enum.Material.SmoothPlastic, false)
		weldAccessory(head, brim)
		weldAccessory(head, crown)
	end

	PartFactory.AddBillboard(head, displayName, subtitle, accentCol, 3.2)
	PartFactory.AddPrompt(upperTorso, promptAction, displayName, 16, promptKind, {
		IslandId = islandId,
		NpcRole = role,
	})
end

function NpcBuilder.BuildIslandNpcs(islandFolder: Folder, islandDef: Types.IslandDef, manualIsland: Instance?)
	local npcFolder = Instance.new("Folder")
	npcFolder.Name = "IslandNpcs"
	npcFolder.Parent = islandFolder

	local c = islandDef.centerPosition
	local merchantCf = ManualIslandAdapter.GetMarkerCFrame(manualIsland, "NpcMerchant", CFrame.new(c + Vector3.new(-28, 0, 36.5)))
	local shopCf = ManualIslandAdapter.GetMarkerCFrame(manualIsland, "NpcShop", CFrame.new(c + Vector3.new(28, 0, 36.5)))
	local collectorCf = ManualIslandAdapter.GetMarkerCFrame(manualIsland, "NpcCollector", CFrame.new(c + Vector3.new(-11, 0, 48.2)))
	local coachCf = ManualIslandAdapter.GetMarkerCFrame(manualIsland, "NpcCoach", CFrame.new(c + Vector3.new(-36, 0, -10)) * CFrame.Angles(0, math.rad(-90), 0))

	createArticulatedNpc(
		npcFolder, "Merchant", "Captain Barnaby", "Fish Merchant • Sell & Inspect",
		merchantCf,
		Color3.fromRGB(245, 186, 52), Color3.fromRGB(48, 68, 102), Color3.fromRGB(38, 56, 92), Color3.fromRGB(255, 218, 76),
		"Talk to Merchant", "NpcMerchant", islandDef.id
	)

	createArticulatedNpc(
		npcFolder, "Shop", "Master Kaito", "Rods, Bait, Gear & Enchants",
		shopCf,
		Color3.fromRGB(56, 148, 232), Color3.fromRGB(42, 52, 76), Color3.fromRGB(238, 244, 255), Color3.fromRGB(98, 224, 255),
		"Talk to Crafter", "NpcShop", islandDef.id
	)

	local deskOverride = AssetRegistry.TryClone("Buildings", "AppraiserDesk", true)
	if deskOverride and deskOverride.PrimaryPart then
		deskOverride.Name = "AppraiserDesk"
		deskOverride:PivotTo(collectorCf * CFrame.new(0, 1.6, 3.8))
		deskOverride.Parent = npcFolder
	else
		PartFactory.Block(
			npcFolder, "AppraiserDesk", Vector3.new(7.5, 3.2, 3.6),
			collectorCf * CFrame.new(0, 1.6, 3.8), Color3.fromRGB(136, 92, 58), Enum.Material.WoodPlanks
		)
	end

	createArticulatedNpc(
		npcFolder, "Collector", "Old Man Finn", "Appraiser & Fish Bounties",
		collectorCf,
		Color3.fromRGB(82, 168, 118), Color3.fromRGB(92, 72, 56), Color3.fromRGB(218, 182, 106), Color3.fromRGB(122, 255, 186),
		"Appraise / Bounties", "NpcCollector", islandDef.id
	)

	createArticulatedNpc(
		npcFolder, "Coach", "Coach Atlas", "Strength & Rank Guide",
		coachCf,
		Color3.fromRGB(238, 78, 72), Color3.fromRGB(42, 46, 58), Color3.fromRGB(255, 212, 68), Color3.fromRGB(255, 118, 88),
		"Talk to Coach", "NpcCoach", islandDef.id
	)
end

return NpcBuilder
