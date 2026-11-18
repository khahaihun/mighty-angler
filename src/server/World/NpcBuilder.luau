--!strict
-- NpcBuilder.luau: Dung 4 NPC nguoi that R15 song dong (co trang phuc, mu non, khuon mat, tho/vay tay & hoi thoai)

local RunService = game:GetService("RunService")
local ReplicatedStorage = game:GetService("ReplicatedStorage")

local Shared = ReplicatedStorage:WaitForChild("Shared")
local Types = require(Shared:WaitForChild("Types"))
local AssetRegistry = require(Shared:WaitForChild("AssetRegistry"))

local PartFactory = require(script.Parent.PartFactory)

export type NpcRole = "Merchant" | "Shop" | "Collector" | "Coach"

type AnimatedNpcEntry = {
	torso: Part,
	rightArm: Part,
	baseTorsoCf: CFrame,
	baseRightArmCf: CFrame,
	phaseOffset: number,
}

local NpcBuilder = {}

local animatedNpcs: { AnimatedNpcEntry } = {}
local idleLoopStarted = false

local function startIdleLoopIfNeeded()
	if idleLoopStarted then
		return
	end
	idleLoopStarted = true

	RunService.Heartbeat:Connect(function()
		local t = os.clock()
		for i = #animatedNpcs, 1, -1 do
			local item = animatedNpcs[i]
			if not item.torso.Parent or not item.rightArm.Parent then
				table.remove(animatedNpcs, i)
			else
				local breath = math.sin(t * 2.2 + item.phaseOffset) * 0.08
				local wave = math.sin(t * 3.4 + item.phaseOffset) * math.rad(14)
				item.torso.CFrame = item.baseTorsoCf * CFrame.new(0, breath, 0)
				item.rightArm.CFrame = item.baseRightArmCf
					* CFrame.new(0, breath, 0)
					* CFrame.Angles(math.rad(-26) + wave, 0, math.rad(12))
			end
		end
	end)
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
	local override = AssetRegistry.TryClone("Props", "Npc_" .. role, true)
	if override and override.PrimaryPart then
		override:PivotTo(rootCf)
		override.Parent = parent
		PartFactory.AddBillboard(override.PrimaryPart, displayName, subtitle, accentCol, 4.8)
		PartFactory.AddPrompt(override.PrimaryPart, promptAction, displayName, 15, promptKind, {
			IslandId = islandId,
			NpcRole = role,
		})
		return
	end

	local m = Instance.new("Model")
	m.Name = "Npc_" .. role
	m.Parent = parent

	local skin = Color3.fromRGB(255, 214, 176)
	local shoe = Color3.fromRGB(42, 46, 58)

	-- Chan & Giay R15
	for _, xSide in ipairs({ -0.58, 0.58 }) do
		PartFactory.Block(m, "UpperLeg", Vector3.new(0.95, 1.25, 0.95), rootCf * CFrame.new(xSide, 1.75, 0), pantsCol)
		PartFactory.Block(m, "LowerLeg", Vector3.new(0.88, 1.05, 0.88), rootCf * CFrame.new(xSide, 0.65, 0), pantsCol)
		PartFactory.Block(m, "Foot", Vector3.new(0.92, 0.42, 1.25), rootCf * CFrame.new(xSide, 0.21, -0.14), shoe)
	end

	-- Hong & Than tren R15
	PartFactory.Block(m, "LowerTorso", Vector3.new(2.05, 0.75, 1.15), rootCf * CFrame.new(0, 2.7, 0), pantsCol)
	local torsoCf = rootCf * CFrame.new(0, 3.85, 0)
	local torsoWidth = if role == "Coach" then 2.55 else 2.15
	local upperTorso = PartFactory.Block(m, "UpperTorso", Vector3.new(torsoWidth, 1.75, 1.22), torsoCf, shirtCol)
	m.PrimaryPart = upperTorso

	-- Ao khoac / Tap de chu de
	PartFactory.Block(m, "VestAccent", Vector3.new(torsoWidth + 0.08, 1.45, 1.28), torsoCf * CFrame.new(0, -0.05, 0), accentCol)

	-- Tay trai & Tay phai (tay phai vay chao nhe nhang)
	local armX = torsoWidth * 0.5 + 0.52
	PartFactory.Block(m, "LeftArm", Vector3.new(0.86, 2.15, 0.86), rootCf * CFrame.new(-armX, 3.65, 0) * CFrame.Angles(0, 0, math.rad(-8)), skin)
	local rightArmCf = rootCf * CFrame.new(armX, 3.85, -0.18)
	local rightArm = PartFactory.Block(m, "RightArm", Vector3.new(0.86, 2.15, 0.86), rightArmCf, skin)

	-- Dau, Mat cuoi & Phu kien Mu non
	local headPos = (rootCf * CFrame.new(0, 5.45, 0)).Position
	local head = PartFactory.Ball(m, "Head", 1.85, headPos, skin, Enum.Material.SmoothPlastic, false)
	for _, eyeX in ipairs({ -0.32, 0.32 }) do
		local eyePos = (rootCf * CFrame.new(eyeX, 5.55, -0.82)).Position
		PartFactory.Ball(m, "Eye", 0.22, eyePos, Color3.fromRGB(24, 28, 38), Enum.Material.SmoothPlastic, false)
	end
	PartFactory.Block(m, "Smile", Vector3.new(0.48, 0.10, 0.12), rootCf * CFrame.new(0, 5.22, -0.84), Color3.fromRGB(168, 72, 68), Enum.Material.SmoothPlastic, false)

	if role == "Coach" then
		-- Bang do the thao cho Huan luyen vien Gym
		PartFactory.VerticalCylinder(m, "Headband", 0.32, 1.92, rootCf * CFrame.new(0, 5.78, 0), hatCol)
	else
		-- Mu vanh Thuyen truong / Ngu dan / Tho san
		PartFactory.VerticalCylinder(m, "HatBrim", 0.24, 3.1, rootCf * CFrame.new(0, 6.18, 0), hatCol)
		PartFactory.VerticalCylinder(m, "HatCrown", 0.95, 1.92, rootCf * CFrame.new(0, 6.68, 0), hatCol)
	end

	PartFactory.AddBillboard(head, displayName, subtitle, accentCol, 3.2)
	PartFactory.AddPrompt(upperTorso, promptAction, displayName, 16, promptKind, {
		IslandId = islandId,
		NpcRole = role,
	})

	table.insert(animatedNpcs, {
		torso = upperTorso,
		rightArm = rightArm,
		baseTorsoCf = torsoCf,
		baseRightArmCf = rightArmCf,
		phaseOffset = math.random() * 6.28,
	})
	startIdleLoopIfNeeded()
end

function NpcBuilder.BuildIslandNpcs(islandFolder: Folder, islandDef: Types.IslandDef)
	local npcFolder = Instance.new("Folder")
	npcFolder.Name = "IslandNpcs"
	npcFolder.Parent = islandFolder

	local c = islandDef.centerPosition

	-- 1. Captain Barnaby — Fish Merchant (Quay Fish Market ben trai, nhin ra quang truong)
	createArticulatedNpc(
		npcFolder,
		"Merchant",
		"Captain Barnaby",
		"Fish Merchant • Sell & Inspect",
		CFrame.new(c + Vector3.new(-28, 0, 36.5)) * CFrame.Angles(0, 0, 0),
		Color3.fromRGB(245, 186, 52),
		Color3.fromRGB(48, 68, 102),
		Color3.fromRGB(38, 56, 92),
		Color3.fromRGB(255, 218, 76),
		"Talk to Merchant",
		"NpcMerchant",
		islandDef.id
	)

	-- 2. Master Kaito — Rod & Gear Crafter (Quay Angler Shop ben phai)
	createArticulatedNpc(
		npcFolder,
		"Shop",
		"Master Kaito",
		"Rods, Bait, Gear & Enchants",
		CFrame.new(c + Vector3.new(28, 0, 36.5)) * CFrame.Angles(0, 0, 0),
		Color3.fromRGB(56, 148, 232),
		Color3.fromRGB(42, 52, 76),
		Color3.fromRGB(238, 244, 255),
		Color3.fromRGB(98, 224, 255),
		"Talk to Crafter",
		"NpcShop",
		islandDef.id
	)

	-- 3. Old Man Finn — Fish Appraiser & Collector Bounty (Giua lối ra cầu cảng)
	local collectorStand = PartFactory.Block(
		npcFolder,
		"AppraiserDesk",
		Vector3.new(7.5, 3.2, 3.6),
		CFrame.new(c + Vector3.new(-11, 1.6, 52)),
		Color3.fromRGB(136, 92, 58),
		Enum.Material.WoodPlanks
	)
	collectorStand.Name = "AppraiserDesk"

	createArticulatedNpc(
		npcFolder,
		"Collector",
		"Old Man Finn",
		"Appraiser & Fish Bounties",
		CFrame.new(c + Vector3.new(-11, 0, 48.2)) * CFrame.Angles(0, 0, 0),
		Color3.fromRGB(82, 168, 118),
		Color3.fromRGB(92, 72, 56),
		Color3.fromRGB(218, 182, 106),
		Color3.fromRGB(122, 255, 186),
		"Appraise / Bounties",
		"NpcCollector",
		islandDef.id
	)

	-- 4. Coach Atlas — Gym Head Trainer (Dau khu Gym ben Tay)
	createArticulatedNpc(
		npcFolder,
		"Coach",
		"Coach Atlas",
		"Strength & Rank Guide",
		CFrame.new(c + Vector3.new(-36, 0, -10)) * CFrame.Angles(0, math.rad(-90), 0),
		Color3.fromRGB(238, 78, 72),
		Color3.fromRGB(42, 46, 58),
		Color3.fromRGB(255, 212, 68),
		Color3.fromRGB(255, 118, 88),
		"Talk to Coach",
		"NpcCoach",
		islandDef.id
	)
end

return NpcBuilder
