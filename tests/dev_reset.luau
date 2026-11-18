local Fixture = require("./session_fixture")
local Client = require("./client_fixture")
local function equal(a, b, label) assert(a == b, label .. ": expected " .. tostring(b) .. ", got " .. tostring(a)) end
local function vector(x, y, z)
	return setmetatable({ X = x, Y = y, Z = z, Magnitude = math.sqrt(x*x+y*y+z*z) }, {
		__add = function(a,b) return vector(a.X+b.X,a.Y+b.Y,a.Z+b.Z) end })
end
local function options()
	local function ignore() end
	return { useIslandConfig = true, globals = { Vector3 = { new = vector } }, dependencies = {
		BuffAggregator = {}, PerkService = {}, FishingRoller = {},
		FishingService = { CancelSession = ignore }, IslandService = { TeleportCharacterToIsland = ignore },
		PetsService = { SyncVisualsAndClient = ignore }, RodVisuals = { EquipRodOnCharacter = ignore }, PetAndFishVisuals = {},
	} }
end
local function setup(sources, place)
	local b = Fixture.backend(); local f = Fixture.server(sources, b, "A", place, options())
	f.loadModule("DevTestService").Init()
	local p = f.add(101)
	return b, f, p
end
local function feedback(f)
	for i = #f.messages, 1, -1 do
		local payload = f.messages[i].payload
		if type(payload) == "table" and payload.devReset then return payload end
	end
	error("missing separate RAM/persistent reset feedback")
end
return function(sources)
	local passed, failed = 0, 0
	local function test(name, run)
		local ok, err = pcall(run)
		if ok then passed += 1; print("PASS reset " .. name)
		else failed += 1; print("FAIL reset " .. name .. ": " .. tostring(err)) end
	end
	test("pending autosave completes before object replacement", function()
		local b, f, p = setup(sources)
		local original = f.data.Get(p); original.gold = 505
		local held
		f.afterUpdate = function(kind) if kind == "save" and not held then held = coroutine.running(); coroutine.yield("autosave ack") end end
		local save = f.spawn(function() return f.data.SaveProfile(p) end)
		local reset = f.fireRemote("DevAction", p, "ResetSave")
		equal(f.data.Get(p), original, "object cannot change before pending acknowledgement")
		equal(f.data.IsTransactionLocked(p, false), true, "reset locks transactions while waiting")
		f.resume(held); f.finish(save); f.finish(reset)
		equal(b.document.gold, 0, "reset saved")
		equal(b.document.saveSeq, 3, "reset follows autosave sequence")
		equal(f.data.CanWritePersistent(p), true, "reset keeps confirmed ownership")
		local info = feedback(f).devReset
		equal(info.ramApplied, true, "RAM feedback")
		equal(info.persistent, "Saved", "persistent confirmation")
	end)
	test("write failure reports RAM applied without claiming durable save", function()
		local b, f, p = setup(sources)
		f.data.Get(p).gold = 505; f.data.SaveProfile(p)
		f.beforeUpdate = function(kind) if kind == "save" then error("reset write unavailable") end end
		f.finish(f.fireRemote("DevAction", p, "ResetSave"))
		equal(f.data.Get(p).gold, 0, "RAM reset applied")
		equal(b.document.gold, 505, "failed reset did not persist")
		local message = feedback(f)
		equal(message.devReset.ramApplied, true, "RAM result explicit")
		equal(message.devReset.persistent, "Unconfirmed", "durable result explicit")
		equal(message.kind, "Error", "no success toast for unconfirmed persistence")
		f.beforeUpdate = nil; f.advance(6)
		equal(b.document.gold, 0, "same pending reset eventually saves after recovery")
	end)
	test("RAM-only mode is reported without opening any store", function()
		local b, f, p = setup(sources, 0)
		f.data.Get(p).gold = 19
		f.finish(f.fireRemote("DevAction", p, "ResetSave"))
		equal(f.data.Get(p).gold, 0, "RAM reset")
		equal(feedback(f).devReset.persistent, "RAMOnly", "RAM-only feedback")
		equal(f.opens, 0, "no store opened")
		equal(#b.calls, 0, "no persistent write")
	end)
	test("unresolved prior write prevents RAM replacement", function()
		local b, f, p = setup(sources)
		local original = f.data.Get(p); original.gold = 100
		f.beforeUpdate = function() error("write unavailable") end
		f.beforeRead = function() error("read unavailable") end
		equal(f.data.SaveProfile(p), "TransientError", "pending prior write")
		f.finish(f.fireRemote("DevAction", p, "ResetSave"))
		equal(f.data.Get(p), original, "unresolved operation keeps original object")
		equal(f.data.Get(p).gold, 100, "unresolved operation keeps RAM data")
		equal(feedback(f).devReset.ramApplied, false, "not applied feedback")
		equal(b.document.gold, 0, "no reset snapshot persisted")
	end)
	test("concurrent reset is rejected while first reset awaits persistence", function()
		local b, f, p = setup(sources)
		local held
		f.afterUpdate = function(kind) if kind == "save" then held = coroutine.running(); coroutine.yield("reset ack") end end
		local first = f.fireRemote("DevAction", p, "ResetSave")
		f.finish(f.fireRemote("DevAction", p, "ResetSave"))
		equal(feedback(f).devReset.ramApplied, false, "second reset not applied")
		equal(feedback(f).devReset.persistent, "Busy", "second reset reports busy")
		f.afterUpdate = nil; f.resume(held); f.finish(first)
		equal(b.document.saveSeq, 2, "only one reset write")
	end)
	test("DEV panel renders RAM and persistence as separate results", function()
		local f = Client.new(sources, true)
		f.load("DevTestPanel").Mount({})
		f.emit("Toast", { devReset = { ramApplied = true, persistent = "Unconfirmed", saveSeq = 2 } })
		local status
		for _, item in ipairs(f.instances) do if item.Name == "DevResetStatus" then status = item end end
		assert(status, "panel must have reset status")
		assert(string.find(status.Text, "RAM", 1, true) and string.find(status.Text, "Unconfirmed", 1, true), "panel shows both outcomes")
	end)
	test("closing while reset waits never reinstalls or replaces departed profile", function()
		local b, f, p = setup(sources)
		f.data.Get(p).gold = 505
		local held
		f.afterUpdate = function(kind) if kind == "save" and not held then held = coroutine.running(); coroutine.yield("old write") end end
		local save = f.spawn(function() return f.data.SaveProfile(p) end)
		local reset = f.fireRemote("DevAction", p, "ResetSave")
		local removal = f.remove(p)
		f.afterUpdate = nil; f.resume(held); f.finish(save)
		f.finish(reset); f.finish(removal)
		equal(b.document.gold, 505, "aborted reset keeps previous business data")
		equal(f.data.Get(p), nil, "departed profile not reinstalled")
		equal(feedback(f).devReset.ramApplied, false, "aborted reset not reported applied")
	end)
	test("lost reset acknowledgement confirms same snapshot once", function()
		local b, f, p = setup(sources)
		f.afterUpdate = function(kind) if kind == "save" then error("reset acknowledgement lost") end end
		f.finish(f.fireRemote("DevAction", p, "ResetSave"))
		equal(feedback(f).devReset.persistent, "Saved", "reset confirmed by read-back")
		equal(b.document.saveSeq, 2, "one reset operation")
		equal(b.commits, 2, "claim and reset only")
	end)
	for _, moved in ipairs({ false, true }) do
		test("expired lease rejects reset without RAM change; moved=" .. tostring(moved), function()
			local b, f, p = setup(sources)
			local original = f.data.Get(p); original.gold = 505; f.data.SaveProfile(p)
			b.now += 121
			if moved then
				local other = Fixture.server(sources, b, "B")
				local pB = other.add(101)
				other.data.Get(pB).gold = 999; other.data.SaveProfile(pB)
			end
			local owner, gold, seq = b.document.activeSessionId, b.document.gold, b.document.saveSeq
			local calls = #b.calls
			f.finish(f.fireRemote("DevAction", p, "ResetSave"))
			equal(f.data.Get(p), original, "expired reset keeps RAM object")
			equal(original.gold, 505, "expired reset keeps RAM balance")
			equal(b.document.activeSessionId, owner, "expired reset preserves store owner")
			equal(b.document.gold, gold, "expired reset preserves store balance")
			equal(b.document.saveSeq, seq, "expired reset preserves sequence")
			equal(#b.calls, calls, "expired request does not attempt write")
			equal(feedback(f).devReset.ramApplied, false, "expired reset reported not applied")
		end)
		test("lease expires while reset queues; moved=" .. tostring(moved), function()
			local b, f, p = setup(sources)
			local original = f.data.Get(p); original.gold = 505
			local held
			f.afterUpdate = function(kind) if kind == "save" and not held then held = coroutine.running(); coroutine.yield("old ack") end end
			local save = f.spawn(function() return f.data.SaveProfile(p) end)
			local reset = f.fireRemote("DevAction", p, "ResetSave")
			b.now += 121
			if moved then
				local other = Fixture.server(sources, b, "B")
				local pB = other.add(101)
				other.data.Get(pB).gold = 999; other.data.SaveProfile(pB)
			end
			local owner, gold, seq = b.document.activeSessionId, b.document.gold, b.document.saveSeq
			f.afterUpdate = nil; f.resume(held); f.finish(save); f.finish(reset)
			equal(f.data.Get(p), original, "queued expired reset keeps object")
			equal(original.gold, 505, "queued expired reset keeps RAM money")
			equal(b.document.activeSessionId, owner, "queued reset preserves latest owner")
			equal(b.document.gold, gold, "queued reset preserves latest money")
			equal(b.document.saveSeq, seq, "queued reset does not add a write")
			equal(feedback(f).devReset.ramApplied, false, "queued expired reset reported not applied")
		end)
	end
	print(string.format("RESET_SUITE passed=%d failed=%d", passed, failed))
	assert(failed == 0, "DEV reset suite failed")
end
