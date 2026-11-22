--!strict
-- SkyBuilder.luau: Bau troi, may dong va tia nang. Chi dung doi tuong co san cua Roblox, khong them asset ngoai.
-- Neu Chu du an da dat san Sky/Clouds/SunRays trong Studio thi giu nguyen cua ho.

local Lighting = game:GetService("Lighting")
local Workspace = game:GetService("Workspace")

local SkyBuilder = {}

function SkyBuilder.Apply()
	if not Lighting:FindFirstChildOfClass("Sky") then
		-- Dung bo anh troi mac dinh cua Roblox; khi co skybox duoc duyet chi can gan 6 ID anh vao doi tuong nay.
		local sky = Instance.new("Sky")
		sky.Name = "MightySky"
		sky.SunAngularSize = 24
		sky.MoonAngularSize = 12
		sky.StarCount = 3000
		sky.Parent = Lighting
	end

	if not Lighting:FindFirstChildOfClass("SunRaysEffect") then
		local rays = Instance.new("SunRaysEffect")
		rays.Name = "MightySunRays"
		rays.Intensity = 0.12
		rays.Spread = 0.8
		rays.Parent = Lighting
	end

	-- Clouds chi hoat dong khi nam trong Workspace.Terrain.
	local terrain = Workspace.Terrain
	if not terrain:FindFirstChildOfClass("Clouds") then
		local clouds = Instance.new("Clouds")
		clouds.Name = "MightyClouds"
		clouds.Cover = 0.56
		clouds.Density = 0.7
		clouds.Color = Color3.fromRGB(255, 255, 255)
		clouds.Parent = terrain
	end
end

return SkyBuilder
