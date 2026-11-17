--!strict
-- SoundConfig.luau: Cau hinh am thanh an toan dung san built-in rbxasset://sounds/ cua Roblox Engine

local SoundConfig = {}

SoundConfig.Effects = {
	Click = { id = "rbxasset://sounds/action_footsteps_plastic.mp3", volume = 0.35, pitch = 1.6 },
	Cast = { id = "rbxasset://sounds/action_jump.mp3", volume = 0.45, pitch = 1.25 },
	Splash = { id = "rbxasset://sounds/action_swim.mp3", volume = 0.55, pitch = 1.15 },
	CatchCommon = { id = "rbxasset://sounds/electronicpingshort.wav", volume = 0.45, pitch = 1.2 },
	CatchRare = { id = "rbxasset://sounds/victory.wav", volume = 0.55, pitch = 1.05 },
	GymRep = { id = "rbxasset://sounds/action_get_up.mp3", volume = 0.35, pitch = 1.35 },
	Coins = { id = "rbxasset://sounds/unsheath.wav", volume = 0.45, pitch = 1.5 },
	Error = { id = "rbxasset://sounds/uuhhh.wav", volume = 0.35, pitch = 1.0 },
}

return SoundConfig
