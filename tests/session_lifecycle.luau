local Fixture = require("./session_fixture")
local function equal(actual, expected, label)
	assert(actual == expected, string.format("%s: expected %s, got %s", label, tostring(expected), tostring(actual)))
end

return function(sources)
	local passed, failed = 0, 0
	local function test(name, run)
		local ok, err = pcall(run)
		if ok then passed += 1; print("PASS lifecycle " .. name)
		else failed += 1; print("FAIL lifecycle " .. name .. ": " .. tostring(err)) end
	end

	test("claim timestamp rather than delayed acknowledgement controls lease", function()
		local b = Fixture.backend()
		local a = Fixture.server(sources, b, "A")
		a.afterUpdate = function(kind) if kind == "claim" then coroutine.yield("claim ack held") end end
		local p, load = a.add(101)
		local writtenAt = b.document.lockTimestamp
		b.now = writtenAt + 100
		a.resume(load)
		b.now = writtenAt + 121
		equal(a.data.CanWritePersistent(p), false, "claim acknowledgement cannot extend lease")
	end)

	test("close locks before snapshot and both entry points await one result", function()
		local b = Fixture.backend()
		local a = Fixture.server(sources, b, "A")
		local p = a.add(101)
		local token = a.data.Get(p).activeSessionId
		a.data.Get(p).gold = 404
		local held, locked
		a.beforeUpdate = function(kind)
			if kind == "release" then
				locked = a.data.IsTransactionLocked(p, false)
				held = coroutine.running(); coroutine.yield("final write held")
			end
		end
		local removal = a.remove(p)
		local shutdown = a.spawn(a.bindToClose)
		equal(locked, true, "transactions lock before final write")
		equal(coroutine.status(shutdown), "suspended", "shutdown waits for departed player")
		a.resume(held)
		a.finish(removal); a.finish(shutdown)
		equal(a.results[removal], "Saved", "removal confirms final result")
		equal(type(a.results[shutdown]), "table", "shutdown reports per-session outcomes")
		equal(a.results[shutdown][token], a.results[removal], "both paths receive the same confirmed result")
		equal(b.document.gold, 404, "latest balance persisted")
		equal(b.document.saveSeq, 2, "one final snapshot")
		equal(a.loadModule("ProfilePersistenceService").Count(), 0, "closed session references removed")
	end)

	test("lost final acknowledgement is reconciled without rewriting snapshot", function()
		local b = Fixture.backend()
		local a = Fixture.server(sources, b, "A")
		local p = a.add(101)
		a.data.Get(p).gold = 731
		a.afterUpdate = function(kind) if kind == "release" then error("final acknowledgement lost") end end
		local reads = 0
		a.beforeRead = function()
			reads += 1
			if reads == 1 then error("first confirmation read also unavailable") end
		end
		local removal = a.remove(p)
		a.finish(removal)
		equal(a.results[removal], "Saved", "read-back confirms final snapshot")
		equal(b.document.gold, 731, "lost response did not lose balance")
		equal(b.document.saveSeq, 2, "only one operation applied")
		equal(b.commits, 2, "claim and final write only")
		assert(#b.reads > 0, "ambiguous write must be checked with uncached read")
	end)

	test("release receipt confirms A without touching B after immediate server transfer", function()
		local b = Fixture.backend()
		local a, other = Fixture.server(sources, b, "A"), Fixture.server(sources, b, "B")
		local p = a.add(101)
		a.data.Get(p).gold = 72
		local pB
		a.afterUpdate = function(kind)
			if kind == "release" then
				pB = other.add(101)
				other.data.Get(pB).gold = 999
				equal(other.data.SaveProfile(pB), "Saved", "B saves before A receives final result")
				error("A final acknowledgement lost after B joined")
			end
		end
		local removal = a.remove(p)
		a.finish(removal)
		equal(a.results[removal], "Saved", "receipt confirms A final write")
		equal(b.document.gold, 999, "A reconciliation never overwrites B")
		equal(b.document.activeSessionId, other.data.Get(pB).activeSessionId, "B owner preserved")
		equal(other.data.CanWritePersistent(pB), true, "B permission preserved")
	end)

	test("failed close stops at deadline and reports same unconfirmed result", function()
		local b = Fixture.backend()
		local a = Fixture.server(sources, b, "A")
		local p = a.add(101)
		local token = a.data.Get(p).activeSessionId
		a.data.Get(p).gold = 900
		a.beforeUpdate = function(kind) if kind == "release" then error("store unavailable") end end
		a.beforeRead = function() error("verification unavailable") end
		local start = b.now
		local removal = a.remove(p)
		local duplicate = a.spawn(function() return a.data.CloseProfile(p) end)
		local shutdown = a.spawn(a.bindToClose)
		a.finish(removal); a.finish(duplicate); a.finish(shutdown)
		equal(a.results[removal], "Unconfirmed", "removal reports unconfirmed")
		equal(a.results[duplicate], "Unconfirmed", "duplicate waits for same outcome")
		equal(type(a.results[shutdown]), "table", "shutdown records failed sessions")
		equal(a.results[shutdown][token], a.results[removal], "both paths report same deadline failure")
		assert(b.now - start <= 26, "close must respect bounded deadline")
		equal(b.document.gold, 0, "failed write never pretends balance saved")
		assert(#a.warnings > 0, "unconfirmed final save must be recorded")
		equal(a.loadModule("ProfilePersistenceService").Count(), 0, "failed close references removed")
	end)

	test("pending operation keeps nonce and new progress is saved after reconciliation", function()
		local b = Fixture.backend()
		local a = Fixture.server(sources, b, "A")
		local p = a.add(101)
		local nonce, attempts = nil, 0
		a.beforeUpdate = function(kind, proposed)
			if kind == "save" then
				attempts += 1
				if attempts == 1 then nonce = proposed.lastWriteNonce; error("temporary write failure") end
				if attempts == 2 then equal(proposed.lastWriteNonce, nonce, "same operation retried") end
			end
		end
		a.data.Get(p).gold = 10; a.data.MarkDirty(p)
		equal(a.data.SaveProfile(p), "TransientError", "first attempt unresolved")
		a.data.Get(p).gold = 20; a.data.MarkDirty(p)
		equal(a.data.SaveProfile(p), "Saved", "pending then latest progress saved")
		equal(b.document.gold, 20, "reconciliation never drops newer progress")
		equal(b.document.saveSeq, 3, "two distinct snapshots, each applied once")
	end)

	test("stale queued save cannot write over a new owner", function()
		local b = Fixture.backend()
		local a, other = Fixture.server(sources, b, "A"), Fixture.server(sources, b, "B")
		local p = a.add(101)
		a.data.Get(p).gold = 88
		local held
		a.beforeUpdate = function(kind) if kind == "save" then held = coroutine.running(); coroutine.yield("request held") end end
		local result
		local save = a.spawn(function() result = a.data.SaveProfile(p) end)
		b.now += 121
		local pB = other.add(101)
		local owner = b.document.activeSessionId
		a.resume(held); a.finish(save)
		equal(result, "LostLock", "new owner detected")
		equal(b.document.activeSessionId, owner, "new owner unchanged")
		equal(other.data.CanWritePersistent(pB), true, "new owner writable")
		equal(a.data.CanWritePersistent(p), false, "stale owner blocked")
	end)

	test("idle profiles renew on different phases every sixty seconds", function()
		local b = Fixture.backend()
		local a = Fixture.server(sources, b, "A")
		local players = { (a.add(101)), (a.add(102)), (a.add(103)) }
		local first = {}
		a.beforeUpdate = function(kind, _, key)
			if kind == "save" and not first[key] then first[key] = b.now end
		end
		a.advance(125)
		for _, p in ipairs(players) do equal(a.data.CanWritePersistent(p), true, "idle profile keeps confirmed lease") end
		assert(first.Player_101 and first.Player_102 and first.Player_103, "all idle profiles renew")
		assert(first.Player_101 ~= first.Player_102 and first.Player_102 ~= first.Player_103, "renewals must be spread")
		assert(b.document.saveSeq >= 3 and b.documents.Player_102.saveSeq >= 3, "standing still still renews")
	end)

	test("queued save rechecks permission after previous writer loses ownership", function()
		local b = Fixture.backend()
		local a, other = Fixture.server(sources, b, "A"), Fixture.server(sources, b, "B")
		local p = a.add(101)
		local held
		a.beforeUpdate = function(kind) if kind == "save" then held = coroutine.running(); coroutine.yield("save held") end end
		local first = a.spawn(function() return a.data.SaveProfile(p) end)
		local queued = a.spawn(function() return a.data.SaveProfile(p) end)
		b.now += 121
		other.add(101)
		a.resume(held); a.finish(first)
		local calls = #b.calls
		a.finish(queued)
		equal(a.results[queued], "LostLock", "queued request sees lost permission")
		equal(#b.calls, calls, "queued read-only request must not call store again")
	end)

	test("public release-save uses shared close and removes write permission", function()
		local b = Fixture.backend()
		local a = Fixture.server(sources, b, "A")
		local p = a.add(101)
		equal(a.data.SaveProfile(p, true), "Saved", "release through public API confirms close")
		equal(a.data.CanWritePersistent(p), false, "released profile cannot continue transactions")
		equal(a.loadModule("ProfilePersistenceService").Count(), 0, "public release removes session")
	end)

	test("parallel shutdown bounds a hung profile while saving another", function()
		local b = Fixture.backend()
		local a = Fixture.server(sources, b, "A")
		local p, other = a.add(101), a.add(102)
		a.data.Get(p).gold = 111; a.data.Get(other).gold = 222
		local held
		a.beforeUpdate = function(kind, _, key)
			if kind == "release" and key == "Player_101" then held = coroutine.running(); coroutine.yield("hung API") end
		end
		local shutdown = a.spawn(a.bindToClose)
		equal(b.documents.Player_102.gold, 222, "other profile saves in parallel")
		equal(a.data.CanWritePersistent(other), false, "shutdown locks all transactions")
		a.finish(shutdown)
		equal(a.loadModule("ProfilePersistenceService").Count(), 0, "deadline releases session registry")
		equal(a.data.Get(p), nil, "hung session not retained")
		a.resume(held)
		equal(a.data.Get(p), nil, "late API return cannot reinstall session")
	end)

	test("repeated leave and rejoin returns registry to baseline", function()
		local b = Fixture.backend()
		local a = Fixture.server(sources, b, "A")
		for _ = 1, 30 do
			local p = a.add(101)
			a.finish(a.remove(p))
			equal(a.loadModule("ProfilePersistenceService").Count(), 0, "no closing Player references remain")
		end
	end)

	print(string.format("LIFECYCLE_SUITE passed=%d failed=%d", passed, failed))
	assert(failed == 0, "session lifecycle suite failed")
end
