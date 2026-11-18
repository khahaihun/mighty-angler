local Fixture = require("./session_fixture")
local function equal(a, b, label) assert(a == b, label .. ": expected " .. tostring(b) .. ", got " .. tostring(a)) end
local function copy(value)
	if type(value) ~= "table" then return value end
	local out = {}; for k, v in pairs(value) do out[k] = copy(v) end; return out
end
local function same(a, b)
	if type(a) ~= type(b) then return false end
	if type(a) ~= "table" then return a == b or (type(a) == "number" and a ~= a and b ~= b) end
	for k, v in pairs(a) do if not same(v, b[k]) then return false end end
	for k in pairs(b) do if a[k] == nil then return false end end
	return true
end
local function fish()
	return { uid = "fish-1", fishId = "fixture_fish", weight = 10.4, sellValue = 99,
		originalValue = 99, mutation = "None", sizeTier = "Normal", locked = false, soulbound = false, midasBonus = 1 }
end

return function(sources)
	local passed, failed = 0, 0
	local function test(name, run)
		local ok, err = pcall(run)
		if ok then passed += 1; print("PASS schema " .. name)
		else failed += 1; print("FAIL schema " .. name .. ": " .. tostring(err)) end
	end
	local function setup()
		local b = Fixture.backend()
		local f = Fixture.server(sources, b, "A")
		return b, f, f.loadModule("ProfileMigrator")
	end
	test("valid v1 migration is idempotent and preserves inventory identifiers and explicit unlock", function()
		local _, f, migrator = setup()
		local raw = f.config.CreateDefaultProfile()
		raw.dataVersion = 1
		raw.playtimeDay, raw.playtimeTodaySec, raw.playtimeClaimedToday = nil, nil, nil
		raw.fishBag = { { uid = "legacy-fish", fishId = "fixture_fish", weight = 10.4, sellValue = 99, mutation = "None", locked = false } }
		raw.pets = { { uid = "pet-1", petId = "fixture_pet" } }
		raw.pinnedFishUids = { ["2"] = "legacy-fish" }
		local original = copy(raw)
		local first, reason = migrator.SanitizeLoadedProfile(raw)
		equal(reason, nil, "valid legacy accepted")
		local second, secondReason = migrator.SanitizeLoadedProfile(first)
		equal(secondReason, nil, "migrated profile accepted")
		assert(same(first, second), "migration must be idempotent")
		assert(same(raw, original), "migration never mutates input")
		equal(first.fishBag[1].uid, "legacy-fish", "fish UID preserved")
		equal(first.fishBag[1].weight, 10.4, "fish weight preserved")
		equal(first.fishBag[1].locked, false, "explicit unlock preserved")
		equal(first.pets[1].uid, "pet-1", "pet UID preserved")
		equal(first.pinnedFishUids["2"], "legacy-fish", "pin preserved")
	end)
	test("valid v2 and release receipt survive load and save", function()
		local b, f = setup()
		b.document = f.config.CreateDefaultProfile()
		b.document.fishBag = { fish() }
		b.document.lastReleaseReceipt = { token = "previous", nonce = "receipt", saveSeq = 0 }
		local p = f.add(101)
		equal(f.data.CanWritePersistent(p), true, "valid profile writable")
		equal(f.data.SaveProfile(p), "Saved", "valid profile saves")
		equal(b.document.lastReleaseReceipt.nonce, "receipt", "receipt preserved")
		equal(b.document.fishBag[1].uid, "fish-1", "valid fish preserved")
	end)

	local cases = {
		{ "nested false stat", function(p) p.stats.playTimeSec = false end },
		{ "bag wrong type", function(p) p.fishBag = "invalid" end },
		{ "fish missing id", function(p) p.fishBag = { fish() }; p.fishBag[1].fishId = nil end },
		{ "fish missing v2 weight", function(p) p.fishBag = { fish() }; p.fishBag[1].weight = nil end },
		{ "sparse fish array", function(p) p.fishBag = { [2] = fish() } end },
		{ "mixed fish array", function(p) p.fishBag = { fish(), hidden = fish() } end },
		{ "duplicate fish uid", function(p) p.fishBag = { fish(), fish() } end },
		{ "sparse equipped pet list", function(p) p.equippedPetUids = { [3] = "pet-1" } end },
		{ "sparse pet bag", function(p) p.pets = { [2] = { uid = "pet-1", petId = "pet" } } end },
		{ "map wrong key", function(p) p.potions = { [2] = 3 } end },
		{ "map wrong value", function(p) p.ownedRods.Twig = 1 end },
		{ "nested potion state", function(p) p.activePotions.Luck = { potionId = "luck", tier = 1, expiresAt = false } end },
		{ "nested quest state", function(p) p.dailyQuests.test = { id = "test", progress = {}, claimed = false } end },
		{ "invalid pin value", function(p) p.pinnedFishUids["2"] = false end },
		{ "NaN money", function(p) p.gold = 0/0 end },
		{ "infinite strength", function(p) p.strength = math.huge end },
		{ "negative currency", function(p) p.gems = -1 end },
		{ "wrong version type", function(p) p.dataVersion = "2" end },
		{ "missing v2 stats", function(p) p.stats = nil end },
		{ "invalid legacy present field", function(p) p.dataVersion = 1; p.stats.playTimeSec = false end },
		{ "future version", function(p) p.dataVersion = 3 end },
	}
	for _, case in ipairs(cases) do
		test(case[1] .. " quarantined before writes", function()
			local b, f, migrator = setup()
			local raw = f.config.CreateDefaultProfile()
			case[2](raw)
			local original = copy(raw)
			local _, reason = migrator.SanitizeLoadedProfile(raw)
			assert(reason ~= nil, "invalid input needs quarantine reason")
			assert(same(raw, original), "sanitizer must preserve raw input")
			b.document = raw
			local p, load = f.add(101); f.finish(load)
			equal(f.data.CanWritePersistent(p), false, "corrupt profile read-only")
			equal(f.data.SaveProfile(p), "Skipped", "corrupt profile cannot persist")
			assert(same(b.document, original), "store unchanged including invalid business data")
		end)
	end
	test("UTC changes once and same-day claims survive reconnect", function()
		local b, f, migrator = setup()
		b.now = 86400 - 1
		local raw = f.config.CreateDefaultProfile()
		raw.playtimeTodaySec = 90; raw.playtimeClaimedToday = { ["1"] = true }
		local sameDay = migrator.SanitizeLoadedProfile(raw)
		equal(sameDay.playtimeTodaySec, 90, "same day seconds retained")
		equal(sameDay.playtimeClaimedToday["1"], true, "same day claims retained")
		b.now = 86400
		local newDay = migrator.SanitizeLoadedProfile(sameDay)
		equal(newDay.playtimeDay, 1, "UTC day advanced")
		equal(newDay.playtimeTodaySec, 0, "new UTC day resets seconds")
		equal(next(newDay.playtimeClaimedToday), nil, "new UTC day resets claims")
	end)
	test("runtime corruption cannot stop healthy profile renewal or overwrite store", function()
		local b, f = setup()
		local bad, good = f.add(101), f.add(102)
		f.data.Get(bad).stats.playTimeSec = false
		f.data.Get(bad).gold = 999
		f.data.Get(good).gold = 81; f.data.MarkDirty(good)
		f.advance(130)
		equal(f.data.CanWritePersistent(bad), false, "bad runtime profile quarantined")
		equal(f.data.CanWritePersistent(good), true, "healthy profile still has lease")
		equal(b.document.gold, 0, "corrupt RAM never overwrites good stored data")
		equal(b.documents.Player_102.gold, 81, "healthy profile saved")
		f.finish(f.remove(good))
		local other = Fixture.server(sources, b, "B")
		local rejoin = other.add(102)
		equal(other.data.Get(rejoin).gold, 81, "healthy progress survives rejoin")
	end)
	test("one transport exception in periodic processing does not stop another player", function()
		local b, f = setup()
		local bad, good = f.add(101), f.add(102)
		f.beforeClientFire = function(player, event)
			if player == bad and event == "PlaytimeUpdated" then error("injected per-player transport failure") end
		end
		f.advance(130)
		equal(f.loadModule("ProfilePersistenceService").Find(bad).readOnly, true, "failing player isolated")
		equal(f.data.CanWritePersistent(good), true, "other player keeps renewal loop")
		assert(b.documents.Player_102.saveSeq >= 3, "healthy player's saves continue")
		assert(#f.warnings > 0, "isolated failure recorded")
	end)
	print(string.format("SCHEMA_SUITE passed=%d failed=%d", passed, failed))
	assert(failed == 0, "profile schema suite failed")
end
