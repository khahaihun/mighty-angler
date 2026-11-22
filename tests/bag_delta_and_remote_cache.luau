-- Buoc 5: goi tui ca chi mang phan thay doi (Shared/BagDelta) va Net nho san tham chieu RemoteEvent.
-- Chay ma that cua hai module; Roblox DataModel la gia lap.
local function equal(actual, expected, label)
	if actual ~= expected then error(string.format("%s: expected %s, got %s", label, tostring(expected), tostring(actual)), 2) end
end

return function(sources)
	local passed, failed = 0, 0
	local function test(name, run)
		local ok, err = pcall(run)
		if ok then passed += 1; print("PASS step5 " .. name) else failed += 1; print("FAIL step5 " .. name .. ": " .. tostring(err)) end
	end
	local function load(name, env)
		local run = assert(loadstring(sources[name], "@" .. name))
		setfenv(run, setmetatable(env or {}, { __index = getfenv() }))
		return run()
	end
	local function fish(uid, locked) return { uid = uid, locked = locked == true } end
	local BagDelta = load("BagDelta")

	test("caught_fish_is_appended_without_resending_the_bag", function()
		local bag = { fish("a"), fish("b") }
		local nextBag, inSync = BagDelta.Apply(bag, { added = { fish("c") }, count = 3 })
		equal(#nextBag, 3, "bag size"); equal(nextBag[3].uid, "c", "new fish last"); equal(inSync, true, "in sync")
		equal(#bag, 2, "previous bag table is not mutated behind the UI")
	end)

	test("lock_toggle_replaces_one_fish_in_place", function()
		local bag = { fish("a"), fish("b"), fish("c") }
		local nextBag, inSync = BagDelta.Apply(bag, { updated = { fish("b", true) }, count = 3 })
		equal(nextBag[2].uid, "b", "order kept"); equal(nextBag[2].locked, true, "new state")
		equal(nextBag[1], bag[1], "untouched fish reused"); equal(bag[2].locked, false, "old entry untouched"); equal(inSync, true, "in sync")
	end)

	test("removed_fish_are_dropped", function()
		local nextBag, inSync = BagDelta.Apply({ fish("a"), fish("b"), fish("c") }, { removed = { "a", "c" }, count = 1 })
		equal(#nextBag, 1, "bag size"); equal(nextBag[1].uid, "b", "survivor"); equal(inSync, true, "in sync")
	end)

	test("full_bag_payload_still_replaces_everything", function()
		local full = { fish("x") }
		local nextBag, inSync = BagDelta.Apply({ fish("a"), fish("b") }, { fishBag = full })
		equal(nextBag, full, "server bag used as-is"); equal(inSync, true, "in sync")
	end)

	test("missed_update_is_detected_by_count", function()
		-- Client lo mat mot goi (dang co 2 ca, Server da co 4): phai bao lech de xin lai nguyen tui.
		local _, inSync = BagDelta.Apply({ fish("a"), fish("b") }, { added = { fish("d") }, count = 4 })
		equal(inSync, false, "count mismatch reported")
		local _, noCount = BagDelta.Apply({ fish("a") }, { added = { fish("b") } })
		equal(noCount, false, "delta without a count is never trusted")
	end)

	test("malformed_payload_keeps_current_bag", function()
		local bag = { fish("a") }
		equal(BagDelta.Apply(bag, "garbage"), bag, "non-table ignored")
		local nextBag = BagDelta.Apply(bag, { added = "x", updated = { 5, { uid = 7 } }, removed = 3, count = 1 })
		equal(#nextBag, 1, "bad fields ignored"); equal(nextBag[1].uid, "a", "fish kept")
	end)

	local function netServer()
		local lookups = 0
		local function instance(class, name)
			local item = { ClassName = class, Name = name, children = {} }
			function item:IsA(k) return k == class end
			function item:FindFirstChild(key) lookups += 1; return self.children[key] end
			return item
		end
		local storage = instance("Folder", "ReplicatedStorage")
		local fired = {}
		local env = {
			game = { GetService = function(_, name)
				if name == "ReplicatedStorage" then return storage end
				if name == "RunService" then return { IsServer = function() return true end } end
				return { PlayerRemoving = { Connect = function() end } }
			end },
			Instance = { new = function(class)
				local item = instance(class, class)
				local parent
				if class == "RemoteEvent" then
					function item:FireClient(player, payload) table.insert(fired, { remote = self, player = player, payload = payload }) end
				end
				return setmetatable({}, {
					__index = function(_, key) if key == "Parent" then return parent end; return item[key] end,
					__newindex = function(proxy, key, value)
						if key == "Parent" then
							if parent then parent.children[item.Name] = nil end
							parent = value
							if value then value.children[item.Name] = proxy end
						else item[key] = value end
					end,
				})
			end },
		}
		return load("Net", env), fired, function() return lookups end, storage
	end

	test("remote_reference_is_remembered_after_first_use", function()
		local Net, fired, lookups = netServer()
		Net.FireClient("p1", Net.ServerToClient.Toast, 1)
		local afterFirst = lookups()
		for i = 1, 50 do Net.FireClient("p1", Net.ServerToClient.Toast, i) end
		equal(lookups(), afterFirst, "50 more sends do not rescan the remote folder")
		equal(#fired, 51, "every message still sent"); equal(fired[51].remote.Name, "S2C_Toast", "to the right remote")
		equal(Net.GetEvent(Net.ServerToClient.BagUpdated).Name, "S2C_BagUpdated", "other remotes resolve separately")
	end)

	test("destroyed_remote_is_found_again_and_unknown_name_still_fails", function()
		local Net = netServer()
		local first = Net.GetEvent(Net.ServerToClient.Toast)
		first.Parent = nil
		local second = Net.GetEvent(Net.ServerToClient.Toast)
		equal(second ~= first and second.Parent ~= nil, true, "stale reference replaced by a live remote")
		equal(pcall(Net.GetEvent, "S2C_DoesNotExist"), false, "unknown remote name is still an error")
	end)

	test("bag_resync_remote_is_in_the_manifest", function()
		local Net = netServer()
		equal(Net.GetEvent(Net.ClientToServer.RequestBagSync).Name, "C2S_RequestBagSync", "remote created")
	end)

	print(string.format("STEP5_BAG_NET_SUITE passed=%d failed=%d", passed, failed))
	assert(failed == 0, "bag delta / remote cache suite failed")
end
