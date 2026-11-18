local function node(name)
 return setmetatable({Name=name,WaitForChild=function(_,key) return node(key) end}, {__index=function(_,key) return node(key) end})
end
local vec
vec=function(x,y,z)
 return setmetatable({X=x,Y=y,Z=z},{__index=function(a,k)
  if k=="Magnitude" then return math.sqrt(a.X*a.X+a.Y*a.Y+a.Z*a.Z) end
  if k=="Unit" then local m=math.sqrt(a.X*a.X+a.Y*a.Y+a.Z*a.Z); return vec(a.X/m,a.Y/m,a.Z/m) end
 end,__add=function(a,b) return vec(a.X+b.X,a.Y+b.Y,a.Z+b.Z) end,
 __sub=function(a,b) return vec(a.X-b.X,a.Y-b.Y,a.Z-b.Z) end,
 __mul=function(a,b) return vec(a.X*b,a.Y*b,a.Z*b) end})
end
return function(sources)
 local now, pro, awards, rayCount = 100, false, 0, 0
 local events, timers = {}, {}
 local eventNames=setmetatable({},{__index=function(_,k) return k end})
 local net={ServerToClient=eventNames,ClientToServer=eventNames,
  FireClient=function(_,event,payload) table.insert(events,{event=event,payload=payload}) end}
 local config={FISHING_MAX_WATER_DIST=80,AUTO_FISH_FREE_RECAST_SEC=1.1,AUTO_FISH_PRO_RECAST_SEC=.45,MINIGAME_MAX_WIDTH=.68}
 local water={Size=vec(200,2,200),Position=vec(0,-1,0),IsA=function(_,c) return c=="BasePart" end}
 local wall={GetAttribute=function() return true end}
 local island={FindFirstChild=function(_,k) if k=="FishingWater" then return water end end,GetChildren=function() return {wall} end}
 local world={FindFirstChild=function() return island end,GetChildren=function() return {island} end}
 local rayHit={Material="Water",Position=vec(0,0,20)}
 local workspace={GetServerTimeNow=function() return now end,
  FindFirstChild=function(_,k) if k=="MightyWorld" then return world end end,
  Raycast=function() rayCount+=1; return rayHit end}
 local root={Position=vec(0,4,0),CFrame={LookVector=vec(0,0,1)},IsA=function(_,c) return c=="BasePart" end}
 local p={Character={FindFirstChild=function() return root end}}
 local services={Workspace=workspace,ReplicatedStorage=node("ReplicatedStorage"),Players={GetPlayers=function() return {p} end,PlayerRemoving={Connect=function() end}}}
 local uid=0
 local cache={Types={},Net=net,GameConfig=config,PerkService={HasGamepass=function() return pro end},
  Util={NewUid=function() uid+=1; return tostring(uid) end,TriangleBounce=function() return .5 end},RodVisuals={ClearBobber=function() end}}
 local testMath=table.clone(math); testMath.random=function() return .5 end
 local env=setmetatable({game={GetService=function(_,k) return services[k] end},Vector3={new=vec},typeof=function(v) return if type(v)=="table" and v.X then "Vector3" else type(v) end,
  RaycastParams={new=function() return {} end},Enum={RaycastFilterType={Exclude="Exclude"},Material={Water="Water"}},
  os={clock=function() return now end},math=testMath,task={delay=function(sec,fn) table.insert(timers,{at=now+sec,fn=fn}) end}}, {__index=getfenv()})
 function env.require(mod)
  if cache[mod.Name] then return cache[mod.Name] end
  local fn=assert(loadstring(sources[mod.Name],"@"..mod.Name)); setfenv(fn,setmetatable({script=node("script")},{__index=env})); cache[mod.Name]=fn(); return cache[mod.Name]
 end
 local filter=env.require(node("FishingRayFilter"))
 local params=filter.Create(); assert(table.find(params.FilterDescendantsInstances,wall),"boundary explicitly excluded")
 local roller=env.require(node("FishingRoller"))
 local pos,bounce=roller.ValidateAimedWaterPoint(p,1,vec(0,0,20)); assert(pos==rayHit.Position and bounce==nil)
 rayHit={Material="Wood",Position=vec(0,2,10)}
 pos,bounce=roller.ValidateAimedWaterPoint(p,1,vec(0,0,20)); assert(pos==nil and bounce==rayHit.Position,"actual obstacle used for bounce")
 local before=rayCount; roller.ValidateAimedWaterPoint(p,1,vec(0,100,20)); roller.ValidateAimedWaterPoint(p,1,vec(0,0,500)); assert(rayCount==before,"sky/range fail before ray")
 assert(roller.FindWaterCastPoint(p,1)==nil,"auto cannot treat projected water under land as water")
 rayHit={Material="Water",Position=vec(0,0,20)}; assert(roller.FindWaterCastPoint(p,1)~=nil,"auto shares water validation")
 local manager=env.require(node("FishingSessionManager"))
 local state=env.require(node("FishingCastState"))
 for _,rarity in ipairs({"Rare","Epic","Boss"}) do
  state.SetAuto(p,true)
  local sess=manager.CreateWaitingSession(p,1,vec(0,0,20),false,"AutoFree",{},nil,{minigameWidthBonus=0,minigameSpeedDivisor=1})
  manager.BeginMinigame(p,sess,{rarity=rarity,name="Fish"},"None")
  local start=now
  for r=1,sess.rounds do
   local elapsed=if r==sess.rounds then sess.timeoutSec-.05 else r*.1
   now=start+elapsed+.2
   manager.HandleStrike(p,sess.sessionId,r,elapsed,function() awards+=1 end)
  end
  assert(manager.Get(p)==nil,"last valid strike in grace wins")
  local count=#events
  manager.HandleStrike(p,sess.sessionId,sess.rounds,sess.timeoutSec-.05,function() awards+=1 end)
  manager.CloseSessionOnce(p,sess.sessionId,"Timeout",false)
  assert(#events==count,"late duplicate closes once")
  assert(not state.CanAutoCast(p),"cooldown starts on close")
  now+=1.099; assert(not state.CanAutoCast(p)); now+=.0011; assert(state.CanAutoCast(p))
 end
 assert(awards==3,"one fish for each 1/2/3 round session")
 pro=true; state.Close(p,"pro","Timeout"); now+=.449; assert(not state.CanAutoCast(p)); now+=.0011; assert(state.CanAutoCast(p))
 state.Close(p,"cancel","Unequip"); now+=2; assert(not state.CanAutoCast(p),"unequip stops auto")
 print("PASS fishing rays/first hit/Auto, server 1/2/3 rounds at 200ms, atomic close and Free/Pro cooldown")
end
