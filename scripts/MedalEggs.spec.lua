-- Medal Stat Eggs (MedalEggs through HatchProgress.statEggBuy; V3-LEVELS-BUILD-PLAN-2026-11-22 S4):
-- the credit is derived from the saved XP, the spend is one count in the buy's own transaction, so
-- each medal pays one egg under retry, replay, a lost reply, shutdown and two sessions; a malformed
-- count fails closed; off hides the credit and writes nothing.
-- Isolated adapters only; no DataStore or user writes.
-- Usage (Server): require(ServerScriptService.Server.ZZSpecs.MedalEggs)(ServerScriptService.Server)
return function(server)
	local H=require(server.HatchProgress)
	local M=require(server.MedalEggs)
	local E=require(server.StatEggState)
	local S=require(server.StatState)
	local Shared=game:GetService("ReplicatedStorage").Shared
	local Levels=require(Shared.Levels)
	local C=require(Shared.StatCatalog)
	local K=require(Shared.StatEggCatalog)
	local Eggs=require(Shared.EggCatalog)
	local cases={}
	local function test(name,run)run();table.insert(cases,name)end
	local function copy(v)if type(v)~="table"then return v end;local r={};for k,x in pairs(v)do r[k]=copy(x)end;return r end
	local ALL={track=true,gates=true,medals=true,juice=true}
	local function medals(on)Levels.inject({flags={LevelsMatter=on==true},studio=true,shipped=ALL})end
	local pip=Eggs.bit("pip")
	local NONE={}
	local function fixture(seed,start)
		local db,c={},{now=start or 1700000000,serial=0,writes=0}
		local adapter={
			now=function()return c.now end,guid=function()c.serial+=1;return "op"..c.serial end,
			random=function()return .1 end,wait=function()end,
			update=function(key,transform)
				c.writes+=1
				if c.failBefore then c.failBefore=false;error("fixture before commit")end
				local value=transform(copy(db[key]))
				if c.replay then value=transform(copy(db[key]))end
				if value then db[key]=copy(value)end
				if c.failAfter then c.failAfter=false;error("fixture after commit")end
				return copy(value)
			end,
		}
		if seed then db.player_1=seed end
		return H.load(1,{rank=1},adapter),db,c
	end
	local function reseed(db,fields)
		local seed=copy(db.player_1)
		for key,value in pairs(fields)do seed.hatching[key]=if value==NONE then nil else value end
		seed.hatching.lease={token="",expiresAt=0}
		return seed
	end
	local function ready(fields)
		local _,db,c=fixture()
		local f={inventoryMask=pip,nectar=200,statsSeed=1}
		for k,v in pairs(fields or {})do f[k]=v end
		local h,db2,c2=fixture(reseed(db,f),c.now+200)
		assert(h.status=="Ready","load "..tostring(h.status))
		return h,db2,c2
	end
	local function xp(levels)local row={};for stat,level in pairs(levels)do row[stat]=C.xpFor(level)end;return{pip=row}end
	local function key(h)return H.public(h).statEgg.quotes.pip.key end
	local function open(h,op)return H.statEggBuy(h,op,"pip",true,key(h))end
	local ok,problem=pcall(function()
		test("derived: earned from every owned pet's saved XP, used from one optional field, never negative",function()
			medals(true)
			local both=bit32.bor(pip,Eggs.bit("blip"))
			assert(M.earned({inventoryMask=pip,petStats=xp({jump=25})})==1 and M.earned({inventoryMask=pip,petStats=xp({jump=24})})==0)
			assert(M.earned({inventoryMask=pip,petStats={pip=xp({jump=99}).pip,blip=xp({jump=99}).pip}})==4,"an unowned pet earns nothing")
			assert(M.earned({inventoryMask=both,petStats={pip=xp({jump=99}).pip,blip=xp({heart=50}).pip}})==6)
			local state={inventoryMask=pip,petStats=xp({jump=50})}
			assert(M.used(state)==0 and M.left(state)==2)
			state.medalEggsUsed=2;assert(M.left(state)==0)
			state.medalEggsUsed=9;assert(M.left(state)==0,"never negative")
			state.petStats=nil;assert(M.left(state)==0 and M.earned(state)==0)
			assert(M.left(nil)==0 and M.left({})==0)
		end)
		test("opening: the bank first, then medals; the receipt says so; no Stars and no daily count",function()
			medals(true)
			local h,db=ready({petStats=xp({jump=25,heart=50}),statEgg={free=1,freeDay="1"}})
			local p=H.public(h).statEgg
			assert(p.free==4 and p.medalEggs==3 and p.freeLimit==K.FreeLimit)
			local done,why,r=open(h,"a");assert(done and why=="Saved"and r.free==true and r.source==nil and r.cost==0,tostring(why))
			assert(E.free(h.state)==0 and h.state.medalEggsUsed==nil,"the bank first")
			done,why,r=open(h,"b");assert(done and r.source=="medal"and r.free==true and r.cost==0)
			assert(db.player_1.hatching.medalEggsUsed==1 and h.state.nectar==200 and H.public(h).statEgg.boughtToday==0 and H.public(h).statEgg.free==2)
			assert(open(h,"c")and open(h,"d"))
			done,why=open(h,"e");assert(not done and why=="NoFreeEgg"and h.state.medalEggsUsed==3 and #h.state.snackPouch==4)
			assert(H.valid(h.state)and db.player_1.hatching.statEgg.free==0)
		end)
		test("exactly once: a lost reply, a retry, a replayed callback, the same op again, a reused op",function()
			medals(true)
			local h,db,c=ready({petStats=xp({jump=50})})
			local quote=key(h)
			c.failAfter=true
			local done,why=H.statEggBuy(h,"amb","pip",true,quote);assert(not done and why=="Retrying",tostring(why))
			c.replay=true
			done,why=H.retry(h);assert(done and why=="Saved"and h.state.medalEggsUsed==1 and #h.state.snackPouch==1)
			local r;done,why,r=H.statEggBuy(h,"amb","pip",true,quote)
			assert(done and why=="AlreadySaved"and r.source=="medal"and h.state.medalEggsUsed==1)
			done,why=H.statEggBuy(h,"amb","pip",false,key(h));assert(not done and why=="OperationConflict")
			done,why=H.statEggBuy(h,"stale","pip",true,quote);assert(not done and why=="PoolChanged"and h.state.medalEggsUsed==1,"a quote is good once")
			-- before the commit: shutdown mid-buy. Nothing saved; another server opens it once with the same op
			h,db,c=ready({petStats=xp({jump=25})})
			quote=key(h);c.failBefore=true
			done,why=H.statEggBuy(h,"cut","pip",true,quote);assert(not done and why=="Retrying"and db.player_1.hatching.medalEggsUsed==nil)
			local h2,db2=fixture(reseed(db,{}),c.now+200)
			done,why=H.statEggBuy(h2,"cut","pip",true,quote);assert(done and why=="Saved"and db2.player_1.hatching.medalEggsUsed==1)
			done,why=open(h2,"more");assert(not done and why=="NoFreeEgg")
			-- after the commit: the new server replays the receipt
			h,db,c=ready({petStats=xp({jump=25})})
			quote=key(h);c.failAfter=true
			assert(select(2,H.statEggBuy(h,"late","pip",true,quote))=="Retrying"and db.player_1.hatching.medalEggsUsed==1)
			h2,db2=fixture(reseed(db,{}),c.now+200)
			done,why,r=H.statEggBuy(h2,"late","pip",true,quote);assert(done and why=="AlreadySaved"and r.snackId==1 and db2.player_1.hatching.medalEggsUsed==1 and #h2.state.snackPouch==1)
		end)
		test("two sessions, one op: one commits, the other is SessionLost",function()
			medals(true)
			local h,db,c=ready({petStats=xp({jump=25})})
			local quote=key(h)
			c.now+=200
			local other=H.load(1,{rank=1},h.adapter);assert(other.status=="Ready")
			local done,why=H.statEggBuy(h,"two","pip",true,quote);assert(not done and why=="SessionLost",tostring(why))
			done,why=H.statEggBuy(other,"two","pip",true,quote);assert(done and why=="Saved"and db.player_1.hatching.medalEggsUsed==1)
		end)
		test("crossing: the XP write is the grant; two stats in one write are two credits; nothing else is written",function()
			medals(true)
			local h,db=ready({petStats={pip={jump=C.xpFor(25)-1,heart=C.xpFor(25)-1}}})
			assert(M.left(h.state)==0)
			-- petting and a park game cross Heart and Jump in their own transactions
			assert(H.parkPlay(h,"p1",1,"pip"));assert(M.left(h.state)==1 and H.public(h).statEgg.medalEggs==1)
			assert(H.awardPet(h,H.petCandidate(h,"lease","pip")));assert(M.left(h.state)==2)
			assert(db.player_1.hatching.medalEggsUsed==nil,"nothing stored for a grant")
			local state={inventoryMask=pip,petStats={pip={jump=C.xpFor(25)-1,heart=C.xpFor(50)-1}}}
			S.grant(state,"pip","jump",1,"1",true);S.grant(state,"pip","heart",1,"1",true);assert(M.left(state)==3)
			-- XP lost to a repair cannot pay again on the way back
			state.medalEggsUsed=3;state.petStats={pip={}};assert(M.left(state)==0)
			S.grant(state,"pip","jump",C.xpFor(25),"1",true);assert(M.left(state)==0)
			-- a seeded save earns at load, once
			local _,seedDb,c=fixture()
			local seeded,seededDb=fixture(reseed(seedDb,{inventoryMask=pip,petStats=NONE,statsSeed=NONE,stats=(function()local s=copy(seedDb.player_1.hatching.stats);s.merges=C.xpFor(30);return s end)()}),c.now+200)
			assert(seeded.status=="Ready"and M.left(seeded.state)>=1 and seededDb.player_1.hatching.medalEggsUsed==nil)
			local n=M.left(seeded.state)
			local again=fixture(reseed(seededDb,{}),c.now+600);assert(M.left(again.state)==n,"a reload pays nothing more")
		end)
		test("a free egg ask still refuses with nothing spent: full pouch, every stat at 99, stale quote, unowned pet",function()
			medals(true)
			local pouch={};for i=1,K.PouchSize do pouch[i]={id=i,stat="heart",size="nibble"}end
			local h=ready({petStats=xp({jump=50}),snackPouch=pouch,statEgg={serial=K.PouchSize}})
			local done,why=open(h,"full");assert(not done and why=="PouchFull"and h.state.medalEggsUsed==nil and M.left(h.state)==2)
			local maxed={};for _,stat in ipairs(C.Order)do maxed[stat]=99 end
			h=ready({petStats=xp(maxed),medalEggsUsed=21})
			done,why=open(h,"max");assert(not done and why=="AllMaxed"and M.left(h.state)==3 and h.state.medalEggsUsed==21)
			h=ready({petStats=xp({jump=25})})
			done,why=H.statEggBuy(h,"q","pip",true,"nope");assert(not done and why=="PoolChanged"and M.left(h.state)==1)
			done,why=H.statEggBuy(h,"u","blip",true,key(h));assert(not done and why=="Unowned"and M.left(h.state)==1)
		end)
		test("medal eggs sit outside the 10 egg bank: a big credit never blocks the daily free egg",function()
			medals(true)
			local maxed={};for _,stat in ipairs(C.Order)do maxed[stat]=98 end
			local h=ready({petStats=xp(maxed)})
			assert(M.left(h.state)==18 and H.public(h).statEgg.free==18)
			assert(H.award(h,1,0,{family="pip",day=H.public(h).dailyDay,success=false,clean=false,score=1,chain=1,clears=0,drops=3,heat="easy",goalsMet=0},nil,"pip"))
			assert(E.free(h.state)==1 and h.state.lastRunReward.freeStatEgg==true and H.public(h).statEgg.free>=19)
		end)
		test("malformed counts fail closed: no credit, a load that still works, and the number earned written once",function()
			medals(true)
			for _,bad in ipairs({-1,1.5,1000001,"3",true,{},"garbage",{n=1}})do
				local state={inventoryMask=pip,petStats=xp({jump=50}),medalEggsUsed=bad}
				assert(M.used(state)==nil and M.left(state)==0 and not M.spend(state)and state.medalEggsUsed==bad)
				local h,db=ready({petStats=xp({jump=50}),medalEggsUsed=bad})
				assert(h.status=="Ready"and h.state.medalEggsUsed==2 and db.player_1.hatching.medalEggsUsed==2 and M.left(h.state)==0,"repaired to the number earned")
				local done,why=open(h,"x");assert(not done and why=="NoFreeEgg")
			end
			local state={medalEggsUsed=0/0,inventoryMask=pip,petStats=xp({jump=50})};assert(M.left(state)==0)
			M.sanitize(state);assert(state.medalEggsUsed==2)
			-- the repair runs after the one-time stats seed, so a seed cannot turn a broken count into eggs
			local _,db,c=fixture()
			local seeded=fixture(reseed(db,{inventoryMask=pip,petStats=NONE,statsSeed=NONE,medalEggsUsed="broken",stats=(function()local s=copy(db.player_1.hatching.stats);s.merges=C.xpFor(50);return s end)()}),c.now+200)
			assert(seeded.status=="Ready"and M.earned(seeded.state)>=2 and M.left(seeded.state)==0)
			-- valid values are never touched
			for _,fine in ipairs({0,1,1000000})do local h=ready({petStats=xp({jump=50}),medalEggsUsed=fine});assert(h.state.medalEggsUsed==fine)end
			-- petStats dropped at load: credit 0, and the count kept
			local h=ready({petStats="junk",medalEggsUsed=2});assert(h.status=="Ready"and M.left(h.state)==0 and h.state.medalEggsUsed==2)
		end)
		test("off: the credit is hidden, NoFreeEgg as before, nothing written; on again it is all still there",function()
			medals(false)
			local h,db,c=ready({petStats=xp({jump=50}),medalEggsUsed=1})
			local p=H.public(h).statEgg
			assert(p.free==0 and p.medalEggs==nil)
			local done,why=open(h,"off");assert(not done and why=="NoFreeEgg")
			assert(H.parkPlay(h,"p",1,"pip")and db.player_1.hatching.medalEggsUsed==1)
			local bad=ready({petStats=xp({jump=50}),medalEggsUsed="junk"});assert(bad.status=="Ready"and bad.state.medalEggsUsed=="junk","off writes nothing")
			medals(true)
			local h2=fixture(reseed(db,{}),c.now+200)
			assert(H.public(h2).statEgg.medalEggs==1 and open(h2,"on")and h2.state.medalEggsUsed==2)
		end)
		test("the switch is frozen with the request: a retry after it flips settles the same way",function()
			medals(true)
			local h,db,c=ready({petStats=xp({jump=25})})
			c.failBefore=true
			assert(select(2,open(h,"flip"))=="Retrying")
			medals(false)
			local done,why=H.retry(h);assert(done and why=="Saved"and db.player_1.hatching.medalEggsUsed==1)
			medals(true)
		end)
		test("the live build reads the new receipt and field: unknown keys stay valid and survive a write",function()
			medals(true)
			local h,db=ready({petStats=xp({jump=25})})
			assert(open(h,"keep"))
			assert(E.valid(db.player_1.hatching)and H.valid(db.player_1.hatching))
			local before=copy(db.player_1.hatching.statEgg.receipts)
			assert(H.parkPlay(h,"p",1,"pip"))
			assert(db.player_1.hatching.medalEggsUsed==1 and db.player_1.hatching.statEgg.receipts[1].source=="medal"and #before==1)
		end)
	end)
	Levels.inject(nil)
	assert(ok,problem)
	return{passed=#cases,cases=cases}
end
