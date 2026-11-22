-- Level-gated Star purchases (WearableState, BallThemeState, FaceplateState through HatchProgress;
-- V3-LEVELS-BUILD-PLAN-2026-11-22 S2). Below the gate is NeedsLevel with no charge, read from the save
-- inside the transaction; at the gate it buys once under retry, replay and a lost reply; with gates
-- off a gated id is NotForSale and an owned one stays wearable. Ungated prices never move.
-- Isolated adapters only; no DataStore or user writes.
-- Usage (Server): require(ServerScriptService.Server.ZZSpecs.GatedPurchase)(ServerScriptService.Server)
return function(server)
	local H=require(server.HatchProgress)
	local W=require(server.WearableState)
	local B=require(server.BallThemeState)
	local F=require(server.FaceplateState)
	local Shared=game:GetService("ReplicatedStorage").Shared
	local Levels=require(Shared.Levels)
	local Stats=require(Shared.StatCatalog)
	local Wear=require(Shared.WearableCatalog)
	local Variants=require(Shared.WearableVariants)
	local Balls=require(Shared.BallThemes)
	local Plates=require(Shared.DeckThemes)
	local Shelf=require(Shared.WeeklyShelf)
	local Eggs=require(Shared.EggCatalog)
	local cases={}
	local function test(name,run)run();table.insert(cases,name)end
	local function copy(v)if type(v)~="table"then return v end;local r={};for k,x in pairs(v)do r[k]=copy(x)end;return r end
	local ALL={track=true,gates=true,medals=true,juice=true}
	local function gates(on)Levels.inject({flags={LevelsMatter=on==true},studio=true,shipped=ALL})end
	local function fixture(seed,start)
		local db,c={},{now=start or 1700000000,serial=0,writes=0}
		local adapter={
			now=function()return c.now end,guid=function()c.serial+=1;return "op"..c.serial end,
			random=function()return .1 end,wait=function()end,
			update=function(key,transform)
				c.writes+=1
				if c.failBefore then c.failBefore=false;error("fixture before commit")end
				local value=transform(copy(db[key]))
				if c.replay then value=transform(copy(db[key]))end
				if value then db[key]=copy(value)end
				if c.failAfter then c.failAfter=false;error("fixture after commit")end
				return copy(value)
			end,
		}
		if seed then db.player_1=seed end
		return H.load(1,{rank=1},adapter),db,c,adapter
	end
	local both=bit32.bor(Eggs.bit("pip"),Eggs.bit("blip"))
	-- A ready save with both pets and Stars; levels = {petId={stat=level}}.
	local function ready(levels,nectar)
		local _,db,c=fixture()
		local seed=copy(db.player_1)
		seed.hatching.inventoryMask,seed.hatching.nectar,seed.hatching.statsSeed=both,nectar or 1000,1
		local xp={};for pet,row in pairs(levels or {})do xp[pet]={};for stat,level in pairs(row)do xp[pet][stat]=Stats.xpFor(level)end end
		seed.hatching.petStats=xp
		seed.hatching.lease={token="",expiresAt=0}
		local h,db2,c2=fixture(seed,c.now+200)
		assert(h.status=="Ready","load "..tostring(h.status))
		return h,db2,c2
	end
	local function total(n)local row={};for _,stat in ipairs(Stats.Order)do row[stat]=n end;return row end
	local function gatedRows()local out={};for _,row in ipairs(Variants.Rows)do if row.gate then table.insert(out,row)end end;return out end
	local function price(id)return Wear.forPet("pip",math.huge).byId[id].price end
	local ok,problem=pcall(function()
		test("off: every gated id is NotForSale on both pets, with no write and no charge, whatever the level",function()
			gates(false)
			local h,_,c=ready({pip=total(99),blip=total(99)})
			local writes=c.writes
			for _,row in ipairs(gatedRows())do
				for _,pet in ipairs({"pip","blip"})do
					local bought,why=H.buyWearable(h,"off-"..row.id..pet,pet,row.id,price(row.id),true)
					assert(not bought and why=="NotForSale",row.id.." "..tostring(why))
					local row2,reason=W.equipResult(h.state,pet,Wear.forPet(pet,math.huge).byId[row.id].slot,row.id)
					assert(row2==nil and reason=="InvalidWearable","as an unknown id: "..tostring(reason))
				end
			end
			for _,id in ipairs(Balls.Gated)do
				local bought,why=H.buyBallTheme(h,"off-"..id,id,Balls.ById[id].price,true);assert(not bought and why=="NotForSale",tostring(why))
				local used,reason=H.equipBallTheme(h,"offuse-"..id,id);assert(not used and reason=="InvalidBallTheme",tostring(reason))
			end
			assert(h.state.nectar==1000 and c.writes==writes)
		end)
		test("on: one level below is NeedsLevel with no charge; at the gate it is sold at the base price and worn",function()
			gates(true)
			for _,row in ipairs(gatedRows())do
				local slot=Wear.forPet("pip",math.huge).byId[row.id].slot
				local below=if row.gate.total then total(math.floor(row.gate.total/6)-1)else {[row.gate.stat]=row.gate.level-1}
				local h,_,c=ready({pip=below})
				local writes=c.writes
				local bought,why=H.buyWearable(h,"low-"..row.id,"pip",row.id,price(row.id),true)
				assert(not bought and why=="NeedsLevel"and h.state.nectar==1000 and c.writes==writes and not h.pending,row.id.." "..tostring(why))
				local at=if row.gate.total then total(row.gate.total/6)else {[row.gate.stat]=row.gate.level}
				h=ready({pip=at})
				local cost=W.price("pip",row.id,Shelf.week(1700000200))
				assert(cost==price(row.id),"never on the shelf")
				bought,why=H.buyWearable(h,"ok-"..row.id,"pip",row.id,cost,true)
				assert(bought and why=="Saved"and h.state.nectar==1000-cost and W.owns(h.state,"pip",row.id),row.id.." "..tostring(why))
				assert(W.equipped(h.state,"pip")[Wear.slotKeys("pip",slot)[1]]==row.id and H.valid(h.state))
			end
			local h=ready({pip={power=9}})
			local bought,why=H.buyBallTheme(h,"b1","tangerine_pop",40,true);assert(not bought and why=="NeedsLevel"and h.state.nectar==1000)
			h=ready({pip={power=10}})
			bought,why=H.buyBallTheme(h,"b2","tangerine_pop",40,true);assert(bought and why=="Saved"and h.state.nectar==960 and B.equipped(h.state)=="tangerine_pop")
		end)
		test("any owned pet's level opens it for every pet; an unowned pet's XP does not; totals never add up across pets",function()
			gates(true)
			local h=ready({blip={jump=15}})
			assert(H.buyWearable(h,"any","pip","partyhat_lime",40,true),"the Bunny's Jump sells the Bear's hat")
			assert(H.buyWearable(h,"any2","blip","partyhat_lime",40,true))
			local _,db,c=fixture()
			local seed=copy(db.player_1);seed.hatching.inventoryMask=Eggs.bit("pip");seed.hatching.nectar=500;seed.hatching.statsSeed=1
			seed.hatching.petStats={blip={jump=Stats.MaxXP}};seed.hatching.lease={token="",expiresAt=0}
			local lone=fixture(seed,c.now+200)
			local bought,why=H.buyWearable(lone,"no","pip","partyhat_lime",40,true);assert(not bought and why=="NeedsLevel",tostring(why))
			h=ready({pip=total(20),blip=total(20)})
			bought,why=H.buyWearable(h,"sum","pip","hoodie_starbloom",250,true);assert(not bought and why=="NeedsLevel","120 + 120 is not 150")
		end)
		test("the order of refusals: price, owned, limit, level, Stars",function()
			gates(true)
			local h=ready({pip={jump=1}},5)
			local function why(...)local okay,reason=W.check(h.state,...);return okay,reason end
			assert(select(2,why("pip","partyhat_lime",41))=="PriceChanged")
			assert(select(2,why("pip","partyhat_lime",40))=="NeedsLevel","level before Stars")
			local full={};for i=1,W.Limit do full[i]="x"..i end
			local state=copy(h.state);state.petWearables={pip={owned=full,equipped={}}}
			assert(select(2,W.check(state,"pip","partyhat_lime",40))=="OwnedLimit")
			state.petWearables={pip={owned={"partyhat_lime"},equipped={}}};assert(select(2,W.check(state,"pip","partyhat_lime",40))=="AlreadyOwned")
			h=ready({pip={jump=15}},5);assert(select(2,W.check(h.state,"pip","partyhat_lime",40))=="NeedStars")
			assert(select(2,B.check(ready({pip={power=1}},5).state,"tangerine_pop",40))=="NeedsLevel"and select(2,B.check(ready({pip={power=10}},5).state,"tangerine_pop",40))=="NeedStars")
			assert(select(2,B.check(h.state,"tangerine_pop",39))=="PriceChanged")
		end)
		test("the level is read from the save being written, not from the session's copy",function()
			gates(true)
			local h,db=ready({pip={jump=15}})
			db.player_1.hatching.petStats={pip={jump=Stats.xpFor(14)}}
			local bought,why=H.buyWearable(h,"stale","pip","partyhat_lime",40,true)
			assert(not bought and why=="NeedsLevel"and db.player_1.hatching.nectar==1000 and db.player_1.hatching.petWearables.pip==nil,tostring(why))
			assert(h.pending==nil,"a refusal leaves nothing pending")
			-- malformed stored XP reads as no level
			h,db=ready({pip={jump=15}})
			local state=copy(h.state);state.petStats={pip={jump="999999"}}
			assert(select(2,W.check(state,"pip","partyhat_lime",40))=="NeedsLevel")
			state.petStats=nil;assert(select(2,W.check(state,"pip","partyhat_lime",40))=="NeedsLevel")
		end)
		test("exactly once: a lost reply, a retry, a replayed callback, a repeated press and a reused id",function()
			gates(true)
			local h,db,c=ready({pip={jump=15}})
			c.failAfter=true
			local bought,why=H.buyWearable(h,"amb","pip","partyhat_lime",40,true);assert(not bought and why=="Retrying",tostring(why))
			bought,why=H.retry(h);assert(bought and why=="Saved"and h.state.nectar==960 and db.player_1.hatching.nectar==960)
			bought,why=H.buyWearable(h,"amb","pip","partyhat_lime",40,true);assert(bought and why=="AlreadyOwned"and h.state.nectar==960)
			bought,why=H.buyWearable(h,"amb","pip","beanie_lime",40,true);assert(not bought and h.state.nectar==960,tostring(why))
			-- before the commit: nothing saved, then one purchase
			h,db,c=ready({pip={jump=15}})
			c.failBefore=true
			bought,why=H.buyWearable(h,"pre","pip","partyhat_lime",40,true);assert(not bought and why=="Retrying"and db.player_1.hatching.nectar==1000)
			c.replay=true
			bought,why=H.buyWearable(h,"pre","pip","partyhat_lime",40,true);assert(bought and why=="Saved"and db.player_1.hatching.nectar==960,tostring(why))
			local n=0;for _,id in ipairs(db.player_1.hatching.petWearables.pip.owned)do if id=="partyhat_lime"then n+=1 end end;assert(n==1)
			-- two sessions: the second takes the save; the first is refused and charges nothing
			h,db,c=ready({pip={power=10}})
			c.now+=200
			local other=H.load(1,{rank=1},h.adapter);assert(other.status=="Ready")
			bought,why=H.buyBallTheme(h,"two","tangerine_pop",40,true);assert(not bought and why=="SessionLost",tostring(why))
			bought,why=H.buyBallTheme(other,"two","tangerine_pop",40,true);assert(bought and db.player_1.hatching.nectar==960)
		end)
		test("gates off again: an owned gated item stays worn, comes off, goes back on, renders, and is never sold",function()
			gates(true)
			local h,db,c=ready({pip={jump=15,power=10}})
			assert(H.buyWearable(h,"w","pip","partyhat_lime",40,true)and H.buyBallTheme(h,"b","tangerine_pop",40,true))
			gates(false)
			local seed=copy(db.player_1);seed.hatching.lease={token="",expiresAt=0}
			local h2=fixture(seed,c.now+400)
			assert(h2.status=="Ready"and W.equipped(h2.state,"pip").Hat=="partyhat_lime"and B.equipped(h2.state)=="tangerine_pop")
			assert(Wear.renderMap("pip",W.equipped(h2.state,"pip")).mapped.Hat=="partyhat")
			assert(H.equipWearable(h2,"e1","pip","Hat",false)and W.equipped(h2.state,"pip").Hat==nil)
			assert(H.equipWearable(h2,"e2","pip","Hat","partyhat_lime")and W.equipped(h2.state,"pip").Hat=="partyhat_lime")
			local okay,why=H.equipWearable(h2,"e3","pip","Shirt","partyhat_lime");assert(not okay and why=="InvalidWearable")
			assert(H.equipBallTheme(h2,"u1","smileys")and H.equipBallTheme(h2,"u2","tangerine_pop")and B.equipped(h2.state)=="tangerine_pop")
			okay,why=H.buyWearable(h2,"again","blip","partyhat_lime",40,true);assert(not okay and why=="NotForSale")
			local tab=Wear.shopTab("pip","Hat",W.row(h2.state,"pip").owned)
			local listed=false;for _,item in ipairs(tab)do if item.id=="partyhat_lime"then listed=true end;assert(item.gate==nil or item.id=="partyhat_lime")end
			assert(listed and table.find(Balls.listed(h2.state.ballThemes.owned),"tangerine_pop")and not table.find(Balls.listed({}),"tangerine_pop"))
			assert(H.valid(h2.state))
		end)
		test("the two gated plates: Energy 10 and 30, sold below off and at the gate, kept and worn off",function()
			for id,want in pairs({sky_fizz={10,40},storm_glass={30,100}})do
				local level,cost=want[1],want[2]
				gates(false);local h=ready({pip={energy=99}})
				local bought,why=H.buyFaceplate(h,"off-"..id,id,cost);assert(not bought and why=="NotForSale"and h.state.nectar==1000,id)
				gates(true);h=ready({pip={energy=level-1}})
				bought,why=H.buyFaceplate(h,"low-"..id,id,cost);assert(not bought and why=="NeedsLevel"and h.state.nectar==1000,id)
				h=ready({pip={energy=level}})
				bought,why=H.buyFaceplate(h,"ok-"..id,id,cost);assert(bought and why=="Saved"and h.state.nectar==1000-cost and F.owns(h.state,id),id.." "..tostring(why))
				gates(false);assert(table.find(Plates.listed(h.state.faceplates),id)and not table.find(Plates.listed({}),id)and H.valid(h.state))
				assert(require(Shared.AppearanceCatalog).canEquip("theme",id,require(Shared.AppearanceCatalog).facts({trials=0},h.state)),id.." stays wearable")
			end
		end)
		test("faceplates: the same gate (every shipped gated plate has its texture and palette)",function()
			for _,id in ipairs(Plates.Gated)do local plate=Plates.ById[id];assert(plate.gate and plate.texture and plate.toy and not table.find(Plates.Order,id),id)end
			-- a fixture row, as a shipped gated plate will look to the server
			Plates.ById._spec_gated={name="Spec",priceStars=40,gate={stat="energy",level=10}}
			local fine,wrong=pcall(function()
				gates(false)
				local state={faceplates={},nectar=100,inventoryMask=both,petStats={pip={energy=Stats.xpFor(99)}}}
				assert(select(2,F.check(state,"_spec_gated",40))=="NotForSale")
				gates(true)
				assert(F.check(state,"_spec_gated",40))
				state.petStats.pip.energy=Stats.xpFor(9);assert(select(2,F.check(state,"_spec_gated",40))=="NeedsLevel")
				local before=state.nectar;assert(not F.apply(state,{plateId="_spec_gated",price=40})and state.nectar==before and #state.faceplates==0)
				state.petStats.pip.energy=Stats.xpFor(10);assert(F.apply(state,{plateId="_spec_gated",price=40})and state.nectar==60)
				Plates.ById._spec_gated.gate={stat="energy"};state.faceplates={}
				assert(select(2,F.check(state,"_spec_gated",40))=="NeedsLevel","a malformed gate never opens")
			end)
			Plates.ById._spec_gated=nil
			assert(fine,wrong)
		end)
		test("ungated items never need a level, on or off",function()
			for _,on in ipairs({true,false})do
				gates(on)
				local h=ready({},10000)
				for _,item in ipairs(Wear.forPet("pip").order)do
					if item.gate==nil then
						local okay,why=W.check(h.state,"pip",item.id,item.price);assert(okay,item.id.." "..tostring(why))
					end
				end
				for _,id in ipairs(Balls.Order)do if Balls.price(id)then assert(B.check(h.state,id,Balls.price(id)),id)end end
				for _,id in ipairs(Plates.Order)do if Plates.price(id)then assert(F.check(h.state,id,Plates.price(id)),id)end end
			end
		end)
		test("every gated recolour recolours something on both rigs and shares its base's slot",function()
			local Defs=require(Shared.PetRigDefinitions)
			for _,pet in ipairs({"pip","blip"})do
				for _,row in ipairs(gatedRows())do
					local item=Wear.forPet(pet,math.huge).byId[row.id]
					local tint=Wear.renderMap(pet,{[item.keys[1]]=row.id}).tints[item.keys[1]]
					local n=0;for _,a in ipairs(Defs[pet].attachments)do if Wear.tintFor(tint,a)then n+=1;assert(Wear.tintFor(tint,a)==row.color)end end
					assert(n>=1,pet.." "..row.id)
				end
			end
		end)
	end)
	Levels.inject(nil)
	assert(ok,problem)
	return{passed=#cases,cases=cases}
end
