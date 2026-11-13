-- Pet Park director (BUILD-PLAN 2026-11-13, slice K1): isolated GardenState + ParkDirector with an
-- injected clock, a seeded random and fake owners. No Players, remotes, DataStore or rewards.
-- Usage (Server): require(ServerScriptService.Server.ZZSpecs.ParkDirector)(ServerScriptService.Server)
-- Returns {passed, cases, payload = {bytes, actors, slots}}: the largest snapshot JSON seen with 12
-- actors on long approach paths and a full park.
return function(server)
	local Garden=require(server.GardenState)
	local Director=require(server.ParkDirector)
	local Shared=game:GetService("ReplicatedStorage").Shared
	local Activity=require(Shared.GardenActivity)
	local Park=require(Shared.ParkLayout)
	local Catalog=require(Shared.ParkActivities)
	local Http=game:GetService("HttpService")
	assert(Park.Enabled,"ParkLayout needs the v7 world")
	local cases={}
	local function test(name,run)run();table.insert(cases,name)end
	local C,R=Park.Center,Park.Radius
	-- An owner standing at normalised radius `scale` and angle `theta`, 3 studs above the lawn.
	local function spot(theta,scale)
		local x,z=C.X+R.X*scale*math.cos(theta),C.Z+R.Y*scale*math.sin(theta)
		return Vector3.new(x,Park.ground(x,z),z)
	end
	local function place(input,ground)
		input.anchor=ground;input.position=ground+Vector3.new(0,3,0)
	end
	local function fixture(count,options)
		options=options or {}
		local c={now=1000,inputs={},finished={},busy={},seed=options.seed or 12345,writes=0,maxPayload=0}
		local function random()c.seed=(c.seed*1103515245+12345)%2147483648;return c.seed/2147483648 end
		for id=1,count do
			local ground=options.at and options.at(id)or spot(id/count*math.pi*2,.85)
			c.inputs[id]={petId="pip",owned=true,alive=true,characterId=1,petGeneration=0,mode="Room",yaw=0,charmVisible=true}
			place(c.inputs[id],ground)
		end
		c.garden=Garden.new({now=function()return c.now end,publish=function(snapshot)
			c.writes+=1;c.snapshot=snapshot
			if options.measure then c.maxPayload=math.max(c.maxPayload,#Http:JSONEncode(snapshot))end
		end,validFocus=function()return true end})
		c.park=Director.attach(c.garden,{enabled=options.enabled~=false,random=random,
			busy=function(id)return c.busy[id]==true end,
			finished=function(id,activity,session)table.insert(c.finished,{id=id,activity=activity,session=session,at=c.now})end})
		function c:step(seconds)
			for _=1,math.max(1,math.floor((seconds or .5)/.5+.5))do self.now+=.5;self.garden:step(.5,self.inputs)end
		end
		function c:sessions()local list={};for _,s in pairs(self.park.sessions)do table.insert(list,s)end;return list end
		return c
	end
	-- Every live session: slots never shared, exclusive equipment held once, distinct owners.
	local function checkExclusive(c)
		local slots,equipment={},{}
		for _,session in pairs(c.park.sessions)do
			local activity=Catalog.ById[session.activity]
			if activity.exclusive then assert(not equipment[session.equipment],"two sessions on "..session.equipment);equipment[session.equipment]=true end
			local owners={}
			for _,ownerId in ipairs(session.ownerIds)do
				assert(not owners[ownerId],"pet paired with itself");owners[ownerId]=true
				local slotId=session.slots[ownerId]
				assert(slotId and not slots[slotId],"slot "..tostring(slotId).." held twice");slots[slotId]=true
				assert(Park.Slots[slotId].equipment==session.equipment)
			end
		end
	end
	-- Owners stand still in the park, but no pet may pick an activity on its own.
	local function hold(c)for _,actor in pairs(c.garden.actors)do if actor.park then actor.park.nextPickAt=math.huge end end end
	-- Start a chosen activity directly (white box), once the pets are inside the kerb; every other
	-- park pet is held so only this session runs.
	local function force(c,activityId,ids)
		local activity=Catalog.ById[activityId]
		for _=1,40 do
			local ready=true
			for _,id in ipairs(ids)do
				local actor=c.garden.actors[id]
				if not actor or not actor.park or not Park.inside(c.garden:position(actor,c.now),0)then ready=false end
			end
			if ready then break end
			c:step(.5)
		end
		hold(c)
		for _,id in ipairs(ids)do c.garden:release(c.garden.actors[id])end
		local actors={}
		for _,id in ipairs(ids)do table.insert(actors,c.garden.actors[id])end
		assert(c.park:start(activity,activity.slotSets[1],actors,c.now),"could not start "..activityId)
		local actor=c.garden.actors[ids[1]]
		return c.park.sessions[actor.park.session]
	end
	test("catalogue: every play timeline is 8-20 s and every slot exists on the layout",function()
		for _,id in ipairs(Catalog.Order)do
			local activity=Catalog.ById[id]
			assert(activity.duration>=Catalog.MinPlay and activity.duration<=Catalog.MaxPlay,id.." lasts "..activity.duration)
			for _,set in ipairs(activity.slotSets)do
				assert((activity.kind=="solo"and #set==1)or(activity.kind=="duo"and #set==2),id)
				for _,slotId in ipairs(set)do assert(Park.Slots[slotId]and Park.Slots[slotId].equipment==activity.equipment,id.." "..slotId)end
			end
			if activity.solo then assert(Catalog.ById[activity.solo].duration==activity.duration,"solo variant keeps the timeline")end
		end
		for _,slotId in ipairs(Park.SlotOrder)do
			local slot=Park.Slots[slotId]
			assert(Park.inside(slot.approach,-1.5),slotId.." sits inside the kerb")
			for _,gate in ipairs(Park.Gateways)do assert(Vector2.new(slot.approach.X-gate.position.X,slot.approach.Z-gate.position.Z).Magnitude>3,slotId.." clear of "..gate.id)end
		end
		for _,bench in ipairs(Park.Benches)do assert(Park.member(bench.position,false),"a seated owner is in the park: "..bench.id)end
	end)

	test("membership has hysteresis: join 0.5 inside the kerb, leave only 1.5 outside",function()
		local c=fixture(1,{at=function()return Vector3.new(C.X+R.X+1,C.Y,C.Z)end})
		local function stand(offset)place(c.inputs[1],Vector3.new(C.X+R.X+offset,Park.ground(C.X+R.X+offset,C.Z),C.Z));c:step(.5)end
		stand(1);local actor=c.garden.actors[1]
		assert(actor.park==nil,"outside: not a member")
		stand(-.2);assert(actor.park==nil,"0.2 inside is not enough to join")
		stand(-.8);assert(actor.park~=nil,"0.8 inside joins")
		stand(1);assert(actor.park~=nil,"1 stud outside stays")
		stand(1.4);assert(actor.park~=nil,"1.4 outside stays")
		stand(2);assert(actor.park==nil,"2 outside leaves")
		assert(actor.behavior=="follow","a pet whose owner left runs back")
	end)

	test("one pet alone cycles solo equipment, never twice in a row, and never a duo",function()
		local c=fixture(1);c:step(240)
		assert(#c.finished>=8,"solo pet finished only "..#c.finished)
		local last
		for _,entry in ipairs(c.finished)do
			local activity=Catalog.ById[entry.activity]
			assert(activity.kind=="solo","alone, the pet took "..entry.activity)
			assert(activity.equipment~=last,"same equipment twice: "..activity.equipment);last=activity.equipment
		end
	end)

	test("duos only start with two eligible pets of different owners, and both play",function()
		local c=fixture(2);local duos={}
		for _=1,600 do
			c:step(.5);checkExclusive(c)
			for _,session in pairs(c.park.sessions)do
				if Catalog.ById[session.activity].kind=="duo"then
					assert(#session.ownerIds==2 and session.ownerIds[1]~=session.ownerIds[2])
					duos[session.id]=session.activity
				end
			end
		end
		local count=0;for _ in pairs(duos)do count+=1 end
		assert(count>=3,"two pets shared only "..count.." duo sessions")
		-- A petted pet is never matched: pet 2 busy for 60 s, pet 1 plays only solo.
		c.busy[2]=true;c:step(4)
		for _=1,120 do
			c:step(.5)
			for _,session in pairs(c.park.sessions)do
				assert(Catalog.ById[session.activity].kind=="solo"or session.ownerIds[1]~=2 and session.ownerIds[2]~=2)
				assert(not table.find(session.ownerIds,2),"a petted pet took a slot")
			end
		end
	end)

	test("12 pets share 9 slots oldest-first: exclusive slots, no starvation, no repeats",function()
		local c=fixture(12)
		local finishes={}
		for _=1,1440 do -- 12 minutes
			c:step(.5);checkExclusive(c)
		end
		local lastEquipment,lastAt={},{}
		for _,entry in ipairs(c.finished)do
			local equipment=Catalog.ById[entry.activity].equipment
			finishes[entry.id]=(finishes[entry.id]or 0)+1
			assert(lastEquipment[entry.id]~=equipment,"pet "..entry.id.." repeated "..equipment)
			if lastAt[entry.id]then assert(entry.at-lastAt[entry.id]<=75,"pet "..entry.id.." waited "..(entry.at-lastAt[entry.id]).." s")
			else assert(entry.at-1000<=75,"pet "..entry.id.." first finished at "..(entry.at-1000))end
			lastEquipment[entry.id],lastAt[entry.id]=equipment,entry.at
		end
		local least=math.huge
		for id=1,12 do least=math.min(least,finishes[id]or 0)end
		assert(least>=8,"a pet finished only "..least.." activities in 12 minutes")
	end)

	test("timelines end on time, free the slot and credit only the finished pet",function()
		local c=fixture(1);hold(c)
		local session=force(c,"swing",{1})
		local actor=c.garden.actors[1]
		assert(actor.action==Catalog.ApproachAction and actor.park.state=="approach")
		assert(c.garden:snapshot().park.slots.swing1.startTime==session.startTime)
		while c.now<session.startTime+.5 do c:step(.5)end
		assert(actor.action=="parkSwing"and actor.behavior=="play"and actor.startTime==session.startTime and actor.endTime==session.endTime)
		local phase=Catalog.phaseAt("swing",session.startTime,c.now)
		assert(phase and phase.name=="mount")
		while c.now<session.endTime do assert(#c.finished==0);c:step(.5)end
		c:step(.5)
		assert(#c.finished==1 and c.finished[1].id==1 and c.finished[1].activity=="swing")
		assert(next(c.park.sessions)==nil and next(c.garden:snapshot().park.slots)==nil)
		assert(actor.park.state=="idle"and actor.park.last=="swing")
		-- The slide's play path ends at the chute foot, so the next walk starts where the pet is.
		hold(c);session=force(c,"slide",{1})
		while c.now<session.endTime do c:step(.5)end
		local final=Activity.sample(actor,session.endTime)
		assert((final.position-Park.Slots.slide.chuteEnd).Magnitude<.05,"slide ends at the chute foot")
	end)

	test("owner leaving the kerb or the server frees the slot; the see-saw partner hops off",function()
		local c=fixture(2);hold(c)
		local session=force(c,"seesaw",{1,2})
		while c.now<session.startTime+1 do c:step(.5)end
		place(c.inputs[1],Vector3.new(C.X,Park.ground(C.X,C.Z-R.Y-4),C.Z-R.Y-4));c:step(.5)
		local a,b=c.garden.actors[1],c.garden.actors[2]
		assert(a.park==nil and a.behavior=="follow","leaver runs to its owner")
		assert(next(c.park.sessions)==nil,"see-saw slots freed")
		assert(b.action==Catalog.HopOffAction and b.park.state=="hop"and not b.park.session)
		assert(#c.finished==0,"an abandoned see-saw is not a finished activity")
		-- Server exit mid sandbox duo: the remaining pet finishes the castle solo and is credited.
		local d=fixture(2);hold(d)
		session=force(d,"sandboxDuo",{1,2})
		while d.now<session.startTime+2 do d:step(.5)end
		d.garden:remove(1)
		assert(session.activity=="sandbox"and #session.ownerIds==1 and session.ownerIds[1]==2,"duo became solo")
		local slots=d.garden:snapshot().park.slots
		assert(slots.sand2 and slots.sand2.activity=="sandbox"and not slots.sand1)
		local _,equipment=d.park:occupancy();assert(equipment.sandbox,"the left spot stays locked to the castle")
		while d.now<session.endTime+1 do d:step(.5)end
		assert(#d.finished==1 and d.finished[1].id==2 and d.finished[1].activity=="sandbox")
	end)

	test("petting, a superseded generation or care release the slot; a half-left toss finishes solo",function()
		local c=fixture(2);hold(c)
		local session=force(c,"seesaw",{1,2})
		c.busy[1]=true;c:step(.5)
		assert(next(c.park.sessions)==nil and c.garden.actors[2].action==Catalog.HopOffAction,"petting pet 1 ends the see-saw")
		assert(c.garden.actors[1].park and not c.garden.actors[1].park.session)
		for _=1,20 do c:step(.5);assert(not c.garden.actors[1].park.session,"no start while petted")end
		c.busy[1]=nil;hold(c)
		session=force(c,"ballToss",{1,2})
		c.garden.actors[2].generation+=1;c:step(.5) -- superseded half, swept like a greeting pair
		assert(session.activity=="ball"and #session.ownerIds==1 and session.ownerIds[1]==1)
		assert(not c.garden.actors[2].park.session)
		c.garden.actors[1].care={state="Docked"};c:step(.5)
		assert(next(c.park.sessions)==nil and c.garden.actors[1].park==nil,"care drops membership and the slot")
	end)

	test("castle stage derives from startTime: 3 stages, then crumble, then gone",function()
		local start=500;local P=Catalog.ById.sandbox
		local function stage(t)return(Catalog.stageAt("sandbox",start,start+t))end
		assert(stage(-1)==0 and stage(.1)==0 and stage(3.3)==1 and stage(6.5)==2 and stage(9.7)==3)
		assert(stage(Catalog.phaseStart(P,"admire")+.1)==3 and stage(Catalog.phaseStart(P,"crumble")+.1)==4 and stage(P.duration+.1)==0)
		assert(Catalog.stageAt("swing",start,start+5)==0)
		-- A late joiner reads the same stage from the published startTime alone.
		local c=fixture(1);hold(c)
		local session=force(c,"sandbox",{1})
		local published=c.garden:snapshot().park.slots.sand1
		for _,t in ipairs({1,4,7.5,10,11.5})do
			assert(Catalog.stageAt(published.activity,published.startTime,published.startTime+t)==Catalog.stageAt("sandbox",session.startTime,session.startTime+t))
		end
		-- Two swings side by side share one beat.
		local d=fixture(2);hold(d)
		local first=force(d,"swing",{1})
		d:step(1.5);hold(d)
		d.garden:release(d.garden.actors[2])
		assert(d.park:start(Catalog.ById.swing,{"swing2"},{d.garden.actors[2]},d.now))
		local second=d.park.sessions[d.garden.actors[2].park.session]
		local beats=(second.startTime-first.startTime)/Catalog.ById.swing.period
		assert(math.abs(beats-math.floor(beats+.5))<1e-6,"second swing starts on the first swing's beat")
	end)

	test("park pets are not recalled by owner shuffling or a far bench; greeting and wander skip slotted pets",function()
		local c=fixture(2);hold(c)
		local session=force(c,"slide",{1})
		local actor=c.garden.actors[1]
		-- QA Q4 left one bench (the entrance bench, ~18 studs from the ladder): the owner settles on
		-- the far west lawn inside the kerb instead, > 22 studs from the slide ladder.
		local bench={position=spot(math.pi,.8)}
		local slideAt=Park.Slots.slide.approach
		assert(Park.member(bench.position,false))
		assert(Vector2.new(bench.position.X-slideAt.X,bench.position.Z-slideAt.Z).Magnitude>22)
		local generation
		for step=1,math.ceil((session.endTime-c.now)/.5)-1 do
			-- Owner shuffles a stud each sample (the old > 0.65 recall), ending on the far bench.
			local wobble=Vector3.new(if step%2==0 then 1 else -1,0,0)
			place(c.inputs[1],if step>6 then bench.position else bench.position+wobble+Vector3.new(0,0,-2))
			c:step(.5)
			assert(actor.park and actor.park.session==session.id,"recalled at step "..step)
			if actor.park.state=="play"then generation=generation or actor.generation;assert(actor.generation==generation,"play restarted")end
		end
		while c.now<session.endTime+.5 do c:step(.5)end
		assert(#c.finished==1 and c.finished[1].id==1,"slide finished with the owner on the far bench")
		-- Greeting and wander leave slotted park pets alone.
		hold(c);force(c,"seesaw",{1,2})
		c.garden.nextGreeting=0;c.garden:greeting(c.now,{c.garden.actors[1],c.garden.actors[2]})
		assert(next(c.garden.pairs)==nil,"global greeting paired a slotted pet")
		c.garden.options.validWander=function()error("wander ran for a slotted pet")end
		assert(c.garden:wander(c.garden.actors[1],c.inputs[1],c.now)==false)
		c.garden.options.validWander=nil
	end)

	test("QA Q4: a pet left outside walks in beside its owner at the catch-up pace and starts playing",function()
		local c=fixture(1,{at=function()return spot(-.26,1.9)end}) -- outside the east gate
		c:step(1)
		local actor=c.garden.actors[1]
		-- The pet trails far behind (36 studs from the park middle) as the owner walks in.
		local far=spot(-.26,2.6)
		actor.from=Activity.pack(far);actor.to=actor.from;actor.path=nil;actor.startTime=c.now;actor.endTime=c.now
		place(c.inputs[1],spot(-.26,.3));c:step(.5)
		assert(actor.park,"owner inside the kerb: the pet is a park member")
		local inside,startedAt
		for _=1,40 do
			c:step(.5)
			local position=c.garden:position(actor,c.now)
			if not inside and Park.inside(position,0)then inside=c.now end
			if not startedAt and actor.park and actor.park.session then startedAt=c.now end
			if inside and startedAt then break end
		end
		assert(inside and inside-1001.5<=7,"the pet took "..tostring(inside and inside-1001.5).." s to come into the park")
		local target=Activity.vector(actor.to)
		assert(startedAt and startedAt-1001.5<=12,"no activity within 12 s of the owner walking in")
		assert(target~=nil)
		-- The walk-in target is on the owner's side, clear of the equipment.
		local entry=Director.entryPoint(spot(-.26,.3))
		assert(Park.inside(entry,-1)and Park.clearOfKeepout(entry,0),"entry point inside and clear")
		local entryOutside=Director.entryPoint(spot(2.2,1.05))
		assert(Park.inside(entryOutside,-1),"entry point for an owner on the kerb is inside")
	end)

	test("QA Q4: two owners walking in 7 s apart get a duo within 45 s of the second arrival",function()
		for _,seed in ipairs({12345,777,4242,99,31337})do
			local c=fixture(2,{seed=seed,at=function(id)return spot(-.26+id*.2,1.6)end}) -- both outside
			c:step(1)
			place(c.inputs[1],spot(-.26,.4));c:step(7)
			place(c.inputs[2],spot(-.1,.4))
			local arrived=c.now;local duoAt
			for _=1,90 do
				c:step(.5);checkExclusive(c)
				for _,session in pairs(c.park.sessions)do
					if Catalog.ById[session.activity].kind=="duo"and #session.ownerIds==2 then duoAt=duoAt or c.now end
				end
				if duoAt then break end
			end
			assert(duoAt and duoAt-arrived<=45,"seed "..seed..": no duo within 45 s of the second owner arriving")
			-- Then they keep playing together often: at least 3 duo sessions in the next 3 minutes.
			local duos={}
			for _=1,360 do
				c:step(.5)
				for _,session in pairs(c.park.sessions)do
					if Catalog.ById[session.activity].kind=="duo"then duos[session.id]=true end
				end
			end
			local count=0;for _ in pairs(duos)do count+=1 end
			assert(count>=3,"seed "..seed..": only "..count.." duos in 3 minutes")
		end
	end)

	test("QA Q4: a lone pet never waits for a partner; a busy park does not hold pets",function()
		local c=fixture(1)
		for _=1,120 do c:step(.5);assert(c.garden.actors[1].park.partnerWaitUntil==nil,"a lone pet waited for a partner")end
		assert(#c.finished>=1)
	end)

	test("code review: an expired partner wait is cleared, so the pet can hold for a partner again",function()
		local c=fixture(2);c:step(1)
		local a=c.garden.actors[1]
		local stale=c.now-1
		a.park.partnerWaitUntil=stale;a.park.nextPickAt=0
		local cleared=false
		for _=1,40 do
			c:step(.5)
			if a.park and a.park.partnerWaitUntil~=stale then cleared=true;break end
			if a.park then a.park.nextPickAt=0 end
		end
		assert(cleared,"an expired partner wait was left on the pet")
	end)

	test("idle park pets greet every 6 s at most; the same pair waits 45 s",function()
		local c=fixture(2,{at=function(id)return Vector3.new(C.X-1+id*2,Park.ground(C.X-1+id*2,C.Z),C.Z)end})
		c:step(.5);hold(c)
		local a,b=c.garden.actors[1],c.garden.actors[2]
		local function idle()
			for _,actor in ipairs({a,b})do
				if actor.pairId then c.park:endGreeting(actor,c.now)end
				c.garden:transition(actor,"rest",c.garden:position(actor,c.now),.5,"wanderPause");actor.park.state="idle"
				actor.park.waitingSince=c.now -- just went idle (a pet queueing > 8 s is not greeted)
			end
		end
		-- The first decide may already have greeted them; start from a clean cadence and cooldown.
		idle();c.park.nextGreetAt=0;table.clear(c.park.cooldowns)
		c.park:greetings(c.now,{a,b},{})
		assert(a.pairId and a.pairId==b.pairId and a.action=="greet","idle park pets greet")
		c.now+=6;idle();c.park:greetings(c.now,{a,b},{})
		assert(not a.pairId,"same pair inside 45 s")
		c.now+=40;idle();c.park:greetings(c.now,{a,b},{})
		assert(a.pairId and a.pairId==b.pairId,"pair greets again after 45 s")
		local before=a.pairId;c.now+=1;idle();c.park:greetings(c.now,{a,b},{})
		assert(not a.pairId and before~=nil,"no second greeting inside 6 s")
		-- QA Q4: a pet that has queued for a slot longer than GreetPatience is never greeted.
		c.now+=60;idle();table.clear(c.park.cooldowns);c.park.nextGreetAt=0
		a.park.waitingSince=c.now-Director.GreetPatience-1
		c.park:greetings(c.now,{a,b},{})
		assert(not a.pairId and not b.pairId,"the longest-waiting pet was greeted instead of queueing")
	end)

	test("never starts for petted, docked, greeting, resting-on-dais or outside-park pets",function()
		local c=fixture(1);c:step(1)
		local actor=c.garden.actors[1]
		actor.park.nextPickAt=0
		local function eligible()return c.park:eligible(actor,c.now)end
		c.garden:transition(actor,"rest",Park.Center,1,"wanderPause");c.now+=1.1
		assert(eligible(),"baseline idle pet in the park is eligible")
		c.busy[1]=true;assert(not eligible(),"petted");c.busy[1]=nil
		actor.care={};assert(not eligible(),"docked");actor.care=nil
		actor.pairId=99;assert(not eligible(),"greeting");actor.pairId=nil
		actor.action="nookRest";assert(not eligible(),"resting on a dais");actor.action="wanderPause"
		actor.from=Activity.pack(C+Vector3.new(R.X+4,0,0));actor.to=actor.from;actor.path=nil
		assert(not eligible(),"pet still outside the kerb")
	end)

	test("flag off: no director and a byte-identical snapshot",function()
		local function run(withDirector)
			local now=0
			local inputs={}
			for id=1,3 do inputs[id]={petId="pip",owned=true,alive=true,characterId=1,petGeneration=0,mode="Room",yaw=0,charmVisible=true}
				place(inputs[id],spot(id,.5))end
			local garden=Garden.new({now=function()return now end})
			if withDirector then assert(Director.attach(garden,{enabled=false})==nil and garden.park==nil)end
			for _=1,80 do now+=.5;garden:step(.5,inputs)end
			return garden:snapshot()
		end
		local plain,off=run(false),run(true)
		assert(off.park==nil)
		local keys={};for key in pairs(off)do table.insert(keys,key)end;table.sort(keys)
		assert(table.concat(keys,",")=="actors,revision,toy,version","snapshot keys "..table.concat(keys,","))
		assert(Http:JSONEncode(plain)==Http:JSONEncode(off),"flag-off snapshot changed")
		for _,actor in pairs(off.actors)do assert(actor.park==nil)end
	end)

	local payload
	test("payload: 12 actors on long paths with a full park stays one bounded attribute",function()
		-- Owners on the kerb all round, pets start far outside (long first walk), then fill the park.
		local c=fixture(12,{measure=true});c:step(.5)
		for id=1,12 do
			local actor=c.garden.actors[id]
			local far=spot(id/12*math.pi*2,1.8)
			actor.from=Activity.pack(far);actor.to=actor.from;actor.path=nil
		end
		local most,parkBytes,total,samples,writes=0,0,0,0,c.writes
		for _=1,240 do
			c:step(.5)
			local count=0;for _,session in pairs(c.park.sessions)do count+=#session.ownerIds end
			most=math.max(most,count)
			local bytes=#Http:JSONEncode(c.garden:snapshot())
			total+=bytes;samples+=1
			parkBytes=math.max(parkBytes,#Http:JSONEncode(c.garden:snapshot().park))
		end
		assert(most>=7,"park filled to "..most.." pets")
		-- Baseline without the park: the same 12 owners walking a loop, pets following (today's cost).
		local b=fixture(12,{measure=true,enabled=false});b:step(.5)
		for step=1,240 do
			for id=1,12 do place(b.inputs[id],spot(id/12*math.pi*2+step*.05,.6+.3*math.sin(step*.1+id)))end
			b:step(.5)
		end
		payload={bytes=c.maxPayload,meanBytes=math.floor(total/samples),parkBlockBytes=parkBytes,writesPerSecond=(c.writes-writes)/120,
			actors=12,slots=most,baselineBytes=b.maxPayload}
		assert(c.maxPayload<20000,"snapshot JSON "..c.maxPayload.." bytes")
	end)

	return {passed=#cases,cases=cases,payload=payload}
end
