local Fixture = require("./session_fixture")
local function equal(actual, expected, label)
	assert(actual == expected, string.format("%s: expected %s, got %s", label, tostring(expected), tostring(actual)))
end

return function(sources)
	local failures, passed = 0, 0
	local function test(name, run)
		local ok, err = pcall(run)
		if ok then passed += 1; print("PASS " .. name)
		else failures += 1; print("FAIL " .. name .. ": " .. tostring(err)) end
	end

	test("nonce exception fails closed and queue remains usable", function()
		local backend = Fixture.backend()
		local f = Fixture.server(sources, backend, "A")
		f.failGuidAt = 2 -- outside UpdateAsync pcall, inside real WithUserLock callback
		local p = f.add(101)
		equal(#f.warnings, 1, "exception recorded")
		equal(f.data.CanWritePersistent(p), false, "unconfirmed session cannot write")
		equal(f.data.IsTransactionLocked(p, false), true, "unconfirmed session cannot transact")
		equal(f.data.SaveProfile(p), "Skipped", "unconfirmed session cannot save")
		equal(#backend.calls, 0, "no store transaction after nonce exception")
		f.remove(p)
		local p2 = f.add(101)
		equal(f.data.CanWritePersistent(p2), true, "healthy player still writable")
	end)

	test("pending load is locked then confirmed profile saves", function()
		local b = Fixture.backend()
		local f = Fixture.server(sources, b, "A")
		f.afterUpdate = function(kind) if kind == "claim" then coroutine.yield("claim-ack") end end
		local p, load = f.add(101)
		equal(f.data.IsTransactionLocked(p, false), true, "pending transaction gate")
		equal(f.data.CanWritePersistent(p), false, "pending persistence gate")
		f.afterUpdate = nil
		f.resume(load)
		equal(f.data.CanWritePersistent(p), true, "confirmed session unlocks after pending check")
		f.data.Get(p).gold = 321
		equal(f.data.SaveProfile(p), "Saved", "confirmed save")
		equal(b.document.gold, 321, "business data persisted")
		equal(b.document.saveSeq, 2, "sequence increased")
	end)

	test("unexpected queue exception before sending claim fails closed without cleanup request", function()
		local b = Fixture.backend()
		local f = Fixture.server(sources, b, "A")
		f.failStudioCheck = true
		local p = f.add(101)
		equal(f.data.CanWritePersistent(p), false, "queue exception cannot grant persistence")
		equal(f.data.SaveProfile(p), "Skipped", "queue exception cannot save")
		equal(#f.warnings, 1, "queue exception reported")
		equal(#b.calls, 0, "no request or cleanup when no claim was sent")
		f.failStudioCheck = false
		f.remove(p)
		local nextPlayer = f.add(101)
		equal(f.data.CanWritePersistent(nextPlayer), true, "queue exception releases same-UserId queue")
	end)

	test("load failures stay read-only after bounded acquisition retries", function()
		local b = Fixture.backend()
		local f = Fixture.server(sources, b, "A")
		local claims, cleanup = 0, 0
		f.beforeUpdate = function(kind)
			if kind == "claim" then claims += 1 else cleanup += 1 end
			error("temporary datastore failure")
		end
		local p, load = f.add(101)
		f.finish(load)
		equal(claims, 3, "acquire attempt bound")
		equal(cleanup, 3, "uncertain cleanup attempt bound")
		equal(b.document, nil, "failed requests never changed stored business data")
		equal(f.data.CanWritePersistent(p), false, "failed load blocked")
		equal(f.data.SaveProfile(p), "Skipped", "failed load never overwrites")
	end)

	for _, field in ipairs({ "activeSessionId", "lastWriteNonce" }) do
		test("wrong returned " .. field .. " never opens persistent transactions", function()
			local b = Fixture.backend()
			local f = Fixture.server(sources, b, "A")
			f.afterUpdate = function(kind, response)
				if kind == "claim" then response[field] = "unconfirmed-response" end
			end
			local p, load = f.add(101)
			f.finish(load)
			equal(f.data.CanWritePersistent(p), false, "returned confirmation required")
			equal(f.data.SaveProfile(p), "Skipped", "unconfirmed response cannot save")
		end)
	end

	test("active owner blocks another server and still saves", function()
		local b = Fixture.backend()
		local a, other = Fixture.server(sources, b, "A"), Fixture.server(sources, b, "B")
		local pA = a.add(101)
		local tokenA = b.document.activeSessionId
		local pB, loadB = other.add(101)
		other.finish(loadB)
		equal(a.data.CanWritePersistent(pA), true, "A keeps permission")
		equal(other.data.CanWritePersistent(pB), false, "B cannot acquire live A lease")
		equal(b.document.activeSessionId, tokenA, "A owner unchanged")
		equal(#b.calls, 4, "known refusal uses three claims and no extra release")
		equal(other.data.SaveProfile(pB), "Skipped", "B cannot overwrite")
		a.data.Get(pA).gold = 999
		equal(a.data.SaveProfile(pA), "Saved", "A can still save")
		equal(b.document.gold, 999, "A progress intact")
	end)

	test("all claim acknowledgements lost while online then immediate rejoin succeeds", function()
		local b = Fixture.backend()
		local f = Fixture.server(sources, b, "A")
		f.afterUpdate = function(kind) if kind == "claim" then error("claim acknowledgement lost") end end
		local p, load = f.add(101)
		f.finish(load)
		equal(f.data.CanWritePersistent(p), false, "uncertain completed load stays read-only")
		equal(b.document.activeSessionId, nil, "uncertain claim cleaned before failed load finishes")
		equal(#b.calls, 4, "three claims followed by one token cleanup")
		f.remove(p)
		f.afterUpdate = nil
		local rejoin, nextLoad = f.add(101)
		f.finish(nextLoad)
		equal(f.data.CanWritePersistent(rejoin), true, "quick rejoin writable without waiting TTL")
		f.data.Get(rejoin).gold = 642
		equal(f.data.SaveProfile(rejoin), "Saved", "quick rejoin saves")
		equal(b.document.gold, 642, "quick rejoin progress preserved")
	end)

	test("nonce exception after uncertain committed claim still cleans that token", function()
		local b = Fixture.backend()
		local f = Fixture.server(sources, b, "A")
		f.failGuidAt = 3
		f.afterUpdate = function(kind) if kind == "claim" then error("claim acknowledgement lost") end end
		local p, load = f.add(101)
		f.finish(load)
		equal(f.data.CanWritePersistent(p), false, "setup exception after uncertain write stays locked")
		equal(b.document.activeSessionId, nil, "setup exception cannot strand previous uncertain claim")
		equal(#b.calls, 2, "one sent claim then one cleanup")
	end)

	test("two joins same UserId serialize through orphan release retry", function()
		local b = Fixture.backend()
		local f = Fixture.server(sources, b, "A")
		local releaseAttempts = 0
		f.afterUpdate = function(kind) if kind == "claim" then coroutine.yield("claim-ack") end end
		local a, loadA = f.add(101)
		local tokenA = b.document.activeSessionId
		f.remove(a)
		local nextPlayer, loadB = f.add(101)
		equal(#b.calls, 1, "second join waits for same UserId")
		equal(f.data.CanWritePersistent(nextPlayer), false, "second join not confirmed")
		f.afterUpdate = nil
		f.beforeUpdate = function(kind)
			if kind == "release" then
				releaseAttempts += 1
				if releaseAttempts == 1 then error("temporary release failure") end
			end
		end
		f.resume(loadA)
		f.finish(loadA)
		equal(releaseAttempts, 2, "orphan release retried and confirmed")
		equal(b.document.activeSessionId, nil, "A token released")
		f.finish(loadB)
		equal(f.data.Get(a), nil, "departed A has no loaded profile")
		equal(f.data.CanWritePersistent(nextPlayer), true, "second join confirmed")
		assert(b.document.activeSessionId ~= tokenA, "join needs distinct token")
		f.data.Get(nextPlayer).gold = 456
		equal(f.data.SaveProfile(nextPlayer), "Saved", "second join saves")
		equal(b.document.gold, 456, "second join progress persists")
	end)

	for _, pausePhase in ipairs({ "before", "after" }) do
		test("late A release " .. pausePhase .. " commit preserves B", function()
			local b = Fixture.backend()
			local a = Fixture.server(sources, b, "A")
			a.afterUpdate = function(kind) if kind == "claim" then coroutine.yield("claim-ack") end end
			local playerA, loadA = a.add(101)
			a.remove(playerA)
			a.afterUpdate = nil
			local paused = false
			a[pausePhase .. "Update"] = function(kind)
				if kind == "release" and not paused then paused = true; coroutine.yield("release-pause") end
			end
			a.resume(loadA)
			equal(paused, true, "A release actually suspended")
			if pausePhase == "before" then b.now += 121 end -- B can take expired A lease
			local serverB = Fixture.server(sources, b, "B")
			local playerB = serverB.add(101)
			equal(serverB.data.CanWritePersistent(playerB), true, "B holds confirmed session")
			serverB.data.Get(playerB).gold = 789
			equal(serverB.data.SaveProfile(playerB), "Saved", "B saves before late A response")
			local tokenB, seqB, commits = b.document.activeSessionId, b.document.saveSeq, b.commits
			a.resume(loadA)
			a.finish(loadA)
			equal(b.document.activeSessionId, tokenB, "late release preserves B token")
			equal(b.document.saveSeq, seqB, "late release preserves B sequence")
			equal(b.document.gold, 789, "late release preserves B business data")
			equal(b.commits, commits, "late release never commits over B")
			equal(a.data.CanWritePersistent(playerA), false, "A never regains write permission")
		end)
	end

	test("orphan release exhaustion is bounded and explicitly reported", function()
		local b = Fixture.backend()
		local f = Fixture.server(sources, b, "A")
		f.afterUpdate = function(kind) if kind == "claim" then coroutine.yield("claim-ack") end end
		local p, load = f.add(101)
		f.remove(p)
		f.afterUpdate = nil
		local attempts = 0
		f.beforeUpdate = function(kind)
			if kind == "release" then attempts += 1; error("release still unavailable") end
		end
		f.resume(load)
		f.finish(load)
		equal(attempts, 3, "release retry bound")
		assert(#f.warnings > 0, "unconfirmed release must be reported")
		equal(f.data.CanWritePersistent(p), false, "exhausted departed session cannot write")
	end)

	test("release reports confirmed release, no ownership, and exhausted error", function()
		local b = Fixture.backend()
		local f = Fixture.server(sources, b, "A")
		b.document = { activeSessionId = "token-A", lockTimestamp = 10000, gold = 55, saveSeq = 1 }
		equal(f.helper.ReleaseToken(f.store, "Player_101", "token-A"), "Released", "release acknowledgement")
		equal(b.document.gold, 55, "release keeps business fields")
		b.document.activeSessionId = "token-B"
		local commits = b.commits
		equal(f.helper.ReleaseToken(f.store, "Player_101", "token-A"), "NotOwner", "different owner acknowledgement")
		equal(b.commits, commits, "different owner never rewritten")
		equal(b.document.activeSessionId, "token-B", "different owner retained")
		f.beforeUpdate = function() error("API unavailable") end
		local calls = #b.calls
		local status
		local request = f.spawn(function() status = f.helper.ReleaseToken(f.store, "Player_101", "token-A") end)
		f.finish(request)
		equal(status, "TransientError", "unconfirmed result is explicit")
		equal(#b.calls - calls, 3, "unconfirmed request stops after three attempts")
		assert(string.find(f.warnings[1], "Player_101", 1, true), "warning must identify profile key")
		assert(string.find(f.warnings[1], "token-A", 1, true), "warning must identify orphan token")
	end)

	test("release committed but response lost is confirmed on retry without rewriting", function()
		local b = Fixture.backend()
		local f = Fixture.server(sources, b, "A")
		f.afterUpdate = function(kind) if kind == "claim" then coroutine.yield("claim-ack") end end
		local p, load = f.add(101)
		f.remove(p)
		f.afterUpdate = function(kind) if kind == "release" then error("release acknowledgement lost") end end
		f.resume(load)
		f.finish(load)
		equal(#b.calls, 3, "claim, committed release, retry cancellation")
		equal(b.commits, 2, "retry must not write an unlocked document")
		equal(b.document.activeSessionId, nil, "token no longer owns document")
		equal(#f.warnings, 0, "retry confirmed no ownership")
	end)

	for _, newOwner in ipairs({ false, true }) do
		test("claim response lost then A leaves; new owner=" .. tostring(newOwner), function()
			local b = Fixture.backend()
			local a = Fixture.server(sources, b, "A")
			a.afterUpdate = function(kind) if kind == "claim" then error("claim acknowledgement lost") end end
			local playerA, loadA = a.add(101)
			local tokenA = b.document.activeSessionId
			a.remove(playerA) -- A is now waiting between acquisition attempts
			local tokenB, seqB, commits
			if newOwner then
				b.now += 121
				local serverB = Fixture.server(sources, b, "B")
				local pB = serverB.add(101)
				equal(serverB.data.CanWritePersistent(pB), true, "B acquired expired uncertain A claim")
				serverB.data.Get(pB).gold = 975
				equal(serverB.data.SaveProfile(pB), "Saved", "B saves after uncertain A claim")
				tokenB, seqB, commits = b.document.activeSessionId, b.document.saveSeq, b.commits
			end
			local callsBeforeCleanup = #b.calls
			a.finish(loadA)
			equal(#b.calls, callsBeforeCleanup + 1, "uncertain departed claim checks token ownership")
			assert(b.document.activeSessionId ~= tokenA, "uncertain departed A token must not remain until TTL")
			equal(a.data.Get(playerA), nil, "departed uncertain A has no profile")
			if newOwner then
				equal(b.document.activeSessionId, tokenB, "uncertain A cleanup preserves B token")
				equal(b.document.saveSeq, seqB, "uncertain A cleanup preserves B sequence")
				equal(b.document.gold, 975, "uncertain A cleanup preserves B money")
				equal(b.commits, commits, "uncertain A cleanup never rewrites B")
			else equal(b.document.activeSessionId, nil, "uncertain A token release confirmed") end
		end)
	end

	test("leave during quarantine release never reinstalls departed profile", function()
		local b = Fixture.backend()
		local f = Fixture.server(sources, b, "A")
		b.document = f.config.CreateDefaultProfile()
		b.document.fishBag = { { fishId = "fixture_fish_without_uid" } }
		f.failGuidAt = 3 -- token, claim nonce, then migration UID: actual quarantine path
		local callbacks, releases = 0, 0
		f.data.OnProfileLoaded(function() callbacks += 1 end)
		f.beforeUpdate = function(kind)
			if kind == "release" then
				releases += 1
				if releases == 1 then error("temporary quarantine release failure") end
			end
		end
		local p, load = f.add(101)
		equal(coroutine.status(load), "suspended", "quarantine release retry actually waits")
		f.remove(p)
		f.finish(load)
		equal(releases, 2, "quarantine cleanup released token")
		equal(b.document.activeSessionId, nil, "quarantine token cleared")
		equal(f.data.Get(p), nil, "departed profile never reinstalled")
		equal(callbacks, 0, "departed profile never announces loaded")
	end)

	test("RAM-only unpublished Studio keeps gameplay without persistence", function()
		local b = Fixture.backend()
		local f = Fixture.server(sources, b, "A", 0)
		local p = f.add(101)
		equal(f.data.IsTransactionLocked(p, false), false, "RAM session playable")
		f.data.Get(p).gold = 123
		equal(f.data.SaveProfile(p), "Saved", "existing RAM save result")
		equal(f.data.Get(p).gold, 123, "RAM changes retained")
		equal(f.opens, 0, "RAM mode never opens store")
		equal(#b.calls, 0, "RAM mode never writes datastore")
	end)

	print(string.format("SESSION_SUITE passed=%d failed=%d; real DataService/LockHelper, simulated stores only", passed, failures))
	assert(failures == 0, "session acquisition suite failed")
end
