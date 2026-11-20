-- v2 Stat Eggs, the snack pouch and feeding (StatEggCatalog, StatEggState, StatState boosts,
-- HatchProgress.statEggBuy / snackFeed / award free egg). Isolated adapters only; no DataStore.
-- Usage (Server): require(ServerScriptService.Server.ZZSpecs.StatEggs)(ServerScriptService.Server)
return function(server)
	local H=require(server.HatchProgress)
	local S=require(server.StatState)
	local E=require(server.StatEggState)
	local Shared=game:GetService("ReplicatedStorage").Shared
	local C=require(Shared.StatCatalog)
	local K=require(Shared.StatEggCatalog)
	local Eggs=require(Shared.EggCatalog)
	local cases={}
	local function test(name,run)run();table.insert(cases,name)end
	local function copy(v)if type(v)~="table"then return v end;local r={};for k,x in pairs(v)do r[k]=copy(x)end;return r end
	local pip=Eggs.bit("pip")
	local function fixture(seed,start)
		local db,c={},{now=start or 1700000000,serial=0,rand={},throwAfter=false}
		local adapter={
			now=function()return c.now end,
			guid=function()c.serial+=1;return "op"..c.serial end,
			random=function()return if #c.rand>0 then table.remove(c.rand,1)else .1 end,
			wait=function()end,
			update=function(key,transform)
				local value=transform(copy(db[key]))
				if value then db[key]=copy(value)end
				if c.throwAfter then c.throwAfter=false;error("ambiguous: committed but the reply was lost")end
				return copy(value)
			end,
		}
		if seed then db.player_1=seed end
		return H.load(1,{rank=1},adapter),db,c
	end
	local NONE={}
	local function reseed(db,fields)
		local seed=copy(db.player_1)
		for key,value in pairs(fields)do seed.hatching[key]=if value==NONE then nil else value end
		seed.hatching.lease={token="",expiresAt=0};return seed
	end
	-- A ready handle with the Bear and Stars (restricted by default, as the host before PolicyService answers).
	local function ready(fields,nectar)
		local _,db,c=fixture()
		local f={inventoryMask=pip,nectar=nectar or 200}
		for k,v in pairs(fields or {})do f[k]=v end
		c.now+=200
		local h,db2,c2=fixture(reseed(db,f),c.now)
		assert(h.status=="Ready","load "..tostring(h.status))
		return h,db2,c2
	end
	-- Move the clock to `at` and keep the session's lease alive (a day jump passes the 90 s lease).
	local function jump(h,db,c,at)
		c.now=at
		db.player_1.hatching.lease.expiresAt=at+90
		h.state.lease.expiresAt=at+90
	end
	local function key(h,petId)return H.public(h).statEgg.quotes[petId or "pip"].key end
	local function buy(h,op,free)return H.statEggBuy(h,op,"pip",free==true,key(h))end

	test("catalogue: odds sum to 100, roll matches the shown odds at the edges, fixed order is disclosed",function()
		local all=K.eligible({})
		assert(#all==6)
		local function size(u,misses)local _,s=K.roll(0,u,all,misses);return s end
		assert(size(0,0)=="nibble"and size(.5999,0)=="nibble"and size(.6,0)=="snack"and size(.8999,0)=="snack"and size(.9,0)=="feast"and size(.99999999,0)=="feast")
		assert(size(0,7)=="feast"and size(.5,7)=="feast","the promise: the 8th egg is a Feast")
		assert(K.pityLeft(0)==8 and K.pityLeft(7)==1 and K.pityLeft(40)==1)
		for n=1,6 do
			local pool={};for i=1,n do pool[i]=C.Order[i]end
			for i=0,n-1 do local stat=K.roll((i+.5)/n,0,pool,0);assert(stat==pool[i+1],"uniform stat "..n)end
			assert(K.roll(.9999999,0,pool,0)==pool[n]and K.roll(0,0,pool,0)==pool[1])
		end
		assert(K.roll(1,0,all,0)==nil and K.roll(0,0,{},0)==nil)
		-- restricted cycle: 6 Nibble, 3 Snack, 1 Feast; stats in panel order skipping 99s
		local tally,cycle,cursor={nibble=0,snack=0,feast=0},0,0
		local pool={"heart","energy","smarts"} -- power, jump, speed at 99
		local seen={}
		for i=1,10 do
			local stat,s,nc,ncur=K.fixedNext(pool,cycle,cursor)
			tally[s]+=1;table.insert(seen,stat);cycle,cursor=nc,ncur
		end
		assert(tally.nibble==6 and tally.snack==3 and tally.feast==1)
		assert(table.concat(seen,",",1,4)=="heart,energy,smarts,heart","panel order, skipping 99s: "..table.concat(seen,","))
		local stat=K.fixedNext({"jump"},0,0);assert(stat=="jump","the cursor's stat at 99 moves on")
		assert(K.fixedNext({},0,0)==nil)
		assert(K.eligible({heart=99,power=99,energy=99,jump=99,speed=99,smarts=99})[1]==nil)
	end)

	test("buy: a paid egg puts one snack in the pouch, charges 15, counts toward 3 a day",function()
		local h,db,c=ready()
		local ok,why,r=buy(h,"b1")
		assert(ok and why=="Saved","buy "..tostring(why))
		assert(r and r.kind=="buy"and r.cost==15 and r.snackId==1 and C.ById[r.stat]and K.Sizes[r.size]and r.digest==nil)
		assert(h.state.nectar==185 and #h.state.snackPouch==1 and h.state.snackPouch[1].id==1)
		assert(db.player_1.hatching.statEgg.boughtCount==1,"saved")
		assert(buy(h,"b2")and buy(h,"b3"))
		local ok4,why4=buy(h,"b4");assert(not ok4 and why4=="SoldOut"and h.state.nectar==155,"3 a day: "..tostring(why4))
		assert(H.public(h).statEgg.boughtToday==3)
		-- the next day the nest refills
		jump(h,db,c,c.now+86400)
		assert(buy(h,"b5"),"next day")
		assert(H.valid(h.state)and E.valid(h.state))
	end)

	test("idempotence: the same op twice is one snack and one charge; a reused op is a conflict",function()
		local h=ready()
		local k=key(h)
		assert(H.statEggBuy(h,"same","pip",false,k))
		local ok,why,r=H.statEggBuy(h,"same","pip",false,k)
		assert(ok and why=="AlreadySaved"and r.snackId==1 and h.state.nectar==185 and #h.state.snackPouch==1)
		local okc,whyc=H.statEggBuy(h,"same","pip",true,key(h))
		assert(not okc and whyc=="OperationConflict")
		-- a buy op reused for a feed
		local okf,whyf=H.snackFeed(h,"same",1,"pip");assert(not okf and whyf=="OperationConflict")
		assert(H.snackFeed(h,"f1",1,"pip"))
		local ok2,why2,r2=H.snackFeed(h,"f1",1,"pip")
		assert(ok2 and why2=="AlreadySaved"and r2.kind=="feed"and #h.state.snackPouch==0)
		assert(#S.boosts(h.state,"pip",r2.stat)==1,"one boost, not two")
		local okx,whyx=H.snackFeed(h,"f1",2,"pip");assert(not okx and whyx=="OperationConflict")
	end)

	test("an ambiguous write: the retry and a fresh server both return the same roll",function()
		local h,db,c=ready()
		h.restricted=false
		c.rand={.95,.95} -- smarts, feast
		c.throwAfter=true
		local ok,why=buy(h,"amb")
		assert(not ok and why=="Retrying","ambiguous "..tostring(why))
		c.rand={.0,.0} -- a re-roll would give heart nibble
		local ok2,why2=H.retry(h)
		assert(ok2 and why2=="Saved","retry "..tostring(why2))
		local r=E.receipt(h.state,"amb")
		assert(r.stat=="smarts"and r.size=="feast"and h.state.nectar==185 and #h.state.snackPouch==1)
		-- a new server (another session) replaying the op gets the saved receipt
		local h2=fixture(reseed(db,{}),c.now+200)
		local ok3,why3,r3=H.statEggBuy(h2,"amb","pip",false,"stale-key")
		assert(not ok3 and why3=="OperationConflict","a different key is a conflict")
		local digestKey=string.match(E.receipt(h2.state,"amb").digest,"^egg:pip:0:(.+)$")
		ok3,why3,r3=H.statEggBuy(h2,"amb","pip",false,digestKey)
		assert(ok3 and why3=="AlreadySaved"and r3.stat=="smarts"and h2.state.nectar==185)
	end)

	test("refusals take nothing: full pouch, no Stars, no free egg, stale quote, policy flip",function()
		local pouch={};for i=1,12 do pouch[i]={id=i,stat="heart",size="nibble"}end
		local h=ready({snackPouch=pouch,statEgg={serial=12}})
		local ok,why=buy(h,"full");assert(not ok and why=="PouchFull"and h.state.nectar==200,"full "..tostring(why))
		local h2=ready(nil,10)
		ok,why=buy(h2,"poor");assert(not ok and why=="NeedStars")
		ok,why=buy(h2,"free",true);assert(not ok and why=="NoFreeEgg")
		local h3=ready()
		local k=key(h3)
		h3.restricted=false -- PolicyService answered after the card was drawn
		ok,why=H.statEggBuy(h3,"flip","pip",false,k);assert(not ok and why=="PoolChanged"and h3.state.nectar==200)
		ok,why=H.statEggBuy(h3,"flip2","pip",false,key(h3));assert(ok,"the fresh quote works")
		ok,why=H.statEggBuy(h3,"again","pip",false,k);assert(not ok and why=="PoolChanged","a quote is good once (serial)")
		assert(not H.statEggBuy(h3,"x","pip","yes",k)and not H.statEggBuy(h3,string.rep("x",81),"pip",false,k))
		-- all six at 99
		local maxed={};for _,s in ipairs(C.Order)do maxed[s]=C.xpFor(99)end
		local h4=ready({petStats={pip=maxed},statsSeed=1})
		ok,why=buy(h4,"m");assert(not ok and why=="AllMaxed")
	end)

	test("restricted players get the disclosed fixed order; random players keep the Feast promise",function()
		local h,db,c0=ready(nil,1000)
		local sizes={}
		for day=0,3 do
			jump(h,db,c0,1700000200+86400*day)
			for i=1,3 do
				local nextFixed=H.public(h).statEgg.quotes.pip.next
				local ok,_,r=buy(h,"r"..day..i);assert(ok)
				assert(r.stat==nextFixed.stat and r.size==nextFixed.size,"the card's Next is what hatched")
				table.insert(sizes,r.size)
				assert(H.snackFeed(h,"rf"..day..i,r.snackId,"pip"))
				-- drain the boost so the queue never fills
				S.grant(h.state,"pip",r.stat,1000,"1",true)
				h.state.petBoosts=nil
			end
		end
		assert(table.concat(sizes,",",1,10)==table.concat(K.Cycle,","),"cycle "..table.concat(sizes,","))
		local h2,db2,c=ready(nil,1000)
		h2.restricted=false
		local feast=0
		for i=1,8 do
			if i==4 or i==7 then jump(h2,db2,c,1700000200+86400*i)end
			c.rand={.5,.1} -- always a Nibble roll
			local ok,_,r=buy(h2,"p"..i);assert(ok,"pity buy "..i)
			if r.size=="feast"then feast=i end
		end
		assert(feast==8,"the 8th is a Feast: "..feast)
		assert(h2.state.statEgg.misses==0)
	end)

	test("feeding: owned snack, owned pet, stat under 99, queue room; the snack moves to a boost",function()
		local h=ready(nil,1000)
		local _,_,r=buy(h,"a")
		local ok,why=H.snackFeed(h,"nope",99,"pip");assert(not ok and why=="NoSnack")
		ok,why=H.snackFeed(h,"bunny",r.snackId,"puddle");assert(not ok and(why=="Unowned"or why=="InvalidSnack"),"unowned pet "..tostring(why))
		ok,why=H.snackFeed(h,"eat",r.snackId,"pip");assert(ok)
		local q=S.boosts(h.state,"pip",r.stat)
		assert(#q==1 and q[1].mult==K.Sizes[r.size].mult and q[1].left==K.Sizes[r.size].xp)
		-- queue room 3 per stat
		local pouch={};for i=1,4 do pouch[i]={id=100+i,stat="jump",size="nibble"}end
		local h2=ready({snackPouch=pouch,statEgg={serial=104}})
		for i=1,3 do assert(H.snackFeed(h2,"j"..i,100+i,"pip"),"feed "..i)end
		ok,why=H.snackFeed(h2,"j4",104,"pip");assert(not ok and why=="QueueFull"and #h2.state.snackPouch==1)
		-- a stat at 99 takes no more snacks
		local h3=ready({snackPouch={{id=1,stat="power",size="feast"}},statEgg={serial=1},petStats={pip={power=C.xpFor(99)}},statsSeed=1})
		ok,why=H.snackFeed(h3,"s",1,"pip");assert(not ok and why=="StatMaxed")
		-- a pending reveal blocks it
		local h4=ready({snackPouch={{id=1,stat="heart",size="nibble"}},statEgg={serial=1},lastHatch={id="x",petId="pip"}})
		ok,why=H.snackFeed(h4,"s",1,"pip");assert(not ok and why=="RevealPending")
		-- unknown future snack sizes are kept, never fed
		local h5=ready({snackPouch={{id=1,stat="heart",size="banquet"}},statEgg={serial=1}})
		ok,why=H.snackFeed(h5,"s",1,"pip");assert(not ok and why=="UnknownSnack"and #h5.state.snackPouch==1)
	end)

	test("grant: a boost doubles plain XP after the day's Bonus XP, queues, never passes 3x",function()
		local state={inventoryMask=pip}
		assert(S.queueBoost(state,"pip","power",2,50))
		-- 60 XP on a fresh day: 60 doubled by Bonus (bonus left 40), no boost on doubled XP
		local added,extra=S.grant(state,"pip","power",60,"100")
		assert(added==120 and extra==0 and S.boosts(state,"pip","power")[1].left==50)
		-- 100 XP: 40 doubled by bonus, 60 plain -> 50 boosted (+50), 10 plain
		added,extra=S.grant(state,"pip","power",100,"100")
		assert(added==40*2+60+50 and extra==50,"boost after bonus "..added)
		assert(#S.boosts(state,"pip","power")==0 and state.petBoosts==nil,"used up")
		-- queue: a Feast then a Snack, consumed in turn, never multiplied together
		assert(S.queueBoost(state,"pip","power",3,120)and S.queueBoost(state,"pip","power",2,120))
		added,extra=S.grant(state,"pip","power",200,"100")
		assert(extra==120*2+80*1 and added==200+extra,"queue "..extra)
		assert(S.boosts(state,"pip","power")[1].left==40)
		-- a stored mult above the cap is used at 3x
		local odd={inventoryMask=pip,petBoosts={pip={heart={{mult=9,left=10}}}}}
		assert(S.validBoosts(odd))
		added,extra=S.grant(odd,"pip","heart",10,"5",true)
		assert(added==10 and extra==0,"noBonus means no boost either")
		local both={inventoryMask=pip,statBonus={day="5",left={heart=0}},petBoosts={pip={heart={{mult=9,left=10}}}}}
		added,extra=S.grant(both,"pip","heart",10,"5")
		assert(added==30 and extra==20,"capped at 3x: "..added)
		-- the Bonus stat-limit path: bonus not applied -> all of it boosts
		local left={};for i=1,16 do left["zz"..i]=1 end
		local full={inventoryMask=pip,statBonus={day="5",left=left},petBoosts={pip={heart={{mult=2,left=100}}}}}
		added,extra=S.grant(full,"pip","heart",10,"5")
		assert(added==20 and extra==10,"boost without a bonus "..added)
		-- MaxXP: the clamp clears the queue
		local top={inventoryMask=pip,petStats={pip={power=C.MaxXP-5}},petBoosts={pip={power={{mult=3,left=100}}}}}
		added,extra=S.grant(top,"pip","power",10,"5")
		assert(S.xp(top,"pip","power")==C.MaxXP and #S.boosts(top,"pip","power")==0)
		-- public shows "2x · 80 XP left"
		local pub={inventoryMask=pip,petBoosts={pip={jump={{mult=2,left=80},{mult=3,left=120}}}}}
		local b=S.public(pub,"5").pets.pip.boosts.jump
		assert(b.mult==2 and b.left==80 and b.queued==200 and b.count==2)
	end)

	test("the free daily egg rides the round award: once a day, capped at 10, never on a clock rollback",function()
		local h=ready()
		local function summary()return {family="pip",day=H.public(h).dailyDay,success=false,clean=false,score=1,chain=1,clears=0,drops=3,heat="easy",goalsMet=0}end
		assert(H.award(h,1,0,summary(),nil,"pip"))
		assert(E.free(h.state)==1 and h.state.lastRunReward.freeStatEgg==true)
		assert(H.award(h,2,0,summary(),nil,"pip"))
		assert(E.free(h.state)==1 and h.state.lastRunReward.freeStatEgg==nil,"once a day")
		-- a free egg hatches with no charge and no daily count
		local ok,_,r=buy(h,"fr",true);assert(ok and r.free==true and r.cost==0 and h.state.nectar==200 and E.free(h.state)==0)
		assert(H.public(h).statEgg.boughtToday==0)
		-- an award with unknown keys inside statEgg still pays, and keeps them
		local h2=ready({statEgg={futureKey="x",free=10,freeDay="0"}})
		local before=h2.state.nectar
		assert(H.award(h2,1,6,{family="pip",day=H.public(h2).dailyDay,success=true,clean=false,score=1,chain=1,clears=0,drops=24,heat="easy",goalsMet=0},nil,"pip"))
		assert(h2.state.nectar>before and h2.state.statEgg.futureKey=="x"and E.free(h2.state)==10,"capped at 10")
		-- a server clock behind the saved free day adds nothing
		local h3=ready({statEgg={freeDay="99999"}})
		assert(H.award(h3,1,0,{family="pip",day=H.public(h3).dailyDay,success=false,clean=false,score=1,chain=1,clears=0,drops=3,heat="easy",goalsMet=0},nil,"pip"))
		assert(E.free(h3.state)==0 and h3.state.statEgg.freeDay=="99999")
	end)

	test("a server clock behind the bought day refuses with no charge and never moves the day back",function()
		local h=ready({statEgg={boughtDay="99999",boughtCount=1}})
		assert(H.public(h).statEgg.boughtToday==K.DailyBuys,"reads as sold out")
		local ok,why=buy(h,"late");assert(not ok and why=="ClockRollback"and h.state.nectar==200)
		assert(h.state.statEgg.boughtDay=="99999")
	end)

	test("valid and sanitize: tolerant, frozen bounds, ids repaired, a bad boost keeps petStats",function()
		assert(E.valid({})and E.valid({snackPouch={},statEgg={}}))
		assert(E.valid({snackPouch={{id=1,stat="futureStat",size="banquet",extra=true}},statEgg={serial=1,futureKey={nested=true}}}),"unknown ids and keys kept")
		assert(not E.valid({snackPouch={{id=1,stat="heart",size="snack"},{id=1,stat="heart",size="snack"}},statEgg={serial=1}}),"duplicate ids")
		assert(not E.valid({snackPouch={{id=5,stat="heart",size="snack"}},statEgg={serial=2}}),"serial below an id")
		assert(not E.valid({statEgg={misses=64}})and not E.valid({statEgg={boughtDay="x"}})and not E.valid({snackPouch="no"}))
		local state={snackPouch={{id=3,stat="heart",size="snack"},{id=3,stat="jump",size="nibble"},"junk",{id=9,stat="speed",size="feast"}},
			statEgg={misses=1000,free=-4,boughtDay="nope",serial=1,receipts={{op="a",kind="buy",snackId=12},{op=5},"x"},futureKey=1}}
		E.sanitize(state)
		assert(#state.snackPouch==2 and state.snackPouch[2].id==9)
		assert(state.statEgg.misses==K.MissesLimit and state.statEgg.free==0 and state.statEgg.boughtDay==nil and state.statEgg.futureKey==1)
		assert(#state.statEgg.receipts==1 and state.statEgg.serial==12,"serial lifted to the highest id seen")
		assert(E.valid(state))
		-- a malformed petBoosts is repaired on its own and never drops petStats
		local _,db,c=fixture()
		local h=fixture(reseed(db,{inventoryMask=pip,petStats={pip={power=500}},statsSeed=1,petBoosts={pip={power={{mult="x",left=5},{mult=2,left=30}}},bad=7},
			snackPouch={{id=1,stat="heart",size="snack"}},statEgg="garbage"}),c.now+200)
		assert(h.status=="Ready","loads")
		assert(h.state.petStats.pip.power==500,"petStats kept")
		assert(#S.boosts(h.state,"pip","power")==1 and S.boosts(h.state,"pip","power")[1].left==30)
		assert(#h.state.snackPouch==1 and h.state.statEgg.serial==1,"the pouch survives a broken statEgg")
		assert(H.valid(h.state))
	end)

	test("old saves load untouched; the new fields survive other transactions and a reload",function()
		local _,db,c=fixture()
		local old=reseed(db,{inventoryMask=pip,snackPouch=NONE,statEgg=NONE,petBoosts=NONE})
		local h=fixture(old,c.now+200)
		assert(h.status=="Ready"and h.state.snackPouch==nil and h.state.statEgg==nil and h.state.petBoosts==nil)
		local p=H.public(h).statEgg
		assert(p.free==0 and #p.pouch==0 and p.boughtToday==0 and p.pityLeft==K.PityAt and p.quotes.pip)
		-- with the fields: an unrelated write (park play) keeps them byte for byte, and a reload keeps them
		local fields={snackPouch={{id=2,stat="jump",size="feast"}},statEgg={serial=2,free=3,freeDay="1",futureKey="kept",receipts={{op="o",kind="buy",snackId=2,digest="d"}}},
			petBoosts={pip={heart={{mult=2,left=40}}},futurePet={futureStat={{mult=2,left=1}}}}}
		local seeded={inventoryMask=pip};for k,v in pairs(fields)do seeded[k]=copy(v)end
		local _,db2,c2=fixture()
		local h2,db3=fixture(reseed(db2,seeded),c2.now+200)
		assert(H.parkPlay(h2,"park1",1,"pip"))
		local saved=db3.player_1.hatching
		local snack=saved.snackPouch[1]
		assert(#saved.snackPouch==1 and snack.id==2 and snack.stat=="jump"and snack.size=="feast"and saved.statEgg.futureKey=="kept"
			and saved.statEgg.receipts[1].digest=="d"and saved.petBoosts.futurePet.futureStat[1].left==1)
		local h3=fixture(reseed(db3,{}),c2.now+400)
		assert(h3.status=="Ready"and #h3.state.snackPouch==1 and h3.state.statEgg.free==3 and S.boosts(h3.state,"pip","heart")[1].left==40)
		-- an award while a snack op is pending is refused as Pending, never lost
		local h4,_,c4=ready()
		c4.throwAfter=true
		assert(select(2,buy(h4,"pend"))=="Retrying")
		local okA,whyA=H.award(h4,1,0,{family="pip",day=H.public(h4).dailyDay,success=false,clean=false,score=1,chain=1,clears=0,drops=3,heat="easy",goalsMet=0},nil,"pip")
		assert(not okA and whyA=="Pending","award waits for the snack op: "..tostring(whyA))
		assert(H.retry(h4))
		assert(H.award(h4,1,0,{family="pip",day=H.public(h4).dailyDay,success=false,clean=false,score=1,chain=1,clears=0,drops=3,heat="easy",goalsMet=0},nil,"pip"))
	end)

	return {passed=#cases,cases=cases}
end
