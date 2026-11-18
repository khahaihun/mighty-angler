--!strict
-- PetAndFishVisuals.luau: Mo hinh 3D Low-Poly cho Ca vang len khi cau dinh & Pet bay theo nhan vat

local Debris = game:GetService("Debris")
local Players = game:GetService("Players")
local ReplicatedStorage = game:GetService("ReplicatedStorage")
local RunService = game:GetService("RunService")
local Workspace = game:GetService("Workspace")

local Shared = ReplicatedStorage:WaitForChild("Shared")
local Types = require(Shared:WaitForChild("Types"))
local Util = require(Shared:WaitForChild("Util"))
local AssetRegistry = require(Shared:WaitForChild("AssetRegistry"))
local GameConfig = require(Shared:WaitForChild("Config"):WaitForChild("GameConfig"))
local IslandsRegistry = require(Shared:WaitForChild("Config"):WaitForChild("Islands"))

local PetAndFishVisuals = {}

local activePetFolders: { [Player]: Folder } = {}
local activePetDefs: { [Player]: { Types.PetDef } } = {}
local fishLookup: { [string]: Types.FishDef } = {}
for _, isl in ipairs(IslandsRegistry.List) do
	for _, f in ipairs(isl.fishPool) do
		fishLookup[f.id] = f
	end
end

local function buildFishModel(fishDef: Types.FishDef, mutation: Types.MutationName): Model
	local override = AssetRegistry.TryClone("Fish", fishDef.id, true)
	if override and override.PrimaryPart then
		return override
	end

	local model = Instance.new("Model")
	model.Name = "CaughtFish_" .. fishDef.id
	local sc = math.clamp(fishDef.scale, 0.75, 2.5)

	local bodyCol = fishDef.primaryColor
	local finCol = fishDef.secondaryColor
	local mat = Enum.Material.SmoothPlastic

	if mutation == "Shiny" then
		bodyCol = GameConfig.Mutations.Shiny.color
		mat = Enum.Material.Neon
	elseif mutation == "Golden" then
		bodyCol = GameConfig.Mutations.Golden.color
		mat = Enum.Material.Foil
	elseif mutation == "Cosmic" then
		bodyCol = GameConfig.Mutations.Cosmic.color
		mat = Enum.Material.Neon
	end

	local body = Instance.new("Part")
	body.Name = "Body"
	body.Shape = Enum.PartType.Ball
	body.Size = Vector3.new(1.1 * sc, 1.35 * sc, 2.4 * sc)
	body.Color = bodyCol
	body.Material = mat
	body.Anchored = true
	body.CanCollide = false
	body.Parent = model
	model.PrimaryPart = body

	local function makeFin(finName: string, sz: Vector3)
		local w = Instance.new("WedgePart")
		w.Name = finName
		w.Size = sz
		w.Color = finCol
		w.Material = Enum.Material.SmoothPlastic
		w.Anchored = true
		w.CanCollide = false
		w.Parent = model
	end
	makeFin("TailFin", Vector3.new(0.32 * sc, 1.45 * sc, 1.15 * sc))
	makeFin("DorsalFin", Vector3.new(0.24 * sc, 0.75 * sc, 1.0 * sc))

	return model
end

local function positionFishParts(model: Model, centerCf: CFrame, sc: number)
	local body = model.PrimaryPart
	if not body then
		return
	end
	body.CFrame = centerCf
	local tail = model:FindFirstChild("TailFin")
	if tail and tail:IsA("BasePart") then
		tail.CFrame = centerCf * CFrame.new(0, 0, 1.45 * sc)
	end
	local dorsal = model:FindFirstChild("DorsalFin")
	if dorsal and dorsal:IsA("BasePart") then
		dorsal.CFrame = centerCf * CFrame.new(0, 0.8 * sc, 0.1 * sc)
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

	local fishModel = buildFishModel(fishDef, mutation)
	fishModel.Parent = Workspace
	local sc = math.clamp(fishDef.scale, 0.75, 2.5)

	task.spawn(function()
		local duration = 0.72
		local elapsed = 0
		while elapsed < duration and fishModel.Parent ~= nil do
			local dt = task.wait()
			elapsed += dt
			local alpha = math.clamp(elapsed / duration, 0, 1)
			local endPos = if root.Parent then (root.Position + Vector3.new(0, 2.4, 0)) else (startPos + Vector3.new(0, 4, 0))
			local flat = startPos:Lerp(endPos, alpha)
			local arcHeight = math.sin(alpha * math.pi) * 7.5
			local curPos = flat + Vector3.new(0, arcHeight, 0)
			local spinCf = CFrame.lookAt(curPos, endPos + Vector3.new(0, 0.5, 0))
				* CFrame.Angles(math.rad(alpha * 360), 0, 0)
			positionFishParts(fishModel, spinCf, sc)
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
	if not entry then
		return
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
	local sc = math.clamp(def.scale * tierScale, 0.8, 3.8)
	local m = buildFishModel(def, entry.mutation)
	m.Name = "HeldFlexFish"
	m.Parent = char
	local centerCf = torso.CFrame * CFrame.new(0, 0.45, -(1.35 + sc * 0.42)) * CFrame.Angles(0, math.rad(90), 0)
	positionFishParts(m, centerCf, sc)
	for _, d in ipairs(m:GetDescendants()) do
		if d:IsA("BasePart") then
			d.Size = d.Size * tierScale
			d.Anchored = false
			d.CanCollide = false
			d.CanQuery = false
			d.Massless = true
			local w = Instance.new("WeldConstraint")
			w.Part0 = torso
			w.Part1 = d
			w.Parent = d
		end
	end
	if m.PrimaryPart then
		local bb = Instance.new("BillboardGui")
		bb.Size = UDim2.fromOffset(180, 38)
		bb.StudsOffset = Vector3.new(0, 1.2 + sc * 0.55, 0)
		bb.MaxDistance = 48
		bb.Adornee = m.PrimaryPart
		bb.Parent = m.PrimaryPart
		local lbl = Instance.new("TextLabel")
		lbl.Size = UDim2.fromScale(1, 1)
		lbl.BackgroundTransparency = 1
		lbl.Font = Enum.Font.FredokaOne
		lbl.TextScaled = true
		local mutTag = if entry.mutation ~= "None" then ("[" .. entry.mutation .. "] ") else ""
		local tierTag = if entry.sizeTier ~= "Normal" then (entry.sizeTier .. " ") else ""
		lbl.Text = string.format("%s%s%s (%s)", mutTag, tierTag, def.name, Util.FormatWeight(entry.weight))
		lbl.TextColor3 = GameConfig.RarityColors[def.rarity] or Color3.fromRGB(255, 255, 255)
		lbl.Parent = bb
	end
end

local function createPetModel(petDef: Types.PetDef): Model
	local override = AssetRegistry.TryClone("Pets", petDef.id, true)
	if override and override.PrimaryPart then
		return override
	end

	local m = Instance.new("Model")
	m.Name = "Pet_" .. petDef.id

	local function makePetPart(pName: string, shape: Enum.PartType, sz: Vector3, col: Color3, mat: Enum.Material): Part
		local p = Instance.new("Part")
		p.Name = pName
		p.Shape = shape
		p.Size = sz
		p.Color = col
		p.Material = mat
		p.Anchored = true
		p.CanCollide = false
		p.Parent = m
		return p
	end

	local bodyShape = if petDef.archetype == "Star" then Enum.PartType.Block else Enum.PartType.Ball
	local bodyMat = if petDef.rarity == "Mythic" or petDef.rarity == "Legendary" then Enum.Material.Neon else Enum.Material.SmoothPlastic
	local head = makePetPart("Body", bodyShape, Vector3.new(1.85, 1.75, 1.95), petDef.primaryColor, bodyMat)
	m.PrimaryPart = head

	for _, side in ipairs({ -0.65, 0.65 }) do
		makePetPart(if side < 0 then "WingL" else "WingR", Enum.PartType.Block, Vector3.new(0.75, 0.45, 0.95), petDef.secondaryColor, Enum.Material.SmoothPlastic)
		makePetPart(if side < 0 then "EyeL" else "EyeR", Enum.PartType.Ball, Vector3.new(0.32, 0.32, 0.32), Color3.fromRGB(22, 26, 36), Enum.Material.SmoothPlastic)
	end

	local bb = Instance.new("BillboardGui")
	bb.Size = UDim2.fromOffset(120, 32)
	bb.StudsOffset = Vector3.new(0, 1.85, 0)
	bb.MaxDistance = 55
	bb.Adornee = head
	bb.Parent = head

	local lbl = Instance.new("TextLabel")
	lbl.Size = UDim2.fromScale(1, 1)
	lbl.BackgroundTransparency = 1
	lbl.Font = Enum.Font.FredokaOne
	lbl.Text = petDef.name
	lbl.TextColor3 = GameConfig.RarityColors[petDef.rarity] or Color3.fromRGB(255, 255, 255)
	lbl.TextScaled = true
	lbl.Parent = bb

	local st = Instance.new("UIStroke")
	st.Thickness = 1.6
	st.Color = Color3.fromRGB(16, 20, 32)
	st.Parent = lbl

	return m
end

local function updateSinglePetModel(model: Model, targetCf: CFrame)
	local body = model.PrimaryPart
	if not body then
		return
	end
	local nextCf = body.CFrame:Lerp(targetCf, 0.18)
	body.CFrame = nextCf

	local wingL = model:FindFirstChild("WingL")
	if wingL and wingL:IsA("BasePart") then
		wingL.CFrame = nextCf * CFrame.new(-1.05, 0.15, 0.1) * CFrame.Angles(0, 0, math.rad(18))
	end
	local wingR = model:FindFirstChild("WingR")
	if wingR and wingR:IsA("BasePart") then
		wingR.CFrame = nextCf * CFrame.new(1.05, 0.15, 0.1) * CFrame.Angles(0, 0, math.rad(-18))
	end
	local eyeL = model:FindFirstChild("EyeL")
	if eyeL and eyeL:IsA("BasePart") then
		eyeL.CFrame = nextCf * CFrame.new(-0.42, 0.22, -0.86)
	end
	local eyeR = model:FindFirstChild("EyeR")
	if eyeR and eyeR:IsA("BasePart") then
		eyeR.CFrame = nextCf * CFrame.new(0.42, 0.22, -0.86)
	end
end

function PetAndFishVisuals.SyncPlayerPets(player: Player, equippedDefs: { Types.PetDef })
	local oldFolder = activePetFolders[player]
	if oldFolder then
		oldFolder:Destroy()
		activePetFolders[player] = nil
	end
	activePetDefs[player] = equippedDefs
	if #equippedDefs == 0 then
		return
	end

	local folder = Instance.new("Folder")
	folder.Name = "PlayerPets_" .. player.Name
	folder.Parent = Workspace
	activePetFolders[player] = folder

	local char = player.Character
	local root = if char then char:FindFirstChild("HumanoidRootPart") else nil
	local startPos = if root and root:IsA("BasePart") then root.Position else Vector3.new(0, 14, 0)

	for idx, def in ipairs(equippedDefs) do
		local m = createPetModel(def)
		m.Name = "Slot_" .. tostring(idx)
		m.Parent = folder
		if m.PrimaryPart then
			m.PrimaryPart.CFrame = CFrame.new(startPos + Vector3.new(idx * 2, 2, 3))
		end
	end
end

function PetAndFishVisuals.InitFollowLoop()
	local offsets = {
		Vector3.new(-3.2, 1.8, 3.4),
		Vector3.new(3.2, 1.8, 3.4),
		Vector3.new(-5.4, 2.5, 4.8),
		Vector3.new(5.4, 2.5, 4.8),
	}

	RunService.Heartbeat:Connect(function()
		local t = os.clock()
		for player, folder in pairs(activePetFolders) do
			local char = player.Character
			local root = if char then char:FindFirstChild("HumanoidRootPart") else nil
			if root and root:IsA("BasePart") then
				for idx, child in ipairs(folder:GetChildren()) do
					if child:IsA("Model") then
						local off = offsets[idx] or Vector3.new(0, 2.5, 4.5)
						local bobY = math.sin(t * 3.4 + idx * 1.3) * 0.48
						local targetPos = (root.CFrame * CFrame.new(off + Vector3.new(0, bobY, 0))).Position
						local targetCf = CFrame.lookAt(targetPos, targetPos + root.CFrame.LookVector)
						updateSinglePetModel(child, targetCf)
					end
				end
			end
		end
	end)

	Players.PlayerRemoving:Connect(function(player: Player)
		local folder = activePetFolders[player]
		if folder then
			folder:Destroy()
			activePetFolders[player] = nil
		end
		activePetDefs[player] = nil
	end)
end

return PetAndFishVisuals
