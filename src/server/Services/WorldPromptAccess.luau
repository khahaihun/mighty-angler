--!strict
-- Resolve the live prompt, including NPC overrides; never authorize from design coordinates.
local Workspace = game:GetService("Workspace")
local WorldPromptAccess = {}

function WorldPromptAccess.IsNear(player: Player, islandId: number, allowedKinds: { [string]: boolean }): boolean
 local char = player.Character
 local root = if char then char:FindFirstChild("HumanoidRootPart") else nil
 if not root or not root:IsA("BasePart") then return false end
 local world = Workspace:FindFirstChild("MightyWorld")
 local island = if world then world:FindFirstChild("Island_" .. tostring(islandId)) else nil
 if not island then return false end
 for _, item in ipairs(island:GetDescendants()) do
  if item:IsA("ProximityPrompt") and item.Enabled and item:GetAttribute("IslandId") == islandId then
   local kind = item:GetAttribute("PromptKind")
   -- Shop scenery has its own prompt; Enchant is authorized only by the live Kaito NPC.
   local correctNpc = kind ~= "NpcShop" or item:GetAttribute("NpcRole") == "Shop"
   local parent = item.Parent
   local pos: Vector3? = nil
   if parent and parent:IsA("Attachment") then pos = parent.WorldPosition
   elseif parent and parent:IsA("BasePart") then pos = parent.Position
   elseif parent and parent:IsA("Model") and parent.PrimaryPart then pos = parent.PrimaryPart.Position end
   if type(kind) == "string" and allowedKinds[kind] and correctNpc and pos
    and (root.Position - pos).Magnitude <= item.MaxActivationDistance then return true end
  end
 end
 return false
end

return WorldPromptAccess
