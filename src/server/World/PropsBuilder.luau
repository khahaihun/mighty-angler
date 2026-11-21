--!strict
-- PropsBuilder.luau: Dung cau go cau ca, quay Sell/Shop, 3 may Gym, tru Trung Pet va cong Dao

local ReplicatedStorage = game:GetService("ReplicatedStorage")
local Shared = ReplicatedStorage:WaitForChild("Shared")
local Types = require(Shared:WaitForChild("Types"))
local Util = require(Shared:WaitForChild("Util"))
local AssetRegistry = require(Shared:WaitForChild("AssetRegistry"))

local PartFactory = require(script.Parent.PartFactory)
local ManualIslandAdapter = require(script.Parent.ManualIslandAdapter)

local PropsBuilder = {}

function PropsBuilder.BuildWoodenDock(islandFolder: Folder, center: Vector3, accentColor: Color3, manualIsland: Instance?)
	local dockCf = ManualIslandAdapter.GetMarkerCFrame(manualIsland, "Dock", CFrame.new(center))
	local dockOrigin = dockCf.Position

	local override = AssetRegistry.TryClone("Buildings", "FishingDock", true)
	if override and override.PrimaryPart then
		override.Name = "FishingDock"
		override:PivotTo(dockCf)
		override.Parent = islandFolder
		PartFactory.AddBillboard(override.PrimaryPart, "FISHING PIER", "Equip Rod [1] • Hold & Release on Water!", Color3.fromRGB(110, 245, 255), 5.0)
		return
	end

	local dockModel = Instance.new("Model")
	dockModel.Name = "FishingDock"
	dockModel.Parent = islandFolder

	local woodMain = Color3.fromRGB(162, 112, 68)
	local woodDark = Color3.fromRGB(116, 78, 46)

	-- San cau go dai ra bien phia Nam (Z duong)
	PartFactory.Block(dockModel, "DockDeck", Vector3.new(18, 0.9, 54), CFrame.new(dockOrigin + Vector3.new(0, 0.35, 84)), woodMain, Enum.Material.WoodPlanks)
	PartFactory.Block(dockModel, "DockEndPlatform", Vector3.new(28, 0.9, 16), CFrame.new(dockOrigin + Vector3.new(0, 0.35, 115)), woodMain, Enum.Material.WoodPlanks)

	-- Coc go va den long 2 ben cau
	for _, zOff in ipairs({ 64, 82, 100, 120 }) do
		for _, xOff in ipairs({ -8.5, 8.5 }) do
			local postX = if zOff == 120 then xOff * 1.45 else xOff
			PartFactory.VerticalCylinder(dockModel, "DockPost", 8.5, 1.3, CFrame.new(dockOrigin + Vector3.new(postX, -2.0, zOff)), woodDark, Enum.Material.Wood)
			if zOff == 64 or zOff == 120 then
				PartFactory.Ball(dockModel, "DockLantern", 1.3, dockOrigin + Vector3.new(postX, 2.8, zOff), accentColor, Enum.Material.Neon, false)
			end
		end
	end

	-- Vong sang goi y vi tri cau ca dep nhat tren mui cau
	local spot = PartFactory.VerticalCylinder(
		dockModel,
		"BestFishSpot",
		0.25,
		7.5,
		CFrame.new(dockOrigin + Vector3.new(0, 0.85, 117)),
		Color3.fromRGB(88, 240, 255),
		Enum.Material.Neon,
		false,
		0.35
	)
	PartFactory.AddBillboard(spot, "FISHING PIER", "Equip Rod [1] • Hold & Release on Water!", Color3.fromRGB(110, 245, 255), 3.4)
end

function PropsBuilder.BuildMarketStalls(islandFolder: Folder, islandDef: Types.IslandDef, manualIsland: Instance?)
	local center = islandDef.centerPosition

	-- 1. Quay Ban Ca (Fish Market - Ben Trai Duong Ra Cau)
	local sellCf = ManualIslandAdapter.GetMarkerCFrame(manualIsland, "SellMarket", CFrame.new(center + Vector3.new(-28, 0, 44)))
	local sellPos = sellCf.Position
	local sellOverride = AssetRegistry.TryClone("Buildings", "SellMarket", true)
	if sellOverride and sellOverride.PrimaryPart then
		sellOverride.Name = "SellMarket"
		sellOverride:PivotTo(sellCf)
		sellOverride.Parent = islandFolder
		PartFactory.AddBillboard(sellOverride.PrimaryPart, "FISH MARKET", "Talk to Captain Barnaby!", Color3.fromRGB(255, 222, 76), 8.8)
		PartFactory.AddPrompt(sellOverride.PrimaryPart, "Talk to Merchant", "Fish Market", 16, "NpcMerchant", { IslandId = islandDef.id })
	else
		local sellFolder = Instance.new("Model")
		sellFolder.Name = "SellMarket"
		sellFolder.Parent = islandFolder
		local counter = PartFactory.Block(sellFolder, "SellCounter", Vector3.new(13, 3.6, 6), CFrame.new(sellPos + Vector3.new(0, 1.8, 0)), Color3.fromRGB(168, 116, 72), Enum.Material.WoodPlanks)
		PartFactory.Block(sellFolder, "CounterTop", Vector3.new(13.8, 0.5, 6.8), CFrame.new(sellPos + Vector3.new(0, 3.8, 0)), Color3.fromRGB(242, 226, 196))
		for _, xP in ipairs({ -5.8, 5.8 }) do
			for _, zP in ipairs({ -2.4, 2.4 }) do
				PartFactory.VerticalCylinder(sellFolder, "Post", 9.0, 0.7, CFrame.new(sellPos + Vector3.new(xP, 4.5, zP)), Color3.fromRGB(122, 82, 48), Enum.Material.Wood)
			end
		end
		PartFactory.Block(sellFolder, "Roof", Vector3.new(15.2, 1.1, 8.6), CFrame.new(sellPos + Vector3.new(0, 9.2, 0)) * CFrame.Angles(math.rad(8), 0, 0), Color3.fromRGB(245, 92, 76))
		PartFactory.Block(sellFolder, "RoofStripe", Vector3.new(5.2, 1.18, 8.7), CFrame.new(sellPos + Vector3.new(0, 9.22, 0)) * CFrame.Angles(math.rad(8), 0, 0), Color3.fromRGB(255, 246, 224))
		PartFactory.AddBillboard(counter, "FISH MARKET", "Talk to Captain Barnaby!", Color3.fromRGB(255, 222, 76), 8.8)
		PartFactory.AddPrompt(counter, "Talk to Merchant", "Fish Market", 16, "NpcMerchant", { IslandId = islandDef.id })
	end

	-- 2. Quay Cua Hang Can Cau & Phu Kien (Angler Shop - Ben Phai)
	local shopCf = ManualIslandAdapter.GetMarkerCFrame(manualIsland, "RodShop", CFrame.new(center + Vector3.new(28, 0, 44)))
	local shopPos = shopCf.Position
	local shopOverride = AssetRegistry.TryClone("Buildings", "RodShopStall", true)
	if shopOverride and shopOverride.PrimaryPart then
		shopOverride.Name = "RodShopStall"
		shopOverride:PivotTo(shopCf)
		shopOverride.Parent = islandFolder
		PartFactory.AddBillboard(shopOverride.PrimaryPart, "ANGLER SHOP", "Rods, Bait & Exclusive Gear", Color3.fromRGB(98, 224, 255), 8.8)
		PartFactory.AddPrompt(shopOverride.PrimaryPart, "Talk to Crafter", "Angler Shop", 16, "NpcShop", { IslandId = islandDef.id })
	else
		local shopFolder = Instance.new("Model")
		shopFolder.Name = "RodShopStall"
		shopFolder.Parent = islandFolder
		local shopCounter = PartFactory.Block(shopFolder, "ShopCounter", Vector3.new(13, 3.6, 6), CFrame.new(shopPos + Vector3.new(0, 1.8, 0)), Color3.fromRGB(76, 114, 168), Enum.Material.WoodPlanks)
		PartFactory.Block(shopFolder, "CounterTop", Vector3.new(13.8, 0.5, 6.8), CFrame.new(shopPos + Vector3.new(0, 3.8, 0)), Color3.fromRGB(232, 244, 255))
		for _, xP in ipairs({ -5.8, 5.8 }) do
			for _, zP in ipairs({ -2.4, 2.4 }) do
				PartFactory.VerticalCylinder(shopFolder, "Post", 9.0, 0.7, CFrame.new(shopPos + Vector3.new(xP, 4.5, zP)), Color3.fromRGB(64, 82, 116), Enum.Material.Wood)
			end
		end
		PartFactory.Block(shopFolder, "Roof", Vector3.new(15.2, 1.1, 8.6), CFrame.new(shopPos + Vector3.new(0, 9.2, 0)) * CFrame.Angles(math.rad(8), 0, 0), Color3.fromRGB(56, 168, 255))
		PartFactory.Block(shopFolder, "RoofStripe", Vector3.new(5.2, 1.18, 8.7), CFrame.new(shopPos + Vector3.new(0, 9.22, 0)) * CFrame.Angles(math.rad(8), 0, 0), Color3.fromRGB(245, 250, 255))
		PartFactory.AddBillboard(shopCounter, "ANGLER SHOP", "Rods, Bait & Exclusive Gear", Color3.fromRGB(98, 224, 255), 8.8)
		PartFactory.AddPrompt(shopCounter, "Talk to Crafter", "Angler Shop", 16, "NpcShop", { IslandId = islandDef.id })
	end
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

function PropsBuilder.BuildGymZone(islandFolder: Folder, islandDef: Types.IslandDef, manualIsland: Instance?)
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

		local stCf = ManualIslandAdapter.GetMarkerCFrame(manualIsland, "Gym_" .. tostring(idx), CFrame.new(islandDef.centerPosition + st.offset))
		local worldPos = stCf.Position
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

function PropsBuilder.BuildEggPedestals(islandFolder: Folder, islandDef: Types.IslandDef, goldCost: number, gemCost: number, manualIsland: Instance?)
	local eggFolder = Instance.new("Model")
	eggFolder.Name = "EggPedestals"
	eggFolder.Parent = islandFolder

	local specs: { { eggId: string, marker: string, title: string, sub: string, offset: Vector3, color: Color3, isExclusive: boolean } } = {
		{ eggId = islandDef.goldEggId, marker = "EggGold", title = "GOLD EGG", sub = Util.FormatNumber(goldCost) .. " Gold", offset = Vector3.new(50, 0, -12), color = Color3.fromRGB(255, 208, 64), isExclusive = false },
	}
	if islandDef.gemEggId and islandDef.gemEggId ~= "" then
		table.insert(specs, {
			eggId = islandDef.gemEggId,
			marker = "EggGem",
			title = "👑 EXCLUSIVE GEM EGG",
			sub = Util.FormatNumber(gemCost) .. " Gems • Scales w/ Best Pet!",
			offset = Vector3.new(50, 0, 12),
			color = Color3.fromRGB(214, 96, 255),
			isExclusive = true,
		})
	end

	for _, sp in ipairs(specs) do
		local pedCf = ManualIslandAdapter.GetMarkerCFrame(manualIsland, sp.marker, CFrame.new(islandDef.centerPosition + sp.offset))
		local pos = pedCf.Position
		local baseH = if sp.isExclusive then 3.4 else 2.8
		local baseDiam = if sp.isExclusive then 8.6 else 7.2
		local base = PartFactory.VerticalCylinder(eggFolder, "Pedestal_" .. sp.eggId, baseH, baseDiam, CFrame.new(pos + Vector3.new(0, baseH * 0.5, 0)), if sp.isExclusive then Color3.fromRGB(54, 38, 86) else Color3.fromRGB(236, 240, 248))
		PartFactory.VerticalCylinder(eggFolder, "PedestalRim", 0.48, baseDiam + 0.7, CFrame.new(pos + Vector3.new(0, baseH + 0.08, 0)), sp.color, Enum.Material.Neon)
		if sp.isExclusive then
			PartFactory.VerticalCylinder(eggFolder, "ExclusiveHalo", 0.22, baseDiam + 2.4, CFrame.new(pos + Vector3.new(0, 0.14, 0)), Color3.fromRGB(255, 218, 72), Enum.Material.Neon, false, 0.25)
		end

		local eggCenter = pos + Vector3.new(0, baseH + 3.0, 0)
		local eggOverride = AssetRegistry.TryClone("Eggs", sp.eggId, true)
		if eggOverride and eggOverride.PrimaryPart then
			eggOverride.Name = "EggVisual_" .. sp.eggId
			eggOverride:PivotTo(CFrame.new(eggCenter))
			eggOverride.Parent = eggFolder
		else
			local egg = PartFactory.Ball(eggFolder, "EggVisual_" .. sp.eggId, if sp.isExclusive then 4.6 else 4.2, eggCenter, sp.color, Enum.Material.SmoothPlastic, false)
			egg.Size = if sp.isExclusive then Vector3.new(4.2, 5.4, 4.2) else Vector3.new(3.8, 4.9, 3.8)
			PartFactory.Ball(eggFolder, "EggCoreGlow", if sp.isExclusive then 4.9 else 4.4, eggCenter, if sp.isExclusive then Color3.fromRGB(255, 224, 96) else sp.color, Enum.Material.Neon, false, 0.72)
		end

		PartFactory.AddBillboard(base, sp.title, sp.sub, sp.color, baseH + 5.8)
		PartFactory.AddPrompt(base, "Hatch Egg", sp.title, 14, "HatchEgg", {
			EggId = sp.eggId,
			IslandId = islandDef.id,
		})
	end
end

function PropsBuilder.BuildPortals(islandFolder: Folder, islandDef: Types.IslandDef, nextIsland: Types.IslandDef?, manualIsland: Instance?)
	local portalFolder = Instance.new("Model")
	portalFolder.Name = "IslandPortals"
	portalFolder.Parent = islandFolder

	local northCf = ManualIslandAdapter.GetMarkerCFrame(manualIsland, "PortalNext", CFrame.new(islandDef.centerPosition + Vector3.new(0, 0, -58)))
	local northPos = northCf.Position
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
