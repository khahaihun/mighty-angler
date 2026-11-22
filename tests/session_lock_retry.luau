-- Buoc 2: khoa ho so dang ban thi cho va tu thu lai; khong bao gio dua ho so trang cho nguoi choi.
local Fixture = require("./session_fixture")
local function equal(actual, expected, label)
	assert(actual == expected, string.format("%s: expected %s, got %s", label, tostring(expected), tostring(actual)))
end
-- Vong dau: 3 lan claim cach nhau 1.5s + toi da 2 lan cho don dep 0.5s.
local FIRST_ROUND = 4.5

local function accessEvents(f)
	local out = {}
	for _, item in ipairs(f.messages) do
		if item.event == "ProfileAccessChanged" then table.insert(out, item.payload) end
	end
	return out
end

return function(sources)
	local failures, passed = 0, 0
	local function test(name, run)
		local ok, err = pcall(run)
		if ok then passed += 1; print("PASS retry " .. name)
		else failures += 1; print("FAIL retry " .. name .. ": " .. tostring(err)) end
	end

	test("server hop: B waits for A's final save then loads the real profile without rejoin", function()
		local b = Fixture.backend()
		local a, other = Fixture.server(sources, b, "A"), Fixture.server(sources, b, "B")
		local pA = a.add(101)
		a.data.Get(pA).gold = 4321
		local loaded = 0
		other.data.OnProfileLoaded(function() loaded += 1 end)
		local pB = other.add(101)
		other.advance(FIRST_ROUND)
		equal(other.data.Get(pB), nil, "B has no profile while A still owns the save")
		equal(loaded, 0, "gameplay services are not started on a blank profile")
		equal(other.data.IsTransactionLocked(pB, false), true, "B cannot transact while waiting")
		a.finish(a.remove(pA)) -- A luu lan cuoi va nha khoa
		equal(b.document.gold, 4321, "A final save landed")
		other.advance(other.config.SESSION_LOCK_RETRY_SEC + 0.5)
		local profile = other.data.Get(pB)
		assert(profile, "B loads after A releases, without rejoining")
		equal(profile.gold, 4321, "B sees A's saved progress, not a blank account")
		equal(loaded, 1, "profile-loaded callbacks fire exactly once, with the real profile")
		equal(other.data.CanWritePersistent(pB), true, "B can save")
		profile.gold = 5000
		equal(other.data.SaveProfile(pB), "Saved", "B save")
		equal(b.document.gold, 5000, "B progress persisted")
	end)

	test("crashed owner: B takes over only after the lease expires", function()
		local b = Fixture.backend()
		local a, other = Fixture.server(sources, b, "A"), Fixture.server(sources, b, "B")
		local pA = a.add(101)
		a.data.Get(pA).gold = 77
		equal(a.data.SaveProfile(pA), "Saved", "A saved before crashing")
		local tokenA = b.document.activeSessionId
		local pB = other.add(101) -- A khong bao gio nha khoa (server chet)
		other.advance(other.config.SESSION_LOCK_EXPIRE_SEC - 5)
		equal(other.data.Get(pB), nil, "B still waiting while A's lease is alive")
		equal(b.document.activeSessionId, tokenA, "live lease is never stolen")
		other.advance(20)
		local profile = other.data.Get(pB)
		assert(profile, "B takes over once the lease has expired")
		equal(profile.gold, 77, "B loads the last saved progress")
		assert(b.document.activeSessionId ~= tokenA, "B owns the lock")
	end)

	test("store outage: paced retries, stored data untouched, recovers when the store returns", function()
		local b = Fixture.backend()
		local f = Fixture.server(sources, b, "A")
		b.document = f.config.CreateDefaultProfile()
		b.document.gold = 888
		local claims = 0
		f.beforeUpdate = function(kind)
			if kind == "claim" then claims += 1 end
			error("datastore outage")
		end
		local p = f.add(101)
		f.advance(FIRST_ROUND)
		equal(claims, 3, "first round is bounded")
		f.advance(120)
		assert(claims >= 3 + 12 and claims <= 3 + 24, "background retries run every 5-10s, got " .. claims)
		equal(f.data.Get(p), nil, "no blank profile during the whole outage")
		equal(b.document.gold, 888, "outage never changed stored data")
		f.beforeUpdate = nil
		f.advance(f.config.SESSION_LOCK_RETRY_SLOW_SEC + 1.5)
		local profile = f.data.Get(p)
		assert(profile, "profile loads when the store recovers")
		equal(profile.gold, 888, "real save loaded")
		equal(f.data.CanWritePersistent(p), true, "session writable after recovery")
	end)

	test("client is told once that the save is being retried, then that it is ready", function()
		local b = Fixture.backend()
		local a, other = Fixture.server(sources, b, "A"), Fixture.server(sources, b, "B")
		local pA = a.add(101)
		local pB = other.add(101)
		other.advance(FIRST_ROUND + 30)
		local events = accessEvents(other)
		equal(#events, 2, "loading, then one retry notice (no spam per round)")
		equal(events[2].retrying, true, "retry notice flagged")
		equal(events[2].loading, true, "retry notice keeps actions locked")
		a.finish(a.remove(pA))
		other.advance(other.config.SESSION_LOCK_RETRY_SEC + 0.5)
		events = accessEvents(other)
		local last = events[#events]
		equal(last.loading, false, "ready after recovery")
		equal(last.safeReadOnly, false, "writable after recovery")
		equal(last.retrying, false, "retry flag cleared")
		assert(last.accessVersion > events[2].accessVersion, "version increases so the HUD accepts the update")
		assert(other.data.Get(pB), "profile present")
	end)

	test("leaving while waiting closes at once, stops retrying and never touches the owner", function()
		local b = Fixture.backend()
		local a, other = Fixture.server(sources, b, "A"), Fixture.server(sources, b, "B")
		local pA = a.add(101)
		local tokenA = b.document.activeSessionId
		local pB = other.add(101)
		other.advance(FIRST_ROUND)
		local persistence = other.loadModule("ProfilePersistenceService")
		equal(persistence.Count(), 1, "waiting session tracked")
		local leave = other.remove(pB)
		equal(coroutine.status(leave), "dead", "leave does not wait for the retry timer")
		equal(persistence.Count(), 0, "waiting session removed immediately")
		local callsAtLeave = #b.calls
		other.advance(60)
		equal(#b.calls, callsAtLeave, "no further lock requests after the player left")
		equal(b.document.activeSessionId, tokenA, "A still owns the save")
		equal(a.data.CanWritePersistent(pA), true, "A unaffected")
	end)

	test("corrupt save stays quarantined read-only and is not retried", function()
		local b = Fixture.backend()
		local f = Fixture.server(sources, b, "A")
		b.document = f.config.CreateDefaultProfile()
		b.document.gold = "not-a-number"
		local stored = b.document
		local p = f.add(101)
		f.advance(FIRST_ROUND)
		local callsAfterLoad = #b.calls
		assert(f.data.Get(p), "quarantined session keeps the protected placeholder profile")
		equal(f.data.CanWritePersistent(p), false, "quarantined session cannot write")
		f.advance(60)
		equal(#b.calls, callsAfterLoad, "quarantine is final: no retry loop")
		equal(b.document.gold, stored.gold, "corrupt document left untouched for recovery")
	end)

	print(string.format("LOCK_RETRY_SUITE passed=%d failed=%d", passed, failures))
	assert(failures == 0, "session lock retry suite failed")
end
