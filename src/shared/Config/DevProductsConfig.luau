--!strict
-- DevProductsConfig.luau: 5 goi nap Gems bang Robux (Developer Products). id = 0 la chua cau hinh: Chu du an dien ID that khi Publish.

export type DevProductDef = {
	key: string,
	id: number,
	name: string,
	gems: number,
	robuxDisplay: number,
	badge: string?,
	color: Color3,
}

local DevProductsConfig = {}

DevProductsConfig.List = {
	{ key = "GemsPouch", id = 0, name = "Pouch of Gems", gems = 100, robuxDisplay = 25, color = Color3.fromRGB(196, 132, 255) },
	{ key = "GemsSack", id = 0, name = "Sack of Gems", gems = 550, robuxDisplay = 99, badge = "+10%", color = Color3.fromRGB(176, 108, 255) },
	{ key = "GemsChest", id = 0, name = "Chest of Gems", gems = 1200, robuxDisplay = 199, badge = "POPULAR", color = Color3.fromRGB(212, 102, 255) },
	{ key = "GemsVault", id = 0, name = "Vault of Gems", gems = 3200, robuxDisplay = 449, badge = "+42%", color = Color3.fromRGB(255, 110, 220) },
	{ key = "GemsHoard", id = 0, name = "Dragon Hoard", gems = 7000, robuxDisplay = 899, badge = "BEST VALUE", color = Color3.fromRGB(255, 196, 56) },
} :: { DevProductDef }

DevProductsConfig.ByKey = {} :: { [string]: DevProductDef }
for _, product in ipairs(DevProductsConfig.List) do
	DevProductsConfig.ByKey[product.key] = product
end

-- ID <= 0 khong bao gio khop: bien lai mang ID 0 khong duoc cap Gems.
function DevProductsConfig.GetById(productId: any): DevProductDef?
	if type(productId) ~= "number" or productId <= 0 then
		return nil
	end
	for _, product in ipairs(DevProductsConfig.List) do
		if product.id == productId then
			return product
		end
	end
	return nil
end

return DevProductsConfig
