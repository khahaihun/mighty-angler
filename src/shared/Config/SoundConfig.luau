--!strict
-- SoundConfig.luau: He thong Am thanh da lop (Nen song bien nhe nhang + SFX quang can, nay dat, ca can, dap trung & tap ta)

local SoundConfig = {}

SoundConfig.OceanAmbience = {
	id = "rbxasset://sounds/action_swim.mp3",
	volume = 0.08,
	pitch = 0.55,
}

SoundConfig.Effects = {
	Click = { id = "rbxasset://sounds/action_footsteps_plastic.mp3", volume = 0.34, pitch = 1.65 },
	Cast = { id = "rbxasset://sounds/action_jump.mp3", volume = 0.45, pitch = 1.28 },
	Splash = { id = "rbxasset://sounds/action_swim.mp3", volume = 0.55, pitch = 1.15 },
	LandBounce = { id = "rbxasset://sounds/impact_water.mp3", volume = 0.42, pitch = 1.55 },
	CatchCommon = { id = "rbxasset://sounds/electronicpingshort.wav", volume = 0.44, pitch = 1.22 },
	CatchRare = { id = "rbxasset://sounds/victory.wav", volume = 0.56, pitch = 1.06 },
	GymRep = { id = "rbxasset://sounds/action_get_up.mp3", volume = 0.36, pitch = 1.35 },
	Coins = { id = "rbxasset://sounds/unsheath.wav", volume = 0.45, pitch = 1.50 },
	Error = { id = "rbxasset://sounds/uuhhh.wav", volume = 0.34, pitch = 1.00 },
}

return SoundConfig
