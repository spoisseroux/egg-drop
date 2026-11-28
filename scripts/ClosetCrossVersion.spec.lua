-- The closet across versions (lane C; ROTATION-BRIEF 1 "Wardrobe with the switch on", 5 "Older builds and live"): a save
-- whose pet bought clothes on the live build (and on the base commit) loads on this build with the rack switch on and
-- keeps every item owned and worn: they equip and come off, a second buy of one is AlreadyOwned with no charge, the
-- Outfit Egg's rack marks them owned (never offered again), and a direct buy of something new is FromOutfitEgg with no
-- charge. Colours the Outfit Egg gave on this build load back on the older builds, which keep them and save over them.
-- Offline only (scripts/run_dash_server_specs.py): `offline` holds the new tree, the base commit and the live build.
return function(_,offline)
	local new,base,live=offline.new,offline.base,offline.live
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
	local function open(tree,db,c)
		local H=tree.require(tree.server.HatchProgress)
		local adapter={now=function()return c.now end,guid=function()c.serial+=1;return "cc"..c.serial end,random=function()return .37 end,wait=function()end,
			update=function(key,transform)local value=transform(copy(db[key]));if value then db[key]=copy(value)end;return copy(value)end}
		local h=H.load(1,{},adapter);h.restricted=false
		return h,H
	end
	local function later(db,c)c.now+=200;db.player_1.hatching.lease.expiresAt=0 end
	local Rack=new.require(new.shared.DailyRack)
	local W=new.require(new.server.WearableState)
	local PET="pip"

	local ok,problem=pcall(function()
	for _,pair in ipairs({{"live",live},{"base",base}})do
		local label,old=pair[1],pair[2]
		test("clothes bought on the "..label.." build stay owned and worn in the closet; nothing is charged twice",function()
			local db,c={},{now=1795410000+3600,serial=0}
			local o,OH=open(old,db,c)
			assert(o.status=="Ready")
			assert(OH.grantStarter(o,false,false)and OH.command(o,"ack",o.state.lastHatch.id,o.state.revision))
			OH.release(o);later(db,c);db.player_1.hatching.nectar=1000
			o,OH=open(old,db,c);assert(o.status=="Ready")
			local OW=old.require(old.server.WearableState)
			for i,id in ipairs({"beanie","tee","beanie_mint"})do
				local okB,why=OH.buyWearable(o,"old-buy-"..i,PET,id,OW.price(PET,id),i~=3)
				assert(okB,label.." sells "..id..": "..tostring(why))
			end
			OH.release(o);later(db,c)
			local saved=copy(db.player_1.hatching)
			assert(Rack.inject({flags={DailyRack=true},studio=true}),"inject needs the offline mocks")
			local h,H=open(new,db,c)
			assert(h.status=="Ready","this build loads it: "..tostring(h.status))
			assert(same(h.state.petWearables,saved.petWearables),"owned and worn as saved")
			local stars=h.state.nectar
			for i,id in ipairs({"beanie","tee","beanie_mint"})do
				local okA,whyA=H.buyWearable(h,"again-"..label..i,PET,id,W.price(PET,id),false)
				assert(okA and whyA=="AlreadyOwned",id..": "..tostring(whyA))
			end
			assert(h.state.nectar==stars,"never charged twice")
			assert(H.equipWearable(h,"cc-mint",PET,"Hat","beanie_mint"));assert(W.equipped(h.state,PET).Hat=="beanie_mint")
			assert(H.equipWearable(h,"cc-off",PET,"Shirt",false));assert(W.equipped(h.state,PET).Shirt==nil)
			assert(H.equipWearable(h,"cc-tee",PET,"Shirt","tee"))
			local okN,whyN=H.buyWearable(h,"cc-new",PET,"sunhat",W.price(PET,"sunhat"),true)
			assert(not okN and whyN=="FromOutfitEgg"and h.state.nectar==stars,"something new comes from the egg: "..tostring(whyN))
			local rack=H.public(h).rack
			assert(rack and rack.pets[PET],"the rack is on")
			for _,item in ipairs(rack.pets[PET].items)do
				if item.id=="beanie"or item.id=="tee"or item.id=="beanie_mint"then assert(item.owned and item.units==0,"owned leaves the pool: "..item.id)end
			end
			-- an Outfit Egg pick hatched here, worn through the Wardrobe's equip, then back on the older build
			local okR,whyR,record=H.rackEgg(h,"outfit",{requestId="cc-egg-"..label,petId=PET,day=rack.day,price=rack.price,mode=rack.mode,
				poolKey=rack.pets[PET].poolKey,equip=false})
			assert(okR and whyR=="Saved",tostring(whyR))
			local got=W.row(h.state,PET).owned;got=got[#got]
			assert(record.item==got and W.owns(h.state,PET,got))
			local slot=new.require(new.shared.WearableCatalog).forPet(PET,math.huge).byId[got].slot
			assert(H.equipWearable(h,"cc-egg-wear",PET,slot,got))
			assert(new.require(new.shared.WearableCatalog).equippedIn(PET,W.equipped(h.state,PET),slot)==got,"the egg colour is worn")
			H.release(h);later(db,c)
			Rack.inject(nil)
			local back=copy(db.player_1.hatching)
			local o2,OH2=open(old,db,c)
			assert(o2.status=="Ready",label.." loads it back: "..tostring(o2.status))
			assert(same(o2.state.petWearables,back.petWearables),label.." keeps the closet as saved")
			assert(OH2.grantPurchase(o2,"cc-fund",3,false),label.." saves over it")
			assert(same(db.player_1.hatching.petWearables,back.petWearables),"and keeps it")
			OH2.release(o2)
		end)
	end
	end)
	Rack.inject(nil)
	if not ok then error(problem,0)end
	return {passed=#cases,cases=cases}
end
