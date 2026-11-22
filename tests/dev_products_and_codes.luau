-- Gems packs (ProcessReceipt), Redeem Codes, AnalyticsHelper and profile v3 migration.
-- Runs the real ReceiptService, CodesService, AnalyticsHelper, DataService, persistence, validator and migrator in the
-- Luau VM; only DataStore, Players, PerkService policy and client pushes are simulated. Does not prove Roblox's
-- real MarketplaceService retry cadence or AnalyticsService dashboards.
local Fixture = require("./session_fixture")
local function equal(a, b, label) assert(a == b, label .. ": expected " .. tostring(b) .. ", got " .. tostring(a)) end

local GRANTED, NOT_YET = "PurchaseGranted", "NotProcessedYet"
local ENUM = { ProductPurchaseDecision = { PurchaseGranted = GRANTED, NotProcessedYet = NOT_YET } }

local function goldenV2()
	return {
		dataVersion = 2, lockTimestamp = 0, saveSeq = 12, gold = 4000, gems = 30, strength = 50, totalStrength = 50,
		rebirths = 0, rodId = "Twig", ownedRods = { Twig = true }, rodEnchants = {}, enchantRelics = 1,
		equippedHotbarSlot = 1, pinnedFishUids = {}, unlockedIslands = { ["1"] = true }, currentIsland = 1,
		fishBag = {}, potions = {}, activePotions = {}, bait = {}, gymGearLevel = 0, pets = {}, equippedPetUids = {},
		indexFish = {}, indexPets = {}, claimedIndexRewards = {}, claimedAchievements = {}, dailyStreak = 0,
		lastDailyClaimDay = 0, questDay = 0, dailyQuests = {}, playtimeDay = 1, playtimeTodaySec = 0,
		playtimeClaimedToday = {}, autoLockRare = true, autoLockMutated = true, lowGfx = false, muteSfx = false,
		stats = { fishCaught = 9, rareCaught = 0, bossCaught = 0, mutationsCaught = 0, gymReps = 0, goldEarned = 4000,
			eggsHatched = 0, eventsJoined = 0, playTimeSec = 600 },
	}
end

-- One server with player 101 joined (profile loaded) and every Gems pack configured with id 9001..9005.
local function world(sources, backend, job, document)
	backend = backend or Fixture.backend()
	if document ~= nil then backend.document = document end
	local m = { pushes = 0, inventory = 0, policy = "Allowed", failSaves = false, slowSaves = false }
	local deps = {
		CurrencyService = { PushCurrencies = function() m.pushes += 1 end },
		ShopAndItemsService = { PushInventory = function() m.inventory += 1 end },
		PerkService = { GetPolicyState = function() return m.policy end,
			ArePaidRandomItemsRestricted = function() return m.policy ~= "Allowed" end },
	}
	local f = Fixture.server(sources, backend, job or "A", nil, { dependencies = deps, globals = { Enum = ENUM } })
	f.beforeUpdate = function(kind)
		if kind == "save" and m.slowSaves then coroutine.yield(0.5) end
		if kind == "save" and m.failSaves then error("DataStore 503 (injected)") end
	end
	local p, load = f.add(101)
	f.finish(load)
	f.products = f.loadModule("DevProductsConfig")
	for index, product in ipairs(f.products.List) do product.id = 9000 + index end
	f.receipts = f.loadModule("ReceiptService")
	f.codes = f.loadModule("CodesService")
	f.codesConfig = f.loadModule("CodesConfig")
	return backend, f, p, m
end

local function receipt(f, purchaseId, productId, userId)
	local out
	f.finish(f.spawn(function()
		out = f.receipts.ProcessReceipt({ PurchaseId = purchaseId, ProductId = productId or 9001, PlayerId = userId or 101, CurrencySpent = 25 })
	end))
	return out
end

local function redeem(f, p, raw)
	local status, message
	f.finish(f.spawn(function() status, message = f.codes.Redeem(p, raw) end))
	f.advance(2) -- past CODE_REDEEM_MIN_GAP_SEC so the next attempt is not rate-limited
	return status, message
end

local function count(list, value)
	local n = 0
	for _, item in ipairs(list or {}) do if item == value then n += 1 end end
	return n
end

-- Standalone AnalyticsHelper with a custom AnalyticsService (or none).
local function analytics(sources, service, enum)
	local players = {}
	local env = setmetatable({
		game = { GetService = function(_, name)
			if name == "Players" then return players end
			if service == nil then error("Unknown service " .. name) end
			return service
		end },
		Enum = enum, warn = function() end,
	}, { __index = getfenv() })
	local chunk = assert(loadstring(sources.AnalyticsHelper, "@AnalyticsHelper"))
	setfenv(chunk, env)
	local player = { UserId = 7 }
	function player:IsDescendantOf(parent) return parent == players end
	return chunk(), player
end

return function(sources)
	local passed, failed = 0, 0
	local function test(name, run)
		local ok, err = pcall(run)
		if ok then passed += 1; print("PASS monetization " .. name)
		else failed += 1; print("FAIL monetization " .. name .. ": " .. tostring(err)) end
	end

	test("receipt grants Gems once, only after the DataStore save is confirmed", function()
		local b, f, p, m = world(sources)
		local before = f.data.Get(p).gems
		equal(receipt(f, "P1", 9002), GRANTED, "first delivery")
		equal(f.data.Get(p).gems, before + 550, "RAM gems")
		equal(b.document.gems, before + 550, "stored gems before PurchaseGranted")
		equal(b.document.processedPurchaseIds[1], "P1", "stored purchase id")
		local commits = b.commits
		equal(receipt(f, "P1", 9002), GRANTED, "duplicate delivery is idempotent")
		equal(f.data.Get(p).gems, before + 550, "duplicate adds nothing"); equal(b.commits, commits, "duplicate writes nothing")
		assert(m.pushes >= 1, "currency pushed to client")
	end)

	test("same PurchaseId replayed on another server after rejoin is not granted twice", function()
		local b, f, p = world(sources)
		equal(receipt(f, "P9", 9005), GRANTED, "granted on server A")
		local gems = b.document.gems
		f.finish(f.remove(p))
		local _, g, q = world(sources, b, "B")
		equal(g.data.Get(q).gems, gems, "loaded on B")
		equal(receipt(g, "P9", 9005), GRANTED, "replay acknowledged")
		equal(g.data.Get(q).gems, gems, "no second grant on B")
	end)

	test("DataStore failure returns NotProcessedYet: Robux not lost, Gems never doubled", function()
		local b, f, p, m = world(sources)
		local base, storedBase = f.data.Get(p).gems, b.document.gems
		m.failSaves = true
		equal(receipt(f, "P2", 9001), NOT_YET, "save failed -> retry later")
		equal(b.document.gems, storedBase, "store unchanged"); equal(count(b.document.processedPurchaseIds, "P2"), 0, "id not stored")
		equal(receipt(f, "P2", 9001), NOT_YET, "still failing")
		equal(f.data.Get(p).gems, base + 100, "RAM credited once, not per retry")
		m.failSaves = false
		equal(receipt(f, "P2", 9001), GRANTED, "store recovered")
		equal(b.document.gems, base + 100, "stored exactly once"); equal(f.data.Get(p).gems, base + 100, "RAM exactly once")
		equal(count(f.data.Get(p).processedPurchaseIds, "P2"), 1, "id recorded once")
		equal(receipt(f, "P2", 9001), GRANTED, "later replay"); equal(f.data.Get(p).gems, base + 100, "still once")
	end)

	test("unconfirmed grant persisted by the leave-save is honoured by the next server", function()
		local b, f, p, m = world(sources)
		local base = f.data.Get(p).gems
		m.failSaves = true
		equal(receipt(f, "P3", 9001), NOT_YET, "unconfirmed")
		m.failSaves = false
		f.finish(f.remove(p))
		equal(b.document.gems, base + 100, "leave-save carried gems and id together")
		local _, g, q = world(sources, b, "B")
		equal(receipt(g, "P3", 9001), GRANTED, "Roblox retry on B")
		equal(g.data.Get(q).gems, base + 100, "no double grant")
	end)

	test("read-only (quarantined) profile returns NotProcessedYet and changes nothing", function()
		local future = goldenV2()
		future.dataVersion = 99
		local b, f, p = world(sources, nil, "A", future)
		equal(f.data.CanWritePersistent(p), false, "quarantined")
		equal(receipt(f, "P4", 9001), NOT_YET, "read-only")
		equal(f.data.Get(p).gems, 0, "no RAM grant"); equal(b.document.gems, 30, "store untouched")
	end)

	test("session lock stolen mid-purchase: NotProcessedYet, other server's save untouched", function()
		local b, f, p = world(sources)
		b.document.activeSessionId, b.document.gems = "thief-token", 5
		equal(receipt(f, "P5", 9001), NOT_YET, "LostLock is not a grant")
		equal(f.data.CanWritePersistent(p), false, "now read-only")
		equal(receipt(f, "P5", 9001), NOT_YET, "retry while read-only")
		equal(b.document.gems, 5, "thief document untouched"); equal(count(b.document.processedPurchaseIds, "P5"), 0, "no id written")
	end)

	test("concurrent duplicate delivery while the first save is in flight grants once", function()
		local b, f, p, m = world(sources)
		local base = f.data.Get(p).gems
		m.slowSaves = true
		local first
		local t1 = f.spawn(function() first = f.receipts.ProcessReceipt({ PurchaseId = "P6", ProductId = 9001, PlayerId = 101 }) end)
		equal(receipt(f, "P6", 9001), NOT_YET, "second copy waits for the first")
		f.finish(t1)
		equal(first, GRANTED, "first copy granted")
		equal(f.data.Get(p).gems, base + 100, "granted once"); equal(b.document.gems, base + 100, "stored once")
	end)

	test("unknown, unconfigured (id 0) or offline-player receipts never grant", function()
		local _, f, p = world(sources)
		local base = f.data.Get(p).gems
		equal(receipt(f, "Q1", 0), NOT_YET, "id 0"); equal(receipt(f, "Q2", 123456), NOT_YET, "unknown id")
		equal(receipt(f, "Q3", 9001, 999), NOT_YET, "player not in server")
		equal(f.receipts.ProcessReceipt(nil), NOT_YET, "malformed receipt")
		equal(f.data.Get(p).gems, base, "nothing granted")
	end)

	test("purchase id ring buffer keeps only the 60 most recent ids", function()
		local b, f, p = world(sources)
		for i = 1, 65 do equal(receipt(f, "R" .. i, 9001), GRANTED, "receipt " .. i) end
		local ids = f.data.Get(p).processedPurchaseIds
		equal(#ids, 60, "capped"); equal(ids[1], "R6", "oldest kept"); equal(ids[60], "R65", "newest kept")
		equal(#b.document.processedPurchaseIds, 60, "stored capped")
	end)

	test("purchase prompt blocked for id 0, loading policy and read-only saves", function()
		local _, f, p, m = world(sources)
		f.products.ByKey.GemsPouch.id = 0
		local id, message = f.receipts.CheckPrompt(p, "GemsPouch")
		equal(id, nil, "id 0 blocked"); assert(message and string.find(message, "DevProductsConfig", 1, true), "friendly studio hint")
		equal(select(1, f.receipts.CheckPrompt(p, "GemsSack")), 9002, "configured pack allowed")
		m.policy = "Loading"
		id, message = f.receipts.CheckPrompt(p, "GemsSack")
		equal(id, nil, "policy still loading -> fail closed"); assert(message, "policy toast")
		equal(select(1, f.receipts.CheckPrompt(p, "NotAPack")), nil, "unknown key ignored")
		local future = goldenV2()
		future.dataVersion = 99
		local _, g, q = world(sources, nil, "A", future)
		equal(select(1, g.receipts.CheckPrompt(q, "GemsSack")), nil, "read-only save cannot buy")
	end)

	test("code redeems once: lowercase and spaces normalised, reward atomic, re-entry refused", function()
		local b, f, p = world(sources)
		local profile = f.data.Get(p)
		local gems, gold = profile.gems, profile.gold
		equal(redeem(f, p, "  re lease \n"), "Redeemed", "normalised code")
		equal(profile.gems, gems + 150, "gems"); equal(profile.gold, gold + 2500, "gold"); equal(profile.redeemedCodes.RELEASE, true, "marked")
		equal(redeem(f, p, "RELEASE"), "AlreadyRedeemed", "second use")
		equal(redeem(f, p, "release"), "AlreadyRedeemed", "second use lowercase")
		equal(profile.gems, gems + 150, "no double gems")
		f.finish(f.remove(p))
		equal(b.document.redeemedCodes.RELEASE, true, "persisted")
		local _, g, q = world(sources, b, "B")
		equal(redeem(g, q, "Release"), "AlreadyRedeemed", "refused on another server")
		equal(g.data.Get(q).gems, gems + 150, "still once")
	end)

	test("expired, unknown and malformed codes grant nothing; potion rewards land", function()
		local _, f, p = world(sources)
		f.codesConfig.ByCode.OLDCODE = { code = "OLDCODE", label = "old", reward = { gems = 999 }, expiresAtUtc = 5000 }
		local profile = f.data.Get(p)
		local gems = profile.gems
		equal(redeem(f, p, "oldcode"), "Expired", "expired by UTC clock")
		equal(redeem(f, p, "NOPE"), "Invalid", "unknown"); equal(redeem(f, p, "bad!code"), "Invalid", "symbols")
		equal(redeem(f, p, string.rep("A", 30)), "Invalid", "too long"); equal(redeem(f, p, 42), "Invalid", "not a string")
		equal(profile.gems, gems, "nothing granted"); equal(profile.redeemedCodes.OLDCODE, nil, "expired code not marked")
		equal(redeem(f, p, "sunny"), "Redeemed", "SUNNY before its expiry")
		equal(profile.potions.lucky_elixir_s, 1, "potion granted"); equal(profile.gems, gems + 50, "gems granted")
	end)

	test("code entry is rate limited per player", function()
		local _, f, p = world(sources)
		local first = f.codes.Redeem(p, "NOPE")
		equal(first, "Invalid", "first attempt checked")
		equal(f.codes.Redeem(p, "RELEASE"), "RateLimited", "instant second attempt")
		equal(f.data.Get(p).redeemedCodes.RELEASE, nil, "limited attempt grants nothing")
		local statuses = {}
		for i = 1, 6 do f.advance(2); statuses[i] = f.codes.Redeem(p, "NOPE" .. i) end
		equal(statuses[5], "Invalid", "within window budget"); equal(statuses[6], "RateLimited", "window budget exhausted")
		f.advance(61)
		equal(f.codes.Redeem(p, "RELEASE"), "Redeemed", "allowed after the window")
	end)

	test("read-only profile cannot redeem codes", function()
		local future = goldenV2()
		future.dataVersion = 99
		local b, f, p = world(sources, nil, "A", future)
		equal(redeem(f, p, "RELEASE"), "ReadOnly", "blocked")
		equal(f.data.Get(p).redeemedCodes.RELEASE, nil, "not marked"); equal(b.document.gems, 30, "store untouched")
	end)

	test("version-2 and version-1 saves upgrade to the current schema writable with empty receipts/codes", function()
		local b, f, p = world(sources, nil, "A", goldenV2())
		equal(f.data.CanWritePersistent(p), true, "v2 writable, not quarantined")
		local profile = f.data.Get(p)
		equal(profile.dataVersion, f.config.PROFILE_SCHEMA_VERSION, "upgraded")
		equal(#profile.processedPurchaseIds, 0, "empty receipts"); equal(next(profile.redeemedCodes), nil, "empty codes")
		equal(profile.gold, 4000, "progress kept")
		equal(receipt(f, "M1", 9001), GRANTED, "can buy right after migration")
		f.finish(f.remove(p))
		equal(b.document.dataVersion, f.config.PROFILE_SCHEMA_VERSION, "stored as current version")
		equal(b.document.processedPurchaseIds[1], "M1", "receipt stored")
		-- saveSeq is present: tests/session_fixture.luau compares saveSeq numerically when classifying writes.
		local v1 = { saveSeq = 3, lockTimestamp = 0, gold = 500, gems = 3, rodId = "Twig", ownedRods = { Twig = true }, fishBag = {}, stats = { fishCaught = 2 } }
		local b1, g, q = world(sources, nil, "A", v1)
		equal(g.data.CanWritePersistent(q), true, "v1 (no dataVersion) writable")
		equal(g.data.Get(q).gold, 500, "v1 gold kept"); equal(#g.data.Get(q).processedPurchaseIds, 0, "v1 receipts")
		g.finish(g.remove(q))
		equal(b1.document.dataVersion, g.config.PROFILE_SCHEMA_VERSION, "v1 stored upgraded")
	end)

	test("current-version save: oversized receipt list trimmed, malformed receipt/code fields quarantined", function()
		local doc = goldenV2()
		doc.dataVersion = 3
		doc.processedPurchaseIds, doc.redeemedCodes = {}, { RELEASE = true }
		for i = 1, 70 do doc.processedPurchaseIds[i] = "old" .. i end
		local _, f, p = world(sources, nil, "A", doc)
		equal(f.data.CanWritePersistent(p), true, "writable")
		local ids = f.data.Get(p).processedPurchaseIds
		equal(#ids, 60, "trimmed"); equal(ids[1], "old11", "kept most recent")
		equal(receipt(f, "old70", 9001), GRANTED, "recent id still deduplicated")
		for _, broken in ipairs({ { processedPurchaseIds = { 1, 2 } }, { redeemedCodes = { RELEASE = "yes" } }, { processedPurchaseIds = { [2] = "x" } } }) do
			local bad = goldenV2()
			bad.dataVersion, bad.processedPurchaseIds, bad.redeemedCodes = 3, {}, {}
			for key, value in pairs(broken) do bad[key] = value end
			local b2, g, q = world(sources, nil, "A", bad)
			equal(g.data.CanWritePersistent(q), false, "malformed field quarantined")
			equal(b2.document.saveSeq, 12, "store untouched")
		end
	end)

	test("AnalyticsHelper never crashes: missing service, throwing service, missing Enum", function()
		local missing, player = analytics(sources, nil, nil)
		equal(missing.LogOnboardingStep(player, "JoinedGame"), false, "no service -> false")
		equal(missing.LogEconomySource(player, "Gems", 10, 10, "IAP", "x"), false, "no service economy")
		local throwing = { LogOnboardingFunnelStepEvent = function() error("boom") end, LogEconomyEvent = function() error("boom") end }
		local helper, p2 = analytics(sources, throwing, nil)
		equal(helper.LogOnboardingStep(p2, "FirstCatch"), false, "throwing service contained")
		equal(helper.LogEconomySource(p2, "Gems", 10, 10, "IAP", "x"), false, "missing Enum contained")
		equal(helper.FailureCount(), 2, "failures counted")
		local calls = {}
		local working = { LogOnboardingFunnelStepEvent = function(_, _, step, name) table.insert(calls, step .. ":" .. name) end,
			LogEconomyEvent = function(_, _, flow, currency, amount, _, kind, sku) table.insert(calls, table.concat({ flow, currency, amount, kind, sku }, "|")) end }
		local enum = { AnalyticsEconomyFlowType = { Source = "Source" }, AnalyticsEconomyTransactionType = { IAP = { Name = "IAP" } } }
		local ok, p3 = analytics(sources, working, enum)
		equal(ok.LogOnboardingStep(p3, "FirstCatch"), true, "logged"); equal(ok.LogOnboardingStep(p3, "FirstCatch"), false, "once per session")
		equal(ok.LogOnboardingStep(p3, "NotAStep"), false, "unknown step")
		equal(ok.LogEconomySource(p3, "Gems", 100, 130, "IAP", "GemsPouch"), true, "economy logged")
		equal(calls[1], "2:FirstCatch", "funnel args"); equal(calls[2], "Source|Gems|100|IAP|GemsPouch", "economy args")
		equal(ok.LogEconomySource(p3, "Gems", 0, 130, "IAP"), false, "zero amount skipped")
	end)

	print(string.format("MONETIZATION_SUITE passed=%d failed=%d", passed, failed))
	assert(failed == 0, "dev_products_and_codes suite failed")
end
