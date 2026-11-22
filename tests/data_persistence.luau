-- Exercise production handlers against the same deterministic RAM store as session_acquisition.
local Fixture = require("./session_fixture")

local function equal(actual, expected, label)
	assert(actual == expected, string.format("%s: expected %s, got %s", label, tostring(expected), tostring(actual)))
end

local function vector(x, y, z)
	return setmetatable({ X = x, Y = y, Z = z, Magnitude = math.sqrt(x*x + y*y + z*z) }, {
		__add = function(a, b) return vector(a.X + b.X, a.Y + b.Y, a.Z + b.Z) end,
	})
end

local function gameplayOptions()
	local function ignoreVisual() end
	return {
		useIslandConfig = true,
		globals = { Vector3 = { new = vector } },
		dependencies = {
			BuffAggregator = {}, PerkService = {}, FishingRoller = {},
			WorldPromptAccess = { IsNear = function() return true end }, -- range is covered by fishing_prompt_grid
			FishingService = { CancelSession = ignoreVisual },
			IslandService = { TeleportCharacterToIsland = ignoreVisual },
			PetsService = { SyncVisualsAndClient = ignoreVisual },
			RodVisuals = { EquipRodOnCharacter = ignoreVisual },
			PetAndFishVisuals = {},
		},
	}
end

return function(sources)
	local passed, failed = 0, 0
	local function test(name, run)
		local ok, err = pcall(run)
		if ok then
			passed += 1
			print("PASS persistence " .. name)
		else
			failed += 1
			print("FAIL persistence " .. name .. ": " .. tostring(err))
		end
	end

	test("competing_sessions", function()
		local b = Fixture.backend()
		local a = Fixture.server(sources, b, "A")
		local other = Fixture.server(sources, b, "B")
		local pA = a.add(101)
		local owner = b.document.activeSessionId
		local pB = other.add(101)
		other.advance(4.5) -- het vong lay khoa dau tien, B o trang thai cho thu lai
		equal(a.data.CanWritePersistent(pA), true, "owner A may write")
		equal(other.data.CanWritePersistent(pB), false, "competing B is locked")
		equal(other.data.Get(pB), nil, "competing B has no blank profile")
		equal(other.data.SaveProfile(pB), "Skipped", "competing save")
		a.data.Get(pA).gold = 937
		equal(a.data.SaveProfile(pA), "Saved", "owner save")
		equal(b.document.activeSessionId, owner, "owner unchanged")
		equal(b.document.gold, 937, "only owner persists")
	end)

	test("transient_final_save_retries", function()
		local b = Fixture.backend()
		local a = Fixture.server(sources, b, "A")
		local p = a.add(101)
		a.data.Get(p).gold = 731
		local attempts = 0
		a.beforeUpdate = function(kind)
			if kind == "release" then
				attempts += 1
				if attempts == 1 then error("injected failure before final write") end
			end
		end
		local removal = a.remove(p)
		equal(attempts, 1, "first final write attempted")
		equal(b.document.gold, 0, "failed write did not commit")
		a.finish(removal)
		equal(attempts, 2, "automatic final-save retry")
		equal(b.document.activeSessionId, nil, "retry released ownership")
		equal(b.document.gold, 731, "retry persisted latest balance")
		equal(b.document.saveSeq, 2, "one final write committed")
	end)

	test("late_save_response_cannot_extend_ownership", function()
		local b = Fixture.backend()
		local a = Fixture.server(sources, b, "A")
		local other = Fixture.server(sources, b, "B")
		local pA = a.add(101)
		a.data.Get(pA).gold = 761
		a.afterUpdate = function(kind)
			if kind == "save" then coroutine.yield("save committed; response held") end
		end
		local saveResult
		local pending = a.spawn(function() saveResult = a.data.SaveProfile(pA) end)
		equal(b.document.gold, 761, "A's save committed before the response")
		equal(coroutine.status(pending), "suspended", "A still awaits response")
		local committedAt = b.document.lockTimestamp
		b.now = committedAt + 100
		a.resume(pending)
		equal(saveResult, "Saved", "late response confirms the original write")
		b.now = committedAt + 121
		local pB, loadB = other.add(101)
		other.finish(loadB)
		equal(other.data.CanWritePersistent(pB), true, "B acquired expired lock")
		equal(other.data.Get(pB).gold, 761, "B loaded A's confirmed save")
		equal(a.data.CanWritePersistent(pA), false, "A must stop transactions once the stored lock expires")
	end)

	test("both_close_paths_wait_for_final_save", function()
		local b = Fixture.backend()
		local a = Fixture.server(sources, b, "A")
		local p = a.add(101)
		a.data.Get(p).gold = 404
		local held
		a.beforeUpdate = function(kind)
			if kind == "release" then held = coroutine.running(); coroutine.yield("final write held") end
		end
		local removal = a.remove(p)
		equal(coroutine.status(removal), "suspended", "PlayerRemoving awaits final save")
		equal(b.document.gold, 0, "final balance is not persisted yet")
		local shutdown = a.spawn(a.bindToClose)
		local shutdownWhilePending = coroutine.status(shutdown)
		a.resume(held)
		a.finish(removal)
		a.finish(shutdown)
		equal(b.document.gold, 404, "final balance persisted")
		equal(b.document.activeSessionId, nil, "final write released ownership")
		equal(b.document.saveSeq, 2, "only one final write")
		equal(shutdownWhilePending, "suspended", "BindToClose must also await the in-flight final save")
	end)

	test("malformed_profile_is_quarantined", function()
		local b = Fixture.backend()
		local a = Fixture.server(sources, b, "A")
		b.document = a.config.CreateDefaultProfile()
		b.document.gold = 801
		b.document.stats.playTimeSec = false
		b.document.fishBag = "invalid bag"
		local p, load = a.add(101)
		a.finish(load)
		local canWrite = a.data.CanWritePersistent(p)
		local saveResult = a.data.SaveProfile(p)
		equal(canWrite, false, string.format("malformed profile must be read-only (save=%s, stored bag type=%s)",
			saveResult, type(b.document.fishBag)))
		equal(b.document.gold, 801, "stored balance untouched")
		equal(b.document.stats.playTimeSec, false, "invalid nested stat preserved for recovery")
		equal(b.document.fishBag, "invalid bag", "invalid stored bag preserved for recovery")
	end)

	test("dev_reset_during_autosave", function()
		local b = Fixture.backend()
		local a = Fixture.server(sources, b, "A", nil, gameplayOptions())
		a.loadModule("DevTestService").Init()
		local p = a.add(101)
		a.data.Get(p).gold = 505
		local autosave
		a.afterUpdate = function(kind)
			if kind == "save" and not autosave then
				autosave = coroutine.running()
				coroutine.yield("autosave committed; response held")
			end
		end
		for _ = 1, 60 do
			b.now += 1
			a.resume(a.periodic)
		end
		assert(autosave and coroutine.status(autosave) == "suspended", "periodic save did not reach the held response")
		equal(b.document.gold, 505, "autosave committed prior balance")
		local reset = a.fireRemote("DevAction", p, "ResetSave")
		a.resume(autosave)
		a.finish(reset)
		equal(b.document.gold, 0, "DEV reset persists the default balance")
		equal(b.document.saveSeq, 3, "reset follows the pending autosave")
		equal(a.data.CanWritePersistent(p), true, "reset keeps write ownership")
		local removal = a.remove(p)
		a.finish(removal)
		local other = Fixture.server(sources, b, "B")
		local rejoin, load = other.add(101)
		other.finish(load)
		equal(other.data.CanWritePersistent(rejoin), true, "rejoin loads the reset profile")
		equal(other.data.Get(rejoin).gold, 0, "reset survives server change")
	end)

	test("bounty_uid_rewards_once_across_rejoin", function()
		local b = Fixture.backend()
		local a = Fixture.server(sources, b, "A", nil, gameplayOptions())
		a.loadModule("EnchantAndBountyService").Init()
		local p = a.add(101)
		local root = { Position = vector(-11, 10, 48.2), IsA = function(_, name) return name == "BasePart" end }
		local character = { FindFirstChild = function(_, name) return if name == "HumanoidRootPart" then root else nil end }
		p.Character = character
		local profile = a.data.Get(p)
		profile.enchantRelics = 3
		profile.fishBag = {
			{ uid = "fish-to-turn-in", fishId = "sunset_barracuda", weight = 18, mutation = "None", sellValue = 99, originalValue = 99, sizeTier = "Normal", locked = false, soulbound = false, midasBonus = 1 },
			{ uid = "fish-to-keep", fishId = "sunset_barracuda", weight = 18, mutation = "None", sellValue = 99, originalValue = 99, sizeTier = "Normal", locked = false, soulbound = false, midasBonus = 1 },
		}
		profile.pinnedFishUids["2"] = "fish-to-turn-in"
		profile.equippedHotbarSlot = 2
		local heldAutosave
		a.afterUpdate = function(kind)
			if kind == "save" then heldAutosave = coroutine.running(); coroutine.yield("pre-bounty autosave held") end
		end
		local autosave = a.spawn(function() return a.data.SaveProfile(p) end)
		local function claim(server, player)
			server.finish(server.fireRemote("TurnInBounty", player, "bounty_sunny_epic", "fish-to-turn-in"))
		end
		local function checkReward(saved, stage)
			equal(saved.gems, 45, stage .. " Gems awarded once")
			equal(saved.enchantRelics, 4, stage .. " exactly one Relic added to the existing three")
			equal(saved.potions.lucky_elixir_s, 1, stage .. " potion awarded once")
			equal(#saved.fishBag, 1, stage .. " only one fish removed")
			equal(saved.fishBag[1].uid, "fish-to-keep", stage .. " other eligible fish kept")
			equal(saved.pinnedFishUids["2"], nil, stage .. " consumed fish unpinned")
		end
		claim(a, p)
		checkReward(profile, "first request")
		claim(a, p)
		checkReward(profile, "duplicate request")
		local heldRead
		a.afterUpdate = function(kind) if kind == "release" then error("bounty final acknowledgement lost") end end
		a.beforeRead = function() heldRead = coroutine.running(); coroutine.yield("bounty verification held") end
		local removal = a.remove(p)
		local shutdown = a.spawn(a.bindToClose)
		equal(coroutine.status(shutdown), "suspended", "shutdown waits for bounty close")
		a.resume(heldAutosave); a.finish(autosave)
		a.advance(0.1)
		assert(heldRead, "final bounty write must reach confirmation read")
		a.beforeRead = nil
		a.resume(heldRead)
		a.finish(removal); a.finish(shutdown)
		equal(a.results[removal], "Saved", "bounty final write confirmed despite lost response")
		equal(b.document.saveSeq, 3, "autosave then one final bounty snapshot")
		checkReward(b.document, "saved at departure")
		local other = Fixture.server(sources, b, "B", nil, gameplayOptions())
		other.loadModule("EnchantAndBountyService").Init()
		local rejoin, load = other.add(101)
		other.finish(load)
		equal(other.data.CanWritePersistent(rejoin), true, "B is writable before retry")
		rejoin.Character = character
		claim(other, rejoin)
		checkReward(other.data.Get(rejoin), "duplicate after rejoin")
	end)

	print(string.format("PERSISTENCE_SUITE passed=%d failed=%d", passed, failed))
	assert(failed == 0, "data persistence suite failed")
end
