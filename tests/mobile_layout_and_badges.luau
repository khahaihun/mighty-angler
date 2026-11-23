return function(sources)
	local passed = 0
	local function load(path, env)
		local run = assert(loadstring(assert(sources[path]), "@" .. path))
		setfenv(run, setmetatable(env or {}, { __index = getfenv() }))
		return run()
	end
	local Window = load("UI/Components/WindowFrame.luau", {
		script = { Parent = { Parent = { Theme = {} } } }, require = function() return {} end,
	})
	local Scale = load("UI/ResponsiveScale.luau")
	local function test(name, fn)
		fn()
		passed += 1
		print("PASS mobile " .. name)
	end
	local function overlaps(a, b)
		return a.x < b.x + b.w - 1e-6 and b.x < a.x + a.w - 1e-6
			and a.y < b.y + b.h - 1e-6 and b.y < a.y + a.h - 1e-6
	end
	for _, screen in ipairs({
		{ 667, 375, { 0, 58, 0, 0 } },
		{ 844, 390, { 47, 58, 47, 21 } },
		{ 1024, 768, { 0, 58, 0, 20 } },
		{ 1920, 1080, { 0, 58, 0, 0 } },
	}) do
		test(screen[1] .. "x" .. screen[2] .. "_safe_bounds_and_coexistence", function()
			local i = screen[3]
			local uw, uh = screen[1] - i[1] - i[3], screen[2] - i[2] - i[4]
			local s = Scale.Compute(uw, uh)
			local rects = Window.ComputeLayout(uw / s, uh / s)
			local physical = Window.ComputeLayout(screen[1] / s, screen[2] / s, { i[1] / s, i[2] / s, i[3] / s, i[4] / s })
			for name, r in pairs(rects) do
				assert(r.x >= 0 and r.y >= 0 and r.w > 0 and r.h > 0, name .. " invalid bounds")
				assert((r.x + r.w) * s <= uw + 1e-6 and (r.y + r.h) * s <= uh + 1e-6, name .. " outside safe area")
				assert(math.abs(physical[name].x * s - r.x * s - i[1]) < 1e-6, name .. " left inset counted twice")
				assert(math.abs(physical[name].y * s - r.y * s - i[2]) < 1e-6, name .. " top inset counted twice")
				for other, b in pairs(rects) do
					-- Modals and the bait dropdown may cover the HUD underneath.
					if name ~= other and name ~= "Window" and other ~= "Window" and name ~= "QuickBaitPopup" and other ~= "QuickBaitPopup" then
						assert(not overlaps(r, b), name .. " overlaps " .. other)
					end
				end
			end
			-- Check the actual children, not only their dock's bounding box.
			local dock = rects.LeftMenuDock
			assert(7 * 42 + 6 * 7 <= dock.h, "navigation buttons escape dock")
			local hotbar = rects.CustomHotbar
			assert(5 * 90 + 4 * 8 <= hotbar.w and 62 <= hotbar.h, "slots escape hotbar")
			assert(172 + 196 + 108 + 16 <= rects.AboveHotbarAutoRow.w, "auto buttons escape row")
			assert(rects.Window.h - 112 >= 240, "modal body cannot show cards")
			assert(3 * 48 + 2 * 6 <= rects.ToastStack.h, "toast budget escapes stack")
			assert(rects.ToastStack.w == math.min(440, uw / s - 384), "toast width is not flexible")
			print(string.format("LAYOUT %dx%d scale=%.4f Window.h=%.1f body=%.1f ToastStack=(%.1f,%.1f,%.1f,%.1f)", screen[1], screen[2], s,
				rects.Window.h, rects.Window.h - 112, rects.ToastStack.x, rects.ToastStack.y, rects.ToastStack.w, rects.ToastStack.h))
		end)
	end
	test("old_tutorial_would_cover_auto_buttons", function()
		local w, h = 667 / Scale.Compute(667, 317), 317 / Scale.Compute(667, 317)
		local old = { x = (w - 600) / 2, y = h - 150, w = 600, h = 28 }
		local oldAuto = { x = (w - 520) / 2, y = h - 118, w = 520, h = 36 }
		-- Old tutorial also intersects the cast-charge bar (h-164 .. h-138).
		assert(overlaps(old, { x = (w - 310) / 2, y = h - 164, w = 310, h = 26 }))
		assert(not overlaps(Window.ComputeLayout(w, h).OnboardingHint, oldAuto))
	end)
	test("empty_viewport_is_not_laid_out", function()
		assert(next(Window.ComputeLayout(0, 0)) == nil)
		assert(next(Window.ComputeLayout(-1, 375)) == nil)
	end)
	test("modules_use_live_safe_area_bindings_and_width_constraints", function()
		local hud, fxSource = sources["UI/Panels/HudPanel.luau"], sources["Controllers/SoundAndFxController.luau"]
		assert(hud:find("evLbl.TextWrapped = true", 1, true))
		assert(hud:find("islTag.TextTruncate = Enum.TextTruncate.AtEnd", 1, true))
		assert(fxSource:find("lbl.TextWrapped = true", 1, true))
		assert(fxSource:find("Theme.FitText(lbl, 15, 13)", 1, true))
		for _, path in ipairs({ "Controllers/TutorialController.luau", "Controllers/SoundAndFxController.luau" }) do
			assert(sources[path]:find('Instance.new("UISizeConstraint")', 1, true))
			assert(sources[path]:find("UDim2.new(1, 0, 1, 0)", 1, true))
			assert(sources[path]:find("WindowFrame.BindLayout", 1, true))
		end
		local source = sources["UI/Components/WindowFrame.luau"]
		assert(source:find("created.ScreenInsets = gui.ScreenInsets", 1, true))
		assert(source:find("created.IgnoreGuiInset = gui.IgnoreGuiInset", 1, true))
		assert(source:find('GetPropertyChangedSignal("Scale")', 1, true))
		assert(source:find('GetPropertyChangedSignal("AbsoluteSize")', 1, true))
	end)
	local function node(name)
		return setmetatable({ Name = name, WaitForChild = function(self, key) return self[key] end }, {
			__index = function(_, key) return node(key) end,
		})
	end
	local handlers, instances, cache = {}, {}, {}
	local names = setmetatable({}, { __index = function(_, key) return key end })
	local function tuple(...) return { ... } end
	local env = {
		script = node("NotificationBadge"),
		game = { GetService = function() return node("Service") end },
		Color3 = { fromRGB = tuple, new = tuple }, Vector3 = { new = tuple },
		Vector2 = { new = tuple }, UDim = { new = tuple }, UDim2 = { new = tuple, fromOffset = tuple },
		Enum = setmetatable({}, { __index = function() return names end }),
		Instance = { new = function(class)
			local item = { ClassName = class }; table.insert(instances, item); return item
		end },
	}
	cache.Net = { ServerToClient = names, OnClientEvent = function(event, callback) handlers[event] = callback end }
	local function dependency(module)
		local name = module.Name
		if cache[name] then return cache[name] end
		local path = "shared/Config/" .. name .. ".luau"
		if name == "Types" or name == "Util" then path = "shared/" .. name .. ".luau" end
		if name == "Islands" then path = "shared/Config/Islands/init.luau"
		elseif name:match("^Island%d_") then path = "shared/Config/Islands/" .. name .. ".luau" end
		local childEnv = table.clone(env)
		childEnv.script = node(name)
		childEnv.require = dependency
		cache[name] = load(path, childEnv)
		return cache[name]
	end
	env.require = dependency
	local Badge = load("UI/Components/NotificationBadge.luau", env)
	local gifts, quests = cache.GameConfig.PlaytimeGifts, cache.AchievementsConfig.DailyQuests
	local rods, islands = cache.RodsConfig.NormalList, cache.Islands.List
	test("badge_empty_and_malformed_event_boundaries", function()
		assert(not Badge.Playtime(nil) and not Badge.Progress(nil, 10) and not Badge.Shop(nil) and not Badge.Islands(nil))
		assert(not Badge.Playtime({}) and not Badge.Progress({}, 10) and not Badge.Shop({}) and not Badge.Islands({}))
		Badge.Init(); Badge.Init()
		handlers.StateSnapshot(false); handlers.CurrencyUpdated(false)
	end)
	test("playtime_exact_boundary_and_claimed", function()
		for _, gift in ipairs(gifts) do
			local claimed = {}
			for _, other in ipairs(gifts) do claimed[tostring(other.slot)] = true end
			claimed[tostring(gift.slot)] = nil
			local state = { playtimeTodaySec = gift.reqSec - 1, playtimeClaimedToday = claimed }
			assert(not Badge.Playtime(state))
			state.playtimeTodaySec = gift.reqSec; assert(Badge.Playtime(state))
			claimed[tostring(gift.slot)] = true; assert(not Badge.Playtime(state))
		end
	end)
	test("progress_daily_quest_and_rebirth_boundaries", function()
		assert(Badge.Progress({ canClaimDaily = true }, 10))
		assert(not Badge.Progress({ canClaimDaily = false, lastDailyClaimDay = 9 }, 10))
		assert(Badge.Progress({ lastDailyClaimDay = 9 }, 10))
		assert(not Badge.Progress({ lastDailyClaimDay = 10 }, 10))
		for _, q in ipairs(quests) do
			local entry = { progress = q.target - 1, claimed = false }
			local state = { dailyQuests = { [q.id] = entry }, questDay = 10 }
			assert(not Badge.Progress(state, 10))
			entry.progress = q.target; assert(Badge.Progress(state, 10))
			state.questDay = 9; assert(not Badge.Progress(state, 10)); state.questDay = 10
			entry.claimed = true; assert(not Badge.Progress(state, 10))
		end
		for rebirths = 0, 3 do
			local req = cache.RebirthConfig.GetStrengthRequirement(rebirths)
			assert(not Badge.Progress({ rebirths = rebirths, strength = req - 1 }, 10))
			assert(Badge.Progress({ rebirths = rebirths, strength = req }, 10))
		end
	end)
	test("next_island_affordability_and_all_unlocked", function()
		local owned = { ["1"] = true }
		for n = 2, #islands do
			local state = { unlockedIslands = owned, gold = islands[n].unlockCostGold - 1 }
			assert(not Badge.Islands(state)); state.gold += 1; assert(Badge.Islands(state))
			owned[tostring(islands[n].id)] = true
		end
		assert(not Badge.Islands({ unlockedIslands = owned, gold = math.huge }))
	end)
	test("next_regular_rod_requires_both_gold_and_strength", function()
		local owned = { [rods[1].id] = true }
		for n = 2, #rods do
			local rod = rods[n]
			local state = { ownedRods = owned, gold = rod.priceGold, strength = rod.strengthReq - 1 }
			assert(not Badge.Shop(state)); state.strength += 1; assert(Badge.Shop(state))
			state.gold -= 1; assert(not Badge.Shop(state)); owned[rod.id] = true
		end
		assert(not Badge.Shop({ ownedRods = owned, gold = math.huge, strength = math.huge }))
	end)
	test("badge_attachment_and_visible_toggle_on_live_events", function()
		local dot = Badge.Attach({ ZIndex = 5 })
		assert(dot.ZIndex == 7 and not dot.Visible and dot.Size[1] == 10 and dot.Position[1] == 1)
		Badge.Update(dot, "Gifts", { playtimeTodaySec = gifts[1].reqSec }, 10); assert(dot.Visible)
		Badge.Update(dot, "Gifts", { playtimeTodaySec = gifts[1].reqSec, playtimeClaimedToday = { [tostring(gifts[1].slot)] = true } }, 10)
		assert(not dot.Visible)
		local buttons = { Gifts = {}, Progress = {}, Islands = {}, Shop = {} }
		for key in pairs(buttons) do
			local button = { ZIndex = 2 }; Badge.AttachToHud(button, key)
			for _, item in ipairs(instances) do if item.Parent == button then buttons[key] = item end end
		end
		handlers.StateSnapshot({ profile = { gold = rods[2].priceGold, strength = rods[2].strengthReq, ownedRods = { [rods[1].id] = true } } })
		assert(buttons.Shop.Visible)
		handlers.InventoryUpdated({ ownedRods = { [rods[1].id] = true, [rods[2].id] = true } }); assert(not buttons.Shop.Visible)
		handlers.PlaytimeUpdated({ playtimeTodaySec = gifts[1].reqSec }); assert(buttons.Gifts.Visible)
		handlers.PlaytimeUpdated({ playtimeClaimedToday = { [tostring(gifts[1].slot)] = true } }); assert(not buttons.Gifts.Visible)
		handlers.ProgressionUpdated({ canClaimDaily = true }); assert(buttons.Progress.Visible)
		handlers.ProgressionUpdated({ canClaimDaily = false }); assert(not buttons.Progress.Visible)
		handlers.IslandChanged({ unlockedIslands = { ["1"] = true } })
		handlers.CurrencyUpdated({ gold = islands[2].unlockCostGold }); assert(buttons.Islands.Visible)
		handlers.CurrencyUpdated({ gold = 0 }); assert(not buttons.Islands.Visible)
		handlers.StateSnapshot({ profile = {} }); assert(not buttons.Shop.Visible and not buttons.Gifts.Visible)
	end)
	local rays = {
		{ Enabled = true, IsA = function(_, class) return class == "SunRaysEffect" end },
		{ Enabled = false, IsA = function(_, class) return class == "SunRaysEffect" end },
		{ Enabled = true, IsA = function() return false end },
	}
	local clouds = { Density = 0.8, Cover = 0.6, Enabled = true }
	local lighting = { GetDescendants = function() return rays end, FindFirstChild = function() return nil end }
	local terrain = { FindFirstChildOfClass = function() return clouds end }
	local particleUpdates = 0
	local fx = load("Controllers/SoundAndFxController.luau", {
		script = node("SoundAndFxController"),
		game = { GetService = function(_, name)
			if name == "Lighting" then return lighting end
			if name == "Workspace" then return { Terrain = terrain } end
			return node(name)
		end },
		require = function(module)
			if module.Name == "ParticleBudgetController" then return { Update = function() particleUpdates += 1 end } end
			return {}
		end,
	})
	test("low_gfx_all_sunrays_and_clouds_restore_originals", function()
		fx.SetClientPrefs(false, false)
		assert(rays[1].Enabled and not rays[2].Enabled and clouds.Density == 0.8)
		fx.SetClientPrefs(false, true)
		assert(fx.IsLowGfx() and not rays[1].Enabled and not rays[2].Enabled and rays[3].Enabled)
		assert(clouds.Enabled and clouds.Density == 0.2 and clouds.Cover == 0.3)
		fx.SetClientPrefs(true, true)
		assert(clouds.Density == 0.2 and clouds.Cover == 0.3, "repeated ON must not compound reduction")
		fx.SetClientPrefs(false, false)
		assert(not fx.IsLowGfx() and lighting.GlobalShadows and rays[1].Enabled and not rays[2].Enabled)
		assert(clouds.Density == 0.8 and clouds.Cover == 0.6 and clouds.Enabled)
		clouds.Density, clouds.Cover, clouds.Enabled = 0.4, 0.2, false
		fx.SetClientPrefs(false, true); fx.SetClientPrefs(false, false)
		assert(clouds.Density == 0.4 and clouds.Cover == 0.2 and not clouds.Enabled, "next cycle must capture fresh originals")
		assert(particleUpdates == 6)
	end)
	test("low_gfx_empty_lighting_and_missing_clouds", function()
		table.clear(rays); clouds = nil
		fx.SetClientPrefs(false, true); fx.SetClientPrefs(false, false)
		assert(not fx.IsLowGfx())
	end)
	local pets = load("Controllers/ClientPetRenderer.luau", {
		script = node("ClientPetRenderer"),
		game = { GetService = function() return node("Service") end },
		require = function() return {} end,
		Vector3 = { new = tuple },
	})
	test("pet_distance_and_time_policy_local_near_far_on_off", function()
		for _, low in ipairs({ false, true }) do
			for _, distance in ipairs({ 0, 60, 90, 160, 1000 }) do
				local visible, interval = pets.RenderPolicy(true, low, distance)
				assert(visible and interval == 0, "local pets must stay unaffected")
			end
		end
		local visible, interval = pets.RenderPolicy(false, true, 60)
		assert(visible and interval == 1 / 30)
		visible, interval = pets.RenderPolicy(false, true, 90)
		assert(visible and interval == 0.2)
		assert(not pets.RenderPolicy(false, true, 90.01))
		visible, interval = pets.RenderPolicy(false, false, 90.01)
		assert(visible and interval == 1 / 15, "OFF restores normal range and cadence")
		visible, interval = pets.RenderPolicy(false, false, 85)
		assert(visible and interval == 0)
		assert(pets.RenderPolicy(false, false, 160) and not pets.RenderPolicy(false, false, 160.01))
		assert(pets.ShouldUpdate(1, nil, 0.2))
		assert(not pets.ShouldUpdate(1.1, 1, 0.2))
		assert(pets.ShouldUpdate(1.25, 1, 0.2))
		assert(pets.ShouldUpdate(1, 1, 0))
	end)
	print(string.format("MOBILE_LAYOUT_BADGES_SUITE passed=%d failed=0", passed))
end
