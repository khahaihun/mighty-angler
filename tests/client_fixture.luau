-- Headless UI/property and transport boundaries; no Roblox layout/render claim.
local ClientFixture = {}
local function node(name)
	local result = { Name = name }
	setmetatable(result, { __index = function(self, key) local child = node(key); rawset(self, key, child); return child end })
	function result:WaitForChild(key) return self[key] end
	return result
end
function ClientFixture.new(sources, studio, extra)
	local f = { instances = {}, buttons = {}, handlers = {}, requests = {}, threads = {} }
	local function blank() return {} end
	local colors = setmetatable({}, { __index = blank })
	local names = setmetatable({}, { __index = function(_, key) return key end })
	local deps = {
		Net = { ServerToClient = names, ClientToServer = names,
			OnClientEvent = function(event, fn)
				f.handlers[event] = f.handlers[event] or {}; table.insert(f.handlers[event], fn)
			end,
			FireServer = function(...) table.insert(f.requests, table.pack(...)) end },
		Theme = { Colors = colors, FontTitle = "Title", FontBody = "Body",
			AddCorner = blank, AddStroke = blank, AddTextStroke = blank, AddGradient = blank,
			FitText = function(label, size) label.TextSize = size end,
			CreateButton = function(_, name, _, _, _, _, callback)
				local b = { callback = callback }; f.buttons[name] = b; return b
			end },
	}
	for name, value in pairs(extra or {}) do deps[name] = value end
	local globals = setmetatable({
		game = { GetService = function(_, name)
			if name == "Players" then return { LocalPlayer = { WaitForChild = function() return {} end } } end
            if name == "RunService" then return { IsStudio = function() return studio end } end
			return { WaitForChild = function(_, key) return node(key) end }
		end },
		Color3 = { fromRGB = blank, new = blank }, Vector2 = { new = blank }, Vector3 = { new = blank },
		UDim2 = { new = blank, fromOffset = blank, fromScale = blank }, UDim = { new = blank },
		Enum = setmetatable({}, { __index = function() return names end }),
		Instance = { new = function(class)
			local item = { ClassName = class, Text = "", Visible = true, Activated = { Connect = function(signal, cb) signal.callback = cb; return { Disconnect = blank } end }, Destroy = blank }
			table.insert(f.instances, item); return item
		end },
		task = { spawn = function(fn)
			local thread = coroutine.create(fn); table.insert(f.threads, thread)
			local ok, err = coroutine.resume(thread); assert(ok, tostring(err)); return thread
		end, wait = function() coroutine.yield() end },
	}, { __index = getfenv() })
	function globals.require(module)
		local name = module.Name
		if deps[name] ~= nil then return deps[name] end
		local run = assert(loadstring(assert(sources[name], name), "@" .. name))
		setfenv(run, setmetatable({ script = node(name) }, { __index = globals }))
		deps[name] = run(); return deps[name]
	end
	f.load = function(name) return globals.require(node(name)) end
	f.emit = function(event, payload)
		for _, handler in ipairs(assert(f.handlers[event], event)) do handler(payload) end
	end
	return f
end
return ClientFixture
