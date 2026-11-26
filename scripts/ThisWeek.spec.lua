-- "This week" (ThisWeek.lua; GARDEN-PLAY-BRIEF-2 section 8, AERO-JUICE-BRIEF section 6, Spencer 2026-11-26): one
-- wardrobe recolour a week at its full price on a stated cycle. The week clock (the shelf's, from a time or a day
-- number, so server and client agree), the rotation (pure, every item back every 8 weeks, each base every 4 in a new
-- colour), the prices (three weeks at 60, the fourth at 150, never a discount and never on the shelf), the listing
-- (off: nothing; on: only this week's pick; math.huge: every row, so a saved one renders), and the server's purchase
-- path (the price from the server's table for the server's week, idempotent, never a double charge, a week boundary
-- before the write charges nothing, a bought item stays owned and wearable). Isolated adapters only.
-- Usage (Server): require(ServerScriptService.Server.ZZSpecs.ThisWeek)(ServerScriptService.Server)
return function(server)
	local Shared=game:GetService("ReplicatedStorage").Shared
	local ThisWeek=require(Shared.ThisWeek)
	local Variants=require(Shared.WearableVariants)
	local Wear=require(Shared.WearableCatalog)
	local Shelf=require(Shared.WeeklyShelf)
	local Daily=require(Shared.DailyContracts)
	local Flags=require(Shared.FeatureFlags)
	local H=require(server.HatchProgress)
	local W=require(server.WearableState)
	local Config=require(server.ThisWeekConfig)
	local cases={}
	local function test(name,run)run();table.insert(cases,name)end
	local function copy(v)if type(v)~="table"then return v end;local r={};for k,x in pairs(v)do r[k]=copy(x)end;return r end
	local WEEK=7*86400
	-- Mon 23 Nov 2026 05:00:00 UTC: the first second of week 2969 (the Anchor, row 1).
	local MONDAY=1795410000
	local function on()assert(ThisWeek.inject({on=true,studio=true,flags={ThisWeek=true}}),"inject needs Studio (or the offline mocks)")end
	local function off()ThisWeek.inject({on=false,studio=true,flags={ThisWeek=true}})end
	local function clear()ThisWeek.inject(nil)end
	-- A time inside the week that shows row `index` (cycle `cycle`, 0 = the first).
	local function timeFor(index,cycle)return MONDAY+((cycle or 0)*ThisWeek.Every+index-1)*WEEK+3600 end
	local function weeklyIn(petId,week)
		local out={}
		for _,item in ipairs(Wear.forPet(petId,week).order)do if item.weekly then table.insert(out,item.id)end end
		return out
	end

	local ok,problem=pcall(function()
	test("the week is the shelf's week (Monday 05:00 UTC), the same from a time or from the snapshot's day",function()
		assert(Flags.ThisWeek==true,"the build ceiling is on for this build")
		assert(ThisWeek.week(MONDAY)==ThisWeek.Anchor and ThisWeek.week(MONDAY-1)==ThisWeek.Anchor-1,"the Anchor week starts on that Monday")
		for _,t in ipairs({MONDAY-1,MONDAY,MONDAY+1,MONDAY+WEEK-1,MONDAY+WEEK,1700000000,1700456399,1700456400,1800000000})do
			local week=ThisWeek.week(t)
			assert(week==Shelf.week(t)and week==Variants.week(t),"one week clock at "..t)
			-- The client derives the week from the snapshot's dailyDay (a string), the server from its clock.
			assert(ThisWeek.weekOfDay(Daily.dayOf(t))==week and ThisWeek.weekOfDay(tonumber(Daily.dayOf(t)))==week)
		end
	end)

	test("the rotation: a pure function of the week; row 1 shows in week 2969; bad weeks pick nothing",function()
		local first={}
		for i=0,7 do
			local row=ThisWeek.pick(ThisWeek.Anchor+i)
			table.insert(first,row.id..":"..row.price)
			-- Server (from its clock) and client (from the snapshot's day) pick the same row.
			local t=timeFor(i+1)
			assert(ThisWeek.pick(ThisWeek.week(t))==row and ThisWeek.pick(ThisWeek.weekOfDay(Daily.dayOf(t)))==row)
			assert(ThisWeek.pick(ThisWeek.Anchor+i)==row,"same week, same row")
		end
		assert(table.concat(first,",")=="partyhat_plum:60,bands_sherbet:60,specs_bluebell:60,hoodie_lantern:150,"
			.."partyhat_berry:60,bands_lime:60,specs_lilac:60,hoodie_tide:150",table.concat(first,","))
		for _,bad in ipairs({0/0,1.5,"2969",math.huge,-math.huge,nil,2e9})do assert(ThisWeek.pick(bad)==nil and ThisWeek.index(bad)==nil,tostring(bad))end
		assert(ThisWeek.pick(-3)~=nil and ThisWeek.pick(0)~=nil,"weeks before the Anchor loop too")
	end)

	test("nothing is gone for good: every item back every 8 weeks, each base every 4 in another colour",function()
		assert(ThisWeek.Every==8 and ThisWeek.BaseEvery==4)
		local last={}
		for week=ThisWeek.Anchor-400,ThisWeek.Anchor+400 do
			local row=ThisWeek.pick(week)
			if last[row.id]then assert(week-last[row.id]==ThisWeek.Every,row.id.." came back after "..(week-last[row.id]))end
			last[row.id]=week
			local later=ThisWeek.pick(week+ThisWeek.BaseEvery)
			assert(later.base==row.base and later.color~=row.color and later.id~=row.id,"the base returns recoloured: "..row.id)
			-- Any 8 weeks in a row hold every item exactly once.
			local seen={}
			for k=0,ThisWeek.Every-1 do local id=ThisWeek.pick(week+k).id;assert(not seen[id],id);seen[id]=true end
			for _,r in ipairs(ThisWeek.Rows)do
				assert(seen[r.id],r.id.." missing from an 8-week window")
				local wait=ThisWeek.weeksUntil(r.id,week)
				assert(wait>=0 and wait<ThisWeek.Every and ThisWeek.pick(week+wait)==r,"weeksUntil "..r.id)
			end
		end
		for _,r in ipairs(ThisWeek.Rows)do assert(last[r.id],r.id.." never shown")end
	end)

	test("prices: three weeks at 60, the fourth at 150; each row a weekly recolour of a rig item at that price",function()
		for index,row in ipairs(ThisWeek.Rows)do
			local want=if index%ThisWeek.BigEvery==0 then ThisWeek.BigPrice else ThisWeek.Price
			assert(row.price==want,row.id.." costs "..row.price)
			local variant=Variants.ById[row.id]
			assert(variant and variant.weekly==true and variant.base==row.base and variant.price==row.price and variant.color==row.color
				and variant.gate==nil and variant.from==nil,row.id)
			for _,pet in ipairs({"pip","blip"})do
				local item=Wear.forPet(pet,math.huge).byId[row.id]
				assert(item and item.price==row.price and item.variant==true and item.weekly==true and item.base==row.base,pet.." "..row.id)
			end
		end
		assert(Variants.problem(Variants.Rows)==nil)
		assert(Variants.problem({{id="x_y",base="x",name="X",color="#FFFFFF",weekly=true}})=="weekly x_y","a weekly row needs a price")
		assert(Variants.problem({{id="x_y",base="x",name="X",color="#FFFFFF",price=60,weekly=true,from=3}})=="weekly x_y","and no from")
	end)

	test("never a discount: no weekly row is ever on the weekly shelf, and the shelf picks what it picked before",function()
		for week=ThisWeek.Anchor-20,ThisWeek.Anchor+40 do
			off()
			local before=Shelf.compute(week,Shelf.pools)
			on()
			local after=Shelf.compute(week,Shelf.pools)
			assert(#before==#after,"week "..week)
			for i,slot in ipairs(after)do
				assert(slot.id==before[i].id and slot.price==before[i].price,"the shelf moved in week "..week)
				assert(not ThisWeek.isWeekly(slot.id),slot.id.." on the shelf")
			end
			for _,row in ipairs(ThisWeek.Rows)do assert(Shelf.price("wearable",row.id,week)==nil,row.id.." has a shelf price")end
		end
		clear()
	end)

	test("the listing: off lists none; on lists only this week's pick, for each pet that sells its base; math.huge all",function()
		off()
		for week=ThisWeek.Anchor,ThisWeek.Anchor+15 do assert(#weeklyIn("pip",week)==0 and ThisWeek.featured(week)==nil)end
		assert(#weeklyIn("pip",math.huge)==ThisWeek.Every,"a saved weekly item always renders")
		on()
		for week=ThisWeek.Anchor,ThisWeek.Anchor+15 do
			for _,pet in ipairs({"pip","blip"})do
				local list=weeklyIn(pet,week)
				assert(#list==1 and list[1]==ThisWeek.pick(week).id and ThisWeek.featured(week)==ThisWeek.pick(week),pet.." week "..week)
			end
		end
		assert(#weeklyIn("pip",math.huge)==ThisWeek.Every)
		clear()
	end)

	test("review B37: one pick per list (its key names it), and the clock's list never sells the pick in a slot tab",function()
		on()
		local rows,key=Variants.rows(ThisWeek.Anchor)
		assert(key==ThisWeek.pick(ThisWeek.Anchor).id,"the key is the pick")
		local weekly=0;for _,row in ipairs(rows)do if row.weekly then weekly+=1 end end
		assert(weekly==1)
		local all,allKey=Variants.rows(math.huge);assert(allKey=="*"and #all==#Variants.Rows)
		off()
		local _,offKey=Variants.rows(ThisWeek.Anchor);assert(offKey=="")
		on()
		local clock=ThisWeek.pick(ThisWeek.week())
		local slot=Wear.forPet("pip",math.huge).byId[clock.id].slot
		assert(Wear.forPet("pip").byId[clock.id]~=nil,"the clock's list holds the pick")
		for _,entry in ipairs(Wear.shopTab("pip",slot,{}))do assert(entry.id~=clock.id,"unowned, only the This week tab sells it")end
		for _,entry in ipairs(Wear.shopTab("pip",slot))do assert(entry.id~=clock.id)end
		clear()
		assert(ThisWeek.ceiling()==ThisWeek.ceiling(),"the build's own ceiling is stable")
	end)

	test("bought stays owned: a weekly item the pet owns is in its slot tab every week after, and wears",function()
		on()
		local clockPick=ThisWeek.pick(ThisWeek.week())
		local row=ThisWeek.Rows[1].id==clockPick.id and ThisWeek.Rows[2]or ThisWeek.Rows[1]
		local item=Wear.forPet("pip",math.huge).byId[row.id]
		local tab=Wear.shopTab("pip",item.slot,{row.id})
		local found=false;for _,entry in ipairs(tab)do if entry.id==row.id then found=true end end
		assert(found,"an owned weekly item stays in its slot tab outside its week")
		local unowned=Wear.shopTab("pip",item.slot,{})
		for _,entry in ipairs(unowned)do assert(entry.id~=row.id,"not owned, not this week: not listed")end
		local state={inventoryMask=require(Shared.EggCatalog).bit("pip"),petWearables={pip={owned={row.id},equipped={}}}}
		local worn=W.equipResult(state,"pip",item.slot,row.id)
		assert(worn and worn.equipped[item.keys[1]]==row.id,"it wears in any week")
		clear()
	end)

	-- The server path: the HatchProgress fixture (ShelfPurchase's), an injected switch.
	local function fixture(now)
		local db,c={},{now=now,serial=0,writes=0,failNext=nil}
		local adapter={
			now=function()return c.now end,
			guid=function()c.serial+=1;return "op"..c.serial end,
			random=function()return .1 end,
			wait=function()end,
			update=function(key,transform)
				c.writes+=1
				if c.failNext=="before"then c.failNext=nil;error("store down")end
				local value=transform(copy(db[key]))
				if value then db[key]=copy(value)end
				if c.failNext=="after"then c.failNext=nil;error("response lost")end
				return copy(value)
			end,
		}
		local h=H.load(1,{rank=1},adapter)
		assert(h.status=="Ready","fixture load "..tostring(h.status))
		return h,db,c
	end
	local function fund(h,stars)assert(H.grantPurchase(h,"fund-"..stars.."-"..h.state.revision,stars,false))end
	local function buy(h,op,id,price)return H.buyWearable(h,op,"pip",id,price,false)end
	local function owns(h,id)return W.owns(h.state,"pip",id)end

	test("server: the snapshot names the server's week; this week's pick sells at its price, once",function()
		on()
		local now=timeFor(1)
		local h=fixture(now);fund(h,500)
		assert(H.public(h).thisWeek==ThisWeek.week(now),"public.thisWeek")
		local wallet=h.state.nectar
		local saved,why=buy(h,"a","partyhat_plum",60)
		assert(saved and why=="Saved"and owns(h,"partyhat_plum")and h.state.nectar==wallet-60,tostring(why))
		local again,whyAgain=buy(h,"a","partyhat_plum",60)
		assert(again and whyAgain=="AlreadyOwned"and h.state.nectar==wallet-60,"the same operation never charges twice")
		local other,whyOther=buy(h,"b","partyhat_plum",60)
		assert(other and whyOther=="AlreadyOwned"and h.state.nectar==wallet-60,"a new operation for an owned item never charges")
		off()
		assert(H.public(h).thisWeek==nil,"off: no week in the snapshot")
		clear()
	end)

	test("server: a made-up price, another week's pick, or the switch off is refused with no charge",function()
		on()
		local h=fixture(timeFor(2));fund(h,500)
		local wallet=h.state.nectar
		for _,price in ipairs({48,59,61,40,0})do
			local ok,why=buy(h,"p"..price,"bands_sherbet",price)
			assert(not ok and why=="PriceChanged"and h.state.nectar==wallet and not owns(h,"bands_sherbet"),price.." "..tostring(why))
		end
		local ok,why=buy(h,"wrongweek","partyhat_plum",60)
		assert(not ok and why=="NotForSale"and h.state.nectar==wallet and not owns(h,"partyhat_plum"),"last week's pick: "..tostring(why))
		-- The week check reads the frozen week, never the clock's list.
		assert(select(2,W.check(h.state,"pip","bands_sherbet",60))=="NotForSale","a weekly id is never sold without its week")
		off()
		local refused,whyOff=buy(h,"off","bands_sherbet",60)
		assert(not refused and whyOff=="NotForSale"and h.state.nectar==wallet,"switch off: "..tostring(whyOff))
		on()
		assert(buy(h,"fair","bands_sherbet",60)and h.state.nectar==wallet-60)
		clear()
	end)

	test("server: the fourth week's pick is 150 Stars, and short of it is NeedStars with no charge",function()
		on()
		local h=fixture(timeFor(4,1));assert(H.betaSetStars(h,149),"the test wallet")
		local wallet=h.state.nectar
		local ok,why=buy(h,"short","hoodie_lantern",150)
		assert(not ok and why=="NeedStars"and h.state.nectar==wallet,tostring(why))
		fund(h,1)
		assert(buy(h,"big","hoodie_lantern",150)and h.state.nectar==wallet+1-150 and owns(h,"hoodie_lantern"),"a later cycle sells it again")
		clear()
	end)

	test("server: a week boundary between the request and the write uses the server's week and charges nothing",function()
		on()
		local now=timeFor(8)-3600+WEEK-60 -- the last minute of row 8's week
		local h,db,c=fixture(now);fund(h,500)
		local wallet=h.state.nectar
		c.failNext="before"
		local ok,why=buy(h,"edge","hoodie_tide",150)
		assert(not ok and why=="Retrying"and h.pending and h.pending.candidate.listWeek==ThisWeek.week(now),"the week is frozen")
		db.player_1.hatching.lease.expiresAt=c.now+WEEK+1000
		c.now+=120 -- past Monday 05:00 UTC: row 1's week
		local late,lateWhy=H.retry(h)
		assert(not late and lateWhy=="ShelfChanged",tostring(lateWhy))
		assert(h.pending==nil and not owns(h,"hoodie_tide")and db.player_1.hatching.nectar==wallet,"no charge, nothing stranded")
		-- The same request now: last week's pick is not for sale, this week's is.
		local stale,staleWhy=buy(h,"stale","hoodie_tide",150)
		assert(not stale and staleWhy=="NotForSale"and h.state.nectar==wallet)
		assert(buy(h,"now","partyhat_plum",60)and h.state.nectar==wallet-60)
		clear()
	end)

	test("server: an ambiguous write retried after the boundary pays exactly once",function()
		on()
		local now=timeFor(3)-3600+WEEK-60
		local h,db,c=fixture(now);fund(h,500)
		local wallet=h.state.nectar
		c.failNext="after"
		local ok,why=buy(h,"lost","specs_bluebell",60)
		assert(not ok and why=="Retrying"and db.player_1.hatching.nectar==wallet-60,"the write landed")
		db.player_1.hatching.lease.expiresAt=c.now+WEEK+1000
		c.now+=120
		local saved,savedWhy=H.retry(h)
		assert(saved and savedWhy=="Saved"and h.pending==nil and owns(h,"specs_bluebell")and h.state.nectar==wallet-60,tostring(savedWhy))
		-- Bought stays owned: worn the week after (and with the switch off).
		off()
		assert(H.equipWearable(h,"wear","pip","Eyewear","specs_bluebell"))
		assert(W.equipped(h.state,"pip").Eyewear=="specs_bluebell"and owns(h,"specs_bluebell"))
		clear()
	end)

	test("the switch: the Finds rules (ceiling, place, Studio, missing = on) and /thisweek",function()
		assert(ThisWeek.ceiling({flags={ThisWeek=false},studio=true})==false)
		assert(ThisWeek.ceiling({flags={ThisWeek=true},studio=false,place=ThisWeek.PlaceId})==true)
		assert(ThisWeek.ceiling({flags={ThisWeek=true},studio=false,place=96451847774961})==false,"never the live place")
		assert(ThisWeek.resolve(nil,nil,true)==true and ThisWeek.resolve("yes",nil,true)==true and ThisWeek.resolve(false,nil,true)==false)
		assert(ThisWeek.resolve(false,true,true)==true and ThisWeek.resolve(true,nil,false)==false)
		local p=Config.parse("/thisweek off");assert(p.feature=="thisweek"and p.value==false)
		assert(Config.parse(" /ThisWeek ON ").value==true and Config.parse("/thisweek clear").value==nil)
		assert(Config.parse("/thisweek maybe")==nil and Config.parse("/finds off")==nil and Config.parse(nil)==nil)
		ThisWeek.inject({on=true,studio=false,place=96451847774961,flags={ThisWeek=true}})
		assert(ThisWeek.on()==false and ThisWeek.featured(ThisWeek.Anchor)==nil,"the live place never opens")
		clear()
	end)
	end)
	clear()
	if not ok then error(problem,0)end
	return{passed=#cases,cases=cases}
end
