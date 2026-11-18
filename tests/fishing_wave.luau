return function(sources)
 local function node(name)
  return setmetatable({Name=name, WaitForChild=function(_, key) return node(key) end}, {__index=function(_, key) return node(key) end})
 end
 local clock, render, input, sends = 0, nil, nil, 0
 local function signal(setter)
  return {Connect=function(_, fn) setter(fn); return {Disconnect=function() end} end}
 end
 local config = {SizeTiers={{name="Titanic",chance=1,weightMult=5,valueMult=4}}}
 local util = {PickWeighted=function(items) return items[1] end, TriangleBounce=function() return 0.5 end}
 local services = {
  ReplicatedStorage=node("ReplicatedStorage"), Players={}, Workspace={},
  RunService={RenderStepped=signal(function(fn) render=fn end)},
  UserInputService={InputBegan=signal(function(fn) input=fn end)},
 }
 local env = setmetatable({game={GetService=function(_, name) return services[name] end},
  script=node("script"), os={clock=function() return clock end},
  Enum={KeyCode={Space="Space"},UserInputType={MouseButton1="Mouse"}},
  require=function(mod) return ({Types={}, Util=util, GameConfig=config, Theme={}})[mod.Name] end,
 },{__index=getfenv()})
 local function load(name)
  local fn=assert(loadstring(sources[name], "@"..name)); setfenv(fn,env); return fn()
 end
 local roller=load("FishingRoller")
 local fish={minWeight=5,maxWeight=22}
 for _, max in ipairs({10,17}) do
  local tier, kg, value=roller.RollSizeTierAndWeight(fish,max,1)
  assert(kg==22 and tier=="Titanic" and value==4, "ordinary cap must preserve 22.0kg and tier")
 end
 local tier, kg, value=roller.RollSizeTierAndWeight(fish,17,1.45)
 assert(kg==21.2 and tier=="Titanic" and value==4, "Titan 21.2kg cap retains tier/value")
 local mini=load("MinigameBar")
 -- Mount is intentionally skipped: Start and server acknowledgement are real module paths.
 for _, rounds in ipairs({1,2,3}) do
  clock=0
  mini.Start({sessionId="session",fishName="Fish",rarity="Rare",mutation="None",rounds=rounds,zoneWidth=.3,zoneCenters={.5,.5,.5},speed=1,timeoutSec=5.5+2*rounds})
  local limit=5.5+2*rounds
  clock=limit+.001; render()
  assert(mini.IsOpen(), "deadline waits for server result")
  mini.SyncRoundFromServer("session",2)
  clock=limit+2; render()
  assert(mini.IsOpen(), "late ack cannot locally close the session")
  mini.ForceClose(); assert(not mini.IsOpen())
 end
 print("PASS fishing wave: ordinary/Titan caps and 1/2/3 round server-owned close")
end
