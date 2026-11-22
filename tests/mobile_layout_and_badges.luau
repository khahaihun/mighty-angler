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
					-- The open bait dropdown is a transient overlay, not a persistent HUD control.
					if name ~= other and name ~= "QuickBaitPopup" and other ~= "QuickBaitPopup" then
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
			assert(3 * 38 + 2 * 6 <= rects.ToastStack.h, "toast budget escapes stack")
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
	print(string.format("MOBILE_LAYOUT_BADGES_SUITE passed=%d failed=0", passed))
end
