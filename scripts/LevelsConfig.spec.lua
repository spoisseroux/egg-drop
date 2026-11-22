-- Studio Server. The Levels runtime switch (LevelsConfig on AliveConfig's publisher) on a fake ConfigService,
-- clock and scheduler: the server's value before the attribute, off until the config has loaded once, then
-- missing / malformed = on, failures keep the last value, /levels overrides; purchases and medal eggs in flight finish; credit is hidden, never lost.
-- Isolated adapters only; no DataStore or user writes.
-- Usage: require(ServerScriptService.Server.ZZSpecs.LevelsConfig)(ServerScriptService.Server)
return function(server)
	local Shared=game:GetService("ReplicatedStorage").Shared
	local Config=require(server.LevelsConfig)
	local Alive=require(server.AliveConfig)
	local Levels=require(Shared.Levels)
	local H=require(server.HatchProgress)
	local W=require(server.WearableState)
	local B=require(server.BallThemeState)
	local F=require(server.FaceplateState)
	local M=require(server.MedalEggs)
	local Juice=require(server.DeckJuiceState)
	local Stats=require(Shared.StatCatalog)
	local Plates=require(Shared.DeckThemes)
	local Eggs=require(Shared.EggCatalog)
	local cases={}
	local function test(name,run)run();table.insert(cases,name)end
	local function copy(v)if type(v)~="table"then return v end;local r={};for k,x in pairs(v)do r[k]=copy(x)end;return r end
	local ALL={track=true,gates=true,medals=true,juice=true}
	local function switch(on)Levels.inject({flags={LevelsMatter=true},studio=true,shipped=ALL,switch=on})end
	-- A hand-run scheduler, as the AliveConfig spec's.
	local function rig(service,ceiling,set)
		local r={at=0,log={},parked={},waits={},warnings={}}
		r.config=Config.new({service=service,now=function()return r.at end,ceiling=ceiling or function()return true end,
			hold=function(value)r.held=value;table.insert(r.log,"hold "..tostring(value))end,
			set=set or function(name,value)assert(name==Levels.Attribute);r.attr=value;table.insert(r.log,"set "..tostring(value))end,
			warn=function(text)table.insert(r.warnings,text)end,
			spawn=function(fn)local co=coroutine.create(fn);local ok,problem=coroutine.resume(co);assert(ok,problem)end,
			wait=function(s)table.insert(r.waits,s);table.insert(r.parked,{co=coroutine.running(),due=r.at+s});return coroutine.yield()end})
		function r.advance(s)
			local target=r.at+s
			while true do
				local best
				for i,p in ipairs(r.parked)do if p.due<=target and(not best or p.due<r.parked[best].due)then best=i end end
				if not best then break end
				local p=table.remove(r.parked,best);r.at=math.max(r.at,p.due)
				local ok,problem=coroutine.resume(p.co);assert(ok,problem)
			end
			r.at=target
		end
		function r.is(value)return r.held==value and r.attr==value end
		return r
	end
	local function snapshot(values)
		local s={values=values,refreshes=0,listeners={},asked={}}
		function s:GetValue(key)table.insert(s.asked,key);if s.throw then error("boom")end;return s.values[key]end
		function s:Refresh()s.refreshes+=1;if s.onRefresh then s.onRefresh()end end
		s.UpdateAvailable={Connect=function(_,fn)table.insert(s.listeners,fn)end}
		function s.update()for _,fn in ipairs(s.listeners)do fn()end end
		return s
	end
	local function serviceOf(snap)return function()return{GetConfigAsync=function()return if type(snap)=="function"then snap()else snap end}end end
	local function fixture(seed,start)
		local db,c={},{now=start or 1700000000,serial=0}
		local adapter={now=function()return c.now end,guid=function()c.serial+=1;return "op"..c.serial end,random=function()return .1 end,wait=function()end,
			update=function(key,transform)
				if c.failBefore then c.failBefore=false;error("fixture before commit")end
				if c.during then local run=c.during;c.during=nil;run()end
				local value=transform(copy(db[key]))
				if value then db[key]=copy(value)end
				if c.failAfter then c.failAfter=false;error("fixture after commit")end
				return copy(value)
			end}
		if seed then db.player_1=seed end
		return H.load(1,{rank=1},adapter),db,c
	end
	local function ready(levels)
		local _,db,c=fixture()
		local seed=copy(db.player_1)
		seed.hatching.inventoryMask,seed.hatching.nectar,seed.hatching.statsSeed=Eggs.bit("pip"),1000,1
		local xp={};for stat,level in pairs(levels)do xp[stat]=Stats.xpFor(level)end
		seed.hatching.petStats={pip=xp};seed.hatching.lease={token="",expiresAt=0}
		local h,db2,c2=fixture(seed,c.now+200)
		assert(h.status=="Ready",tostring(h.status))
		return h,db2,c2
	end
	local ok,problem=pcall(function()
		test("off is written before anything yields, the server's value first; a service that never answers leaves it off",function()
			local r=rig(function()return{GetConfigAsync=function()return coroutine.yield()end}end)
			r.config.start();assert(table.concat(r.log,",")=="hold false,set false"and r.is(false));r.config.start();r.advance(1000);assert(#r.log==2)
		end)
		test("levels_matter=false is off, true is on; missing and malformed are the shipped default; no other key is read",function()
			for _,case in ipairs({{false,false},{true,true},{nil,true},{"false",true},{0,true}})do
				local s=snapshot({levels_matter=case[1],alive_wind=false});local r=rig(serviceOf(s));r.config.start()
				assert(r.is(case[2]),tostring(case[1]))
				for _,key in ipairs(s.asked)do assert(key=="levels_matter",key)end
			end
		end)
		test("off while it has never loaded: failures retry at 5, 15, 60 then every 300 s; a late load applies",function()
			local calls=0
			local r=rig(serviceOf(function()calls+=1;if calls<5 then error("down")end;return snapshot({levels_matter=false})end))
			r.config.start();r.advance(5+15+60);assert(r.is(false)and calls==4);r.advance(300);assert(r.is(false)and calls==5 and r.config.loaded)
			assert(table.concat(r.waits," ")=="5 15 60 300"and #r.warnings==1 and string.find(r.warnings[1],"[Levels]",1,true))
			local errored=snapshot({levels_matter=false});errored.Error="LoadFailed"
			r=rig(serviceOf(errored));r.config.start();r.advance(1000);assert(r.is(false))
		end)
		test("off then on once a late load lands (missing key), then off and on again: one attribute write per flip, no rejoin",function()
			local calls=0
			local s=snapshot({})
			local r=rig(serviceOf(function()calls+=1;if calls==1 then error("down")end;return s end))
			r.config.start();assert(r.is(false));r.advance(5);assert(r.is(true))
			r.at=20;s.values={levels_matter=false};s.update();assert(r.is(false));r.at=40;s.values={};s.update();assert(r.is(true))
			assert(table.concat(r.log,",")=="hold false,set false,hold true,set true,hold false,set false,hold true,set true")
			-- an owner override speaks before the first load; clear goes back to off
			r=rig(function()error("down")end);r.config.start();assert(r.config.command("/levels on")and r.is(true)and r.config.command("/levels clear")and r.is(false))
		end)
		test("an update flips it without a publish; a refresh that fails keeps the last value",function()
			local s=snapshot({});local r=rig(serviceOf(s));r.config.start();assert(r.is(true))
			r.at=10;s.values={levels_matter=false};s.update();assert(r.is(false))
			r.at=20;s.values={};s.onRefresh=function()error("down")end;s.update();assert(r.is(false),"a throw")
			s.onRefresh=nil;s.Error="LoadFailed";r.at=400;s.update();assert(r.is(false),"an errored snapshot")
			s.Error=nil;s.throw=true;r.at=800;s.update();assert(r.is(false),"a throwing value")
			s.throw=nil;r.at=1200;s.update();assert(r.is(true),"a good one applies")
		end)
		test("an attribute that cannot be written still turns the server off",function()
			local r=rig(serviceOf(snapshot({levels_matter=false})),nil,function()error("locked")end)
			r.config.start();assert(r.held==false)
		end)
		test("the ceiling is false: off, and ConfigService is never asked",function()
			local asked=false
			local r=rig(function()asked=true;error("asked")end,function()return false end)
			r.config.start();r.config.command("/levels on");r.advance(1000);assert(r.is(false)and not asked)
		end)
		test("/levels on, off and clear beat the config; nonsense and /alive are ignored",function()
			local s=snapshot({levels_matter=false});local r=rig(serviceOf(s));r.config.start()
			assert(r.config.command(" /LEVELS On ")and r.is(true));r.at=10;s.update();assert(r.is(true))
			assert(r.config.command("/levels off")and r.is(false)and r.config.command("/levels on")and r.config.command("/levels clear")and r.is(false))
			for _,odd in ipairs({"/levels","/levels maybe","/levels all off","levels on","/alive all on","/levels on now"})do assert(not r.config.command(odd),odd)end
			for _,odd in ipairs({5,{},true})do assert(not r.config.command(odd))end
			assert(not r.config.command(nil)and r.is(false)and Alive.parse("/levels on")==nil)
		end)
		test("a gated purchase that began with gates on finishes: in the write, and from a retry after the switch goes off",function()
			switch(true)
			local h,db,c=ready({jump=15,power=10})
			c.during=function()switch(false)end
			local bought,why=H.buyWearable(h,"w","pip","partyhat_lime",40,true)
			assert(bought and why=="Saved"and W.owns(h.state,"pip","partyhat_lime")and W.equipped(h.state,"pip").Hat=="partyhat_lime"and db.player_1.hatching.nectar==960,tostring(why))
			switch(true);c.failBefore=true
			bought,why=H.buyBallTheme(h,"b","tangerine_pop",40,true);assert(not bought and why=="Retrying")
			switch(false)
			bought,why=H.retry(h);assert(bought and why=="Saved"and B.equipped(h.state)=="tangerine_pop"and db.player_1.hatching.nectar==920 and h.status=="Ready",tostring(why))
			switch(true);c.failAfter=true
			bought,why=H.buyWearable(h,"a","pip","tee_sky",40,false)
			assert(not bought and why=="NeedsLevel","energy 1")
			c.failAfter=true
			switch(true);c.failAfter=true
			bought,why=H.buyWearable(h,"b2","pip","beanie",40,false);assert(not bought and why=="Retrying")
			switch(false);bought,why=H.buyWearable(h,"b2","pip","beanie",40,false);assert(bought and db.player_1.hatching.nectar==880,tostring(why))
			assert(H.valid(h.state))
		end)
		test("the real switch, no seam: flipped off through the publisher, met and unmet wearables, balls and plates are NotForSale; only an op that began while on finishes",function()
			Levels.inject(nil)
			local savedAttribute=workspace:GetAttribute(Levels.Attribute)
			local fine,wrong=pcall(function()
				local s=snapshot({levels_matter=true})
				local r=rig(serviceOf(s),function()return Levels.allowed()end,function(name,value)workspace:SetAttribute(name,value)end)
				local hold=Levels.setSwitch
				local config=Config.new({service=serviceOf(s),now=function()return r.at end,ceiling=function()return Levels.allowed()end,hold=hold,
					set=function(name,value)workspace:SetAttribute(name,value)end,warn=function()end,spawn=function(fn)fn()end,wait=function()return coroutine.yield()end})
				local function flip(on)assert(config.command(if on then "/levels on"else "/levels off"));assert(Levels.on("gates")==(on and Levels.ceiling("gates")))end
				if not Levels.ceiling("gates")then return end -- a build without the flag has nothing to flip
				flip(true)
				local function refused(h,tag)
					for _,buy in ipairs({
						function(op)return H.buyWearable(h,op,"pip","tee_sky",40,true)end,       -- Energy 15
						function(op)return H.buyWearable(h,op,"pip","tee_sky",nil,true)end,      -- a raw request with no price
						function(op)return H.buyWearable(h,op,"pip","tee_sky",32,true)end,       -- a shelf price
						function(op)return H.buyWearable(h,op,"pip","bowtail_periwinkle",100,false)end, -- Speed 30
						function(op)return H.buyBallTheme(h,op,"tangerine_pop",40,true)end,      -- Power 10
						function(op)return H.buyBallTheme(h,op,"tangerine_pop",32,true)end,
						function(op)return H.buyFaceplate(h,op,"sky_fizz",40)end,                -- Energy 10
						function(op)return H.buyFaceplate(h,op,"storm_glass",nil)end,            -- Energy 30
					})do
						tag..="."
						local bought,why=buy("off-"..tag)
						assert(not bought and why=="NotForSale",tag.." "..tostring(why))
					end
					assert(h.pending==nil and h.status=="Ready")
				end
				-- met and unmet, on both sides of the flip, in one open session
				for name,levels in pairs({met={energy=99,power=99,speed=99},unmet={energy=1}})do
					flip(true)
					local h,db=ready(levels)
					flip(false);refused(h,name);assert(db.player_1.hatching.nectar==1000,name)
				end
				-- either half off is off: the attribute (clients were told), or the server's own value
				flip(true)
				local h,db=ready({energy=99,power=99,speed=99})
				workspace:SetAttribute(Levels.Attribute,false);refused(h,"attribute")
				workspace:SetAttribute(Levels.Attribute,true);Levels.setSwitch(false);refused(h,"value")
				flip(true)
				-- the op that began while on finishes after the flip; a new op, and a reused id for another item, do not
				flip(true)
				local h2,db2,c2=ready({energy=99,power=99,speed=99})
				c2.failBefore=true
				local bought,why=H.buyWearable(h2,"began","pip","tee_sky",40,true);assert(not bought and why=="Retrying")
				flip(false)
				bought,why=H.buyWearable(h2,"other","pip","bowtail_periwinkle",100,true);assert(not bought and why=="Pending",tostring(why))
				bought,why=H.buyWearable(h2,"began","pip","tee_sky",40,true);assert(bought and why=="Saved"and db2.player_1.hatching.nectar==960,tostring(why))
				bought,why=H.buyBallTheme(h2,"after","tangerine_pop",40,true);assert(not bought and why=="NotForSale")
				for _,plate in ipairs({"sky_fizz"})do
					flip(true);c2.failBefore=true
					bought,why=H.buyFaceplate(h2,"plate",plate,40);assert(not bought and why=="Retrying")
					flip(false);bought,why=H.retry(h2);assert(bought and F.owns(h2.state,plate)and db2.player_1.hatching.nectar==920,tostring(why))
				end
				-- back on: sold again, no rejoin
				flip(true);bought,why=H.buyBallTheme(h2,"again","tangerine_pop",40,true);assert(bought and db2.player_1.hatching.nectar==880,tostring(why))
			end)
			Levels.setSwitch(savedAttribute==true);workspace:SetAttribute(Levels.Attribute,savedAttribute)
			assert(fine,wrong)
		end)
		test("a purchase that begins with the switch off is NotForSale with no charge; a frozen gate never skips the level check",function()
			switch(false)
			local h,db=ready({jump=15,power=10,energy=10})
			local bought,why=H.buyWearable(h,"w","pip","partyhat_lime",40,true);assert(not bought and why=="NotForSale")
			bought,why=H.buyBallTheme(h,"b","tangerine_pop",40,true);assert(not bought and why=="NotForSale"and db.player_1.hatching.nectar==1000 and not h.pending)
			assert(select(2,W.check(h.state,"pip","partyhat_lime",40,nil,false))=="NotForSale"and W.check(h.state,"pip","partyhat_lime",40,nil,true))
			assert(select(2,W.check(h.state,"pip","sunhat_sky",100,nil,true))=="NeedsLevel"and select(2,W.check(h.state,"pip","nope",40,nil,true))=="NotForSale")
			assert(W.check(h.state,"pip","beanie",40,nil,true)and B.check(h.state,"gumdrops",40,nil,true))
			Plates.ById._spec_gated={name="Spec",priceStars=40,gate={stat="energy",level=10}}
			local fine,wrong=pcall(function()
				assert(select(2,F.check(h.state,"_spec_gated",40))=="NotForSale"and F.check(h.state,"_spec_gated",40,nil,true))
			end)
			Plates.ById._spec_gated=nil;assert(fine,wrong)
		end)
		test("a medal egg in flight finishes; credit is hidden while off and comes back whole",function()
			switch(true)
			local h,db,c=ready({jump=50})
			local function key()return H.public(h).statEgg.quotes.pip.key end
			assert(H.public(h).statEgg.medalEggs==2)
			c.failBefore=true
			local op=key()
			local done,why=H.statEggBuy(h,"m1","pip",true,op);assert(not done and why=="Retrying")
			switch(false)
			done,why=H.retry(h);assert(done and why=="Saved"and db.player_1.hatching.medalEggsUsed==1,tostring(why))
			local p=H.public(h).statEgg;assert(p.free==0 and p.medalEggs==nil)
			done,why=H.statEggBuy(h,"m2","pip",true,key());assert(not done and why=="NoFreeEgg"and db.player_1.hatching.medalEggsUsed==1,tostring(why))
			switch(true);assert(H.public(h).statEgg.medalEggs==1 and M.left(h.state)==1)
			done=H.statEggBuy(h,"m3","pip",true,key());assert(done and db.player_1.hatching.medalEggsUsed==2 and M.left(h.state)==0)
		end)
		test("off then on for one open session: gated sale, medal credit and snapshot keys follow the switch",function()
			switch(false)
			local h=ready({jump=50})
			assert(select(2,H.buyWearable(h,"o1","pip","partyhat_lime",40,true))=="NotForSale"and H.public(h).statEgg.medalEggs==nil)
			switch(true)
			assert(H.public(h).statEgg.medalEggs==2 and H.buyWearable(h,"o2","pip","partyhat_lime",40,true)and H.statEggBuy(h,"o3","pip",true,H.public(h).statEgg.quotes.pip.key))
			switch(false);assert(H.public(h).statEgg.medalEggs==nil and H.equipWearable(h,"o4","pip","Hat",false))
		end)
		test("deck juice: off publishes nothing and refuses a choice; the saved choice is untouched",function()
			local state={inventoryMask=Eggs.bit("pip"),petStats={pip={power=Stats.xpFor(50)}}}
			local saved={pop="fizz"}
			switch(false);assert(Juice.public(saved,state)==nil and select(2,Juice.choose(saved,state,"pop","confetti"))=="Off")
			switch(true);assert(Juice.public(saved,state).pop=="fizz"and Juice.choose(saved,state,"pop","confetti").pop=="confetti"and saved.pop=="fizz")
		end)
	end)
	Levels.inject(nil)
	assert(ok,problem)
	return{passed=#cases,cases=cases}
end
