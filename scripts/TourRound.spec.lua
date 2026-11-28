-- The deck tour's untouched round (beta 44: ONBOARD-SIMPLIFY-BRIEF 2 "The dealt round", ARCH-REVIEW-SIMPLIFY Q1 and 1).
-- The tour holds every drop and closes the deck itself, so its field round is dealt and never touched. Proved here on
-- the server's own pieces:
--   1. the round host never ends a 0-drop round by itself: no drop budget spent, nothing on the board to overflow, and
--      the 300 s idle timeout (a phone backgrounded mid-tour) no longer finishes it (BoardLockstep.idleFinishes, read by
--      ClientSimHost before RoundSim.finish)
--   2. leaving it is the "fresh board" case: RunReturn keeps an unfinished round (Preserve), so no award transaction
--      (settleReward runs only on a round that is over) and no new run starts
--   3. the only save write the tour causes, its latches (deckTour, level, quests through Hatching.coachMark), leaves
--      stats.rounds, totalWins, starterRounds, quest progress, bestScore and the Stars exactly as they were
-- Offline: scripts/run_dash_server_specs.py. Studio: require(ServerScriptService.Server.ZZSpecs.TourRound)(Server).
return function(server)
	local H=require(server.HatchProgress)
	local Return=require(server.RunReturn)
	local Shared=game:GetService("ReplicatedStorage").Shared
	local L=require(Shared.BoardLockstep)
	local Teach=require(Shared.TeachMarks)
	local cases={}
	local function test(name,run)run();table.insert(cases,name)end
	local function copy(v)if type(v)~="table"then return v end;local r={};for k,x in pairs(v)do r[k]=copy(x)end;return r end
	local function same(a,b)
		if type(a)~=type(b)then return false end
		if type(a)~="table"then return a==b end
		for k,v in pairs(a)do if not same(v,b[k])then return false end end
		for k in pairs(b)do if a[k]==nil then return false end end
		return true
	end

	test("1. the idle timeout finishes only a round with a drop in it (ARCH-REVIEW-SIMPLIFY 1)",function()
		assert(L.idleFinishes(0)==false and L.idleFinishes(nil)==false,"0 drops: never finished, never paid")
		assert(L.idleFinishes(1)==true and L.idleFinishes(24)==true,"a played round still ends after IdleSeconds")
		assert(L.IdleSeconds==300,"the timeout itself unchanged")
	end)

	test("1b. a dealt field round stepped far past the idle window with no drop is still live (no budget spent, no overflow)",function()
		local RoundSim=require(Shared.BoardRoundSim)
		local Objectives=require(Shared.FieldObjectives)
		for _,heat in ipairs({"easy","medium","hard"})do
			local descriptor=Objectives.create("bank_pair",4242,heat)
			local host=assert(RoundSim.new(RoundSim.fieldSpec("Springy",0,descriptor,heat,true)))
			for _=1,L.TicksPerSecond*20 do RoundSim.step(host)end
			assert(host.over==false and host.outcome==nil and host.board.drops==0,heat..": 20 s untouched, live, nothing counted")
		end
	end)

	test("2. leaving it is the fresh-board case: an unfinished round is preserved (no award, no new run)",function()
		local board={nursery={status="Ready",busy=false,pending=nil,state={}},field={},round={over=false},mode="Room"}
		assert(Return.classify(board,true,true)=="Preserve","not over: kept, never a FreshField (that needs a saved payout)")
		local entered=false
		assert(Return.enter(board,true,true,function()entered=true end)==false and not entered,"no new run on the way back")
		board.round.over=true
		assert(Return.classify(board,true,true)=="Preserve","even over, no saved payout of this run: kept")
	end)

	test("3. the tour's latches leave rounds, wins, the Welcome bonus, quests, best and Stars untouched",function()
		local db,c={},{now=1700000000,serial=0}
		local adapter={now=function()return c.now end,guid=function()c.serial+=1;return "tr"..c.serial end,random=function()return .1 end,
			wait=function()end,update=function(key,transform)local value=transform(copy(db[key]));if value then db[key]=copy(value)end;return copy(value)end}
		local h=H.load(1,{},adapter);assert(h.status=="Ready")
		assert(H.grantStarter(h,true))
		if h.state.lastHatch then assert(H.command(h,"ack",h.state.lastHatch.id,h.state.revision))end
		local before=copy(h.state)
		local bits=Teach.merge(Teach.merge(Teach.bit("deckTour"),Teach.bit("level")),Teach.bit("quests"))
		local ok,why=H.coachMark(h,0,bits,0)
		assert(ok,"saved: "..tostring(why))
		assert(Teach.has(h.state.teachMask,"deckTour"),"the latch is saved")
		local s=h.state
		local stats,old=s.stats or {},before.stats or {}
		assert(same(stats.rounds,old.rounds),"stats.rounds unchanged")
		assert(same(s.totalWins,before.totalWins),"totalWins unchanged")
		assert(same(s.starterRounds,before.starterRounds),"starterRounds unchanged (the Welcome bonus waits for a real round)")
		assert(same(s.quests,before.quests),"quest progress unchanged")
		assert(same(s.bestScore,before.bestScore),"bestScore unchanged")
		assert(s.nectar==before.nectar,"no Stars, not even the 1-Star effort pay")
		assert(same(s.lastRunReward,before.lastRunReward),"no round reward receipt")
	end)

	return{passed=#cases,cases=cases}
end
