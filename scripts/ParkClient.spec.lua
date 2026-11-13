-- Pet Park client (BUILD-PLAN 2026-11-13, slice K3): local moving equipment from server times,
-- late join mid-phase, castle stages, ball arcs, flag off creates nothing, and no instances per
-- frame. Fake park blocks and fake meshes; no remotes, no GardenState.
-- Usage (Client): require(PlayerScripts.Client.ZZSpecs.ParkClient)(PlayerScripts.Client, workspace)
return function(client,parent)
	local ParkClient=require(client.ParkClient)
	local Shared=game:GetService("ReplicatedStorage").Shared
	local Park=require(Shared.ParkLayout)
	local Catalog=require(Shared.ParkActivities)
	local Data=require(Shared.ParkPoseData)
	local Activity=require(Shared.GardenActivity)
	local cases={}
	local function test(name,run)run();table.insert(cases,name)end
	assert(Park.Enabled,"ParkLayout needs the v7 world")
	local root=Instance.new("Folder");root.Name="_ParkClientSpec";root.Parent=parent or workspace
	local function fakeMesh()return Instance.new("MeshPart")end
	local function near(a,b,eps)return(a.Position-b.Position).Magnitude<(eps or 1e-3)and(a.LookVector-b.LookVector).Magnitude<(eps or 1e-3)and(a.UpVector-b.UpVector).Magnitude<(eps or 1e-3)end
	local function session(id,activity,ownerId,start,ownerIds)
		return {session=id,activity=activity,ownerId=ownerId,ownerIds=ownerIds or {ownerId},walkStart=start-3,startTime=start,endTime=start+Catalog.ById[activity].duration}
	end
	local function make(block,extra)
		local folder=Instance.new("Folder");folder.Parent=root
		local options={enabled=true,parent=folder,gui=folder,createMesh=fakeMesh,park=function()return block.value end,playDate=function()return block.playDate end}
		for key,value in pairs(extra or {})do options[key]=value end
		return ParkClient.new(options),folder
	end
	local ok,err=pcall(function()

	test("flag off creates nothing and returns nil; companions keep the old six-pet rule",function()
		local folder=Instance.new("Folder");folder.Parent=root
		assert(ParkClient.new({enabled=false,parent=folder,gui=folder,createMesh=fakeMesh})==nil,"client made with the flag off")
		assert(#folder:GetDescendants()==0,"instances created with the flag off")
		local Companions=require(client.RoomCompanions)
		local plain=Companions.new(folder,function()end,function()return false end,{tiers=false})
		assert(plain.tiers==false and Companions.MaxRendered>=6)
		local Flags=require(Shared.FeatureFlags)
		assert(Companions.new(folder,function()end,function()return false end).tiers==(Flags.Park==true),"tiers must follow FeatureFlags.Park")
	end)

	test("QA Q4: local moving parts carry the import turn; their pivot sits on the group pivot",function()
		local c=make({value={version=1,slots={}}})
		c:animate(0)
		for _,name in ipairs(Data.Moving)do
			local entry=c.parts[name]
			assert(entry.part.PivotOffset==Data.pivotOffset(name),name.." pivot offset")
		end
		-- Undoing the turn gives the authored axes: the beam's front is the see-saw group's front.
		local beam=c.parts.Park_SeeSawBeam.part
		assert((beam.CFrame*Data.ImportTurn).LookVector:Dot(Data.Roots.SeeSaw.LookVector)>.99,"beam turned back to front")
		c:destroy()
	end)

	test("swings follow the swinging pet's pendulum from server times and settle after the hop",function()
		local block={value={version=1,slots={swing1=session(1,"swing",11,100)}}}
		local c=make(block)
		local entry=c.parts[Data.Swings.swing1.mesh]
		local other=c.parts[Data.Swings.swing2.mesh]
		assert(entry~=other,"both swings map to one mesh")
		local seen={}
		for _,t in ipairs({100.5,102.2,103,104.6,106.4})do
			c:animate(t)
			local angle=Data.swingAngle("swing1",block.value.slots.swing1,t)
			assert(near(entry.part.CFrame,Data.frame(entry.name,Data.Roots.SwingSet,Data.swingMotion(angle))),"swing frame at "..t)
			table.insert(seen,angle)
		end
		assert(seen[1]==0,"mount should hold the swing still")
		assert(math.abs(seen[3])>.2,"no swing at a quarter beat")
		assert(near(other.part.CFrame,Data.frame(other.name,Data.Roots.SwingSet)),"the idle swing moved")
		-- The session ends: the swing settles from the hop, reaching rest.
		local hop=Data.swingHopAt(block.value.slots.swing1)
		c:animate(hop-.01);block.value={version=1,slots={}}
		c:animate(hop+.6);assert(math.abs(entry.angle)>.01,"no settle swing after the hop")
		c:animate(hop+Data.SwingSettle.stop+.1);assert(entry.angle==0,"swing never came to rest")
		c:destroy()
	end)

	test("the see-saw tilts in counter-phase: one seat up while the other is down",function()
		local block={value={version=1,slots={}}}
		local duo=session(2,"seesaw",11,200,{11,12})
		block.value.slots.seesaw1=duo
		block.value.slots.seesaw2=table.clone(duo);block.value.slots.seesaw2.ownerId=12
		local c=make(block)
		local bob=200+Catalog.phaseStart("seesaw","bob")
		local period=Catalog.ById.seesaw.period
		for _,u in ipairs({0,.25,.5,.75})do
			local t=bob+period*(1+u)
			c:animate(t)
			local tilt=Data.seesawTilt(duo,t)
			assert(near(c.parts.Park_SeeSawBeam.part.CFrame,Data.frame("Park_SeeSawBeam",Data.Roots.SeeSaw,Data.seesawMotion(tilt))),"beam frame")
			local a,b=Data.seesawSeat("seesaw1",tilt).Y,Data.seesawSeat("seesaw2",tilt).Y
			local mid=Data.SeeSaw.pivot.Y
			if u==0 then assert(a<mid and b>mid,"seat A should be down at the beat start")end
			if u==.5 then assert(a>mid and b<mid,"seat B should be down half a beat later")end
		end
		c:animate(199);assert(c.parts.Park_SeeSawBeam.tilt==Data.SeeSaw.rest,"see-saw not at rest before the bob")
		c:destroy()
	end)

	test("the castle grows through three stages, holds, crumbles and clears",function()
		local entry=session(3,"sandboxDuo",11,300,{11,12})
		local block={value={version=1,slots={sand1=entry,sand2=table.clone(entry)}}}
		block.value.slots.sand2.ownerId=12
		local c=make(block)
		local function shown()
			local index=0
			for k=1,3 do if c.parts["Park_Castle"..k].part.Transparency<1 then assert(index==0,"two castles shown");index=k end end
			return index
		end
		local stages={}
		for t=299,300+entry.endTime-entry.startTime+1,.25 do
			c:animate(t)
			local stage,scaleY=Data.castle(entry,t)
			assert(shown()==stage,"castle "..shown().." vs "..stage.." at "..t)
			if stage>0 then
				local part=c.parts["Park_Castle"..stage].part
				assert(math.abs(part.Size.Y-Data.Meshes["Park_Castle"..stage].size.Y*scaleY)<1e-3,"castle size")
			end
			stages[stage]=true
		end
		assert(stages[1]and stages[2]and stages[3],"not every stage showed")
		c:animate(300+Catalog.phaseStart("sandboxDuo","admire")+.5);assert(shown()==3 and c.parts.Park_Castle3.scaleY==1,"admire should hold stage 3")
		c:animate(300+Catalog.phaseStart("sandboxDuo","crumble")+1.2);assert(shown()==3 and c.parts.Park_Castle3.scaleY<.5,"crumble did not squash")
		c:animate(entry.endTime+.1);assert(shown()==0,"castle left after the session")
		c:destroy()
	end)

	test("balls bounce for a solo player and arc between two pets for a toss",function()
		local block={value={version=1,slots={ball2=session(4,"ball",11,400)}}}
		local c=make(block)
		c:animate(399);assert((c.parts.Park_BallB.part.Position-Data.Ball.homeB).Magnitude<1e-3,"ball not home before play")
		c:animate(400+Catalog.ById.ball.period*1.5)
		local out=c.parts.Park_BallB.part.Position
		assert((out-Data.ballFront("ball2")).Magnitude>1.5,"solo ball never went out")
		assert((c.parts.Park_BallA.part.Position-Data.Ball.homeA).Magnitude<1e-3,"the other ball moved")
		local toss=session(5,"ballToss",11,500,{11,12})
		block.value={version=1,slots={ball1=toss,ball2=table.clone(toss)}};block.value.slots.ball2.ownerId=12
		local period=Catalog.ById.ballToss.period
		c:animate(500+period*2);assert((c.parts.Park_BallA.part.Position-Data.ballFront("ball1")).Magnitude<1e-3,"toss should start at pet 1")
		c:animate(500+period*2.25)
		local mid=c.parts.Park_BallA.part.Position;local a,b=Data.ballFront("ball1"),Data.ballFront("ball2")
		assert(mid.Y>a.Y+1 and math.abs(mid.X-(a.X+b.X)*.5)<.05,"toss is not arcing mid-way")
		c:animate(500+period*2.5);assert((c.parts.Park_BallA.part.Position-b).Magnitude<1e-3,"toss should reach pet 2")
		c:destroy()
	end)

	test("a late joiner lands mid-phase on exactly the same frames",function()
		local slots={swing1=session(6,"swing",11,600),slide=session(7,"slide",12,600),ball1=session(8,"ball",13,600)}
		local duo=session(9,"seesaw",14,600,{14,15});slots.seesaw1=duo;slots.seesaw2=table.clone(duo);slots.seesaw2.ownerId=15
		local sand=session(10,"sandbox",16,600);slots.sand2=sand
		local block={value={version=1,slots=slots}}
		local early=make(block)
		for t=600,606.25,1/30 do early:animate(t)end
		early:animate(606.3)
		local late=make(block)
		late:animate(606.3)
		for name,entry in pairs(early.parts)do
			assert(entry.part.Transparency==late.parts[name].part.Transparency,name.." visibility differs")
			if entry.part.Transparency<1 then assert(near(entry.part.CFrame,late.parts[name].part.CFrame),name.." differs for a late joiner")end
		end
		early:destroy();late:destroy()
	end)

	test("drive puts a garden pet on its swing seat and hands the server origin back each frame",function()
		local block={value={version=1,slots={swing1=session(11,"swing",21,700)}}}
		local c=make(block)
		local slot=Park.Slots.swing1
		local actor={ownerId=21,mode="Room",behavior="play",action="parkSwing",from=Activity.pack(slot.approach),to=Activity.pack(slot.approach),
			startTime=700,endTime=720,yaw=slot.yaw,generation=1,actionId=1}
		local visual={origin=slot.approach,yaw=0,worldScale=.72,greet=function()end}
		local t=703.3
		c:drive(visual,actor,t+Data.Delay,1/60,nil,false)
		local seat=Data.swingSeat("swing1",Data.swingAngle("swing1",block.value.slots.swing1,t))
		assert((visual.origin-seat.Position).Magnitude<1e-3,"pet not on the seat")
		assert((visual.parkBase-slot.approach).Magnitude<1e-3,"server origin not kept")
		local state
		for i=1,10 do state=c:drive(visual,actor,t+Data.Delay+i/60,1/60,state,false)end
		assert(visual.gaitWeight==0,"riding pet is walking")
		assert(visual.parkPose==true and visual.activitySit==true,"riding pet should sit with the feet free")
		-- The session leaves the snapshot: the pet is handed back to its plain path at once.
		block.value={version=1,slots={}}
		actor.action="wanderPause";actor.behavior="rest"
		c:drive(visual,actor,t+1,1/60,state,false)
		assert(visual.parkPose==false and(visual.origin-slot.approach).Magnitude<.01,"pet kept a park pose after the session")
		c:destroy()
	end)

	test("ring, chip and equipment allocate no instances per frame over 60 frames",function()
		local slots={swing1=session(12,"swing",31,800),seesaw1=session(13,"seesaw",32,800,{32,33}),sand1=session(14,"sandbox",34,800),ball1=session(15,"ball",35,800)}
		slots.seesaw2=table.clone(slots.seesaw1);slots.seesaw2.ownerId=33
		local block={value={version=1,slots=slots},playDate={count=1,target=3,reward=4,done=false}}
		local c,folder=make(block)
		local pet={origin=Park.Slots.ball1.approach,worldScale=.72}
		local context={camera=CFrame.lookAt(Park.Center+Vector3.new(0,12,-25),Park.Center),ownerPosition=Park.Center,ownPet=pet,active=true}
		c:step(803,context)
		local chip=folder:FindFirstChild("EggDropPark",true)
		assert(chip and chip.Enabled,"park chip not shown inside the kerb")
		assert(c.ring and c.ring.Parent,"own-pet ring not shown")
		assert(string.find(c.chipCount.Text,"1/3"),"chip should read the Play date count: "..c.chipCount.Text)
		local count=#folder:GetDescendants()
		for i=1,60 do c:step(803+i/60,context)end
		assert(#folder:GetDescendants()==count,"instances created per frame")
		block.playDate={count=3,target=3,reward=4,done=true};c:step(804.1,context)
		assert(string.find(c.chipCount.Text,"4"),"done chip should show the reward")
		context.ownerPosition=Park.Center+Vector3.new(Park.Radius.X+5,0,0)
		c:step(804.2,context)
		assert(not chip.Enabled and not c.ring.Parent,"chip/ring still shown outside the kerb")
		-- Far away: equipment frames are skipped (no writes), the chip state still updates.
		local swing=c.parts[Data.Swings.swing1.mesh];local before=swing.part.CFrame
		context.camera=CFrame.new(Park.Center+Vector3.new(0,0,ParkClient.FarDistance+50))
		c:step(805.5,context);assert(swing.part.CFrame==before,"far park still animated")
		c:destroy()
	end)

	end)
	root:Destroy()
	assert(ok,err)
	return {passed=#cases,cases=cases}
end
