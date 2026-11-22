-- Production loader: fake only Roblox/service boundaries, never rewrite module source.
local function node(name)
 local t = {Name = name}
 function t:WaitForChild(key) return self[key] end
 return setmetatable(t, {__index = function(self, key) local v = node(key); rawset(self,key,v); return v end})
end
local function noop() end
return function(sources)
 local f = {handlers = {}, events = {}, mults = {strengthMult=9, titanWeightFactor=1.25, mutationMult=1, midasSellBonus=1, sellMult=1}}
 local vectorMt = {}
 local function vec(x,y,z) return setmetatable({X=x,Y=y,Z=z},vectorMt) end
 vectorMt.__add = function(a,b) return vec(a.X+b.X,a.Y+b.Y,a.Z+b.Z) end
 vectorMt.__index = function(v,k) if k == 'Magnitude' then return math.sqrt(v.X^2+v.Y^2+v.Z^2) end end
 local function signal() return {Connect=function() return {Disconnect=noop} end} end
 f.player = {UserId=1,DisplayName='Regression',Character={FindFirstChild=function() return {Position=vec(-11,0,48.2),IsA=function() return true end} end}}
 f.profile = {gold=10000,gems=5000,strength=100,totalStrength=100,rebirths=0,currentIsland=3,unlockedIslands={['1']=true,['2']=true,['3']=true},ownedRods={Twig=true},rodId='Twig',rodEnchants={},fishBag={},pinnedFishUids={},equippedHotbarSlot=1,enchantRelics=0,indexFish={},indexPets={},bait={},stats={goldEarned=0,fishCaught=0,rareCaught=0,bossCaught=0,mutationsCaught=0},claimedAchievements={},lastDailyClaimDay=0}
 local strings=setmetatable({}, {__index=function(_,k) return k end})
 local deps = {
 Types={},
 Net={ClientToServer=strings,ServerToClient=strings,OnServerEvent=function(id,cb) f.handlers[id]=cb end,FireClient=function(_,id,payload) table.insert(f.events,{id=id,payload=payload}) end,FireAllClients=noop},
 DataService={Get=function() return f.profile end,IsTransactionLocked=function() return f.locked == true end,MarkDirty=noop,SyncLeaderstats=noop,OnProfileLoaded=noop},
 BuffAggregator={GetMultipliers=function() return f.mults end},
 PerkService={HasGamepass=function() return false end,ArePaidRandomItemsRestricted=function() return false end},
 ShopAndItemsService={PushInventory=noop,SyncCharacterHandVisuals=noop,HandleEquipRod=noop,GrantPotion=noop,ConsumeGivenBaitOnCatch=noop,OnHotbarSlotChanged=noop},
 WorldPromptAccess={IsNear=function() return f.nearPrompt ~= false end},
 ProfileMigrator={GetFishDef=function(id) return f.fishDefs[id] end},
 Islands={ById={[3]={centerPosition=vec(0,0,0)}}},
 RodVisuals={ClearBobber=noop},PetAndFishVisuals={SpawnCaughtFishLeap=noop},WhirlpoolManager={},
 GymService={OnGymRepCompleted=noop},IslandService={TeleportCharacterToIsland=noop},PetsService={OnPetHatched=noop},PlayerVisuals={RefreshRankAndAura=noop},
 AchievementsConfig={List={},DailyQuests={},QuestsById={}},PotionsConfig={},
 }
 f.fishDefs={boss={id='boss',name='Test Boss',rarity='Boss',islandId=3,minWeight=1,maxWeight=20000,baseValue=100,strengthReward=10},lowboss={id='lowboss',name='Early Boss',rarity='Boss',islandId=2,minWeight=1,maxWeight=30,baseValue=100}}
 deps.FishingSessionManager={HandleStrike=function(p,_,_,_,award) award(p,f.session) end,Get=function() return nil end,CloseSessionOnce=noop}
 local shared=node('Shared')
 local players={PlayerAdded=signal(),PlayerRemoving=signal(),GetPlayers=function() return {f.player} end}
 f.player.Parent=players
 local services={ReplicatedStorage={WaitForChild=function() return shared end},Players=players,Workspace={},HttpService={GenerateGUID=function() return 'caught-uid' end}}
 local env=setmetatable({game={GetService=function(_,k) assert(services[k],k); return services[k] end},Color3={fromRGB=function() return {} end},Vector3={new=vec},task={spawn=function(cb,...) cb(...) end}}, {__index=getfenv()})
 function f.load(name)
  if deps[name] then return deps[name] end
  local chunk=assert(loadstring(assert(sources[name],name),'@'..name))
  setfenv(chunk,setmetatable({script=node(name),require=function(m) return f.load(m.Name) end},{__index=env}))
  local result=chunk(); deps[name]=result; return result
 end
 function f.emit(id,...) assert(f.handlers[id],id)(f.player,...) end
 function f.event(id) for i=#f.events,1,-1 do if f.events[i].id==id then return f.events[i].payload end end end
 function f.fish(uid,overrides)
  local entry={uid=uid,fishId='boss',weight=600,sizeTier='Titanic',mutation='Golden',locked=false,soulbound=false,originalValue=100,sellValue=100,midasBonus=1}
  for k,v in pairs(overrides or {}) do entry[k]=v end
  return entry
 end
 f.deps=deps
 return f
end
