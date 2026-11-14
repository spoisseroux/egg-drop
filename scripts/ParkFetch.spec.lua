-- Real director/fetch modules with fake owners and an injected server clock.
return function(server)
	local Shared=game:GetService("ReplicatedStorage").Shared
	local Park=require(Shared.ParkLayout)
	local Garden=require(server.GardenState)
	local Director=require(server.ParkDirector)
	local Host=require(server.ParkThrowHost)
	local Motion=require(Shared.ParkFetchMotion)
	local cases={}
	local function test(name,run)run();table.insert(cases,name)end
	local function fixture(count)
		local c={now=1000,inputs={},busy={},finished={}}
		for id=1,count do
			local at=Park.Center+Vector3.new((id-1)*.4,0,0)
			c.inputs[id]={petId="pip",owned=true,alive=true,characterId=1,petGeneration=0,mode="Room",anchor=at,position=at+Vector3.new(0,3,0),yaw=0}
		end
		c.garden=Garden.new({now=function()return c.now end,sharedToyEnabled=false})
		c.garden:sync(c.inputs)
		c.director=Director.attach(c.garden,{enabled=true,random=function()return .1 end,busy=function(id)return c.busy[id]end,
			finished=function(id,activity,session)table.insert(c.finished,{ownerId=id,activity=activity,session=session})end})
		for _,site in pairs(c.director.sites)do site.nextGreetAt=math.huge end
		local ordered={};for _,actor in pairs(c.garden.actors)do table.insert(ordered,actor)end
		c.director:schedule(c.now,ordered)
		for _,actor in pairs(c.garden.actors)do actor.park.nextPickAt=0 end
		function c:step(seconds)
			for _=1,math.ceil(seconds/.5)do
				self.now+=.5
				for _,site in pairs(self.director.sites)do site.fetch:step(self.now)end
			end
		end
		return c
	end
	test("solo fetch follows authoritative stages and credits one completed game",function()
		local c=fixture(1)
		assert(c.director:throw(1))
		local fetch=c.director.fetch;local session=fetch.session
		assert(session.winnerId==1 and #session.owners==1)
		assert(c.garden.actors[1].generation==session.generations[1],"own transition generation bound")
		local initial=fetch:snapshot();local first=Motion.sample(initial,c.now)
		assert(first and(first-(Park.Center+Vector3.new(0,Motion.Radius+.03,0))).Magnitude<.001)
		c:step(20)
		assert(fetch.session==nil and #c.finished==1 and c.finished[1].activity=="fetch")
		assert(c.garden.actors[1].park.fetchId==nil)
		c:step(20);assert(#c.finished==1,"completion counted once")
	end)
	test("up to three nearby idle pets join; own pet preferred and busy slots untouched",function()
		local c=fixture(6)
		c.busy[2]=true;c.garden.actors[3].care={state="Docked"}
		assert(c.director:throw(6))
		local session=c.director.fetch.session
		assert(#session.owners==3 and session.owners[1]==6 and not table.find(session.owners,2)and not table.find(session.owners,3))
		assert(c.garden.actors[2].park.fetchId==nil and c.garden.actors[3].park.fetchId==nil)
		assert(not c.director:start(require(Shared.ParkActivities).ById.swing,{"swing1"},{c.garden.actors[6]},c.now),"fetch cannot overlap equipment")
		c:step(20);assert(#c.finished==3)
	end)
	test("partial preflight failure reserves nothing; no eligible pet rejects cleanly",function()
		local c=fixture(3)
		c.garden.options.planPath=function()return {},0 end
		local ok,why=c.director:throw(1)
		assert(not ok and why=="NoIdlePets"and c.director.fetch.session==nil)
		for _,actor in pairs(c.garden.actors)do assert(actor.park.fetchId==nil)end
		c.garden.options.planPath=nil
		for id=1,3 do c.busy[id]=true end
		local unavailable=c.director.fetch:snapshot()
		assert(unavailable.ready==false and unavailable.laneReady==true and unavailable.availableOwners["1"]==false,"busy equipment must not advertise a ready throw")
		assert(not c.director:throw(1))
	end)
	test("winner or initiator departure/contact cancels everyone without credit",function()
		for _,cause in ipairs({"leave","focus","contact","generation","expiry"})do
			local c=fixture(3);assert(c.director:throw(1))
			local winner=c.garden.actors[c.director.fetch.session.winnerId]
			if cause=="leave"then c.inputs[1].position=Park.Center+Vector3.new(40,0,0)
			elseif cause=="focus"then winner.mode="Focus";c.garden:release(winner)
			elseif cause=="contact"then c.busy[winner.ownerId]=true
			elseif cause=="generation"then winner.generation+=1;winner.action="newerAction"
			else c.now+=50 end
			c:step(.5)
			assert(c.director.fetch.session==nil and #c.finished==0,cause)
			if cause=="generation"then assert(winner.action=="newerAction","cancellation must not overwrite a superseding action")end
			for _,actor in pairs(c.garden.actors)do assert(not actor.park.fetchId,cause)end
		end
	end)
	test("orphaned companion is released; remaining pets finish once",function()
		local c=fixture(3);assert(c.director:throw(1))
		local session=c.director.fetch.session
		local other
		for _,id in ipairs(session.owners)do if id~=1 and id~=session.winnerId then other=id;break end end
		assert(other)
		c.garden.actors[other].park=nil
		c:step(.5)
		assert(not table.find(session.owners,other),"missing membership cannot steal a pet back on return")
		c:step(20)
		assert(#c.finished==2)
		for _,entry in ipairs(c.finished)do assert(entry.ownerId~=other)end
	end)
	test("two parks throw independently and never invite the other site",function()
		local c=fixture(2)
		local grove=Park.ById.grove;local actor=c.garden.actors[2]
		c.garden:release(actor);actor.park={parkId="grove",state="idle",nextPickAt=0}
		c.inputs[2].position=grove.Center+Vector3.new(0,3,0);c.inputs[2].anchor=grove.Center
		c.garden:transition(actor,"rest",grove.Center,0,"wanderPause",nil,nil,{path={},duration=0})
		actor.from,actor.to={grove.Center.X,grove.Center.Y,grove.Center.Z},{grove.Center.X,grove.Center.Y,grove.Center.Z}
		assert(c.director:throw(1)and c.director:throw(2))
		local first,second=c.director.fetch.session,c.director.sites.grove.fetch.session
		assert(first.id~=second.id and #first.owners==1 and #second.owners==1)
		c:step(20);assert(#c.finished==2)
	end)
	test("remote validates generations/Room, applies once and bounds repeated requests",function()
		local c=fixture(1)
		local board={mode="Room",profile={companionId="pip"},characterGeneration=1,companionGeneration=0}
		local packet={kind="parkThrow",seq=1,petId="pip",characterId=1,petGeneration=0}
		local bad=table.clone(packet);bad.petId="other"
		assert(Host.request(board,c.garden,1,bad,c.now).reason=="StalePet")
		bad=table.clone(packet);bad.seq=0;assert(Host.request(board,c.garden,1,bad,c.now)==nil)
		local reply=Host.request(board,c.garden,1,packet,c.now)
		assert(reply.status=="Applied")
		local again=Host.request(board,c.garden,1,packet,c.now+.1)
		assert(again.actionId==reply.actionId and c.director.fetch.serial==1)
		bad=table.clone(packet);bad.seq=2
		assert(Host.request(board,c.garden,1,bad,c.now+1).reason=="Cooldown")
		board.mode="Board";bad.seq=3
		assert(Host.request(board,c.garden,1,bad,c.now+10).reason=="StalePet")
	end)
	test("real automatic scheduling leaves a usable fetch window during post-activity rest",function()
		local c=fixture(1)
		local completed=false
		-- Use the actual Garden.step/director scheduler, without whitebox holds.
		for _=1,120 do
			c.now+=.5;c.garden:step(.5,c.inputs)
			local actor=c.garden.actors[1]
			if #c.finished>0 and actor.park and actor.park.session==nil and actor.behavior=="rest"and actor.action=="wanderPause"then
				assert(actor.park.nextPickAt>c.now,"this must exercise the autonomous cooldown")
				assert(c.director:throw(1),"a truly idle cooling-down pet must be joinable")
				completed=true;break
			end
		end
		assert(completed,"autonomous equipment never completed")
		local before=#c.finished
		for _=1,80 do c.now+=.5;c.garden:step(.5,c.inputs)end
		local games=0
		for index=before+1,#c.finished do if c.finished[index].activity=="fetch"then games+=1 end end
		assert(games==1,"automatic scheduler must not steal a fetch reservation")
	end)

	return {passed=#cases,cases=cases}
end
