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
 local config={FISHING_MAX_WATER_DIST=80,AUTO_FISH_FREE_RECAST_SEC=1.1,AUTO_FISH_PRO_RECAST_SEC=.45,MANUAL_CAST_MIN_INTERVAL_SEC=.45,MINIGAME_MAX_WIDTH=.68}
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
 local signal={Connect=function() end}
 local services={Workspace=workspace,ReplicatedStorage=node("ReplicatedStorage"),Players={GetPlayers=function() return {p} end,PlayerAdded=signal,PlayerRemoving=signal}}
 p.Parent=services.Players
 local uid=0
 local cache={Types={},OddsCalculator={},Net=net,GameConfig=config,PerkService={HasGamepass=function() return pro end},
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
 state.Close(p,"manual","Win"); assert(events[#events].payload.manualReadyAt==now+.45,"client is told when manual casting reopens")
 assert(not state.CanManualCast(p),"manual cast waits after a session closes")
 now+=.449; assert(not state.CanManualCast(p)); now+=.0011; assert(state.CanManualCast(p),"manual cast reopens after the minimum interval")
 state.Close(p,"cancel","Unequip"); now+=2; assert(not state.CanAutoCast(p),"unequip stops auto")
 for _,reason in ipairs({"IslandChange","Rebirth","Died"}) do
  state.SetAuto(p,true); state.Close(p,"transition",reason); now+=2
  assert(state.CanAutoCast(p),"transition retains server intent "..reason)
  state.Reset(p,reason); assert(state.CanAutoCast(p),"cooling reset retains server intent")
 end
 assert(state.ApplyRequest(p,true,10)); assert(not state.ApplyRequest(p,false,9)); assert(not state.ApplyRequest(p,true,10))
 assert(state.CanAutoCast(p),"stale/duplicate intent cannot turn OFF or restart")
 local handlers={}
 net.OnServerEvent=function(event,callback) handlers[event]=callback end
 local loaded
 local locked=true
 local profile={fishBag={},stats={fishCaught=0},indexFish={}}
 cache.DataService={Get=function() return profile end,IsTransactionLocked=function() return locked end,OnProfileLoaded=function(fn) loaded=fn end}
 cache.CurrencyService={AddStrength=function() error("must not grant Strength while locked") end}
 cache.ShopAndItemsService={OnHotbarSlotChanged=function() end,SyncCharacterHandVisuals=function() end}
 cache.BuffAggregator={}; cache.BountiesConfig={}; cache.Islands={}; cache.RodsConfig={}; cache.PetAndFishVisuals={}; cache.WhirlpoolManager={}
 local service=env.require(node("FishingService")); service.Init()
 for _,reason in ipairs({"IslandChange","Rebirth","Died"}) do
  state.SetAuto(p,true)
  manager.CreateWaitingSession(p,1,vec(0,0,20),false,"AutoFree",{},nil,{})
  service.CancelSession(p,false,reason); now+=2
  assert(state.CanAutoCast(p),"real CancelSession retains ON for "..reason)
  service.CancelSession(p,false,reason)
  assert(state.CanAutoCast(p),"CancelSession while cooling retains ON")
 end
 -- Execute the real registered minigame handler and its real reward callback at the write gate.
 for _,mode in ipairs({"read-only","closing","profile removed"}) do
  local saved=profile
  if mode=="profile removed" then profile=nil end
  local sess=manager.CreateWaitingSession(p,1,vec(0,0,20),false,"AutoFree",{},nil,{minigameWidthBonus=0,minigameSpeedDivisor=1})
  manager.BeginMinigame(p,sess,{rarity="Rare",name="Fish"},"None")
  now+=.1
  handlers.FishingMinigameStrike(p,sess.sessionId,1,.1)
  assert(#saved.fishBag==0 and saved.stats.fishCaught==0 and next(saved.indexFish)==nil,"award gate preserves bag/stats/index: "..mode)
  profile=saved
 end
 local died,added
 local humanoid={Health=100,IsA=function(_,k) return k=="Humanoid" end,Died={Connect=function(_,fn) died=fn end}}
 p.Character.FindFirstChildOfClass=function() return humanoid end
 p.CharacterAdded={Connect=function(_,fn) added=fn end}
 env.task.spawn=function(fn,...) fn(...) end; env.task.wait=function() end
 loaded(p); assert(died and added)
 state.SetAuto(p,true); died(); now+=2; assert(state.CanAutoCast(p),"actual Humanoid.Died keeps ON")
 added(p.Character); assert(state.CanAutoCast(p),"server CharacterAdded does not erase ON")
 -- Real cast handler: an auto-clicker re-casting by hand right after a catch is refused; Auto-Fish intent survives.
 locked=false; profile.equippedHotbarSlot=1; state.SetAuto(p,true); state.Close(p,"spam","Win")
 handlers.FishingCastWithAim(p,{castMode="Manual",hitWater=true,targetPos=vec(0,0,20),holdRatio=.55})
 assert(manager.Get(p)==nil,"manual cast inside the cooldown opens no session")
 assert(events[#events].event=="FishingStateReset" and events[#events].payload.reason=="CastCooldown","client is reset, not left hanging")
 assert(events[#events].payload.autoEnabled==true,"manual cooldown refusal keeps Auto-Fish ON")
 print("PASS fishing rays/first hit/Auto, server 1/2/3 rounds at 200ms, atomic close and Free/Pro cooldown")
end
