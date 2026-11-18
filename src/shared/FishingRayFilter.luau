--!strict
-- Shared by pointer previews and authoritative casts. Boundary walls still collide with players.
local Players = game:GetService("Players")
local Workspace = game:GetService("Workspace")
local FishingRayFilter = {}
function FishingRayFilter.Create(): RaycastParams
 local params = RaycastParams.new()
 params.FilterType = Enum.RaycastFilterType.Exclude
 params.IgnoreWater = false
 local exclude: { Instance } = {}
 for _, player in ipairs(Players:GetPlayers()) do
  if player.Character then table.insert(exclude, player.Character) end
 end
 for _, name in ipairs({"OceanWhirlpools", "ClientRenderedPets"}) do
  local folder = Workspace:FindFirstChild(name)
  if folder then table.insert(exclude, folder) end
 end
 local world = Workspace:FindFirstChild("MightyWorld")
 if world then
  for _, island in ipairs(world:GetChildren()) do
   for _, child in ipairs(island:GetChildren()) do
    if child:GetAttribute("FishingRayIgnore") == true then table.insert(exclude, child) end
   end
  end
 end
 params.FilterDescendantsInstances = exclude
 return params
end
return FishingRayFilter
