-- The daily rack's pure rules (DailyRack.lua; artifacts/qa-2026-11-28-rotation/ROTATION-BRIEF.md 1, ARCH-REVIEW-ROTATION
-- 3, 5, 6, 7): the day (05:00 UTC, the same from a time or the snapshot's day), the deal (deterministic, 8 distinct picks,
-- one colour of a base at a time, every row back within its stated bound over a year of days), the exact integer odds
-- (weights, the flat 1% sparkle, every unit enumerated on 30 days, a 100k-roll sample), owned items leaving the pool (no
-- duplicates), the egg resting when every pick is owned (the daily cap), the fixed path for restricted players, the
-- Outfit Egg rows (shape, never listed or sold, the 128 cap), the Paint Egg's daily tables and no pity, and the switches.
-- Offline: scripts/run_dash_server_specs.py. Studio: require(ServerScriptService.Server.ZZSpecs.DailyRack)(Server).
return function(server)
	local Shared=game:GetService("ReplicatedStorage").Shared
	local Rack=require(Shared.DailyRack)
	local Variants=require(Shared.WearableVariants)
	local Wear=require(Shared.WearableCatalog)
	local Daily=require(Shared.DailyContracts)
	local Look=require(Shared.LookEggCatalog)
	local Hue=require(Shared.HueCatalog)
	local OddsText=require(Shared.OddsText)
	local W=require(server.WearableState)
	local Config=require(server.RackConfig)
	local cases={}
	local function test(name,run)run();table.insert(cases,name)end
	local DAY0=20420 -- a server day near the build (2025-11-28 + a year of days covers 2026)
	local function ids(rows)local out={};for _,r in ipairs(rows)do table.insert(out,r.id)end;return table.concat(out,",")end

	test("the day: 05:00 UTC, the same number from a time or from the snapshot's dailyDay",function()
		local t=1795410000 -- Mon 23 Nov 2026 05:00:00 UTC
		assert(Rack.today(t)==Rack.today(t-1)+1,"the day rolls at 05:00 UTC")
		assert(Rack.today(t+86399)==Rack.today(t)and Rack.today(t+86400)==Rack.today(t)+1)
		assert(Rack.today(t)==tonumber(Daily.dayOf(t)))
		assert(Rack.dayArg("20000")==20000 and Rack.dayArg(20000)==20000 and Rack.dayArg("20000.5")==nil and Rack.dayArg("x")==nil
			and Rack.dayArg(1.5)==nil and Rack.dayArg("020000")==nil and Rack.dayArg(nil)==nil)
	end)

	test("the deal: deterministic, 8 distinct bases a day, every base once a cycle, the short last day wrapping",function()
		for _,pet in ipairs({"pip","blip"})do
			local bases=#Wear.compose(pet,{}).order
			assert(bases==23,pet.." has 23 rig items: "..bases)
			assert(Rack.period(pet)==3)
			for day=DAY0,DAY0+365 do
				local a,b=Rack.picks(pet,day),Rack.picks(pet,day)
				assert(#a==8 and ids(a)==ids(b),"same day, same picks")
				local seen={}
				for _,row in ipairs(a)do assert(not seen[row.base],"one colour of a base a day");seen[row.base]=true end
			end
			for c=DAY0//3,DAY0//3+40 do
				local dealt={}
				for k=0,2 do for _,row in ipairs(Rack.picks(pet,c*3+k))do dealt[row.base]=(dealt[row.base]or 0)+1 end end
				local count=0;for _ in pairs(dealt)do count+=1 end
				assert(count==23,"every base in every cycle")
			end
		end
		assert(ids(Rack.picks("pip",DAY0))~=ids(Rack.picks("pip",DAY0+1)),"a new rack tomorrow")
		assert(#Rack.picks("puddle",DAY0)==0 and Rack.sparkle("puddle",DAY0)==nil,"a pet with no wearables has no egg")
	end)

	test("one colour per base each cycle, the next colour next cycle; every row returns within its bound over a year",function()
		local maxColours=0
		for _,base in ipairs({"beanie","tee","sunhat","bellcollar","ring","eyes"})do
			local list=Rack.colours("pip",base)
			if list then maxColours=math.max(maxColours,#list)end
		end
		assert(#Rack.colours("pip","beanie")==8 and #Rack.colours("pip","tee")==8,"base + 3 shipped + 4 egg rows")
		assert(#Rack.colours("pip","sunhat")==7 and #Rack.colours("pip","ring")==5 and #Rack.colours("pip","w")==1)
		-- within one cycle a base shows one colour; across cycles it walks its list
		for c=DAY0//3,DAY0//3+16 do
			local shown={}
			for k=0,2 do for _,row in ipairs(Rack.picks("pip",c*3+k))do
				assert(shown[row.base]==nil or shown[row.base]==row.id);shown[row.base]=row.id
			end end
			local list=Rack.colours("pip","beanie")
			assert(shown.beanie==list[c%#list+1].id,"cycle c shows list[(c mod n) + 1]")
		end
		-- the real return bounds (the per-cycle shuffle moves a base inside its cycle): a base within 2P - 1 days, a row of
		-- a base with n colours within (n + 1) P - 1 days (26 for the two 8-colour bases, 23 for the rest)
		local last,gapBase,gapRow={},{},{}
		local pool=Rack.pool("pip")
		local start,stop=DAY0,DAY0+365
		for day=start,stop do
			for _,row in ipairs(Rack.picks("pip",day))do
				if last[row.id]then gapRow[row.id]=math.max(gapRow[row.id]or 0,day-last[row.id])end
				last[row.id]=day
				local key="base:"..row.base
				if last[key]then gapBase[row.base]=math.max(gapBase[row.base]or 0,day-last[key])end
				last[key]=day
			end
		end
		for base,gap in pairs(gapBase)do assert(gap<=5,base.." back within 5 days: "..gap)end
		local sparkles={};for _,r in ipairs(Rack.sparkles("pip"))do sparkles[r.id]=true end
		sparkles[Rack.wings("pip").id]=true -- Angel Wings: only ever the wings-day sparkle pick (RackSlice2.spec)
		for _,id in ipairs(pool)do
			if not sparkles[id]then
				assert(last[id],"every row shows in a year: "..id)
				local n=#Rack.colours("pip",Variants.ById[id]and Variants.ById[id].base or id)
				assert(gapRow[id]and gapRow[id]<=(n+1)*3-1,id.." returns within "..((n+1)*3-1).." days: "..tostring(gapRow[id]))
				if n<=7 then assert(gapRow[id]<=24,id.." within the brief's 24 days")end
			end
		end
	end)

	test("the sparkle pick: one legendary row a day, each back every 5 days",function()
		local list=Rack.sparkles("pip")
		assert(ids(list)=="beanie_rainbow,bowtail_rainbow,hoodie_aurora,partyhat_aurora,flowercrown_stardust",ids(list))
		for day=DAY0,DAY0+30 do
			local s=Rack.sparkle("pip",day)
			assert(s.rarity=="legendary"and s.finish and s==list[day%5+1]and Rack.sparkle("pip",day+5)==s)
			for _,row in ipairs(Rack.picks("pip",day))do assert(row.rarity~="legendary","never among the 8")end
		end
	end)

	test("odds: exact integer weights; the sparkle a flat 1%; the units sum to the total; every unit enumerated on 30 days",function()
		assert(Rack.Weights.common==18 and Rack.Weights.uncommon==12 and Rack.Weights.rare==6 and Rack.Weights.epic==2)
		for day=DAY0,DAY0+29 do
			local view=Rack.view("pip",day,{},"random")
			local W=0;for _,r in ipairs(view.items)do W+=r.weight end
			assert(view.total==100*W and view.sparkle.units==W,"sparkle W of 100 W")
			local sum,percent=view.sparkle.units,view.sparkle.percent
			for _,r in ipairs(view.items)do assert(r.units==99*r.weight);sum+=r.units;percent+=r.percent end
			assert(sum==view.total and math.abs(percent-100)<1e-9,"the units are the whole egg")
			assert(math.abs(view.sparkle.percent-1)<1e-12,"the sparkle pick is exactly 1%")
			-- every r in [0, total) maps to exactly its row's units (the roll is the shown odds, no rounding)
			local counts={}
			for r=0,view.total-1 do
				local id=Rack.roll(view,(r+.5)/view.total)
				counts[id]=(counts[id]or 0)+1
			end
			for _,r in ipairs(view.items)do assert(counts[r.id]==r.units,r.id)end
			assert(counts[view.sparkle.id]==view.sparkle.units)
			-- the shown text adds to 100% (OddsText.list on the units)
			local units={};for _,r in ipairs(view.items)do table.insert(units,r.units)end;table.insert(units,view.sparkle.units)
			local texts=OddsText.list(units);assert(#texts==9)
		end
		-- a 100k-roll sample on one day sits on the shown odds
		local view=Rack.view("pip",DAY0,{},"random")
		local seed,counts=12345,{}
		for _=1,100000 do
			seed=seed*16807%2147483647 -- Park-Miller (exact in doubles)
			local id=Rack.roll(view,seed/2147483647)
			counts[id]=(counts[id]or 0)+1
		end
		for _,r in ipairs(view.items)do
			assert(math.abs(counts[r.id]/100000-r.units/view.total)<.006,r.id)
		end
		assert(math.abs((counts[view.sparkle.id]or 0)/100000-.01)<.002,"about 1 in 100")
	end)

	test("no duplicates: owned picks leave the pool; the sparkle owned, the picks share 100%; all owned, the egg rests",function()
		local day=DAY0+3
		local view=Rack.view("pip",day,{},"random")
		local owned={}
		local rolls=0
		while not view.rest do
			local id=Rack.roll(view,.5)
			assert(id and table.find(owned,id)==nil,"never an owned item")
			table.insert(owned,id);rolls+=1
			view=Rack.view("pip",day,owned,"random")
			for _,r in ipairs(view.items)do if table.find(owned,r.id)then assert(r.owned and r.units==0)end end
		end
		assert(rolls<=9,"the daily cap: the 8 picks and the sparkle at most: "..rolls)
		assert(Rack.roll(view,.5)==nil and view.total==0,"resting sells nothing, never a 100% sparkle")
		-- the sparkle owned: the picks share 100%
		local s=Rack.sparkle("pip",day)
		local v2=Rack.view("pip",day,{s.id},"random")
		local W=0;for _,r in ipairs(v2.items)do W+=r.weight end
		assert(v2.total==W and v2.sparkle.units==0 and v2.sparkle.owned)
		-- the pool key moves with what is owned
		assert(Rack.view("pip",day,{},"random").poolKey~=Rack.view("pip",day,{v2.items[1].id},"random").poolKey)
		assert(Rack.view("pip",day,{},"random").poolKey==Rack.view("pip",day,{},"fixed").poolKey,"the key binds the pool, not the mode")
		assert(Rack.view("pip",day,{"not_a_rack_item"},"random").poolKey==Rack.view("pip",day,{},"random").poolKey)
	end)

	test("restricted players: the fixed next pick, common first then deal order, never the sparkle",function()
		local day=DAY0+7
		local view=Rack.view("pip",day,{},"fixed")
		local order={common=1,uncommon=2,rare=3,epic=4}
		local best=nil
		for _,r in ipairs(view.items)do if best==nil or order[r.rarity]<order[best.rarity]then best=r end end
		assert(view.next==best.id and Rack.roll(view,.999)==best.id and view.total==1 and view.sparkle.units==0)
		local owned={}
		for _=1,8 do
			local v=Rack.view("pip",day,owned,"fixed");table.insert(owned,v.next)
		end
		assert(Rack.view("pip",day,owned,"fixed").rest and #owned==8)
	end)

	test("Outfit Egg rows: 16 bases x 4 colours + 5 finishes; never listed or sold; problem() refuses sale fields",function()
		local egg,finish={},0
		for _,row in ipairs(Variants.Rows)do if row.egg then table.insert(egg,row);if row.finish then finish+=1 end end end
		assert(#egg==69 and finish==5,#egg.." egg rows")
		assert(Variants.problem(Variants.Rows)==nil)
		for _,row in ipairs(egg)do
			assert(Variants.released(row,math.huge)and not Variants.released(row,0)and not Variants.released(row,Variants.week()))
			assert(Wear.forPet("pip").byId[row.id]==nil and Wear.forPet("pip",math.huge).byId[row.id].egg==true)
			assert(select(2,W.check({inventoryMask=1,nectar=1000,petWearables={}},"pip",row.id,nil))=="NotForSale")
			assert(select(2,W.check({inventoryMask=1,nectar=1000,petWearables={}},"pip",row.id,nil,nil,true))=="NotForSale","gates on")
			assert(select(2,W.check({inventoryMask=1,nectar=1000,petWearables={}},"pip",row.id,nil,nil,nil,Variants.week()))=="NotForSale")
		end
		local base={id="beanie_test",base="beanie",name="T",color="#123456",egg=true,rarity="common"}
		assert(Variants.problem({base})==nil)
		for field,value in pairs({price=10,from=1,gate={total=5},weekly=true})do
			local bad=table.clone(base);bad[field]=value
			assert(Variants.problem({bad})~=nil,"an egg row never carries "..field)
		end
		local legendary=table.clone(base);legendary.rarity="legendary"
		assert(Variants.problem({legendary})~=nil,"a legendary row needs a finish")
		local plain=table.clone(base);plain.egg=nil
		assert(Variants.problem({plain})~=nil,"rarity is an egg-row field")
		-- the wardrobe lists an owned egg row in its tab (kept), never an unowned one
		local tab=Wear.shopTab("pip","Hat",{"beanie_sky"})
		local found=false;for _,item in ipairs(tab)do if item.id=="beanie_sky"then found=true end;assert(item.id~="beanie_gold")end
		assert(found)
	end)

	test("the 128 cap: everything a Bear could ever own fits; a full closet refuses every grant",function()
		local all=#Wear.forPet("pip",math.huge).order+#Wear.eggBases("pip")
		assert(all==125 and all<=W.Limit and W.Limit==128,"23 + 24 + 8 + 64 + 5 + Angel Wings = "..all)
		local owned={};for i=1,128 do owned[i]="x"..i end
		local state={inventoryMask=1,petWearables={pip={owned=owned,equipped={}}}}
		assert(select(2,W.grant(state,"pip","beanie_sky"))=="ClosetFull"and #state.petWearables.pip.owned==128)
		assert(select(2,W.grant({inventoryMask=1},"blip","beanie_sky"))=="Unowned")
	end)

	test("the Paint Egg's daily splash: pots total 68, the splash 23 and the rest 15; shine and charms never move",function()
		for day=DAY0,DAY0+7 do
			local splash=Look.splashOf(day)
			assert(splash==Hue.RollOrder[day%4+1])
			for m,row in pairs(Look.tables(day))do
				local base=Look.Tables[m];local pots=0
				for _,id in ipairs(Look.HueItems)do pots+=row[id];assert(row[id]==(if id==splash then 23 else 15))end
				assert(pots==68)
				for _,id in ipairs(Look.FinishItems)do assert(row[id]==base[id])end
				assert(row.charm==base.charm)
			end
			local odds=Look.odds({},day);local total=0;for _,r in ipairs(odds)do total+=r.percent end
			assert(total==100)
		end
		assert(Look.tables(nil)==Look.Tables and Look.odds({})[1].percent==17,"no day: today's egg exactly")
		assert(Look.PoolVersion==1,"no new pool version")
		-- the roll follows the day's table
		local function rate(day)
			local n=0;for i=0,999 do if Look.roll((i+.5)/1000,{},0,{day=day})==Look.splashOf(day)then n+=1 end end;return n
		end
		assert(rate(DAY0)==230 and rate(DAY0+1)==230)
	end)

	test("no pity: never a guaranteed charm while the switch is on; misses still stop at the limit",function()
		local all=Look.missing({})
		assert(Look.pityDue(all,14)and not Look.pityDue(all,14,true)and Look.pityLeft(all,3,true)==nil)
		local charms=0
		for i=0,999 do
			local id=Look.roll((i+.5)/1000,all,Look.MissesLimit,{noPity=true})
			if Look.kind(id)=="charm"then charms+=1 end
		end
		assert(charms==60,"the shown 2% each, no pity: "..charms)
		assert(Look.kind(Look.roll(.9,all,14))=="charm","off: pity as before")
	end)

	test("the switches: the build ceiling, the defaults (rack on, the Paint parts off), owner chat",function()
		assert(Rack.ceiling({flags={DailyRack=true},studio=false,place=Rack.PlaceId}))
		assert(not Rack.ceiling({flags={DailyRack=true},studio=false,place=96451847774961}),"live never opens it")
		assert(not Rack.ceiling({flags={},studio=true}))
		assert(Rack.resolve("rack",nil,nil,true)==true and Rack.resolve("lookdaily",nil,nil,true)==false and Rack.resolve("looknopity","x",nil,true)==false)
		assert(Rack.resolve("rack",false,nil,true)==false and Rack.resolve("lookdaily",true,nil,true)==true and Rack.resolve("rack",true,nil,false)==false)
		assert(Rack.resolve("rack",false,true,true)==true,"an owner override wins")
		local p=Config.parse("/rack all off");assert(p and #p.features==6 and p.value==false)
		p=Config.parse("/rack lookdaily clear");assert(p and p.features[1]=="lookdaily"and p.value==nil)
		assert(Config.parse("/rack nope on")==nil and Config.parse("/thisweek on")==nil)
		assert(Rack.inject({flags={DailyRack=true},studio=true}))
		assert(Rack.on("rack")and not Rack.on("lookdaily")and not Rack.on("looknopity"))
		Rack.inject({flags={DailyRack=true},studio=true,rack=false,lookdaily=true})
		assert(not Rack.on("rack")and Rack.on("lookdaily"))
		Rack.inject(nil)
		assert(not Rack.on("rack"),"uninjected server: off until RackConfig sets it")
	end)
	return {passed=#cases,cases=cases}
end
