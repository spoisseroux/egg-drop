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

	-- v2 Bunny (2026-11-19): the earned slot can also be adopted at once for a fixed Star price
	-- (Hatching.adoptPet). Idempotent by the operation id, never charges an owner, and races the
	-- 7th-stamp grant without ever charging for a pet the grant gave free.
	local PRICE=Earned.Rules.blip.stars
	test("adopt: the price is fixed at 400 Stars and refused below it with no write",function()
		assert(PRICE==400 and Pets.byId.blip.name=="Bunny"and Pets.byId.blip.favouriteStat=="jump")
		withBlip(function()
			local _,db=fixture()
			local h,db2,c=fixture(reseed(db,{nectar=PRICE-1,stamps=2}))
			local writes=c.writes
			local ok,reason=H.adoptPet(h,"adopt-1","blip",PRICE)
			assert(not ok and reason=="NotEnoughStars"and c.writes==writes and h.pending==nil,tostring(reason))
			assert(h.state.nectar==PRICE-1 and bit32.band(h.state.inventoryMask,BLIP)==0 and db2.player_1.hatching.nectar==PRICE-1)
			-- The client never sets the price, and junk never reaches the store.
			local h2,_,c2=fixture(reseed(db,{nectar=1000}))
			local w2=c2.writes
			local okP,whyP=H.adoptPet(h2,"adopt-2","blip",1);assert(not okP and whyP=="PriceChanged","a lower price is refused")
			local okH,whyH=H.adoptPet(h2,"adopt-3","blip",PRICE+1);assert(not okH and whyH=="PriceChanged","any other price is refused")
			for _,args in ipairs({{nil,"blip",PRICE},{"","blip",PRICE},{string.rep("x",81),"blip",PRICE},{"a","pip",PRICE},{"a","nope",PRICE},{"a",nil,PRICE}})do
				local okJ,whyJ=H.adoptPet(h2,args[1],args[2],args[3]);assert(not okJ and whyJ=="InvalidAdopt",tostring(whyJ))
			end
			local okN,whyN=H.adoptPet(h2,"adopt-4","blip",nil);assert(not okN and whyN=="PriceChanged")
			assert(c2.writes==w2 and h2.state.nectar==1000 and h2.pending==nil)
		end)
	end)

	test("adopt: 400 Stars buys the pet once; any replay is AlreadyOwned with no charge",function()
		withBlip(function()
			local _,db=fixture()
			local h,db2,c=fixture(reseed(db,{nectar=PRICE+50,stamps=3}))
			local pets=h.state.stats.pets
			local ok,reason=H.adoptPet(h,"adopt-1","blip",PRICE)
			assert(ok and reason=="Saved",tostring(reason))
			assert(h.state.nectar==50 and db2.player_1.hatching.nectar==50,"exactly 400 Stars")
			assert(bit32.band(h.state.inventoryMask,BLIP)==BLIP and bit32.band(db2.player_1.hatching.inventoryMask,BLIP)==BLIP)
			assert(h.state.stats.pets==pets+1 and h.state.lastHatch==nil and H.valid(h.state),"counts a pet, writes no reveal")
			assert(#Earned.owed(h.state)==0,"nothing owed once owned")
			local writes=c.writes
			local again,why=H.adoptPet(h,"adopt-1","blip",PRICE)
			assert(again and why=="AlreadyOwned"and c.writes==writes and h.state.nectar==50,"same id: no write, no charge")
			local other,why2=H.adoptPet(h,"adopt-2","blip",PRICE)
			assert(other and why2=="AlreadyOwned"and c.writes==writes and h.state.nectar==50,"new id: still no charge")
			-- The 7th stamp later grants nothing more (the bit is the receipt).
			local okG,whyG=H.grantEarnedPet(h,"blip")
			assert(okG and whyG=="AlreadyOwned"and h.state.stats.pets==pets+1)
			-- A second server loading the save agrees: owned, nothing charged.
			local h2,_,c2=fixture(reseed(db2,{}))
			local w2=c2.writes
			local ok3,why3=H.adoptPet(h2,"adopt-9","blip",PRICE)
			assert(ok3 and why3=="AlreadyOwned"and c2.writes==w2 and h2.state.nectar==50)
		end)
	end)

	test("adopt: an ambiguous write resumes by its id and charges exactly once",function()
		withBlip(function()
			local _,db=fixture()
			local h,db2,c=fixture(reseed(db,{nectar=PRICE}))
			c.failNext="after"
			local ok,reason=H.adoptPet(h,"adopt-1","blip",PRICE)
			assert(not ok and reason=="Retrying"and h.pending and h.pending.signature=="adopt:adopt-1")
			assert(db2.player_1.hatching.nectar==0,"the write landed")
			-- The pending id is bound to its pet and price.
			local okC,whyC=H.adoptPet(h,"adopt-1","blip",PRICE-100);assert(not okC and whyC=="OperationConflict")
			local okO,whyO=H.adoptPet(h,"adopt-2","blip",PRICE);assert(not okO and whyO=="Pending","another id waits")
			local ok2,reason2=H.adoptPet(h,"adopt-1","blip",PRICE)
			assert(ok2 and reason2=="Saved"and h.pending==nil and h.state.nectar==0 and db2.player_1.hatching.nectar==0,tostring(reason2))
			-- A write that never landed is retried from the same operation.
			local h3,db3,c3=fixture(reseed(db,{nectar=PRICE}))
			c3.failNext="before"
			local ok4,reason4=H.adoptPet(h3,"adopt-7","blip",PRICE)
			assert(not ok4 and reason4=="Retrying"and db3.player_1.hatching.nectar==PRICE)
			assert(H.retry(h3))
			assert(h3.state.nectar==0 and db3.player_1.hatching.nectar==0 and bit32.band(h3.state.inventoryMask,BLIP)==BLIP)
		end)
	end)

	test("adopt never charges a save that has earned the pet; it races the grant without a double spend",function()
		withBlip(function()
			local _,db=fixture()
			-- 7 stamps, grant not run yet (the loop waits for a quiet window): the adopt is the free grant.
			local h0,db0,c0=fixture(reseed(db,{nectar=1000,stamps=7}))
			local pets=h0.state.stats.pets
			local ok0,why0=H.adoptPet(h0,"adopt-0","blip",PRICE)
			assert(ok0 and why0=="EarnedFree",tostring(why0))
			assert(h0.state.nectar==1000 and db0.player_1.hatching.nectar==1000 and bit32.band(h0.state.inventoryMask,BLIP)==BLIP,"free, no Stars")
			assert(h0.state.stats.pets==pets+1)
			local w0=c0.writes
			local again,whyAgain=H.adoptPet(h0,"adopt-0","blip",PRICE)
			assert(again and whyAgain=="AlreadyOwned"and c0.writes==w0)
			-- The free grant is mid-write when the adopt arrives: the adopt resumes it, costs nothing.
			local h,db2,c=fixture(reseed(db,{nectar=PRICE+100,stamps=7}))
			c.failNext="after"
			local okG,whyG=H.grantEarnedPet(h,"blip")
			assert(not okG and whyG=="Retrying"and h.pending)
			local ok,why=H.adoptPet(h,"adopt-1","blip",PRICE)
			assert(ok and why=="EarnedFree"and h.pending==nil,tostring(why))
			assert(h.state.nectar==PRICE+100 and db2.player_1.hatching.nectar==PRICE+100,"free pet, no charge")
			assert(h.state.stats.pets==pets+1,"counted once")
			-- Bought at 6 stamps and still mid-write when the grant loop runs: the grant waits, then
			-- adds nothing; the 400 Stars are spent exactly once.
			local h3,db3,c3=fixture(reseed(db,{nectar=PRICE+100,stamps=6}))
			c3.failNext="after"
			local ok3,why3=H.adoptPet(h3,"adopt-2","blip",PRICE)
			assert(not ok3 and why3=="Retrying")
			local okG2,whyG2=H.grantEarnedPet(h3,"blip")
			assert(not okG2 and(whyG2=="Pending"or whyG2=="NotEarned"),tostring(whyG2))
			assert(H.retry(h3))
			local okG3,whyG3=H.grantEarnedPet(h3,"blip")
			assert(okG3 and whyG3=="AlreadyOwned"and h3.state.nectar==100 and db3.player_1.hatching.nectar==100,"charged once")
			assert(h3.state.stats.pets==pets+1)
			-- Owned inside the write (the grant committed after the local check): refused in the
			-- write as AlreadyOwned, so the debit never commits.
			local h4,db4=fixture(reseed(db,{nectar=PRICE,stamps=2}))
			local root=db4.player_1.hatching
			root.inventoryMask=bit32.bor(root.inventoryMask,BLIP)
			local ok5,why5=H.adoptPet(h4,"adopt-3","blip",PRICE)
			assert(ok5==true and why5=="AlreadyOwned",tostring(why5))
			assert(db4.player_1.hatching.nectar==PRICE,"no debit was written")
			-- Earned inside the write (the 7th stamp saved after the local check): no debit either.
			local h5,db5=fixture(reseed(db,{nectar=PRICE,stamps=6}))
			db5.player_1.hatching.stamps=7
			local ok6,why6=H.adoptPet(h5,"adopt-4","blip",PRICE)
			assert(db5.player_1.hatching.nectar==PRICE and bit32.band(db5.player_1.hatching.inventoryMask,BLIP)==0,"no debit for an earned pet: "..tostring(ok6).." "..tostring(why6))
		end)
	end)
	return cases
end
