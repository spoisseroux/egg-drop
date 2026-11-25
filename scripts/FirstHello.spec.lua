-- G2 (G2-FIRST-SESSION-LOOK 2026-11-25 section 1b): the first hello. The first paid pet on a brand-new save pays +2
-- on top of its +1, once per save, ever: paid and saved (`firstHello`, receipt `lastPetAward.hello`) inside the
-- petting award transaction, so a retry, an ambiguous write or a rejoin never pays twice; an existing save (a pet
-- already paid, or a field round saved) gets nothing; a malformed field never fails a load. Isolated adapters only.
-- Usage (Server): require(ServerScriptService.Server.ZZSpecs.FirstHello)(ServerScriptService.Server)
-- Offline: the growth harness (see artifacts/growth-2026-11-26/G2-PLAN.md, Verification).
return function(server)
	local H=require(server.HatchProgress)
	local Shared=game:GetService("ReplicatedStorage").Shared
	local Hello=require(Shared.FirstHello)
	local Flags=require(Shared.FeatureFlags)
	local cases={}
	local function copy(v)if type(v)~="table"then return v end;local r={};for k,x in pairs(v)do r[k]=copy(x)end;return r end
	local function test(name,run)run();table.insert(cases,name)end
	-- hello: true opts this adapter in, as the live one does (defaultAdapter); nil keeps every old spec's +1.
	local fixtures=0
	local function fixture(seed,hello)
		fixtures+=1
		local db,c={},{now=1700000000,serial=0,writes=0,failNext=nil,prefix="h"..fixtures.."op"}
		local adapter={
			now=function()return c.now end,
			guid=function()c.serial+=1;return c.prefix..c.serial end,
			random=function()return .1 end,
			wait=function()end,
			firstHello=if hello==false then nil else true,
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
		return h,db,c,adapter
	end
	local function reseed(db,changes)
		local seed=copy(db.player_1)
		for k,v in pairs(changes)do seed.hatching[k]=v end
		seed.hatching.lease={token="",expiresAt=0}
		return seed
	end
	local function pet(h)return H.awardPet(h,H.petCandidate(h,"lease","pip"))end

	test("the switch is on for the live build and the hello is +2 (+3 with the pet)",function()
		assert(Flags.FirstHelloBonus==true and Hello.Bonus==2 and Hello.Stored==255)
	end)

	test("pure rules: due only on a save that has never been paid for a pet nor saved a field round",function()
		assert(Hello.due({stats={rounds=0},lastAwardSeq=0}),"a new save")
		assert(not Hello.due({stats={rounds=0},lastAwardSeq=0,firstHello=2}),"paid")
		assert(not Hello.due({stats={rounds=0},lastAwardSeq=0,firstHello=0}),"any present value is done")
		assert(not Hello.due({stats={rounds=0},lastAwardSeq=0,lastPetAward={id="x"}}),"petted before")
		assert(not Hello.due({stats={rounds=3},lastAwardSeq=3}),"rounds saved")
		assert(not Hello.due({stats={rounds=0},lastAwardSeq=2}),"a pre-v11 save whose counters started at 0")
		assert(not Hello.due({})and not Hello.due(nil)and not Hello.due({lastAwardSeq=0}))
		assert(Hello.valid({})and Hello.valid({firstHello=0})and Hello.valid({firstHello=2})and Hello.valid({firstHello=255}))
		for _,bad in ipairs({-1,1.5,256,"2",true,{},0/0})do
			assert(not Hello.valid({firstHello=bad}),"invalid: "..tostring(bad))
			assert(Hello.sanitize(bad)==nil)
		end
		local s={stats={rounds=0},lastAwardSeq=0}
		assert(Hello.apply(s)==2 and s.firstHello==2 and Hello.apply(s)==0 and s.firstHello==2,"once")
		local old={stats={rounds=5},lastAwardSeq=5}
		assert(Hello.apply(old)==0 and old.firstHello==nil,"an ineligible save gets no field written")
	end)

	test("a new save: the first pet pays 3 with the receipt's hello, the next pays 1; one of the day's pets",function()
		local h=fixture()
		assert(h.status=="Ready"and h.state.firstHello==nil and h.state.lastPetAward==nil)
		local w=h.state.nectar
		assert(pet(h))
		assert(h.state.nectar==w+3 and h.state.firstHello==2 and h.state.lastPetAward.hello==2 and h.state.petCount==1)
		assert(H.valid(h.state),"the saved state validates")
		w=h.state.nectar
		assert(pet(h))
		assert(h.state.nectar==w+1 and h.state.lastPetAward.hello==nil and h.state.firstHello==2 and h.state.petCount==2)
		assert(h.state.stats.starsEarned>=4,"the hello counts as earned")
	end)

	test("one payout: a repeat, a lost response and a failed write never pay twice",function()
		local h,db,c=fixture()
		local w=h.state.nectar
		local candidate=H.petCandidate(h,"lease","pip")
		c.failNext="after"
		local ok=H.awardPet(h,candidate)
		assert(not ok and h.pending~=nil,"the response was lost")
		assert(db.player_1.hatching.firstHello==2,"the write landed")
		assert(H.retry(h))
		assert(h.state.nectar==w+3 and h.state.firstHello==2,"proved, not paid again")
		local again,why=H.awardPet(h,candidate)
		assert(again and why=="AlreadySaved"and h.state.nectar==w+3,"a repeat of the same award")
		-- A fresh save whose first write fails before the store: the resumed award pays the hello once.
		local f,fdb,fc=fixture()
		local fw=f.state.nectar
		local p=H.petCandidate(f,"lease","pip")
		fc.failNext="before"
		assert(not H.awardPet(f,p)and f.pending~=nil and fdb.player_1.hatching.firstHello==nil)
		assert(H.awardPet(f,p),"the same pending award resumes")
		assert(f.state.nectar==fw+3 and f.state.firstHello==2)
		assert(pet(f)and f.state.nectar==fw+4,"then +1")
	end)

	test("a rejoin (or another server) reads the saved field: never a second hello",function()
		local h,db=fixture()
		assert(pet(h))
		local again=fixture(reseed(db,{}))
		assert(again.status=="Ready"and again.state.firstHello==2)
		local w=again.state.nectar
		assert(pet(again)and again.state.nectar==w+1)
	end)

	test("existing saves get nothing and no field is written: a pet already paid, or a field round saved",function()
		local h,db=fixture(nil,false)
		local w=h.state.nectar
		assert(pet(h)and h.state.nectar==w+1 and h.state.firstHello==nil and h.state.lastPetAward.hello==nil,"adapter off: today's +1")
		local live=fixture(reseed(db,{}))
		w=live.state.nectar
		assert(pet(live)and live.state.nectar==w+1 and live.state.firstHello==nil,"petted before (on an old server)")
		local played,pdb=fixture(nil,false)
		assert(H.award(played,1,6,{family="pip",day=H.public(played).dailyDay,success=true,clean=false,score=100,chain=1,clears=0,drops=24,heat="medium",goalsMet=2}))
		local later=fixture(reseed(pdb,{}))
		assert(later.state.stats.rounds==1 and later.state.lastPetAward==nil)
		w=later.state.nectar
		assert(pet(later)and later.state.nectar==w+1 and later.state.firstHello==nil,"a field round saved")
	end)

	test("a malformed firstHello is dropped at load, never a failed load; the save is then done (a pet was paid)",function()
		local h,db=fixture()
		assert(pet(h))
		for _,bad in ipairs({"x",-1,1.5,256,{1},true})do
			local again=fixture(reseed(db,{firstHello=bad}))
			assert(again.status=="Ready","load survives firstHello="..tostring(bad))
			assert(again.state.firstHello==nil and H.valid(again.state))
			local w=again.state.nectar
			assert(pet(again)and again.state.nectar==w+1,"no second hello")
		end
		local later=fixture(reseed(db,{firstHello=9}))
		assert(later.status=="Ready"and later.state.firstHello==9,"a later build's value is kept")
	end)

	test("an old server's rules accept the new fields: v10 and v11 validation read named keys only",function()
		local h=fixture()
		assert(pet(h))
		local s=copy(h.state)
		assert(s.firstHello==2 and s.lastPetAward.hello==2 and H.valid(s))
		s.firstHello=nil
		assert(H.valid(s),"the receipt's extra key alone is valid (what a v1056 server writes over it)")
	end)

	return {passed=#cases,cases=cases}
end
