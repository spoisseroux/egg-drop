-- The closet (lane C of the daily rack; ROTATION-BRIEF 1 "Wardrobe with the switch on" and 2, ARCH-REVIEW-ROTATION 13;
-- Spencer: "move clothes to eggs ... add a colour selector"). The pure rules in WearableCatalog (what the closet still
-- sells: level-gated rows and the This week pick; one card per base; a card's face; the owned colours of its swatch
-- row), the equip path's lookup of Outfit Egg rows (review 13: equipResult reads every row ever, so a swatch tap on an
-- egg colour wears it), and the server's refusal: with the rack switch on a direct buy of anything else answers
-- FromOutfitEgg with no charge and no write, an older pending purchase (no `closet` in its candidate) still completes,
-- an item already owned stays owned, worn and unchargeable; switch off, the Wardrobe sells exactly as before.
-- Offline: scripts/run_dash_server_specs.py. Studio: require(ServerScriptService.Server.ZZSpecs.WardrobeCloset)(Server).
return function(server)
	local H=require(server.HatchProgress)
	local W=require(server.WearableState)
	local Shared=game:GetService("ReplicatedStorage").Shared
	local Rack=require(Shared.DailyRack)
	local Wear=require(Shared.WearableCatalog)
	local Variants=require(Shared.WearableVariants)
	local ThisWeek=require(Shared.ThisWeek)
	local cases={}
	local function test(name,run)run();table.insert(cases,name)end
	local function copy(v)if type(v)~="table"then return v end;local r={};for k,x in pairs(v)do r[k]=copy(x)end;return r end
	local function on()assert(Rack.inject({flags={DailyRack=true},studio=true}),"inject needs Studio (or the offline mocks)")end
	local function off()Rack.inject({flags={DailyRack=true},studio=true,rack=false})end
	local PET="pip"
	local fixtures=0
	local function fresh()
		fixtures+=1
		local db,c={},{now=1795410000+3600,serial=0,writes=0}
		local adapter={now=function()return c.now end,guid=function()c.serial+=1;return "wc"..fixtures.."g"..c.serial end,random=function()return .5 end,
			wait=function()end,update=function(key,transform)c.writes+=1;local value=transform(copy(db[key]));if value then db[key]=copy(value)end;return copy(value)end}
		local h=H.load(1,{},adapter);assert(h.status=="Ready","fixture "..tostring(h.status))
		assert(H.grantStarter(h,false,false))
		assert(H.command(h,"ack",h.state.lastHatch.id,h.state.revision))
		-- Stars for the shop, in the saved record (the write reads the store, never the handle)
		H.release(h);c.now+=200
		db.player_1.hatching.lease.expiresAt=0;db.player_1.hatching.nectar=1000
		h=H.load(1,{},adapter);assert(h.status=="Ready","fixture rejoin "..tostring(h.status))
		h.restricted=false
		return h,db,c
	end
	local function ids(list)local out={};for _,item in ipairs(list)do table.insert(out,item.id)end;return out end

	local ok,problem=pcall(function()
	test("what the closet still sells: a level-gated row and the This week pick; never a base, a shipped recolour or an egg row",function()
		local all=Wear.forPet(PET,math.huge).byId
		assert(all.beanie and not Wear.closetSells(all.beanie),"a base item comes from the egg")
		assert(all.beanie_mint and not Wear.closetSells(all.beanie_mint),"an ungated shipped recolour comes from the egg")
		assert(all.beanie_sky and all.beanie_sky.egg and not Wear.closetSells(all.beanie_sky),"an Outfit Egg row is never sold")
		assert(all.beanie_rose and all.beanie_rose.gate and Wear.closetSells(all.beanie_rose),"an earned goal stays for sale")
		local weekly=nil;for _,row in ipairs(Variants.Rows)do if row.weekly and all[row.id]then weekly=all[row.id];break end end
		assert(weekly and Wear.closetSells(weekly),"the This week pick stays")
		assert(not Wear.closetSells(nil)and not Wear.closetSells("beanie"))
	end)

	test("one card per base: no recolour cards, unowned gated rows listed now keep theirs, owning one makes it a colour",function()
		for _,tab in ipairs(Wear.Tabs)do
			local cards=Wear.closetTab(PET,tab.slot,{})
			local listed=Wear.forPet(PET).byId
			local bases,seen=0,{}
			for _,item in ipairs(cards)do
				assert(item.slot==tab.slot and not seen[item.id],"one card each, in its own tab");seen[item.id]=true
				if item.variant then assert(item.gate~=nil and listed[item.id],"only a gated row listed now: "..item.id)else bases+=1 end
				assert(not item.egg and not item.weekly,"no egg or weekly card: "..item.id)
			end
			local want=0;for _,item in ipairs(Wear.forPet(PET,math.huge).order)do if item.slot==tab.slot and not item.variant then want+=1 end end
			assert(bases==want,"every base has its card in "..tab.slot)
		end
		-- An owned gated row leaves the card list (it is a swatch of its base now).
		local hat=ids(Wear.closetTab(PET,"Hat",{}))
		local rose=table.find(hat,"beanie_rose")
		if rose then assert(not table.find(ids(Wear.closetTab(PET,"Hat",{"beanie_rose"})),"beanie_rose"))end
		assert(table.find(hat,"beanie")and not table.find(hat,"beanie_mint")and not table.find(hat,"beanie_sky"))
	end)

	test("the swatch row: the owned colours of the base, in family order, two or more; never an unowned colour",function()
		local fam=ids(Wear.family(PET,"beanie"))
		assert(fam[1]=="beanie"and table.find(fam,"beanie_sky")and table.find(fam,"beanie_rainbow")and table.find(fam,"beanie_mint"))
		for _,id in ipairs(fam)do local item=Wear.forPet(PET,math.huge).byId[id];assert(id=="beanie"or item.base=="beanie")end
		assert(Wear.swatchRow(PET,"beanie",{"beanie"})==nil,"one colour: no row")
		assert(Wear.swatchRow(PET,"beanie",{})==nil)
		local row=Wear.swatchRow(PET,"beanie_sky",{"tee","beanie_sky","beanie_rainbow","beanie"})
		assert(row and #row==3,"only the beanie colours owned")
		local got=ids(row)
		assert(got[1]=="beanie","family order: the base first")
		assert(table.find(fam,got[2])<table.find(fam,got[3]))
		assert(not table.find(got,"beanie_mint"),"an unowned colour is never drawn")
		assert(#Wear.swatches(PET,"nope",{"beanie"})==0)
	end)

	test("a card's face: the colour worn, else the base when owned, else the first owned colour, else the base",function()
		local owned={"beanie_sky","beanie_gold"}
		assert(Wear.closetFace(PET,"beanie",owned,{Hat="beanie_gold"})=="beanie_gold","worn")
		assert(Wear.closetFace(PET,"beanie",owned,{Hat="sunhat"})==ids(Wear.swatches(PET,"beanie",owned))[1],"first owned")
		assert(Wear.closetFace(PET,"beanie",{"beanie","beanie_sky"},{})=="beanie","the base when owned")
		assert(Wear.closetFace(PET,"beanie",{},{})=="beanie","unowned: the base (From the Outfit Egg)")
	end)

	test("review 13: an owned Outfit Egg colour equips through equipResult (every row ever); an unowned one does not",function()
		local h=fresh()
		assert(W.grant(h.state,PET,"beanie_sky",false))
		assert(W.grant(h.state,PET,"beanie_rainbow",false))
		assert(Wear.forPet(PET,math.huge).byId.beanie_sky and not Wear.forPet(PET).byId.beanie_sky,"listed only under math.huge")
		local row=W.equipResult(h.state,PET,"Hat","beanie_sky");assert(row and row.equipped.Hat=="beanie_sky")
		row=W.equipResult(h.state,PET,"Hat","beanie_rainbow");assert(row and row.equipped.Hat=="beanie_rainbow","a sparkle pick too")
		local none,why=W.equipResult(h.state,PET,"Hat","beanie_gold");assert(none==nil and why~=nil,"unowned: refused")
		assert(W.equipResult(h.state,PET,"Shirt","beanie_sky")==nil,"its own slot only")
		-- the real request path: an Outfit Egg pick (saved), then the swatch's equip call wears it
		on()
		local live=fresh()
		local rack=H.public(live).rack
		local okR,whyR,record=H.rackEgg(live,"outfit",{requestId="wc-egg",petId=PET,day=rack.day,price=rack.price,mode=rack.mode,
			poolKey=rack.pets[PET].poolKey,equip=false})
		assert(okR and whyR=="Saved",tostring(whyR))
		local item=Wear.forPet(PET,math.huge).byId[record.item]
		assert(item and W.owns(live.state,PET,item.id))
		local okE,whyE=H.equipWearable(live,"wc-eq1",PET,item.slot,item.id)
		assert(okE,tostring(whyE));assert(Wear.equippedIn(PET,W.equipped(live.state,PET),item.slot)==item.id)
		Rack.inject(nil)
	end)

	test("switch on: a direct buy of a base or a shipped recolour is FromOutfitEgg, no charge, no write",function()
		on()
		local h=fresh()
		local before,revision=h.state.nectar,h.state.revision
		for _,id in ipairs({"beanie","beanie_mint","tee"})do
			local okB,why=H.buyWearable(h,"wc-buy-"..id,PET,id,W.price(PET,id),true)
			assert(not okB and why==W.ClosetReason and why=="FromOutfitEgg",id..": "..tostring(why))
			assert(not W.owns(h.state,PET,id))
		end
		assert(h.state.nectar==before and h.state.revision==revision,"no charge")
		-- the same refusal from the pure check, and an egg row stays NotForSale
		local okC,whyC=W.check(h.state,PET,"beanie",nil,nil,nil,nil,true);assert(not okC and whyC=="FromOutfitEgg")
		local okE,whyE=W.check(h.state,PET,"beanie_sky",nil,nil,nil,nil,true);assert(not okE and whyE=="NotForSale")
		Rack.inject(nil)
	end)

	test("switch on: a level-gated row and the This week pick still sell (never FromOutfitEgg)",function()
		local h=fresh()
		local _,why=W.check(h.state,PET,"beanie_rose",nil,nil,true,nil,true)
		assert(why~="FromOutfitEgg","a gated row is an earned goal: "..tostring(why))
		assert(ThisWeek.inject({on=true,studio=true,flags={ThisWeek=true}}))
		local week,pick=nil,nil
		local base=ThisWeek.week(1795410000+3600)
		for w=base,base+ThisWeek.Every*2 do
			local row=ThisWeek.featured(w)
			if row and Wear.forPet(PET,w).byId[row.id]then week,pick=w,row;break end
		end
		assert(pick,"a week whose pick the pet's rig sells")
		local okW,whyW=W.check(h.state,PET,pick.id,nil,nil,nil,week,true)
		assert(okW,"the This week pick sells in the closet: "..tostring(whyW))
		ThisWeek.inject(nil)
	end)

	test("an older pending purchase (no closet in its candidate) completes; closet=true refuses the same candidate",function()
		local h=fresh()
		local price=W.price(PET,"sunhat")
		local candidate={petId=PET,itemId="sunhat",price=price,operationId="old-op",equip=false}
		local state=copy(h.state)
		assert(W.applyBuy(state,candidate),"nil = off: the purchase asked before the switch finishes")
		assert(W.owns(state,PET,"sunhat")and state.nectar==h.state.nectar-price)
		local state2=copy(h.state);candidate.closet=true
		local okB,why=W.applyBuy(state2,candidate);assert(not okB and why=="FromOutfitEgg"and state2.nectar==h.state.nectar)
	end)

	test("switch off: the Wardrobe sells as before; switch on later: what was bought stays owned, worn and never charged again",function()
		off()
		local h=fresh()
		local before=h.state.nectar
		local okB,why=H.buyWearable(h,"wc-off-1",PET,"beanie",W.price(PET,"beanie"),true)
		assert(okB and why~="FromOutfitEgg",tostring(why));assert(W.owns(h.state,PET,"beanie")and h.state.nectar==before-W.price(PET,"beanie"))
		on()
		local paid=h.state.nectar
		local okA,whyA=H.buyWearable(h,"wc-on-1",PET,"beanie",W.price(PET,"beanie"),true)
		assert(okA and whyA=="AlreadyOwned"and h.state.nectar==paid,"owned stays owned, no second charge: "..tostring(whyA))
		assert(H.equipWearable(h,"wc-on-off",PET,"Hat",false))
		assert(H.equipWearable(h,"wc-on-wear",PET,"Hat","beanie"));assert(W.equipped(h.state,PET).Hat=="beanie","still wearable")
		-- the rack never offers it again: owned items leave the pool
		local rack=H.public(h).rack
		if rack and rack.pets[PET]then
			for _,item in ipairs(rack.pets[PET].items)do if item.id=="beanie"then assert(item.owned and item.units==0)end end
		end
		Rack.inject(nil)
	end)
	end)
	Rack.inject(nil);ThisWeek.inject(nil)
	if not ok then error(problem,0)end
	return {passed=#cases,cases=cases}
end
