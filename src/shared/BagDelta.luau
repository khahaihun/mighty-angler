--!strict
-- BagDelta.luau: Ap goi S2C_BagUpdated len tui ca phia Client.
-- Server gui nguyen tui ({ fishBag }) khi ban/sap xep, hoac chi phan thay doi ({ added, updated, removed, count })
-- khi cau duoc ca / khoa ca. count la so ca Server dang giu; lech thi Client phai xin lai nguyen tui.

local BagDelta = {}

function BagDelta.Apply(bag: { any }, payload: any): ({ any }, boolean)
	if type(payload) ~= "table" then
		return bag, true
	end
	if type(payload.fishBag) == "table" then
		return payload.fishBag, true
	end
	local removed: { [string]: boolean } = {}
	local updated: { [string]: any } = {}
	for _, uid in ipairs(if type(payload.removed) == "table" then payload.removed else {}) do
		removed[uid] = true
	end
	for _, entry in ipairs(if type(payload.updated) == "table" then payload.updated else {}) do
		if type(entry) == "table" and type(entry.uid) == "string" then
			updated[entry.uid] = entry
		end
	end
	-- Luon tao bang moi: UI dang giu tham chieu bang cu khong bi sua ngam.
	local result: { any } = {}
	for _, entry in ipairs(bag) do
		local uid = if type(entry) == "table" then entry.uid else nil
		if not (uid and removed[uid]) then
			table.insert(result, if uid and updated[uid] then updated[uid] else entry)
		end
	end
	for _, entry in ipairs(if type(payload.added) == "table" then payload.added else {}) do
		table.insert(result, entry)
	end
	return result, #result == tonumber(payload.count)
end

return BagDelta
