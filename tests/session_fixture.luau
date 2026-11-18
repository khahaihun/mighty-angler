-- Deterministic Roblox boundaries; production DataService/LockHelper/Migrator stay real.
local Fixture = {}

local function copy(value)
	if type(value) ~= "table" then return value end
	local result = {}
	for key, item in pairs(value) do result[key] = copy(item) end
	return result
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

function Fixture.backend()
	return { now = 10000, document = nil, version = 0, calls = {}, commits = 0 }
end

function Fixture.server(sources, backend, job, placeId)
	local f = { backend = backend, warnings = {}, messages = {}, guidCount = 0, opens = 0 }
	local delays, cache, active = {}, {}, {}
	function f.resume(thread)
		local ok, result = coroutine.resume(thread)
		assert(ok, tostring(result))
		delays[thread] = result
		return result
	end
	local function spawn(fn, ...)
		local args = table.pack(...)
		local thread = coroutine.create(function() fn(table.unpack(args, 1, args.n)) end)
		f.resume(thread)
		return thread
	end
	function f.finish(thread, limit)
		for _ = 1, limit or 30 do
			if coroutine.status(thread) == "dead" then return end
			local delay = delays[thread]
			assert(type(delay) == "number", "unhandled pause: " .. tostring(delay))
			backend.now += delay
			f.resume(thread)
		end
		error("thread did not finish within bounded steps")
	end
	local function signal()
		local callback
		return { Connect = function(_, fn) callback = fn end,
			Fire = function(_, ...) assert(callback); return spawn(callback, ...) end }
	end
	local players = { PlayerAdded = signal(), PlayerRemoving = signal() }
	function players:GetPlayers()
		local result = {}
		for player in pairs(active) do table.insert(result, player) end
		return result
	end
	local store = {}
	f.store = store
	function store:UpdateAsync(key, transform)
		table.insert(backend.calls, { job = job, key = key })
		for _ = 1, 10 do -- optimistic retry if another server commits while suspended
			local version = backend.version
			local proposed = transform(copy(backend.document))
			local kind = "cancel"
			if proposed then
				kind = if proposed.activeSessionId == nil then "release"
					elseif backend.document and proposed.saveSeq > backend.document.saveSeq then "save"
					else "claim"
			end
			if f.beforeUpdate then f.beforeUpdate(kind, proposed) end
			if version == backend.version then
				if proposed ~= nil then
					backend.document = copy(proposed)
					backend.version += 1
					backend.commits += 1
				end
				local response = copy(proposed)
				if f.afterUpdate then f.afterUpdate(kind, response) end
				print(string.format("TRACE t=%.2f server=%s action=%s seq=%s owner=%s", backend.now, job,
					kind, tostring(backend.document and backend.document.saveSeq),
					tostring(backend.document and backend.document.activeSessionId)))
				return response
			end
		end
		error("too many simulated optimistic conflicts")
	end
	local dataStoreService = { GetDataStore = function(_, name)
		f.opens += 1
		assert(name == "MightyAngler_Profile_v2_StudioDev", "test must only open Studio test store")
		return store
	end }
	local services = {
		Players = players, DataStoreService = dataStoreService,
		RunService = { IsStudio = function()
			if f.failStudioCheck then error("injected exception before store acquisition") end
			return true
		end },
		ReplicatedStorage = { WaitForChild = function() return node("Shared") end },
		HttpService = { GenerateGUID = function()
			f.guidCount += 1
			if f.guidCount == f.failGuidAt then error("injected nonce generation exception") end
			return string.format("%s%010d", job, f.guidCount)
		end },
	}
	cache.Net = { ClientToServer = { RequestInitialState = "init" },
		ServerToClient = { Toast = "toast", StateSnapshot = "snapshot" },
		OnServerEvent = function() end,
		FireClient = function(player, event, payload)
			table.insert(f.messages, { player = player, event = event, payload = payload })
		end }
	cache.Islands = { List = {} } -- default profiles have no fish; world config irrelevant here
	local testOs = table.clone(os)
	testOs.time = function() return math.floor(backend.now) end
	testOs.clock = function() return backend.now end
	local env = setmetatable({ os = testOs,
		game = { PlaceId = placeId or 123456, JobId = job,
			GetService = function(_, name) assert(services[name], name); return services[name] end,
			BindToClose = function(_, fn) f.bindToClose = fn end },
		Color3 = { fromRGB = function() return {} end },
		Instance = { new = function() return {} end }, -- leaderstats only
		warn = function(...) table.insert(f.warnings, table.concat({ ... }, " ")) end,
		task = { spawn = spawn, wait = function(delay) return coroutine.yield(delay) end },
	}, { __index = getfenv() })
	function env.require(module)
		local name = module.Name
		if cache[name] ~= nil then return cache[name] end
		assert(sources[name], "unexpected module " .. name)
		local run = assert(loadstring(sources[name], "@" .. name))
		setfenv(run, setmetatable({ script = node(name, node("Services", node("Server"))) }, { __index = env }))
		cache[name] = run()
		return cache[name]
	end
	f.data = env.require(node("DataService"))
	f.helper = env.require(node("DataStoreLockHelper"))
	f.config = env.require(node("GameConfig"))
	f.data.Init() -- actual signals and load/save paths; periodic thread remains suspended
	function f.add(userId)
		local player = { UserId = userId, DisplayName = job }
		function player:IsDescendantOf(service) return service == players and active[self] == true end
		active[player] = true
		return player, players.PlayerAdded:Fire(player)
	end
	function f.remove(player)
		active[player] = nil
		return players.PlayerRemoving:Fire(player)
	end
	f.spawn = spawn
	return f
end

return Fixture
