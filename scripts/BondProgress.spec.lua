-- Overnight 2026-11-14, slice F server (SYSTEMS-SCOPE 5.1 / 5.2 / 5.5): bond XP per pet in the
-- optional `bond` field (missing is valid, malformed is repaired at load, no version bump).
-- XP comes only from writes that already exist: +1 per paid pet, +2 / +3 for a saved round
-- with the pet as companion, +5 when today's Play date completes. XP never makes one of those
-- writes fail, counts once across an ambiguous write, is per pet and stops at MaxXP.
-- Isolated adapters only.
-- Usage (Server): require(ServerScriptService.Server.ZZSpecs.BondProgress)(ServerScriptService.Server)
return function(server)
	local H=require(server.HatchProgress)
	local Bond=require(server.BondState)
	local PlayDate=require(server.PlayDateState)
	local Shared=game:GetService("ReplicatedStorage").Shared
	local Eggs=require(Shared.EggCatalog)
	local cases={}
	local XP=Bond.XP
	local function copy(v)if type(v)~="table"then return v end;local r={};for k,x in pairs(v)do r[k]=copy(x)end;return r end
	local function test(name,run)run();table.insert(cases,name)end
	local function fixture(seed,profile)
		local db,c={},{now=1700000000,serial=0,writes=0,failNext=nil}
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
		local h=H.load(1,profile or {rank=1},adapter)
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
	local function pet(h,petId)
		return H.awardPet(h,H.petCandidate(h,"lease-"..h.state.operationSeq,petId or "pip"))
	end
	local function bond(h,petId)return(h.state.bond or {})[petId or "pip"]or 0 end

	test("the numbers: pet 1, round 2, win 3, Play date 5; XP caps at 100000",function()
		assert(XP.pet==1 and XP.round==2 and XP.win==3 and XP.playDate==5,"[PLACEHOLDER] numbers from the scope")
		assert(Bond.MaxXP==100000 and Bond.Limit==16)
	end)

	test("no bond field is valid and reads {}; a malformed one is repaired at load, never a failed load",function()
		local h,db=fixture()
		assert(h.status=="Ready"and h.state.bond==nil and H.valid(h.state))
		assert(next(H.public(h).bond)==nil,"public.bond is {} when missing")
		for _,bad in ipairs({"x",5,true,{pip=-1},{pip=1.5},{pip="3"},{nope=3},{pip=0/0},{[1]=4}})do
			local again=fixture(reseed(db,{bond=bad}))
			assert(again.status=="Ready","load survives a malformed bond")
			assert(H.valid(again.state)and bond(again)==0,"bad entries are dropped")
		end
		local mixed=fixture(reseed(db,{bond={pip=40,nope=3,puddle=7}}))
		assert(mixed.status=="Ready"and mixed.state.bond.pip==40 and mixed.state.bond.nope==nil,"good entries survive beside bad ones")
		assert(mixed.state.bond.puddle==7,"an entry needs no ownership check: XP is only ever written for an owned pet")
		local over=fixture(reseed(db,{bond={pip=Bond.MaxXP+500}}))
		assert(over.status=="Ready"and over.state.bond.pip==Bond.MaxXP,"over the cap is clamped")
		assert(Bond.valid({})and Bond.valid({bond={}})and Bond.valid({bond={pip=0}})and not Bond.valid({bond={pip=-1}})
			and not Bond.valid({bond={nope=1}})and not Bond.valid({bond=3})and not Bond.valid({bond={pip=Bond.MaxXP+1}}))
	end)

	test("+1 per paid pet, capped by the daily petting cap",function()
		local h=fixture()
		assert(pet(h))
		assert(bond(h)==XP.pet and H.public(h).bond.pip==XP.pet)
		for _=2,H.PetDailyCap do assert(pet(h))end
		assert(bond(h)==H.PetDailyCap*XP.pet)
		local ok,reason=pet(h)
		assert(not ok and reason=="PetCap"and bond(h)==H.PetDailyCap*XP.pet,"no XP past the cap")
		assert(H.valid(h.state))
	end)

	test("a saved round gives the companion +2, or +3 on a win, in the award write",function()
		local h=fixture()
		local wallet=h.state.nectar
		assert(H.award(h,1,6,summary(h),nil,"pip"))
		assert(bond(h)==XP.win and h.state.nectar>wallet,"a win: +3 with the payout")
		assert(H.award(h,2,0,summary(h,{success=false,goalsMet=0}),nil,"pip"))
		assert(bond(h)==XP.win+XP.round,"a finished miss: +2")
		assert(H.award(h,3,8,summary(h,{clean=true}),{multiplier=2,bonus=1,petId="pip"}))
		assert(bond(h)==2*XP.win+XP.round,"the companion may ride in the boost table (close drain)")
		local ok,reason=H.award(h,3,8,summary(h,{clean=true}),nil,"pip")
		assert(ok and reason=="AlreadyAwarded"and bond(h)==2*XP.win+XP.round,"one round, one gain")
		assert(H.award(h,4,6,summary(h)))
		assert(bond(h)==2*XP.win+XP.round,"no companion named: no XP, the award still pays")
		assert(H.award(h,5,0,nil,nil,"pip"))
		assert(bond(h)==2*XP.win+XP.round,"a round with no summary earns nothing")
	end)

	test("an unowned or unknown companion earns nothing and never fails the award",function()
		local h=fixture()
		for index,petId in ipairs({"puddle","blip","nope","",false,12,{}})do
			local wallet=h.state.nectar
			local ok,reason=H.award(h,index,6,summary(h),nil,petId)
			assert(ok,"award "..index.." refused: "..tostring(reason))
			assert(h.state.nectar>wallet and h.state.bond==nil,"paid, no XP")
		end
		assert(H.valid(h.state))
	end)

	test("XP is per pet",function()
		local h=fixture(nil,{rank=2})
		assert(Eggs.isOwned(h.state.inventoryMask,"puddle"))
		assert(H.award(h,1,6,summary(h),nil,"puddle"))
		assert(bond(h,"puddle")==XP.win and bond(h,"pip")==0)
		assert(pet(h,"pip"))
		assert(bond(h,"pip")==XP.pet and bond(h,"puddle")==XP.win)
	end)

	test("an ambiguous award or pet write counts its XP exactly once",function()
		local h,db,c=fixture()
		c.failNext="after"
		local ok,reason=H.award(h,1,6,summary(h),nil,"pip")
		assert(not ok and reason=="Retrying"and db.player_1.hatching.bond.pip==XP.win,"the write landed")
		assert(H.retry(h))
		assert(bond(h)==XP.win,"not counted again")
		local candidate=H.petCandidate(h,"lease-x","pip")
		c.failNext="after"
		local okPet,whyPet=H.awardPet(h,candidate)
		assert(not okPet and whyPet=="Retrying")
		assert(H.awardPet(h,candidate))
		assert(bond(h)==XP.win+XP.pet)
		-- A write that never landed adds nothing until its retry commits.
		c.failNext="before"
		assert(not H.award(h,2,6,summary(h),nil,"pip"))
		assert(db.player_1.hatching.bond.pip==XP.win+XP.pet)
		assert(H.retry(h))
		assert(bond(h)==2*XP.win+XP.pet)
	end)

	test("Play date: +5 once, in the write that completes it",function()
		local h=fixture()
		assert(H.parkPlay(h,"park-1",PlayDate.Target-1,"pip"))
		assert(bond(h)==0,"not complete yet")
		assert(H.parkPlay(h,"park-2",1,"pip"))
		assert(bond(h)==XP.playDate and H.playDateDone(h),"the crossing write pays")
		assert(H.parkPlay(h,"park-3",2,"pip"))
		assert(bond(h)==XP.playDate,"more play the same day adds nothing")
		local again,why=H.parkPlay(h,"park-3",2,"pip")
		assert(again and why=="AlreadySaved"and bond(h)==XP.playDate)
		-- No companion named, or one the player does not own: the park write still saves.
		local other=fixture()
		assert(H.parkPlay(other,"park-a",PlayDate.Target))
		assert(other.state.bond==nil and H.playDateDone(other))
		local third=fixture()
		assert(H.parkPlay(third,"park-b",PlayDate.Target,"puddle"))
		assert(third.state.bond==nil and H.playDateDone(third))
	end)

	test("XP stops at MaxXP and a full bond never fails a write",function()
		local _,db=fixture()
		local h=fixture(reseed(db,{bond={pip=Bond.MaxXP-1}}))
		assert(H.award(h,1,6,summary(h),nil,"pip"))
		assert(bond(h)==Bond.MaxXP and H.valid(h.state))
		assert(pet(h)and bond(h)==Bond.MaxXP)
		assert(H.parkPlay(h,"park-max",PlayDate.Target,"pip")and bond(h)==Bond.MaxXP)
	end)

	test("BondState.add is a no-op for bad input and repairs a malformed field in place",function()
		local state={inventoryMask=1}
		for _,gain in ipairs({0,-3,0/0,math.huge,"2"})do Bond.add(state,"pip",gain)end
		Bond.add(state,"puddle",2);Bond.add(state,"nope",2);Bond.add(state,nil,2);Bond.add(nil,"pip",2)
		assert(state.bond==nil,"nothing written")
		state.bond={pip="x",nope=4}
		Bond.add(state,"pip",2.9)
		assert(state.bond.pip==2 and state.bond.nope==nil and Bond.valid(state),"floored, and the field is clean afterwards")
		assert(Bond.xp(state,"pip")==2 and Bond.xp(state,"puddle")==0 and Bond.xp(nil,"pip")==0)
	end)

	return cases
end
