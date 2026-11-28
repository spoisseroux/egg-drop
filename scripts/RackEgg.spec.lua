-- The Outfit Egg's save path and the Outfit gift (HatchProgress.rackEgg / rackPublic / giftEgg "outfit", RackState;
-- ROTATION-BRIEF 4 and 5, ARCH-REVIEW-ROTATION 1-3, 7, 10, 11): the switch off is the game before (no snapshot key,
-- NotReady, the gift chain Paint -> Toy -> Snack); on, a paid egg charges once per request id (a replay, a store error
-- before or after the write), each mismatch the player did not see answers with no charge (DayChanged, PriceChanged,
-- PolicyChanged, PoolChanged), the write refuses RackDone, ClosetFull, NeedStars, a broken field (never written over)
-- and an open reveal; restricted players get the fixed next pick. The chain under the rack: Outfit (the Pom Beanie, worn)
-- -> Paint -> Toy -> Snack, the Outfit gift checking the pet and the 128 cap, `seen` through giftSeen. The Paint Egg's
-- daily splash checks the day beside the quote, and no pity gives no guaranteed charm. Isolated adapters only.
-- Offline: scripts/run_dash_server_specs.py. Studio: require(ServerScriptService.Server.ZZSpecs.RackEgg)(Server).
return function(server)
	local H=require(server.HatchProgress)
	local RackState=require(server.RackState)
	local W=require(server.WearableState)
	local LS=require(server.LookState)
	local Shared=game:GetService("ReplicatedStorage").Shared
	local Rack=require(Shared.DailyRack)
	local Gifts=require(Shared.GiftEggs)
	local Hue=require(Shared.HueCatalog)
	local LE=require(Shared.LookEggCatalog)
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
	local function on(parts)
		local env={flags={DailyRack=true},studio=true}
		for k,v in pairs(parts or {})do env[k]=v end
		assert(Rack.inject(env),"inject needs Studio (or the offline mocks)")
	end
	local function off()Rack.inject({flags={DailyRack=true},studio=true,rack=false,lookdaily=false,looknopity=false})end
	local fixtures=0
	local function adapterFor(db,c)
		return {
			now=function()return c.now end,
			guid=function()c.serial+=1;return c.prefix..c.serial end,
			random=function()return c.unit or .5 end,
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
	end
	local function fresh(chain,keepReveal)
		fixtures+=1
		local db,c={},{now=1795410000+3600,serial=0,writes=0,prefix="rk"..fixtures.."op"}
		local h=H.load(1,{},adapterFor(db,c));assert(h.status=="Ready","fixture "..tostring(h.status))
		assert(H.grantStarter(h,false,chain~=false))
		if not keepReveal then assert(H.command(h,"ack",h.state.lastHatch.id,h.state.revision))end
		h.restricted=false
		return h,db,c
	end
	local function rejoin(h,db,c,changes,later)
		H.release(h)
		c.now+=later or 200
		local saved=db.player_1.hatching
		saved.lease.expiresAt=0
		for k,v in pairs(changes or {})do saved[k]=copy(v)end
		local again=H.load(1,{},adapterFor(db,c));assert(again.status=="Ready","rejoin "..tostring(again.status))
		again.restricted=h.restricted
		return again
	end
	local function rich(h,db,c,extra)
		local changes={nectar=1000}
		for k,v in pairs(extra or {})do changes[k]=v end
		return rejoin(h,db,c,changes)
	end
	-- The request the client builds from the snapshot.
	local serial=0
	local function ask(h,overrides,pet)
		local rack=H.public(h).rack
		local view=rack.pets[pet or "pip"]
		serial+=1
		local r={requestId="req-"..serial,petId=pet or "pip",day=rack.day,price=rack.price,mode=rack.mode,poolKey=view.poolKey}
		for k,v in pairs(overrides or {})do r[k]=v end
		return r,view
	end
	local function owned(h,pet)return W.row(h.state,pet or "pip").owned end

	local ok,problem=pcall(function()
	test("off: no snapshot key, the egg and the Outfit gift NotReady, the chain Paint first as before",function()
		off()
		local h,db,c=fresh()
		local p=H.public(h)
		assert(p.rack==nil and p.lookDay==nil and p.lookNoPity==nil,"the snapshot as before")
		local okR,whyR=H.rackEgg(h,"outfit",{requestId="x1",petId="pip",day=Rack.today(c.now),price=Rack.Price,mode="random",poolKey="0"})
		assert(not okR and whyR=="NotReady")
		h=rejoin(h,db,c,{nest={at=c.now,n=0,tucked=true,pet="pip"}})
		assert(select(2,H.giftEgg(h,"outfit",{nest=true}))=="NotReady")
		assert(H.giftReady(h,{nest=true})=="paint")
		local pub=H.giftsPublic(h,{nest=true})
		assert(pub.granted.outfit==nil and pub.outfit==nil and pub.ready=="paint")
		local okP,whyP,r=H.giftEgg(h,"paint",{nest=true})
		assert(okP and whyP=="Saved"and r.item and db.player_1.hatching.gifts.paint.rounds==nil,"no new record keys while off")
	end)

	test("on: the snapshot carries today's picks per owned pet with rarity, weights, units, owned, price and the pool key",function()
		on()
		local h,db,c=fresh()
		local rack=H.public(h).rack
		assert(rack and rack.day==Rack.today(c.now)and rack.price==25 and rack.mode=="random"and not rack.broken)
		local view=rack.pets.pip
		assert(rack.outfit==view and rack.pets.blip==nil,"only owned pets; outfit is the pet that is out")
		assert(#view.items==8 and view.sparkle and view.sparkle.rarity=="legendary"and view.total>0 and type(view.poolKey)=="string")
		for _,item in ipairs(view.items)do assert(item.rarity and item.weight and item.units and item.percent and item.owned==false)end
		h.restricted=true
		local fixed=H.public(h).rack
		assert(fixed.mode=="fixed"and fixed.outfit.next,"restricted: the fixed next pick")
	end)

	test("a paid egg: one item from today's picks, 25 Stars, saved with its op; the same request id twice charges once",function()
		on()
		local h,db,c=fresh();h=rich(h,db,c)
		local request,view=ask(h)
		local before,writes=h.state.nectar,c.writes
		local okB,why,record=H.rackEgg(h,"outfit",request)
		assert(okB and why=="Saved",tostring(why))
		assert(h.state.nectar==before-25 and db.player_1.hatching.nectar==before-25)
		assert(record.item and record.rarity and record.id==request.requestId and record.day==request.day and record.pet=="pip")
		assert(Rack.rarityOf("pip",request.day,record.item)==record.rarity)
		assert(table.find(owned(h),record.item)and table.find(db.player_1.hatching.petWearables.pip.owned,record.item))
		local found=false;for _,r in ipairs(view.items)do if r.id==record.item then found=true end end
		assert(found or view.sparkle.id==record.item,"from today's egg")
		assert(db.player_1.hatching.rack.v==1 and db.player_1.hatching.rack.ops[1]==request.requestId)
		local writesAfter=c.writes
		local again,whyAgain,r2=H.rackEgg(h,"outfit",request)
		assert(again and whyAgain=="AlreadySaved"and r2.item==record.item and c.writes==writesAfter and h.state.nectar==before-25,"a replay")
		local other=rejoin(h,db,c)
		local third,whyThird=H.rackEgg(other,"outfit",request)
		assert(third and whyThird=="AlreadySaved"and other.state.nectar==before-25,"a rejoin or a second server")
		assert(writes<writesAfter)
	end)

	test("a store error before the write and a lost reply after it: the frozen candidate gives one item once",function()
		on()
		local h,db,c=fresh();h=rich(h,db,c)
		local request=ask(h)
		local before=h.state.nectar
		c.failNext="before"
		local okA,whyA=H.rackEgg(h,"outfit",request);assert(not okA and whyA=="Retrying"and h.pending)
		assert(db.player_1.hatching.rack==nil,"nothing written")
		c.unit=.01 -- a fresh roll would differ: the resumed candidate keeps its own
		local okB,whyB,r=H.rackEgg(h,"outfit",request);assert(okB and whyB=="Saved"and h.state.nectar==before-25)
		local g,dbg,cg=fresh();g=rich(g,dbg,cg)
		local req2=ask(g);local b2=g.state.nectar
		cg.failNext="after"
		local okC,whyC=H.rackEgg(g,"outfit",req2);assert(not okC and whyC=="Retrying")
		assert(dbg.player_1.hatching.rack.ops[1]==req2.requestId,"it did commit")
		local okD,whyD=H.rackEgg(g,"outfit",req2)
		assert(okD and(whyD=="Saved"or whyD=="AlreadySaved")and g.state.nectar==b2-25 and dbg.player_1.hatching.nectar==b2-25,"proved, never charged twice: "..tostring(whyD))
		assert(#dbg.player_1.hatching.petWearables.pip.owned==#W.row(g.state,"pip").owned)
		assert(r.item)
	end)

	test("what the player did not see answers with no charge: DayChanged, PriceChanged, PolicyChanged, PoolChanged",function()
		on()
		local h,db,c=fresh();h=rich(h,db,c)
		local stars,writes=h.state.nectar,c.writes
		for field,case in pairs({day={Rack.today(c.now)-1,"DayChanged"},price={24,"PriceChanged"},mode={"fixed","PolicyChanged"},poolKey={"deadbeef","PoolChanged"}})do
			local request=ask(h,{[field]=case[1]})
			local okM,why=H.rackEgg(h,"outfit",request)
			assert(not okM and why==case[2],field..": "..tostring(why))
		end
		h.restricted=true
		assert(select(2,H.rackEgg(h,"outfit",ask(h,{mode="random"})))=="PolicyChanged")
		h.restricted=false
		-- a pick owned since the snapshot (another server, the gift): the key no longer binds the pool
		local request=ask(h)
		local item=H.public(h).rack.pets.pip.items[1].id
		h.state.petWearables={pip={owned={item},equipped={}}}
		assert(select(2,H.rackEgg(h,"outfit",request))=="PoolChanged")
		assert(h.state.nectar==stars and c.writes==writes and db.player_1.hatching.rack==nil,"no charge, no write")
		assert(select(2,H.rackEgg(h,"outfit",{requestId="",petId="pip"}))=="InvalidRack")
		assert(select(2,H.rackEgg(h,"hat",request))=="InvalidRack")
	end)

	test("inside the write: RackDone, ClosetFull at 128, NeedStars, a broken field never written over, an open reveal",function()
		on()
		local h,db,c=fresh();h=rich(h,db,c)
		local day=Rack.today(c.now)
		local picks={};for _,r in ipairs(Rack.picks("pip",day))do table.insert(picks,r.id)end
		h=rejoin(h,db,c,{petWearables={pip={owned=picks,equipped={}}}})
		local done=ask(h);assert(H.public(h).rack.pets.pip.rest)
		assert(select(2,H.rackEgg(h,"outfit",done))=="RackDone","every pick owned: the egg rests")
		local full={};for i=1,128 do full[i]="old_item_"..i end
		h=rejoin(h,db,c,{petWearables={pip={owned=full,equipped={}}}})
		assert(H.public(h).rack.pets.pip.full==true)
		assert(select(2,H.rackEgg(h,"outfit",ask(h)))=="ClosetFull"and #db.player_1.hatching.petWearables.pip.owned==128)
		h=rejoin(h,db,c,{petWearables={},nectar=24})
		assert(select(2,H.rackEgg(h,"outfit",ask(h)))=="NeedStars"and h.state.nectar==24)
		h=rejoin(h,db,c,{nectar=1000,rack={v=1,ops="junk"}})
		local pub=H.public(h).rack
		assert(pub.broken and pub.pets.pip.rest,"a broken field rests the egg")
		assert(select(2,H.rackEgg(h,"outfit",ask(h)))=="RackBroken"and db.player_1.hatching.rack.ops=="junk"and h.state.nectar==1000)
		local r,dbr,cr=fresh(true,true)
		r=rejoin(r,dbr,cr,{nectar=1000})
		local seq=r.state.operationSeq
		assert(select(2,H.rackEgg(r,"outfit",ask(r)))=="RevealPending"and r.state.operationSeq==seq,"never under an open reveal")
	end)

	test("restricted players: the fixed next pick (common first), never the sparkle; ops keep the last 16",function()
		on()
		local h,db,c=fresh();h=rich(h,db,c);h.restricted=true
		local day=Rack.today(c.now)
		for i=1,8 do
			local request,view=ask(h)
			local okF,why,record=H.rackEgg(h,"outfit",request)
			assert(okF and why=="Saved"and record.item==view.next,i..": "..tostring(why))
		end
		assert(select(2,H.rackEgg(h,"outfit",ask(h)))=="RackDone")
		assert(not table.find(owned(h),Rack.sparkle("pip",day).id),"the sparkle is not on the fixed path")
		local op=0
		local field=copy(db.player_1.hatching.rack)
		field.ops={};for i=1,20 do table.insert(field.ops,"o"..i)end
		local s={rack=field,inventoryMask=1,nectar=100,petWearables={}}
		assert(not RackState.read(s).broken,"a later build may keep more")
		field.ops[1]=5;assert(RackState.read(s).broken)
		assert(op==0)
	end)

	test("the rack's Outfit gift: after the tuck, the Pom Beanie worn on the pet that is out; then Paint, Toy counted from it",function()
		on()
		local h,db,c=fresh()
		assert(select(2,H.giftEgg(h,"outfit",{nest=true}))=="NotDue","before the tuck")
		h=rejoin(h,db,c,{nest={at=c.now,n=0,tucked=true,pet="pip"}})
		assert(H.giftReady(h,{nest=true})=="outfit")
		local pub=H.giftsPublic(h,{nest=true})
		assert(pub.outfit=="beanie"and pub.granted.outfit==false and Gifts.odds("outfit",h.state,"pip")[1].percent==100)
		assert(select(2,H.giftEgg(h,"paint",{nest=true}))=="NotDue","Paint waits for the Outfit gift")
		local stars=h.state.nectar
		local okO,whyO,r=H.giftEgg(h,"outfit",{nest=true})
		assert(okO and whyO=="Saved"and r.kind=="outfit"and r.item=="beanie"and r.pet=="pip",tostring(whyO))
		assert(table.find(owned(h),"beanie")and h.state.petWearables.pip.equipped.Hat=="beanie"and h.state.nectar==stars,"worn, free")
		local saved=db.player_1.hatching.gifts.outfit
		assert(saved.item=="beanie"and saved.pet=="pip"and saved.rounds==(h.state.stats.rounds or 0))
		assert(Gifts.unseen(h.state,true)=="outfit"and Gifts.unseen(h.state)==nil)
		assert(H.giftSeen(h,"outfit")and db.player_1.hatching.gifts.outfit.seen==true,"seen through giftSeen, no coach bit")
		local again,whyAgain=H.giftEgg(h,"outfit",{nest=true});assert(again and whyAgain=="AlreadyGranted")
		-- Paint: two rounds after the Outfit gift (or a later day)
		assert(select(2,H.giftEgg(h,"paint",{nest=true}))=="NotDue")
		local stats=copy(db.player_1.hatching.stats);stats.rounds=(saved.rounds or 0)+2
		h=rejoin(h,db,c,{stats=stats})
		assert(H.giftReady(h,{nest=true})=="paint")
		local okP,whyP=H.giftEgg(h,"paint",{nest=true});assert(okP and whyP=="Saved")
		assert(db.player_1.hatching.gifts.paint.rounds==stats.rounds)
		-- Toy: counted from the Paint gift now
		assert(select(2,H.giftEgg(h,"toy",{nest=true}))=="NotDue","two rounds after Paint, not after the Bear")
		local later=rejoin(h,db,c,nil,86400)
		assert(H.giftEgg(later,"toy",{nest=true}),"a later server day")
	end)

	test("the Outfit gift: an unowned pet, no hat left, a full closet; Paint keeps its trigger when the Outfit can never come",function()
		on()
		local h,db,c=fresh()
		h=rejoin(h,db,c,{nest={at=c.now,n=0,tucked=true,pet="pip"}})
		h.statPetOf=function()return "blip"end
		assert(select(2,H.giftEgg(h,"outfit",{nest=true}))=="Unowned","the pet that is out must be owned")
		h.statPetOf=nil
		h=rejoin(h,db,c,{petWearables={pip={owned={"beanie","partyhat"},equipped={}}}})
		assert(select(2,H.giftEgg(h,"outfit",{nest=true}))=="AllOwned")
		assert(H.giftReady(h,{nest=true})=="paint","no hat to give: Paint keeps its own trigger")
		local full={};for i=1,128 do full[i]="old_item_"..i end
		h=rejoin(h,db,c,{petWearables={pip={owned=full,equipped={}}}})
		assert(select(2,H.giftEgg(h,"outfit",{nest=true}))=="ClosetFull"and #db.player_1.hatching.petWearables.pip.owned==128)
		-- the first unowned common Hat when the beanie is owned
		h=rejoin(h,db,c,{petWearables={pip={owned={"beanie"},equipped={}}}})
		local okO,_,r=H.giftEgg(h,"outfit",{nest=true});assert(okO and r.item=="partyhat")
	end)

	test("a save that got Paint under the old order is owed the Outfit gift next; a malformed Outfit record closes it alone",function()
		off()
		local h,db,c=fresh()
		h=rejoin(h,db,c,{nest={at=c.now,n=0,tucked=true,pet="pip"}})
		assert(H.giftEgg(h,"paint",{nest=true}))
		on()
		assert(H.giftReady(h,{nest=true})=="outfit")
		assert(H.giftEgg(h,"outfit",{nest=true}))
		local s={gifts={v=1,outfit={op="a",day="1"}},inventoryMask=1,nest={tucked=true}}
		assert(Gifts.granted(s,"outfit")and not Gifts.granted(s,"paint"),"a bad Outfit record closes the Outfit gift only")
		assert(select(2,Gifts.due(s,"outfit","2",{rack=true,petId="pip"}))=="AlreadyGranted")
		assert(Gifts.due(s,"paint","2",{rack=true,petId="pip"}),"Paint keeps its trigger")
		assert(Gifts.due(s,"paint","2",{}),"off: as before")
	end)

	test("the Paint Egg's daily splash: the day beside the quote must be today; the roll uses that day's table; no quote key",function()
		on({lookdaily=true,looknopity=true})
		local h,db,c=fresh();h=rich(h,db,c);h.lookAvailable=true
		local p=H.public(h)
		assert(p.lookDay==Rack.today(c.now)and p.lookNoPity==true and p.lookPoolVersion==1)
		local function fields(extra)
			local s=h.state;local r=s.revision
			local v={id=tostring(r)..":look-"..tostring(s.operationSeq+1),catalogVersion=Hue.CatalogVersion,poolVersion=LE.PoolVersion,price=LE.Price,
				selectionMode="random",missingCharms=LE.missing(s.charmUnlocks),charmMisses=LS.misses(s)}
			for k,x in pairs(extra or {})do v[k]=x end
			return v,r
		end
		local stars=h.state.nectar
		local q,r=fields()
		assert(select(2,H.hueCommand(h,"lookBuy",q,r))=="PoolChanged","no day: refused")
		q,r=fields({lookDay=p.lookDay-1})
		assert(select(2,H.hueCommand(h,"lookBuy",q,r))=="PoolChanged","yesterday's odds: refused")
		assert(h.state.nectar==stars,"no charge")
		-- the splash pot's slice: the middle of its 23%
		local splash=LE.splashOf(p.lookDay)
		local cumulative=0
		for _,row in ipairs(LE.odds(LE.missing(h.state.charmUnlocks),p.lookDay))do
			if row.id==splash then c.unit=(cumulative+row.percent/2)/100 end
			cumulative+=row.percent
		end
		q,r=fields({lookDay=tostring(p.lookDay)})
		local okL,whyL,receipt=H.hueCommand(h,"lookBuy",q,r)
		assert(okL,tostring(whyL))
		assert(receipt.itemId==splash,"rolled on the day's table: "..tostring(receipt.itemId))
		local saved=h.state.hueItemReceipts[q.id]
		assert(saved and saved.quote.lookDay==nil and saved.quote.poolVersion==1,"the day is never in the quote")
		off()
		assert(H.public(h).lookDay==nil)
	end)
	end)
	Rack.inject(nil)
	if not ok then error(problem,0)end
	return {passed=#cases,cases=cases}
end
