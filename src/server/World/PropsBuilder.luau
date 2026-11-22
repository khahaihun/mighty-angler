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

	local woodMain = Color3.fromRGB(178, 120, 68)
	local woodTrim = Color3.fromRGB(218, 164, 102)
	local woodDark = Color3.fromRGB(118, 76, 44)

	-- San cau go dai ra bien phia Nam (Z duong) + nep go 2 ben kieu cang nhiet doi Gu B
	PartFactory.Block(dockModel, "DockDeck", Vector3.new(18, 0.9, 54), CFrame.new(dockOrigin + Vector3.new(0, 0.35, 84)), woodMain, Enum.Material.WoodPlanks)
	PartFactory.Block(dockModel, "DockEndPlatform", Vector3.new(28, 0.9, 16), CFrame.new(dockOrigin + Vector3.new(0, 0.35, 115)), woodMain, Enum.Material.WoodPlanks)
	for _, xSide in ipairs({ -8.6, 8.6 }) do
		PartFactory.Block(dockModel, "DockCurb", Vector3.new(0.8, 0.45, 50), CFrame.new(dockOrigin + Vector3.new(xSide, 0.95, 83)), woodTrim, Enum.Material.Wood)
	end
	PartFactory.Block(dockModel, "EndTrimFront", Vector3.new(28.4, 0.45, 0.8), CFrame.new(dockOrigin + Vector3.new(0, 0.95, 122.7)), woodTrim, Enum.Material.Wood)

	-- Coc go, nap dong & den long am 2 ben cau
	for _, zOff in ipairs({ 64, 82, 100, 120 }) do
		for _, xOff in ipairs({ -8.5, 8.5 }) do
			local postX = if zOff == 120 then xOff * 1.45 else xOff
			PartFactory.VerticalCylinder(dockModel, "DockPost", 8.8, 1.4, CFrame.new(dockOrigin + Vector3.new(postX, -1.85, zOff)), woodDark, Enum.Material.Wood)
			PartFactory.VerticalCylinder(dockModel, "PostCap", 0.35, 1.65, CFrame.new(dockOrigin + Vector3.new(postX, 2.55, zOff)), woodTrim, Enum.Material.SmoothPlastic)
			if zOff == 64 or zOff == 120 then
				local lantern = PartFactory.Ball(dockModel, "DockLantern", 1.35, dockOrigin + Vector3.new(postX, 3.25, zOff), accentColor, Enum.Material.Neon, false)
				PartFactory.AddWarmLight(lantern, accentColor, 16, 1.1)
			end
		end
	end

	-- Vong sang 2 lop goi y vi tri cau ca dep nhat tren mui cau
	PartFactory.VerticalCylinder(dockModel, "BestFishHalo", 0.16, 9.2, CFrame.new(dockOrigin + Vector3.new(0, 0.82, 117)), Color3.fromRGB(255, 224, 92), Enum.Material.Neon, false, 0.45)
	local spot = PartFactory.VerticalCylinder(
		dockModel,
		"BestFishSpot",
		0.25,
		7.4,
		CFrame.new(dockOrigin + Vector3.new(0, 0.86, 117)),
		Color3.fromRGB(64, 232, 255),
		Enum.Material.Neon,
		false,
		0.3
	)
	PartFactory.AddBillboard(spot, "FISHING PIER", "Equip Rod [1] • Hold & Release on Water!", Color3.fromRGB(110, 245, 255), 3.4)
end

local function buildCartoonStall(islandFolder: Folder, name: string, pos: Vector3, palette: { Color3 }): Part
	local stall = Instance.new("Model")
	stall.Name = name
	stall.Parent = islandFolder
	local counter = PartFactory.Block(stall, "StallCounter", Vector3.new(13.2, 3.6, 6), CFrame.new(pos + Vector3.new(0, 1.8, 0)), palette[1], Enum.Material.WoodPlanks)
	PartFactory.Block(stall, "CounterBaseTrim", Vector3.new(13.8, 0.65, 6.6), CFrame.new(pos + Vector3.new(0, 0.35, 0)), palette[3])
	PartFactory.Block(stall, "CounterTop", Vector3.new(14.0, 0.55, 6.8), CFrame.new(pos + Vector3.new(0, 3.85, 0)), palette[2])
	for _, xP in ipairs({ -5.8, 5.8 }) do
		for _, zP in ipairs({ -2.4, 2.4 }) do
			PartFactory.VerticalCylinder(stall, "Post", 9.0, 0.72, CFrame.new(pos + Vector3.new(xP, 4.5, zP)), palette[3], Enum.Material.Wood)
		end
	end
	-- Mai bat soc 5 dai tuoi sang theo Gu B
	for s = -2, 2 do
		local col = if s % 2 == 0 then palette[4] else palette[5]
		PartFactory.Block(stall, "AwningStripe", Vector3.new(3.15, 0.95, 8.8), CFrame.new(pos + Vector3.new(s * 3.1, 9.2, 0)) * CFrame.Angles(math.rad(9), 0, 0), col)
		PartFactory.Ball(stall, "AwningScallop", 1.15, pos + Vector3.new(s * 3.1, 8.35, 4.25), col, Enum.Material.SmoothPlastic, false)
	end
	for _, xL in ipairs({ -5.2, 5.2 }) do
		local globe = PartFactory.Ball(stall, "StallLantern", 0.95, pos + Vector3.new(xL, 7.6, 2.7), palette[6], Enum.Material.Neon, false)
		PartFactory.AddWarmLight(globe, palette[6], 14, 0.9)
	end
	return counter
end

function PropsBuilder.BuildMarketStalls(islandFolder: Folder, islandDef: Types.IslandDef, manualIsland: Instance?)
	local center = islandDef.centerPosition
	local stalls = {
		{
			marker = "SellMarket", name = "SellMarket", offset = Vector3.new(-28, 0, 44),
			title = "FISH MARKET", sub = "Talk to Captain Barnaby!", titleCol = Color3.fromRGB(255, 222, 76),
			action = "Talk to Merchant", obj = "Fish Market", kind = "NpcMerchant",
			palette = {
				Color3.fromRGB(176, 118, 68), Color3.fromRGB(252, 236, 202), Color3.fromRGB(122, 78, 44),
				Color3.fromRGB(252, 84, 72), Color3.fromRGB(255, 248, 232), Color3.fromRGB(255, 214, 92),
			},
		},
		{
			marker = "RodShop", name = "RodShopStall", offset = Vector3.new(28, 0, 44),
			title = "ANGLER SHOP", sub = "Rods, Bait & Exclusive Gear", titleCol = Color3.fromRGB(98, 224, 255),
			action = "Talk to Crafter", obj = "Angler Shop", kind = "NpcShop",
			palette = {
				Color3.fromRGB(68, 122, 188), Color3.fromRGB(236, 248, 255), Color3.fromRGB(52, 78, 122),
				Color3.fromRGB(44, 174, 255), Color3.fromRGB(246, 252, 255), Color3.fromRGB(118, 236, 255),
			},
		},
	}

	for _, st in ipairs(stalls) do
		local cf = ManualIslandAdapter.GetMarkerCFrame(manualIsland, st.marker, CFrame.new(center + st.offset))
		local override = AssetRegistry.TryClone("Buildings", st.name, true)
		local host: BasePart
		if override and override.PrimaryPart then
			override.Name = st.name
			override:PivotTo(cf)
			override.Parent = islandFolder
			host = override.PrimaryPart
		else
			host = buildCartoonStall(islandFolder, st.name, cf.Position, st.palette)
		end
		PartFactory.AddBillboard(host, st.title, st.sub, st.titleCol, 8.8)
		PartFactory.AddPrompt(host, st.action, st.obj, 16, st.kind, { IslandId = islandDef.id })
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
		PartFactory.VerticalCylinder(eggFolder, "PedestalStep", 0.7, baseDiam + 1.8, CFrame.new(pos + Vector3.new(0, 0.35, 0)), if sp.isExclusive then Color3.fromRGB(40, 28, 66) else Color3.fromRGB(214, 224, 240))
		local base = PartFactory.VerticalCylinder(eggFolder, "Pedestal_" .. sp.eggId, baseH, baseDiam, CFrame.new(pos + Vector3.new(0, baseH * 0.5, 0)), if sp.isExclusive then Color3.fromRGB(58, 38, 96) else Color3.fromRGB(244, 248, 255))
		PartFactory.VerticalCylinder(eggFolder, "PedestalRim", 0.48, baseDiam + 0.7, CFrame.new(pos + Vector3.new(0, baseH + 0.08, 0)), sp.color, Enum.Material.Neon)
		if sp.isExclusive then
			PartFactory.VerticalCylinder(eggFolder, "ExclusiveHalo", 0.22, baseDiam + 2.8, CFrame.new(pos + Vector3.new(0, 0.14, 0)), Color3.fromRGB(255, 218, 72), Enum.Material.Neon, false, 0.22)
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
			local bandCol = if sp.isExclusive then Color3.fromRGB(255, 224, 88) else Color3.fromRGB(255, 248, 210)
			PartFactory.VerticalCylinder(eggFolder, "EggBelt", 0.55, if sp.isExclusive then 4.35 else 3.95, CFrame.new(eggCenter + Vector3.new(0, -0.15, 0)), bandCol, Enum.Material.Neon, false, 0.15)
			if sp.isExclusive then
				PartFactory.Block(eggFolder, "EggCrown", Vector3.new(1.5, 0.72, 1.5), CFrame.new(eggCenter + Vector3.new(0, 2.85, 0)) * CFrame.Angles(0, math.rad(45), 0), Color3.fromRGB(255, 214, 62), Enum.Material.Neon, false)
				PartFactory.AddWarmLight(egg, Color3.fromRGB(224, 132, 255), 22, 1.3)
			end
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
