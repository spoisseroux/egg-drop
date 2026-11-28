-- Rotation slice 2 (artifacts/qa-2026-11-28-rotation/ROTATION-2-BRIEF.md, ARCH-REVIEW-ROTATION-2 1-9): the three switches
-- (rack_toys, rack_deck, rack_wings under daily_rack, owner chat); Angel Wings (an egg-only base: never one of the daily 8,
-- never in a Wardrobe sale list, the wings-day sparkle pick at a flat 1% only while unowned, never on the fixed path, the
-- slice 1 schedule with the switch off, the other sparkle picks back within 10 days); the Toy Colour Egg's data and deal
-- (24 skins, a toy back within 3 days, a colour within 9, locked picks at 0 units) and the Deck Egg's (12 plates, 11 ball
-- themes, everything back within 11 days); the shown odds against a 100k-roll sample on each of 30 days for every egg; the
-- save path per egg (one charge per request id, a store error, what the player did not see, never an owned item, the egg
-- resting, restricted players' `next`); the deck grant re-checking ownership and the 64 limits inside the write; Deck style
-- as a closet (FromDeckEgg); toySkinWear and the published `toySkin`; a malformed rack.toy refusing only toy actions; the
-- 128 write cap with a 256 load limit. Offline: scripts/run_dash_server_specs.py.
return function(server)
	local H=require(server.HatchProgress)
	local RackState=require(server.RackState)
	local W=require(server.WearableState)
	local FP=require(server.FaceplateState)
	local BT=require(server.BallThemeState)
	local A=require(server.PetAppearance)
	local Config=require(server.RackConfig)
	local Shared=game:GetService("ReplicatedStorage").Shared
	local Rack=require(Shared.DailyRack)
	local Skins=require(Shared.ToySkins)
	local Deck=require(Shared.DeckRack)
	local Wear=require(Shared.WearableCatalog)
	local Defs=require(Shared.PetRigDefinitions)
	local Rules=require(Shared.PetAttachmentRules)
	local Toys=require(Shared.ToyCatalog)
	local Plates=require(Shared.DeckThemes)
	local Balls=require(Shared.BallThemes)
	local cases={}
	local function test(name,run)run();table.insert(cases,name)end
	local function copy(v)if type(v)~="table"then return v end;local r={};for k,x in pairs(v)do r[k]=copy(x)end;return r end
	local function same(a,b)
		if type(a)~=type(b)then return false end
		if type(a)~="table"then return a==b end
		for k,v in pairs(a)do if not same(v,b[k])then return false end end
		for k in pairs(b)do if a[k]==nil then return false end end
		return true
	end
	local DAY0=20420
	local function on(parts)
		local env={flags={DailyRack=true},studio=true}
		for k,v in pairs(parts or {})do env[k]=v end
		assert(Rack.inject(env),"inject needs Studio (or the offline mocks)")
	end
	local ALLTOYS={ball=true,bone=true,sparkler=true,wobble_top=true,squeaky_carrot=true,pocket_deck=true}
	local fixtures=0
	local function adapterFor(db,c)
		return {now=function()return c.now end,guid=function()c.serial+=1;return c.prefix..c.serial end,
			random=function()return c.unit or .5 end,wait=function()end,
			update=function(key,transform)
				c.writes+=1
				if c.failNext=="before"then c.failNext=nil;error("store down")end
				local value=transform(copy(db[key]))
				if value then db[key]=copy(value)end
				if c.failNext=="after"then c.failNext=nil;error("response lost")end
				return copy(value)
			end}
	end
	local function rejoin(h,db,c,changes)
		H.release(h);c.now+=200
		local saved=db.player_1.hatching
		saved.lease.expiresAt=0
		for k,v in pairs(changes or {})do saved[k]=copy(v)end
		local again=H.load(1,{},adapterFor(db,c));assert(again.status=="Ready","rejoin "..tostring(again.status))
		again.restricted=h.restricted
		return again
	end
	local function fresh(changes)
		fixtures+=1
		local db,c={},{now=1795410000+3600,serial=0,writes=0,prefix="s2_"..fixtures.."_"}
		local h=H.load(1,{},adapterFor(db,c));assert(h.status=="Ready","fixture "..tostring(h.status))
		assert(H.grantStarter(h,false,false))
		assert(H.command(h,"ack",h.state.lastHatch.id,h.state.revision))
		h.restricted=false
		local base={nectar=5000,toyUnlocks=ALLTOYS}
		for k,v in pairs(changes or {})do base[k]=v end
		return rejoin(h,db,c,base),db,c
	end
	local serial=0
	local function ask(h,egg,overrides)
		local rack=H.public(h).rack
		local view=if egg=="outfit"then rack.pets.pip else rack[egg=="toycolour"and "toy"or egg]
		serial+=1
		local r={requestId="s2req-"..serial,petId="pip",day=rack.day,price=view.price or rack.price,mode=view.mode or rack.mode,poolKey=view.poolKey}
		for k,v in pairs(overrides or {})do r[k]=v end
		return r,view
	end
	-- Park-Miller: exact in doubles, the same sample every run.
	local function sampler(seed)return function()seed=seed*16807%2147483647;return seed/2147483647 end end
	-- The shown odds against 100k rolls, and every unit enumerated (the roll is the shown odds exactly).
	local function checkOdds(view,label)
		local rows={}
		for _,r in ipairs(view.items)do table.insert(rows,r)end
		if view.sparkle then table.insert(rows,view.sparkle)end
		local sum,percent=0,0
		for _,r in ipairs(rows)do sum+=r.units;percent+=r.percent end
		assert(sum==view.total and math.abs(percent-100)<1e-9,label..": the units are the whole egg")
		if view.total<=20000 then
			local counts={}
			for u=0,view.total-1 do local id=Rack.roll(view,(u+.5)/view.total);counts[id]=(counts[id]or 0)+1 end
			for _,r in ipairs(rows)do assert((counts[r.id]or 0)==r.units,label..": enumerated "..r.id)end
		end
		local draw,counts=sampler(1000+view.day),{}
		local N=100000
		for _=1,N do local id=Rack.roll(view,draw());counts[id]=(counts[id]or 0)+1 end
		for _,r in ipairs(rows)do
			local p=r.units/view.total
			local tol=5*math.sqrt(p*(1-p)/N)+1e-4
			assert(math.abs((counts[r.id]or 0)/N-p)<=tol,label..": "..r.id.." rolled "..((counts[r.id]or 0)/N).." vs shown "..p)
			assert(math.abs(r.percent/100-p)<1e-12,label..": the shown percent is the units")
		end
	end

	local ok,problem=pcall(function()
	test("the switches: rack_toys, rack_deck, rack_wings (missing = on) each need daily_rack; owner chat",function()
		for _,feature in ipairs({"toys","deck","wings"})do
			assert(table.find(Rack.Features,feature)and Rack.Defaults[feature]==true and Rack.Needs[feature]=="rack")
			assert(Rack.resolve(feature,nil,nil,true)==true and Rack.resolve(feature,false,nil,true)==false and Rack.resolve(feature,true,nil,false)==false)
		end
		assert(Rack.key("toys")=="rack_toys"and Rack.key("deck")=="rack_deck"and Rack.key("wings")=="rack_wings")
		assert(Rack.attribute("toys")=="RackToys_on"and Rack.attribute("deck")=="RackDeck_on"and Rack.attribute("wings")=="RackWings_on")
		on();assert(Rack.on("toys")and Rack.on("deck")and Rack.on("wings"))
		on({rack=false});assert(not Rack.on("toys")and not Rack.on("deck")and not Rack.on("wings"),"under daily_rack")
		on({deck=false});assert(Rack.on("toys")and not Rack.on("deck")and Rack.on("rack"))
		local p=Config.parse("/rack toys off");assert(p and p.features[1]=="toys"and p.value==false)
		p=Config.parse("/rack wings clear");assert(p and p.features[1]=="wings"and p.value==nil)
		p=Config.parse("/rack deck on");assert(p and p.features[1]=="deck"and p.value==true)
		assert(same(Rack.Eggs,{"outfit","toycolour","deck"}))
		Rack.inject(nil)
	end)

	test("Angel Wings: an egg-only Back base for the Bear and the Bunny; never one of the daily 8 or on any sale list",function()
		for _,pet in ipairs({"pip","blip"})do
			local item=Wear.forPet(pet,math.huge).byId.angelwings
			assert(item and item.slot=="Back"and item.egg==true and item.eggBase and not item.variant and item.finish=="sparkle"and item.price==nil,pet)
			assert(#Wear.eggBases(pet)==1 and Rack.wings(pet).id=="angelwings")
			for _,row in ipairs(Wear.forPet(pet,math.huge).order)do assert(row.id~="angelwings","never in `order`")end
			assert(Wear.forPet(pet).byId.angelwings==nil and #Wear.inTab(pet,"Back")==0,"never listed this week")
			for _,tab in ipairs(Wear.tabsFor(pet))do assert(tab.slot~="Back","no Back tab without it")end
			local tabs=Wear.tabsFor(pet,{"angelwings"});assert(tabs[#tabs].slot=="Back","the Back tab once owned")
			assert(#Wear.shopTab(pet,"Back",{})==0 and Wear.shopTab(pet,"Back",{"angelwings"})[1].id=="angelwings")
			assert(#Wear.closetTab(pet,"Back",{})==0 and Wear.closetTab(pet,"Back",{"angelwings"})[1].id=="angelwings")
			assert(not Wear.closetSells(item))
			local s={inventoryMask=require(Shared.EggCatalog).bit(pet),nectar=99999,petWearables={}}
			for _,args in ipairs({{nil},{nil,nil,true},{nil,nil,nil,Wear.week()},{nil,nil,nil,nil,true}})do
				assert(select(2,W.check(s,pet,"angelwings",table.unpack(args)))=="NotForSale","never sold")
			end
			for day=DAY0,DAY0+365 do for _,row in ipairs(Rack.picks(pet,day))do assert(row.id~="angelwings","never a daily pick")end end
		end
		assert(Wear.forPet("puddle",math.huge).byId.angelwings==nil and Rack.wings("puddle")==nil,"no mount, not in its pool")
		assert(#Wear.compose("pip",{}).order==23,"compose without egg bases is the rig as before")
		-- the rig rows: two Back pieces on the stage 5 wing templates, in Snow; worn, they hide the grown wings
		local bear=Defs.pip
		local rows={};for _,a in ipairs(bear.attachments)do if a.item=="angelwings"then table.insert(rows,a)end end
		assert(#rows==2 and Defs.blip.attachments==bear.attachments,"the Bunny inherits them")
		for _,a in ipairs(rows)do
			assert(a.slot=="Back"and(a.anchor=="WingL"or a.anchor=="WingR")and a.colorRole=="own"and a.color=="#F4F6FB")
			assert(a.template==a.name and(a.name=="WingL_S5"or a.name=="WingR_S5"))
		end
		local shown=Rules.resolve(bear,{wings=5},{Back="angelwings"})
		assert(shown.stages.wings==0,"a Back wearable hides the grown wings")
		local n=0;for _,a in ipairs(shown.show)do if a.item=="angelwings"then n+=1 end end;assert(n==2)
		assert(Rules.resolve(bear,{wings=5},{}).stages.wings==5,"off: they come back")
		assert(Wear.Tabs[#Wear.Tabs].id=="back"and Wear.Tabs[#Wear.Tabs].slot=="Back","append-only")
	end)

	test("the wings day: day mod 9 == 4, Angel Wings the sparkle pick at a flat 1% while unowned; off is slice 1 exactly",function()
		local wingsDays=0
		for day=DAY0,DAY0+365 do
			local slice1=Rack.view("pip",day,{},"random")
			local off=Rack.view("pip",day,{},"random",false)
			assert(same(slice1,off),"off: the slice 1 schedule exactly")
			local v=Rack.view("pip",day,{},"random",true)
			if day%9==4 then
				wingsDays+=1
				assert(v.sparkle.id=="angelwings"and v.sparkle.wings and v.sparkle.rarity=="legendary"and v.sparkle.finish=="sparkle")
				assert(math.abs(v.sparkle.percent-1)<1e-12,"the same flat 1%")
				assert(Rack.rarityOf("pip",day,"angelwings",true)=="legendary"and Rack.rarityOf("pip",day,"angelwings",false)==nil)
				local owned=Rack.view("pip",day,{"angelwings"},"random",true)
				assert(owned.sparkle.id==Rack.sparkle("pip",day).id,"owned: the regular sparkle pick")
				assert(Rack.view("pip",day,{},"fixed",true).sparkle.units==0,"never on the fixed path")
			else
				assert(same(v,slice1),"other days unchanged")
			end
		end
		assert(wingsDays>=40)
		-- the other five sparkle picks return within 10 days with wings on (and unowned)
		local last,gap={},{}
		for day=DAY0,DAY0+365 do
			local s=Rack.view("pip",day,{},"random",true).sparkle
			if not s.wings then
				if last[s.id]then gap[s.id]=math.max(gap[s.id]or 0,day-last[s.id])end
				last[s.id]=day
			end
		end
		local n=0;for id,g in pairs(gap)do n+=1;assert(g<=10,id.." back within 10 days: "..g)end
		assert(n==5)
		-- the only way in is the roll: no fixed path, no gift, no sale (above), and a roll on a wings day
		on()
		local h=fresh({toyUnlocks=ALLTOYS})
		h.restricted=true
		local pub=H.public(h).rack
		assert(pub.pets.pip.next~="angelwings")
		Rack.inject(nil)
	end)

	test("toy colours: 24 skins, 4 per toy, the brief's hexes and names; only the named part; ids and the 64 cap",function()
		assert(#Skins.Rows==24 and #Skins.Order==24)
		local want={ball={"FeltBall","#5CBEF5","#FF86C8","#2F2C7C","#F0B429"},bone={"BoneBody","#7FE0CF","#9B7BE8","#2F2C7C","#F0B429"},
			sparkler={"IndigoGrip","#E9574C","#7FE0CF","#9B7BE8","#F2A0A8"},wobble_top={"TealBody","#E9574C","#9B7BE8","#2F2C7C","#F0B429"},
			squeaky_carrot={"CarrotBody","#FFD86B","#9B7BE8","#F4F6FB","#F0B429"},pocket_deck={"DeckShell","#5CBEF5","#FF86C8","#2F2C7C","#F0B429"}}
		for toy,w in pairs(want)do
			local rows=Skins.ByToy[toy];assert(#rows==4)
			for i,rarity in ipairs({"common","uncommon","rare","epic"})do
				assert(rows[i].rarity==rarity and rows[i].hex==w[i+1]and rows[i].part==w[1]and rows[i].toy==toy,toy.." "..rarity)
				assert(Skins.get(rows[i].id)==rows[i]and Skins.idShape(rows[i].id))
			end
		end
		assert(Skins.get("ball_sky").name=="Sky Ball"and Skins.get("squeaky_carrot_grape").name=="Purple Carrot")
		assert(Skins.Price==15 and Skins.OwnedLimit==64)
		-- the published colour: only an owned skin of that toy, known to this build
		assert(Skins.shown({owned={ball_sky=true},worn={ball="ball_sky"}},"ball")=="ball_sky")
		assert(Skins.shown({owned={},worn={ball="ball_sky"}},"ball")==nil,"not owned: the original")
		assert(Skins.shown({owned={bone_mint=true},worn={ball="bone_mint"}},"ball")==nil,"another toy's skin")
		assert(Skins.shown({owned={ball_later=true},worn={ball="ball_later"}},"ball")==nil,"an unknown skin draws the original")
		local over={};for i=1,65 do over["s"..i]=true end
		assert(Skins.read({owned=over}).broken and not Skins.read({owned={x=true},extra=1}).broken,"64 cap; unknown keys kept")
		assert(Skins.read({owned={["Bad"]=true}}).broken and Skins.read({owned={a="yes"}}).broken and Skins.read("x").broken)
	end)

	test("the Toy Colour Egg's deal: 3 toys a day, every toy each 2-day cycle, a toy back in 3 days, a colour in 9",function()
		local lastToy,lastSkin,gapToy,gapSkin={},{},0,0
		for c=DAY0//2,DAY0//2+60 do
			local seen={}
			for k=0,1 do for _,r in ipairs(Skins.picks(c*2+k))do assert(not seen[r.toy],"once a cycle");seen[r.toy]=true end end
			local n=0;for _ in pairs(seen)do n+=1 end;assert(n==6)
		end
		for day=DAY0,DAY0+365 do
			local picks=Skins.picks(day);assert(#picks==3)
			for _,r in ipairs(picks)do
				if lastToy[r.toy]then gapToy=math.max(gapToy,day-lastToy[r.toy])end;lastToy[r.toy]=day
				if lastSkin[r.id]then gapSkin=math.max(gapSkin,day-lastSkin[r.id])end;lastSkin[r.id]=day
				assert(r.id==Skins.colours(r.toy)[(day//2)%4+1].id,"cycle c shows list[(c mod 4) + 1]")
			end
		end
		assert(gapToy<=3 and gapSkin<=9,gapToy.." "..gapSkin)
		local n=0;for _ in pairs(lastSkin)do n+=1 end;assert(n==24,"every colour shows")
		-- a pick whose toy is not owned is locked with 0 units; nothing owned: the egg rests
		local day=DAY0
		local picks=Skins.picks(day)
		local unlocks={[picks[1].toy]=true}
		local v=Skins.view(day,unlocks,{},"random")
		assert(v.items[1].units==v.total and v.items[2].locked and v.items[2].units==0 and not v.items[1].locked)
		assert(Skins.view(day,{},{},"random").rest,"no toy: rests")
		local full=Skins.view(day,ALLTOYS,{[picks[1].id]=true,[picks[2].id]=true,[picks[3].id]=true},"random")
		assert(full.rest and full.total==0 and Rack.roll(full,.5)==nil)
		-- restricted: the first unowned unlocked pick, common first
		local fixed=Skins.view(day,ALLTOYS,{},"fixed")
		local best=nil;for _,r in ipairs(fixed.items)do if best==nil or Rack.rank[r.rarity]<Rack.rank[best.rarity]then best=r end end
		assert(fixed.next==best.id and fixed.total==1 and Rack.roll(fixed,.99)==best.id)
	end)

	test("the Deck Egg's deal: 12 plates and 11 ball themes by tier; 2 + 2 a day; everything back within 11 days",function()
		assert(#Deck.Plates==12 and #Deck.Balls==11 and Deck.Price==60)
		local rarity={common=0,rare=0,epic=0}
		for _,id in ipairs(Deck.Plates)do
			local t=Plates.ById[id];assert(Plates.price(id)and t.gate==nil and not t.bookOnly);rarity[Deck.ById[id].rarity]+=1
		end
		assert(rarity.common==4 and rarity.rare==6 and rarity.epic==2)
		rarity={common=0,rare=0,epic=0}
		for _,id in ipairs(Deck.Balls)do assert(Balls.price(id)and Balls.ById[id].gate==nil);rarity[Deck.ById[id].rarity]+=1 end
		assert(rarity.common==3 and rarity.rare==6 and rarity.epic==2)
		-- every sold, ungated plate and theme is in the egg; starters, Book and level goals never
		for id,t in pairs(Plates.ById)do if Plates.price(id)and t.gate==nil then assert(Deck.ById[id],id)end end
		for _,id in ipairs({"cloud_glass","sherbet","bookworm","stargazer","sky_fizz","storm_glass"})do assert(Deck.ById[id]==nil,id)end
		for _,id in ipairs(Balls.Order)do if Balls.price(id)then assert(Deck.ById[id],id)else assert(not Deck.ById[id])end end
		assert(Deck.ById.tangerine_pop==nil)
		local last,gap={},0
		for day=DAY0,DAY0+365 do
			local picks=Deck.picks(day);assert(#picks==4 and picks[1].kind=="plate"and picks[2].kind=="plate"and picks[3].kind=="ball"and picks[4].kind=="ball")
			assert(picks[1].id~=picks[2].id and picks[3].id~=picks[4].id)
			for _,r in ipairs(picks)do
				assert(r.rarity~="legendary")
				if last[r.id]then gap=math.max(gap,day-last[r.id])end;last[r.id]=day
			end
		end
		local n=0;for _ in pairs(last)do n+=1 end
		assert(n==23 and gap<=11,"back within 11 days: "..gap)
		-- the brief's typical day (1 common, 2 rare, 1 epic): 56.25 / 18.75 / 18.75 / 6.25
		for day=DAY0,DAY0+60 do
			local v=Deck.view(day,{},{"smileys","marbles"},"random")
			local c={common=0,rare=0,epic=0};for _,r in ipairs(v.items)do c[r.rarity]+=1 end
			if c.common==1 and c.rare==2 and c.epic==1 then
				for _,r in ipairs(v.items)do assert(math.abs(r.percent-({common=56.25,rare=18.75,epic=6.25})[r.rarity])<1e-9)end
				break
			end
		end
	end)

	test("odds: 100k rolls against the shown odds on each of 30 days, every egg (the outfit with its wings days)",function()
		local wingsDays=0
		for day=DAY0,DAY0+29 do
			local outfit=Rack.view("pip",day,{},"random",true)
			if outfit.sparkle.wings then wingsDays+=1 end
			checkOdds(outfit,"outfit "..day)
			checkOdds(Skins.view(day,ALLTOYS,{},"random"),"toycolour "..day)
			checkOdds(Deck.view(day,{},{"smileys","marbles"},"random"),"deck "..day)
		end
		assert(wingsDays>=3,"the 30 days hold wings days: "..wingsDays)
		-- part-owned days too: a pick owned leaves the pool, the rest scale up
		local day=DAY0+4
		local picks=Skins.picks(day)
		checkOdds(Skins.view(day,ALLTOYS,{[picks[1].id]=true},"random"),"toycolour part-owned")
		local deck=Deck.picks(day)
		checkOdds(Deck.view(day,{deck[1].id},{"smileys","marbles",deck[3].id},"random"),"deck part-owned")
	end)

	test("the Toy Colour Egg and the Deck Egg: one charge per request id, a store error, never an owned item, then rest",function()
		on()
		for _,egg in ipairs({"toycolour","deck"})do
			local h,db,c=fresh()
			local price=RackState.price(egg)
			local before=h.state.nectar
			local request,view=ask(h,egg)
			assert(view and view.price==price and #view.items==(egg=="deck"and 4 or 3))
			local okB,why,record=H.rackEgg(h,egg,request)
			assert(okB and why=="Saved",egg..": "..tostring(why))
			assert(h.state.nectar==before-price and db.player_1.hatching.nectar==before-price)
			assert(record.egg==egg and record.pet=="pip"and record.item and record.rarity and record.id==request.requestId)
			if egg=="deck"then assert(record.kind==Deck.kindOf(record.item))end
			local writes=c.writes
			local again,whyAgain,r2=H.rackEgg(h,egg,request)
			assert(again and whyAgain=="AlreadySaved"and r2.item==record.item and c.writes==writes and h.state.nectar==before-price,"replay")
			local other=rejoin(h,db,c)
			assert(select(2,H.rackEgg(other,egg,request))=="AlreadySaved"and other.state.nectar==before-price,"another server")
			-- buy until it rests: every item distinct, never one already owned, at most the day's picks
			h=other
			local got={record.item}
			while true do
				local rq,v=ask(h,egg)
				if v.rest then assert(select(2,H.rackEgg(h,egg,rq))=="RackDone");break end
				local okN,whyN,rN=H.rackEgg(h,egg,rq)
				assert(okN and whyN=="Saved",tostring(whyN))
				assert(not table.find(got,rN.item),"never an owned item: "..rN.item)
				table.insert(got,rN.item)
			end
			assert(#got==(egg=="deck"and 4 or 3))
			if egg=="deck"then
				local plates,balls=0,0
				for _,id in ipairs(got)do
					if Deck.kindOf(id)=="plate"then plates+=1;assert(FP.owns(h.state,id))else balls+=1;assert(BT.owns(h.state,id))end
				end
				assert(plates==2 and balls==2 and BT.valid(h.state)and FP.valid(h.state),"the owned lists stay valid")
			else
				local toy=RackState.toy(h.state)
				for _,id in ipairs(got)do assert(toy.owned[id])end
			end
			-- a store error before the write, then the frozen candidate
			local g,dbg,cg=fresh()
			local rq=ask(g,egg);local b=g.state.nectar
			cg.failNext="before"
			assert(select(2,H.rackEgg(g,egg,rq))=="Retrying")
			cg.unit=.01
			local okR,whyR=H.rackEgg(g,egg,rq);assert(okR and whyR=="Saved"and g.state.nectar==b-price)
			cg.failNext="after"
			local rq2=ask(g,egg);local b2=g.state.nectar
			assert(select(2,H.rackEgg(g,egg,rq2))=="Retrying")
			local okA,whyA=H.rackEgg(g,egg,rq2)
			assert(okA and(whyA=="Saved"or whyA=="AlreadySaved")and g.state.nectar==b2-price and dbg.player_1.hatching.nectar==b2-price)
		end
		Rack.inject(nil)
	end)

	test("what the player did not see answers with no charge, per egg; restricted players get `next` per egg",function()
		on()
		for _,egg in ipairs({"toycolour","deck"})do
			local h,db,c=fresh()
			local stars,writes=h.state.nectar,c.writes
			for field,case in pairs({day={Rack.today(c.now)-1,"DayChanged"},price={RackState.price(egg)+1,"PriceChanged"},
				mode={"fixed","PolicyChanged"},poolKey={"deadbeef","PoolChanged"}})do
				assert(select(2,H.rackEgg(h,egg,ask(h,egg,{[field]=case[1]})))==case[2],egg.." "..field)
			end
			assert(select(2,H.rackEgg(h,egg,ask(h,egg,{petId="puddle"})))=="Unowned")
			assert(h.state.nectar==stars and db.player_1.hatching.rack==nil,"no charge, no write")
			assert(c.writes>=writes)
			h.restricted=true
			local rq,view=ask(h,egg)
			assert(view.mode=="fixed"and view.next and view.total==1)
			local okF,whyF,r=H.rackEgg(h,egg,rq)
			assert(okF and whyF=="Saved"and r.item==view.next,egg..": "..tostring(whyF))
		end
		Rack.inject(nil)
	end)

	test("switches off are slice 1: no toy or deck snapshot, NotReady, no wings, Deck style sells as today",function()
		on({toys=false,deck=false,wings=false})
		local h,db,c=fresh()
		local rack=H.public(h).rack
		assert(rack and rack.toy==nil and rack.deck==nil and rack.pets.pip,"the outfit egg alone")
		local day=Rack.today(c.now)
		local req={requestId="off-1",petId="pip",day=day,price=15,mode="random",poolKey="0"}
		assert(select(2,H.rackEgg(h,"toycolour",req))=="NotReady")
		req.price=60;assert(select(2,H.rackEgg(h,"deck",req))=="NotReady")
		assert(select(2,H.toySkinWear(h,"off-w","ball","ball_sky"))=="NotReady")
		local okP,whyP=H.buyFaceplate(h,"off-p","aqua_pop",40);assert(okP and whyP~="FromDeckEgg",tostring(whyP))
		local okB,whyB=H.buyBallTheme(h,"off-b","gumdrops",40,false);assert(okB,tostring(whyB))
		-- a wings day with wings off: the slice 1 sparkle pick
		for d=day,day+9 do
			if d%9==4 then assert(Rack.view("pip",d,{},"random",Rack.on("wings")).sparkle.id==Rack.sparkle("pip",d).id)end
		end
		local p=A.public({companionId="pip"},nil,nil,nil,{pip="ball"},nil,"pip",nil,{rack={v=1,toy={owned={ball_sky=true},worn={ball="ball_sky"}}}})
		assert(p.pip.toySkin==nil,"off: every toy draws its original colour")
		on({rack=false})
		assert(H.public(h).rack==nil)
		Rack.inject(nil)
	end)

	test("Deck style as a closet: a direct plate or ball buy is FromDeckEgg, no charge; level goals sell; owned stays",function()
		on()
		local h=fresh()
		local stars,revision=h.state.nectar,h.state.revision
		assert(select(2,H.buyFaceplate(h,"cl-p","aqua_pop",40))=="FromDeckEgg")
		assert(select(2,H.buyBallTheme(h,"cl-b","gumdrops",40,false))=="FromDeckEgg")
		assert(h.state.nectar==stars and h.state.revision==revision and not FP.owns(h.state,"aqua_pop"))
		local _,whyG=FP.check(h.state,"sky_fizz",nil,nil,true,true);assert(whyG~="FromDeckEgg","a level goal stays: "..tostring(whyG))
		local _,whyT=BT.check(h.state,"tangerine_pop",nil,nil,true,true);assert(whyT~="FromDeckEgg")
		assert(select(2,FP.check(h.state,"aqua_pop",nil,nil,nil,nil))~="FromDeckEgg","nil (an older pending purchase) = off")
		assert(H.public(h).rack.deck.closet==true)
		-- bought before the switch: owned, no second charge
		local s=copy(h.state);s.faceplates={"aqua_pop"}
		local v=Deck.view(Rack.today(1795410000+3600),s.faceplates,{"smileys","marbles"},"random")
		for _,r in ipairs(v.items)do if r.id=="aqua_pop"then assert(r.owned and r.units==0)end end
		Rack.inject(nil)
	end)

	test("review 6: the deck grant re-checks ownership and the 64 limits inside the write; a duplicate theme is never saved",function()
		local s={faceplates={"aqua_pop"},ballThemes={owned={"smileys","marbles","gumdrops"},equipped="smileys"}}
		local grant=RackState.Eggs.deck.grant
		assert(select(2,grant(s,{},"aqua_pop"))=="AlreadyOwned"and #s.faceplates==1)
		assert(select(2,grant(s,{},"gumdrops"))=="AlreadyOwned"and #s.ballThemes.owned==3)
		assert(grant(s,{},"kittens")and s.ballThemes.owned[4]=="kittens"and BT.valid(s))
		local full={};for i=1,64 do full[i]="p"..i end
		local f={faceplates=full,ballThemes={owned={"smileys","marbles"},equipped="smileys"}}
		assert(select(2,grant(f,{},"lime_gel"))=="ShelfFull"and #f.faceplates==64)
		local balls={"smileys","marbles"};for i=3,64 do balls[i]="b"..i end
		local b={faceplates={},ballThemes={owned=balls,equipped="smileys"}}
		assert(select(2,grant(b,{},"gems"))=="ShelfFull"and #b.ballThemes.owned==64)
		-- the whole write: a full shelf refuses ShelfFull with no charge
		on()
		local h,db=fresh({faceplates=full})
		local rq,view=ask(h,"deck")
		assert(view.full)
		assert(select(2,H.rackEgg(h,"deck",rq))=="ShelfFull"and db.player_1.hatching.nectar==5000)
		Rack.inject(nil)
	end)

	test("toySkinWear: an owned colour on an unlocked toy, 'none' the original; refusals; the published toySkin",function()
		on()
		local h,db=fresh({rack={v=1,toy={owned={ball_sky=true,bone_mint=true},worn={}}}})
		assert(select(2,H.toySkinWear(h,"w0","ball","ball_gold"))=="NotOwned")
		assert(select(2,H.toySkinWear(h,"w1","ball","bone_mint"))=="InvalidSkin")
		assert(select(2,H.toySkinWear(h,"w2","none","ball_sky"))=="InvalidSkin")
		local okW,whyW=H.toySkinWear(h,"w3","ball","ball_sky");assert(okW and whyW=="Saved",tostring(whyW))
		assert(db.player_1.hatching.rack.toy.worn.ball=="ball_sky"and db.player_1.hatching.rack.toy.owned.bone_mint)
		local again,whyA=H.toySkinWear(h,"w3","ball","ball_sky");assert(again,tostring(whyA))
		assert(select(2,H.toySkinWear(h,"w4","ball","ball_sky"))=="NoChange")
		assert(H.public(h).rack.toy.worn.ball=="ball_sky"and H.public(h).rack.toy.owned.ball_sky)
		local p=A.public({companionId="pip"},nil,nil,nil,{pip="ball"},nil,"pip",nil,h.state)
		assert(p.pip.toyId=="ball"and p.pip.toySkin=="ball_sky","other players see the colour")
		p=A.public({companionId="pip"},nil,nil,nil,{pip="bone"},nil,"pip",nil,h.state)
		assert(p.pip.toySkin==nil,"a toy without a worn colour: the original")
		assert(H.toySkinWear(h,"w5","ball","none")and db.player_1.hatching.rack.toy.worn.ball==nil)
		local g=fresh({toyUnlocks={bone=true},rack={v=1,toy={owned={ball_sky=true}}}})
		assert(select(2,H.toySkinWear(g,"w6","ball","ball_sky"))=="LockedToy")
		-- the egg with equip wears the colour in the same write
		local e=fresh()
		local rq=ask(e,"toycolour",{equip=true})
		local okE,_,r=H.rackEgg(e,"toycolour",rq);assert(okE)
		assert(RackState.toy(e.state).worn[Skins.get(r.item).toy]==r.item)
		Rack.inject(nil)
	end)

	test("review 9: a malformed rack.toy refuses only toy actions and is never written over; the outfit egg still works",function()
		on()
		local bad={v=1,toy={owned="junk"},keep="later"}
		local h,db=fresh({rack=bad})
		local pub=H.public(h).rack
		assert(not pub.broken and pub.toy.broken and pub.toy.rest,"the rack is fine, the toy egg rests")
		assert(select(2,H.rackEgg(h,"toycolour",ask(h,"toycolour")))=="RackBroken")
		assert(select(2,H.toySkinWear(h,"bw","ball","ball_sky"))=="RackBroken")
		local okO,whyO=H.rackEgg(h,"outfit",ask(h,"outfit"));assert(okO and whyO=="Saved",tostring(whyO))
		local okD,whyD=H.rackEgg(h,"deck",ask(h,"deck"));assert(okD and whyD=="Saved",tostring(whyD))
		assert(db.player_1.hatching.rack.toy.owned=="junk"and db.player_1.hatching.rack.keep=="later","never written over; unknown keys kept")
		-- a later build's skins and keys survive a toy egg write
		local g,dbg=fresh({rack={v=1,toy={owned={ball_later=true},worn={wand="wand_x"},next=7}}})
		assert(H.rackEgg(g,"toycolour",ask(g,"toycolour")))
		local t=dbg.player_1.hatching.rack.toy
		assert(t.owned.ball_later and t.worn.wand=="wand_x"and t.next==7)
		-- a long egg id in `last` is broken (review 9: last.egg <= 16)
		assert(RackState.read({rack={v=1,last={op="a",egg=string.rep("e",17),pet="pip",item="x",rarity="common",day=1}}}).broken)
		Rack.inject(nil)
	end)

	test("the 128 write cap with a 256 load limit (review 4): loads accept more; every write still refuses at 128",function()
		assert(W.Limit==128 and W.LoadLimit==256 and Wear.LoadLimit==256)
		local owned={};for i=1,200 do owned[i]="later_"..i end
		local s={inventoryMask=1,nectar=9999,petWearables={pip={owned=owned,equipped={}}}}
		assert(W.valid(s),"a later build's 200 load")
		local over={};for i=1,257 do over[i]="later_"..i end
		assert(not W.valid({inventoryMask=1,petWearables={pip={owned=over,equipped={}}}}))
		assert(select(2,W.grant(s,"pip","beanie_sky"))=="ClosetFull"and #s.petWearables.pip.owned==200)
		assert(select(2,W.grant(s,"pip","angelwings"))=="ClosetFull")
		assert(select(2,W.check(s,"pip","beanie",nil))=="OwnedLimit")
		local exact={};for i=1,127 do exact[i]="x"..i end
		local t={inventoryMask=1,petWearables={pip={owned=exact,equipped={}}}}
		assert(W.grant(t,"pip","angelwings",true)and #t.petWearables.pip.owned==128 and t.petWearables.pip.equipped.Back=="angelwings")
		assert(select(2,W.grant(t,"pip","beanie_sky"))=="ClosetFull")
	end)
	end)
	Rack.inject(nil)
	if not ok then error(problem,0)end
	return {passed=#cases,cases=cases}
end
