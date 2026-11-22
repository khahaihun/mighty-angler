-- Chay PerkService + GamepassOwnership that voi MarketplaceService/Players/dong ho gia lap.
-- Chi kiem logic cap quyen; khong chung minh hanh vi mang hay cache cua Roblox Engine that.
return function(sources)
	local passed, failed = 0, 0

	local function build(options)
		local f = { now = 0, calls = {}, toasts = {}, pushes = 0, unlocked = {}, warnings = {}, groupCalls = 0 }
		local due, active = {}, {}
		local function resume(thread, ...)
			local ok, result = coroutine.resume(thread, ...)
			assert(ok, tostring(result))
			due[thread] = if coroutine.status(thread) == "dead" then nil else f.now + (tonumber(result) or 0)
		end
		local function spawn(fn, ...)
			local thread = coroutine.create(fn)
			resume(thread, ...)
			return thread
		end
		function f.advance(seconds)
			local target = f.now + seconds
			for _ = 1, 5000 do
				local thread, at
				for candidate, time in pairs(due) do
					if at == nil or time < at then thread, at = candidate, time end
				end
				if not thread or at > target then f.now = target; return end
				f.now = math.max(f.now, at)
				resume(thread)
			end
			error("scheduler exceeded bounded steps")
		end
		local function signal()
			local callback
			return { Connect = function(_, fn) callback = fn end, Fire = function(_, ...) return spawn(callback, ...) end }
		end
		local players = { PlayerAdded = signal(), PlayerRemoving = signal() }
		function players:GetPlayers() return {} end
		f.players = players
		f.owned, f.apiError, f.groupError, f.inGroup = {}, false, false, false
		local marketplace = { PromptGamePassPurchaseFinished = signal() }
		function marketplace:UserOwnsGamePassAsync(userId, passId)
			table.insert(f.calls, { userId = userId, passId = passId, at = f.now })
			assert(passId > 0, "must never ask Roblox about an unconfigured pass")
			if f.apiError then error("HTTP 503") end
			return f.owned[passId] == true
		end
		f.marketplace = marketplace
		local services = {
			MarketplaceService = marketplace, Players = players,
			PolicyService = { GetPolicyInfoForPlayerAsync = function() return { ArePaidRandomItemsRestricted = false } end },
			RunService = { IsStudio = function() return false end },
			ReplicatedStorage = { WaitForChild = function() return { WaitForChild = function(_, name)
				if name == "Config" then return { WaitForChild = function(_, child) return { Name = child } end } end
				return { Name = name }
			end } end },
		}
		local list = {}
		for index, key in ipairs({ "AutoFish", "DoubleGold", "DoubleStrength", "ExtraPets", "ExclusiveDragonRod" }) do
			list[index] = { key = key, id = if options.configured then 100 + index else 0, name = key }
		end
		local byKey = {}
		for _, gp in ipairs(list) do byKey[gp.key] = gp end
		f.profile = { ownedRods = {} }
		local cache = {
			GamepassesConfig = { List = list, ByKey = byKey },
			GameConfig = { ROBLOX_GROUP_ID = 777, DEV_UNLOCK_PERKS_IN_STUDIO = true },
			Net = { ServerToClient = { Toast = "Toast", PerksUpdated = "Perks" },
				ClientToServer = { RequestInitialState = "Init", PromptGamepass = "Prompt" },
				OnServerEvent = function() end,
				FireClient = function(player, event, payload)
					assert(active[player], "must not message a player who left")
					if event == "Toast" then table.insert(f.toasts, payload) else f.pushes += 1; f.lastPerks = payload end
				end },
			DataService = { Get = function() return f.profile end, MarkDirty = function() end, OnProfileLoaded = function() end },
		}
		local testOs = table.clone(os)
		testOs.clock = function() return f.now end
		local env
		local function load(name)
			if cache[name] == nil then
				local chunk = assert(loadstring(assert(sources[name], name), "@" .. name))
				setfenv(chunk, setmetatable({ script = { Parent = setmetatable({}, { __index = function(_, key) return { Name = key } end }) } }, { __index = env }))
				cache[name] = chunk()
			end
			return cache[name]
		end
		env = setmetatable({ os = testOs,
			game = { GetService = function(_, name) return assert(services[name], name) end },
			task = { wait = function(seconds) return coroutine.yield(seconds or 0) end, spawn = spawn },
			warn = function(...) table.insert(f.warnings, table.concat({ ... }, " ")) end,
			require = function(ref) return load(ref.Name) end,
		}, { __index = _G })
		f.perks = load("PerkService")
		f.perks.OnGamepassUnlocked(function(_, key) table.insert(f.unlocked, key) end)
		f.perks.Init()
		function f.join(userId)
			local player = { UserId = userId }
			function player:IsDescendantOf(parent) return parent == players and active[self] == true end
			function player:IsInGroupAsync(groupId)
				assert(groupId == 777)
				f.groupCalls += 1
				if f.groupError then error("HTTP 503") end
				return f.inGroup
			end
			active[player] = true
			players.PlayerAdded:Fire(player)
			return player
		end
		function f.leave(player)
			active[player] = nil
			players.PlayerRemoving:Fire(player)
		end
		function f.signalPurchase(player, passId, wasPurchased)
			marketplace.PromptGamePassPurchaseFinished:Fire(player, passId, wasPurchased)
		end
		function f.ownedKeys(player)
			local keys = {}
			for _, gp in ipairs(list) do
				if f.perks.HasGamepass(player, gp.key) then table.insert(keys, gp.key) end
			end
			return table.concat(keys, ",")
		end
		return f
	end

	local function case(name, options, body)
		local ok, err = pcall(function() body(build(options)) end)
		if ok then passed += 1; print("PASS " .. name) else failed += 1; print("FAIL " .. name .. ": " .. tostring(err)) end
	end

	case("forged_signal_with_id_0_grants_nothing_while_passes_unconfigured", { configured = false }, function(f)
		local player = f.join(1)
		f.advance(600)
		for _, id in ipairs({ 0, -1, 101 }) do f.signalPurchase(player, id, true) end
		f.advance(600)
		assert(f.ownedKeys(player) == "", "granted: " .. f.ownedKeys(player))
		assert(#f.calls == 0 and #f.unlocked == 0 and #f.toasts == 0)
	end)

	case("forged_signal_for_real_pass_is_rejected_by_roblox_ownership", { configured = true }, function(f)
		local player = f.join(1)
		f.advance(5)
		local before = #f.calls
		for _ = 1, 50 do f.signalPurchase(player, 105, true) end
		f.advance(1200)
		assert(f.ownedKeys(player) == "" and #f.unlocked == 0 and not f.profile.ownedRods.SeraphimDragon)
		assert(#f.calls - before <= 1 + 6, "spam must not multiply ownership queries: " .. (#f.calls - before))
		for _, toast in ipairs(f.toasts) do assert(toast.kind ~= "Success", "no unlock toast for unconfirmed purchase") end
	end)

	case("cancelled_prompt_is_ignored", { configured = true }, function(f)
		local player = f.join(1)
		f.advance(5)
		local before = #f.calls
		f.owned[101] = true
		f.signalPurchase(player, 101, false)
		f.advance(5)
		assert(#f.calls == before and f.ownedKeys(player) == "")
	end)

	case("confirmed_purchase_unlocks_once", { configured = true }, function(f)
		local player = f.join(1)
		f.advance(5)
		f.owned[105] = true
		f.signalPurchase(player, 105, true)
		f.signalPurchase(player, 105, true)
		f.advance(5)
		assert(f.ownedKeys(player) == "ExclusiveDragonRod" and f.profile.ownedRods.SeraphimDragon == true)
		local success = 0
		for _, toast in ipairs(f.toasts) do if toast.kind == "Success" then success += 1 end end
		assert(success == 1, "one unlock toast, got " .. success)
	end)

	case("purchase_during_roblox_outage_unlocks_when_api_recovers", { configured = true }, function(f)
		local player = f.join(1)
		f.advance(600)
		f.apiError, f.owned[102] = true, true
		f.signalPurchase(player, 102, true)
		f.advance(10)
		assert(f.ownedKeys(player) == "", "API error must never be read as owned")
		f.apiError = false
		f.advance(60)
		assert(f.ownedKeys(player) == "DoubleGold" and f.unlocked[1] == "DoubleGold")
	end)

	case("owner_joining_during_outage_gets_pass_back_without_rejoin", { configured = true }, function(f)
		f.apiError, f.owned[101], f.owned[104] = true, true, true
		local player = f.join(1)
		f.advance(40)
		assert(f.ownedKeys(player) == "", "API error must never be read as owned")
		f.apiError = false
		f.advance(120)
		assert(f.ownedKeys(player) == "AutoFish,ExtraPets", f.ownedKeys(player))
		local snapshot = f.perks.GetPerkSnapshot(player)
		assert(snapshot.autoFish and snapshot.extraPets and not snapshot.doubleGold)
	end)

	case("leaving_mid_verification_sends_nothing_and_stops_retrying", { configured = true }, function(f)
		f.apiError = true
		local player = f.join(1)
		f.signalPurchase(player, 101, true)
		f.advance(1)
		f.leave(player)
		f.apiError, f.owned[101] = false, true
		local before = #f.calls
		f.advance(1200)
		assert(#f.calls == before, "no ownership queries after leave")
		assert(f.ownedKeys(player) == "")
	end)

	case("group_api_error_is_retried_not_remembered", { configured = true }, function(f)
		f.groupError, f.inGroup = true, true
		local player = f.join(1)
		f.advance(5)
		assert(not f.perks.CanAutoTrain(player) and not f.perks.CanAutoTrain(player))
		assert(f.groupCalls == 1, "failed lookups are throttled, got " .. f.groupCalls)
		assert(f.lastPerks.canAutoTrain == false, "client was told Auto-Train is locked during outage")
		f.groupError = false
		f.advance(31)
		assert(f.perks.CanAutoTrain(player), "member regains Auto-Train after API recovers")
		assert(f.lastPerks.canAutoTrain == true, "client is told as soon as the server grants Auto-Train")
		local settled = f.groupCalls
		assert(f.perks.CanAutoTrain(player) and f.groupCalls == settled, "confirmed answer is cached")
	end)

	print(string.format("GAMEPASS_SUITE passed=%d failed=%d", passed, failed))
	if failed > 0 then error("gamepass ownership suite failed") end
end
