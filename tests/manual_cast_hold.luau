-- Quang tay trong thoi gian cho MANUAL_CAST_MIN_INTERVAL_SEC: cu bam khong bi nuot.
-- Chay ma that cua HotbarAndCastController; UserInputService, RunService, Net va cac controller khac la gia lap.
local function node(name)
	return setmetatable({ Name = name, WaitForChild = function(_, k) return node(k) end }, { __index = function(_, k) return node(k) end })
end
local function signal()
	local callbacks = {}
	return { Connect = function(_, cb) table.insert(callbacks, cb) end }, function(...) for _, cb in ipairs(callbacks) do cb(...) end end
end

return function(sources)
	local function newController()
		local w = { serverNow = 100, clock = 50, readyAt = 0, busy = false, modal = false, onStation = false, slot = 1, sent = {}, bar = {}, toasts = {} }
		local began, fireBegan = signal()
		local changed, fireChanged = signal()
		local ended, fireEnded = signal()
		local stepped, fireStepped = signal()
		local names = setmetatable({}, { __index = function(_, k) return k end })
		local quiet = setmetatable({}, { __index = function() return function() end end })
		local modules = {
			Net = { ClientToServer = names, ServerToClient = names, OnClientEvent = function() end,
				FireServer = function(event, payload) table.insert(w.sent, { event = event, payload = payload }) end },
			FishingRayFilter = { Create = function() return {} end },
			GameConfig = { PERFECT_HOLD_MIN = 0.78, PERFECT_HOLD_MAX = 0.95 },
			FishingController = { IsBusy = function() return w.busy end, CanManualCast = function() return w.serverNow >= w.readyAt end },
			GymController = { IsOnStation = function() return w.onStation end },
			AnimationController = quiet,
			SoundAndFxController = setmetatable({ ShowToast = function(_, text) table.insert(w.toasts, text) end }, { __index = quiet }),
			HotbarAndBaitUi = { GetEquippedSlot = function() return w.slot end,
				SetCastCharge = function(visible, ratio) table.insert(w.bar, { visible = visible, ratio = ratio }) end },
		}
		local camera = { ViewportPointToRay = function() return { Origin = "origin", Direction = { } } end }
		camera.ScreenPointToRay = camera.ViewportPointToRay
		local services = {
			Debris = {}, Players = { LocalPlayer = { Name = "Tester" } }, ReplicatedStorage = node("ReplicatedStorage"),
			RunService = { RenderStepped = stepped },
			UserInputService = { InputBegan = began, InputChanged = changed, InputEnded = ended, GetMouseLocation = function() return { X = 400, Y = 300, Magnitude = 500 } end },
			Workspace = { CurrentCamera = camera, Raycast = function() return { Material = "Material.Water", Position = "water-point" } end },
		}
		local enum = setmetatable({}, { __index = function(_, group)
			return setmetatable({}, { __index = function(_, item) return group .. "." .. item end })
		end })
		local env = setmetatable({
			script = node("script"), game = { GetService = function(_, k) return services[k] end },
			require = function(mod) return assert(modules[mod.Name], "unmocked module " .. tostring(mod.Name)) end,
			os = { clock = function() return w.clock end }, Enum = enum,
			Vector2 = { new = function(x, y) return { X = x or 0, Y = y or 0, Magnitude = math.sqrt((x or 0) ^ 2 + (y or 0) ^ 2) } end },
			Vector3 = { new = function() return {} end }, UDim2 = { fromOffset = function() return {} end, fromScale = function() return {} end },
			Color3 = { fromRGB = function() return {} end }, Instance = { new = function() return {} end },
		}, { __index = getfenv() })
		camera.ViewportPointToRay = function() return { Origin = "origin", Direction = setmetatable({}, { __mul = function() return "dir" end }) } end
		camera.ScreenPointToRay = camera.ViewportPointToRay
		local run = assert(loadstring(sources.HotbarAndCastController, "@HotbarAndCastController"))
		setfenv(run, env)
		run().Init(function() return w.modal end)

		local mouse = { UserInputType = "UserInputType.MouseButton1", KeyCode = "KeyCode.Unknown", Position = { X = 400, Y = 300 } }
		function w.press(input) fireBegan(input or mouse, false) end
		function w.release(input) fireEnded(input or mouse, false) end
		function w.move(input) fireChanged(input) end
		function w.pass(sec) w.serverNow += sec; w.clock += sec; fireStepped() end
		function w.count(event) local n = 0; for _, e in ipairs(w.sent) do if e.event == event then n += 1 end end; return n end
		function w.barVisible() local last = w.bar[#w.bar]; return last ~= nil and last.visible end
		function w.closeSession() w.readyAt = w.serverNow + 0.45 end -- server: manualReadyAt = now + MANUAL_CAST_MIN_INTERVAL_SEC
		return w
	end

	local passed, failed = 0, 0
	local function test(name, run)
		local ok, err = pcall(run)
		if ok then passed += 1; print("PASS manual cast " .. name) else failed += 1; print("FAIL manual cast " .. name .. ": " .. tostring(err)) end
	end

	test("press_during_cooldown_and_keep_holding_starts_charge_when_cooldown_ends", function()
		local w = newController()
		w.closeSession(); w.pass(0.10); w.press()
		assert(#w.sent == 0 and not w.barVisible(), "nothing is sent and no power bar while the server would still refuse")
		w.pass(0.20)
		assert(#w.sent == 0 and not w.barVisible(), "still waiting at 0.30s of 0.45s")
		w.pass(0.16)
		assert(w.count("FishingChargeStart") == 1 and w.barVisible(), "charge starts by itself once the wait is over")
		local chargeStartedAt = w.clock
		w.pass(0.50); w.pass(0.50)
		assert(w.count("FishingChargeStart") == 1, "charge start is sent exactly once")
		w.release()
		local cast = w.sent[#w.sent]
		assert(w.count("FishingCastWithAim") == 1 and cast.payload.castMode == "Manual" and cast.payload.hitWater == true, "releasing casts")
		-- Thanh luc tinh tu luc bat dau nap (khong tinh thoi gian cho), khop dong ho server bat dau tu FishingChargeStart.
		local elapsed = w.clock - chargeStartedAt
		local u = (elapsed / 1.15) % 2
		assert(math.abs(cast.payload.holdRatio - (if u <= 1 then u else 2 - u)) < 1e-9, "hold ratio counts from charge start, not from the press")
		assert(not w.barVisible(), "power bar hidden after release")
	end)

	test("press_during_cooldown_and_release_early_sends_nothing", function()
		local w = newController()
		w.closeSession(); w.pass(0.10); w.press(); w.pass(0.10); w.release()
		w.pass(0.50); w.pass(0.50)
		assert(#w.sent == 0 and #w.bar == 0 and #w.toasts == 0, "an abandoned press never reaches the server or the power bar")
		w.press()
		assert(w.count("FishingChargeStart") == 1 and w.barVisible(), "the next press after the wait works normally")
	end)

	test("press_after_cooldown_charges_immediately", function()
		local w = newController()
		w.closeSession(); w.pass(0.46); w.press()
		assert(w.count("FishingChargeStart") == 1 and w.barVisible(), "no extra wait once the cooldown has passed")
		w.pass(0.30); w.release()
		assert(w.count("FishingCastWithAim") == 1, "cast sent on release")
	end)

	test("waiting_press_is_dropped_when_casting_becomes_impossible", function()
		for _, block in ipairs({ "busy", "modal", "onStation", "slot" }) do
			local w = newController()
			w.closeSession(); w.pass(0.10); w.press()
			if block == "slot" then w.slot = 2 else w[block] = true end
			w.pass(0.10)
			if block == "slot" then w.slot = 1 else w[block] = false end
			w.pass(0.50); w.release()
			assert(#w.sent == 0 and #w.bar == 0, "held press must not turn into a cast after " .. block)
		end
	end)

	test("second_finger_and_other_inputs_do_not_disturb_a_waiting_press", function()
		local w = newController()
		local first = { UserInputType = "UserInputType.Touch", KeyCode = "KeyCode.Unknown", Position = { X = 200, Y = 500 } }
		local second = { UserInputType = "UserInputType.Touch", KeyCode = "KeyCode.Unknown", Position = { X = 900, Y = 100 } }
		w.closeSession(); w.pass(0.10); w.press(first); w.press(second); w.release(second)
		first.Position = { X = 260, Y = 520 }; w.move(first)
		w.pass(0.40)
		assert(w.count("FishingChargeStart") == 1, "first finger still starts the charge after the wait")
		w.pass(0.30); w.release(second)
		assert(w.count("FishingCastWithAim") == 0, "only the finger that started the hold can release it")
		w.release(first)
		assert(w.count("FishingCastWithAim") == 1, "first finger releases the cast")
	end)

	print(string.format("MANUAL_CAST_HOLD passed=%d failed=%d", passed, failed))
	assert(failed == 0, "manual cast hold suite failed")
end
