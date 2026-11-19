-- v2 slice S1: pet stats core (StatCatalog curve, StatState grant / Bonus XP / seed / repair,
-- HatchProgress load seeding). Isolated adapters only; no DataStore.
-- Usage (Server): require(ServerScriptService.Server.ZZSpecs.StatState)(ServerScriptService.Server)
return function(server)
	local H=require(server.HatchProgress)
	local S=require(server.StatState)
	local Shared=game:GetService("ReplicatedStorage").Shared
	local C=require(Shared.StatCatalog)
	local Eggs=require(Shared.EggCatalog)
	local cases={}
	local function test(name,run)run();table.insert(cases,name)end
	local function copy(v)if type(v)~="table"then return v end;local r={};for k,x in pairs(v)do r[k]=copy(x)end;return r end
	local function fixture(seed,start)
		local db,c={},{now=start or 1700000000,serial=0}
		local adapter={
			now=function()return c.now end,
			guid=function()c.serial+=1;return "op"..c.serial end,
			random=function()return .1 end,
			wait=function()end,
			update=function(key,transform)
				local value=transform(copy(db[key]))
				if value then db[key]=copy(value)end
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
	local pip=Eggs.bit("pip")

	test("the curve matches the scope table and levels round-trip",function()
		for level,xp in pairs({[1]=0,[2]=14,[3]=32,[5]=81,[10]=288,[25]=1785,[50]=8331,[75]=21970,[90]=34534,[99]=43913})do
			assert(C.xpFor(level)==xp,"xpFor "..level)
		end
		for level=1,99 do
			local xp=C.xpFor(level)
			assert(C.levelFor(xp)==level,"levelFor at "..level)
			if level>1 then assert(C.levelFor(xp-1)==level-1,"just below "..level)end
		end
		assert(C.levelFor(10^7)==99 and C.levelFor(-5)==1 and C.levelFor(0/0)==1)
		assert(C.totalLevel({})==6 and C.totalLevel({heart=43913,power=43913,energy=43913,jump=43913,speed=43913,smarts=43913})==594)
		local p=C.progress(300);assert(p.level==10 and p.into==12 and p.need==C.xpFor(11)-288)
		assert(C.tier(1)=="Seedling"and C.tier(25)=="Sprout"and C.tier(99)=="Starbloom"and C.keeperTier(594)=="Garden Star"and C.keeperTier(60)=="Sprout Keeper")
	end)

	test("grant: owned pets only, Bonus XP doubles the first 100 a day, banks to 300, never on a rollback",function()
		local state={inventoryMask=pip}
		assert(S.grant(state,"puddle","power",10,"100")==0,"not owned")
		assert(S.grant(state,"pip","nope",10,"100")==0 and S.grant(state,"pip","power",-1,"100")==0 and S.grant(state,"pip","power",0/0,"100")==0)
		assert(S.grant(state,"pip","power",60,"100")==120,"all doubled")
		assert(S.grant(state,"pip","power",60,"100")==100,"40 doubled, 20 plain")
		assert(S.grant(state,"pip","power",10,"100")==10,"bonus used up today")
		assert(S.grant(state,"pip","heart",10,"100")==20,"each stat has its own bonus")
		assert(S.xp(state,"pip","power")==230 and S.valid(state))
		-- three days later: power banks 0+300 (capped), heart 90+300 -> 300
		assert(S.grant(state,"pip","power",500,"103")==800,"300 banked")
		assert(state.statBonus.day=="103"and state.statBonus.left.power==0 and state.statBonus.left.heart==300)
		-- clock rollback: no bonus, day stays
		assert(S.grant(state,"pip","heart",10,"101")==10 and state.statBonus.day=="103")
		-- noBonus (treat XP)
		assert(S.grant(state,"pip","heart",10,"103",true)==10 and state.statBonus.left.heart==300)
		assert(S.valid(state))
		-- the cap
		local big={inventoryMask=pip,petStats={pip={power=C.MaxXP-5}}}
		assert(S.grant(big,"pip","power",100,"5",true)==5 and S.xp(big,"pip","power")==C.MaxXP)
	end)

	test("valid and sanitize: tolerant, keep well-formed unknown ids, repair the rest",function()
		assert(S.valid({})and S.valid({petStats={},statBonus={day="5",left={}},statsSeed=1}))
		assert(S.valid({petStats={futurePet={futureStat=5}}}),"unknown well-formed ids are valid")
		assert(not S.valid({petStats={pip={power=-1}}})and not S.valid({petStats={pip={power=1.5}}})and not S.valid({statBonus={day="x",left={}}}))
		local state={petStats={pip={power=12.7,heart="x",futureStat=4},[5]={power=1},bad="no"},statBonus={day="7",left={power=-2,heart=50}},statsSeed="z"}
		S.sanitize(state)
		assert(state.petStats.pip.power==12 and state.petStats.pip.heart==nil and state.petStats.pip.futureStat==4)
		assert(state.petStats.bad==nil and state.petStats[5]==nil)
		assert(state.statBonus.left.power==nil and state.statBonus.left.heart==50 and state.statsSeed==nil)
		assert(S.valid(state))
	end)

	test("seed: past play is credited to the Bear once, on load, and never again",function()
		local h,db,c=fixture()
		assert(h.state.statsSeed==1,"a fresh save is marked seeded")
		local stats=copy(db.player_1.hatching.stats)
		stats.merges=100;stats.tierFive=2;stats.rounds=10;stats.winsEasy=3;stats.winsMedium=2;stats.winsHard=1;stats.tidyWins=1
		stats.parkGames=7;stats.fetches=3;stats.questsDaily=4;stats.questsWeekly=1
		c.now+=200
		local h2,db2=fixture(reseed(db,{inventoryMask=pip,stats=stats,bond={pip=25},stamps=2,petStats=NONE,statsSeed=NONE,
			book={claimed={"a","b"},found=5}}),c.now)
		local got=h2.state.petStats.pip
		assert(got.power==100+2*5,"power "..tostring(got.power))
		assert(got.energy==10*6+3*10+2*15+24+6,"energy "..tostring(got.energy))
		assert(got.heart==100 and got.jump==(7-3)*6 and got.speed==15,"heart/jump/speed")
		assert(got.smarts==4*30+100+2*20+2*25+2*60,"smarts "..tostring(got.smarts))
		assert(db2.player_1.hatching.statsSeed==1 and db2.player_1.hatching.petStats.pip.power==110,"written by the load")
		-- more play, then reload: no second credit
		local more=copy(db2.player_1.hatching.stats);more.merges=500
		local h3=fixture(reseed(db2,{stats=more}),c.now+200)
		assert(h3.state.petStats.pip.power==110,"never seeded twice")
		-- a save with petStats but a lost flag is not reseeded
		local h4=fixture(reseed(db2,{stats=more,statsSeed=NONE}),c.now+400)
		assert(h4.state.petStats.pip.power==110)
		-- without the Bear: marked seeded, nothing credited
		local h5=fixture(reseed(db,{inventoryMask=0,stats=stats,petStats=NONE,statsSeed=NONE}),c.now+600)
		assert(h5.state.statsSeed==1 and h5.state.petStats==nil)
		assert(H.valid(h2.state)and H.valid(h3.state))
	end)

	test("a malformed stat field never fails a load, and public shows owned pets",function()
		local h,db,c=fixture()
		local h2=fixture(reseed(db,{inventoryMask=pip,petStats={pip={power="x",heart=50}},statBonus="bad",statsSeed=1}),c.now+200)
		assert(h2.status=="Ready","load ok: "..tostring(h2.status))
		assert(h2.state.petStats.pip.heart==50 and h2.state.petStats.pip.power==nil and h2.state.statBonus==nil)
		local p=H.public(h2).petStats
		assert(p.pets.pip and p.pets.pip.level.heart==C.levelFor(50)and p.pets.pip.total==5+C.levelFor(50))
		assert(p.bonus.power==C.Bonus.Daily)
	end)

	-- v2 slice S2: XP from existing transactions (never fails them; Bonus XP doubles the first 100 a day).
	test("S2: a round, petting, park, fetch and the daily stamp grant stats to the pet",function()
		local h0,db,c=fixture()
		local h,db2=fixture(reseed(db,{inventoryMask=pip,dailyClaimDay="0"}),c.now+200)
		local function summary(overrides)
			local x={family="pip",day=H.public(h).dailyDay,success=true,clean=false,score=100,chain=1,clears=0,drops=24,heat="easy",goalsMet=2}
			for k,v in pairs(overrides or {})do x[k]=v end;return x
		end
		local xp=function(stat)return S.xp(h.state,"pip",stat)end
		assert(H.award(h,1,6,summary({merges=10,chain=3,maxTier=5,clears=1,heat="hard",goalsMet=2}),nil,"pip"))
		-- power 10+2*2+5+8=27, energy 6+2*3+24=36, heart 1; all doubled by Bonus XP
		assert(xp("power")==54 and xp("energy")==72 and xp("heart")==2,"round "..xp("power").." "..xp("energy").." "..xp("heart"))
		local stats=h.state.lastRunReward.stats
		assert(stats and stats.power==54 and stats.energy==72 and stats.heart==2,"results strip gains")
		local again=table.pack(H.award(h,1,6,summary({merges=10}),nil,"pip"))
		assert(again[2]=="AlreadyAwarded"and xp("power")==54,"a replayed round never grants twice")
		-- power is capped per round: 200 merges -> 150, plus the 73 bonus left today
		assert(H.award(h,2,0,summary({success=false,merges=200,goalsMet=0}),nil,"pip"))
		assert(xp("power")==54+150+73,"cap "..xp("power"))
		-- no pet: nothing granted, the award still saves
		local before=xp("energy")
		assert(H.award(h,3,0,summary({success=false,goalsMet=0}),nil,nil)and xp("energy")==before)
		-- petting
		assert(H.awardPet(h,H.petCandidate(h,"lease-1","pip")))
		assert(xp("heart")==2+2+4,"petting "..xp("heart")) -- two rounds (+1 each, doubled) then a pet (+2, doubled)
		-- park: 3 activities, 1 of them a fetch
		assert(H.parkPlay(h,"park1",3,"pip",1))
		assert(xp("jump")==((3-1)*6+20)*2 and xp("speed")==5*2,"park "..xp("jump").." "..xp("speed")) -- 3 activities complete the Play date (+20)
		-- the daily stamp, to the pet that is out
		h.statPetOf=function()return "pip"end
		assert(H.command(h,"daily",H.public(h).dailyDay,h.state.revision))
		assert(xp("smarts")==20*2,"stamp "..xp("smarts"))
		assert(H.valid(h.state)and S.valid(h.state))
		assert(db2.player_1.hatching.petStats.pip.smarts==40,"saved")
	end)

	test("code review: limits never grow past storage, XP never goes down, known ids survive sanitize",function()
		local petStats={}
		for i=1,32 do petStats["future"..i]={power=1}end
		local state={inventoryMask=pip,petStats=petStats}
		assert(S.valid(state))
		assert(S.grant(state,"pip","power",10,"5",true)==0,"a 33rd pet is refused, not saved")
		assert(S.valid(state)and state.petStats.pip==nil)
		local high={inventoryMask=pip,petStats={pip={power=C.MaxXP+500}}}
		assert(S.valid(high)and S.grant(high,"pip","power",10,"5",true)==0 and high.petStats.pip.power==C.MaxXP+500,"never lowered")
		local mixed={}
		for i=1,40 do mixed["zzfuture"..i]={power=1}end
		mixed.pip={power=7}
		local clean=S.sanitizePetStats(mixed)
		assert(clean.pip and clean.pip.power==7,"the known Bear is kept first")
	end)

	return {passed=#cases,cases=cases}
end
