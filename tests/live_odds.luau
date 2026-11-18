-- Runs the unmodified odds/roller/aggregator and real item/pet providers; Engine boundaries only.
local function node(name)
	local result = { Name = name }
	setmetatable(result, { __index = function(self, key)
		local child = node(key); rawset(self, key, child); return child
	end })
	function result:WaitForChild(key) return self[key] end
	function result:Connect() return { Disconnect = function() end } end
	return result
end
local profile, activeEvent = {}, nil
local randomValue: number? = nil
local testMath = table.clone(math)
testMath.random = function(...) return if randomValue then randomValue else math.random(...) end
local handlers, buttons, created = {}, {}, {}
local promptCalls = 0
local function instanceNew(class)
	local obj = { ClassName = class, Destroy = function(self) self.Parent = nil end }
	table.insert(created, obj); return obj
end
local net = { OnServerEvent = function(key, callback) handlers[key.Name] = callback end, FireClient = function() end, FireServer = function() promptCalls += 1 end, ServerToClient = node("S2C"), ClientToServer = node("C2S") }
local extraPets = false
local cache = {
	DataService = { Get = function() return profile end, OnProfileLoaded = function() end, MarkDirty = function() end },
	PerkService = { HasGamepass = function(_, key) return extraPets and key == "ExtraPets" end },
	Theme = { Colors = {}, AddCorner = function() end, CreateButton = function(_, name, _, _, _, _, callback) buttons[name] = callback end },
	Net = net, CurrencyService = {}, RodVisuals = {}, PetAndFishVisuals = {},
}
local loadModule
loadModule = function(ref)
	local name = if type(ref) == "string" then ref else ref.Name
	if cache[name] then return cache[name] end
	assert(sources[name], "Missing source " .. name)
	local chunk = assert(loadstring(sources[name], name))
	local environment = setmetatable({
		script = node(name), require = loadModule, math = testMath,
		Instance = { new = instanceNew }, UDim2 = { fromScale = function() return {} end, fromOffset = function() return {} end, new = function() return {} end }, Enum = node("Enum"),
		game = { GetService = function(_, service) return node(service) end },
		Color3 = { fromRGB = function() return {} end, new = function() return {} end },
		Vector3 = { new = function() return {} end }, Vector2 = { new = function() return {} end },
		os = { time = function() return 10000 end },
	}, { __index = getfenv() })
	setfenv(chunk, environment)
	local module = chunk(); cache[name] = module; return module
end
local odds, rods, islands = loadModule("OddsCalculator"), loadModule("RodsConfig"), loadModule("Islands")
local config, enchants, pets = loadModule("GameConfig"), loadModule("EnchantsConfig"), loadModule("PetsConfig")
local buffs, roller = loadModule("BuffAggregator"), loadModule("FishingRoller")
buffs.RegisterProvider(loadModule("PotionAndBaitHelper").ComputeBuffContribution)
loadModule("PetsService").Init()
buffs.RegisterProvider(function() return if activeEvent then { luckAdd = activeEvent.luckAdd, mutationAdd = activeEvent.mutationAdd } else {} end)
local function near(a, b, context) assert(math.abs(a-b) < 1e-8, string.format("%s: %.12f ~= %.12f", context, a, b)) end
local tests = 0
local potionStates = {}
for _, potion in ipairs(loadModule("PotionsConfig").List) do
	if potion.kind == "Luck" or potion.kind == "Mutation" then potionStates[potion.kind] = { potionId = potion.id, expiresAt = 11000 } end
end
local scenarios = {}
local allRods = table.clone(rods.NormalList)
for _, rod in ipairs(rods.ExclusiveList) do table.insert(allRods, rod) end
for _, rod in ipairs(allRods) do
	for _, event in ipairs(loadModule("EventsConfig").List) do
		if rod.isExclusive then
			for _, enchant in ipairs(enchants.List) do table.insert(scenarios, { rod = rod, event = event, enchant = enchant.id }) end
		else table.insert(scenarios, { rod = rod, event = event, enchant = "" }) end
	end
end
for _, island in ipairs(islands.List) do
	for _, scenario in ipairs(scenarios) do
		local rod = scenario.rod
		for _, bait in ipairs(loadModule("BaitConfig").List) do
			for _, castAdd in ipairs({ 0, 0.25, 0, 0.25 }) do
				profile = { rodId = rod.id, strength = 90000, ownedRods = { [rod.id] = true, Twig = true }, rodEnchants = { [rod.id] = scenario.enchant }, rebirths = 0,
					activeBait = bait.id, bait = { [bait.id] = 10 }, gymGearLevel = 0, activePotions = potionStates,
					pets = { { uid = "Tiki", petId = "pet_tiki_spirit" } }, equippedPetUids = { "Tiki" } }
				activeEvent = scenario.event
				local server = buffs.GetMultipliers({}, castAdd, 0)
				local effective = rods.GetEffectiveStats(rod.id, profile.ownedRods, profile.rodEnchants)
				local live = odds.ComputeLiveOdds(island.id, rod.id, profile.ownedRods, profile.rodEnchants, bait.id, profile.bait,
					potionStates, profile.pets, profile.equippedPetUids, castAdd, activeEvent.id, 10000)
				for _, wp in ipairs({ false, true }) do
					local entries = if wp then live.wpOdds else live.fishOdds
					local candidates = roller.GetEligibleCandidates(island, effective.power, effective.maxWeight)
					local total, expected = 0, {}
					local util = loadModule("Util")
					local originalPick = util.PickWeighted
					local rollWeights = {}
					util.PickWeighted = function(list, weight)
						for _, fish in ipairs(list) do rollWeights[fish.id] = weight(fish) end
						return list[1]
					end
					if #candidates > 0 then roller.RollFishSpecies(nil, island, candidates, server, wp) end
					util.PickWeighted = originalPick
					for _, fish in ipairs(candidates) do
						local weight = odds.GetFishWeight(fish, server.luckMult, server.bossChanceMult, wp)
						near(rollWeights[fish.id], weight, "roller weight " .. fish.id)
						expected[fish.id] = weight; total += weight
					end
					local sum = 0
					for _, entry in ipairs(entries) do
						near(entry.effectivePct, (expected[entry.fish.id] or 0) / math.max(0.0001, total) * 100, "species " .. entry.fish.id)
						sum += entry.effectivePct
					end
					near(sum, if #candidates > 0 then 100 else 0, "bucket sum")
					tests += 1
				end
			end
		end
	end
end
local enchantOdds = odds.ComputeEnchantOdds("swift_caster")
local sum, midasSeen = 0, false
for _, entry in ipairs(enchantOdds) do
	sum += entry.effectivePct
	if entry.enchant.id == "swift_caster" then near(entry.effectivePct, 0, "excluded Swift") end
	if entry.enchant.id == "midas_sovereign" then midasSeen = true; near(entry.effectivePct, 4/72*100, "Midas") end
end
assert(midasSeen, "Midas entry required")
near(sum, 100, "enchant sum")
for _, egg in ipairs(pets.Eggs) do local eggSum = 0; for _, entry in ipairs(odds.ComputeEggOdds(egg)) do eggSum += entry.pct end; near(eggSum, 100, "egg sum") end
local tiki = odds.ComputeLiveOdds(1, "Twig", { Twig = true }, {}, nil, {}, {}, { { uid = "T", petId = "pet_tiki_spirit" } }, { "T" }, 0, nil, 10000)
assert(string.find(tiki.mutationSummary, "Shiny 5.5%%"), tiki.mutationSummary)
local shinyUpper = (config.Mutations.Cosmic.chance + config.Mutations.Golden.chance + config.Mutations.Shiny.chance) * 1.1
randomValue = shinyUpper - 1e-8; assert(roller.RollMutation(1.1, 1) == "Shiny")
randomValue = shinyUpper + 1e-8; assert(roller.RollMutation(1.1, 1) == "None")
randomValue = nil
local preview = loadModule("PurchaseOddsSummary").BuildLines({ islandId = 1, rodId = "Twig", ownedRods = { Twig = true }, rodEnchants = {},
	activeBait = nil, baitMap = {}, activePotions = {}, pets = {}, equippedPets = {}, nowSec = 10000, hasAutoPro = false }, "ExclusiveDragonRod")
assert(#preview > 30, "all modes/species must be disclosed")
print("PASS live odds: " .. tests .. " server/provider buckets, excluded species, Swift/Midas, 10 eggs, Tiki 5.5%, purchase preview")

profile = { pets = {}, equippedPetUids = {} }
for idx = 1, 5 do table.insert(profile.pets, { uid = tostring(idx), petId = pets.Eggs[1].pets[1].id }) end
local equipPlayer = { SetAttribute = function() end }
for idx = 1, 3 do handlers.EquipPet(equipPlayer, tostring(idx)) end
assert(#profile.equippedPetUids == 2 and profile.equippedPetUids[1] == "1" and profile.equippedPetUids[2] == "2", "third pet must not replace existing two")
extraPets = true
handlers.EquipPet(equipPlayer, "3"); handlers.EquipPet(equipPlayer, "4"); handlers.EquipPet(equipPlayer, "5")
assert(#profile.equippedPetUids == 4 and profile.equippedPetUids[1] == "1" and profile.equippedPetUids[4] == "4", "fifth pet must be rejected without replacing existing pets")
print("PASS pet equip: server 2 -> 4, third/fifth reject without replacement")

local view = loadModule("PurchaseOddsController")
local ownedBoth = { islandId = 1, rodId = "SeraphimDragon", ownedRods = { Twig = true, SeraphimDragon = true }, rodEnchants = {}, activeBait = nil, baitMap = {}, activePotions = {}, pets = {}, equippedPets = {}, nowSec = 10000, hasAutoPro = true }
local summary = loadModule("PurchaseOddsSummary")
view.SetProvider(function() error("live view must not use the purchase provider") end)
view.SetLiveProvider(function() return summary.BuildLiveLines(ownedBoth, 0, "ManualNormal") end)
view.ShowLive()
local text
for _, object in ipairs(created) do if object.Name == "OddsText" then text = object end end
assert(text and string.find(text.Text, "Base") and string.find(text.Text, "whirlpool"))
local originalText = text.Text
ownedBoth.activeBait = loadModule("BaitConfig").List[1].id; ownedBoth.baitMap[ownedBoth.activeBait] = 5
view.SetLiveProvider(function() return summary.BuildLiveLines(ownedBoth, 0.25, "ManualPerfect") end)
assert(text.Text ~= originalText and string.find(text.Text, "ManualPerfect"), "open live view must refresh cast and buff changes")
assert(buttons.Continue == nil, "viewing live odds cannot expose a purchase action")
buttons.Cancel()
assert(promptCalls == 0, "opening, refreshing, closing live odds must never prompt a purchase")
print("PASS HUD live view: both passes owned, Base/Live by species, cast+buff refresh, close without prompt")
