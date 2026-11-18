--!strict
-- ClientPetRenderer.luau: Dien hoat Pet Chibi 3D muot 60FPS tren Client (giam tai 100% bang thong Server & toi uu Low GFX)

local Players = game:GetService("Players")
local ReplicatedStorage = game:GetService("ReplicatedStorage")
local RunService = game:GetService("RunService")
local Workspace = game:GetService("Workspace")

local Shared = ReplicatedStorage:WaitForChild("Shared")
local GameConfig = require(Shared:WaitForChild("Config"):WaitForChild("GameConfig"))
local PetsConfig = require(Shared:WaitForChild("Config"):WaitForChild("PetsConfig"))
local PetModelBuilder = require(Shared:WaitForChild("ModelBuilders"):WaitForChild("PetModelBuilder"))

local SoundAndFxController = require(script.Parent.SoundAndFxController)

local ClientPetRenderer = {}

local localPlayer = Players.LocalPlayer
local rootFolder: Folder? = nil
local playerPetModels: { [Player]: { Model } } = {}
local playerSignatures: { [Player]: string } = {}

local SLOT_OFFSETS = {
	Vector3.new(-3.2, 1.85, 3.3),
	Vector3.new(3.2, 1.85, 3.3),
	Vector3.new(-5.3, 2.55, 4.7),
	Vector3.new(5.3, 2.55, 4.7),
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
			if m.Parent then
				m:Destroy()
			end
		end
	end
	playerPetModels[player] = nil
	playerSignatures[player] = nil
end

local function rebuildPetsForPlayer(player: Player)
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
			m.Parent = host
			if m.PrimaryPart then
				m.PrimaryPart.CFrame = CFrame.new(startPos + (SLOT_OFFSETS[idx] or Vector3.new(0, 2.5, 4.2)))

				local bb = Instance.new("BillboardGui")
				bb.Size = UDim2.fromOffset(124, 30)
				bb.StudsOffset = Vector3.new(0, 1.75, 0)
				bb.MaxDistance = 52
				bb.Adornee = m.PrimaryPart
				bb.Parent = m.PrimaryPart

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
	rebuildPetsForPlayer(player)
	player:GetAttributeChangedSignal("EquippedPetIds"):Connect(function()
		rebuildPetsForPlayer(player)
	end)
	player.CharacterAdded:Connect(function()
		task.wait(0.25)
		playerSignatures[player] = nil
		rebuildPetsForPlayer(player)
	end)
end

function ClientPetRenderer.Init()
	ensureRootFolder()
	for _, p in ipairs(Players:GetPlayers()) do
		watchPlayer(p)
	end
	Players.PlayerAdded:Connect(watchPlayer)
	Players.PlayerRemoving:Connect(clearPetsForPlayer)

	local frameStep = 0
	RunService.RenderStepped:Connect(function(dt: number)
		frameStep = (frameStep + 1) % 4
		local t = os.clock()
		local lowGfx = SoundAndFxController.IsLowGfx()
		local localChar = localPlayer.Character
		local localHrp = if localChar then localChar:FindFirstChild("HumanoidRootPart") else nil
		local myPos = if localHrp and localHrp:IsA("BasePart") then localHrp.Position else nil

		for player, models in pairs(playerPetModels) do
			local char = player.Character
			local hrp = if char then char:FindFirstChild("HumanoidRootPart") else nil
			if hrp and hrp:IsA("BasePart") then
				local dist = if myPos and player ~= localPlayer then (hrp.Position - myPos).Magnitude else 0
				local skipFrame = (dist > 85 or (lowGfx and player ~= localPlayer)) and (frameStep ~= 0)
				if not skipFrame then
					local lerpAlpha = math.clamp(dt * 10.5, 0.08, 0.45)
					for idx, m in ipairs(models) do
						local primary = m.PrimaryPart
						if primary then
							local off = SLOT_OFFSETS[idx] or Vector3.new(0, 2.5, 4.5)
							local bobY = if lowGfx and player ~= localPlayer then 0 else (math.sin(t * 3.5 + idx * 1.4) * 0.44)
							local tiltZ = math.cos(t * 2.8 + idx) * math.rad(6)
							local goalPos = (hrp.CFrame * CFrame.new(off + Vector3.new(0, bobY, 0))).Position
							local goalCf = CFrame.lookAt(goalPos, goalPos + hrp.CFrame.LookVector) * CFrame.Angles(0, 0, tiltZ)
							primary.CFrame = primary.CFrame:Lerp(goalCf, lerpAlpha)
						end
					end
				end
			end
		end
	end)
end

return ClientPetRenderer
