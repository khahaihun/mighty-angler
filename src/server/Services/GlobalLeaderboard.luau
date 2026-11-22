--!strict
-- GlobalLeaderboard.luau: Bang xep hang TOAN CAU qua OrderedDataStore.
-- Chi ghi khi diem tang, doc top theo nhip cham; loi cua mot nguoi/mot bang khong lam hong phan con lai.
-- Update() duoc LiveOpsService goi moi 20 giay cho moi bang; cac nhip duoi day tinh theo so lan goi do.

local DataStoreService = game:GetService("DataStoreService")
local Players = game:GetService("Players")
local RunService = game:GetService("RunService")

local GlobalLeaderboard = {}

export type Entry = { name: string, score: number }
export type LiveScore = { player: Player, score: number, canWrite: boolean }
type TopRow = { userId: number, name: string, score: number }
export type Board = {
	storeName: string,
	store: OrderedDataStore?,
	cycle: number,
	nextReadCycle: number,
	top: { TopRow },
	written: { [Player]: number },
	peak: { [Player]: number },
	nextWriteCycle: { [Player]: number },
}

GlobalLeaderboard.TOP_SIZE = 8
GlobalLeaderboard.WRITE_EVERY_CYCLES = 3 -- moi nguoi toi da 1 lan ghi / bang / 60 giay
GlobalLeaderboard.READ_EVERY_CYCLES = 5 -- doc top toan cau moi 100 giay
GlobalLeaderboard.READ_RETRY_CYCLES = 1 -- doc loi thi thu lai o lan goi ke tiep

local nameCache: { [number]: string } = {}

function GlobalLeaderboard.New(storeName: string): Board
	return {
		storeName = storeName,
		store = nil,
		cycle = 0,
		nextReadCycle = 1,
		top = {},
		written = setmetatable({}, { __mode = "k" }) :: any,
		peak = setmetatable({}, { __mode = "k" }) :: any,
		nextWriteCycle = setmetatable({}, { __mode = "k" }) :: any,
	}
end

local function openStore(board: Board): OrderedDataStore?
	if board.store then
		return board.store
	end
	if game.PlaceId <= 0 then
		return nil
	end
	-- Studio da publish van phai cach ly diem DEV, cung quy tac voi kho ho so.
	local suffix = if RunService:IsStudio() then "_StudioDev" else ""
	local ok, store = pcall(function()
		return DataStoreService:GetOrderedDataStore(board.storeName .. suffix)
	end)
	if ok and store then
		board.store = store
	end
	return board.store
end

local function resolveName(userId: number): string
	local online = Players:GetPlayerByUserId(userId)
	if online then
		return online.DisplayName
	end
	local cached = nameCache[userId]
	if cached then
		return cached
	end
	local ok, name = pcall(function()
		return Players:GetNameFromUserIdAsync(userId)
	end)
	if ok and type(name) == "string" and name ~= "" then
		nameCache[userId] = name
		return name
	end
	return "Player " .. tostring(userId)
end

-- Khong bao gio ghi diem cua phien khong giu khoa (canWrite = false) va khong bao gio ha ky luc.
local function writeScores(board: Board, store: OrderedDataStore, live: { LiveScore })
	for _, item in ipairs(live) do
		local player = item.player
		-- Giu dinh diem da thay trong luc cho nhip ghi: Strength ve 0 khi Rebirth nhung ky luc vua dat van phai duoc ghi.
		local value = board.peak[player] or 0
		if item.canWrite then
			value = math.max(value, math.floor(item.score))
			board.peak[player] = value
		end
		if item.canWrite and value > (board.written[player] or 0) and board.cycle >= (board.nextWriteCycle[player] or 0) then
			board.nextWriteCycle[player] = board.cycle + GlobalLeaderboard.WRITE_EVERY_CYCLES
			local ok, err = pcall(function()
				store:UpdateAsync(tostring(player.UserId), function(oldValue: any)
					return math.max(tonumber(oldValue) or 0, value)
				end)
			end)
			if ok then
				board.written[player] = value
			else
				warn(string.format("[GlobalLeaderboard] Write failed board=%s user=%d: %s", board.storeName, player.UserId, tostring(err)))
			end
		end
	end
end

local function readTop(board: Board, store: OrderedDataStore)
	local ok, page = pcall(function(): any
		return store:GetSortedAsync(false, GlobalLeaderboard.TOP_SIZE):GetCurrentPage()
	end)
	if not ok or type(page) ~= "table" then
		-- Giu danh sach doc duoc lan truoc; thu lai som.
		board.nextReadCycle = board.cycle + GlobalLeaderboard.READ_RETRY_CYCLES
		warn(string.format("[GlobalLeaderboard] Read failed board=%s: %s", board.storeName, tostring(page)))
		return
	end
	local top: { TopRow } = {}
	for _, row in ipairs(page) do
		local userId, score = tonumber(row.key), tonumber(row.value)
		if userId and score then
			table.insert(top, { userId = userId, name = resolveName(userId), score = score })
		end
	end
	board.top = top
	board.nextReadCycle = board.cycle + GlobalLeaderboard.READ_EVERY_CYCLES
end

-- Tra ve top de hien thi: top toan cau da doc, gop voi diem dang co cua nguoi trong server (lay diem cao hon).
function GlobalLeaderboard.Update(board: Board, live: { LiveScore }): { Entry }
	board.cycle += 1
	local store = openStore(board)
	if store then
		writeScores(board, store, live)
		if board.cycle >= board.nextReadCycle then
			readTop(board, store)
		end
	end
	local byUser: { [number]: Entry } = {}
	for _, row in ipairs(board.top) do
		byUser[row.userId] = { name = row.name, score = row.score }
	end
	for _, item in ipairs(live) do
		local existing = byUser[item.player.UserId]
		if not existing or item.score > existing.score then
			byUser[item.player.UserId] = { name = item.player.DisplayName, score = item.score }
		end
	end
	local entries: { Entry } = {}
	for _, entry in pairs(byUser) do
		table.insert(entries, entry)
	end
	table.sort(entries, function(a: Entry, b: Entry)
		if a.score ~= b.score then
			return a.score > b.score
		end
		return a.name < b.name
	end)
	for index = #entries, GlobalLeaderboard.TOP_SIZE + 1, -1 do
		entries[index] = nil
	end
	return entries
end

return GlobalLeaderboard
