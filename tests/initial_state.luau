local Fixture = require("./session_fixture")
local Client = require("./client_fixture")
local function equal(a,b,label) assert(a == b, label .. ": expected " .. tostring(b) .. ", got " .. tostring(a)) end
local function snapshots(f)
	local out = {}; for _, item in ipairs(f.messages) do if item.event == "snapshot" then table.insert(out, item.payload) end end; return out
end
local function profile(f)
	local p = f.config.CreateDefaultProfile()
	p.gold, p.gems, p.strength, p.rodId = 321, 45, 67, "Twig"
	p.fishBag = { { uid="fish-1",fishId="fish",weight=2,mutation="None",sellValue=20,originalValue=20,sizeTier="Normal",locked=false,soulbound=false,midasBonus=1 } }
	p.pinnedFishUids["2"] = "fish-1"; p.equippedHotbarSlot = 2
	return p
end
local function client(sources)
	local function ignore() end
	local panel = setmetatable({}, { __index = function() return ignore end })
	local deps = {
		FishingController = { OnStateChanged = ignore, IsAutoFishEnabled = function() return false end },
		GymController = panel, SoundAndFxController = panel, HotbarAndBaitUi = panel,
		BagPanel = panel, ShopPanel = panel, PetsPanel = panel, EnchantAndBountyModal = panel,
		PlaytimeAndSettingsModal = panel,
		
	}
	local f = Client.new(sources, true, deps)
	f.load("HudPanel").Mount({}, { OnTogglePanel=ignore,OnCancelCast=ignore,OnToggleAutoFish=ignore,OnToggleAutoTrain=ignore,OnManualGymTap=ignore })
	f.load("ClientStateController").Init(nil)
	return f
end
local function warning(f)
	for _, item in ipairs(f.instances) do if item.Name == "ProfileAccessWarning" then return item end end
	error("missing dedicated save warning on HUD")
end

return function(sources)
	local passed, failed = 0, 0
	local function test(name, run)
		local ok, err = pcall(run)
		if ok then passed += 1; print("PASS init " .. name)
		else failed += 1; print("FAIL init " .. name .. ": " .. tostring(err)) end
	end
	for _, delay in ipairs({ 7.9, 8, 8.1 }) do
		test("one complete snapshot when load completes at " .. delay .. " seconds", function()
			local b = Fixture.backend(); local f = Fixture.server(sources,b,"A")
			b.document = profile(f)
			f.afterUpdate = function(kind) if kind == "claim" then coroutine.yield("held load") end end
			local p, load = f.add(101)
			local request = f.fireRemote("init",p)
			b.now += delay; f.afterUpdate = nil; f.resume(load); f.finish(request)
			local list = snapshots(f); equal(#list,1,"exactly one initial snapshot")
			local snap = list[1]
			equal(snap.profile.gold,321,"Gold complete"); equal(snap.profile.gems,45,"Gems complete")
			equal(snap.profile.rodId,"Twig","rod complete"); equal(snap.profile.fishBag[1].uid,"fish-1","bag complete")
			equal(snap.profile.pinnedFishUids["2"],"fish-1","pin complete"); equal(snap.safeReadOnly,false,"permission complete")
			f.advance(10); equal(#snapshots(f),1,"no deferred duplicate")
		end)
	end
	test("each queued request receives one snapshot",function()
		local b=Fixture.backend(); local f=Fixture.server(sources,b,"A")
		f.afterUpdate=function(kind) if kind=="claim" then coroutine.yield("load") end end
		local p,load=f.add(101)
		local first,second=f.fireRemote("init",p),f.fireRemote("init",p)
		f.afterUpdate=nil;f.resume(load);f.finish(first);f.finish(second)
		equal(#snapshots(f),2,"two requests exactly two snapshots")
		f.finish(f.fireRemote("init",p));equal(#snapshots(f),3,"ready request sends once")
	end)
	test("late failed load returns one protected snapshot and HUD warning",function()
		local b=Fixture.backend();local f=Fixture.server(sources,b,"A")
		local held=false
		f.beforeUpdate=function(kind)
			if kind=="claim" then if not held then held=true;coroutine.yield("late API failure") end;error("load unavailable") end
		end
		local p,load=f.add(101);local request=f.fireRemote("init",p)
		b.now+=8.1;f.resume(load);f.finish(load);f.finish(request)
		local list=snapshots(f);equal(#list,1,"failed load snapshot once");equal(list[1].safeReadOnly,true,"read-only explicit")
		local ui=client(sources);ui.emit("StateSnapshot",list[1])
		equal(warning(ui).Visible,true,"late failure warning visible")
		assert(string.find(warning(ui).Text,"READ-ONLY",1,true),"warning uses English protected mode")
	end)
	test("expired session notifies HUD and cannot spend or write leaderboards",function()
		local b=Fixture.backend();local f=Fixture.server(sources,b,"A",nil,{dependencies={
			BuffAggregator={RegisterProvider=function() end},ShopAndItemsService={},PartFactory={},EventsConfig={CYCLE_INTERVAL_SEC=1800},
		}})
		local p=f.add(101);f.data.Get(p).gold=100
		f.finish(f.fireRemote("init",p));b.now+=121
		equal(f.data.IsTransactionLocked(p,false),true,"expired locked")
		equal(f.loadModule("CurrencyService").SpendGold(p,25),false,"expired spend rejected")
		f.loadModule("LiveOpsService").Init()
		equal(f.data.Get(p).gold,100,"balance unchanged");equal(#b.leaderWrites,0,"no leaderboard write")
		local latest
		for _,item in ipairs(f.messages) do if item.event=="ProfileAccessChanged" then latest=item.payload end end
		assert(latest and latest.safeReadOnly==true,"server publishes lost lease status")
		local ui=client(sources);ui.emit("StateSnapshot",snapshots(f)[1]);ui.emit("ProfileAccessChanged",latest)
		equal(warning(ui).Visible,true,"expired warning visible")
		ui.emit("ServerEventChanged",{bannerText="EVENT"})
		equal(warning(ui).Visible,true,"event/buff line cannot hide warning")
		ui.emit("StateSnapshot",snapshots(f)[1])
		equal(warning(ui).Visible,true,"stale snapshot cannot clear newer warning")
	end)
	test("lost owner from save publishes status without extra full snapshot",function()
		local b=Fixture.backend();local a=Fixture.server(sources,b,"A");local other=Fixture.server(sources,b,"B")
		local p=a.add(101);a.finish(a.fireRemote("init",p));b.now+=121;other.add(101)
		equal(a.data.SaveProfile(p),"LostLock","save identifies new owner")
		equal(#snapshots(a),1,"access change does not resend full initialization")
		local latest;for _,item in ipairs(a.messages) do if item.event=="ProfileAccessChanged" then latest=item.payload end end
		assert(latest and latest.safeReadOnly,"lost owner status emitted")
	end)
	test("leave during pending initial request sends no snapshot",function()
		local b=Fixture.backend();local f=Fixture.server(sources,b,"A")
		f.afterUpdate=function(kind) if kind=="claim" then coroutine.yield("load") end end
		local p,load=f.add(101);local request=f.fireRemote("init",p);local removal=f.remove(p)
		f.afterUpdate=nil;f.resume(load);f.finish(load);f.finish(request);f.finish(removal)
		equal(#snapshots(f),0,"departed request discarded")
	end)
	test("idle loss of lease pushes warning without a new client request",function()
		local b=Fixture.backend();local f=Fixture.server(sources,b,"A")
		local p=f.add(101);f.finish(f.fireRemote("init",p))
		f.beforeUpdate=function(kind) if kind=="save" then error("renewal unavailable") end end
		f.beforeRead=function() error("verification unavailable") end
		f.advance(121)
		local latest;for _,item in ipairs(f.messages) do if item.event=="ProfileAccessChanged" then latest=item.payload end end
		assert(latest and latest.safeReadOnly,"periodic access check must publish expired lease")
		equal(#snapshots(f),1,"passive loss never resends initialization")
		local notifications=#f.messages;f.advance(3)
		equal(#f.messages,notifications,"unchanged expired status is not emitted each second")
	end)
	test("idle background save losing owner publishes once despite read-only skip",function()
		local b=Fixture.backend();local f=Fixture.server(sources,b,"A");local other=Fixture.server(sources,b,"B")
		local p=f.add(101);f.finish(f.fireRemote("init",p));b.now+=121;other.add(101)
		f.advance(2)
		equal(f.loadModule("ProfilePersistenceService").Find(p).readOnly,true,"background save detected lost owner")
		local latest,count=nil,0
		for _,item in ipairs(f.messages) do if item.event=="ProfileAccessChanged" then latest=item.payload;count+=1 end end
		assert(latest and latest.safeReadOnly,"background lost owner status published")
		f.advance(3)
		local after=0;for _,item in ipairs(f.messages) do if item.event=="ProfileAccessChanged" then after+=1 end end
		equal(after,count,"read-only status is not spammed")
		equal(#snapshots(f),1,"lost owner does not resend initial profile")
	end)
	test("RuntimeTick quarantine notifies idle player on next scheduler tick",function()
		local b=Fixture.backend();local f=Fixture.server(sources,b,"A")
		local p=f.add(101);f.finish(f.fireRemote("init",p))
		f.beforeClientFire=function(player,event) if player==p and event=="PlaytimeUpdated" then error("RuntimeTick transport fault") end end
		f.advance(8)
		equal(f.loadModule("ProfilePersistenceService").Find(p).readOnly,true,"RuntimeTick isolated profile")
		local latest,count=nil,0
		for _,item in ipairs(f.messages) do if item.event=="ProfileAccessChanged" then latest=item.payload;count+=1 end end
		assert(latest and latest.safeReadOnly,"quarantine status delivered without client action")
		f.advance(3)
		local after=0;for _,item in ipairs(f.messages) do if item.event=="ProfileAccessChanged" then after+=1 end end
		equal(after,count,"quarantine state is not emitted repeatedly")
	end)
	test("HUD loading protected ready and recovered states follow monotonic version",function()
		local f=client(sources)
		equal(warning(f).Visible,true,"loading warning initially visible")
		f.emit("ProfileAccessChanged",{safeReadOnly=false,loading=false,accessVersion=2})
		equal(warning(f).Visible,true,"ready event alone cannot clear initial loading")
		f.emit("StateSnapshot",{profile=f.load("GameConfig").CreateDefaultProfile(),safeReadOnly=false,loading=false,accessVersion=2})
		equal(warning(f).Visible,false,"ready hides warning")
		f.emit("ProfileAccessChanged",{safeReadOnly=true,loading=false,accessVersion=3})
		equal(warning(f).Visible,true,"protected mode warns")
		f.emit("ProfileAccessChanged",{safeReadOnly=false,loading=false,accessVersion=4})
		equal(warning(f).Visible,false,"confirmed recovery clears warning")
		f.emit("ProfileAccessChanged",{safeReadOnly=true,loading=false,accessVersion=3})
		equal(warning(f).Visible,false,"old event cannot undo recovery")
	end)
	test("failed access notification is retried after RuntimeTick quarantine",function()
		local b=Fixture.backend();local f=Fixture.server(sources,b,"A")
		local p=f.add(101);f.finish(f.fireRemote("init",p))
		f.beforeUpdate=function(kind) if kind=="save" then error("renewal unavailable") end end
		f.beforeRead=function() error("verification unavailable") end
		local rejected=false
		f.beforeClientFire=function(_,event,payload)
			if event=="ProfileAccessChanged" and payload.safeReadOnly and not payload.loading and not rejected then
				rejected=true;error("first status send failed")
			end
		end
		f.advance(123)
		local latest;for _,item in ipairs(f.messages) do if item.event=="ProfileAccessChanged" then latest=item.payload end end
		assert(rejected and latest and latest.safeReadOnly,"failed status must retry rather than be cached as delivered")
	end)
	test("Live Odds and read-only warning coexist through loading protection and recovery",function()
 local f=client(sources)
 local function item(name)
  for i=#f.instances,1,-1 do if f.instances[i].Name==name then return f.instances[i] end end
 end
 local button=assert(item("LiveOddsBanner"),"Live Odds button preserved")
 assert(button.Activated.callback,"Live Odds remains clickable")
 button.Activated.callback(); equal(item("OddsText"),nil,"loading has no invented odds")
 equal(warning(f).Visible,true,"loading warning visible")
 local p=f.load("GameConfig").CreateDefaultProfile()
 p.ownedRods.SeraphimDragon=true; p.rodId="SeraphimDragon"
 f.emit("StateSnapshot",{profile=p,safeReadOnly=false,loading=false,accessVersion=2})
 equal(warning(f).Visible,false,"initial confirmed state clears warning")
 button.Activated.callback()
 local text=assert(item("OddsText"),"full snapshot enables real live odds")
 assert(string.find(text.Text,"Base") and string.find(text.Text,"whirlpool"),"per-species odds provided")
 f.emit("ProfileAccessChanged",{safeReadOnly=true,loading=false,accessVersion=3})
 equal(warning(f).Visible,true,"access loss warning visible")
 equal(button.Visible,true,"Live Odds stays visible in read-only")
 button.Activated.callback(); assert(item("OddsText"),"read-only can still inspect odds")
 f.emit("ProfileAccessChanged",{safeReadOnly=false,loading=false,accessVersion=4})
 equal(warning(f).Visible,false,"recovery clears warning")
 button.Activated.callback(); assert(item("OddsText"),"recovery keeps Live Odds")
 for _,request in ipairs(f.requests) do assert(request[1]~="PromptGamepass","viewing odds must never prompt purchase") end
end)
	print(string.format("INITIAL_SUITE passed=%d failed=%d",passed,failed))
	assert(failed==0,"initial state suite failed")
end
