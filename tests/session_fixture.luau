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
	return { now = 10000, document = nil, version = 0, documents = {}, versions = {}, calls = {}, reads = {}, commits = 0 }
end

function Fixture.server(sources, backend, job, placeId, options)
	options = options or {}
	local f = { backend = backend, warnings = {}, messages = {}, guidCount = 0, opens = 0 }
	local delays, due, cache, active = {}, {}, {}, {}
	f.results = {}
	function f.resume(thread)
		local ok, result = coroutine.resume(thread)
		assert(ok, tostring(result))
		delays[thread] = result
		if coroutine.status(thread) == "dead" then
			due[thread] = nil
			f.results[thread] = result
		else due[thread] = if type(result) == "number" then backend.now + result else nil end
		return result
	end
	local function spawn(fn, ...)
		local args = table.pack(...)
		local thread = coroutine.create(function() return fn(table.unpack(args, 1, args.n)) end)
		f.resume(thread)
		f.lastSpawn = thread
		return thread
	end
	local function nextDue()
		local thread, earliest
		for candidate, at in pairs(due) do
			if earliest == nil or at < earliest then thread, earliest = candidate, at end
		end
		return thread, earliest
	end
	function f.advance(seconds)
		local target = backend.now + seconds
		for _ = 1, 20000 do
			local thread, at = nextDue()
			if not thread or at > target then backend.now = target; return end
			backend.now = math.max(backend.now, at)
			f.resume(thread)
		end
		error("scheduler exceeded bounded steps")
	end
	function f.finish(thread, limit)
		for _ = 1, limit or 20000 do
			if coroutine.status(thread) == "dead" then return end
			assert(type(delays[thread]) == "number", "unhandled pause: " .. tostring(delays[thread]))
			local ready, at = nextDue()
			assert(ready, "no runnable task")
			backend.now = math.max(backend.now, at)
			f.resume(ready)
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
	local function document(key) return if key == "Player_101" then backend.document else backend.documents[key] end
	local function versionOf(key) return if key == "Player_101" then backend.version else backend.versions[key] or 0 end
	function store:GetAsync(key, getOptions)
		assert(getOptions and getOptions.UseCache == false, "verification reads must bypass cache")
		table.insert(backend.reads, { job = job, key = key, at = backend.now })
		if f.beforeRead then f.beforeRead(key) end
		local result = copy(document(key))
		if f.afterRead then f.afterRead(key, result) end
		return result
	end
	function store:UpdateAsync(key, transform)
		table.insert(backend.calls, { job = job, key = key, at = backend.now })
		for _ = 1, 10 do -- optimistic retry if another server commits while suspended
			local version = versionOf(key)
			local old = document(key)
			local proposed = transform(copy(old))
			local kind = "cancel"
			if proposed then
				kind = if proposed.activeSessionId == nil then "release"
					elseif old and proposed.saveSeq > old.saveSeq then "save"
					else "claim"
			end
			if f.beforeUpdate then f.beforeUpdate(kind, proposed, key) end
			if version == versionOf(key) then
				if proposed ~= nil then
					if key == "Player_101" then backend.document = copy(proposed); backend.version += 1
					else backend.documents[key] = copy(proposed); backend.versions[key] = version + 1 end
					backend.commits += 1
				end
				local response = copy(proposed)
				if f.afterUpdate then f.afterUpdate(kind, response, key) end
				local saved = document(key)
				print(string.format("TRACE t=%.2f server=%s action=%s seq=%s owner=%s", backend.now, job,
					kind, tostring(saved and saved.saveSeq), tostring(saved and saved.activeSessionId)))
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
		LogService = { MessageOut = signal() },
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
	local handlers = {}
	local eventNames = { __index = function(_, key) return key end }
	cache.Net = { ClientToServer = setmetatable({ RequestInitialState = "init" }, eventNames),
		ServerToClient = setmetatable({ Toast = "toast", StateSnapshot = "snapshot" }, eventNames),
		OnServerEvent = function(event, fn) handlers[event] = fn end,
		FireClient = function(player, event, payload)
			table.insert(f.messages, { player = player, event = event, payload = payload })
		end }
	if not options.useIslandConfig then cache.Islands = { List = {} } end
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
	for name, dependency in pairs(options.dependencies or {}) do cache[name] = dependency end
	for name, value in pairs(options.globals or {}) do env[name] = value end
	function env.require(module)
		local name = module.Name
		if cache[name] ~= nil then return cache[name] end
		assert(sources[name], "unexpected module " .. name)
		local run = assert(loadstring(sources[name], "@" .. name))
		setfenv(run, setmetatable({ script = node(name, node("Services", node("Server"))) }, { __index = env }))
		cache[name] = run()
		return cache[name]
	end
	function f.loadModule(name) return env.require(node(name)) end
	function f.fireRemote(event, ...)
		return spawn(assert(handlers[event], "unregistered remote " .. event), ...)
	end
	f.data = f.loadModule("DataService")
	f.helper = f.loadModule("DataStoreLockHelper")
	f.config = f.loadModule("GameConfig")
	f.data.Init() -- actual signals and load/save paths; periodic thread remains suspended
	f.periodic = f.lastSpawn
	function f.add(userId)
		local player = { UserId = userId, DisplayName = job }
		function player:IsDescendantOf(service) return service == players and active[self] == true end
		function player:FindFirstChild() return nil end
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
