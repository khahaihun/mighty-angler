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
local intentIds: { [Player]: number } = {}
local readyAt: { [Player]: number } = {}
local manualReadyAt: { [Player]: number } = {}

function FishingCastState.Reply(player: Player, _requestId: any?)
 Net.FireClient(player, Net.ServerToClient.FishingAutoState, {
  enabled = enabled[player] == true, readyAt = readyAt[player] or 0, requestId = intentIds[player] or 0,
 })
end
function FishingCastState.SetAuto(player: Player, active: boolean)
 enabled[player] = active
end
function FishingCastState.ShouldResume(reason: string): boolean
 return reason == "Win" or reason == "Miss" or reason == "Timeout" or reason == "Died" or reason == "IslandChange" or reason == "Rebirth"
  or reason == "CastCooldown"
end
function FishingCastState.ApplyRequest(player: Player, active: boolean, requestId: any): boolean
 if type(requestId) ~= "number" or requestId ~= math.floor(requestId) or requestId < 1 or requestId > 1e9 then return false end
 local oldId = intentIds[player] or 0
 if requestId <= oldId then return false end
 intentIds[player] = requestId; enabled[player] = active
 return true
end
function FishingCastState.Reset(player: Player, reason: string)
 charges[player] = nil
 if not FishingCastState.ShouldResume(reason) then enabled[player] = false end
 Net.FireClient(player, Net.ServerToClient.FishingStateReset, {
  reason = reason, autoEnabled = enabled[player] == true, requestId = intentIds[player] or 0, readyAt = readyAt[player] or 0,
 })
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
function FishingCastState.CanManualCast(player: Player): boolean
 return Workspace:GetServerTimeNow() >= (manualReadyAt[player] or 0)
end
function FishingCastState.Close(player: Player, sessionId: string, reason: string)
 local delay = if PerkService.HasGamepass(player, "AutoFish") then GameConfig.AUTO_FISH_PRO_RECAST_SEC else GameConfig.AUTO_FISH_FREE_RECAST_SEC
 readyAt[player] = Workspace:GetServerTimeNow() + delay
 manualReadyAt[player] = Workspace:GetServerTimeNow() + GameConfig.MANUAL_CAST_MIN_INTERVAL_SEC
 charges[player] = nil
 if not FishingCastState.ShouldResume(reason) then enabled[player] = false end
 Net.FireClient(player, Net.ServerToClient.FishingSessionClosed, {
  sessionId = sessionId, reason = reason, readyAt = readyAt[player], manualReadyAt = manualReadyAt[player], autoEnabled = enabled[player] == true, requestId = intentIds[player] or 0,
 })
end
function FishingCastState.Forget(player: Player)
 enabled[player] = nil; charges[player] = nil; readyAt[player] = nil; manualReadyAt[player] = nil; intentIds[player] = nil
end
return FishingCastState
