local fixture = require('./v3_regression_fixture')
local function eq(a,b,label) assert(a==b,string.format('%s: expected %s, got %s',label,tostring(b),tostring(a))) end
return function(sources)
 local count,failures=0,0
 local function test(name,cb)
  count+=1
  local ok,err=pcall(cb)
  print((if ok then 'PASS ' else 'FAIL ')..name..(if ok then '' else ': '..tostring(err)))
  if not ok then failures+=1 end
 end
 local function tradeFixture()
  local f=fixture(sources)
  f.load('EnchantAndBountyService').Init()
  return f
 end
 for _,flags in ipairs({{soulbound=true},{locked=true},{fishId='lowboss'},{uid='wrong'}}) do
  test('Trident rejects '..next(flags),function()
   local f=tradeFixture(); local entry=f.fish('chosen',flags); f.profile.fishBag={entry}
   f.emit('UnlockExclusiveRod','RelicTrident','chosen')
   eq(f.profile.gems,5000,'no Gems spent'); eq(#f.profile.fishBag,1,'no fish consumed'); eq(f.profile.ownedRods.RelicTrident,nil,'rod not awarded')
  end)
 end
 test('Trident consumes exactly selected UID once',function()
  local f=tradeFixture(); f.profile.fishBag={f.fish('other'),f.fish('chosen')}; f.profile.pinnedFishUids['2']='chosen'
  f.emit('UnlockExclusiveRod','RelicTrident','chosen')
  eq(f.profile.gems,4200,'800 Gems'); eq(#f.profile.fishBag,1,'one consumed'); eq(f.profile.fishBag[1].uid,'other','unselected survives')
  eq(f.profile.pinnedFishUids['2'],nil,'stale pin cleared'); eq(f.profile.ownedRods.RelicTrident,true,'rod awarded')
  f.emit('UnlockExclusiveRod','RelicTrident','chosen'); eq(f.profile.gems,4200,'replay not charged')
 end)
 test('Trident insufficient Gems preserves fish',function()
  local f=tradeFixture(); f.profile.gems=799; f.profile.fishBag={f.fish('chosen')}
  f.emit('UnlockExclusiveRod','RelicTrident','chosen'); eq(#f.profile.fishBag,1,'fish retained'); eq(f.profile.gems,799,'balance retained')
 end)
 test('Bounty accepts explicit Trophy UID and replay gives no reward',function()
  local f=tradeFixture(); f.profile.fishBag={f.fish('other'),f.fish('trophy',{soulbound=true,locked=true,sellValue=0})}
  f.profile.pinnedFishUids['2']='trophy'; f.profile.equippedHotbarSlot=2
  f.emit('TurnInBounty','bounty_deep_boss','trophy')
  eq(#f.profile.fishBag,1,'one consumed'); eq(f.profile.fishBag[1].uid,'other','unselected survives')
  eq(f.profile.gems,5240,'reward once'); eq(f.profile.enchantRelics,3,'relics once'); eq(f.profile.equippedHotbarSlot,1,'held Trophy cleared')
  f.emit('TurnInBounty','bounty_deep_boss','trophy'); eq(f.profile.gems,5240,'no replay Gems'); eq(f.profile.enchantRelics,3,'no replay relics')
 end)
 test('Bounty validates fish and current-cycle island before consume',function()
  local f=tradeFixture(); f.profile.fishBag={f.fish('small',{weight=499.9})}
  f.emit('TurnInBounty','bounty_deep_boss','small'); eq(#f.profile.fishBag,1,'too small retained')
  f.profile.fishBag[1].weight=600; f.profile.unlockedIslands['3']=nil
  f.emit('TurnInBounty','bounty_deep_boss','small'); eq(#f.profile.fishBag,1,'island denied retained'); eq(f.profile.gems,5000,'no reward')
 end)
 for _,method in ipairs({'SellAllFish','SellSingleFish','SellSelectedFish','SellHeldFish'}) do
  test('Gold protection '..method,function()
   local f=fixture(sources); local c=f.load('CurrencyService')
   f.profile.fishBag={f.fish('trophy',{soulbound=true,locked=false,sellValue=999}),f.fish('locked',{locked=true})}
   f.profile.pinnedFishUids['2']='trophy'; f.profile.equippedHotbarSlot=2
   c[method](f.player,if method=='SellSelectedFish' then {'trophy','locked'} else 'trophy')
   eq(#f.profile.fishBag,2,'protected bag retained'); eq(f.profile.gold,10000,'no Gold gained')
  end)
 end
 test('Trophy cannot be unlocked',function()
  local f=fixture(sources); f.profile.fishBag={f.fish('trophy',{soulbound=true,locked=true})}
  f.load('CurrencyService').ToggleLockFish(f.player,'trophy'); eq(f.profile.fishBag[1].locked,true,'still locked')
 end)
 test('Appraise 10.4kg floor 8.9kg preserves tier mutation and syncs record',function()
  local f=fixture(sources)
  f.deps.FishingRoller={RollSizeTierAndWeight=function() return 'Normal',0.1,1 end,RollMutation=function() return 'None',1 end,GetMutationMultiplier=function(m) return if m=='Golden' then 5 else 1 end}
  f.load('EnchantAndBountyService').Init()
  f.profile.fishBag={f.fish('target',{weight=10.4,soulbound=true,sellValue=0})}; f.profile.indexFish.boss=8
  f.emit('AppraiseFish','target'); local entry=f.profile.fishBag[1]
  eq(entry.weight,8.9,'ceil floor'); eq(entry.sizeTier,'Titanic','tier retained'); eq(entry.mutation,'Golden','mutation retained'); eq(entry.sellValue,0,'Trophy unsellable')
  eq(entry.originalValue,1125,'retained tier and mutation value multipliers'); eq(f.event('AppraiseResult').indexFish.boss,8.9,'record emitted immediately')
  f.emit('AppraiseFish','target'); eq(f.event('AppraiseResult').indexFish,nil,'no fake record update')
 end)
 test('Trident Twig effective load stays 17kg',function()
  local f=fixture(sources); eq(f.load('RodsConfig').GetEffectiveStats('RelicTrident',{Twig=true,RelicTrident=true},{}).maxWeight,17,'floor 15 * 1.15')
 end)
 test('Titan cap keeps rolled tier and multiplier',function()
  local f=fixture(sources)
  local util=f.load('Util'); util.PickWeighted=function(items,weight)
   eq(weight(items[1]),items[1].chance*2.5,'Titan boosts large tier odds'); return items[1]
  end
  local tier,kg,mult=f.load('FishingRoller').RollSizeTierAndWeight({minWeight=20000,maxWeight=20000},5750,1.25)
  eq(tier,'Titanic','tier retained'); eq(kg,7187.5,'1.25 cap'); eq(mult,3,'tier value multiplier retained')
 end)
 test('Rebirth shared partition caps 12 with stable priority and overflow',function()
  local f=fixture(sources); local bag={f.fish('old',{soulbound=true,locked=false,originalValue=1}),f.fish('ignored',{locked=false})}
  for i=1,13 do table.insert(bag,f.fish(string.format('locked-%02d',i),{locked=true,originalValue=100})) end
  local helper=f.load('TrophyHelper')
  eq(helper.CompareCandidates(f.fish('z',{originalValue=200}),f.fish('a',{originalValue=100})),true,'original value priority')
  eq(helper.CompareCandidates(f.fish('z',{weight=700}),f.fish('a',{weight=600})),true,'weight priority before UID')
  local kept,overflow,set=helper.PartitionForRebirth(bag)
  eq(#kept,12,'12 cap'); eq(#overflow,2,'overflow'); eq(kept[1].uid,'old','old soulbound first'); eq(kept[2].uid,'locked-01','UID tie order'); eq(set.ignored,nil,'unlocked excluded')
  for _,entry in ipairs(kept) do entry.soulbound=true; entry.locked=true; entry.sellValue=0 end
  local again=helper.PartitionForRebirth(kept); eq(#again,12,'next cycle retains 12')
 end)
 test('Rebirth production handler keeps preview selection and pins across cycles',function()
  local f=fixture(sources)
  f.deps.FishingService={CancelSession=function() end,OnFishCaught=function() end}
  f.load('ProgressionService').Init()
  f.profile.strength=5000000
  f.profile.ownedRods={Twig=true,Bamboo=true,RelicTrident=true}; f.profile.rodId='RelicTrident'
  for i=1,14 do table.insert(f.profile.fishBag,f.fish('fish-'..i,{locked=true,originalValue=i})) end
  f.profile.fishBag[1].soulbound=true
  f.profile.pinnedFishUids={['2']='fish-1',['3']='fish-2'}
  local expected,overflow=f.load('TrophyHelper').PartitionForRebirth(f.profile.fishBag)
  eq(#overflow,2,'preview overflow')
  f.emit('DoRebirth')
  eq(f.profile.rebirths,1,'rebirth executed'); eq(#f.profile.fishBag,12,'server keeps twelve')
  for i,entry in ipairs(f.profile.fishBag) do
   eq(entry.uid,expected[i].uid,'server matches shared preview'); eq(entry.soulbound,true,'soulbound'); eq(entry.locked,true,'locked'); eq(entry.sellValue,0,'zero Gold sale')
  end
  eq(f.profile.pinnedFishUids['2'],'fish-1','kept pin'); eq(f.profile.pinnedFishUids['3'],nil,'overflow pin removed')
  eq(f.profile.ownedRods.RelicTrident,true,'Exclusive retained'); eq(f.profile.ownedRods.Bamboo,nil,'normal reset'); eq(f.profile.rodId,'RelicTrident','Exclusive equipped')
  f.profile.strength=f.load('RebirthConfig').GetStrengthRequirement(1)
  f.emit('DoRebirth'); eq(#f.profile.fishBag,12,'next Rebirth preserves all'); eq(f.profile.rebirths,2,'second cycle')
 end)
 for _,method in ipairs({'SellAllFish','SellSingleFish','SellSelectedFish','SellHeldFish'}) do
  test('Sell positive control '..method,function()
   local f=fixture(sources); f.profile.fishBag={f.fish('normal')}; f.profile.pinnedFishUids['2']='normal'; f.profile.equippedHotbarSlot=2
   f.load('CurrencyService')[method](f.player,if method=='SellSelectedFish' then {'normal'} else 'normal')
   eq(#f.profile.fishBag,0,'ordinary fish sold'); eq(f.profile.gold,10100,'ordinary sale credited')
  end)
 end
 test('Award uses snapshot Strength once and retained Titan value',function()
  local f=fixture(sources); local fishing=f.load('FishingService'); fishing.Init()
  local roller=f.load('FishingRoller'); roller.RollSizeTierAndWeight=function() return 'Titanic',7187.5,3 end
  f.session={rolledFish=f.fishDefs.boss,rolledMutation='None',snapRod={maxWeight=5750},snapMults={strengthMult=2.5,titanWeightFactor=1.25,midasSellBonus=1},snapBait=nil,inWhirlpool=false,islandId=3,waterPos={}}
  f.emit('FishingMinigameStrike','session',1,0.2)
  eq(f.profile.strength,125,'10 * snapshot 2.5 once, current buff 9 ignored'); eq(f.profile.totalStrength,125,'total gain once')
  eq(f.event('FishingCatchResult').strengthGained,25,'display gain'); eq(f.profile.fishBag[1].sizeTier,'Titanic','award retains tier'); eq(f.profile.fishBag[1].originalValue,225,'award uses 3x tier value')
 end)
 print(string.format('V3 regression: %d/%d passed',count-failures,count))
 assert(failures==0,string.format('%d V3 regression failures',failures))
end
