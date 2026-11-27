-- Paint pots through the real save (PAINT-SHINE-DRESS-PLAN): HatchProgress.potCommand on isolated fixture records.
-- Charged once (replay, a lost reply, a store error), Stars checked inside UpdateAsync, refused under an open Paint Egg
-- reservation with nothing charged, newer and malformed paintPots data repaired at load (never a failed load), and the
-- snapshot unchanged until a pot is bought. Isolated adapters only; never real user writes.
-- Offline: scripts/run_dash_server_specs.py. Studio: require(ServerScriptService.Server.ZZSpecs.PaintPotProgress)(Server).
return function(server)
	local RawH=require(server.HatchProgress)
	local H={};for k,v in pairs(RawH)do H[k]=v end
	function H.load(...)local h=RawH.load(...);h.restricted=false;return h end
	local Shared=game:GetService("ReplicatedStorage").Shared
	local Pots=require(Shared.PaintPotCatalog)
	local Hue=require(Shared.HueCatalog)
	local LE=require(Shared.LookEggCatalog)
	local LS=require(server.LookState)
	local S=require(server.PaintPotState)
	local cases={}
	local function test(name,run)run();table.insert(cases,name)end
	local function copy(v)if type(v)~="table"then return v end;local r={};for k,x in pairs(v)do r[k]=copy(x)end;return r end
	local function fixture(db)
		db=db or {}
		local c={now=1700000000,serial=0,writes=0}
		local a={now=function()return c.now end,guid=function()c.serial+=1;return "pp"..c.serial end,random=function()return .01 end,wait=function()end}
		a.update=function(key,transform)
			c.writes+=1
			if c.failNext=="before"then c.failNext=nil;error("store down")end
			local value=transform(copy(db[key]))
			if value then db[key]=copy(value)end
			if c.failNext=="after"then c.failNext=nil;error("response lost")end
			if c.failSettlement and db[key]and db[key].hatching.hueReservation then c.failSettlement=false;c.failNext="before"end
			return copy(value)
		end
		local h=H.load(1,{rank=1},a);assert(h.status=="Ready","fixture "..tostring(h.status))
		return h,db,c,a
	end
	local function fund(h,stars)assert(H.grantPurchase(h,"fund-"..stars.."-"..h.state.revision,stars,false))end
	local function quote(h,item,id)
		local r=h.state.revision
		return {id=id or(tostring(r)..":pot-"..tostring(h.state.operationSeq+1)),itemId=item or "tide",price=Pots.Price},r
	end
	local function buy(h,item,id)local v,r=quote(h,item,id);local ok,why,receipt=H.potCommand(h,"potBuy",v,r);return ok,why,receipt,v,r end

	test("a pot: 15 Stars out, one jar in hueInventory, one revision, a valid save",function()
		local h,db=fixture();fund(h,40)
		local wallet,rev,jars=h.state.nectar,h.state.revision,h.state.hueInventory.tide
		local ok,why,receipt=buy(h,"tide")
		assert(ok and why=="Saved",tostring(why))
		assert(h.state.nectar==wallet-15 and h.state.hueInventory.tide==jars+1 and h.state.revision==rev+1)
		assert(receipt.itemId=="tide"and receipt.price==15 and receipt.inventoryAfter==jars+1)
		assert(RawH.valid(h.state)and RawH.valid(db.player_1.hatching))
		assert(H.public(h).lastPotResult.id==receipt.id)
		assert(db.player_1.hatching.lastOperation.digest=="pot:tide:15"and #db.player_1.hatching.lastOperation.digest<=120)
	end)

	test("charged once: the same request replays AlreadySaved; the same id for another pot is a conflict",function()
		local h=fixture();fund(h,40)
		local ok,why,_,v,r=buy(h,"rose");assert(ok and why=="Saved")
		local wallet=h.state.nectar
		local again,whyAgain,receipt=H.potCommand(h,"potBuy",v,r)
		assert(again and whyAgain=="AlreadySaved"and receipt.itemId=="rose"and h.state.nectar==wallet)
		local other=table.clone(v);other.itemId="iris"
		local no,whyNo=H.potCommand(h,"potBuy",other,r);assert(not no and whyNo=="OperationConflict"and h.state.nectar==wallet)
	end)

	test("a lost reply and a store error: the pending buy resumes with the same id and charges once",function()
		local h,db,c=fixture();fund(h,40)
		local wallet=h.state.nectar
		c.failNext="after"
		local ok,why,_,v,r=buy(h,"citrus");assert(not ok and why=="Retrying")
		assert(db.player_1.hatching.nectar==wallet-15,"the write landed")
		local resumed,whyResumed=H.potCommand(h,"potBuy",v,r);assert(resumed and(whyResumed=="Saved"or whyResumed=="AlreadySaved"),tostring(whyResumed))
		assert(h.state.nectar==wallet-15 and h.state.hueInventory.citrus==1)
		c.failNext="before"
		local ok2,why2,_,v2,r2=buy(h,"citrus");assert(not ok2 and why2=="Retrying"and h.state.nectar==wallet-15)
		local ok3=H.retry(h);assert(ok3 and h.state.nectar==wallet-30 and h.state.hueInventory.citrus==2)
		local ok4,why4=H.potCommand(h,"potBuy",v2,r2);assert(ok4 and why4=="AlreadySaved"and h.state.nectar==wallet-30)
	end)

	test("Stars are the save's check: short refuses NeedStars with nothing written; a stale price or revision too",function()
		local h,db,c=fixture()
		h.state.nectar=0;db.player_1.hatching.nectar=0
		local writes=c.writes
		local ok,why=buy(h,"tide");assert(not ok and why=="NeedStars"and c.writes==writes)
		fund(h,40)
		local v,r=quote(h,"tide");v.price=12
		ok,why=H.potCommand(h,"potBuy",v,r);assert(not ok and why=="PriceChanged")
		v,r=quote(h,"tide");ok,why=H.potCommand(h,"potBuy",v,r-1);assert(not ok)
		-- The snapshot's own wallet can be stale: the UpdateAsync state decides.
		h.state.nectar=999
		ok,why=buy(h,"tide")
		assert(ok,tostring(why))
	end)

	test("an open Paint Egg reservation: the pot is refused, nothing charged, and the reservation still settles (review item 2)",function()
		local h,db,c,a=fixture();fund(h,200);h.lookAvailable=true
		local cleared=false;for _,id in ipairs({"rose","tide","citrus","iris"})do cleared=cleared or h.state.hueInventory[id]==0 end;assert(cleared)
		c.failSettlement=true
		local r=h.state.revision
		local look={id=tostring(r)..":look-1",catalogVersion=Hue.CatalogVersion,poolVersion=LE.PoolVersion,price=LE.Price,selectionMode="random",
			missingCharms=LE.missing(h.state.charmUnlocks),charmMisses=LS.misses(h.state)}
		local ok,why=H.hueCommand(h,"lookBuy",look,r);assert(not ok and why=="Retrying",tostring(why))
		assert(db.player_1.hatching.hueReservation,"the reservation is saved")
		local wallet,seq=db.player_1.hatching.nectar,db.player_1.hatching.operationSeq
		local pot,potWhy=buy(h,"tide");assert(not pot,"refused while the reservation is open: "..tostring(potWhy))
		assert(db.player_1.hatching.nectar==wallet and db.player_1.hatching.operationSeq==seq,"nothing charged, the sequence untouched")
		-- The rule itself, on a state that holds the reservation (a handle with no pending, e.g. another code path).
		local s=copy(db.player_1.hatching)
		local q=S.quote("potBuy",{id=tostring(s.revision)..":pot-x",itemId="tide",price=15},s.revision)
		local allowed,refusal=S.apply(s,{quote=q,operationId="z",sequence=s.operationSeq+1,digest=S.digest(q)})
		assert(not allowed and refusal=="RevealPending")
		c.now+=200
		local joined=H.load(1,{rank=1},a)
		assert(joined.status=="Ready"and not joined.state.hueReservation and joined.state.nectar==wallet-LE.Price,"the egg settles")
	end)

	test("load: a newer build's paintPots is kept; a malformed one is repaired; never a failed load (review item 4)",function()
		local h,db,c,a=fixture();fund(h,40)
		assert(buy(h,"tide"))
		local hatching=db.player_1.hatching
		hatching.paintPots.version=3
		table.insert(hatching.paintPots.receipts,{op="99:pot-z",digest="pot:gold:40",itemId="gold",price=40,later=true})
		hatching.lease.expiresAt=0;c.now+=200
		local again=H.load(1,{rank=1},a);assert(again.status=="Ready")
		assert(again.state.paintPots.version==3 and #again.state.paintPots.receipts==2 and again.state.paintPots.receipts[2].later==true)
		db.player_1.hatching.paintPots={receipts={"junk",{op=""},{op="ok",digest="pot:rose:15"}}}
		db.player_1.hatching.lease.expiresAt=0;c.now+=200
		local repaired=H.load(1,{rank=1},a);assert(repaired.status=="Ready")
		assert(#repaired.state.paintPots.receipts==1 and repaired.state.paintPots.receipts[1].op=="ok")
		db.player_1.hatching.paintPots=7
		db.player_1.hatching.lease.expiresAt=0;c.now+=200
		local dropped=H.load(1,{rank=1},a);assert(dropped.status=="Ready"and dropped.state.paintPots==nil and dropped.state.hueInventory.tide>=1)
	end)

	test("no pot, no change: the snapshot and the save carry nothing new",function()
		local h,db=fixture();fund(h,40)
		assert(H.public(h).lastPotResult==nil and db.player_1.hatching.paintPots==nil)
	end)

	return {passed=#cases,cases=cases}
end
