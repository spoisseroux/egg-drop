-- v1 track A onboarding (ONBOARDING-V1-SCOPE-2026-11-13, Spencer's accepted decisions): the
-- optional `coachMask` save field (missing or invalid reads 0, never fails a load, no version
-- bump), each coach bit saved once and never cleared, the Welcome round's Stars paid with the
-- Bear in the starter transaction, the +2 finish pay for a missed round with a goal met (inside
-- the award transaction), and the safe (no-fail) Welcome board. Isolated adapters only.
-- Usage (Server): require(ServerScriptService.Server.ZZSpecs.CoachMask)(ServerScriptService.Server)
return function(server)
	local H=require(server.HatchProgress)
	local Round=require(server.BoardRound)
	local Shared=game:GetService("ReplicatedStorage").Shared
	local Coach=require(Shared.CoachMarks)
	local Payout=require(Shared.HeatPayout)
	local Config=require(Shared.BoardConfig)
	local cases={}
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
	local function reseed(db,field,value)
		local seed=copy(db.player_1);seed.hatching[field]=value;seed.hatching.lease={token="",expiresAt=0};return seed
	end
	local function summary(h,overrides)
		local s={family="pip",day=H.public(h).dailyDay,success=false,clean=false,score=100,chain=1,clears=0,drops=24,heat="easy",goalsMet=1}
		for k,v in pairs(overrides or {})do s[k]=v end
		return s
	end

	test("missing coachMask is valid and reads 0; a malformed one is dropped at load, never a failed load",function()
		local h,db=fixture()
		assert(h.status=="Ready"and h.state.coachMask==nil and H.valid(h.state))
		assert(H.public(h).coachMask==0,"public reads 0 when missing")
		for _,bad in ipairs({"x",-1,1.5,2^31,0/0,{1},true})do
			local again=fixture(reseed(db,"coachMask",bad))
			assert(again.status=="Ready","load survives coachMask="..tostring(bad))
			assert(again.state.coachMask==nil and H.public(again).coachMask==0,"malformed mask dropped: "..tostring(bad))
		end
		local kept=fixture(reseed(db,"coachMask",2^30+5))
		assert(kept.status=="Ready"and kept.state.coachMask==2^30+5,"bits from a later build are kept")
		assert(Coach.valid({})and Coach.valid({coachMask=0})and not Coach.valid({coachMask=-1})and not Coach.valid({coachMask="1"}))
	end)

	test("a coach bit saves once, ORs in, is never cleared, and repeats cost no write",function()
		local h,db,c=fixture()
		local fill,park=Coach.bit("fillLine"),Coach.bit("park")
		assert(H.coachMark(h,fill))
		assert(h.state.coachMask==fill and db.player_1.hatching.coachMask==fill)
		local writes=c.writes
		local ok,reason=H.coachMark(h,fill)
		assert(ok and reason=="AlreadySaved"and c.writes==writes,"already saved: no write")
		assert(H.coachMark(h,park))
		assert(h.state.coachMask==fill+park,"OR, never replace")
		assert(Coach.has(H.public(h).coachMask,"fillLine")and Coach.has(H.public(h).coachMask,"park"))
		assert(not Coach.has(H.public(h).coachMask,"hatch"))
		for _,bad in ipairs({0,-4,1.5,"4",2^31})do
			local okBad,why=H.coachMark(h,bad)
			assert(not okBad and why=="InvalidCoach","refuses "..tostring(bad))
		end
		-- Survives a reload, and a later save keeps it.
		local again=fixture(reseed(db,"coachMask",db.player_1.hatching.coachMask))
		assert(again.state.coachMask==fill+park)
	end)

	test("an ambiguous coach write resumes and commits exactly once",function()
		local h,db,c=fixture()
		local bit=Coach.bit("gardenIntro")
		c.failNext="after"
		local ok,reason=H.coachMark(h,bit)
		assert(not ok and reason=="Retrying"and h.pending)
		assert(db.player_1.hatching.coachMask==bit,"the write landed")
		assert(H.retry(h))
		assert(h.pending==nil and h.state.coachMask==bit)
		local ok2,reason2=H.coachMark(h,bit)
		assert(ok2 and reason2=="AlreadySaved")
	end)

	test("each card shows once: a saved or session-seen bit never shows again; veterans see none",function()
		local ctx={mask=0,seen={},totalWins=0,owned=1}
		for _,id in ipairs(Coach.Order)do
			assert(Coach.wants(id,ctx),id.." wanted on a fresh save")
			assert(not Coach.wants(id,{mask=Coach.with(0,id),seen={},totalWins=0,owned=1}),id.." saved: never again")
			assert(not Coach.wants(id,{mask=0,seen={[id]=true},totalWins=0,owned=1}),id.." seen this session: never again")
			assert(not Coach.wants(id,{mask=0,seen={},totalWins=Coach.VeteranWins,owned=1}),id.." veteran: none")
			assert(not Coach.wants(id,{mask=0,seen={},totalWins=0,owned=0}),id.." waits for the first pet")
		end
		-- Bits are saved data: unique and fixed.
		local used={}
		for _,id in ipairs(Coach.Order)do local b=Coach.Bits[id];assert(not used[b],"unique bit");used[b]=true end
		assert(Coach.Bits.fillLine==0 and Coach.Bits.gardenIntro==1 and Coach.Bits.questDone==9)
		assert(Coach.validId("park")and not Coach.validId("nope")and not Coach.validId(4))
	end)

	test("the Welcome round pays its Stars with the Bear, once, in the starter transaction",function()
		local h=fixture(nil,{})
		local before=h.state.nectar
		assert(before==6,"a fresh save still starts with 6")
		local writes
		assert(H.grantStarter(h))
		assert(h.state.nectar==before+Coach.WelcomeStars,"Bear and first Stars together")
		assert(Coach.WelcomeStars==14 and h.state.nectar>=require(game:GetService("ReplicatedStorage").Shared.ToyCatalog).Cost,"a fresh save can afford its first Toy Egg after the Welcome round")
		assert(h.state.lastHatch.starter and h.state.lastHatch.stars==Coach.WelcomeStars,"the reveal receipt carries the Stars")
		assert(h.state.stats.starsEarned==Coach.WelcomeStars,"Welcome Stars are earned Stars")
		local ok,reason=H.grantStarter(h)
		assert(ok and reason=="AlreadyOwned"and h.state.nectar==before+Coach.WelcomeStars,"never paid twice")
		assert(H.command(h,"ack",h.state.lastHatch.id,h.state.revision))
		-- A save that already owns the Bear is not paid.
		local owner=fixture(nil,{rank=1})
		local wallet=owner.state.nectar
		assert(H.grantStarter(owner)and owner.state.nectar==wallet)
	end)

	test("+2 Stars for a missed round with a goal met, inside the award transaction",function()
		local h=fixture()
		assert(Payout.missStars(false,1)==2 and Payout.missStars(false,2)==2 and Payout.missStars(false,0)==0 and Payout.missStars(true,2)==0)
		local w=h.state.nectar
		assert(H.award(h,1,0,summary(h,{goalsMet=1,heat="easy"})))
		assert(h.state.nectar==w+2 and h.state.lastRunReward.missPay==2 and h.state.lastRunReward.total==2,"Easy miss with a goal: +2")
		w=h.state.nectar
		assert(H.award(h,2,0,summary(h,{goalsMet=1,heat="hard"})))
		assert(h.state.nectar==w+2,"flat on Hard (no heat multiplier)")
		w=h.state.nectar
		assert(H.award(h,3,0,summary(h,{goalsMet=0,heat="medium"})))
		assert(h.state.nectar==w and h.state.lastRunReward.missPay==0,"no goal met: nothing")
		w=h.state.nectar
		assert(H.award(h,4,0,summary(h,{goalsMet=2,drops=9})))
		assert(h.state.nectar==w+2,"an overflowed round with goals met is a miss too")
		w=h.state.nectar
		assert(H.award(h,5,0,summary(h,{goalsMet=1}),{multiplier=2,bonus=1}))
		assert(h.state.nectar==w+5,"2x pass doubles it, Supporter adds 1 (as any finished round)")
		local ok,reason=H.award(h,5,0,summary(h,{goalsMet=1}))
		assert(ok and reason=="AlreadyAwarded"and h.state.nectar==w+5,"one payout per round")
		w=h.state.nectar
		assert(H.award(h,6,6,summary(h,{success=true,goalsMet=2,heat="easy"})))
		assert(h.state.nectar==w+5 and h.state.lastRunReward.missPay==0,"an Easy win is unchanged (5)")
		assert(h.state.stats.starsEarned>=2+2+2+5+5,"miss pay counts as earned")
	end)

	test("the Welcome board is safe: the fill line never ends it; a field round still can",function()
		local function pile(n)
			local eggs={}
			for i=1,n do table.insert(eggs,{position={X=0,Y=Config.OverflowY+1},radius=1,enteredTray=true,roundAge=5})end
			return eggs
		end
		local safe=Round.new({safe=true})
		for _=1,600 do safe:step(pile(4),1/60,10)end
		assert(not safe.over and safe.danger==0 and safe.graceLeft==0,"Welcome never overflows")
		local full=pile(Config.MaxEggs)
		local capped=Round.new({safe=true});capped:step(full,1/60,40)
		assert(not capped.over and capped.danger==0 and capped.graceLeft==0,"Welcome cap requests a tray refresh without ending the run")
		assert(require(server.WelcomeSeed).needsRefresh({eggs=full}),"the full Welcome tray must trigger its host refresh")
		local fieldCap=Round.new();fieldCap:step(pile(Config.MaxEggs),1/60,40)
		assert(fieldCap.over,"the cap still ends an ordinary field round")
		local normal=Round.new()
		for _=1,600 do normal:step(pile(4),1/60,10)end
		assert(normal.over,"a normal round still overflows")
	end)

	-- Overnight 2026-11-14, slice E: the "a friend arrived" card for the earned pet is bit 10.
	test("petArrived is bit 10: it saves, survives a reload and never disturbs the older bits",function()
		assert(Coach.Bits.petArrived==10 and Coach.bit("petArrived")==1024 and Coach.validId("petArrived"))
		assert(Coach.Order[11]=="petArrived","appended, never renumbered")
		-- Things to do: 11 to 13 after it. A server without them drops the ids and keeps the bits.
		assert(Coach.Bits.parkInvite==11 and Coach.Bits.dashIntro==12 and Coach.Bits.dashSeen==13 and Coach.Order[14]=="dashSeen"and Coach.Bits.findsIntro==14 and Coach.Order[15]=="findsIntro")
		-- Onboarding v3: 15 to 26, station tips on their own bits (never hatch/style/companions/park), within 31 bits.
		local v3={"tipHatch","tipStyle","tipCompanions","tipPark","tipNest","needHi","needToy","needDeck","needNest","needPark","nestIntro","weekDone"}
		for i,id in ipairs(v3)do assert(Coach.Bits[id]==14+i and Coach.Order[15+i]==id and Coach.validId(id),id)end
		assert(#Coach.Order==29 and Coach.Bits.nestHelp==27 and Coach.Bits.menuSeen==28 and Coach.Order[29]=="menuSeen"and Coach.Bits.weekDone<=30 and Coach.bit("weekDone")<=Coach.Max)
		assert(Coach.Bits.hatch==2 and Coach.Bits.style==3 and Coach.Bits.companions==4 and Coach.Bits.park==7,"the station bits are untouched")
		local all=0;for _,id in ipairs(Coach.Order)do all=Coach.with(all,id)end;assert(all==2^29-1 and Coach.valid({coachMask=all}))
		local kept=Coach.merge(Coach.bit("dashSeen"),Coach.bit("fillLine"));assert(Coach.valid({coachMask=kept})and Coach.sanitize(kept)==kept)
		local h,db=fixture()
		local quests=Coach.bit("questDone")
		assert(H.coachMark(h,quests))
		assert(H.coachMark(h,Coach.bit("petArrived")))
		assert(h.state.coachMask==quests+1024 and Coach.has(H.public(h).coachMask,"petArrived")and Coach.has(H.public(h).coachMask,"questDone"))
		local again=fixture(reseed(db,"coachMask",db.player_1.hatching.coachMask))
		assert(again.status=="Ready"and again.state.coachMask==quests+1024 and H.valid(again.state))
		local ok,reason=H.coachMark(again,1024)
		assert(ok and reason=="AlreadySaved")
		-- The card waits for a pet, like every other one-time card, and shows once.
		assert(Coach.wants("petArrived",{mask=0,seen={},totalWins=0,owned=2}))
		assert(not Coach.wants("petArrived",{mask=1024,seen={},totalWins=0,owned=2}))
	end)

	-- Onboarding part 2 (ARCH-REVIEW-P2 1, lesson C): menuSeen is bit 28, gated by Onboard "teach" (off on live), saved
	-- OR-only like every bit, and kept by a build that does not know it.
	test("menuSeen is bit 28: gated by teach, saved OR-only, kept by an older build",function()
		assert(Coach.Bits.menuSeen==28 and Coach.bit("menuSeen")==2^28 and Coach.validId("menuSeen")and Coach.Order[29]=="menuSeen")
		assert(Coach.Gated.menuSeen=="teach"and Coach.GateOwner.teach=="Onboard","refused while the teach switch is off")
		local Onboard=require(Shared.Onboard)
		assert(table.find(Onboard.Features,"teach")==#Onboard.Features and Onboard.attribute("teach")=="Onboard_teach"and Onboard.key("teach")=="onboard_teach",
			"appended, nothing renumbered")
		assert(Onboard.Events.TeachShown and Onboard.Events.TeachDone)
		assert(Onboard.inject({flags={OnboardingV3=true},place=Onboard.PlaceId,studio=true,teach=false}))
		assert(not Coach.allows("menuSeen"),"teach off: refused")
		assert(Onboard.inject({flags={OnboardingV3=true},place=Onboard.PlaceId,studio=true}))
		assert(Coach.allows("menuSeen"),"teach on (beta, Studio): allowed")
		assert(Onboard.inject({flags={OnboardingV3=false},place=1,studio=false}))
		assert(not Coach.allows("menuSeen"),"the build ceiling (live): refused")
		Onboard.inject(nil)
		-- Bits 29 and 30 are the last two (plan a second mask field before spending them); unknown bits survive a load.
		local mask=Coach.with(Coach.bit("nestHelp"),"menuSeen")
		assert(Coach.sanitize(mask)==mask and Coach.has(mask,"menuSeen")and Coach.has(mask,"nestHelp"))
		local later=Coach.merge(mask,2^30);assert(Coach.sanitize(later)==later and Coach.valid({coachMask=later}))
		local h=fixture()
		assert(H.coachMark(h,Coach.bit("menuSeen")))
		assert(Coach.has(H.public(h).coachMask,"menuSeen"))
		local ok,reason=H.coachMark(h,Coach.bit("menuSeen"))
		assert(ok and reason=="AlreadySaved","OR-only: a second mark changes nothing")
	end)

	test("teach more (ARCH-REVIEW-TEACH 4): a graduated save gets no teaching card; the four news cards stay",function()
		local ctx={mask=0,totalWins=0,owned=1,graduated=true}
		for _,id in ipairs({"gardenIntro","parkInvite","needHi","menuSeen"})do
			assert(not Coach.wants(id,ctx),"graduated: "..id)
			assert(Coach.wants(id,{mask=0,totalWins=0,owned=1}),"in the course: "..id)
		end
		for _,id in ipairs({"petArrived","questDone","weekDone","nestIntro"})do assert(Coach.wants(id,ctx),"kept: "..id)end
		-- beta 44 (ARCH-REVIEW-SIMPLIFY 7): graduation is at about minute 5 now; a screen's first-use cards stay after it
		for _,id in ipairs({"fillLine","item","hatch","style","companions","quests","book","park","tipHatch","tipStyle","tipCompanions","tipPark","tipNest"})do
			assert(Coach.wants(id,ctx),"kept after graduation: "..id)
			assert(not Coach.wants(id,{mask=Coach.bit(id),totalWins=0,owned=1,graduated=true}),"still once: "..id)
		end
		assert(not Coach.wants("hatch",{mask=0,totalWins=9,owned=1,graduated=true}),"a veteran: still none")
		assert(Coach.stage({owned=1,graduated=true,mask=0})=="free","graduated: no garden step")
	end)

	return{passed=#cases,cases=cases}
end
