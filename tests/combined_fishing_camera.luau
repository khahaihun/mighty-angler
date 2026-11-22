-- Integration of merged production client scheduling, server intent state, camera focus and odds.
local function node(name)
 return setmetatable({Name=name,WaitForChild=function(_,k) return node(k) end},{__index=function(_,k) return node(k) end})
end
return function(sources)
 local now,alive,casts=1000,true,0
 local timers,handlers={},{}
 local miniOpen,miniChanged=false,nil
 local characterAdded
 local player={CharacterAdded={Connect=function(_,cb) characterAdded=cb end},Character={FindFirstChildOfClass=function() return {Health=if alive then 100 else 0} end}}
 local camera={FieldOfView=70}
 local workspace={CurrentCamera=camera,GetServerTimeNow=function() return now end,GetPropertyChangedSignal=function() return {Connect=function() end} end}
 local mini={IsOpen=function() return miniOpen end,OnOpenStateChanged=function(cb) miniChanged=cb end,Mount=function() end,SyncRoundFromServer=function() end}
 function mini.Start() miniOpen=true; miniChanged(true) end
 function mini.ForceClose() miniOpen=false; miniChanged(false) end
 local names=setmetatable({},{__index=function(_,k) return k end})
 local serverState
 local net={ClientToServer=names,ServerToClient=names,OnClientEvent=function(id,cb) handlers[id]=cb end,
  FireClient=function(_,id,payload) assert(handlers[id],id)(payload) end}
 function net.FireServer(id,...)
  if id=='SetAutoFish' then local enabled,requestId=...; serverState.ApplyRequest(player,enabled,requestId); serverState.Reply(player)
  elseif id=='FishingCastWithAim' then assert(serverState.CanAutoCast(player),'cast before server ready'); casts+=1
  elseif id=='FishingCancel' then serverState.SetAuto(player,false); serverState.Reset(player,'ManualCancel') end
 end
 local services={Players={LocalPlayer=player},ReplicatedStorage=node('ReplicatedStorage'),Workspace=workspace,
  TweenService={Create=function(_,target,_,props) return {Cancel=function() end,Play=function() target.FieldOfView=props.FieldOfView end} end}}
 local modules={Net=net,MinigameBar=mini,AnimationController=setmetatable({},{__index=function() return function() end end}),PerkService={HasGamepass=function() return false end},GameConfig={AUTO_FISH_FREE_RECAST_SEC=1.1,AUTO_FISH_PRO_RECAST_SEC=.45,MANUAL_CAST_MIN_INTERVAL_SEC=.45}}
 local env=setmetatable({script=node('script'),game={GetService=function(_,k) return services[k] end},
  os={clock=function() return now-999 end},TweenInfo={new=function() end},Enum={EasingStyle={Quad=0},EasingDirection={Out=0}},
  task={spawn=function(cb,...) cb(...) end,delay=function(sec,cb) table.insert(timers,{at=now+sec,cb=cb}) end}}, {__index=getfenv()})
 function env.require(ref)
  if modules[ref.Name] then return modules[ref.Name] end
  local fn=assert(loadstring(assert(sources[ref.Name],ref.Name),'@'..ref.Name)); setfenv(fn,env)
  modules[ref.Name]=fn(); return modules[ref.Name]
 end
 local focus=env.require(node('CameraFocusController'))
 serverState=env.require(node('FishingCastState'))
 local controller=env.require(node('FishingController')); controller.Init({})
 local function advance(t)
  now=t
  local ready=timers; timers={}
  for _,timer in ipairs(ready) do if timer.at<=now then timer.cb() else table.insert(timers,timer) end end
 end
 controller.ToggleAutoFish(); advance(now); assert(casts==1,'one initial cast')
 for _,reason in ipairs({'IslandChange','Rebirth','Died'}) do
  handlers.FishingCastStarted({sessionId=reason})
  handlers.FishingMinigamePrompt({sessionId=reason})
  assert(camera.FieldOfView==64,'minigame focus')
  focus.SetTalking(true); assert(camera.FieldOfView==62,'dialogue priority')
  serverState.Close(player,reason,reason); serverState.Reset(player,reason); serverState.Reset(player,reason)
  assert(camera.FieldOfView==62,'transition closes minigame without losing dialogue')
  focus.SetTalking(false); assert(camera.FieldOfView==70,'camera restored')
  local before=casts
  if reason=='Died' then alive=false end
  advance(now+1.099); assert(casts==before,'server cooldown preserved')
  advance(now+.001)
  if reason=='Died' then
   assert(casts==before,'no cast while dead'); alive=true; characterAdded(); advance(now+.25)
  end
  assert(casts==before+1,'exactly one resume for '..reason)
  advance(now); assert(casts==before+1,'duplicate reset did not create another cast')
 end
 handlers.FishingCastStarted({sessionId='manual-cancel-window'})
 serverState.Close(player,'manual-cancel-window','Rebirth')
 controller.CancelCurrentCast(); local before=casts
 advance(now+5); assert(casts==before and not controller.IsAutoFishEnabled(),'manual cancel defeats pending transition timer')
 assert(camera.FieldOfView==70,'manual cancel leaves camera restored')
 -- Real shared odds are exercised in the same runner as merged ray/hold/camera scheduling.
 local f=require('./v3_regression_fixture')(sources)
 local odds,roller,util=f.load('OddsCalculator'),f.load('FishingRoller'),f.load('Util')
 local pool={fishPool={{id='rare',rarity='Rare',minRodPower=1,minWeight=1,weightChance=20},{id='boss',rarity='Boss',minRodPower=2,minWeight=20,weightChance=5}}}
 for _,wp in ipairs({false,true}) do
  local candidates=roller.GetEligibleCandidates(pool,2,50)
  local weights={}; local original=util.PickWeighted
  util.PickWeighted=function(items,weight) for _,fish in ipairs(items) do weights[fish.id]=weight(fish) end; return items[1] end
  roller.RollFishSpecies(nil,pool,candidates,{luckMult=2,bossChanceMult=1.5},wp)
  util.PickWeighted=original
  local total=weights.rare+weights.boss
  for _,entry in ipairs(odds.ComputeFishOdds(pool,2,50,2,1.5,wp)) do
   assert(math.abs(entry.effectivePct-weights[entry.fish.id]/total*100)<1e-8,'UI odds equal production roll weights')
  end
 end
 print('PASS combined integration: real server intent + client transitions, manual cancel, server clock, camera overlap, shared roll/UI odds')
end
