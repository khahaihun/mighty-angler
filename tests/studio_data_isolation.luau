-- Run exact production modules in the Luau VM; only Roblox boundaries are faked.
-- Breaks caught: Studio using live names, lost write gate, or overwriting records.
local function equal(actual, expected, label)
	assert(actual == expected, string.format("%s: expected %s, got %s", label, tostring(expected), tostring(actual)))
end

local function node(name, parent)
	local result = { Name = name, Parent = parent }
	setmetatable(result, { __index = function(self, key)
		local child = node(key, self)
		rawset(self, key, child)
		return child
	end })
	function result:WaitForChild(key) return self[key] end
	return result
end

local function fixture(sources, studio, placeId, failedStore)
	local opens, writes, stores, threads = {}, {}, {}, {}
	local writable = { UserId = 101, DisplayName = "Writable" }
	local readOnly = { UserId = 102, DisplayName = "ReadOnly" }
	local missing = { UserId = 103, DisplayName = "Missing" }
	local profiles = {
		[writable] = { strength = 125.9, totalStrength = 500, stats = { goldEarned = 250.8 } },
		[readOnly] = { strength = 999999, totalStrength = 999999, stats = { goldEarned = 999999 } },
	}
	local productionNames = {
		MightyAngler_Profile_v2 = true,
		MightyAngler_TopStr_v2 = true,
		MightyAngler_TopGold_v2 = true,
	}
	local function open(kind, name)
		table.insert(opens, { kind = kind, name = name }) -- spy at actual service boundary
		print(string.format("OPEN studio=%s placeId=%d %s %s", tostring(studio), placeId, kind, name))
		if name == failedStore then error("simulated API unavailable") end
		if not stores[name] then
			local data = { ["101"] = 50, ["102"] = 777, ["103"] = 888 }
			local store = { data = data }
			function store:UpdateAsync(key, transform)
				table.insert(writes, { name = name, key = key })
				local nextValue = transform(data[key])
				if nextValue ~= nil then data[key] = nextValue end
				return nextValue
			end
			stores[name] = store
		end
		return stores[name]
	end
	local dataStoreService = {}
	function dataStoreService:GetDataStore(name) return open("DataStore", name) end
	function dataStoreService:GetOrderedDataStore(name) return open("OrderedDataStore", name) end
	local shared = node("Shared")
	local services = {
		DataStoreService = dataStoreService,
		Players = { GetPlayers = function() return { writable, readOnly, missing } end },
		RunService = { IsStudio = function() return studio end },
		ReplicatedStorage = { WaitForChild = function() return shared end },
		Workspace = { FindFirstChild = function() return nil end },
		HttpService = {},
	}
	local dependencies = {
		DataService = {
			Get = function(player) return profiles[player] end,
			CanWritePersistent = function(player) return player == writable end,
		},
		Net = { ClientToServer = { RequestInitialState = "init" }, ServerToClient = {},
			OnServerEvent = function() end, FireAllClients = function() end },
		BuffAggregator = { RegisterProvider = function() end },
		EventsConfig = { CYCLE_INTERVAL_SEC = 1800 },
		Islands = {}, ShopAndItemsService = {}, PartFactory = {},
	}
	local env = setmetatable({
		game = { PlaceId = placeId, GetService = function(_, name)
			assert(services[name], "Unexpected service: " .. name)
			return services[name]
		end },
		Color3 = { fromRGB = function() return {} end },
		task = {
			spawn = function(fn)
				local thread = coroutine.create(fn)
				table.insert(threads, thread)
				equal(coroutine.resume(thread), true, "initial leaderboard refresh")
			end,
			wait = function() coroutine.yield() end,
		},
	}, { __index = getfenv() })
	function env.require(module)
		local name = module.Name
		if dependencies[name] ~= nil then return dependencies[name] end
		assert(sources[name], "Unexpected module: " .. name)
		local run = assert(loadstring(sources[name], "@" .. name))
		local moduleEnv = setmetatable({ script = node(name, node("Services", node("Server"))) }, { __index = env })
		setfenv(run, moduleEnv)
		local result = run()
		dependencies[name] = result
		return result
	end
	local helper = env.require(node("DataStoreLockHelper"))
	local firstStore = helper.TryGetStore()
	equal(helper.TryGetStore(), firstStore, "profile cache")
	local liveOps = env.require(node("LiveOpsService"))
	liveOps.Init() -- uses real initial refresh; world/UI creation intentionally absent
	local function refresh()
		for _ = 1, 4 do -- actual loop refreshes each 20 seconds
			local ok, err = coroutine.resume(threads[1])
			assert(ok, tostring(err))
		end
	end
	local function productionRequests()
		local count = 0
		for _, call in ipairs(opens) do
			if productionNames[call.name] then count += 1 end
		end
		return count
	end
	return { opens = opens, writes = writes, stores = stores, profiles = profiles,
		writable = writable, readOnly = readOnly, helper = helper, refresh = refresh,
		productionRequests = productionRequests }
end

local function verifyRouting(sources, studio, placeId, suffix)
	local f = fixture(sources, studio, placeId)
	f.refresh()
	if placeId == 0 then
		equal(#f.opens, 0, "unpublished place must never open any store")
		equal(#f.writes, 0, "unpublished place must never persist")
		equal(f.helper.IsStudioOfflineFallback(), true, "RAM fallback")
		equal(f.helper.GetActiveStoreLabel(), "RAM-Only Fallback", "RAM label")
	else
		local expected = {
			{ "DataStore", "MightyAngler_Profile_v2" .. suffix },
			{ "OrderedDataStore", "MightyAngler_TopStr_v2" .. suffix },
			{ "OrderedDataStore", "MightyAngler_TopGold_v2" .. suffix },
			{ "OrderedDataStore", "MightyAngler_TopStr_v2" .. suffix },
			{ "OrderedDataStore", "MightyAngler_TopGold_v2" .. suffix },
		}
		equal(#f.opens, #expected, "all actual open calls")
		for i, call in ipairs(expected) do
			equal(f.opens[i].kind, call[1], "store kind " .. i)
			equal(f.opens[i].name, call[2], "store name " .. i)
		end
		equal(f.helper.GetActiveStoreLabel(), "MightyAngler_Profile_v2" .. suffix, "profile label matches open")
		equal(#f.writes, 4, "initial and periodic Strength/Gold writes")
	end
	if studio then equal(f.productionRequests(), 0, "Studio production store requests") end
	print(string.format("PASS routing studio=%s placeId=%d productionRequests=%d (all stores simulated)",
		tostring(studio), placeId, f.productionRequests()))
	return f
end

local function verifyRecords(f, suffix)
	local str = f.stores["MightyAngler_TopStr_v2" .. suffix].data
	local gold = f.stores["MightyAngler_TopGold_v2" .. suffix].data
	equal(str["101"], 125, "Strength rounded down")
	equal(gold["101"], 250, "Gold rounded down")
	equal(str["102"], 777, "read-only Strength unchanged")
	equal(gold["102"], 777, "read-only Gold unchanged")
	equal(str["103"], 888, "unloaded Strength unchanged")
	equal(gold["103"], 888, "unloaded Gold unchanged")
	local p = f.profiles[f.writable]
	p.strength, p.stats.goldEarned = 5, 10
	f.refresh()
	equal(str["101"], 125, "lower Strength keeps record")
	equal(gold["101"], 250, "lower Gold keeps record")
	p.strength, p.stats.goldEarned = 400, 800
	f.refresh()
	equal(str["101"], 400, "higher Strength raises record")
	equal(gold["101"], 800, "higher Gold raises record")
	local writeCount = #f.writes
	p.strength, p.stats.goldEarned = 0, 0
	f.refresh()
	equal(#f.writes, writeCount, "zero scores skipped")
	f.profiles[f.writable] = nil
	f.profiles[f.readOnly] = nil
	f.refresh()
	equal(#f.writes, writeCount, "no writable profiles skipped")
	if suffix == "_StudioDev" then
		equal(f.productionRequests(), 0, "all Studio record tests avoid production names")
	end
	print("PASS records/write permission for suffix=" .. suffix)
end

return function(sources)
	verifyRouting(sources, true, 0, "")
	verifyRecords(verifyRouting(sources, true, 123456, "_StudioDev"), "_StudioDev")
	verifyRecords(verifyRouting(sources, false, 123456, ""), "")
	for _, name in ipairs({ "MightyAngler_Profile_v2_StudioDev", "MightyAngler_TopStr_v2_StudioDev", "MightyAngler_TopGold_v2_StudioDev" }) do
		local f = fixture(sources, true, 123456, name)
		f.refresh()
		local attempted = false
		for _, call in ipairs(f.opens) do
			if call.name == name then attempted = true end
		end
		equal(attempted, true, "failed store was actually requested")
		equal(f.productionRequests(), 0, "API failure must never fall back to production")
		equal(f.helper.GetActiveStoreLabel(), "MightyAngler_Profile_v2_StudioDev", "failure label")
		print("PASS isolated API failure: " .. name)
	end
	print("PASS Studio isolation suite; no Roblox API or network used by tests")
end
