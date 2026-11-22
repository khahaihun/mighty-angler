--!strict
-- ResponsiveScale.luau: Ti le UIScale chung cho HUD va cua so, tinh tu vung man hinh dung duoc (da tru thanh Roblox phia tren).
-- Ham thuan, khong cham Roblox DataModel, de chay duoc trong bo test VM.

local ResponsiveScale = {}

-- Khung thiet ke cua HUD: thanh tien 560 o giua + nhan dao 240 ben trai can ngang >= 1072;
-- cot 7 nut trai (cao 336, canh giua) nam duoi nhan su kien (day o 62) can cao >= 480.
ResponsiveScale.DESIGN_WIDTH = 1180
ResponsiveScale.DESIGN_HEIGHT = 480
ResponsiveScale.MIN_WIDTH_SCALE = 0.62 -- May ngang hep (667) van giu chu doc duoc; HUD da can chinh o muc nay.
ResponsiveScale.MAX_SCALE = 1.08
ResponsiveScale.HARD_MIN_SCALE = 0.45

-- Cua so lon nhat la 650 x 465; cong le de vien va nut dong khong cham mep man hinh.
ResponsiveScale.WINDOW_FIT_WIDTH = 670
ResponsiveScale.WINDOW_FIT_HEIGHT = 480

function ResponsiveScale.Compute(usableWidth: number, usableHeight: number): number
	if usableWidth <= 0 or usableHeight <= 0 then
		return 1
	end
	local byWidth = math.max(usableWidth / ResponsiveScale.DESIGN_WIDTH, ResponsiveScale.MIN_WIDTH_SCALE)
	local scale = math.min(byWidth, usableHeight / ResponsiveScale.DESIGN_HEIGHT, ResponsiveScale.MAX_SCALE)
	-- Man hinh qua thap hoac qua hep: thu nho tiep de cua so khong tran ra ngoai.
	scale = math.min(scale, usableWidth / ResponsiveScale.WINDOW_FIT_WIDTH, usableHeight / ResponsiveScale.WINDOW_FIT_HEIGHT)
	return math.max(scale, ResponsiveScale.HARD_MIN_SCALE)
end

return ResponsiveScale
