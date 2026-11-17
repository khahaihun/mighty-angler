--!strict
-- PropsBuilder.luau: Dung cau go cau ca, quay Sell/Shop, 3 may Gym, tru Trung Pet va cong Dao

local ReplicatedStorage = game:GetService("ReplicatedStorage")
local Shared = ReplicatedStorage:WaitForChild("Shared")
local Types = require(Shared:WaitForChild("Types"))
local Util = require(Shared:WaitForChild("Util"))
local AssetRegistry = require(Shared:WaitForChild("AssetRegistry"))

local PartFactory = require(script.Parent.PartFactory)

local PropsBuilder = {}

local function buildStylizedNpc(parent: Instance, basePos: Vector3, shirtColor: Color3, hatColor: Color3)
	PartFactory.Block(parent, "NpcLegs", Vector3.new(2.2, 2.2, 1.2), CFrame.new(basePos + Vector3.new(0, 1.1, 0)), Color3.fromRGB(52, 74, 112))
	PartFactory.Block(parent, "NpcTorso", Vector3.new(2.4, 2.4, 1.3), CFrame.new(basePos + Vector3.new(0, 3.4, 0)), shirtColor)
	PartFactory.Ball(parent, "NpcHead", 2.0, basePos + Vector3.new(0, 5.5, 0), Color3.fromRGB(255, 216, 178), Enum.Material.SmoothPlastic, false)
	PartFactory.VerticalCylinder(parent, "NpcHatBrim", 0.3, 3.1, CFrame.new(basePos + Vector3.new(0, 6.35, 0)), hatColor)
	PartFactory.VerticalCylinder(parent, "NpcHatTop", 1.0, 1.9, CFrame.new(basePos + Vector3.new(0, 6.85, 0)), hatColor)
end

function PropsBuilder.BuildWoodenDock(islandFolder: Folder, center: Vector3, accentColor: Color3)
	local dockModel = Instance.new("Model")
	dockModel.Name = "FishingDock"
	dockModel.Parent = islandFolder

	local woodMain = Color3.fromRGB(162, 112, 68)
	local woodDark = Color3.fromRGB(116, 78, 46)

	-- San cau go dai ra bien phia Nam (Z duong)
	PartFactory.Block(dockModel, "DockDeck", Vector3.new(18, 0.9, 54), CFrame.new(center + Vector3.new(0, 0.35, 84)), woodMain, Enum.Material.WoodPlanks)
	PartFactory.Block(dockModel, "DockEndPlatform", Vector3.new(28, 0.9, 16), CFrame.new(center + Vector3.new(0, 0.35, 115)), woodMain, Enum.Material.WoodPlanks)

	-- Coc go va den long 2 ben cau
	for _, zOff in ipairs({ 64, 82, 100, 120 }) do
		for _, xOff in ipairs({ -8.5, 8.5 }) do
			local postX = if zOff == 120 then xOff * 1.45 else xOff
			PartFactory.VerticalCylinder(dockModel, "DockPost", 8.5, 1.3, CFrame.new(center + Vector3.new(postX, -2.0, zOff)), woodDark, Enum.Material.Wood)
			if zOff == 64 or zOff == 120 then
				PartFactory.Ball(dockModel, "DockLantern", 1.3, center + Vector3.new(postX, 2.8, zOff), accentColor, Enum.Material.Neon, false)
			end
		end
	end

	-- Vong sang goi y vi tri cau ca dep nhat tren mui cau
	local spot = PartFactory.VerticalCylinder(
		dockModel,
		"BestFishSpot",
		0.25,
		7.5,
		CFrame.new(center + Vector3.new(0, 0.85, 117)),
		Color3.fromRGB(88, 240, 255),
		Enum.Material.Neon,
		false,
		0.35
	)
	PartFactory.AddBillboard(spot, "FISHING PIER", "Click Cast or Tap FISH!", Color3.fromRGB(110, 245, 255), 3.4)
end

function PropsBuilder.BuildMarketStalls(islandFolder: Folder, islandDef: Types.IslandDef)
	local center = islandDef.centerPosition

	-- 1. Quay Ban Ca (Fish Market - Ben Trai Duong Ra Cau)
	local sellFolder = Instance.new("Model")
	sellFolder.Name = "SellMarket"
	sellFolder.Parent = islandFolder
	local sellPos = center + Vector3.new(-28, 0, 44)

	local counter = PartFactory.Block(sellFolder, "SellCounter", Vector3.new(13, 3.6, 6), CFrame.new(sellPos + Vector3.new(0, 1.8, 0)), Color3.fromRGB(168, 116, 72), Enum.Material.WoodPlanks)
	PartFactory.Block(sellFolder, "CounterTop", Vector3.new(13.8, 0.5, 6.8), CFrame.new(sellPos + Vector3.new(0, 3.8, 0)), Color3.fromRGB(242, 226, 196))
	for _, xP in ipairs({ -5.8, 5.8 }) do
		for _, zP in ipairs({ -2.4, 2.4 }) do
			PartFactory.VerticalCylinder(sellFolder, "Post", 9.0, 0.7, CFrame.new(sellPos + Vector3.new(xP, 4.5, zP)), Color3.fromRGB(122, 82, 48), Enum.Material.Wood)
		end
	end
	PartFactory.Block(sellFolder, "Roof", Vector3.new(15.2, 1.1, 8.6), CFrame.new(sellPos + Vector3.new(0, 9.2, 0)) * CFrame.Angles(math.rad(8), 0, 0), Color3.fromRGB(245, 92, 76))
	PartFactory.Block(sellFolder, "RoofStripe", Vector3.new(5.2, 1.18, 8.7), CFrame.new(sellPos + Vector3.new(0, 9.22, 0)) * CFrame.Angles(math.rad(8), 0, 0), Color3.fromRGB(255, 246, 224))
	buildStylizedNpc(sellFolder, sellPos + Vector3.new(0, 0, -4.2), Color3.fromRGB(245, 152, 56), Color3.fromRGB(245, 214, 92))

	PartFactory.AddBillboard(counter, "FISH MARKET", "Sell Your Catch for Gold!", Color3.fromRGB(255, 222, 76), 8.8)
	PartFactory.AddPrompt(counter, "Sell All Fish", "Fish Market", 16, "SellAll", { IslandId = islandDef.id })

	-- 2. Quay Cua Hang Can Cau & Phu Kien (Angler Shop - Ben Phai)
	local shopFolder = Instance.new("Model")
	shopFolder.Name = "RodShopStall"
	shopFolder.Parent = islandFolder
	local shopPos = center + Vector3.new(28, 0, 44)

	local shopCounter = PartFactory.Block(shopFolder, "ShopCounter", Vector3.new(13, 3.6, 6), CFrame.new(shopPos + Vector3.new(0, 1.8, 0)), Color3.fromRGB(76, 114, 168), Enum.Material.WoodPlanks)
	PartFactory.Block(shopFolder, "CounterTop", Vector3.new(13.8, 0.5, 6.8), CFrame.new(shopPos + Vector3.new(0, 3.8, 0)), Color3.fromRGB(232, 244, 255))
	for _, xP in ipairs({ -5.8, 5.8 }) do
		for _, zP in ipairs({ -2.4, 2.4 }) do
			PartFactory.VerticalCylinder(shopFolder, "Post", 9.0, 0.7, CFrame.new(shopPos + Vector3.new(xP, 4.5, zP)), Color3.fromRGB(64, 82, 116), Enum.Material.Wood)
		end
	end
	PartFactory.Block(shopFolder, "Roof", Vector3.new(15.2, 1.1, 8.6), CFrame.new(shopPos + Vector3.new(0, 9.2, 0)) * CFrame.Angles(math.rad(8), 0, 0), Color3.fromRGB(56, 168, 255))
	PartFactory.Block(shopFolder, "RoofStripe", Vector3.new(5.2, 1.18, 8.7), CFrame.new(shopPos + Vector3.new(0, 9.22, 0)) * CFrame.Angles(math.rad(8), 0, 0), Color3.fromRGB(245, 250, 255))
	buildStylizedNpc(shopFolder, shopPos + Vector3.new(0, 0, -4.2), Color3.fromRGB(62, 182, 245), Color3.fromRGB(48, 72, 128))

	PartFactory.AddBillboard(shopCounter, "ANGLER SHOP", "Rods, Bait & Gym Gear", Color3.fromRGB(98, 224, 255), 8.8)
	PartFactory.AddPrompt(shopCounter, "Open Shop", "Angler Shop", 16, "OpenShop", { IslandId = islandDef.id })
end

local function buildGymEquipmentVisual(parent: Instance, stationType: string, pos: Vector3, accentColor: Color3)
	local override = AssetRegistry.TryClone("Gym", stationType, true)
	if override then
		override:PivotTo(CFrame.new(pos))
		override.Parent = parent
		return
	end

	local metalDark = Color3.fromRGB(52, 58, 72)
	local silver = Color3.fromRGB(205, 214, 226)

	if stationType == "Dumbbells" then
		PartFactory.Block(parent, "RackBase", Vector3.new(7.5, 2.6, 2.4), CFrame.new(pos + Vector3.new(0, 1.3, -3.6)), metalDark, Enum.Material.Metal)
		for _, xOff in ipairs({ -2.1, 2.1 }) do
			local dbPos = pos + Vector3.new(xOff, 2.9, -3.6)
			PartFactory.Block(parent, "Handle", Vector3.new(1.8, 0.35, 0.35), CFrame.new(dbPos), silver, Enum.Material.Metal)
			PartFactory.Block(parent, "WeightL", Vector3.new(0.55, 1.25, 1.25), CFrame.new(dbPos + Vector3.new(-0.85, 0, 0)), accentColor)
			PartFactory.Block(parent, "WeightR", Vector3.new(0.55, 1.25, 1.25), CFrame.new(dbPos + Vector3.new(0.85, 0, 0)), accentColor)
		end
	elseif stationType == "Treadmill" then
		PartFactory.Block(parent, "BeltBase", Vector3.new(4.8, 0.7, 8.2), CFrame.new(pos + Vector3.new(0, 0.45, 0)), metalDark, Enum.Material.Metal)
		PartFactory.Block(parent, "RunningBelt", Vector3.new(3.6, 0.76, 7.2), CFrame.new(pos + Vector3.new(0, 0.48, 0.2)), Color3.fromRGB(32, 36, 44))
		PartFactory.Block(parent, "PostL", Vector3.new(0.45, 4.4, 0.45), CFrame.new(pos + Vector3.new(-2.1, 2.4, -3.4)), silver, Enum.Material.Metal)
		PartFactory.Block(parent, "PostR", Vector3.new(0.45, 4.4, 0.45), CFrame.new(pos + Vector3.new(2.1, 2.4, -3.4)), silver, Enum.Material.Metal)
		PartFactory.Block(parent, "Console", Vector3.new(4.8, 1.4, 1.1), CFrame.new(pos + Vector3.new(0, 4.5, -3.5)) * CFrame.Angles(math.rad(-22), 0, 0), accentColor)
	else
		PartFactory.Block(parent, "BenchPad", Vector3.new(2.8, 1.5, 6.8), CFrame.new(pos + Vector3.new(0, 0.9, 0.4)), accentColor)
		PartFactory.Block(parent, "UprightL", Vector3.new(0.5, 4.8, 0.5), CFrame.new(pos + Vector3.new(-2.4, 2.4, -2.4)), metalDark, Enum.Material.Metal)
		PartFactory.Block(parent, "UprightR", Vector3.new(0.5, 4.8, 0.5), CFrame.new(pos + Vector3.new(2.4, 2.4, -2.4)), metalDark, Enum.Material.Metal)
		PartFactory.Block(parent, "Barbell", Vector3.new(8.2, 0.35, 0.35), CFrame.new(pos + Vector3.new(0, 4.1, -2.4)), silver, Enum.Material.Metal)
		for _, side in ipairs({ -3.4, 3.4 }) do
			PartFactory.VerticalCylinder(parent, "Plate", 0.55, 2.4, CFrame.new(pos + Vector3.new(side, 4.1, -2.4)) * CFrame.Angles(0, 0, math.rad(90)), Color3.fromRGB(255, 86, 86))
		end
	end
end

function PropsBuilder.BuildGymZone(islandFolder: Folder, islandDef: Types.IslandDef)
	local gymFolder = Instance.new("Model")
	gymFolder.Name = "GymZone"
	gymFolder.Parent = islandFolder

	local stationColors = {
		Color3.fromRGB(82, 214, 126),
		Color3.fromRGB(68, 178, 255),
		Color3.fromRGB(255, 152, 62),
	}

	for idx, st in ipairs(islandDef.gymStations) do
		local stModel = Instance.new("Model")
		stModel.Name = "GymStation_" .. tostring(idx)
		stModel.Parent = gymFolder

		local worldPos = islandDef.centerPosition + st.offset
		local color = stationColors[idx] or islandDef.theme.accentColor

		local pad = PartFactory.VerticalCylinder(stModel, "GymPad", 0.5, 13.5, CFrame.new(worldPos + Vector3.new(0, 0.25, 0)), Color3.fromRGB(44, 52, 68))
		PartFactory.VerticalCylinder(stModel, "GymRing", 0.56, 12.2, CFrame.new(worldPos + Vector3.new(0, 0.26, 0)), color, Enum.Material.Neon, false, 0.25)

		pad:SetAttribute("IsGymPad", true)
		pad:SetAttribute("IslandId", islandDef.id)
		pad:SetAttribute("StationIndex", idx)
		pad:SetAttribute("StationType", st.stationType)
		pad:SetAttribute("MinStrength", st.minStrength)

		buildGymEquipmentVisual(stModel, st.stationType, worldPos + Vector3.new(0, 0.5, 0), color)

		local gainPerRep = math.floor(islandDef.baseGymGain * st.multiplier)
		local reqText = if st.minStrength > 0 then ("Req: " .. Util.FormatNumber(st.minStrength) .. " Str") else "Starter Station"
		PartFactory.AddBillboard(
			pad,
			string.format("%s (+%s Str)", st.name, Util.FormatNumber(gainPerRep)),
			reqText .. " • Click to Train!",
			color,
			6.6
		)
		PartFactory.AddPrompt(pad, "Train (" .. st.name .. ")", "Gym Station", 13, "GymFocus", {
			IslandId = islandDef.id,
			StationIndex = idx,
		})
	end
end

function PropsBuilder.BuildEggPedestals(islandFolder: Folder, islandDef: Types.IslandDef, goldCost: number, gemCost: number)
	local eggFolder = Instance.new("Model")
	eggFolder.Name = "EggPedestals"
	eggFolder.Parent = islandFolder

	local specs = {
		{ eggId = islandDef.goldEggId, title = "GOLD EGG", sub = Util.FormatNumber(goldCost) .. " Gold", offset = Vector3.new(50, 0, -12), color = Color3.fromRGB(255, 208, 64) },
		{ eggId = islandDef.gemEggId, title = "MYTHIC GEM EGG", sub = Util.FormatNumber(gemCost) .. " Gems", offset = Vector3.new(50, 0, 12), color = Color3.fromRGB(214, 96, 255) },
	}

	for _, sp in ipairs(specs) do
		local pos = islandDef.centerPosition + sp.offset
		local base = PartFactory.VerticalCylinder(eggFolder, "Pedestal_" .. sp.eggId, 2.8, 7.2, CFrame.new(pos + Vector3.new(0, 1.4, 0)), Color3.fromRGB(236, 240, 248))
		PartFactory.VerticalCylinder(eggFolder, "PedestalRim", 0.45, 7.8, CFrame.new(pos + Vector3.new(0, 2.85, 0)), sp.color, Enum.Material.Neon)

		local egg = PartFactory.Ball(eggFolder, "EggVisual_" .. sp.eggId, 4.2, pos + Vector3.new(0, 5.6, 0), sp.color, Enum.Material.SmoothPlastic, false)
		egg.Size = Vector3.new(3.8, 4.9, 3.8)
		PartFactory.Ball(eggFolder, "EggCoreGlow", 4.4, pos + Vector3.new(0, 5.6, 0), sp.color, Enum.Material.Neon, false, 0.72)

		PartFactory.AddBillboard(base, sp.title, sp.sub, sp.color, 8.2)
		PartFactory.AddPrompt(base, "Hatch Egg", sp.title, 14, "HatchEgg", {
			EggId = sp.eggId,
			IslandId = islandDef.id,
		})
	end
end

function PropsBuilder.BuildPortals(islandFolder: Folder, islandDef: Types.IslandDef, nextIsland: Types.IslandDef?)
	local portalFolder = Instance.new("Model")
	portalFolder.Name = "IslandPortals"
	portalFolder.Parent = islandFolder

	local northPos = islandDef.centerPosition + Vector3.new(0, 0, -58)
	local frameColor = Color3.fromRGB(72, 82, 108)
	local glowColor = if nextIsland then nextIsland.theme.accentColor else Color3.fromRGB(255, 118, 232)

	PartFactory.Block(portalFolder, "GateBase", Vector3.new(18, 1.2, 6), CFrame.new(northPos + Vector3.new(0, 0.6, 0)), frameColor)
	PartFactory.Block(portalFolder, "PillarL", Vector3.new(2.4, 13, 2.4), CFrame.new(northPos + Vector3.new(-7, 7.1, 0)), frameColor)
	PartFactory.Block(portalFolder, "PillarR", Vector3.new(2.4, 13, 2.4), CFrame.new(northPos + Vector3.new(7, 7.1, 0)), frameColor)
	PartFactory.Block(portalFolder, "TopBeam", Vector3.new(18.5, 2.6, 3.2), CFrame.new(northPos + Vector3.new(0, 14.2, 0)), glowColor)

	local curtain = PartFactory.Block(portalFolder, "PortalField", Vector3.new(11.6, 11.8, 0.8), CFrame.new(northPos + Vector3.new(0, 7.1, 0)), glowColor, Enum.Material.Neon, false, 0.35)

	if nextIsland then
		PartFactory.AddBillboard(
			curtain,
			"ISLAND " .. tostring(nextIsland.id) .. ": " .. string.upper(nextIsland.name),
			"Unlock: " .. Util.FormatNumber(nextIsland.unlockCostGold) .. " Gold",
			glowColor,
			9.2
		)
		PartFactory.AddPrompt(curtain, "Unlock / Travel", nextIsland.name, 16, "PortalNext", {
			TargetIslandId = nextIsland.id,
		})
	else
		PartFactory.AddBillboard(
			curtain,
			"COMING SOON!",
			"New Islands & Bosses in Next Update!",
			Color3.fromRGB(255, 214, 92),
			9.2
		)
	end

	if islandDef.id > 1 then
		local hubPad = PartFactory.VerticalCylinder(
			portalFolder,
			"ReturnHubPad",
			0.6,
			8.0,
			CFrame.new(islandDef.centerPosition + Vector3.new(-24, 0.3, -56)),
			Color3.fromRGB(82, 224, 255),
			Enum.Material.Neon
		)
		PartFactory.AddBillboard(hubPad, "SUNNY SHORES", "Return to Island 1", Color3.fromRGB(110, 245, 255), 4.8)
		PartFactory.AddPrompt(hubPad, "Teleport to Island 1", "Return Portal", 13, "PortalTravel", {
			TargetIslandId = 1,
		})
	end
end

return PropsBuilder
