-- Isolated adapters only. Supply a fresh server module namespace, never cached v3.
return function(server)
	local H=require(server.HatchProgress);local Close=require(server.CloseProgress)
	assert(type(H.awardPet)=="function","Fresh v4 HatchProgress required")
	local cases={}
	local function copy(v)if type(v)~="table"then return v end;local r={};for k,x in pairs(v)do r[k]=copy(x)end;return r end
	local function test(name,run)run();table.insert(cases,name)end
	local function fixture(now)
		local db,c={}, {now=now or 1700000000,serial=0,writes=0,rolls=0}
		local function adapter(label)
			return{now=function()return c.now end,guid=function()c.serial+=1;return label..c.serial end,
				random=function()c.rolls+=1;return .1 end,wait=function()end,update=function(key,transform)
					c.writes+=1
					if c.failBefore then c.failBefore=false;error("fixture before commit")end
					if c.before then local f=c.before;c.before=nil;f()end
					local value=transform(copy(db[key]));if c.replay then value=transform(copy(db[key]))end
					if value then db[key]=copy(value)end
					if c.failAfter then c.failAfter=false;error("fixture after commit")end
					return copy(value)
				end}
		end
		local h=H.load(1,{rank=1},adapter("a"));assert(h.status=="Ready"and h.state.version==11)
		return h,db,c,adapter
	end
	local function candidate(h)return H.petCandidate(h,"server-lease","pip")end
	test("one exact pet operation adds one once, independent of field reward and hatch state",function()
		local h,db,c=fixture();c.replay=true;local before=h.state.nectar;local p=candidate(h)
		assert(H.awardPet(h,p)and h.state.nectar==before+1 and h.state.petCount==1)
		assert(h.state.lastPetAward.id==p.id and h.state.lastPetAward.sequence==h.state.operationSeq)
		local writes=c.writes;assert(H.awardPet(h,p)and c.writes==writes and c.rolls==0)
		assert(h.state.lastAwardSeq==0 and h.state.lastRunReward==nil and h.state.lastHatch==nil)
		assert(db.player_1.hatching.nectar==before+1)
	end)
	test("four to five is atomic and further candidates do no storage work",function()
		local h,_,c=fixture();for _=1,4 do assert(H.awardPet(h,candidate(h)))end
		assert(h.state.petCount==4);assert(H.awardPet(h,candidate(h))and h.state.petCount==5)
		local writes,balance=c.writes,h.state.nectar
		assert(not H.awardPet(h,candidate(h))and c.writes==writes and h.state.nectar==balance)
	end)
	test("immutable captured candidate survives mutation and repeated store callbacks",function()
		local h,_,c=fixture();local p=copy(candidate(h));local expected=p.id;c.replay=true
		c.before=function()p.petId="wick";p.day="0";p.id="changed";p.sequence=999 end
		assert(H.awardPet(h,p)and h.state.lastPetAward.id==expected and h.state.lastPetAward.petId=="pip")
	end)
	test("forged amount unknown pet and missing lease are rejected before a write",function()
		local h,_,c=fixture();local writes=c.writes
		local p=copy(candidate(h));p.amount=999;assert(not H.awardPet(h,p))
		p=copy(candidate(h));p.petId="unknown";assert(not H.awardPet(h,p))
		p=copy(candidate(h));p.leaseId=nil;assert(not H.awardPet(h,p))
		p=copy(candidate(h));p.petId="wick";assert(not H.awardPet(h,p))
		assert(c.writes==writes)
	end)
	test("commit-before-error is proved by exact receipt before midnight expiry",function()
		local h,db,c=fixture(18000+86400*20+86399.5);local p=candidate(h);c.failAfter=true
		assert(not H.awardPet(h,p)and h.status=="Retrying"and h.pending.id==p.id)
		assert(db.player_1.hatching.lastPetAward.id==p.id);c.now+=1
		assert(H.retry(h)and h.status=="Ready"and not h.pending and h.state.petCount==1)
		assert(h.state.petDay=="20"and h.state.nectar==7)
	end)
	test("precommit midnight expiry clears only proved noncommit and restores Ready",function()
		local h,_,c=fixture(18000+86400*20+86399.5);local p=candidate(h);c.failBefore=true
		assert(not H.awardPet(h,p)and h.pending.id==p.id);c.now+=1
		local ok,reason=H.retry(h)
		assert(not ok and reason=="ExpiredDay"and h.status=="Ready"and h.pending==nil)
		assert(h.state.petCount==0 and h.state.nectar==6 and h.state.lastPetAward==nil)
		assert(H.renew(h)and h.status=="Ready")
	end)
	test("a newer day resets allowance only in its admitted award; rollback never resets it",function()
		local h,db,c,adapter=fixture();for _=1,5 do assert(H.awardPet(h,candidate(h)))end
		local day=h.state.petDay;assert(H.release(h));c.now+=86400
		h=H.load(1,{},adapter("b"));assert(h.state.petCount==5 and h.state.petDay==day)
		assert(H.awardPet(h,candidate(h))and h.state.petCount==1 and h.state.nectar==12)
		local current=h.state.petDay;c.now-=86400;local writes=c.writes
		assert(not H.awardPet(h,candidate(h))and c.writes==writes and db.player_1.hatching.petDay==current)
	end)
	test("a second epoch fences the old writer and awards exactly once",function()
		local old,db,c,adapter=fixture();local stale=candidate(old);c.now+=91
		local current=H.load(1,{},adapter("b"));assert(current.epoch>old.epoch)
		assert(not H.awardPet(old,stale)and old.status=="SessionLost")
		assert(H.awardPet(current,candidate(current))and db.player_1.hatching.petCount==1)
	end)
	test("pending field or hatch operations retain their sole owner",function()
		local h,db,c=fixture();c.failBefore=true;assert(not H.award(h,1,6))
		local pending=h.pending;local writes=c.writes
		assert(not H.awardPet(h,candidate(h))and h.pending==pending and c.writes==writes)
		assert(H.retry(h)and h.state.lastAwardSeq==1 and h.state.petCount==0)
		-- v1: Meadow is retired (no spend, no write); a saved reveal replaces the hatch fixture.
		assert(H.award(h,2,6));writes=c.writes;local ok,why=H.command(h,"hatch","meadow",h.state.revision)
		assert(not ok and why=="RetiredEgg"and c.writes==writes and h.state.nectar==18)
		db.player_1.hatching.lastHatch={id="saved-reveal",petId="pip",duplicate=false,family="pip",mastery=0,rare=false,starter=true};assert(H.renew(h))
		writes=c.writes;assert(not H.awardPet(h,candidate(h))and c.writes==writes)
	end)
	test("close drains retained pet proof before releasing without a second award",function()
		local h,db,c=fixture();local p=candidate(h);c.failAfter=true;assert(not H.awardPet(h,p))
		local clock=0
		assert(Close.drain(H,h,nil,{now=function()return clock end,wait=function(dt)clock+=dt end,timeout=2}))
		assert(h.status=="Released"and db.player_1.hatching.petCount==1 and db.player_1.hatching.nectar==7)
	end)
	test("authentic v3 upgrades preserve every old nested fact and sibling",function()
		local h,db,_,adapter=fixture();assert(H.release(h));local old=db.player_1.hatching
		old.version=3;old.quests=nil;old.petWearables=nil;old.ballThemes,old.stats,old.stamps,old.book=nil,nil,nil,nil;old.contracts={day="20",progress={runs=0,chain=0,score=0},claimedMask=0};old.petDay,old.petCount,old.lastPetAward=nil,nil,nil
		-- Authentic v3 input: the fixture root is now v8, so drop the later Hue/Material/Toy/Feature namespaces.
		for _,key in ipairs({"toyUnlocks","petToys","toyReceipts","toyReceiptOrder","toyReservation","pendingToyResult","lastToyResult","featureStock","petFeatures","featureReceipts","featureReceiptOrder","featureReservation","pendingFeatureResult","lastFeatureResult","materialUnlocks","petMaterials","materialReceipts","materialReceiptOrder","materialReservation","pendingMaterialResult","lastMaterialResult","hueInventory","petHues","hueItemReceipts","hueReceiptOrder","hueMigrationId","hueMigrationAcknowledged","legacyLastHueResult","legacyHueEgg","legacyHueRedemption","pendingHueResult","hueReservation","hueAssignments"})do old[key]=nil end
		old.mastery.pip=10;old.masteryChallenges.pip=7;old.masteryLegacyMask=1;old.totalWins=4
		old.lastHatch={id="old-result",petId="pip",duplicate=true};db.player_1.keep={value=17}
		local captured=copy(old)
		h=H.load(1,{},adapter("b"));assert(h.status=="Ready"and h.state.version==11)
		assert(h.state.nectar==captured.nectar and h.state.inventoryMask==captured.inventoryMask and h.state.mastery.pip==10)
		assert(h.state.masteryChallenges.pip==7 and h.state.masteryLegacyMask==1 and h.state.totalWins==4)
		assert(h.state.contracts==nil and h.state.quests.v==1 and h.state.lastHatch.id=="old-result"and db.player_1.keep.value==17)
		assert(h.state.petCount==0 and h.state.lastPetAward==nil)
	end)
	test("future and malformed persisted schemas are not overwritten",function()
		for _,mutate in ipairs({function(s)s.version=5 end,function(s)s.petDay="020"end,function(s)s.petCount=6 end,
			function(s)s.petCount=1 end,function(s)s.version=3;s.petDay=nil;s.petCount=nil;s.nectar="bad"end})do
			local h,db,_,adapter=fixture();assert(H.release(h));mutate(db.player_1.hatching)
			local captured=game.HttpService:JSONEncode(db.player_1)
			h=H.load(1,{},adapter("b"));assert(h.status=="InvalidData")
			assert(game.HttpService:JSONEncode(db.player_1)==captured)
		end
	end)
	test("A then B then replay A cannot reuse an old admitted operation sequence",function()
		local h,_,c=fixture();local a=candidate(h);assert(H.awardPet(h,a))
		local b=candidate(h);assert(H.awardPet(h,b))
		local writes,balance,revision=c.writes,h.state.nectar,h.state.revision
		local ok,reason=H.awardPet(h,a)
		assert(not ok and reason=="StalePetAward"and c.writes==writes and h.state.nectar==balance and h.state.revision==revision)
		assert(h.state.lastPetAward.id==b.id and h.state.petCount==2)
	end)
	test("A followed by a non-pet operation retains exact A proof without a second award",function()
		local h,_,c=fixture();local a=candidate(h);assert(H.awardPet(h,a));assert(H.award(h,1,6))
		local writes,balance=c.writes,h.state.nectar
		assert(H.awardPet(h,a)and c.writes==writes and h.state.nectar==balance and h.state.petCount==1)
	end)
	test("renew may prove and clear a committed pet pending operation exactly once",function()
		local h,_,c=fixture();local a=candidate(h);c.failAfter=true;assert(not H.awardPet(h,a))
		assert(h.pending.id==a.id and H.renew(h)and h.pending==nil and h.status=="Ready")
		local writes=c.writes;assert(H.awardPet(h,a)and c.writes==writes and h.state.petCount==1)
	end)
	return{passed=#cases,cases=cases,persistentWrites=false,evidence="isolated fenced v4 adapter transactions, clocks and exact commit receipts"}
end
