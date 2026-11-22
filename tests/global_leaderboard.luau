-- Runs the real GlobalLeaderboard module in the Luau VM; only DataStoreService/Players/RunService are faked.
-- Breaks caught: boards that only list the current server, writes on every refresh, writes from sessions
-- without a valid lock, one failing player/board blocking the others, records being lowered.
local function equal(actual, expected, label)
	assert(actual == expected, string.format("%s: expected %s, got %s", label, tostring(expected), tostring(actual)))
end

local function fixture(sources, options)
	options = options or {}
	local f = { stores = {}, opens = {}, warnings = {}, nameLookups = {}, online = {}, names = options.names or {},
		placeId = options.placeId or 123456, studio = options.studio == true, failOpen = {}, failNames = false }
	local function open(name)
		table.insert(f.opens, name)
		if f.failOpen[name] then error("simulated open failure") end
		if not f.stores[name] then
			local store = { data = {}, writes = {}, reads = 0, failRead = false, failWriteFor = {} }
			function store:UpdateAsync(key, transform)
				table.insert(self.writes, key)
				if self.failWriteFor[key] then error("simulated write failure") end
				local nextValue = transform(self.data[key])
				if nextValue ~= nil then self.data[key] = nextValue end
				return nextValue
			end
			function store:GetSortedAsync(ascending, pageSize)
				self.reads += 1
				if self.failRead then error("simulated read failure") end
				equal(ascending, false, "top must be read in descending order")
				local rows = {}
				for key, value in pairs(self.data) do table.insert(rows, { key = key, value = value }) end
				table.sort(rows, function(a, b) return a.value > b.value end)
				for index = #rows, pageSize + 1, -1 do rows[index] = nil end
				return { GetCurrentPage = function() return rows end }
			end
			f.stores[name] = store
		end
		return f.stores[name]
	end
	local services = {
		DataStoreService = { GetOrderedDataStore = function(_, name) return open(name) end },
		RunService = { IsStudio = function() return f.studio end },
		Players = {
			GetPlayerByUserId = function(_, userId) return f.online[userId] end,
			GetNameFromUserIdAsync = function(_, userId)
				table.insert(f.nameLookups, userId)
				if f.failNames or not f.names[userId] then error("simulated name failure") end
				return f.names[userId]
			end,
		},
	}
	local env = setmetatable({
		game = { PlaceId = f.placeId, GetService = function(_, name) return assert(services[name], "Unexpected service: " .. name) end },
		warn = function(...) table.insert(f.warnings, table.concat({ ... }, " ")) end,
	}, { __index = getfenv() })
	local run = assert(loadstring(sources.GlobalLeaderboard, "@GlobalLeaderboard"))
	setfenv(run, env)
	f.module = run()
	function f.player(userId, name)
		local player = { UserId = userId, DisplayName = name }
		f.online[userId] = player
		return player
	end
	function f.store(name) return open(name) end
	return f
end

local function live(player, score, canWrite)
	return { player = player, score = score, canWrite = canWrite ~= false }
end

local function describe(entries)
	local parts = {}
	for _, entry in ipairs(entries) do table.insert(parts, entry.name .. "=" .. tostring(entry.score)) end
	return table.concat(parts, ",")
end

local sources_placeholder
local tests = {}
local function test(name, fn) table.insert(tests, { name = name, fn = fn }) end

test("top lists players from other servers, best first, capped at 8, and replaces a stale own row", function()
	local f = fixture(sources_placeholder, { names = { [201] = "Alice", [202] = "Bob" } })
	local store = f.store("Top")
	table.remove(f.opens)
	for id = 301, 309 do store.data[tostring(id)] = id end -- nine low rows from other servers
	store.data["201"], store.data["202"], store.data["101"] = 9000, 8000, 500
	local me = f.player(101, "Me")
	local board = f.module.New("Top")
	local entries = f.module.Update(board, { live(me, 8500.7) })
	equal(#entries, 8, "capped at 8 rows")
	equal(entries[1].name .. entries[2].name .. entries[3].name, "AliceMeBob", "global order with my live score merged in")
	equal(entries[2].score, 8500.7, "my live score replaces my stale stored row (no duplicate)")
	equal(entries[4].name, "Player 309", "unknown name falls back to user id")
	equal(store.data["101"], 8500, "my record was raised, rounded down")
	equal(#f.opens, 1, "store opened once")
end)

test("writes only when the score rises, at most once per 3 refreshes, and never lowers a record", function()
	local f = fixture(sources_placeholder)
	local store = f.store("Top")
	local me = f.player(101, "Me")
	local board = f.module.New("Top")
	for _ = 1, 30 do f.module.Update(board, { live(me, 100) }) end -- 10 minutes standing still
	equal(#store.writes, 1, "unchanged score is written once, not 30 times")
	for step = 1, 9 do f.module.Update(board, { live(me, 100 + step) }) end -- rising every refresh
	equal(#store.writes, 4, "rising score: one write per 3 refreshes")
	equal(store.data["101"], 107, "latest throttled value stored")
	for _ = 1, 6 do f.module.Update(board, { live(me, 5) }) end
	equal(#store.writes, 4, "lower score is not written")
	equal(store.data["101"], 107, "record never lowered")
	for _ = 1, 6 do f.module.Update(board, { live(me, 0) }) end
	equal(#store.writes, 4, "zero score is not written")
	local reborn = f.module.New("Top") -- new server: cache empty, stored record is higher
	f.module.Update(reborn, { live(me, 50) })
	equal(store.data["101"], 107, "a new server cannot lower the stored record")
end)

test("top is read once per 5 refreshes, not on every refresh", function()
	local f = fixture(sources_placeholder)
	local store = f.store("Top")
	local board = f.module.New("Top")
	for _ = 1, 30 do f.module.Update(board, {}) end
	equal(store.reads, 6, "30 refreshes -> 6 reads")
	equal(#store.writes, 0, "no players -> no writes")
end)

test("session without a valid lock is shown but never written", function()
	local f = fixture(sources_placeholder)
	local store = f.store("Top")
	store.data["102"] = 777
	local locked = f.player(102, "Locked")
	local board = f.module.New("Top")
	local entries
	for _ = 1, 10 do entries = f.module.Update(board, { live(locked, 999999, false) }) end
	equal(#store.writes, 0, "no write without lock")
	equal(store.data["102"], 777, "stored record untouched")
	equal(describe(entries), "Locked=999999", "still listed locally")
end)

test("one player's failed write does not block other players or the read, and is retried", function()
	local f = fixture(sources_placeholder, { names = { [201] = "Alice" } })
	local store = f.store("Top")
	store.data["201"] = 9000
	store.failWriteFor["101"] = true
	local a, b = f.player(101, "A"), f.player(102, "B")
	local board = f.module.New("Top")
	local entries = f.module.Update(board, { live(a, 300), live(b, 200) })
	equal(store.data["102"], 200, "second player written despite first player's error")
	equal(store.data["101"], nil, "failed write stored nothing")
	equal(describe(entries), "Alice=9000,A=300,B=200", "board still shows global top plus live scores")
	equal(#f.warnings, 1, "failure logged once")
	store.failWriteFor["101"] = nil
	for _ = 1, 3 do f.module.Update(board, { live(a, 300), live(b, 200) }) end
	equal(store.data["101"], 300, "failed write retried after the throttle window")
	equal(#store.writes, 3, "B was not rewritten")
end)

test("failed read keeps the last good top and retries on the next refresh", function()
	local f = fixture(sources_placeholder, { names = { [201] = "Alice", [202] = "Bob" } })
	local store = f.store("Top")
	store.data["201"] = 9000
	local board = f.module.New("Top")
	equal(describe(f.module.Update(board, {})), "Alice=9000", "first read")
	for _ = 1, 4 do f.module.Update(board, {}) end
	store.failRead, store.data["202"] = true, 9500
	equal(describe(f.module.Update(board, {})), "Alice=9000", "read error keeps previous list")
	equal(describe(f.module.Update(board, {})), "Alice=9000", "still failing, still previous list")
	equal(store.reads, 3, "failed read retried on the very next refresh")
	store.failRead = false
	equal(describe(f.module.Update(board, {})), "Bob=9500,Alice=9000", "recovers without restart")
	f.module.Update(board, {})
	equal(store.reads, 4, "back to the slow read pace after recovery")
end)

test("names: online player uses display name, offline names are looked up once, failures fall back", function()
	local f = fixture(sources_placeholder, { names = { [201] = "Alice" } })
	local store = f.store("Top")
	store.data["201"], store.data["202"], store.data["101"] = 300, 200, 100
	f.player(101, "OnlineDisplay")
	local board = f.module.New("Top")
	local entries
	for _ = 1, 11 do entries = f.module.Update(board, {}) end -- 3 reads
	equal(describe(entries), "Alice=300,Player 202=200,OnlineDisplay=100", "names resolved")
	local lookups = {}
	for _, id in ipairs(f.nameLookups) do lookups[id] = (lookups[id] or 0) + 1 end
	equal(lookups[201], 1, "successful lookup cached")
	equal(lookups[101], nil, "online player never looked up")
	equal(lookups[202], 3, "failed lookup is retried on later reads, not cached as a failure")
end)

test("two boards are independent: one store failing to open does not blank the other, then recovers", function()
	local f = fixture(sources_placeholder)
	f.failOpen["Str_StudioDev"] = true
	f.studio = true
	local me = f.player(101, "Me")
	local str, gold = f.module.New("Str"), f.module.New("Gold")
	equal(describe(f.module.Update(str, { live(me, 10) })), "Me=10", "failed board still lists the server's players")
	f.module.Update(gold, { live(me, 20) })
	equal(f.stores["Gold_StudioDev"].data["101"], 20, "other board written")
	equal(f.stores["Gold"], nil, "Studio never opens the live store")
	f.failOpen["Str_StudioDev"] = nil
	f.module.Update(str, { live(me, 10) })
	equal(f.stores["Str_StudioDev"].data["101"], 10, "board recovers when the store opens")
end)

test("unpublished place never opens a store and still lists the server's players", function()
	local f = fixture(sources_placeholder, { placeId = 0 })
	local a, b = f.player(101, "A"), f.player(102, "B")
	local board = f.module.New("Top")
	local entries = f.module.Update(board, { live(a, 5), live(b, 9) })
	equal(#f.opens, 0, "no store opened")
	equal(describe(entries), "B=9,A=5", "local list sorted")
end)

return function(sources)
	sources_placeholder = sources
	local passed, failed = 0, 0
	for _, item in ipairs(tests) do
		local ok, err = pcall(item.fn)
		print(string.format("%s leaderboard %s%s", if ok then "PASS" else "FAIL", item.name, if ok then "" else ": " .. tostring(err)))
		if ok then passed += 1 else failed += 1 end
	end
	print(string.format("LEADERBOARD_SUITE passed=%d failed=%d; real GlobalLeaderboard, simulated OrderedDataStore only", passed, failed))
	assert(failed == 0, "global_leaderboard suite failed")
end
