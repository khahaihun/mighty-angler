--!strict
local ReplicatedStorage = game:GetService("ReplicatedStorage")
local Workspace = game:GetService("Workspace")
local Shared = ReplicatedStorage:WaitForChild("Shared")
local Net = require(Shared:WaitForChild("Net"))
local GameConfig = require(Shared:WaitForChild("Config"):WaitForChild("GameConfig"))
local PerkService = require(script.Parent.PerkService)
local FishingCastState = {}
local enabled: { [Player]: boolean } = {}
local charges: { [Player]: number } = {}
local readyAt: { [Player]: number } = {}

function FishingCastState.Reply(player: Player, requestId: any?)
 Net.FireClient(player, Net.ServerToClient.FishingAutoState, {
  enabled = enabled[player] == true, readyAt = readyAt[player] or 0, requestId = requestId,
 })
end
function FishingCastState.SetAuto(player: Player, active: boolean)
 enabled[player] = active
end
function FishingCastState.StartCharge(player: Player)
 charges[player] = os.clock()
end
function FishingCastState.TakeCharge(player: Player): number?
 local started = charges[player]; charges[player] = nil; return started
end
function FishingCastState.CanAutoCast(player: Player): boolean
 return enabled[player] == true and Workspace:GetServerTimeNow() >= (readyAt[player] or 0)
end
function FishingCastState.Close(player: Player, sessionId: string, reason: string)
 local delay = if PerkService.HasGamepass(player, "AutoFish") then GameConfig.AUTO_FISH_PRO_RECAST_SEC else GameConfig.AUTO_FISH_FREE_RECAST_SEC
 readyAt[player] = Workspace:GetServerTimeNow() + delay
 charges[player] = nil
 if reason ~= "Win" and reason ~= "Miss" and reason ~= "Timeout" then
  enabled[player] = false
  local messages = { Unequip = "rod put away", ManualCancel = "cast cancelled", Died = "character died", IslandChange = "island changed", Rebirth = "Rebirth completed" }
  Net.FireClient(player, Net.ServerToClient.Toast, { kind = "Info", text = "Fishing stopped: " .. (messages[reason] or reason) .. ". Turn Auto-Fish on to resume." })
 end
 Net.FireClient(player, Net.ServerToClient.FishingSessionClosed, {
  sessionId = sessionId, reason = reason, readyAt = readyAt[player], autoEnabled = enabled[player] == true,
 })
end
function FishingCastState.Forget(player: Player)
 enabled[player] = nil; charges[player] = nil; readyAt[player] = nil
end
return FishingCastState
