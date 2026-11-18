--!strict
-- FishingSessionManager.luau: Quan ly phien cau ca nguyen tu (CloseSessionOnce) & Per-Strike Server Clock chinh xac

local Players = game:GetService("Players")
local ReplicatedStorage = game:GetService("ReplicatedStorage")

local Shared = ReplicatedStorage:WaitForChild("Shared")
local Types = require(Shared:WaitForChild("Types"))
local CatchControl = require(Shared:WaitForChild("CatchControl"))
local Net = require(Shared:WaitForChild("Net"))
local Util = require(Shared:WaitForChild("Util"))

local RodVisuals = require(script.Parent.Parent.World.RodVisuals)

export type CastSession = {
	sessionId: string,
	state: "Waiting" | "Minigame",
	islandId: number,
	waterPos: Vector3,
	inWhirlpool: boolean,
	castMode: string,
	snapRod: Types.EffectiveRodStats,
	snapBait: string?,
	snapMults: Types.AggregatedMultipliers,
	rolledFish: Types.FishDef?,
	rolledMutation: Types.MutationName,
	rounds: number,
	currentRound: number,
	zoneWidth: number,
	zoneCenters: { number },
	speed: number,
	promptSentClock: number,
	timeoutSec: number,
	serverDeadlineClock: number,
	lastStrikeElapsed: number,
}

local FishingSessionManager = {}

local sessions: { [Player]: CastSession } = {}

function FishingSessionManager.Get(player: Player): CastSession?
	return sessions[player]
end

function FishingSessionManager.CreateWaitingSession(
	player: Player,
	islandId: number,
	waterPos: Vector3,
	inWhirlpool: boolean,
	castMode: string,
	snapRod: Types.EffectiveRodStats,
	snapBait: string?,
	snapMults: Types.AggregatedMultipliers
): CastSession
	local sess: CastSession = {
		sessionId = Util.NewUid(),
		state = "Waiting",
		islandId = islandId,
		waterPos = waterPos,
		inWhirlpool = inWhirlpool,
		castMode = castMode,
		snapRod = snapRod,
		snapBait = snapBait,
		snapMults = snapMults,
		rolledFish = nil,
		rolledMutation = "None",
		rounds = 1,
		currentRound = 1,
		zoneWidth = 0.28,
		zoneCenters = {},
		speed = 1.0,
		promptSentClock = 0,
		timeoutSec = 7.5,
		serverDeadlineClock = 0,
		lastStrikeElapsed = 0,
	}
	sessions[player] = sess
	return sess
end

function FishingSessionManager.CloseSessionOnce(
	player: Player,
	expectedSessionId: string?,
	reason: string,
	silent: boolean?
): CastSession?
	local cur = sessions[player]
	if not cur then
		return nil
	end
	if expectedSessionId ~= nil and cur.sessionId ~= expectedSessionId then
		return nil
	end
	sessions[player] = nil
	RodVisuals.ClearBobber(player)

	if not silent then
		if reason == "Timeout" then
			Net.FireClient(player, Net.ServerToClient.FishingCatchResult, {
				success = false,
				timedOut = true,
			})
			Net.FireClient(player, Net.ServerToClient.Toast, {
				kind = "Info",
				text = "⏱️ Too slow! The rare fish broke free off the line!",
			})
		elseif reason == "Miss" then
			Net.FireClient(player, Net.ServerToClient.FishingCatchResult, {
				success = false,
			})
			Net.FireClient(player, Net.ServerToClient.Toast, {
				kind = "Error",
				text = "The rare fish slipped off the hook! Train Strength or Steadiness!",
			})
		elseif reason ~= "Win" then
			Net.FireClient(player, Net.ServerToClient.FishingStateReset, { reason = reason })
		end
	end
	return cur
end

function FishingSessionManager.BeginMinigame(
	player: Player,
	sess: CastSession,
	fishDef: Types.FishDef,
	mutName: Types.MutationName
)
	sess.state = "Minigame"
	sess.rolledFish = fishDef
	sess.rolledMutation = mutName

	local rounds = if fishDef.rarity == "Boss"
		then 3
		elseif fishDef.rarity == "Legendary" or fishDef.rarity == "Epic" then 2
		else 1
	local zoneWidth = CatchControl.ComputeWidth(fishDef.rarity == "Boss", sess.snapMults.minigameWidthBonus)
	local baseSpeed = if fishDef.rarity == "Boss" then 1.42 elseif fishDef.rarity == "Legendary" then 1.24 else 1.05
	local speed = math.max(0.48, baseSpeed / math.max(1.0, sess.snapMults.minigameSpeedDivisor))

	local centers: { number } = {}
	for _ = 1, rounds do
		local c = 0.30 + math.random() * 0.52 -- Dung mien [0.30, 0.82] cua PLAN.md
		table.insert(centers, math.floor(c * 1000 + 0.5) / 1000)
	end

	local nowClock = os.clock()
	local timeoutSec = 5.5 + rounds * 2.0
	local serverCloseDelay = timeoutSec + 0.40

	sess.rounds = rounds
	sess.currentRound = 1
	sess.zoneWidth = zoneWidth
	sess.zoneCenters = centers
	sess.speed = speed
	sess.promptSentClock = nowClock
	sess.timeoutSec = timeoutSec
	sess.serverDeadlineClock = nowClock + serverCloseDelay
	sess.lastStrikeElapsed = 0

	Net.FireClient(player, Net.ServerToClient.FishingMinigamePrompt, {
		sessionId = sess.sessionId,
		fishName = fishDef.name,
		rarity = fishDef.rarity,
		mutation = mutName,
		rounds = rounds,
		zoneWidth = zoneWidth,
		zoneCenters = centers,
		speed = speed,
		timeoutSec = timeoutSec,
	})

	local capturedId = sess.sessionId
	task.delay(serverCloseDelay, function()
		local stillOpen = sessions[player]
		if stillOpen and stillOpen.sessionId == capturedId and stillOpen.state == "Minigame" then
			FishingSessionManager.CloseSessionOnce(player, capturedId, "Timeout", false)
		end
	end)
end

function FishingSessionManager.HandleStrike(
	player: Player,
	rawSessionId: any,
	rawRound: any,
	rawClientElapsed: any,
	onWin: (Player, CastSession) -> ()
)
	local sess = sessions[player]
	if not sess or sess.state ~= "Minigame" or type(rawSessionId) ~= "string" or sess.sessionId ~= rawSessionId then
		return
	end

	local nowClock = os.clock()
	if nowClock > sess.serverDeadlineClock then
		FishingSessionManager.CloseSessionOnce(player, sess.sessionId, "Timeout", false)
		return
	end

	if type(rawRound) ~= "number" or type(rawClientElapsed) ~= "number" then
		return
	end
	if rawRound ~= rawRound or rawClientElapsed ~= rawClientElapsed or math.abs(rawClientElapsed) == math.huge then
		return
	end
	if rawRound ~= math.floor(rawRound) or rawRound ~= sess.currentRound then
		return
	end
	if rawClientElapsed <= sess.lastStrikeElapsed or rawClientElapsed > sess.timeoutSec then
		FishingSessionManager.CloseSessionOnce(player, sess.sessionId, "Timeout", false)
		return
	end

	-- Hang so chuan PLAN.md 2.2(2): clientElapsed <= serverElapsed + 0.08 va (serverElapsed - clientElapsed) <= 0.45
	local serverElapsed = nowClock - sess.promptSentClock
	if rawClientElapsed > (serverElapsed + 0.08) or (serverElapsed - rawClientElapsed) > 0.45 then
		FishingSessionManager.CloseSessionOnce(player, sess.sessionId, "Miss", false)
		return
	end

	local needlePos = Util.TriangleBounce(0.08, sess.speed, rawClientElapsed)
	local targetCenter = sess.zoneCenters[sess.currentRound] or 0.5
	local halfTolerance = sess.zoneWidth * 0.52 + 0.05

	if math.abs(needlePos - targetCenter) > halfTolerance then
		FishingSessionManager.CloseSessionOnce(player, sess.sessionId, "Miss", false)
		return
	end

	sess.lastStrikeElapsed = rawClientElapsed
	if sess.currentRound >= sess.rounds then
		local closed = FishingSessionManager.CloseSessionOnce(player, sess.sessionId, "Win", true)
		if closed then
			onWin(player, closed)
		end
	else
		sess.currentRound += 1
		Net.FireClient(player, Net.ServerToClient.FishingMinigameStep, {
			sessionId = sess.sessionId,
			nextRound = sess.currentRound,
		})
	end
end

Players.PlayerRemoving:Connect(function(player: Player)
	sessions[player] = nil
end)

return FishingSessionManager
