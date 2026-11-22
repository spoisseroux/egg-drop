-- Garden Dash prediction (DashPredict, slice S7): the owner's pet is the server's, bit for bit, through lag, late
-- inputs and zoomies; corrections are quiet; the pacing always leaves room to let Dash go.
-- Usage (Client): require(ZZSpecs.DashPredict)(StarterPlayerScripts.Client)   options.races (default 1000)
return function(client,options)
	local Shared=game:GetService("ReplicatedStorage").Shared
	local Sim=require(Shared.DashSim)
	local Stats=require(Shared.DashStats)
	local Wire=require(Shared.DashWire)
	local Predict=require(client.DashPredict)
	local cases={}
	local function test(name,run)run();table.insert(cases,name)end
	local RACES=options and options.races or 1000

	-- One race on a fake network. oneWay: seconds each way. Returns the server race, the prediction and the tallies.
	local function play(random,settings)
		local mode=settings.mode
		local runners={}
		for seat=1,settings.count do
			runners[seat]={speed=random:NextInteger(1,99),energy=random:NextInteger(1,99),jump=random:NextInteger(1,99),bot=if seat>1 then true else nil}
		end
		if mode=="stats"then for seat=2,settings.count do runners[seat].speed,runners[seat].energy,runners[seat].jump=runners[1].speed,runners[1].energy,runners[1].jump end end
		local seed=random:NextInteger(1,2147483646)
		local race=Sim.new({seed=seed,mode=mode,runners=runners})
		local p=Predict.new({raceId="race",seat=1,plan=Sim.publicPlan(race.plan),levels=if mode=="stats"then runners[1]else nil,goAt=0,lead=if settings.lead==nil then Predict.lead(settings.oneWay*2)else settings.lead})
		local toServer,toClient={},{}
		local out={refused=0,reasons={},sent=0,zooms=0,race=race,p=p}
		local frame=1/settings.fps
		local now,held,stateAt=0,false,0
		local mine=race.runners[1]
		repeat
			now+=frame*random:NextNumber(.6,1.4)
			if settings.hitch and random:NextNumber()<.002 then now+=random:NextNumber(.2,1.2)end
			-- Server frame: what has arrived, in order, then the step (DashDirector.advance).
			while toServer[1]and toServer[1].at<=now do
				local item=table.remove(toServer,1)
				local ok,why=Sim.push(race,1,item.packet.t,item.packet.k)
				if not ok then
					out.refused+=1;out.reasons[why]=(out.reasons[why]or 0)+1
					table.insert(toClient,{at=now+settings.oneWay,refused=item.packet.n})
				end
			end
			local target,stepped=math.floor(now*100)-Sim.LagTicks,0
			while race.tick<target and stepped<10 and not race.over do
				Sim.step(race);stepped+=1
				if mine.zoomTick==race.tick then out.zooms+=1;table.insert(toClient,{at=now+settings.oneWay,zoom=race.tick})end
			end
			if stepped>0 and now-stateAt>=.1 then
				stateAt=now
				local state=Wire.decode(Wire.encode("race",race,Stats.UnitsPerCs))
				-- Unreliable: some are lost, some come later than a correction sent after them.
				if random:NextNumber()<.9 then table.insert(toClient,{at=now+settings.oneWay*random:NextNumber(.5,1.5),state=state})end
			end
			-- Client frame.
			for index=#toClient,1,-1 do
				local item=toClient[index]
				if item.at<=now then
					table.remove(toClient,index)
					if item.refused then assert(p:refused(item.refused))
					elseif item.zoom then p:zoom(item.zoom)
					else p:observe(item.state.tick,item.state.seats[1].cs)end
				end
			end
			p:step(now,frame)
			local r=p.runner
			local gap=Sim.nextJump(r)
			local function press(kind)
				local packet=p:press(kind)
				if packet then out.sent+=1;table.insert(toServer,{at=math.max(now+settings.oneWay,if #toServer>0 then toServer[#toServer].at else 0),packet=packet})end
				return packet~=nil
			end
			if p:started()and not p:finished()then
				if gap and gap<random:NextNumber(0,8)and r.air==0 and random:NextNumber()<.5 then press("jump")
				elseif random:NextNumber()<.01 then press("jump")end
				if random:NextNumber()<(if held then .05 else .03)then
					if held then assert(press("dashUp"),"a let go always goes out");held=false
					elseif press("dashDown")then held=true end
				end
				if random:NextNumber()<.02 then press("stones")end
			end
			assert(now<200)
		until race.over and p.race.tick>=race.tick and #toServer==0 and #toClient==0 or now>180
		out.mine=mine
		return out
	end
	local function same(out)
		local a,b=out.mine,out.p.runner
		for _,key in ipairs({"finishUs","bar","perfects","clears","trips","puffs","stones","inputs","zoomTick","cloverTick","total"})do
			if a.finishUs then assert(a[key]==b[key],key..": "..tostring(a[key]).." / "..tostring(b[key]))end
		end
		for index,kind in pairs(a.results)do if a.finishUs then assert(b.results[index]==kind)end end
		assert(not out.p.serverRender,"never falls back on an honest line")
	end
	test(RACES.." races: every mode, 0 to 120 ms each way, hitches, late presses, zoomies: the same pet to the bit",function()
		local random=Random.new(20261122)
		local tallies={refused=0,zooms=0,rebuilds=0,sent=0}
		for index=1,RACES do
			local out=play(random,{mode=({"fun","stats","trial"})[index%3+1],count=if index%3==2 then 1 else random:NextInteger(2,4),oneWay=random:NextNumber(0,.12),
				fps=({60,30,20})[index%3+1],hitch=index%2==0})
			same(out)
			tallies.refused+=out.refused;tallies.zooms+=out.zooms;tallies.rebuilds+=out.p.rebuilds;tallies.sent+=out.sent
			for why,count in pairs(out.reasons)do assert(why=="late"or((why=="early"or why=="closed")and index%2==0),why.." "..count)end -- early, closed: only after a hitch
		end
		assert(tallies.zooms>0 and tallies.sent>RACES*10,"the races were played")
	end)
	test("a bad line (250 ms each way, no lead): refused presses are taken out and the rest still equals the server",function()
		local random=Random.new(7)
		local refused=0
		for index=1,60 do
			local out=play(random,{mode=if index%2==0 then "fun"else"stats",count=2,oneWay=.25,lead=0,fps=60})
			same(out);refused+=out.refused
			assert(out.p.rebuilds>=1)
		end
		assert(refused>100,"it was a bad line")
		-- With the lead nothing honest is late.
		for _=1,20 do assert(play(random,{mode="fun",count=2,oneWay=.25,fps=60}).refused==0)end
	end)
	test("the lead: nothing near, half the trip and a margin over the server's lag far, never over 0.3 s",function()
		assert(Predict.lead(nil)==0 and Predict.lead(0/0)==0 and Predict.lead(.05)==0 and Predict.lead(.2)==0)
		assert(math.abs(Predict.lead(.4)-.08)<1e-9 and Predict.lead(5)==.3)
	end)
	local function solo(mode)
		local race=Sim.new({seed=5,mode=mode or"trial",runners={{}}})
		return Predict.new({raceId="r",seat=1,plan=Sim.publicPlan(race.plan),goAt=10,lead=0})
	end
	test("pacing: eight a second, and dashUp always",function()
		local p=solo()
		p:step(9.9,.1);assert(p:press("jump")==nil,"nothing before GO")
		p:step(10.5,.1)
		for _=1,4 do assert(p:press("dashDown")and p:press("dashUp"))end
		assert(p:press("jump")==nil and p:press("dashDown")==nil,"eight in a second")
		assert(p:press("dashUp"),"a let go is never refused")
		p:step(11.605,.1);assert(p:press("jump").t==161)
	end)
	test("a refusal is quiet: no news is replayed, the drawn place eases and never jumps",function()
		local p=solo()
		p:step(10,.1)
		local down=p:press("dashDown")
		for i=1,60 do p:step(10+i/60,1/60)end
		local before=p:cs()
		assert(p:refused(down.n)and not p:refused(down.n)and not p:refused(99))
		assert(math.abs(p:cs()-before)<1e-6,"the frame it lands on shows nothing")
		local last=p:cs()
		for i=1,30 do
			p:step(11+i/60,1/60)
			local cs=p:cs();assert(cs>=last-25 and cs-last<40);last=cs
		end
		assert(p.easeLeft==0 and not p.runner.dash)
	end)
	test("server drawing: one disagreement is forgiven, a corrected one does not count, a second one stays",function()
		local p=solo()
		p:step(11,.1);p:step(12,.1)
		p:observe(50,buffer.readu16(p.history,100));assert(p.pending==nil)
		p:observe(50,1);p:step(12.3,.1);assert(p.pending and p.mismatches==0)
		p:step(13,.1);assert(p.mismatches==1 and not p.serverRender)
		p:observe(60,1);p:step(14,.1);assert(p.serverRender)
		local q=solo()
		q:step(10.2,.1);local press=q:press("dashDown");q:step(11,.1);q:step(12,.1)
		local clean=solo();clean:step(11,.1);clean:step(12,.1)
		local cs=buffer.readu16(clean.history,300)
		q:observe(150,cs);assert(q.pending,"a state from before the refusal got here first")
		q:refused(press.n);q:step(13,.1);assert(q.mismatches==0)
		p:observe(0,0);p:observe(11900,0)
	end)
	test("a plan that is not one makes no prediction",function()
		local good=Sim.publicPlan(Sim.new({seed=5,mode="fun",runners={{},{}}}).plan)
		assert(Predict.new({raceId="r",seat=2,plan=good,goAt=1}))
		for _,odd in ipairs({{},{seat=3},{plan=false},{goAt=false},{plan={layout="x",lanes={1},clovers={}}}})do
			local o={raceId="r",seat=1,plan=good,goAt=1}
			if next(odd)==nil then o.plan=nil end
			for k,v in pairs(odd)do o[k]=if v==false then nil else v end
			assert(Predict.new(o)==nil)
		end
		local p=solo()
		assert(not p:zoom("x")and not p:zoom(1.5)and not p:zoom(0)and p:zoom(40)and not p:zoom(40))
	end)
	test("a rebuild of a whole race is far under 8 ms here",function()
		local p=solo()
		for i=1,40 do p:step(10+i,.1)end
		local start=os.clock()
		for _=1,20 do p:rebuild()end
		assert((os.clock()-start)/20<.008)
	end)
	return{passed=#cases,cases=cases}
end
