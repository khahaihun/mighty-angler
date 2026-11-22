local function noop() end

local function node(name)
	return setmetatable({ Name = name, WaitForChild = function(_, key) return node(key) end }, {
		__index = function(_, key) return node(key) end,
	})
end

local vectorMt = {}
local function vector(x, y, z)
	return setmetatable({ X = x, Y = y, Z = z }, vectorMt)
end
vectorMt.__add = function(a, b) return vector(a.X + b.X, a.Y + b.Y, a.Z + b.Z) end
vectorMt.__index = function(v, key)
	if key == "Magnitude" then return math.sqrt(v.X ^ 2 + v.Y ^ 2 + v.Z ^ 2) end
end

local observedTables = {
	Net = "rateBuckets",
	RemoteRateLimiter = "buckets",
	FishingService = "forcedRarityDev",
	FishingCastState = "enabled, charges, intentIds, readyAt, manualReadyAt",
	FishingSessionManager = "sessions",
	GymService = "lastManualRepAt, lastReqToastAt, autoTrainActive",
}

return function(sources)
	local now, profileReads = 100, 0
	local profiles, adding, removing, handlers, probes = {}, {}, {}, {}, {}
	local players = {
		PlayerAdded = { Connect = function(_, callback) table.insert(adding, callback) end },
		PlayerRemoving = { Connect = function(_, callback) table.insert(removing, callback) end },
	}
	local existingPlayer = { Parent = players }
	players.GetPlayers = function() return { existingPlayer } end
	local services = {
		Players = players,
		Workspace = { GetServerTimeNow = function() return now end },
		ReplicatedStorage = node("ReplicatedStorage"),
		RunService = { IsServer = function() return true end },
	}
	local perk = { CanAutoTrain = function() return true end, HasGamepass = function() return true end, OnGamepassUnlocked = noop }
	local station = { offset = vector(0, 0, 0), minStrength = 100, name = "Test Station" }
	local island = { centerPosition = vector(0, 0, 0), gymStations = { station } }
	local modules = {
		PerkService = perk,
		BuffAggregator = { RegisterProvider = noop },
		Util = { NewUid = function() return "session" end, FormatNumber = tostring },
		DataService = {
			OnProfileLoaded = noop,
			IsTransactionLocked = function() return false end,
			Get = function(player)
				profileReads += 1
				return profiles[player]
			end,
		},
		Islands = { Get = function() return island end, ById = { island } },
		GymGearConfig = { ByLevel = {} },
	}
	local env = setmetatable({
		game = { GetService = function(_, name) return assert(services[name], name) end },
		os = { clock = function() return now end },
		Color3 = { fromRGB = noop },
		Vector3 = { new = vector },
		typeof = function(v) return if getmetatable(v) == vectorMt then "Vector3" else typeof(v) end,
		task = { spawn = noop },
	}, { __index = getfenv() })
	local function load(name)
		if modules[name] then return modules[name] end
		local source = sources[name]
		if not source then return {} end
		if observedTables[name] then
			-- Observe private maps without adding a production test API or depending on the GC.
			local count
			source, count = source:gsub("\nreturn " .. name .. "%s*$",
				"\nreturn " .. name .. ", function() return " .. observedTables[name] .. " end")
			assert(count == 1, name)
		end
		local chunk = assert(loadstring(source, "@" .. name))
		setfenv(chunk, setmetatable({ script = node(name), require = function(ref) return load(ref.Name) end }, { __index = env }))
		local result, observe = chunk()
		modules[name], probes[name] = result, observe
		return result
	end
	local net = load("Net")
	net.GetEvent = function(action)
		return { OnServerEvent = { Connect = function(_, callback)
			assert(not handlers[action], "duplicate registration: " .. action)
			handlers[action] = callback
		end } }
	end
	net.FireClient = noop
	local config = load("GameConfig")
	local limiter = load("RemoteRateLimiter")
	for _, name in ipairs({
		"CurrencyService", "ShopAndItemsService", "FishingService", "PetsService",
		"GymService", "EnchantAndBountyService", "IslandService", "ProgressionService",
	}) do
		load(name).Init()
	end
	local c2s = net.ClientToServer
	local function join()
		local player = { Parent = players }
		for _, callback in ipairs(adding) do callback(player) end
		return player
	end
	local function leave(player)
		for _, callback in ipairs(removing) do callback(player) end
		assert(not limiter.Allow(player, c2s.GymRep), "departing player cannot recreate a bucket")
		player.Parent, profiles[player] = nil, nil
	end
	assert(limiter.Allow(existingPlayer, c2s.GymRep), "players present at module startup are tracked")
	leave(existingPlayer)
	local function send(action, player, ...)
		assert(handlers[action], "missing handler: " .. action)(player, ...)
	end
	for name, action in pairs(c2s) do
		if name ~= "DevAction" and name ~= "PromptGamepass" and name ~= "FishingMinigameResult" then
			assert(handlers[action], "unbound gameplay action: " .. name)
		end
	end

	local angler, gym = join(), join()
	for index = 1, 100 do
		now = 100 + index * config.AUTO_FISH_PRO_RECAST_SEC
		assert(limiter.Allow(angler, c2s.FishingCastWithAim), "Auto-Fish Pro must pass every 0.45s")
	end
	for index = 1, 100 do
		now = 200 + index / 10
		assert(limiter.Allow(gym, c2s.GymRep), "Gym must tolerate 10 taps/s")
	end
	leave(angler)
	leave(gym)
	print("PASS Auto-Fish Pro 0.45s and Gym 10 taps/sec, 100 calls each")

	local flooded, other = join(), join()
	now = 300
	for _ = 1, 12 do assert(limiter.Allow(flooded, c2s.GymRep)) end
	assert(not limiter.Allow(flooded, c2s.GymRep), "Gym burst is capped at 12")
	assert(limiter.Allow(flooded, c2s.FishingCastWithAim), "action budgets are independent")
	assert(limiter.Allow(other, c2s.GymRep), "player budgets are independent")
	for _, frequency in ipairs({ 50, 100 }) do
		now += 2
		local accepted = 0
		for index = 1, frequency do
			now += 1 / frequency
			if limiter.Allow(flooded, c2s.GymRep) then accepted += 1 end
		end
		assert(accepted == 23, "expected a 12-token burst plus 11 refills, got " .. accepted)
	end
	leave(flooded)
	leave(other)
	print("PASS 50 and 100 requests/sec flood capped to burst plus refill; action and player isolation")

	local validSelection = table.create(config.BAG_CAPACITY, "uid")
	assert(limiter.IsValidPayload(c2s.SellSelectedFish, validSelection), "full bag must be selectable")
	assert(limiter.IsValidPayload(c2s.EquipPet, string.rep("x", 128)))
	assert(limiter.IsValidPayload(c2s.FishingCastWithAim, { castMode = "Auto" }))
	assert(limiter.IsValidPayload(c2s.FishingCastWithAim, { hitWater = false, targetPos = vector(0, -1, 5) }))
	assert(limiter.IsValidPayload(c2s.FishingCastWithAim, { castMode = "Manual", targetPos = vector(-1, 0, 5), holdRatio = 1 }))
	assert(limiter.IsValidPayload(c2s.AppraiseFish))
	assert(limiter.IsValidPayload(c2s.UnlockExclusiveRod, "rod", nil))
	assert(limiter.IsValidPayload(c2s.UpdateSettings, { lowGfx = false }))
	local nested = {}
	nested.loops = nested
	local poison = {
		{ c2s.SellSelectedFish, table.create(5000, "junk") },
		{ c2s.SellSelectedFish, { [1] = "uid", [3] = "uid" } },
		{ c2s.SellSelectedFish, { "uid", garbage = true } },
		{ c2s.SellSelectedFish, { nested } },
		{ c2s.SellSelectedFish, { string.rep("x", 129) } },
		{ c2s.BuyGymGear, 0 / 0 },
		{ c2s.ClaimPlaytimeGift, math.huge },
		{ c2s.UnlockIsland, -math.huge },
		{ c2s.TravelIsland, -1 },
		{ c2s.BuyGymGear, "1" },
		{ c2s.SelectHotbarSlot, 1.5 },
		{ c2s.SelectHotbarSlot, 6 },
		{ c2s.SelectHotbarSlot, string.rep("1", 129) },
		{ c2s.PinFishToSlot, "2.5", "uid" },
		{ c2s.FishingMinigameStrike, "session", 1, -0.2 },
		{ c2s.FishingCastWithAim, { castMode = "Auto", targetPos = vector(0, math.huge, 0) } },
		{ c2s.FishingCastWithAim, { castMode = "Auto", garbage = nested } },
		{ c2s.UpdateSettings, { lowGfx = nested } },
		{ c2s.UpdateSettings, { lowGfx = true, extra = false } },
		{ c2s.SetAutoFish, true, 0 / 0 },
		{ c2s.SetAutoTrain, "true" },
		{ c2s.EquipPet, string.rep("x", 129) },
		{ c2s.GymRep, nested },
	}
	for _, request in ipairs(poison) do
		local action = request[1]
		assert(not limiter.IsValidPayload(action, table.unpack(request, 2)), "invalid payload accepted: " .. action)
		local player = join()
		local before = profileReads
		send(action, player, table.unpack(request, 2))
		assert(profileReads == before, "invalid payload entered gameplay: " .. action)
		leave(player)
	end
	local buyer = join()
	for _ = 1, 4 do send(c2s.BuyGymGear, buyer, 0 / 0) end
	local before = profileReads
	send(c2s.BuyGymGear, buyer, 1)
	assert(profileReads == before, "invalid remote calls must still consume tokens")
	now += 1
	send(c2s.BuyGymGear, buyer, 1)
	assert(profileReads == before + 1, "valid packet reaches the real handler after refill")
	leave(buyer)
	print("PASS 23 malformed packets rejected before gameplay, with no errors and rate cost")

	local castState = load("FishingCastState")
	local sessionManager = load("FishingSessionManager")
	local fishing = load("FishingService")
	local function assertNoPlayers()
		for name, observe in pairs(probes) do
			for index, map in ipairs({ observe() }) do
				assert(next(map) == nil, string.format("%s player map #%d retained an entry", name, index))
			end
		end
	end
	for _ = 1, 100 do
		local player = join()
		profiles[player] = { currentIsland = 1, strength = 0, equippedHotbarSlot = 1, fishBag = {} }
		player.Character = { FindFirstChild = function()
			return { IsA = function() return true end, Position = vector(0, 0, 0) }
		end }
		fishing.SetForcedRarityForDev(player, "Rare")
		castState.Close(player, "prior-session", "Win")
		send(c2s.SetAutoFish, player, true, 1)
		send(c2s.FishingChargeStart, player)
		sessionManager.CreateWaitingSession(player, 1, vector(0, 0, 0), false, "AutoPro", {}, nil, {})
		send(c2s.GymRep, player)
		send(c2s.SetAutoTrain, player, true)
		send(c2s.RequestBagSync, player)
		for name, observe in pairs(probes) do
			for index, map in ipairs({ observe() }) do
				assert(map[player] ~= nil, string.format("%s player map #%d not exercised", name, index))
			end
		end
		leave(player)
		assertNoPlayers()
	end

	local departing = join()
	perk.CanAutoTrain = function() return coroutine.yield() end
	local pending = coroutine.create(function() send(c2s.SetAutoTrain, departing, true) end)
	assert(coroutine.resume(pending))
	assert(coroutine.status(pending) == "suspended")
	leave(departing)
	assert(coroutine.resume(pending, false))
	assert(coroutine.status(pending) == "dead")
	assertNoPlayers()
	print("PASS 100 consecutive joins/leaves emptied all 12 observed player maps; yielding Gym request did not revive state")
end
