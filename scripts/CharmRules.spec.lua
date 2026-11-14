-- Overnight 2026-11-14, slice D server (SYSTEMS-SCOPE 4.1 / 4.3 / 4.4): the server side of the
-- earned charm shapes, the two optional lifetime counters, the item-kinds summary field, the
-- state-derived Discoveries hook and the stale toy pool refusal.
--   * a charm shape whose rule is not met is rejected as "Locked"; free shapes and
--     visibility-only requests never ask
--   * stats.weeklyBonuses goes up only on a paid weekly bonus claim (slot 0); stats.itemWinKinds
--     ORs the item kinds of won rounds; a save without either key is valid
--   * summary.itemKinds out of range is InvalidSummary (never a failed save)
--   * Discoveries the save itself earns are set on any committed write; pet_night only on a pet write
--   * a Toy Egg purchase quoting an old pool is LegacyPurchaseClosed
-- The catalogues (charm rules, discovery bits, toy pools) are Lane K's; cases that need content
-- this build lacks are returned as "SKIPPED ...". Isolated adapters only.
-- Usage (Server): require(ServerScriptService.Server.ZZSpecs.CharmRules)(ServerScriptService.Server)
return function(server)
	local H=require(server.HatchProgress)
	local L=require(server.LifetimeState)
	local A=require(server.PetAppearance)
	local Shared=game:GetService("ReplicatedStorage").Shared
	local Charms=require(Shared.PetCharmCatalog)
	local Book=require(Shared.BookCatalog)
	local Toys=require(Shared.ToyCatalog)
	local Items=require(Shared.RoundItems)
	local cases={}
	local function copy(v)if type(v)~="table"then return v end;local r={};for k,x in pairs(v)do r[k]=copy(x)end;return r end
	local function test(name,run)run();table.insert(cases,name)end
	local function skip(name)table.insert(cases,"SKIPPED "..name)end
	local function fixture(seed,now)
		local db,c={},{now=now or 1700000000,serial=0,writes=0}
		local adapter={
			now=function()return c.now end,
			guid=function()c.serial+=1;return "op"..c.serial end,
			random=function()return .1 end,
			wait=function()end,
			update=function(key,transform)
				c.writes+=1
				local value=transform(copy(db[key]))
				if value then db[key]=copy(value)end
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
	local function summary(h,overrides)
		local s={family="pip",day=H.public(h).dailyDay,success=true,clean=false,score=100,chain=1,clears=0,drops=24,heat="easy",goalsMet=2}
		for k,v in pairs(overrides or {})do s[k]=v end
		return s
	end
	local function has(found,id)
		local entry=Book.DiscoveryById[id]
		return entry~=nil and bit32.band(found,bit32.lshift(1,entry.bit))~=0
	end

	-- ── Charm shapes ────────────────────────────────────────────────────────
	-- One request through PetAppearance.request with a stand-in profile writer.
	local function ask(state,profile,seq,shape,now,earned)
		local value={petId="pip",visible=true,seq=seq,shape=shape,shapeVersion=if shape then Charms.Version else nil}
		return A.request(state,profile,value,now,true,function()return true end,function(target,id,visible,chosen)
			target.petAppearance=target.petAppearance or {}
			local old=target.petAppearance[id]
			target.petAppearance[id]={charmVisible=visible,charmShape=chosen or(old and old.charmShape)or Charms.Default,at=seq,writer="spec"}
		end,earned)
	end
	local ruled
	for _,id in ipairs(Charms.Order)do
		if type(Charms.rule)=="function"and Charms.rule(id)then ruled=ruled or id end
	end

	test("facts come from the save: stamps, claimed milestones, stats, bond",function()
		local facts=A.facts({stamps=9,book={claimed={"wardrobe.100"},found=0},stats={weeklyBonuses=4},bond={pip=3}})
		assert(facts.stamps==9 and facts.claimed[1]=="wardrobe.100"and facts.stats.weeklyBonuses==4 and facts.bond.pip==3)
		local empty=A.facts(nil)
		assert(empty.stamps==0 and #empty.claimed==0 and next(empty.stats)==nil and next(empty.bond)==nil,"junk reads as nothing earned")
		assert(A.facts({stamps="7",book=3,stats="x",bond=false}).stamps==0)
		for _,id in ipairs({"dot","ring","pebble"})do assert(A.earned(id,{})==true,id.." is free")end
	end)

	if ruled then
		test("a locked shape is rejected as Locked and changes nothing; earned and free shapes save",function()
			local state,profile=A.new({selectionsEnabled=true}),{petAppearance={}}
			local locked,changed=ask(state,profile,1,ruled,10,function(shape)return shape~=ruled end)
			assert(locked.status=="Rejected"and locked.reason=="Locked"and changed==false,"Locked")
			assert(A.shape(profile,"pip")==Charms.Default and not A.visible(profile,"pip"),"nothing applied")
			local free,freeChanged=ask(state,profile,2,"ring",11,function(shape)return shape~=ruled end)
			assert(free.status=="Saved"and freeChanged and A.shape(profile,"pip")=="ring","a free shape is unaffected")
			local ok,okChanged=ask(state,profile,3,ruled,12,function()return true end)
			assert(ok.status=="Saved"and okChanged and A.shape(profile,"pip")==ruled,"once earned it saves")
			-- Visibility-only requests (no marked shape) never ask the rule, even for a worn earned shape.
			local asked=false
			local value={petId="pip",visible=false,seq=4}
			local hide=A.request(state,profile,value,13,true,function()return true end,function(target,id,visible)
				target.petAppearance[id].charmVisible=visible
			end,function()asked=true;return false end)
			assert(hide.status=="Saved"and not asked and A.shape(profile,"pip")==ruled,"hide/show keeps the shape")
			-- Callers that pass no rule callback (older call sites, specs) behave as before.
			local legacy=ask(A.new({selectionsEnabled=true}),{petAppearance={}},1,ruled,20,nil)
			assert(legacy.status=="Saved")
		end)

		test("the rule is read from the save through PetAppearance.earned",function()
			local h=fixture()
			assert(A.earned(ruled,h.state)==false,"a fresh save has not earned "..ruled)
			assert(A.earned("nope",h.state)==false,"unknown shapes are never earned")
			if Charms.known("heart")then
				assert(not A.earned("heart",{book={claimed={"wardrobe.75"},found=0}}))
				assert(A.earned("heart",{book={claimed={"wardrobe.75","wardrobe.100"},found=0}}),"Heart: Wardrobe page claimed at 100%")
			end
			if Charms.known("star")then
				assert(not A.earned("star",{stats={weeklyBonuses=3}}))
				assert(A.earned("star",{stats={weeklyBonuses=4}}),"Star: four weekly bonuses")
				assert(not A.earned("star",{stats={}}),"a save without the counter has earned none")
			end
		end)
	else skip("charm rule cases (no charm shape carries a rule in this build's catalogue)")end

	-- ── Optional lifetime counters ──────────────────────────────────────────
	test("weeklyBonuses counts only a paid weekly bonus claim; a save without the key is valid",function()
		local function state()return {nectar=10,inventoryMask=1,stats=L.freshStats(),stamps=0,book=L.freshBook()}end
		local function claim(signature,gain)
			local after=state();after.nectar+=gain
			L.record({nectar=10,inventoryMask=1},after,signature,1700000000)
			return after.stats.weeklyBonuses
		end
		assert(L.valid(state())and state().stats.weeklyBonuses==nil,"the key is optional, never required")
		assert(table.find(L.Counters,"weeklyBonuses")==nil and table.find(L.Counters,"itemWinKinds")==nil,"not in the required list")
		assert(claim("quest:weekly:2811:0",15)==1,"slot 0 of the weekly scope is the bonus")
		assert(claim("quest:weekly:2811:1",15)==nil,"a weekly quest is not the bonus")
		assert(claim("quest:daily:19675:0",15)==nil and claim("quest:daily:19675:1",15)==nil,"never a daily")
		assert(claim("quest:weekly:2811:0",0)==nil,"an unpaid write does not count")
		assert(claim("reroll:19675:0",5)==nil and claim("award:1:6:easy",5)==nil and claim(nil,5)==nil)
		local after=state();after.stats.weeklyBonuses=3;after.nectar+=15
		L.record({nectar=10,inventoryMask=1},after,"quest:weekly:2812:0",1700000000)
		assert(after.stats.weeklyBonuses==4 and after.stats.starsEarned==15 and L.valid(after),"it accumulates, and the save stays valid")
		local h,db=fixture()
		local kept=fixture(reseed(db,{stats=(function()local s=copy(db.player_1.hatching.stats);s.weeklyBonuses=7;s.itemWinKinds=5;return s end)()}))
		assert(kept.state.stats.weeklyBonuses==7 and kept.state.stats.itemWinKinds==5 and H.public(kept).stats.weeklyBonuses==7,"saved, loaded and published")
		assert(h.state.stats.weeklyBonuses==nil)
	end)

	test("item kinds: one bit per round item, OR-ed into itemWinKinds only on a win",function()
		assert(#Items.Order==4 and L.ItemKindsMask==15,"four item kinds today")
		local seen=0
		for index,id in ipairs(Items.Order)do
			assert(L.itemKindBit(id)==2^(index-1)and H.itemKindBit(id)==2^(index-1))
			seen+=L.itemKindBit(id)
		end
		assert(seen==15 and L.itemKindBit("nope")==0 and L.itemKindBit(nil)==0)
		local h=fixture()
		assert(H.award(h,1,6,summary(h,{itemKinds=5})))
		assert(h.state.stats.itemWinKinds==5)
		assert(H.award(h,2,0,summary(h,{success=false,goalsMet=0,itemKinds=10})))
		assert(h.state.stats.itemWinKinds==5,"a lost round's items do not count")
		assert(H.award(h,3,6,summary(h,{itemKinds=10})))
		assert(h.state.stats.itemWinKinds==15,"OR across wins")
		assert(H.award(h,4,6,summary(h,{itemKinds=0})))
		assert(H.award(h,5,6,summary(h)))
		assert(h.state.stats.itemWinKinds==15 and H.valid(h.state),"nothing ever clears it; a summary without the field is fine")
		if Book.DiscoveryById.win_each_item then assert(has(h.state.book.found,"win_each_item"),"all four kinds: the Discovery is found")end
	end)

	test("itemKinds out of range is InvalidSummary, never a failed save",function()
		local h=fixture()
		local wallet=h.state.nectar
		for _,bad in ipairs({16,-1,1.5,0/0,math.huge,"3",true,{}})do
			local ok,reason=H.award(h,1,6,summary(h,{itemKinds=bad}))
			assert(not ok and reason=="InvalidSummary","refuses itemKinds="..tostring(bad))
		end
		assert(h.state.nectar==wallet and h.pending==nil and h.state.lastAwardSeq==0)
		assert(H.award(h,1,6,summary(h,{itemKinds=15})),"the same round then saves with a valid mask")
	end)

	-- ── State-derived Discoveries ───────────────────────────────────────────
	if type(Book.stateBits)=="function"and Book.DiscoveryById.tidy_25 and Book.DiscoveryById.rounds_100 then
		test("a save that already qualifies earns its Discoveries on the next committed write",function()
			local _,db=fixture()
			local stats=copy(db.player_1.hatching.stats);stats.tidyWins=30;stats.rounds=120
			local h=fixture(reseed(db,{stats=stats}))
			assert(not has(h.state.book.found,"tidy_25")and not has(h.state.book.found,"rounds_100"),"loading alone writes nothing")
			assert(H.coachMark(h,1),"any small write")
			assert(has(h.state.book.found,"tidy_25")and has(h.state.book.found,"rounds_100"),"found on commit")
			assert(not has(h.state.book.found,"pet_night")and not has(h.state.book.found,"play_date"),"and nothing unearned")
			assert(H.valid(h.state))
		end)
	else skip("state Discoveries case (BookCatalog.stateBits or the tidy_25 / rounds_100 entries are not in this build)")end

	if type(Book.stateBits)=="function"and type(Book.isNight)=="function"and Book.DiscoveryById.pet_night then
		test("pet_night is set by a pet write at night, never by another write or a daytime pet",function()
			local night,day
			for hour=0,23 do
				local t=1700000000+hour*3600
				if Book.isNight(t)then night=night or t else day=day or t end
			end
			assert(night and day,"the sampled day has both")
			local h=fixture(nil,night)
			assert(H.awardPet(h,H.petCandidate(h,"lease-n","pip")))
			assert(has(h.state.book.found,"pet_night"),"petting at night finds it")
			local sunny=fixture(nil,day)
			assert(H.awardPet(sunny,H.petCandidate(sunny,"lease-d","pip")))
			assert(not has(sunny.state.book.found,"pet_night"),"a daytime pet does not")
			-- Whatever the catalogue returns, the host drops the bit for a write that is not a pet.
			local state=copy(fixture(nil,night).state)
			state.lastPetAward={id="x",sequence=state.operationSeq+1,day=H.public(fixture(nil,night)).dailyDay,petId="pip"}
			L.record({nectar=state.nectar,inventoryMask=state.inventoryMask},state,"wearable:abc",night)
			assert(not has(state.book.found,"pet_night"),"a purchase at night is not petting")
			L.record({nectar=state.nectar,inventoryMask=state.inventoryMask},state,"pet:abc",night)
			assert(has(state.book.found,"pet_night"))
		end)
	else skip("pet_night case (BookCatalog has no pet_night / isNight in this build)")end

	-- ── Toy pool ────────────────────────────────────────────────────────────
	test("toy pools: every pool is strictly ascending and pool 1 is kept",function()
		assert(Toys.Pools[1]~=nil and #Toys.Pools[1]==3,"stored receipts re-validate against pool 1")
		assert(Toys.Pools[Toys.PoolVersion]~=nil)
		for version,pool in pairs(Toys.Pools)do
			for index=2,#pool do assert(pool[index]>pool[index-1],"pool "..version.." must be sorted") end
			for _,id in ipairs(pool)do assert(Toys.known(id),id)end
		end
	end)

	if Toys.PoolVersion>1 then
		test("a new Toy Egg purchase quoting an old pool is LegacyPurchaseClosed; the current pool buys",function()
			local h=fixture()
			assert(H.grantPurchase(h,"fund-toys",40,false))
			local wallet,revision=h.state.nectar,h.state.revision
			local stale={id=revision..":toy-stale",catalogVersion=Toys.CatalogVersion,poolVersion=1,eligible=Toys.remaining(h.state.toyUnlocks,1)}
			local ok,reason=H.toyCommand(h,"toyBuy",stale,revision)
			assert(not ok and reason=="LegacyPurchaseClosed"and h.state.nectar==wallet and h.pending==nil,tostring(reason))
			local fresh={id=revision..":toy-fresh",catalogVersion=Toys.CatalogVersion,poolVersion=Toys.PoolVersion,eligible=Toys.remaining(h.state.toyUnlocks)}
			local bought,why=H.toyCommand(h,"toyBuy",fresh,revision)
			assert(bought,tostring(why))
			assert(h.state.nectar==wallet-Toys.Cost)
		end)
	else skip("stale toy pool case (ToyCatalog.PoolVersion is still 1)")end

	return cases
end
