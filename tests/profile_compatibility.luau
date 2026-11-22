-- Guards saved profiles across schema changes. Runs the real GameConfig, ProfileValidator, ProfileMigrator
-- and DataService in the Luau VM; only the store is simulated.
-- Breaks caught: adding/removing/retyping a profile field without raising GameConfig.PROFILE_SCHEMA_VERSION
-- (which quarantines every existing save), a version number that is not shared by validator and migrator,
-- and an older server overwriting a save written by a newer one.
local Fixture = require("./session_fixture")
local function equal(a, b, label) assert(a == b, label .. ": expected " .. tostring(b) .. ", got " .. tostring(a)) end

-- FROZEN FIELD LISTS. Never edit a published version's list. When the profile shape changes:
-- 1) raise GameConfig.PROFILE_SCHEMA_VERSION, 2) add the new version's list here, 3) keep the old lists.
local FROZEN = {
	[2] = {
		top = "activePotions:table autoLockMutated:boolean autoLockRare:boolean bait:table claimedAchievements:table "
			.. "claimedIndexRewards:table currentIsland:number dailyQuests:table dailyStreak:number dataVersion:number "
			.. "enchantRelics:number equippedHotbarSlot:number equippedPetUids:table fishBag:table gems:number gold:number "
			.. "gymGearLevel:number indexFish:table indexPets:table lastDailyClaimDay:number lockTimestamp:number "
			.. "lowGfx:boolean muteSfx:boolean ownedRods:table pets:table pinnedFishUids:table playtimeClaimedToday:table "
			.. "playtimeDay:number playtimeTodaySec:number potions:table questDay:number rebirths:number rodEnchants:table "
			.. "rodId:string saveSeq:number stats:table strength:number totalStrength:number unlockedIslands:table",
		stats = "bossCaught:number eggsHatched:number eventsJoined:number fishCaught:number goldEarned:number "
			.. "gymReps:number mutationsCaught:number playTimeSec:number rareCaught:number",
	},
	[3] = {
		top = "activePotions:table autoLockMutated:boolean autoLockRare:boolean bait:table claimedAchievements:table "
			.. "claimedIndexRewards:table currentIsland:number dailyQuests:table dailyStreak:number dataVersion:number "
			.. "enchantRelics:number equippedHotbarSlot:number equippedPetUids:table fishBag:table gems:number gold:number "
			.. "gymGearLevel:number indexFish:table indexPets:table lastDailyClaimDay:number lockTimestamp:number "
			.. "lowGfx:boolean muteSfx:boolean ownedRods:table pets:table pinnedFishUids:table playtimeClaimedToday:table "
			.. "playtimeDay:number playtimeTodaySec:number potions:table processedPurchaseIds:table questDay:number "
			.. "rebirths:number redeemedCodes:table rodEnchants:table "
			.. "rodId:string saveSeq:number stats:table strength:number totalStrength:number unlockedIslands:table",
		stats = "bossCaught:number eggsHatched:number eventsJoined:number fishCaught:number goldEarned:number "
			.. "gymReps:number mutationsCaught:number playTimeSec:number rareCaught:number",
	},
}

-- A save exactly as a version-2 server stores it for a player with real progress.
local function goldenV2()
	return {
		dataVersion = 2, activeSessionId = nil, lockTimestamp = 0, saveSeq = 41, lastWriteNonce = "nonce-41",
		lastReleaseReceipt = { token = "old-server", nonce = "nonce-41", saveSeq = 41 },
		gold = 123456, gems = 77, strength = 9876.5, totalStrength = 54321, rebirths = 2,
		rodId = "Twig", ownedRods = { Twig = true }, rodEnchants = { Twig = "lucky" }, enchantRelics = 3,
		equippedHotbarSlot = 0, pinnedFishUids = { ["2"] = "fish-a" }, unlockedIslands = { ["1"] = true, ["2"] = true },
		currentIsland = 2,
		fishBag = { { uid = "fish-a", fishId = "fixture_fish", weight = 12.5, sellValue = 250, originalValue = 250,
			mutation = "None", sizeTier = "Normal", locked = true, soulbound = false, midasBonus = 1 } },
		potions = { luck_s = 2 }, activePotions = { Luck = { potionId = "luck_s", tier = 1, expiresAt = 20000 } },
		bait = { worm = 9 }, activeBait = "worm", gymGearLevel = 4,
		pets = { { uid = "pet-a", petId = "fixture_pet" } }, equippedPetUids = { "pet-a" },
		indexFish = { fixture_fish = 3 }, indexPets = { fixture_pet = 1 },
		claimedIndexRewards = { r1 = true }, claimedAchievements = { a1 = true },
		dailyStreak = 5, lastDailyClaimDay = 20000, questDay = 20000,
		dailyQuests = { q1 = { id = "q1", progress = 3, claimed = false } },
		playtimeDay = 1, playtimeTodaySec = 600, playtimeClaimedToday = { ["1"] = true },
		autoLockRare = true, autoLockMutated = false, lowGfx = true, muteSfx = false,
		stats = { fishCaught = 300, rareCaught = 12, bossCaught = 1, mutationsCaught = 4, gymReps = 900,
			goldEarned = 222222, eggsHatched = 8, eventsJoined = 2, playTimeSec = 36000 },
	}
end

-- The same player saved by today's server (version 3 adds purchase receipts and redeemed codes).
local function goldenV3()
	local doc = goldenV2()
	doc.dataVersion = 3
	doc.processedPurchaseIds = { "receipt-1", "receipt-2" }
	doc.redeemedCodes = { RELEASE = true }
	return doc
end

local function signature(tbl)
	local parts = {}
	for key, value in pairs(tbl) do table.insert(parts, tostring(key) .. ":" .. type(value)) end
	table.sort(parts)
	return table.concat(parts, " ")
end

local function difference(actual, frozen)
	local have, want, notes = {}, {}, {}
	for item in string.gmatch(actual, "%S+") do have[item] = true end
	for item in string.gmatch(frozen, "%S+") do want[item] = true end
	for item in pairs(have) do if not want[item] then table.insert(notes, "+" .. item) end end
	for item in pairs(want) do if not have[item] then table.insert(notes, "-" .. item) end end
	table.sort(notes)
	return table.concat(notes, " ")
end

-- The rule a developer must follow; also applied to deliberately broken configs below.
local function checkFrozen(config)
	local version = config.PROFILE_SCHEMA_VERSION
	local frozen = FROZEN[version]
	assert(frozen, string.format("PROFILE_SCHEMA_VERSION is %s but tests/profile_compatibility.luau has no frozen "
		.. "field list for it; add FROZEN[%s] and keep the older lists", tostring(version), tostring(version)))
	local defaults = config.CreateDefaultProfile()
	local topDiff, statsDiff = difference(signature(defaults), frozen.top), difference(signature(defaults.stats), frozen.stats)
	assert(topDiff == "" and statsDiff == "", string.format("profile fields changed without raising "
		.. "GameConfig.PROFILE_SCHEMA_VERSION (still %d): top[%s] stats[%s]. Existing saves would be quarantined. "
		.. "Raise the version and add a new FROZEN list.", version, topDiff, statsDiff))
end

-- Future code: the same sources with one more profile field, with or without the version raised.
local function evolved(sources, raiseVersion)
	local patched = table.clone(sources)
	local config, fields = string.gsub(sources.GameConfig, "\t\tlowGfx = false,", "\t\tlowGfx = false,\n\t\tfutureTokens = 7,", 1)
	equal(fields, 1, "test patch: field inserted")
	if raiseVersion then
		local versions
		local current = tonumber(string.match(config, "GameConfig%.PROFILE_SCHEMA_VERSION = (%d+)"))
		config, versions = string.gsub(config, "GameConfig%.PROFILE_SCHEMA_VERSION = %d+", "GameConfig.PROFILE_SCHEMA_VERSION = " .. tostring(current + 1), 1)
		equal(versions, 1, "test patch: version raised")
	end
	patched.GameConfig = config
	return patched
end

local function join(sources, document)
	local b = Fixture.backend()
	b.document = document
	local f = Fixture.server(sources, b, "A")
	local p, load = f.add(101)
	f.finish(load)
	return b, f, p
end

return function(sources)
	local passed, failed = 0, 0
	local function test(name, run)
		local ok, err = pcall(run)
		if ok then passed += 1; print("PASS compatibility " .. name)
		else failed += 1; print("FAIL compatibility " .. name .. ": " .. tostring(err)) end
	end

	test("current profile fields match the frozen list for the current schema version", function()
		local _, f = join(sources, nil)
		checkFrozen(f.config)
	end)

	test("schema version is declared once and shared by defaults, validator and migrator", function()
		local _, f = join(sources, nil)
		local version = f.config.PROFILE_SCHEMA_VERSION
		equal(f.config.CreateDefaultProfile().dataVersion, version, "default profile version")
		for _, name in ipairs({ "ProfileValidator", "ProfileMigrator", "DataService", "ProfilePersistenceService", "ProfileWriteHelper" }) do
			assert(not string.find(sources[name], "dataVersion%s*[<>=~]+%s*%d") and not string.find(sources[name], "version%s*[<>=~]+%s*[2-9]"),
				name .. " compares the data version with a literal number instead of GameConfig.PROFILE_SCHEMA_VERSION")
		end
		local validator = f.loadModule("ProfileValidator")
		local sameVersion, newer = f.config.CreateDefaultProfile(), f.config.CreateDefaultProfile()
		newer.dataVersion = version + 1
		equal(validator.Validate(sameVersion), nil, "current version accepted")
		equal(validator.Validate(newer), "NewerSchemaVersion", "next version rejected by validator")
		local _, reason = f.loadModule("ProfileMigrator").SanitizeLoadedProfile(newer)
		equal(reason, "NewerSchemaVersion", "next version rejected by migrator")
	end)

	test("a real version-2 save loads writable today with every value intact", function()
		local b, f, p = join(sources, goldenV2())
		equal(f.data.CanWritePersistent(p), true, "version-2 save is writable, not quarantined")
		local profile = f.data.Get(p)
		equal(profile.gold, 123456, "gold"); equal(profile.strength, 9876.5, "strength"); equal(profile.rebirths, 2, "rebirths")
		equal(profile.fishBag[1].uid, "fish-a", "fish"); equal(profile.pets[1].uid, "pet-a", "pet")
		equal(profile.equippedHotbarSlot, 0, "hotbar sentinel"); equal(profile.stats.goldEarned, 222222, "stats")
		equal(profile.activePotions.Luck.expiresAt, 20000, "active potion"); equal(profile.dailyQuests.q1.progress, 3, "quest")
		equal(profile.autoLockMutated, false, "false setting kept"); equal(profile.lowGfx, true, "true setting kept")
		profile.gold += 1
		f.finish(f.remove(p))
		equal(b.document.gold, 123457, "saved on leave"); equal(b.document.activeSessionId, nil, "lock released")
	end)

	test("new field without a version bump: old saves get quarantined, and the frozen list catches it first", function()
		local broken = evolved(sources, false)
		local b, f, p = join(broken, goldenV3())
		equal(f.data.CanWritePersistent(p), false, "this is the outage: every existing save becomes read-only")
		equal(b.document.gold, 123456, "quarantined save untouched")
		local ok, err = pcall(checkFrozen, f.config)
		equal(ok, false, "frozen-list check fails for the unbumped change")
		assert(string.find(tostring(err), "+futureTokens:number", 1, true), "failure names the new field: " .. tostring(err))
	end)

	test("a real version-3 save keeps its receipts and redeemed codes", function()
		local b, f, p = join(sources, goldenV3())
		equal(f.data.CanWritePersistent(p), true, "version-3 save is writable")
		local profile = f.data.Get(p)
		equal(profile.processedPurchaseIds[2], "receipt-2", "receipt ids kept"); equal(profile.redeemedCodes.RELEASE, true, "code kept")
		f.finish(f.remove(p))
		equal(b.document.processedPurchaseIds[1], "receipt-1", "receipts saved"); equal(b.document.redeemedCodes.RELEASE, true, "codes saved")
	end)

	test("new field with the version raised: old save loads, gains the default, and is stored as the new version", function()
		local upgraded = evolved(sources, true)
		local b, f, p = join(upgraded, goldenV2())
		local raised = f.config.PROFILE_SCHEMA_VERSION
		equal(f.data.CanWritePersistent(p), true, "version-2 save still writable on raised-version code")
		local profile = f.data.Get(p)
		equal(profile.futureTokens, 7, "missing new field filled from defaults")
		equal(profile.gold, 123456, "old progress kept"); equal(profile.fishBag[1].uid, "fish-a", "old fish kept")
		equal(profile.dataVersion, raised, "profile upgraded in memory")
		f.finish(f.remove(p))
		equal(b.document.dataVersion, raised, "stored as the raised version"); equal(b.document.futureTokens, 7, "new field stored")
		local ok, err = pcall(checkFrozen, f.config)
		equal(ok, false, "a raised version still needs its own frozen list")
		assert(string.find(tostring(err), "no frozen field list", 1, true), "failure asks for the new list: " .. tostring(err))
	end)

	test("rollback safety: today's server never overwrites a save written by a newer version", function()
		local future = goldenV2()
		local _, current = join(sources, nil)
		local newerVersion = current.config.PROFILE_SCHEMA_VERSION + 1
		future.dataVersion, future.futureTokens = newerVersion, 99
		local b, f, p = join(sources, future)
		equal(f.data.CanWritePersistent(p), false, "newer save is read-only on older code")
		equal(f.data.SaveProfile(p), "Skipped", "no save attempted")
		f.finish(f.remove(p))
		equal(b.document.dataVersion, newerVersion, "version untouched"); equal(b.document.futureTokens, 99, "newer field untouched")
		equal(b.document.gold, 123456, "progress untouched")
	end)

	test("a raised-version save missing its own new field is still rejected (strict check stays on for the current version)", function()
		local upgraded = evolved(sources, true)
		local current = goldenV2()
		local _, probe = join(upgraded, nil)
		current.dataVersion = probe.config.PROFILE_SCHEMA_VERSION -- claims the raised version but lacks futureTokens: truncated or hand-edited
		local b, f, p = join(upgraded, current)
		equal(f.data.CanWritePersistent(p), false, "incomplete current-version save quarantined")
		equal(b.document.futureTokens, nil, "store untouched")
	end)

	print(string.format("COMPATIBILITY_SUITE passed=%d failed=%d", passed, failed))
	assert(failed == 0, "profile_compatibility suite failed")
end
