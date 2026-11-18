local function node(name)
 return setmetatable({Name=name,WaitForChild=function(_,k) return node(k) end},{__index=function(_,k) return node(k) end})
end
return function(sources)
 local now, alive, mounted = 0,true,false
 local handlers, sent, timers = {},{},{}
 local names=setmetatable({},{__index=function(_,k) return k end})
 local net={ClientToServer=names,ServerToClient=names,FireServer=function(event,...)
  table.insert(sent,{event=event,args={...}})
 end,OnClientEvent=function(event,fn) handlers[event]=fn end}
 local mini={IsOpen=function() return false end,OnOpenStateChanged=function() end,Mount=function() mounted=true end,ForceClose=function() end,SyncRoundFromServer=function() end}
 local player={Character={FindFirstChildOfClass=function() return {Health=if alive then 100 else 0} end}}
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
 assert(casts()==3 and not controller.IsAutoFishEnabled(),"dead character stops with no cast")
 print("PASS fishing client: authoritative readyAt, OFF-ON, duplicate close/results, manual cancel, unequip and death")
end
