-- The daily rack across versions (DailyRack, RackState; ROTATION-BRIEF 5 "Older builds and live"). Offline only
-- (scripts/run_dash_server_specs.py), where `offline` holds the new tree, the base commit and the live build. A save with
-- the Outfit gift (gifts.outfit, the Pom Beanie worn), paid Outfit Eggs (the optional `rack` field, Outfit Egg ids in
-- petWearables.owned, one equipped) and a Paint gift loads on the live build and on the base commit with its Stars and
-- wardrobe intact; they save over it and keep `rack` and `gifts` as they were and the egg ids owned and worn; this build
-- loads it back, replays the saved request without a charge and never gives the Outfit gift again. A closet at 128 on an
-- older build stays loadable, and this build never writes a 129th item. Slice 2: rack.toy, Deck Egg plates and ball themes
-- (existing ids in the existing lists) and Angel Wings owned and worn (Back) load on both and survive their writes.
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
		local adapter={now=function()return c.now end,guid=function()c.serial+=1;return "rx"..c.serial end,random=function()return .37 end,wait=function()end,
			update=function(key,transform)local value=transform(copy(db[key]));if value then db[key]=copy(value)end;return copy(value)end}
		local h=H.load(1,{},adapter);h.restricted=false
		return h,H
	end
	local function later(db,c)c.now+=200;db.player_1.hatching.lease.expiresAt=0 end
	local Rack=new.require(new.shared.DailyRack)
	assert(Rack.inject({flags={DailyRack=true},studio=true}),"inject needs the offline mocks")

	local ok,problem=pcall(function()
	for _,pair in ipairs({{"live",live},{"base",base}})do
		local label,old=pair[1],pair[2]
		test("a save with the Outfit gift and paid Outfit Eggs loads on the "..label.." build, which saves over it and keeps it all",function()
			local db,c={},{now=1795410000+3600,serial=0}
			local h,H=open(new,db,c)
			assert(H.grantStarter(h,false,true)and H.command(h,"ack",h.state.lastHatch.id,h.state.revision))
			H.release(h);later(db,c)
			db.player_1.hatching.nest={at=c.now,n=0,tucked=true,pet="pip"};db.player_1.hatching.nectar=500
			h,H=open(new,db,c)
			assert(H.giftEgg(h,"outfit",{nest=true}))
			local bought={}
			for i=1,3 do
				local rack=H.public(h).rack
				local okB,why,r=H.rackEgg(h,"outfit",{requestId="cv-"..i,petId="pip",day=rack.day,price=rack.price,mode=rack.mode,poolKey=rack.pets.pip.poolKey,equip=i==3})
				assert(okB and why=="Saved",tostring(why));table.insert(bought,r.item)
			end
			H.release(h);later(db,c)
			local saved=copy(db.player_1.hatching)
			assert(saved.rack and saved.gifts.outfit and #saved.petWearables.pip.owned==4)
			local o,OH=open(old,db,c)
			assert(o.status=="Ready",label.." loads it: "..tostring(o.status))
			assert(o.state.nectar==saved.nectar,label.." keeps the Stars")
			assert(same(o.state.petWearables,saved.petWearables),label.." keeps the egg ids owned and worn")
			assert(OH.grantPurchase(o,"fund-old",3,false),label.." saves over it")
			assert(same(db.player_1.hatching.rack,saved.rack),label.." keeps the rack field")
			assert(same(db.player_1.hatching.gifts,saved.gifts),label.." keeps the gifts field")
			assert(same(db.player_1.hatching.petWearables,saved.petWearables))
			-- an old build's own wardrobe equip works around the unknown ids
			local okE=OH.equipWearable(o,"old-eq","pip","Hat",false)
			assert(okE~=nil)
			OH.release(o);later(db,c)
			local back,BH=open(new,db,c)
			assert(back.status=="Ready"and back.state.nectar==saved.nectar+3)
			local stars=back.state.nectar
			local rack=BH.public(back).rack
			local again,whyAgain,r=BH.rackEgg(back,"outfit",{requestId="cv-3",petId="pip",day=rack.day,price=rack.price,mode=rack.mode,poolKey=rack.pets.pip.poolKey})
			assert(again and whyAgain=="AlreadySaved"and r.item==bought[3]and back.state.nectar==stars,"a replay after the round trip")
			local okG,whyG=BH.giftEgg(back,"outfit",{nest=true});assert(okG and whyG=="AlreadyGranted")
			for _,id in ipairs(bought)do assert(table.find(back.state.petWearables.pip.owned,id))end
		end)
		test("a closet at 128 with Outfit Egg ids loads on the "..label.." build; this build never writes a 129th",function()
			local db,c={},{now=1795410000+3600,serial=0}
			local h,H=open(new,db,c)
			assert(H.grantStarter(h,false,true)and H.command(h,"ack",h.state.lastHatch.id,h.state.revision))
			H.release(h);later(db,c)
			local owned={};for i=1,120 do owned[i]="later_item_"..i end
			for _,id in ipairs({"beanie_sky","tee_snow","hoodie_aurora","specs_rosegold","bellcollar_snow","ring_midnight","blush_grape","acorn_gold"})do table.insert(owned,id)end
			db.player_1.hatching.petWearables={pip={owned=owned,equipped={Hat="beanie_sky"}}};db.player_1.hatching.nectar=500
			local o=open(old,db,c);assert(o.status=="Ready",label.." loads 128: "..tostring(o.status))
			later(db,c)
			h,H=open(new,db,c);assert(h.status=="Ready")
			local rack=H.public(h).rack
			local okB,why=H.rackEgg(h,"outfit",{requestId="cv-full",petId="pip",day=rack.day,price=rack.price,mode=rack.mode,poolKey=rack.pets.pip.poolKey})
			assert(not okB and why=="ClosetFull"and #db.player_1.hatching.petWearables.pip.owned==128 and db.player_1.hatching.nectar==500)
		end)
		test("slice 2: toy colours, Deck Egg plates and themes and Angel Wings worn load on the "..label.." build and survive it",function()
			local db,c={},{now=1795410000+3600,serial=0}
			local h,H=open(new,db,c)
			assert(H.grantStarter(h,false,true)and H.command(h,"ack",h.state.lastHatch.id,h.state.revision))
			H.release(h);later(db,c)
			local saved=db.player_1.hatching
			saved.nectar=2000
			saved.toyUnlocks={ball=true,bone=true,sparkler=true,wobble_top=true,squeaky_carrot=true,pocket_deck=true}
			saved.petWearables={pip={owned={"angelwings","beanie_sky"},equipped={Back="angelwings",Hat="beanie_sky"}}}
			h,H=open(new,db,c);assert(h.status=="Ready")
			local function buy(egg,i,equip)
				local rack=H.public(h).rack
				local view=if egg=="toycolour"then rack.toy else rack.deck
				local okB,why,r=H.rackEgg(h,egg,{requestId="s2cv-"..egg..i,petId="pip",day=rack.day,price=view.price,mode=view.mode,poolKey=view.poolKey,equip=equip})
				assert(okB and why=="Saved",egg..": "..tostring(why));return r.item
			end
			local skin=buy("toycolour",1,true)
			local deck1,deck2=buy("deck",1),buy("deck",2)
			H.release(h);later(db,c)
			saved=copy(db.player_1.hatching)
			assert(saved.rack.toy.owned[skin]and next(saved.rack.toy.worn))
			local o,OH=open(old,db,c)
			assert(o.status=="Ready",label.." loads it: "..tostring(o.status))
			assert(o.state.nectar==saved.nectar and same(o.state.faceplates,saved.faceplates)and same(o.state.ballThemes,saved.ballThemes))
			assert(same(o.state.petWearables,saved.petWearables),label.." keeps Angel Wings owned and worn")
			assert(OH.grantPurchase(o,"fund-s2",3,false),label.." saves over it")
			assert(same(db.player_1.hatching.rack,saved.rack),label.." keeps rack.toy")
			assert(same(db.player_1.hatching.faceplates,saved.faceplates)and same(db.player_1.hatching.ballThemes,saved.ballThemes))
			OH.release(o);later(db,c)
			local back,BH=open(new,db,c)
			assert(back.status=="Ready"and back.state.nectar==saved.nectar+3)
			local rack=BH.public(back).rack
			local again,whyAgain=BH.rackEgg(back,"deck",{requestId="s2cv-deck2",petId="pip",day=rack.day,price=rack.deck.price,mode=rack.deck.mode,poolKey=rack.deck.poolKey})
			assert(again and whyAgain=="AlreadySaved"and back.state.nectar==saved.nectar+3,"a replay after the round trip")
			for _,id in ipairs({deck1,deck2})do assert(table.find(back.state.faceplates or {},id)or table.find(back.state.ballThemes.owned,id))end
		end)
	end
	end)
	Rack.inject(nil)
	if not ok then error(problem,0)end
	return {passed=#cases,cases=cases}
end
