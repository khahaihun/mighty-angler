--!strict
-- ClientPetRenderer.luau: Dien hoat Pet 3D (PivotTo + CharGen Cleanup) & NPC R15 / Whirlpool culled theo khoang cach tren Client

local CollectionService = game:GetService("CollectionService")
local Players = game:GetService("Players")
local ReplicatedStorage = game:GetService("ReplicatedStorage")
local RunService = game:GetService("RunService")
local Workspace = game:GetService("Workspace")

local Shared = ReplicatedStorage:WaitForChild("Shared")
local GameConfig = require(Shared:WaitForChild("Config"):WaitForChild("GameConfig"))
local PetsConfig = require(Shared:WaitForChild("Config"):WaitForChild("PetsConfig"))
local PetModelBuilder = require(Shared:WaitForChild("ModelBuilders"):WaitForChild("PetModelBuilder"))

local SoundAndFxController = require(script.Parent.SoundAndFxController)

type ClientNpcRig = {
	model: Model,
	root: BasePart,
	waist: Motor6D,
	rShoulder: Motor6D,
	baseWaistC0: CFrame,
	baseShoulderC0: CFrame,
	phase: number,
}

local ClientPetRenderer = {}

function ClientPetRenderer.RenderPolicy(isLocal: boolean, lowGfx: boolean, distance: number): (boolean, number)
	if isLocal then return true, 0 end
	if lowGfx then return distance <= 90, if distance > 60 then 0.2 else 1 / 30 end
	return distance <= 160, if distance > 85 then 1 / 15 else 0
end

function ClientPetRenderer.ShouldUpdate(now: number, previous: number?, interval: number): boolean
	return previous == nil or now - previous >= interval
end
local lastPetUpdate: { [Model]: number } = setmetatable({}, { __mode = "k" }) :: any

local localPlayer = Players.LocalPlayer
local rootFolder: Folder? = nil
local playerPetModels: { [Player]: { Model } } = {}
local playerSignatures: { [Player]: string } = {}
local playerConns: { [Player]: { RBXScriptConnection } } = {}
local charGenByPlayer: { [Player]: number } = {}

local npcRigs: { [Instance]: ClientNpcRig } = {}
local pendingNpcs: { [Instance]: boolean } = {}
local nextNpcResolveAt = 0.0
local shadowFishByModel: { [Instance]: { BasePart } } = setmetatable({}, { __mode = "k" }) :: any

local SLOT_OFFSETS = {
	Vector3.new(-3.2, 1.85, 3.3),
	Vector3.new(3.2, 1.85, 3.3),
	Vector3.new(-5.3, 2.55, 4.7),
	Vector3.new(5.3, 2.55, 4.7),
	Vector3.new(-2.4, 3.10, 6.0),
	Vector3.new(2.4, 3.10, 6.0),
	Vector3.new(0.0, 3.45, 6.6),
}

local function ensureRootFolder(): Folder
	local existing = rootFolder
	if existing and existing.Parent then
		return existing
	end
	local f = Instance.new("Folder")
	f.Name = "ClientRenderedPets"
	f.Parent = Workspace
	rootFolder = f
	return f
end

local function clearPetsForPlayer(player: Player)
	local list = playerPetModels[player]
	if list then
		for _, m in ipairs(list) do
			m:Destroy()
		end
	end
	playerPetModels[player] = nil
	playerSignatures[player] = nil
end

local function cleanupLeavingPlayer(player: Player)
	charGenByPlayer[player] = (charGenByPlayer[player] or 0) + 1
	local conns = playerConns[player]
	if conns then
		for _, c in ipairs(conns) do
			c:Disconnect()
		end
		playerConns[player] = nil
	end
	clearPetsForPlayer(player)
	charGenByPlayer[player] = nil
end

local function rebuildPetsForPlayer(player: Player)
	if not player:IsDescendantOf(Players) then
		clearPetsForPlayer(player)
		return
	end
	local rawCsv = player:GetAttribute("EquippedPetIds")
	local csv = if type(rawCsv) == "string" then rawCsv else ""
	if playerSignatures[player] == csv then
		return
	end
	clearPetsForPlayer(player)
	playerSignatures[player] = csv
	if csv == "" then
		return
	end

	local host = ensureRootFolder()
	local char = player.Character
	local hrp = if char then char:FindFirstChild("HumanoidRootPart") else nil
	local startPos = if hrp and hrp:IsA("BasePart") then hrp.Position else Vector3.new(0, 14, 0)

	local created: { Model } = {}
	local idx = 0
	for petId in string.gmatch(csv, "([^,]+)") do
		local def = PetsConfig.PetsById[petId]
		if def then
			idx += 1
			local m = PetModelBuilder.BuildPet(def, false, true)
			m.Name = string.format("Pet_%s_%d", player.Name, idx)
			local spawnCf = CFrame.new(startPos + (SLOT_OFFSETS[idx] or Vector3.new(0, 2.5, 4.2)))
			m:PivotTo(spawnCf)
			m.Parent = host

			local adornee = m.PrimaryPart or m:FindFirstChildWhichIsA("BasePart")
			if adornee then
				local bb = Instance.new("BillboardGui")
				bb.Size = UDim2.fromOffset(124, 30)
				bb.StudsOffset = Vector3.new(0, 1.75, 0)
				bb.MaxDistance = 52
				bb.Adornee = adornee
				bb.Parent = adornee

				local lbl = Instance.new("TextLabel")
				lbl.Size = UDim2.fromScale(1, 1)
				lbl.BackgroundTransparency = 1
				lbl.Font = Enum.Font.FredokaOne
				lbl.Text = def.name
				lbl.TextColor3 = GameConfig.RarityColors[def.rarity] or Color3.fromRGB(255, 255, 255)
				lbl.TextScaled = true
				lbl.Parent = bb

				local st = Instance.new("UIStroke")
				st.Thickness = 1.6
				st.Color = Color3.fromRGB(16, 20, 32)
				st.Parent = lbl
			end
			table.insert(created, m)
		end
	end
	playerPetModels[player] = created
end

local function watchPlayer(player: Player)
	cleanupLeavingPlayer(player)
	charGenByPlayer[player] = 1
	local conns: { RBXScriptConnection } = {}
	playerConns[player] = conns

	rebuildPetsForPlayer(player)
	table.insert(conns, player:GetAttributeChangedSignal("EquippedPetIds"):Connect(function()
		rebuildPetsForPlayer(player)
	end))
	table.insert(conns, player.CharacterAdded:Connect(function(newChar: Model)
		local nextGen = (charGenByPlayer[player] or 0) + 1
		charGenByPlayer[player] = nextGen
		task.wait(0.25)
		if charGenByPlayer[player] ~= nextGen or not player:IsDescendantOf(Players) or player.Character ~= newChar then
			return
		end
		playerSignatures[player] = nil
		rebuildPetsForPlayer(player)
	end))
	table.insert(conns, player.CharacterRemoving:Connect(function()
		charGenByPlayer[player] = (charGenByPlayer[player] or 0) + 1
		clearPetsForPlayer(player)
	end))
end

local function tryBuildNpcRig(model: Instance): ClientNpcRig?
	if not model:IsA("Model") then
		return nil
	end
	local root = model.PrimaryPart or model:FindFirstChild("HumanoidRootPart")
	local uTorso = model:FindFirstChild("UpperTorso")
	local rArm = model:FindFirstChild("RightUpperArm")
	local waist = if uTorso then uTorso:FindFirstChild("Waist") else nil
	local rSh = if rArm then rArm:FindFirstChild("RightShoulder") else nil
	if not (root and root:IsA("BasePart") and waist and waist:IsA("Motor6D") and rSh and rSh:IsA("Motor6D")) then
		return nil
	end
	local bw = waist:GetAttribute("BaseC0")
	local bs = rSh:GetAttribute("BaseC0")
	return {
		model = model,
		root = root,
		waist = waist,
		rShoulder = rSh,
		baseWaistC0 = if typeof(bw) == "CFrame" then bw else waist.C0,
		baseShoulderC0 = if typeof(bs) == "CFrame" then bs else rSh.C0,
		phase = tonumber(model:GetAttribute("PhaseOffset")) or 0,
	}
end

-- NPC duoc Server gan tag; Client chi theo doi dung cac model do thay vi quet ca map moi 5 giay.
-- Model vua stream toi co the chua du khop xuong, nen giu trong pendingNpcs va thu lai moi giay.
local function resolvePendingNpcs(now: number)
	if now < nextNpcResolveAt or next(pendingNpcs) == nil then
		return
	end
	nextNpcResolveAt = now + 1.0
	for model in pairs(pendingNpcs) do
		local rig = tryBuildNpcRig(model)
		if rig then
			pendingNpcs[model] = nil
			npcRigs[model] = rig
		end
	end
end

local function animateNearbyWorldVisuals(t: number, myPos: Vector3)
	resolvePendingNpcs(t)
	for _, npc in pairs(npcRigs) do
		if npc.model.Parent and (npc.root.Position - myPos).Magnitude <= 135 then
			local breath = math.sin(t * 2.2 + npc.phase) * 0.07
			local wave = math.sin(t * 3.2 + npc.phase) * math.rad(14)
			npc.waist.C0 = npc.baseWaistC0 * CFrame.new(0, breath, 0)
			npc.rShoulder.C0 = npc.baseShoulderC0 * CFrame.Angles(math.rad(28) + wave, 0, math.rad(12))
		end
	end

	local wpFolder = Workspace:FindFirstChild("OceanWhirlpools")
	if wpFolder then
		for _, wpModel in ipairs(wpFolder:GetChildren()) do
			local center = wpModel:GetAttribute("WhirlpoolCenter")
			if wpModel:IsA("Model") and typeof(center) == "Vector3" and (center - myPos).Magnitude <= 185 then
				-- Nho san 4 ca bong cua tung xoay nuoc; chi tim lai theo ten khi con thieu (dang stream).
				local fish = shadowFishByModel[wpModel]
				if not fish then
					fish = {}
					shadowFishByModel[wpModel] = fish
				end
				for i = 1, 4 do
					local f = fish[i]
					if not f or f.Parent ~= wpModel then
						local found = wpModel:FindFirstChild("ShadowFish_" .. tostring(i))
						f = if found and found:IsA("BasePart") then found else nil
						fish[i] = f :: any
					end
					if f then
						local ang = t * 1.6 + i * (math.pi * 0.5)
						local pos = center + Vector3.new(math.cos(ang) * 7.2, -0.7, math.sin(ang) * 7.2)
						local tangent = Vector3.new(-math.sin(ang), 0, math.cos(ang))
						f.CFrame = CFrame.lookAt(pos, pos + tangent)
					end
				end
			end
		end
	end
end

local function watchTaggedNpcs()
	local function onAdded(inst: Instance)
		if not npcRigs[inst] then
			pendingNpcs[inst] = true
		end
	end
	local function onRemoved(inst: Instance)
		pendingNpcs[inst] = nil
		npcRigs[inst] = nil
	end
	CollectionService:GetInstanceAddedSignal(GameConfig.ANIMATED_NPC_TAG):Connect(onAdded)
	CollectionService:GetInstanceRemovedSignal(GameConfig.ANIMATED_NPC_TAG):Connect(onRemoved)
	for _, inst in ipairs(CollectionService:GetTagged(GameConfig.ANIMATED_NPC_TAG)) do
		onAdded(inst)
	end
end

function ClientPetRenderer.Init()
	ensureRootFolder()
	for _, p in ipairs(Players:GetPlayers()) do
		watchPlayer(p)
	end
	Players.PlayerAdded:Connect(watchPlayer)
	Players.PlayerRemoving:Connect(cleanupLeavingPlayer)
	watchTaggedNpcs()

	RunService.RenderStepped:Connect(function(dt: number)
		local t = os.clock()
		local lowGfx = SoundAndFxController.IsLowGfx()
		local localChar = localPlayer.Character
		local localHrp = if localChar then localChar:FindFirstChild("HumanoidRootPart") else nil
		local myPos = if localHrp and localHrp:IsA("BasePart") then localHrp.Position else nil

		if myPos and not lowGfx then
			animateNearbyWorldVisuals(t, myPos)
		end

		for player, models in pairs(playerPetModels) do
			local char = player.Character
			local hrp = if char then char:FindFirstChild("HumanoidRootPart") else nil
			if hrp and hrp:IsA("BasePart") then
				local dist = if myPos and player ~= localPlayer then (hrp.Position - myPos).Magnitude else 0
				local visible, interval = ClientPetRenderer.RenderPolicy(player == localPlayer, lowGfx, dist)
				for _, model in ipairs(models) do
					if not visible then
						model.Parent = nil
						lastPetUpdate[model] = nil
					elseif not model.Parent then
						model:PivotTo(hrp.CFrame)
						model.Parent = ensureRootFolder()
					end
				end
				if visible then
					local lerpAlpha = math.clamp(dt * 10.5, 0.08, 0.45)
					for idx, m in ipairs(models) do
						if m.Parent and ClientPetRenderer.ShouldUpdate(t, lastPetUpdate[m], interval) then
							lastPetUpdate[m] = t
							local off = SLOT_OFFSETS[idx] or Vector3.new(0, 2.5, 4.5)
							local bobY = if lowGfx and player ~= localPlayer then 0 else (math.sin(t * 3.5 + idx * 1.4) * 0.44)
							local tiltZ = math.cos(t * 2.8 + idx) * math.rad(6)
							local goalPos = (hrp.CFrame * CFrame.new(off + Vector3.new(0, bobY, 0))).Position
							local goalCf = CFrame.lookAt(goalPos, goalPos + hrp.CFrame.LookVector) * CFrame.Angles(0, 0, tiltZ)
							m:PivotTo(m:GetPivot():Lerp(goalCf, lerpAlpha))
						end
					end
				end
			else
				for _, model in ipairs(models) do model.Parent = nil end
			end
		end
	end)
end

return ClientPetRenderer
