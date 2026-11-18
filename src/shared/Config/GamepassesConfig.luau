--!strict
-- GamepassesConfig.luau: Cau hinh 5 goi Gamepass thuong mai (dien ID that cua Roblox truoc khi Publish)

export type GamepassKey = "AutoFish" | "DoubleGold" | "DoubleStrength" | "ExtraPets" | "ExclusiveDragonRod"

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
		id = 0, -- Thay bang Gamepass ID that khi dua len Roblox (anh xa Auto-Fish Pro)
		name = "Auto-Fish Pro",
		robuxDisplay = 79,
		color = Color3.fromRGB(72, 212, 255),
		description = "100% Perfect Auto-Cast (+25% Luck, +15% Lure Speed) & 0.45s Fast Recast!",
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
	{
		key = "ExclusiveDragonRod" :: GamepassKey,
		id = 0,
		name = "Seraphim Dragon Rod",
		robuxDisplay = 399,
		color = Color3.fromRGB(255, 96, 198),
		description = "130% Scaling Exclusive Rod (kept on Rebirth!) + Unlocks Ancient Enchant Slot!",
	},
} :: { GamepassDef }

GamepassesConfig.ByKey = {} :: { [string]: GamepassDef }
for _, gp in ipairs(GamepassesConfig.List) do
	GamepassesConfig.ByKey[gp.key] = gp
end

return GamepassesConfig
