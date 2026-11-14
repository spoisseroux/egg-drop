-- Overnight 2026-11-14, slice C server (SYSTEMS-SCOPE 3.2 / 3.4): Star purchases of wearables,
-- faceplates and ball themes pay the weekly shelf price on the shelf week and the catalogue
-- price otherwise; the week is frozen in the purchase, a week boundary before the write is
-- refused as ShelfChanged with no charge, and a write that already landed still proves Saved
-- after the boundary. Also the book-only plate generalization (Bookworm + Stargazer).
-- Isolated adapters only; the shelf itself (which items, what discount) is WeeklyShelf.spec.
-- Usage (Server): require(ServerScriptService.Server.ZZSpecs.ShelfPurchase)(ServerScriptService.Server)
-- Returns the passed case names; cases that need content this build lacks are named "SKIPPED ...".
return function(server)
	local H=require(server.HatchProgress)
	local W=require(server.WearableState)
	local F=require(server.FaceplateState)
	local B=require(server.BallThemeState)
	local Shared=game:GetService("ReplicatedStorage").Shared
	local Flags=require(Shared.FeatureFlags)
	local Wear=require(Shared.WearableCatalog)
	local Plates=require(Shared.DeckThemes)
	local Balls=require(Shared.BallThemes)
	local Book=require(Shared.BookCatalog)
	local shelfModule=Shared:FindFirstChild("WeeklyShelf")
	local Shelf=if shelfModule then require(shelfModule)else nil
	local cases={}
	local WEEK=7*86400
	local function copy(v)if type(v)~="table"then return v end;local r={};for k,x in pairs(v)do r[k]=copy(x)end;return r end
	local function test(name,run)run();table.insert(cases,name)end
	local function skip(name)table.insert(cases,"SKIPPED "..name)end
	local function fixture(seed,now)
		local db,c={},{now=now or 1700000000,serial=0,writes=0,failNext=nil}
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
		if seed then db.player_1=seed end
		local h=H.load(1,{rank=1},adapter)
		assert(h.status=="Ready","fixture load "..tostring(h.status))
		return h,db,c
	end
	local function reseed(db,fields)
		local seed=copy(db.player_1)
		for key,value in pairs(fields)do seed.hatching[key]=value end
		seed.hatching.lease={token="",expiresAt=0};return seed
	end
	local function fund(h,stars)assert(H.grantPurchase(h,"fund-"..stars.."-"..h.state.revision,stars,false))end
	local shelfOn=Shelf~=nil and Flags.WeeklyShelf==true
	-- The shelf slot of `kind` in the week of `now` (nil when that kind is not on the shelf).
	local function slotOf(kind,now,variant)
		if not shelfOn then return nil end
		for _,slot in ipairs(Shelf.slots(Shelf.week(now)))do
			if slot.kind==kind then
				local item=kind=="wearable"and Wear.item("pip",slot.id)
				if kind~="wearable"or(item~=nil and(item.variant==true)==(variant==true))then return slot end
			end
		end
		return nil
	end
	-- A time whose shelf week carries `kind` (the third slot alternates weekly).
	local function weekWith(kind,variant)
		for offset=0,3 do
			local now=1700000000+offset*WEEK
			local slot=slotOf(kind,now,variant)
			if slot then return now,slot end
		end
		return nil,nil
	end
	-- One kind's buy call, wallet reader and base price, so every kind runs the same cases.
	local kinds={
		wearable={
			buy=function(h,op,id,price)return H.buyWearable(h,op,"pip",id,price,false)end,
			owns=function(h,id)return W.owns(h.state,"pip",id)end,
			base=function(id)return Wear.price("pip",id)end,
			other=function(avoid)
				for _,item in ipairs(Wear.forPet("pip").order)do
					if item.id~=avoid and not item.variant and type(item.price)=="number"then return item.id end
				end
			end,
		},
		faceplate={
			buy=function(h,op,id,price)return H.buyFaceplate(h,op,id,price)end,
			owns=function(h,id)return F.owns(h.state,id)end,
			base=function(id)return Plates.price(id)end,
			other=function(avoid)for _,id in ipairs(Plates.Order)do if id~=avoid and Plates.price(id)then return id end end end,
		},
		ball={
			buy=function(h,op,id,price)return H.buyBallTheme(h,op,id,price,false)end,
			owns=function(h,id)return B.owns(h.state,id)end,
			base=function(id)return Balls.price(id)end,
			other=function(avoid)for _,id in ipairs(Balls.Order)do if id~=avoid and Balls.price(id)then return id end end end,
		},
	}

	test("the snapshot carries the server's shelf week; without a shelf every price is the catalogue price",function()
		local h=fixture()
		if shelfOn then
			assert(H.public(h).shelfWeek==Shelf.week(1700000000),"public.shelfWeek is the pricing week")
		else
			assert(H.public(h).shelfWeek==nil,"no shelf: no week")
		end
		-- The state checks ignore the shelf when no week is given.
		local id=kinds.wearable.other(nil)
		assert(W.price("pip",id,nil)==Wear.price("pip",id))
	end)

	for _,kind in ipairs({"wearable","faceplate","ball"})do
		local api=kinds[kind]
		local now,slot=weekWith(kind,false)
		if not slot then
			skip(kind.." shelf cases (no "..kind.." on the shelf in the sampled weeks, or the shelf is off)")
			continue
		end
		local full=api.base(slot.id)

		test(kind..": the shelf price is accepted on its week and is what the wallet pays",function()
			assert(type(full)=="number"and slot.full==full and slot.price<full and slot.price>=1,"a real discount")
			local h=fixture(nil,now);fund(h,full*3)
			local wallet=h.state.nectar
			local refused,why=api.buy(h,"full",slot.id,full)
			assert(not refused and why=="PriceChanged"and h.state.nectar==wallet and not api.owns(h,slot.id),"the full price is refused on the shelf week")
			local ok,reason=api.buy(h,"deal",slot.id,slot.price)
			assert(ok and reason=="Saved",tostring(reason))
			assert(api.owns(h,slot.id)and h.state.nectar==wallet-slot.price,"paid the shelf price")
			assert(h.state.stats.starsSpent>=slot.price)
			local again,whyAgain=api.buy(h,"deal",slot.id,slot.price)
			assert(again and whyAgain=="AlreadyOwned"and h.state.nectar==wallet-slot.price,"never charged twice")
		end)

		test(kind..": an item that is not on the shelf pays the catalogue price, never a made-up discount",function()
			local other=api.other(slot.id)
			if not other or (shelfOn and Shelf.price(kind,other,Shelf.week(now)))then return end
			local price=api.base(other)
			local h=fixture(nil,now);fund(h,price*2+10)
			local wallet=h.state.nectar
			local refused,why=api.buy(h,"cheap",other,price-1)
			assert(not refused and why=="PriceChanged"and h.state.nectar==wallet)
			assert(api.buy(h,"fair",other,price))
			assert(h.state.nectar==wallet-price and api.owns(h,other))
		end)

		test(kind..": the week after, the same item is full price again",function()
			local later=now+WEEK
			if Shelf.price(kind,slot.id,Shelf.week(later))then return end -- still on the shelf: nothing to show
			local h=fixture(nil,later);fund(h,full*2)
			local wallet=h.state.nectar
			local refused,why=api.buy(h,"stale",slot.id,slot.price)
			assert(not refused and why=="PriceChanged"and h.state.nectar==wallet,"last week's deal is refused")
			assert(api.buy(h,"full",slot.id,full)and h.state.nectar==wallet-full)
		end)

		test(kind..": a week boundary between the request and the write is ShelfChanged and charges nothing",function()
			local h,db,c=fixture(nil,now);fund(h,full*2)
			local wallet=h.state.nectar
			c.failNext="before"
			local ok,reason=api.buy(h,"edge",slot.id,slot.price)
			assert(not ok and reason=="Retrying"and h.pending and h.pending.candidate.week==Shelf.week(now),"the week is frozen in the candidate")
			-- The store comes back after Monday's rollover. Keep the lease alive across the gap.
			db.player_1.hatching.lease.expiresAt=c.now+WEEK+1000
			c.now+=WEEK
			local late,why=H.retry(h)
			assert(not late and why=="ShelfChanged",tostring(why))
			assert(h.pending==nil and not api.owns(h,slot.id),"no stranded operation")
			assert(db.player_1.hatching.nectar==wallet,"no charge")
		end)

		test(kind..": an ambiguous write retried after the boundary still pays exactly once",function()
			local h,db,c=fixture(nil,now);fund(h,full*2)
			local wallet=h.state.nectar
			c.failNext="after"
			local ok,reason=api.buy(h,"lost",slot.id,slot.price)
			assert(not ok and reason=="Retrying"and db.player_1.hatching.nectar==wallet-slot.price,"the write landed")
			db.player_1.hatching.lease.expiresAt=c.now+WEEK+1000
			c.now+=WEEK
			local saved,why=H.retry(h)
			assert(saved and why=="Saved",tostring(why))
			assert(h.pending==nil and api.owns(h,slot.id)and h.state.nectar==wallet-slot.price,"proof precedes the boundary check")
		end)

		test(kind..": one operation id is bound to one price",function()
			local h,_,c=fixture(nil,now);fund(h,full*2)
			c.failNext="before"
			local ok,reason=api.buy(h,"same",slot.id,slot.price)
			assert(not ok and reason=="Retrying"and h.pending)
			local clash,why=api.buy(h,"same",slot.id,full)
			assert(not clash and why=="OperationConflict","the pending operation keeps its price")
			assert(api.buy(h,"same",slot.id,slot.price),"the same request resumes and saves")
		end)
	end

	do
		local now,slot=weekWith("wearable",true)
		if slot then
			test("a recolour variant on the shelf is priced like any wearable",function()
				local h=fixture(nil,now);fund(h,slot.full*2)
				local wallet=h.state.nectar
				local item=Wear.item("pip",slot.id)
				assert(item and item.variant and item.base and not W.owns(h.state,"pip",item.base))
				assert(H.buyWearable(h,"variant","pip",slot.id,slot.price,true))
				assert(h.state.nectar==wallet-slot.price and W.owns(h.state,"pip",slot.id))
				assert(not W.owns(h.state,"pip",item.base),"owning a variant does not own its base")
			end)
		else skip("variant shelf case (no variant on the shelf in the sampled weeks)")end
	end

	test("book-only plates: the list always starts with Bookworm, and only its ids can be granted",function()
		local ids=H.bookPlateIds()
		assert(#ids>=1 and table.find(ids,Book.BookOnlyFaceplate),"Bookworm stays a book-only plate")
		for _,id in ipairs(ids)do assert(Plates.price(id)==nil,id.." is never sold")end
		local h=fixture()
		assert(#H.bookPlatesOwed(h.state)==0 and not H.bookFaceplateOwed(h.state)and next(H.bookPlatesOwned(h.state))==nil)
	end)

	do
		local stargazer=table.find(H.bookPlateIds(),"stargazer")~=nil and Book.milestone("discoveries.100")~=nil
		if stargazer then
			test("Discoveries at 100% grants Stargazer with the claim; a repeat claim repairs a missed plate",function()
				local found=0
				for _,item in ipairs(Book.Pages.discoveries.items)do found=bit32.bor(found,bit32.lshift(1,item.bit))end
				local _,db0=fixture()
				local h,db=fixture(reseed(db0,{book={claimed={},found=found}}))
				assert(Book.pagePercent(h.state,"discoveries")==100)
				for _,step in ipairs({25,50,75})do
					assert(H.bookClaim(h,"s"..step,"discoveries."..step))
					assert(not F.owns(h.state,"stargazer"),"not before the page is claimed at 100%")
				end
				local wallet=h.state.nectar
				assert(H.bookClaim(h,"s100","discoveries.100"))
				assert(F.owns(h.state,"stargazer")and h.state.nectar==wallet+Book.Rewards[100],"plate and Stars in one write")
				assert(not F.owns(h.state,Book.BookOnlyFaceplate),"one page is not three: Bookworm is separate")
				assert(H.bookPlatesOwned(h.state).stargazer==true and #H.bookPlatesOwed(h.state)==0)
				-- A save that claimed before the plate existed (or lost it): the next claim repairs it, unpaid.
				local plates={}
				for _,id in ipairs(db.player_1.hatching.faceplates)do if id~="stargazer"then table.insert(plates,id)end end
				local again,_,c=fixture(reseed(db,{faceplates=plates}))
				assert(not F.owns(again.state,"stargazer")and H.bookFaceplateOwed(again.state))
				local before,writes=again.state.nectar,c.writes
				local ok,reason=H.bookClaim(again,"repair","discoveries.100")
				assert(ok and reason=="Saved"and F.owns(again.state,"stargazer")and again.state.nectar==before and c.writes==writes+1,"repaired, not paid")
				local done,why=H.bookClaim(again,"repair2","discoveries.100")
				assert(done and why=="AlreadyClaimed"and c.writes==writes+1,"then a no-op")
			end)
		else skip("Stargazer cases (the plate or the Discoveries milestone is not in this build's catalogue)")end
	end

	return cases
end
