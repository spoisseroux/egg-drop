-- Garden Dash director (V3-DASH-BUILD-PLAN-2026-11-22, S6): phases, seats, the line, pals, inputs, trials, errors, on a
-- fake clock with fake boards. No Players, remotes, saves or rewards.
-- Usage (Server): require(ServerScriptService.Server.ZZSpecs.DashDirector)(ServerScriptService.Server)
return function(server)
	local Shared=game:GetService("ReplicatedStorage").Shared
	local Director=require(server.DashDirector)
	local DashState=require(server.DashState)
	local Sim=require(Shared.DashSim)
	local Stats=require(Shared.DashStats)
	local cases={}
	local function test(name,run)run();table.insert(cases,name)end
	local function rig(options)
		options=options or {}
		local c={now=1000,serial=0,seedAt=options.seed or 77,events={},tags={},finished={},states={},refuse={},level={},prizes=true,day="1",warnings=0}
		c.d=Director.new({now=function()return c.now end,guid=function()c.serial+=1;return "race-"..c.serial end,
			seed=function()c.seedAt+=1;return c.seedAt end,day=function()return c.day end,prizes=function()return c.prizes end,
			check=function(id,stage)if c.throw==stage then error("boom")end;local why=c.refuse[id];if why and(why.stage==nil or why.stage==stage)then return false,why.reason end;return true,if stage=="promote"and c.closer and c.closer[id]then"Closer"else nil end,
			levels=function(id)return c.level[id]or{speed=20,energy=20,jump=20}end,pet=function()return "pip"end,
			tag=function(id,race)c.tags[id]=race end,event=function(id,packet)table.insert(c.events,{id=id,packet=packet})end,
			state=function(id,race,sim)table.insert(c.states,{id=id,race=race,tick=sim.tick})end,
			finished=function(id,result)assert(DashState.validResult(result));table.insert(c.finished,{id=id,result=result})end,
			publish=function(roster)c.roster=roster end,warn=function()c.warnings+=1 end})
		function c.run(seconds,each)
			for _=1,math.floor(seconds*60+.5)do
				c.now+=1/60
				if each then each()end
				c.d:step()
			end
		end
		function c.last(id,kind)for i=#c.events,1,-1 do local e=c.events[i];if e.id==id and(not kind or e.packet.kind==kind)then return e.packet end end end
		function c.count(kind)local n=0;for _,e in ipairs(c.events)do if e.packet.kind==kind then n+=1 end end;return n end
		function c.until_(phase,limit)local n=0;while(c.d.heat and c.d.heat.phase or "idle")~=phase do c.run(.25);n+=1;assert(n<(limit or 800),"stuck before "..phase)end end
		return c
	end
	-- A player that presses like a pal would: at every take-off spot, through the real input path.
	local function pilot(c,id,wild)
		local state={n=0,pressed=0}
		return function()
			local record,run=c.d:runner(id)
			if not record or run.phase~="race"then return end
			local r=run.race.runners[record.seat]
			local goal=r.list[r.next]
			if goal and not r.finishUs then
				local ticks=(Sim.takeoff(r,goal)-r.pos)/r.step
				if ticks<=10+(wild or 0)and state.pressed~=r.next then
					state.pressed=r.next;state.n+=1
					local clock=math.floor((c.now-run.goAt)*100)
					c.d:input(id,{r=run.id,n=state.n,t=math.max(run.race.tick+1,clock-5),k="jump"})
				end
			end
		end
	end
	test("a whole race alone: gather 20 s, countdown 3.5 s, three pals, results 6 s, then idle; one paid result and the tag comes off",function()
		local c=rig()
		local ok,why,id=c.d:join(1,"fun");assert(ok and why==nil and id=="race-1"and c.tags[1]=="race-1")
		c.run(19.9);assert(c.d.heat.phase=="gather");c.run(.2);assert(c.d.heat.phase=="countdown")
		local locked=c.last(1,"locked");assert(locked.seat==1 and locked.levels==nil and locked.goAt>c.now+3 and #locked.plan.zoomies==0 and locked.plan.seed==nil)
		assert(#c.roster.seats==4 and c.roster.seats[1].userId==1)
		for seat=2,4 do local pal=c.roster.seats[seat];assert(pal.pal and pal.userId==nil and pal.petId and #pal.name==1)end
		c.run(3.6);assert(c.d.heat.phase=="race")
		c.run(60,pilot(c,1));assert(c.d.heat==nil and #c.finished==1 and c.tags[1]==nil)
		local result=c.finished[1].result
		assert(result.kind=="race"and result.mode=="fun"and result.prize==true and result.inputs>=3 and result.us and result.seed==78)
		local said=c.last(1,"result");assert(said.place==result.place and said.us==result.us and #said.seats==4 and said.seed==nil)
		assert(c.count("judged")>=6 and c.d.roster(c.d).phase=="idle")
	end)
	test("nothing sent to clients carries the seed, the zoomies moments or another pet's levels",function()
		local c=rig();c.level={[1]={speed=20,energy=20,jump=20},[2]={speed=22,energy=20,jump=20}}
		c.d:join(1,"stats");c.d:join(2,"fun");c.until_("race");c.run(3)
		local function scan(value,path)
			if type(value)~="table"then return end
			for key,v in pairs(value)do
				assert(key~="seed"and key~="levels"and key~="zoomies"or(key=="zoomies"and #v==0)or(key=="levels"and path=="locked"),path.."."..tostring(key))
				scan(v,path)
			end
		end
		scan(c.roster,"roster");for _,e in ipairs(c.events)do scan(e.packet,e.packet.kind)end
		local mine=c.last(2,"locked");assert(mine.levels.speed==22 and c.last(1,"locked").levels.speed==20)
	end)
	test("a join resets the gather to at least 8 s, and joins can never hold it past its limit",function()
		local c=rig();c.d:join(1,"fun");c.run(19);c.d:join(2,"fun");assert(c.d.heat.endsAt>=c.now+7.9)
		c.run(7.5);assert(c.d.heat.phase=="gather")
		for id=3,60 do c.d:join(id,"fun");c.run(2);if c.d.heat.phase~="gather"then break end;c.d:leave(id)end
		assert(c.d.heat.phase~="gather"and c.now-1000<Director.GatherMax+4)
	end)
	test("the first player alone picks the mode; nobody else can",function()
		local c=rig();c.d:join(1,"fun")
		assert(not c.d:mode(2,"stats")and c.d:mode(1,"stats")and c.d.heat.band==2)
		c.d:join(2,"fun");local ok,why=c.d:mode(1,"fun");assert(not ok and why=="Locked"and c.d.heat.mode=="stats")
	end)
	test("Stats On takes the first band; other bands wait in line, and a pet that moved band by the countdown is refused",function()
		local c=rig();c.level={[2]={speed=80,energy=80,jump=80},[3]={speed=21,energy=21,jump=21}}
		c.d:join(1,"stats");local ok,why=c.d:join(2,"stats");assert(ok and why=="WrongBand"and #c.d.queue==1 and c.tags[2]==nil)
		assert(c.d:join(3,"fun")and #c.d.heat.seats==2)
		c.level[3]={speed=60,energy=60,jump=60};c.until_("countdown")
		assert(#c.d.heat.seats==1 and c.last(3,"refused").reason=="WrongBand"and c.tags[3]==nil)
		for seat=2,4 do assert(c.d.heat.specs[seat].speed==Stats.bandMiddle(2))end
	end)
	test("12 players: 8 race, 4 wait in order and race next; a 25th request in line is refused",function()
		local c=rig()
		for id=1,12 do local ok,why=c.d:join(id,"fun");assert(ok and(why==nil)==(id<=8))end
		local _,why=c.d:join(3,"fun");assert(why=="AlreadySeated")
		c.run(.1);assert(table.concat(c.roster.queue,",")=="9,10,11,12"and c.tags[9]==nil)
		c.until_("race");assert(#c.d.heat.lineup==8)
		local ok,reason=c.d:join(9,"fun");assert(ok and reason=="Queued"and #c.d.queue==4,"asking again keeps the place")
		c.until_("results");c.until_("gather");assert(#c.d.heat.seats==4 and c.d.heat.seats[1].userId==9 and #c.d.queue==0)
		for id=100,140 do c.d:join(id,"fun")end
		assert(#c.d.heat.seats==8 and #c.d.queue==Director.MaxQueue);ok,reason=c.d:join(141,"fun");assert(not ok and reason=="Full")
	end)
	test("the line drops whoever walked away, and nobody can take the next race from under it",function()
		local c=rig();for id=1,11 do c.d:join(id,"fun")end
		c.refuse[9]={reason="Far",stage="queue"};c.run(1);assert(#c.d.queue==2 and c.last(9,"refused").reason=="Far")
		c.d:abort("Test");local _,why=c.d:join(50,"fun");assert(why=="Queued");c.run(.1)
		assert(c.d.heat.seats[1].userId==10 and c.d.heat.seats[3].userId==50)
	end)
	test("promotion: busy pets keep their place and block nobody, the far ones are told to come closer, the rest are rechecked",function()
		local c=rig();for id=1,11 do c.d:join(id,"fun")end
		c.refuse[9]={reason="Petting",stage="promote"};c.closer={[10]=true};c.d:abort("Test");c.run(.1)
		assert(c.d.heat.seats[1].userId==10 and c.d.heat.seats[2].userId==11 and #c.d.queue==1 and c.d.queue[1].userId==9 and c.tags[9]==nil)
		local told=c.last(10,"joined");assert(told.promoted and told.closer);told=c.last(11,"joined");assert(told.promoted and not told.closer and c.last(9,"refused")==nil)
		c.d:abort("Test");c.run(2);assert(c.d.heat==nil and #c.d.queue==1);c.refuse[9]=nil;c.run(.6);assert(c.d.heat.seats[1].userId==9)
	end)
	test("refused joins touch nothing: no seat, no tag, no line",function()
		local c=rig();c.refuse[1]={reason="Far"};local ok,why=c.d:join(1,"fun");assert(not ok and why=="Far"and c.d.heat==nil and c.tags[1]==nil)
		ok,why=c.d:trial(1);assert(not ok and why=="Far"and next(c.d.trials)==nil)
		c.throw="join";ok=c.d:join(2,"fun");assert(not ok and c.d.heat==nil and c.warnings==1)
	end)
	test("rechecked at the countdown: whoever fails is let go, and an empty race is no race",function()
		local c=rig();c.d:join(1,"fun");c.d:join(2,"fun");c.refuse[2]={reason="Hatching",stage="countdown"};c.until_("countdown")
		assert(#c.d.heat.seats==1 and c.last(2,"refused").reason=="Hatching"and c.tags[2]==nil)
		c=rig();c.d:join(1,"fun");c.refuse[1]={reason="NoCharacter",stage="countdown"};c.run(21);assert(c.d.heat==nil and #c.finished==0)
	end)
	test("a leaver becomes a pal on the spot and wins nothing; the others race on; the last one out ends it unpaid",function()
		local c=rig();c.d:join(1,"fun");c.d:join(2,"fun");c.until_("race");c.run(5)
		local before=c.d.heat.race.runners[1].pos
		assert(c.d:leave(1)and c.tags[1]==nil and c.d.heat.race.runners[1].bot and c.d.heat.race.runners[1].pos==before)
		assert(c.d.heat.lineup[1].userId==nil and c.d.heat.lineup[1].left);assert(not c.d:leave(1))
		c.until_("results");assert(#c.finished==1 and c.finished[1].id==2)
		c=rig();c.d:join(1,"fun");c.until_("race");c.d:leave(1);assert(c.d.heat==nil);c.run(60);assert(#c.finished==0)
		c=rig();c.d:join(1,"fun");c.until_("countdown");c.d:leave(1);assert(c.d.heat==nil and c.tags[1]==nil)
	end)
	test("a seat that stops being allowed (Deck, another pet, gone) is left within half a second",function()
		local c=rig();c.d:join(1,"fun");c.d:join(2,"fun");c.until_("race");c.refuse[1]={reason="Deck",stage="seat"};c.run(.6)
		assert(c.tags[1]==nil and c.last(1,"refused").reason=="Deck"and #c.d.heat.seats==1)
	end)
	test("hostile inputs gain nothing: late, early, duplicate, old race, other seat, reordered, flooded, before GO",function()
		local c=rig();c.d:join(1,"fun");c.d:join(2,"fun");c.until_("countdown")
		local heat=c.d.heat
		local function send(n,t,k,r,id)return c.d:input(id or 1,{r=r or heat.id,n=n,t=t,k=k or "jump"})end
		assert(send(1,5).reason=="closed","input opens on GO");c.until_("race");c.run(2)
		local race=heat.race;local inputs=race.runners[1].inputs
		assert(send(2,race.tick).reason=="late"and send(3,race.tick-50).reason=="late"and send(4,race.tick+101).reason=="early")
		assert(send(5,race.tick+20,"jump","race-9").reason=="race"and send(4,race.tick+20)==nil and send(1,race.tick+20)==nil)
		assert(race.runners[1].inputs==inputs,"nothing above counted")
		assert(send(6,race.tick+30)==nil and send(7,race.tick+20).reason=="order"and race.runners[1].inputs==inputs+1)
		assert(send(1,race.tick+10,"jump",nil,99)==nil,"nobody's seat")
		local two=race.runners[2].inputs
		for n=8,40 do send(n,race.tick+40)end
		assert(race.runners[1].inputs<=inputs+Sim.InputsPerSecond and race.runners[2].inputs==two)
	end)
	test("30 bad packets and the rest of that race is ignored; the next race starts clean",function()
		local c=rig();c.d:join(1,"fun");c.until_("race");c.run(1)
		for _=1,30 do assert(c.d:input(1,nil)==nil)end
		local heat=c.d.heat
		assert(c.d:input(1,{r=heat.id,n=1,t=heat.race.tick+10,k="jump"})==nil and heat.race.runners[1].inputs==0)
		c.until_("idle");c.d:join(1,"fun");c.until_("race");c.run(1);heat=c.d.heat
		c.d:input(1,{r=heat.id,n=1,t=heat.race.tick+10,k="jump"});assert(heat.race.runners[1].inputs==1)
	end)
	test("an honest lag of 150 ms never loses an input: the race is stepped 150 ms behind",function()
		local c=rig();c.d:join(1,"fun");c.until_("race");c.run(3);local heat=c.d.heat
		local pressed=math.floor((c.now-heat.goAt)*100);c.run(.13)
		assert(c.d:input(1,{r=heat.id,n=1,t=pressed,k="dashDown"})==nil)
		pressed=math.floor((c.now-heat.goAt)*100);c.run(.2);assert(c.d:input(1,{r=heat.id,n=2,t=pressed,k="dashUp"}).reason=="late")
	end)
	test("a frame never steps more than 10 ticks, and a 20 s hitch ends in the same result",function()
		local times={}
		for _,hitch in ipairs({false,true})do
			local c=rig({seed=500});c.d:join(1,"fun");c.until_("race")
			if hitch then c.now+=20 end
			local most,n=0,0
			while c.d.heat and c.d.heat.phase=="race"do
				local before=c.d.heat.race.tick
				c.run(1/60);n+=1;assert(n<20000)
				local heat=c.d.heat;if heat then most=math.max(most,heat.race.tick-before)end
			end
			assert(most<=10);table.insert(times,c.finished[1].result.us or -1)
		end
		assert(times[1]==times[2])
	end)
	test("the result replays from the seed and inputs; only five races are kept",function()
		local c=rig()
		for i=1,7 do
			c.d:join(1,"fun");c.d:join(2,"fun");c.until_("race")
			local one,two,left=pilot(c,1),pilot(c,2,20),false
			c.run(50,function()one();two();if i%2==0 and not left and c.d.heat and c.d.heat.race and c.d.heat.race.tick>900 then left=true;c.d:leave(2)end end)
			c.until_("idle")
			local entry=c.d.history[#c.d.history]
			local again=Director.replay(entry)
			for place,s in ipairs(entry.standings)do assert(again[place].seat==s.seat and again[place].us==s.us,"place "..place)end
		end
		assert(#c.d.history==5)
	end)
	test("a pet that never finishes is placed after 20 s with no time; an idle one has no inputs",function()
		local c=rig();c.d:join(1,"fun");c.until_("race");c.d.heat.race.runners[1].stride=1;c.until_("results",2000)
		assert(c.finished[1].result.us==nil and c.finished[1].result.place==4 and c.finished[1].result.inputs==0)
	end)
	test("Time Trial: any time, even in a race by others; private state; the Even course, no luck; ends with the best of the day",function()
		local c=rig();c.d:join(1,"fun");c.until_("race")
		local ok,_,id=c.d:trial(2);assert(ok and c.tags[2]==id)
		local _,why=c.d:join(2,"fun");assert(why=="AlreadySeated");_,why=c.d:trial(1);assert(why=="AlreadySeated")
		local plan=c.last(2,"locked").plan;assert(plan.layout=="even"and #plan.clovers==0)
		c.run(60,pilot(c,2))
		local got;for _,f in ipairs(c.finished)do if f.id==2 then got=f.result end end
		assert(got.kind=="trial"and got.us and c.tags[2]==nil and c.d.trials[2]==nil and c.d.best.userId==2)
		for _,s in ipairs(c.states)do assert((s.race==id)==(s.id==2))end
		c.d.heat=nil;c.day="2";c.d:trial(3);c.run(60);assert(c.d.best.userId==3 and c.d.best.day=="2","a new day starts a new best")
	end)
	test("leaving a trial, or a trial whose seat fails, frees the pet and pays nothing",function()
		local c=rig();c.d:trial(1);assert(c.d:leave(1)and c.tags[1]==nil);c.d:trial(2);c.refuse[2]={reason="Deck",stage="seat"};c.run(1);assert(c.tags[2]==nil and #c.finished==0)
	end)
	test("a trial dropped for a reason (another pet, the Deck) says so once; leaving it yourself says nothing",function()
		for _,reason in ipairs({"PetChanged","Deck"})do
			local c=rig();local sent={};c.d.options.event=function(id,packet)table.insert(sent,{id=id,packet=packet})end
			local _,_,id=c.d:trial(1);table.clear(sent)
			assert(c.d:leave(1,reason)and c.tags[1]==nil and #sent==1 and sent[1].id==1)
			assert(sent[1].packet.kind=="aborted"and sent[1].packet.r==id and sent[1].packet.reason==reason)
			c.d:leave(1,reason);assert(#sent==1)
			c.d:trial(1);table.clear(sent);c.d:leave(1);assert(#sent==0)
		end
	end)
	test("twelve trials and a race at once stay inside the step budget",function()
		local c=rig();for id=1,8 do c.d:join(id,"fun")end;c.until_("race");for id=20,31 do assert(c.d:trial(id))end
		c.run(4);local start=os.clock();c.run(10);local frame=(os.clock()-start)/600
		assert(frame<.004,string.format("%.2f ms a frame",frame*1000));cases.frame=frame
	end)
	test("switched off: everything ends unpaid, every pet is free, the line is told",function()
		local c=rig();for id=1,9 do c.d:join(id,"fun")end;c.d:trial(20);c.until_("race");c.d:shutdown("Off")
		for id=1,8 do assert(c.tags[id]==nil and c.last(id,"aborted").reason=="Off")end
		assert(c.tags[20]==nil and c.last(9,"refused").reason=="Off"and #c.d.queue==0);c.run(60);assert(#c.finished==0)
	end)
	test("an error ends that race unpaid and frees the pets; three turn Dash off",function()
		local c=rig()
		for i=1,3 do
			assert(c.d:join(1,"fun"));c.until_("race");c.d.heat.race.runners[1].list=nil;c.run(.5)
			assert(c.d.heat==nil and c.tags[1]==nil and c.last(1,"aborted").reason=="Error"and c.d.errors==i)
		end
		local ok,why=c.d:join(1,"fun");assert(not ok and why=="Off"and c.d.off and #c.finished==0)
	end)
	test("a trial's error ends only that trial; host callbacks that throw never end a race",function()
		local c=rig();c.d:join(1,"fun");c.until_("race");c.d:trial(2);c.run(5);c.d.trials[2].race.runners[1].list=nil;c.run(.2)
		assert(c.d.trials[2]==nil and c.tags[2]==nil and c.d.heat.phase=="race")
		c.d.options.event=function()error("gone")end;c.d.options.state=function()error("gone")end;c.until_("results");assert(#c.finished==1)
	end)
	test("prizes are frozen when the race ends",function()
		local c=rig();c.d:join(1,"fun");c.until_("race");c.prizes=false;c.until_("results");assert(c.finished[1].result.prize==false)
	end)
	return{passed=#cases,cases=cases,frameMs=(cases.frame or 0)*1000}
end
