-- Buoc 7: ti le UI theo man hinh, co chu toi thieu, mau nen va chuyen sac.
-- Chay ma that cua ResponsiveScale va Theme; Instance, Color3, ColorSequence la gia lap.
-- Khong chung minh hinh anh that tren Roblox: can mo Studio (Device Emulator) va dien thoai that.
return function(sources)
	local passed, failed = 0, 0
	local function test(name, fn)
		local ok, err = pcall(fn)
		if ok then passed += 1; print("PASS ui " .. name) else failed += 1; print("FAIL ui " .. name .. ": " .. tostring(err)) end
	end
	local function load(path, env)
		local run = assert(loadstring(assert(sources[path], "missing source " .. path), "@" .. path))
		setfenv(run, setmetatable(env or {}, { __index = getfenv() }))
		return run()
	end

	local Scale = load("UI/ResponsiveScale.luau")
	local WINDOW_W, WINDOW_H = 650, 465 -- cua so lon nhat trong game
	local HUD_W, HUD_H = 1072, 480 -- khung nho nhat de HUD khong de len nhau

	-- Vung dung duoc = man hinh ngang tru thanh Roblox phia tren (58 px).
	local phones = {
		{ "iPhone SE", 667, 375 - 58 }, { "iPhone 14", 844, 390 - 58 }, { "iPhone Pro Max", 932, 430 - 58 },
		{ "Android 915x412", 915, 412 - 58 }, { "Android 800x360", 800, 360 - 58 },
	}

	test("phones_in_landscape_fit_every_window_and_keep_the_hud_from_overlapping", function()
		for _, p in ipairs(phones) do
			local s = Scale.Compute(p[2], p[3])
			assert(WINDOW_W * s <= p[2] and WINDOW_H * s <= p[3], p[1] .. ": window overflows the screen")
			assert(p[2] / s >= HUD_W - 0.5 and p[3] / s >= HUD_H - 0.5, p[1] .. ": HUD canvas too small")
		end
	end)

	test("typical_phones_get_bigger_ui_than_the_old_formula_and_none_get_smaller", function()
		local grew = 0
		for _, p in ipairs(phones) do
			local old = math.clamp(math.min(p[2] / 1180, (p[3] + 58) / 680), 0.62, 1.08)
			local new = Scale.Compute(p[2], p[3])
			assert(new >= old - 1e-6, p[1] .. ": UI got smaller")
			if new > old + 0.02 then grew += 1 end
		end
		assert(grew >= 3, "expected most phones to gain readable size, got " .. grew)
	end)

	test("desktop_and_tablet_keep_their_old_scale", function()
		assert(Scale.Compute(1920, 1080 - 58) == Scale.MAX_SCALE, "1080p should stay at the cap")
		assert(Scale.Compute(1366, 768 - 58) == Scale.MAX_SCALE, "laptop should stay at the cap")
		assert(math.abs(Scale.Compute(1024, 768 - 58) - 1024 / 1180) < 1e-6, "tablet stays width-limited")
	end)

	test("very_short_or_narrow_screens_shrink_instead_of_overflowing", function()
		for _, size in ipairs({ { 800, 260 }, { 390, 780 }, { 500, 280 }, { 360, 640 } }) do
			local s = Scale.Compute(size[1], size[2])
			assert(s >= Scale.HARD_MIN_SCALE, "scale below hard minimum")
			if s > Scale.HARD_MIN_SCALE then
				assert(WINDOW_W * s <= size[1] and WINDOW_H * s <= size[2], size[1] .. "x" .. size[2] .. ": window overflows")
			end
		end
		assert(Scale.Compute(800, 260) < Scale.MIN_WIDTH_SCALE, "short screen must go below the width floor")
		assert(Scale.Compute(0, 0) == 1, "unknown screen size falls back to 1")
	end)

	test("bigger_screen_never_gives_smaller_ui", function()
		for w = 400, 2000, 100 do
			for h = 250, 1100, 50 do
				assert(Scale.Compute(w + 100, h) >= Scale.Compute(w, h) - 1e-9, "not monotonic in width")
				assert(Scale.Compute(w, h + 50) >= Scale.Compute(w, h) - 1e-9, "not monotonic in height")
			end
		end
	end)

	-- Theme that, Instance gia lap ghi lai thuoc tinh va con.
	local function instance(class)
		local item = { ClassName = class, children = {} }
		local signal = { Connect = function() return {} end }
		return setmetatable(item, {
			__index = function(_, key)
				if key == "FindFirstChildOfClass" then
					return function(self, wanted)
						for _, c in ipairs(self.children) do if c.ClassName == wanted then return c end end
						return nil
					end
				end
				if key == "MouseEnter" or key == "MouseLeave" or key == "MouseButton1Down" or key == "MouseButton1Up" or key == "Activated" then return signal end
				return nil
			end,
			__newindex = function(self, key, value)
				rawset(self, key, value)
				if key == "Parent" and type(value) == "table" and value.children then table.insert(value.children, self) end
			end,
		})
	end
	local names = setmetatable({}, { __index = function(_, k) return k end })
	local Theme = load("UI/Theme.luau", {
		game = { GetService = function() return {} end },
		Instance = { new = instance },
		Color3 = { fromRGB = function(r, g, b) return { r = r, g = g, b = b } end },
		ColorSequence = { new = function(a, b) return { top = a, bottom = b } end },
		UDim = { new = function(s, o) return { s, o } end },
		Enum = setmetatable({}, { __index = function() return names end }),
	})
	local function childOf(parent, class)
		for _, c in ipairs(parent.children) do if c.ClassName == class then return c end end
		return nil
	end

	local function luminance(c)
		local function lin(v) v /= 255; return if v <= 0.03928 then v / 12.92 else ((v + 0.055) / 1.055) ^ 2.4 end
		return 0.2126 * lin(c.r) + 0.7152 * lin(c.g) + 0.0722 * lin(c.b)
	end
	local function contrast(a, b)
		local la, lb = luminance(a), luminance(b)
		if la < lb then la, lb = lb, la end
		return (la + 0.05) / (lb + 0.05)
	end

	test("text_stays_readable_on_the_brighter_panels", function()
		for _, bg in ipairs({ "PanelBg", "PanelInner", "CardBg", "CardOwned" }) do
			for _, fg in ipairs({ "TextPrimary", "TextMuted" }) do
				local ratio = contrast(Theme.Colors[fg], Theme.Colors[bg])
				assert(ratio >= 4.5, string.format("%s on %s contrast %.2f < 4.5", fg, bg, ratio))
			end
		end
		-- Nen moi phai sang hon nen cu (24,32,52 / 34,45,72 / 42,56,88).
		assert(luminance(Theme.Colors.PanelBg) > luminance({ r = 24, g = 32, b = 52 }), "PanelBg not brighter")
		assert(luminance(Theme.Colors.PanelInner) > luminance({ r = 34, g = 45, b = 72 }), "PanelInner not brighter")
		assert(luminance(Theme.Colors.CardBg) > luminance({ r = 42, g = 56, b = 88 }), "CardBg not brighter")
	end)

	test("gradient_is_vertical_keeps_the_base_colour_on_top_and_only_darkens_below", function()
		local frame = instance("Frame")
		local g = Theme.AddGradient(frame)
		assert(g.ClassName == "UIGradient" and g.Parent == frame, "UIGradient not parented")
		assert(g.Rotation == 90, "gradient must run top to bottom")
		assert(g.Color.top.r == 255 and g.Color.top.g == 255 and g.Color.top.b == 255, "top must keep the base colour")
		assert(luminance(g.Color.bottom) < 1 and luminance(g.Color.bottom) > 0.5, "bottom should be a gentle shade")
		local btn = Theme.CreateButton(instance("Frame"), "B", "OK", {}, {}, { r = 1, g = 2, b = 3 }, nil)
		assert(childOf(btn, "UIGradient"), "buttons get the gradient")
		assert(childOf(btn, "UICorner") and childOf(btn, "UIStroke"), "buttons keep corner and stroke")
	end)

	test("fit_text_prefers_the_readable_size_and_never_goes_below_the_old_size", function()
		local label = instance("TextLabel")
		Theme.FitText(label, 13, 11)
		local limit = childOf(label, "UITextSizeConstraint")
		assert(label.TextSize == 13 and label.TextScaled == true, "label not set to scale")
		assert(limit and limit.MaxTextSize == 13 and limit.MinTextSize == 11, "wrong size limits")
		local other = instance("TextLabel")
		Theme.FitText(other, 13, 20)
		assert(childOf(other, "UITextSizeConstraint").MinTextSize == 13, "floor may not exceed the preferred size")
	end)

	test("no_client_text_is_authored_below_the_minimum_size", function()
		local min = Theme.MIN_TEXT_SIZE
		assert(min >= 13, "minimum text size lowered")
		local checked = 0
		for path, source in pairs(sources) do
			for size in string.gmatch(source, "TextSize%s*=%s*(%d+)") do
				checked += 1
				assert(tonumber(size) >= min, path .. ": TextSize " .. size .. " below minimum " .. min)
			end
			for size in string.gmatch(source, "sz%s*=%s*(%d+)") do
				assert(tonumber(size) >= min, path .. ": button size " .. size .. " below minimum " .. min)
			end
			for size in string.gmatch(source, "FitText%([%w_%.]+,%s*(%d+)") do
				checked += 1
				assert(tonumber(size) >= min, path .. ": FitText size " .. size .. " below minimum " .. min)
			end
		end
		assert(checked > 50, "source scan found too few text sizes: " .. checked)
	end)

	test("client_boot_uses_the_usable_screen_below_the_roblox_top_bar", function()
		local boot = assert(sources["init.client.luau"], "missing init.client.luau")
		assert(string.find(boot, "ResponsiveScale.Compute", 1, true), "boot must use ResponsiveScale.Compute")
		-- Do bang ScreenGui rong cung inset voi HUD: khong tu tru inset bang tay (de tru hai lan tren may co tai tho).
		assert(string.find(boot, "screenProbe.AbsoluteSize", 1, true), "boot must measure the real usable area")
		assert(string.find(boot, "screenProbe.IgnoreGuiInset = rootGui.IgnoreGuiInset", 1, true), "probe must share the HUD inset mode")
		assert(string.find(boot, 'screenProbe:GetPropertyChangedSignal("AbsoluteSize")', 1, true), "scale must follow screen changes")
		assert(not string.find(boot, "GetGuiInset", 1, true), "manual inset subtraction can double count the notch")
		assert(not string.find(boot, "/ 680", 1, true), "old height formula still present")
	end)

	print(string.format("UI_SCALE_THEME_SUITE passed=%d failed=%d", passed, failed))
	if failed > 0 then error("ui scale and theme suite failed") end
end
