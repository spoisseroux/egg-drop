-- Growth cuts (GROWTH-CUTS-LOOK 2026-11-25 section 3): the Welcome bonus. +12, +4, +4 on a brand-new save's first
-- three finished field rounds, win or lose, 20 per save at most, flat (no heat, 2x pass or Supporter), paid inside
-- the award transaction and saved in `starterRounds`, so a retry, an ambiguous write, a rejoin or a second award
-- never pays twice; an existing save gets nothing; a malformed field never fails a load. Isolated adapters only.
-- Usage (Server): require(ServerScriptService.Server.ZZSpecs.StarterBonus)(ServerScriptService.Server)
-- Offline: the growth harness (see artifacts/growth-2026-11-26/GROWTH-CUTS-PLAN.md, Verification).
return function(server)
	local H=require(server.HatchProgress)
	local Shared=game:GetService("ReplicatedStorage").Shared
	local Bonus=require(Shared.StarterBonus)
	local Flags=require(Shared.FeatureFlags)
	local cases={}
	local function copy(v)if type(v)~="table"then return v end;local r={};for k,x in pairs(v)do r[k]=copy(x)end;return r end
	local function test(name,run)run();table.insert(cases,name)end
	-- starter: true opts this adapter in, as the live one does (defaultAdapter); nil keeps old spec payouts.
	-- Each fixture has its own operation ids (live ids are GUIDs): a reloaded save must never see a new
	-- operation's id already in its lastOperation.
	local fixtures=0
	local function fixture(seed,starter)
		fixtures+=1
		local db,c={},{now=1700000000,serial=0,writes=0,failNext=nil,prefix="f"..fixtures.."op"}
		local adapter={
			now=function()return c.now end,
			guid=function()c.serial+=1;return c.prefix..c.serial end,
			random=function()return .1 end,
			wait=function()end,
			starterBonus=if starter==false then nil else true,
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
	local function summary(h,overrides)
		local s={family="pip",day=H.public(h).dailyDay,success=false,clean=false,score=100,chain=1,clears=0,drops=24,heat="medium",goalsMet=0}
		for k,v in pairs(overrides or {})do s[k]=v end
		return s
	end
	local WIN={success=true,goalsMet=2}

	test("the switch is on for the live build and the numbers are 12, 4, 4 with a 20 cap",function()
		assert(Flags.StarterBonus==true)
		assert(Bonus.Rewards[1]==12 and Bonus.Rewards[2]==4 and Bonus.Rewards[3]==4 and Bonus.Cap==20 and Bonus.Rounds==3)
		assert(Bonus.amount(0)==12 and Bonus.amount(1)==4 and Bonus.amount(2)==4 and Bonus.amount(3)==0)
	end)

	test("pure rules: missing field is new only with no saved round; malformed reads as played; never past 3",function()
		assert(Bonus.paid({stats={rounds=0},lastAwardSeq=0})==0,"a new save")
		assert(Bonus.paid({stats={rounds=4},lastAwardSeq=4})==3,"an existing player")
		assert(Bonus.paid({stats={rounds=0},lastAwardSeq=2})==3,"a pre-v11 save whose counters started at 0")
		assert(Bonus.paid({stats={rounds=0}})==3 and Bonus.paid({})==3 and Bonus.paid(nil)==3)
		assert(Bonus.paid({starterRounds=1,stats={rounds=9},lastAwardSeq=9})==1,"the field wins over the counters")
		assert(Bonus.paid({starterRounds=200})==3,"a later build's count")
		assert(Bonus.valid({})and Bonus.valid({starterRounds=0})and Bonus.valid({starterRounds=255}))
		for _,bad in ipairs({-1,1.5,256,"1",true,{},0/0})do
			assert(not Bonus.valid({starterRounds=bad}),"invalid: "..tostring(bad))
			assert(Bonus.sanitize(bad)==nil)
		end
		local s={stats={rounds=0},lastAwardSeq=0}
		assert(Bonus.apply(s)==12 and s.starterRounds==1 and Bonus.apply(s)==4 and Bonus.apply(s)==4 and s.starterRounds==3)
		assert(Bonus.apply(s)==0 and s.starterRounds==3,"nothing after the third")
		local old={stats={rounds=5},lastAwardSeq=5}
		assert(Bonus.apply(old)==0 and old.starterRounds==nil,"an ineligible save gets no field written")
	end)

	test("a new save: +12, +4, +4 on its first three rounds, win or lose, then nothing; 20 in all",function()
		local h=fixture()
		assert(h.status=="Ready"and h.state.starterRounds==nil and h.state.stats.rounds==0)
		local w=h.state.nectar
		assert(H.award(h,1,0,summary(h)))
		local r=h.state.lastRunReward
		assert(h.state.nectar==w+12 and r.starter==12 and r.total==12 and r.roundStars==0 and r.bonus==0,"a lost round with no goal pays the bonus alone")
		assert(h.state.starterRounds==1 and h.state.stats.rounds==1)
		w=h.state.nectar
		assert(H.award(h,2,6,summary(h,WIN)))
		r=h.state.lastRunReward
		assert(h.state.nectar==w+6+4 and r.starter==4 and r.total==10 and r.roundStars==6,"a Medium win: 6 + 4")
		w=h.state.nectar
		assert(H.award(h,3,0,summary(h,{goalsMet=1})))
		assert(h.state.nectar==w+2+4 and h.state.lastRunReward.starter==4 and h.state.starterRounds==3,"a miss with a goal: 2 + 4")
		w=h.state.nectar
		assert(H.award(h,4,6,summary(h,WIN)))
		assert(h.state.nectar==w+6 and h.state.lastRunReward.starter==0 and h.state.starterRounds==3,"the fourth round pays no bonus")
		assert(h.state.stats.starsEarned>=12+10+6+6,"the bonus counts as earned")
	end)

	test("flat: the 2x pass, Supporter and Hard never touch the bonus; `bonus` keeps its meaning",function()
		local h=fixture()
		local w=h.state.nectar
		assert(H.award(h,1,8,summary(h,{success=true,clean=true,goalsMet=2,heat="hard"}),{multiplier=2,bonus=1}))
		local r=h.state.lastRunReward
		assert(r.starter==12 and r.roundStars==12,"Hard tidy is 12")
		assert(r.total==12*2+1+12 and h.state.nectar==w+r.total,"(12 x 2 + 1) + 12 flat")
		assert(r.bonus==r.total-r.roundStars-r.starter,"bonus = the pass and Supporter share only")
	end)

	test("one payout per round: a repeat, an ambiguous write and the close-drain path never pay twice",function()
		local h,db,c=fixture()
		local w=h.state.nectar
		assert(H.award(h,1,0,summary(h)))
		local ok,why=H.award(h,1,0,summary(h))
		assert(ok and why=="AlreadyAwarded"and h.state.nectar==w+12,"a repeat")
		-- Round 2's response is lost after the store wrote it: the retry proves the commit, pays nothing more.
		c.failNext="after"
		local first,reason=H.award(h,2,0,summary(h))
		assert(not first and reason=="Retrying"and h.pending~=nil)
		assert(db.player_1.hatching.starterRounds==2,"the write landed")
		assert(H.retry(h))
		assert(h.state.starterRounds==2 and h.state.nectar==w+12+4,"proved, not paid again")
		-- Round 3 fails before the write: the retry pays it once, from the same candidate.
		c.failNext="before"
		local again=H.award(h,3,0,summary(h))
		assert(not again and h.pending~=nil and db.player_1.hatching.starterRounds==2)
		assert(H.award(h,3,0,summary(h)),"the drain path resumes the same pending award")
		assert(h.state.starterRounds==3 and h.state.nectar==w+20,"20 in all")
	end)

	test("a rejoin (or another server) reads the saved count and pays the next step or nothing",function()
		local h,db=fixture()
		assert(H.award(h,1,0,summary(h)))
		local again,db2=fixture(reseed(db,{}))
		assert(again.status=="Ready"and again.state.starterRounds==1)
		local w=again.state.nectar
		assert(H.award(again,again.state.lastAwardSeq+1,0,summary(again)))
		assert(again.state.nectar==w+4 and again.state.starterRounds==2,"the second step, not the first again")
		local third,db3=fixture(reseed(db2,{}))
		assert(H.award(third,third.state.lastAwardSeq+1,0,summary(third))and third.state.starterRounds==3)
		local fourth=fixture(reseed(db3,{}))
		w=fourth.state.nectar
		assert(H.award(fourth,fourth.state.lastAwardSeq+1,0,summary(fourth)))
		assert(fourth.state.nectar==w and fourth.state.starterRounds==3,"done for good")
	end)

	test("an existing player (rounds saved, no field) gets nothing and no field is written",function()
		local h,db=fixture(nil,false)
		assert(H.award(h,1,6,summary(h,WIN))and H.award(h,2,6,summary(h,WIN)))
		assert(h.state.starterRounds==nil and h.state.lastRunReward.starter==0,"switch off for this adapter: today's payout")
		local live=fixture(reseed(db,{}))
		local w=live.state.nectar
		assert(H.award(live,3,0,summary(live)))
		assert(live.state.nectar==w and live.state.starterRounds==nil and live.state.lastRunReward.starter==0)
	end)

	test("a malformed starterRounds is dropped at load, never a failed load, and then reads as played",function()
		local h,db=fixture()
		assert(H.award(h,1,6,summary(h,WIN)))
		for _,bad in ipairs({"x",-1,1.5,256,{1},true})do
			local again=fixture(reseed(db,{starterRounds=bad}))
			assert(again.status=="Ready","load survives starterRounds="..tostring(bad))
			assert(again.state.starterRounds==nil and H.valid(again.state))
			local w=again.state.nectar
			assert(H.award(again,again.state.lastAwardSeq+1,0,summary(again)))
			assert(again.state.nectar==w,"no bonus after a dropped field (rounds already saved)")
		end
		local later=fixture(reseed(db,{starterRounds=9}))
		assert(later.status=="Ready"and later.state.starterRounds==9,"a later build's count is kept")
	end)

	return {passed=#cases,cases=cases}
end
