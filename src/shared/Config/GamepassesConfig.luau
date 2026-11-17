--!strict
-- GamepassesConfig.luau: Cau hinh 4 goi Gamepass thuong mai (dien ID that cua Roblox truoc khi Publish)

export type GamepassKey = "AutoFish" | "DoubleGold" | "DoubleStrength" | "ExtraPets"

export type GamepassDef = {
	key: GamepassKey,
	id: number,
	name: string,
	robuxDisplay: number,
	color: Color3,
	description: string,
}

local GamepassesConfig = {}

GamepassesConfig.List = {
	{
		key = "AutoFish" :: GamepassKey,
		id = 0, -- Thay bang Gamepass ID that khi dua len Roblox
		name = "Auto-Fish",
		robuxDisplay = 39,
		color = Color3.fromRGB(72, 212, 255),
		description = "Automatically cast & reel fish hands-free!",
	},
	{
		key = "DoubleGold" :: GamepassKey,
		id = 0,
		name = "2x Gold",
		robuxDisplay = 99,
		color = Color3.fromRGB(255, 206, 58),
		description = "Earn 2x Gold permanently from selling every fish!",
	},
	{
		key = "DoubleStrength" :: GamepassKey,
		id = 0,
		name = "2x Strength",
		robuxDisplay = 99,
		color = Color3.fromRGB(255, 106, 86),
		description = "Gain 2x Strength from all Gym workouts & fishing!",
	},
	{
		key = "ExtraPets" :: GamepassKey,
		id = 0,
		name = "+2 Pet Equip",
		robuxDisplay = 149,
		color = Color3.fromRGB(208, 108, 255),
		description = "Equip up to 4 Pets at once instead of 2!",
	},
} :: { GamepassDef }

GamepassesConfig.ByKey = {} :: { [string]: GamepassDef }
for _, gp in ipairs(GamepassesConfig.List) do
	GamepassesConfig.ByKey[gp.key] = gp
end

return GamepassesConfig
