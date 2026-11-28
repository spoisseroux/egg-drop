-- The lessons remembered (artifacts/qa-2026-11-27-beta42/TEACH-MORE-BRIEF.md section 3, ARCH-REVIEW-TEACH 1, 2 and 10):
-- the optional `teachMask` and `teachParked` save fields (missing or invalid reads 0, never fails a load, unknown bits
-- kept), their requests (a latch by name, "done:<reason>", "park:<id>"), the coach write carrying both masks in one
-- transaction, the latches in the fact-making transactions (a ribbon, the twelfth round, a pot, a snack), the load-time
-- backfill (veteran, moved on, the facts already true), `done` never cleared, the ignore thermometer, and Onboard
-- `teach` off leaving the save untouched. Isolated adapters only.
-- Usage (Server): require(ServerScriptService.Server.ZZSpecs.TeachMarks)(ServerScriptService.Server)
return function(server)
	local H=require(server.HatchProgress)
	local Shared=game:GetService("ReplicatedStorage").Shared
	local Teach=require(Shared.TeachMarks)
	local Coach=require(Shared.CoachMarks)
	local Onboard=require(Shared.Onboard)
	local Dash=require(Shared.Dash)
	local cases={}
	local function copy(v)if type(v)~="table"then return v end;local r={};for k,x in pairs(v)do r[k]=copy(x)end;return r end
	local function test(name,run)run();table.insert(cases,name)end
	local fixtures=0
	local function adapterFor(db,c)
		return {now=function()return c.now end,guid=function()c.serial+=1;return c.prefix..c.serial end,random=function()return .9 end,wait=function()end,
			update=function(key,transform)
				c.writes+=1
				local value=transform(copy(db[key]))
				if value then db[key]=copy(value)end
				return copy(value)
			end}
	end
	-- A brand-new save with the Bear (owed the gift chain when `chain`), acked.
	local function fresh(chain)
		fixtures+=1
		local db,c={},{now=1700000000,serial=0,writes=0,prefix="tm"..fixtures.."op"}
		local h=H.load(1,{},adapterFor(db,c));assert(h.status=="Ready")
		assert(h.state.teachMask==nil,"a brand-new save (no pet yet) is never a veteran")
		assert(H.grantStarter(h,false,chain))
		assert(H.command(h,"ack",h.state.lastHatch.id,h.state.revision))
		return h,db,c
	end
	local function rejoin(h,db,c,changes)
		H.release(h)
		c.now+=200
		local saved=db.player_1.hatching
		saved.lease.expiresAt=0
		for k,v in pairs(changes or {})do saved[k]=copy(v)end
		local again=H.load(1,{},adapterFor(db,c));assert(again.status=="Ready","rejoin "..tostring(again.status))
		return again
	end
	local function latched(...)local m=0;for _,id in ipairs({...})do m=Teach.with(m,id)end;return m end
	local ok,problem=pcall(function()
		Onboard.inject({flags={OnboardingV3=true},studio=true})

		test("pure: ids fit 31 bits and are append-only; requests parse; the course; the thermometer latches on the third session",function()
			local seen={}
			for id,index in pairs(Teach.Bits)do assert(index>=0 and index<=30 and not seen[index],id);seen[index]=true end
			assert(Teach.Bits.dress==0 and Teach.Bits.dash==4 and Teach.Bits.deckTour==5 and Teach.Bits.wardrobe==14 and Teach.Bits.done==16 and Teach.Bits.needs==17)
			for _,slot in pairs(Teach.Parkable)do assert(2*slot+1<=30)end
			assert(Teach.parse("deckTour").kind=="mark"and Teach.parse("done:skipped").reason=="skipped"and Teach.parse("park:menu").id=="menu")
			for _,bad in ipairs({"done","done:veteran","done:movedOn","park:deckTour","park:level","parked1","nope",5,{},string.rep("a",40)})do
				assert(Teach.parse(bad)==nil,"refused: "..tostring(bad))
			end
			for _,id in ipairs(Teach.Course)do assert(Teach.Bits[id],id)end
			local p,t=Teach.parkStep(0,"menu");assert(p>0 and t==0)
			local p2,t2=Teach.parkStep(p,"menu");assert(p2>0 and p2~=p and t2==0)
			local p3,t3=Teach.parkStep(p+p2,"menu");assert(p3==0 and t3==Teach.bit("menu"),"the third ignored session latches the lesson")
			assert(Teach.parkCount(p+p2,"menu")==2 and Teach.parkCount(p+p2,"dress")==0)
		end)

		test("beta 44 (ARCH-REVIEW-SIMPLIFY 5 and 6): the course is the tour; graduating saves `needs` with `done`; the tour only from the deck",function()
			assert(#Teach.Course==1 and Teach.Course[1]=="deckTour")
			local both=Teach.doneBits()
			assert(Teach.has(both,"done")and Teach.has(both,"needs")and both==Teach.bit("done")+Teach.bit("needs"))
			assert(Teach.OnDeck.deckTour==true and not Teach.OnDeck.level,"the deck tour's latch is taken only while the board is on the deck")
			-- no new bit in this build: the old lessons keep theirs (never renumbered) and older builds keep what they do not know
			assert(Teach.Bits.menu==2 and Teach.Bits.wardrobe==14 and Teach.Bits.needs==17)
			local h,db,c=fresh(true)
			assert(H.coachMark(h,0,both,0))
			assert(Teach.has(h.state.teachMask,"done")and Teach.has(h.state.teachMask,"needs"),"one write")
			local again=rejoin(h,db,c,{})
			assert(Teach.has(again.state.teachMask,"needs")and Teach.has(again.state.teachMask,"done"),"kept across a load")
		end)

		test("save: missing reads 0 and publishes no key; malformed is dropped at load; a later build's bits are kept",function()
			local h,db,c=fresh(true)
			assert(h.state.teachMask==nil and H.public(h).teachMask==nil and H.valid(h.state))
			for _,bad in ipairs({"x",-1,1.5,2^31,0/0,{1},true})do
				local again=rejoin(h,db,c,{teachMask=bad,teachParked=bad})
				assert(again.state.teachParked==nil and again.state.teachMask==nil and H.public(again).teachMask==nil,"dropped: "..tostring(bad))
				h=again
			end
			local kept=rejoin(h,db,c,{teachMask=2^30+Teach.bit("reset")})
			assert(Teach.has(kept.state.teachMask,"reset")and bit32.band(kept.state.teachMask,2^30)~=0,"unknown bits kept")
			assert(Teach.valid({})and Teach.valid({teachMask=0,teachParked=3})and not Teach.valid({teachMask=-1})and not Teach.valid({teachParked="1"}))
		end)

		test("the coach write carries both masks in one transaction; repeats cost nothing; OR-only, never cleared",function()
			local h,db,c=fresh(true)
			local writes=c.writes
			assert(H.coachMark(h,Coach.bit("fillLine"),Teach.bit("deckTour"),0))
			assert(c.writes==writes+1,"one write for both")
			assert(Coach.has(db.player_1.hatching.coachMask,"fillLine")and Teach.has(db.player_1.hatching.teachMask,"deckTour"))
			writes=c.writes
			local same,why=H.coachMark(h,Coach.bit("fillLine"),Teach.bit("deckTour"))
			assert(same and why=="AlreadySaved"and c.writes==writes)
			assert(H.coachMark(h,0,Teach.bit("done"),0)and H.coachMark(h,0,Teach.bit("level")))
			assert(Teach.has(h.state.teachMask,"deckTour")and Teach.has(h.state.teachMask,"done")and Teach.has(h.state.teachMask,"level"))
			assert(H.coachMark(h,nil,0,2^8)and h.state.teachParked==2^8,"the thermometer")
			for _,bad in ipairs({{0,0,0},{-1,0,0},{0,1.5,0},{0,0,"2"},{0,2^31,0}})do
				local okBad,whyBad=H.coachMark(h,bad[1],bad[2],bad[3]);assert(not okBad and whyBad=="InvalidCoach")
			end
			assert(Teach.has(H.public(h).teachMask,"done"))
			local again=rejoin(h,db,c);assert(Teach.has(again.state.teachMask,"done")and Teach.has(again.state.teachMask,"deckTour"),"survives a reload")
		end)

		test("latched in the write that makes the fact true: a ribbon, a pot, a snack, the twelfth round (moved on)",function()
			Dash.inject({flags={GardenDash=true},studio=true})
			local h=fresh(true)
			assert(H.dashResults(h,"race1",{{kind="race",mode="fun",place=1,us=35000000,inputs=9,seed=1,prize=true}}))
			assert(Teach.has(h.state.teachMask,"dash"),"the ribbon's own write latched dash")
			Dash.inject(nil)
			-- the pure latch every transaction runs (a pot used, a snack's boost, rounds)
			local s={petHues={pip={main={rose=1}}},petBoosts={pip={heart={{mult=2,left=50}}}},stats={rounds=12}}
			assert(Teach.latch(s)>0 and Teach.has(s.teachMask,"dress")and Teach.has(s.teachMask,"snacks")and Teach.has(s.teachMask,"done"))
			s.petHues.pip.main.rose=0;s.petBoosts=nil
			assert(Teach.latch(s)==0 and Teach.has(s.teachMask,"dress")and Teach.has(s.teachMask,"snacks"),"Back to white, a boost used up: the latch stays")
			local m0,mdb,mc=fresh(true)
			local st=copy(mdb.player_1.hatching.stats);st.rounds=11
			Onboard.inject({flags={OnboardingV3=true},studio=true,teach=false}) -- load without the backfill: rounds 11 is not yet moved on anyway
			local m=rejoin(m0,mdb,mc,{stats=st})
			Onboard.inject({flags={OnboardingV3=true},studio=true})
			assert(not Teach.has(m.state.teachMask,"done"))
			local seq=m.nextRunSeq
			assert(H.award(m,seq,8,{family="pip",day=H.public(m).dailyDay,success=true,clean=true,score=900,chain=4,clears=2,drops=24}))
			assert((m.state.stats.rounds or 0)>=12 and Teach.has(m.state.teachMask,"done"),"round twelve's own award graduates (moved on)")
		end)

		test("backfill at load: veteran (owned a pet, never owed), moved on, and the facts already true; a new player keeps the course",function()
			local v,vdb,vc=fresh(false)
			local back=rejoin(v,vdb,vc)
			assert(Teach.has(back.state.teachMask,"done"),"never owed the chain: veteran, graduated")
			local h,db,c=fresh(true)
			local stats=copy(db.player_1.hatching.stats);stats.rounds=2;stats.fetches=1
			local again=rejoin(h,db,c,{stats=stats,coachMask=Coach.bit("menuSeen")+Coach.bit("quests"),dash={ribbons={gold=1}}})
			local mask=again.state.teachMask
			for _,id in ipairs({"deck","deckTour","tipNext","tipGoal","level","menu","quests","park","dash"})do assert(Teach.has(mask,id),id)end
			assert(not Teach.has(mask,"done")and not Teach.has(mask,"tipChain")and not Teach.has(mask,"reset"),"owed, two rounds: still in the course")
			local moved,mdb,mc=fresh(true)
			local ms=copy(mdb.player_1.hatching.stats);ms.rounds=12
			assert(Teach.has(rejoin(moved,mdb,mc,{stats=ms}).state.teachMask,"done"),"twelve rounds at load: moved on")
			local n,ndb,nc=fresh(true)
			local needs=rejoin(n,ndb,nc,{coachMask=Coach.bit("needHi")+Coach.bit("needDeck")})
			assert(Teach.has(needs.state.teachMask,"needs")and not Teach.has(needs.state.teachMask,"done"),"the guide done: the need bubbles are over, the lessons are not")
			local w,wdb,wc=fresh(true)
			assert(not Teach.has(rejoin(w,wdb,wc,{coachMask=Coach.bit("needHi")}).state.teachMask,"needs"),"a guide half done is picked up again")
		end)

		test("Onboard teach off: no backfill and no latch (the save is the build's before it); a field already there is kept",function()
			Onboard.inject({flags={OnboardingV3=true},studio=true,teach=false})
			local v,vdb,vc=fresh(false)
			local back=rejoin(v,vdb,vc)
			assert(back.state.teachMask==nil and vdb.player_1.hatching.teachMask==nil,"off: nothing written")
			local k=rejoin(back,vdb,vc,{teachMask=latched("dress","done")})
			assert(H.grantPurchase(k,"fund-off",3,false)and vdb.player_1.hatching.teachMask==latched("dress","done"),"off: kept as it was")
			Onboard.inject({flags={OnboardingV3=true},studio=true})
		end)
	end)
	Onboard.inject(nil);Dash.inject(nil)
	assert(ok,problem)
	return {passed=#cases,cases=cases}
end
