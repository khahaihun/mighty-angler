--!strict
-- GamepassOwnership.luau: Hoi Roblox ve quyen so huu Gamepass.
-- Loi API tra ve "Unknown" (thu lai sau), KHONG BAO GIO bi coi la "chua mua" hay "da mua".

local MarketplaceService = game:GetService("MarketplaceService")
local Players = game:GetService("Players")

local GamepassOwnership = {}

export type Result = "Owned" | "NotOwned" | "Unknown"

GamepassOwnership.ATTEMPTS = 3
GamepassOwnership.RETRY_WAIT_SEC = 1.5
-- Lich thu lai nen khi Roblox loi keo dai (giay giua cac vong)
GamepassOwnership.BACKGROUND_WAITS_SEC = { 15, 30, 60, 60, 120, 120 }

function GamepassOwnership.QueryPass(player: Player, passId: number): Result
	if passId <= 0 then
		return "NotOwned"
	end
	for attempt = 1, GamepassOwnership.ATTEMPTS do
		if not player:IsDescendantOf(Players) then
			return "Unknown"
		end
		local ok, value = pcall(function(): boolean
			return MarketplaceService:UserOwnsGamePassAsync(player.UserId, passId)
		end)
		if ok then
			return if value == true then "Owned" else "NotOwned"
		end
		if attempt < GamepassOwnership.ATTEMPTS then
			task.wait(GamepassOwnership.RETRY_WAIT_SEC * attempt)
		end
	end
	return "Unknown"
end

-- Goi lai `step` theo lich nen cho toi khi no tra true (xong) hoac nguoi choi roi di.
-- `isLast` = true o vong cuoi de noi goi don trang thai cho.
function GamepassOwnership.RetryInBackground(player: Player, step: (isLast: boolean) -> boolean)
	task.spawn(function()
		local waits = GamepassOwnership.BACKGROUND_WAITS_SEC
		for index, waitSec in ipairs(waits) do
			task.wait(waitSec)
			if not player:IsDescendantOf(Players) or step(index == #waits) then
				return
			end
		end
	end)
end

return GamepassOwnership
