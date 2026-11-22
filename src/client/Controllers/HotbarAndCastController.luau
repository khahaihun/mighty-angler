--!strict
-- HotbarAndCastController.luau: Phim 1..5 Hotbar, Giu Chuot/Touch rieng biet nap Cast Power, Raycast Nuoc vs Vat can & Hieu ung "!"

local Debris = game:GetService("Debris")
local Players = game:GetService("Players")
local ReplicatedStorage = game:GetService("ReplicatedStorage")
local RunService = game:GetService("RunService")
local UserInputService = game:GetService("UserInputService")
local Workspace = game:GetService("Workspace")

local Shared = ReplicatedStorage:WaitForChild("Shared")
local Net = require(Shared:WaitForChild("Net"))
local FishingRayFilter = require(Shared:WaitForChild("FishingRayFilter"))
local GameConfig = require(Shared:WaitForChild("Config"):WaitForChild("GameConfig"))

local FishingController = require(script.Parent.FishingController)
local GymController = require(script.Parent.GymController)
local AnimationController = require(script.Parent.AnimationController)
local SoundAndFxController = require(script.Parent.SoundAndFxController)
local HotbarAndBaitUi = require(script.Parent.Parent.UI.Components.HotbarAndBaitUi)

local HotbarAndCastController = {}

local localPlayer = Players.LocalPlayer
local isUiModalBlocking: (() -> boolean)? = nil

local holdingCast = false
local waitingForCooldown = false -- Dang giu chuot/ngon tay trong thoi gian cho quang tay; chua nap luc, chua gui gi len server.
local activeCastInput: InputObject? = nil
local holdStartClock = 0.0
local holdPointerPos = Vector2.new()
local holdIsTouch = false
local CHARGE_CYCLE_SEC = 1.15

local KEY_TO_SLOT: { [Enum.KeyCode]: number } = {
	[Enum.KeyCode.One] = 1,
	[Enum.KeyCode.Two] = 2,
	[Enum.KeyCode.Three] = 3,
	[Enum.KeyCode.Four] = 4,
	[Enum.KeyCode.Five] = 5,
}

local function computeChargeRatio(elapsed: number): number
	local u = (elapsed / CHARGE_CYCLE_SEC) % 2.0
	return if u <= 1.0 then u else (2.0 - u)
end

local function raycastPointerAim(screenPos: Vector2, isTouchCoord: boolean): (boolean, Vector3?)
	local cam = Workspace.CurrentCamera
	if not cam then
		return false, nil
	end
	-- GetMouseLocation bao gom GuiInset tren Roblox (ViewportPointToRay), con Touch input.Position khong co GuiInset (ScreenPointToRay)
	local ray = if isTouchCoord
		then cam:ScreenPointToRay(screenPos.X, screenPos.Y)
		else cam:ViewportPointToRay(screenPos.X, screenPos.Y)

	local params = FishingRayFilter.Create()

	local hit = Workspace:Raycast(ray.Origin, ray.Direction * 320, params)
	if not hit then
		return false, nil
	end
	if hit.Material == Enum.Material.Water then
		return true, hit.Position
	end
	return false, hit.Position
end

local function spawnExclamationPopup(player: Player)
	local bobber = Workspace:FindFirstChild("FishingBobber_" .. player.Name)
	local char = player.Character
	local adornee: Instance? = if bobber and bobber:IsA("BasePart")
		then bobber
		elseif char then char:FindFirstChild("Head")
		else nil
	if not adornee then
		return
	end

	local bb = Instance.new("BillboardGui")
	bb.Size = UDim2.fromOffset(72, 72)
	bb.StudsOffset = Vector3.new(0, 2.8, 0)
	bb.AlwaysOnTop = true
	bb.Adornee = adornee
	bb.Parent = adornee

	local lbl = Instance.new("TextLabel")
	lbl.Size = UDim2.fromScale(1, 1)
	lbl.BackgroundTransparency = 1
	lbl.Font = Enum.Font.FredokaOne
	lbl.Text = "❗"
	lbl.TextScaled = true
	lbl.TextColor3 = Color3.fromRGB(255, 214, 52)
	lbl.Parent = bb
	Debris:AddItem(bb, 0.95)
end

local function castBlocked(): boolean
	return HotbarAndBaitUi.GetEquippedSlot() ~= 1
		or FishingController.IsBusy()
		or (isUiModalBlocking ~= nil and isUiModalBlocking())
end

-- Thoi gian giu do server do tu luc nhan FishingChargeStart, nen chi gui khi thanh luc tren client bat dau chay.
local function beginCharge()
	waitingForCooldown = false
	holdingCast = true
	holdStartClock = os.clock()
	HotbarAndBaitUi.SetCastCharge(true, 0.05)
	Net.FireServer(Net.ClientToServer.FishingChargeStart)
end

function HotbarAndCastController.Init(checkUiBlocked: () -> boolean)
	isUiModalBlocking = checkUiBlocked

	RunService.RenderStepped:Connect(function()
		if waitingForCooldown then
			if castBlocked() or GymController.IsOnStation() then
				waitingForCooldown = false
				activeCastInput = nil
			elseif FishingController.CanManualCast() then
				beginCharge()
			end
			return
		end
		if not holdingCast then
			return
		end
		if castBlocked() then
			holdingCast = false
			activeCastInput = nil
			HotbarAndBaitUi.SetCastCharge(false, 0)
			return
		end
		local ratio = computeChargeRatio(os.clock() - holdStartClock)
		HotbarAndBaitUi.SetCastCharge(true, ratio)
	end)

	UserInputService.InputBegan:Connect(function(input: InputObject, gameProcessed: boolean)
		if gameProcessed then
			return
		end
		local slot = KEY_TO_SLOT[input.KeyCode]
		if slot then
			SoundAndFxController.PlaySfx("Click")
			Net.FireServer(Net.ClientToServer.SelectHotbarSlot, slot)
			return
		end

		local isTouch = (input.UserInputType == Enum.UserInputType.Touch)
		local isMouse = (input.UserInputType == Enum.UserInputType.MouseButton1)
		if (not isTouch and not isMouse) or holdingCast or waitingForCooldown then
			return
		end
		if GymController.IsOnStation() or castBlocked() then
			return
		end

		activeCastInput = input
		holdIsTouch = isTouch
		holdPointerPos = if isTouch
			then Vector2.new(input.Position.X, input.Position.Y)
			else UserInputService:GetMouseLocation()
		if FishingController.CanManualCast() then
			beginCharge()
		else
			-- Bam trong thoi gian cho: nho cu bam, RenderStepped se bat dau nap luc khi het cho neu van con giu.
			waitingForCooldown = true
		end
	end)

	UserInputService.InputChanged:Connect(function(input: InputObject)
		if (holdingCast or waitingForCooldown) and holdIsTouch and input == activeCastInput then
			holdPointerPos = Vector2.new(input.Position.X, input.Position.Y)
		end
	end)

	UserInputService.InputEnded:Connect(function(input: InputObject, _gameProcessed: boolean)
		if input ~= activeCastInput then
			return
		end
		if waitingForCooldown then
			-- Nha truoc khi het cho: bo cu bam, khong gui gi len server.
			waitingForCooldown = false
			activeCastInput = nil
			return
		end
		if not holdingCast then
			return
		end

		local elapsed = os.clock() - holdStartClock
		local ratio = if elapsed < 0.14 then 0.55 else computeChargeRatio(elapsed)
		local wasTouch = holdIsTouch
		local fallbackPos = holdPointerPos

		holdingCast = false
		activeCastInput = nil
		HotbarAndBaitUi.SetCastCharge(false, 0)

		local endPos = if wasTouch
			then Vector2.new(input.Position.X, input.Position.Y)
			else UserInputService:GetMouseLocation()
		local aimScreen = if endPos.Magnitude > 1 then endPos else fallbackPos
		local hitWater, hitPos = raycastPointerAim(aimScreen, wasTouch)

		if not hitPos then
			AnimationController.StopFishingHold()
			SoundAndFxController.ShowToast("Info", "🌊 Aim downward at the ocean water to cast your rod!")
			return
		end

		SoundAndFxController.PlaySfx("Cast")
		if not hitWater then
			AnimationController.PlayCast()
			Net.FireServer(Net.ClientToServer.FishingCastWithAim, {
				hitWater = false,
				targetPos = hitPos,
			})
			return
		end

		if ratio >= GameConfig.PERFECT_HOLD_MIN and ratio <= GameConfig.PERFECT_HOLD_MAX and elapsed >= 0.55 then
			SoundAndFxController.SpawnFloatingGain("Gems", 0, "✨ PERFECT CAST! (+25% LUCK)")
		end
		Net.FireServer(Net.ClientToServer.FishingCastWithAim, {
			hitWater = true,
			targetPos = hitPos,
			castMode = "Manual",
			holdRatio = ratio,
		})
	end)

	Net.OnClientEvent(Net.ServerToClient.FishingLandBounce, function(_payload: any)
		SoundAndFxController.PlaySfx("LandBounce")
		AnimationController.StopFishingHold()
		SoundAndFxController.ShowToast("Info", "💥 Bobber bounced off dry land! Aim at the ocean water!")
	end)

	Net.OnClientEvent(Net.ServerToClient.FishingMinigamePrompt, function(_payload: any)
		spawnExclamationPopup(localPlayer)
		SoundAndFxController.PlaySfx("CatchCommon")
	end)
end

return HotbarAndCastController
