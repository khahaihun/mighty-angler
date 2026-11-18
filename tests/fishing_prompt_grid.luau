return function(sources)
 local grid=assert(loadstring(sources.GridWindow))()
 local function rows(top,bottom,first,last)
  local a,b=grid.Rows(10,158,1572,top,bottom)
  assert(a==first and b==last,string.format("window %s..%s got %d..%d",top,bottom,a,b))
 end
 rows(-500,-10,0,-1); rows(1572,1800,0,-1); rows(0,316,0,2)
 rows(316,632,1,4); rows(-100,58,0,1); rows(1500,1800,8,9)
 local vec
 vec=function(x,y,z)
  return setmetatable({X=x,Y=y,Z=z}, {__sub=function(a,b)
   local x1,y1,z1=a.X-b.X,a.Y-b.Y,a.Z-b.Z
   return {Magnitude=math.sqrt(x1*x1+y1*y1+z1*z1)}
  end})
 end
 local root={Position=vec(0,0,0),IsA=function(_,c) return c=="BasePart" end}
 local function prompt(kind,role,pos,radius,island)
  return {Enabled=true,MaxActivationDistance=radius,
   Parent={Position=pos,IsA=function(_,c) return c=="BasePart" end},
   IsA=function(_,c) return c=="ProximityPrompt" end,
   GetAttribute=function(_,k) return ({PromptKind=kind,NpcRole=role,IslandId=island or 1})[k] end}
 end
 local prompts={}
 local island={GetDescendants=function() return prompts end}
 local world={FindFirstChild=function(_,name) if name=="Island_1" then return island end end}
 local env=setmetatable({game={GetService=function() return {FindFirstChild=function() return world end} end}},{__index=getfenv()})
 local fn=assert(loadstring(sources.WorldPromptAccess)); setfenv(fn,env); local access=fn()
 local player={Character={FindFirstChild=function() return root end}}
 for _,kind in ipairs({"NpcCollector","NpcShop","OpenEnchantAltar"}) do
  prompts={prompt(kind,"Shop",vec(0,0,0),14)}
  root.Position=vec(13.99,0,0); assert(access.IsNear(player,1,{[kind]=true}),"inside prompt")
  root.Position=vec(14.01,0,0); assert(not access.IsNear(player,1,{[kind]=true}),"outside prompt")
  root.Position=vec(0,14.01,0); assert(not access.IsNear(player,1,{[kind]=true}),"3D height")
  root.Position=vec(0,0,0); assert(not access.IsNear(player,2,{[kind]=true}),"wrong island")
  prompts[1].Enabled=false; assert(not access.IsNear(player,1,{[kind]=true}),"disabled")
 end
 prompts={prompt("NpcShop",nil,vec(0,0,0),16)}
 assert(not access.IsNear(player,1,{NpcShop=true}),"shop prop is not Kaito")
 prompts={prompt("NpcCollector","Collector",vec(100,5,0),15)}
 root.Position=vec(100,5,14.99); assert(access.IsNear(player,1,{NpcCollector=true}),"override prompt position/radius")
 root.Position=vec(100,5,15.01); assert(not access.IsNear(player,1,{NpcCollector=true}),"override outside")
 print("PASS fishing prompts: live 3D range, override, height, island; grid visible rows + one buffer")
end
