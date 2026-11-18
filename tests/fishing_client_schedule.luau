local function node(name)
 return setmetatable({Name=name,WaitForChild=function(_,k) return node(k) end},{__index=function(_,k) return node(k) end})
end
return function(sources)
 local now, alive, mounted, characterAdded = 0,true,false,nil
 local handlers, sent, timers = {},{},{}
 local names=setmetatable({},{__index=function(_,k) return k end})
 local net={ClientToServer=names,ServerToClient=names,FireServer=function(event,...)
  table.insert(sent,{event=event,args={...}})
 end,OnClientEvent=function(event,fn) handlers[event]=fn end}
 local mini={IsOpen=function() return false end,OnOpenStateChanged=function() end,Mount=function() mounted=true end,ForceClose=function() end,SyncRoundFromServer=function() end}
 local player={CharacterAdded={Connect=function(_,cb) characterAdded=cb end},Character={FindFirstChildOfClass=function() return {Health=if alive then 100 else 0} end}}
 local services={Players={LocalPlayer=player},ReplicatedStorage=node("ReplicatedStorage"),Workspace={GetServerTimeNow=function() return now end},TweenService={}}
 local animation=setmetatable({},{__index=function() return function() end end})
 local env=setmetatable({script=node("script"),game={GetService=function(_,k) return services[k] end},
  require=function(mod) return ({Net=net,AnimationController=animation,MinigameBar=mini})[mod.Name] end,
  task={spawn=function(fn,...) fn(...) end,delay=function(sec,fn) table.insert(timers,{at=now+sec,fn=fn}) end}}, {__index=getfenv()})
 local fn=assert(loadstring(sources.FishingController)); setfenv(fn,env); local controller=fn(); controller.Init({}); assert(mounted)
 local function advance(t)
  now=t
  local old=timers; timers={}
  for _,timer in ipairs(old) do if timer.at<=now then timer.fn() else table.insert(timers,timer) end end
 end
 local function casts()
  local n=0; for _,event in ipairs(sent) do if event.event=="FishingCastWithAim" then n+=1 end end; return n
 end
 local function toggleReply(ready)
  controller.ToggleAutoFish()
  local request=sent[#sent]
  handlers.FishingAutoState({enabled=request.args[1],readyAt=ready,requestId=request.args[2]})
 end
 toggleReply(0); advance(0); assert(casts()==1)
 handlers.FishingCastStarted({sessionId="first"})
 handlers.FishingSessionClosed({sessionId="first",reason="Win",readyAt=1.1,autoEnabled=true})
 controller.ToggleAutoFish() -- OFF cancels pending timer.
 toggleReply(1.1) -- ON must retain server cooldown.
 advance(1.099); assert(casts()==1)
 advance(1.1); assert(casts()==2,"OFF-ON while cooling schedules exactly once")
 handlers.FishingCastStarted({sessionId="second"})
 handlers.FishingSessionClosed({sessionId="second",reason="Miss",readyAt=2.2,autoEnabled=true})
 handlers.FishingSessionClosed({sessionId="second",reason="Miss",readyAt=2.2,autoEnabled=true})
 handlers.FishingCatchResult({success=false}); handlers.FishingCatchResult({success=false})
 advance(2.2); assert(casts()==3,"duplicate result/close does not duplicate recast")
 handlers.FishingCastStarted({sessionId="third"})
 handlers.FishingSessionClosed({sessionId="third",reason="Win",readyAt=3.3,autoEnabled=true})
 controller.CancelCurrentCast(); advance(4); assert(casts()==3,"manual cancel invalidates cooling timer")
 toggleReply(5); handlers.HotbarUpdated({equippedSlot=0}); advance(6)
 assert(casts()==3 and not controller.IsAutoFishEnabled(),"unequip never auto-equips on old timer")
 handlers.HotbarUpdated({equippedSlot=1}); toggleReply(6); alive=false; advance(6)
 assert(casts()==3 and controller.IsAutoFishEnabled(),"death preserves ON without casting")
 alive=true; characterAdded(); advance(6.25); assert(casts()==4,"respawn resumes exactly once")
 -- Preserve intent through both kinds of server reset, during a cast and during cooldown.
 local count=4
 for _,reason in ipairs({"IslandChange","Rebirth","Died"}) do
  handlers.FishingCastStarted({sessionId=reason})
  handlers.FishingSessionClosed({sessionId=reason,reason=reason,readyAt=now+1.1,autoEnabled=true,requestId=999})
  handlers.FishingStateReset({reason=reason,requestId=999,autoEnabled=true,readyAt=now+1.1})
  handlers.FishingStateReset({reason=reason,requestId=999,autoEnabled=true,readyAt=now+1.1})
  advance(now+1.1); count+=1; assert(casts()==count,"transition resumes one cast: "..reason)
 end
 -- Turn on while the old manual close (made before server saw ON) is in flight.
 controller.ToggleAutoFish() -- OFF
 handlers.FishingCastStarted({sessionId="manual"})
 controller.ToggleAutoFish() -- ON, ack intentionally delayed
 local request=sent[#sent]; local id=request.args[2]
 handlers.FishingSessionClosed({sessionId="manual",reason="Win",readyAt=now+1.1,autoEnabled=false,requestId=id-1})
 assert(controller.IsAutoFishEnabled(),"old manual close cannot erase newer ON")
 handlers.FishingAutoState({enabled=false,readyAt=now+1.1,requestId=id-1})
 assert(controller.IsAutoFishEnabled(),"stale ACK cannot erase ON")
 local before=#sent
 advance(now+1.1)
 assert(#sent>before and sent[#sent].event=="SetAutoFish" and sent[#sent].args[2]==id,"dropped rate-limited toggle retries same id")
 handlers.FishingAutoState({enabled=true,readyAt=now,requestId=id}); advance(now)
 count+=1; assert(casts()==count,"latest ACK yields one cast")
 print("PASS fishing client: authoritative readyAt, OFF-ON, duplicate close/results, manual cancel, unequip and death")
end
