-- Overnight 2026-11-14, slice E (SYSTEMS-SCOPE 1.3 / 1.7): the earned pet (Blip, collection
-- bit 0x80) is granted on the 7th lifetime stamp through Hatching.grantEarnedPet, gated by
-- EarnedPets.enabled. With the flag off nothing is owed or granted; with it on the grant is
-- idempotent (the ownership bit is the receipt), repairs late, counts in stats.pets, writes no
-- reveal receipt and blocks nothing. A save holding the bit always loads, flag on or off.
-- Isolated adapters only. `EarnedPets.enabled` is swapped inside each flag-on case and restored.
-- Usage (Server): require(ServerScriptService.Server.ZZSpecs.EarnedPet)(ServerScriptService.Server)
return function(server)
	local H=require(server.HatchProgress)
	local Session=require(server.SessionProfile)
	local Bond=require(server.BondState)
	local Shared=game:GetService("ReplicatedStorage").Shared
	local Earned=require(Shared.EarnedPets)
	local Pets=require(Shared.PetCatalog)
	local Eggs=require(Shared.EggCatalog)
	local Flags=require(Shared.FeatureFlags)
	local cases={}
	local BLIP=Eggs.bit("blip")
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
	-- Runs `body` with the gate open for Blip (as the week-1 update will have it), then restores.
	local function withBlip(body)
		local real=Earned.enabled
		Earned.enabled=function(petId)return petId=="blip"end
		local ok,problem=pcall(body)
		Earned.enabled=real
		if not ok then error(problem,0)end
	end
	local function summary(h,overrides)
		local s={family="pip",day=H.public(h).dailyDay,success=true,clean=false,score=100,chain=1,clears=0,drops=24,heat="easy",goalsMet=2}
		for k,v in pairs(overrides or {})do s[k]=v end
		return s
	end

	test("Blip is collection bit 0x80, outside the legacy rank array; the gate is flag AND rig",function()
		assert(BLIP==128 and Pets.byId.blip.index==8 and #Pets==4,"bit 8, never in the Pets rank array")
		assert(Earned.Rules.blip.stamps==7 and Earned.Order[1]=="blip")
		assert(Earned.enabled("pip")==false and Earned.enabled(nil)==false and Earned.enabled("nope")==false,"only earned pets pass the gate")
		if Flags.SecondPet~=true then assert(Earned.enabled("blip")==false,"flag off: never enabled")end
		assert(Pets.isActive("blip")==Earned.enabled("blip"),"Pets.active uses the same gate")
		assert(#Earned.owed(nil)==0 and #Earned.owed({})==0 and #Earned.owed({stamps="7",inventoryMask=1})==0,"owed tolerates junk")
	end)

	test("gate closed: nothing is owed at 7+ stamps and the grant is refused with no write",function()
		if Earned.enabled("blip")then return end -- the gate is open in this build: covered below
		local base,db=fixture()
		local h,_,c=fixture(reseed(db,{stamps=9}))
		assert(h.status=="Ready"and #Earned.owed(h.state)==0 and #Earned.owed(H.public(h))==0)
		local writes=c.writes
		local ok,reason=H.grantEarnedPet(h,"blip")
		assert(not ok and reason=="Disabled"and c.writes==writes and h.pending==nil,"Disabled, no write, nothing pending")
		assert(bit32.band(h.state.inventoryMask,BLIP)==0)
		local okBad,whyBad=H.grantEarnedPet(h,"pip");assert(not okBad and whyBad=="UnknownPet","only pets with a rule")
		local okNil,whyNil=H.grantEarnedPet(h,nil);assert(not okNil and whyNil=="UnknownPet")
		assert(base.status=="Ready")
	end)

	test("a save with bit 0x80 loads whatever the gate says; saves at or under 127 still load",function()
		local _,db=fixture()
		local with=fixture(reseed(db,{inventoryMask=1+BLIP}))
		assert(with.status=="Ready"and H.valid(with.state)and with.state.inventoryMask==129,"mask 129 is valid data")
		assert(fixture(reseed(db,{inventoryMask=255})).status=="Ready","every collection bit")
		assert(fixture(reseed(db,{inventoryMask=127})).status=="Ready"and fixture(reseed(db,{inventoryMask=1})).status=="Ready")
		assert(fixture(reseed(db,{inventoryMask=256})).status=="InvalidData","bit 9 is still out of range")
		-- Owned but not active in this build (flag off, or a rig removed by a rollback): the pet is
		-- never the companion, and nothing un-owns it.
		if not Pets.isActive("blip")then
			assert(not Session.usable(129,"blip")and Session.firstOwnedActive(129)=="pip"and Session.hasActivePet(129))
			assert(not Session.hasActivePet(BLIP)and Session.firstOwnedActive(BLIP)==nil,"an inactive pet alone unlocks nothing")
		end
		assert(Session.usable(1,"pip")and not Session.usable(1,"blip")and not Session.usable(1,nil))
		-- Retained legacy pets keep working as companions exactly as before.
		assert(Session.usable(Eggs.mask({"pip","foxfire_wick"}),"foxfire_wick"))
	end)

	test("the 7th stamp makes Blip owed; the grant saves once, counts a pet and writes no reveal",function()
		withBlip(function()
			local _,db=fixture()
			-- Six stamps, and today's gift not claimed yet (the last claim was yesterday).
			local yesterday=tostring(tonumber(db.player_1.hatching.dailyClaimDay)-1)
			local h,db2,c=fixture(reseed(db,{stamps=6,dailyClaimDay=yesterday}))
			assert(#Earned.owed(h.state)==0)
			local okEarly,whyEarly=H.grantEarnedPet(h,"blip")
			assert(not okEarly and whyEarly=="NotEarned"and h.pending==nil,"6 stamps: not yet")
			assert(H.command(h,"daily",H.public(h).dailyDay,h.state.revision))
			assert(h.state.stamps==7 and Earned.owed(h.state)[1]=="blip"and Earned.owed(H.public(h))[1]=="blip","owed from the save and from the snapshot")
			local pets,wallet=h.state.stats.pets,h.state.nectar
			local ok,reason=H.grantEarnedPet(h,"blip")
			assert(ok and reason=="Saved",tostring(reason))
			assert(bit32.band(h.state.inventoryMask,BLIP)==BLIP and db2.player_1.hatching.inventoryMask==h.state.inventoryMask)
			assert(h.state.stats.pets==pets+1,"stats.pets counts the new bit")
			assert(h.state.lastHatch==nil and h.state.nectar==wallet,"no reveal receipt, no Stars")
			assert(#Earned.owed(h.state)==0 and H.valid(h.state))
			local writes=c.writes
			local again,why=H.grantEarnedPet(h,"blip")
			assert(again and why=="AlreadyOwned"and c.writes==writes and h.state.stats.pets==pets+1,"a replay is a success with no write")
			-- Nothing is blocked behind a reveal: rounds, petting and the daily gift still save.
			assert(H.award(h,1,6,summary(h)))
			assert(H.awardPet(h,H.petCandidate(h,"lease-1","pip")))
			assert(H.awardPet(h,H.petCandidate(h,"lease-2","blip")),"the new pet can be petted at once")
			-- Per-pet namespaces accept the pet now that it is owned.
			assert(Bond.xp(h.state,"blip")==Bond.XP.pet,"and earns bond XP like any owned pet")
			local probe=copy(h.state);Bond.add(probe,"blip",1);assert(probe.bond.blip==Bond.XP.pet+1 and H.valid(probe))
		end)
	end)

	test("an ambiguous grant write resumes and commits exactly once",function()
		withBlip(function()
			local _,db=fixture()
			local h,db2,c=fixture(reseed(db,{stamps=7}))
			local pets=h.state.stats.pets
			c.failNext="after"
			local ok,reason=H.grantEarnedPet(h,"blip")
			assert(not ok and reason=="Retrying"and h.pending and h.pending.signature=="earnedpet:blip")
			assert(bit32.band(db2.player_1.hatching.inventoryMask,BLIP)==BLIP,"the write landed")
			assert(H.retry(h))
			assert(h.pending==nil and h.state.stats.pets==pets+1 and bit32.band(h.state.inventoryMask,BLIP)==BLIP)
			-- A write that never landed is retried from the same pending operation.
			local h2,db3,c2=fixture(reseed(db,{stamps=7}))
			c2.failNext="before"
			local ok2,reason2=H.grantEarnedPet(h2,"blip")
			assert(not ok2 and reason2=="Retrying"and bit32.band(db3.player_1.hatching.inventoryMask,BLIP)==0)
			local ok3,reason3=H.grantEarnedPet(h2,"blip")
			assert(ok3 and reason3=="Saved"and h2.state.stats.pets==pets+1,"the host loop calling again resumes it")
		end)
	end)

	test("repair: a save already past the rule is granted on a later join, once across servers",function()
		withBlip(function()
			local _,db=fixture()
			local h,db2=fixture(reseed(db,{stamps=9}))
			assert(Earned.owed(h.state)[1]=="blip")
			assert(H.grantEarnedPet(h,"blip"))
			-- A second server loading the same save sees it owned: nothing owed, no second count.
			local pets=h.state.stats.pets
			local other,_,c=fixture(reseed(db2,{}))
			assert(other.status=="Ready"and #Earned.owed(other.state)==0)
			local writes=c.writes
			local ok,reason=H.grantEarnedPet(other,"blip")
			assert(ok and reason=="AlreadyOwned"and c.writes==writes and other.state.stats.pets==pets)
		end)
	end)

	test("flag, rule and ownership are re-checked inside the write",function()
		local _,db=fixture()
		local h,_,c
		withBlip(function()
			h,_,c=fixture(reseed(db,{stamps=7}))
			c.failNext="before"
			local ok,reason=H.grantEarnedPet(h,"blip")
			assert(not ok and reason=="Retrying"and h.pending)
		end)
		if Earned.enabled("blip")then return end
		-- The gate closed while the write was pending (as if the flag were turned off): refused.
		local ok,reason=H.retry(h)
		assert(not ok and reason=="Disabled"and h.pending==nil and bit32.band(h.state.inventoryMask,BLIP)==0)
	end)

	return cases
end
