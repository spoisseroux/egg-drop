-- Pet Park poses (BUILD-PLAN 2026-11-13, slice K3) on a real Bear rig built through PetFactory (like
-- PetLifeTuning.spec): every activity phase gives a finite pose, the pet sits on the swing / see-saw
-- seat and follows the chute exactly, cheers once per cheer, Reduced Motion drops the flip, and the
-- rig allocates no instances while posed frame after frame.
-- Usage (Client): require(PlayerScripts.Client.ZZSpecs.ParkPetPose)(PlayerScripts.Client, workspace)
return function(client,parent)
	local Pose=require(client.ParkPetPose)
	local Factory=require(client.PetFactory)
	local Pets=require(game.ReplicatedStorage.Shared.PetCatalog)
	local Shared=game:GetService("ReplicatedStorage").Shared
	local Park=require(Shared.ParkLayout)
	local Catalog=require(Shared.ParkActivities)
	local Data=require(Shared.ParkPoseData)
	local cases={}
	local function test(name,run)run();table.insert(cases,name)end
	local folder=Instance.new("Folder");folder.Name="_ParkPetPose";folder.Parent=parent or workspace
	local v=Factory.new(folder,Park.Center,Pets.byId.pip,.72,nil,{native=true})
	local function piece(name)for _,p in ipairs(v.pieces)do if p.name==name then return p.part end end;error(name)end
	local function finite(n)return n==n and math.abs(n)<1e6 end
	local function session(id,activity,start)return {session=id,activity=activity,ownerId=1,ownerIds={1},walkStart=start-3,startTime=start,endTime=start+Catalog.ById[activity].duration}end
	local count
	-- One posed frame: apply, then the sampler's render (forced fresh so pose levers apply now).
	local function frame(slotId,entry,t,reduced)
		v.reducedEffects=reduced==true
		local posed=Pose.apply(v,slotId,entry,t,1/30,reduced)
		v.poseDirty=true;v:update(1/30)
		for _,p in ipairs(v.pieces)do
			local position=p.part.Position
			assert(finite(position.X)and finite(position.Y)and finite(position.Z),"non-finite part "..p.name.." at "..t)
		end
		assert(#v.model:GetDescendants()==count,"pose allocated instances at "..entry.activity.." "..t)
		return posed
	end
	local ok,err=pcall(function()
		v.greeting=2;v.cosmeticSeed=3;v.poseDirty=true;v:update(0)
		count=#v.model:GetDescendants()

		test("every activity phase gives a finite pose on the real rig with no new instances",function()
			for _,id in ipairs(Catalog.Order)do
				local activity=Catalog.ById[id]
				local slotId=activity.slotSets[1][1]
				local entry=session(10,id,1000)
				local any=false
				for t=999.5,1000+activity.duration+.5,.1 do
					local posed=frame(slotId,entry,t,false)
					local index,step=Data.phase(activity,entry.startTime,t)
					if not index then assert(not posed,"posed outside the session "..id)
					elseif step.action=="parkSlideReturn"then assert(not posed,"the walk back up should be the server path")
					else assert(posed,"no pose for "..id.." "..step.name);any=true end
				end
				assert(any,"nothing posed for "..id)
			end
		end)

		test("the swing rider sits on the seat frame exactly and pitches with the swing",function()
			local entry=session(11,"swing",2000)
			local swing=2000+Catalog.phaseStart("swing","swing")
			for _,t in ipairs({swing+.3,swing+.6,swing+1.5,swing+4})do
				frame("swing1",entry,t,false)
				local angle=Data.swingAngle("swing1",entry,t)
				local seat=Data.swingSeat("swing1",angle)
				assert((v.origin-seat.Position).Magnitude<1e-3,"not on the seat at "..t)
				assert(math.abs(v.carePitch-angle)<1e-3,"pitch does not follow the swing")
				assert(v.parkPose and v.gaitWeight==0,"rider should not walk")
				assert((piece("Body").Position-seat.Position).Magnitude<1.6,"body far from the seat")
			end
			for _=1,15 do frame("swing1",entry,swing+4,false)end
			assert(v.sitWeight==1,"rider never sat down")
			-- Feet travel with the seat (never planted in the world).
			local footBefore=v.model.PrimaryPart.CFrame:PointToObjectSpace(piece("FootL").Position)
			frame("swing1",entry,swing+4.6,false)
			local footAfter=v.model.PrimaryPart.CFrame:PointToObjectSpace(piece("FootL").Position)
			assert((footBefore-footAfter).Magnitude<.05,"feet planted while swinging")
		end)

		test("see-saw riders sit on their beam seats and counter-pitch",function()
			local entry=session(12,"seesaw",3000)
			local t=3000+Catalog.phaseStart("seesaw","bob")+Catalog.ById.seesaw.period*1.2
			frame("seesaw1",entry,t,false)
			local tilt=Data.seesawTilt(entry,t)
			assert((v.origin-Data.seesawSeat("seesaw1",tilt).Position).Magnitude<1e-3,"seat A")
			local pitchA=v.carePitch
			frame("seesaw2",entry,t,false)
			assert((v.origin-Data.seesawSeat("seesaw2",tilt).Position).Magnitude<1e-3,"seat B")
			assert(math.abs(pitchA+v.carePitch)<1e-3 and math.abs(pitchA)>.05,"seats should pitch opposite ways")
		end)

		test("the slide follows the ladder, the chute path and lands on the chute end",function()
			local entry=session(13,"slide",4000)
			local climb=4000+Catalog.phaseStart("slide","climb")
			frame("slide",entry,climb+.001,false)
			assert((v.origin-Data.Slide.ladder[1]).Magnitude<.05,"climb should start at the ladder foot")
			frame("slide",entry,climb+1.999,false)
			assert((v.origin-Data.Slide.platform).Magnitude<.05,"climb should end on the deck")
			local slide=4000+Catalog.phaseStart("slide","slide")
			for u=.05,.95,.15 do
				frame("slide",entry,slide+1.2*u,false)
				local best=math.huge
				for i=2,#Data.Slide.chute do
					local a,b=Data.Slide.chute[i-1],Data.Slide.chute[i]
					local d=b-a;local w=math.clamp((v.origin-a):Dot(d)/d:Dot(d),0,1)
					best=math.min(best,(v.origin-(a+d*w)).Magnitude)
				end
				assert(best<1e-3,"off the chute at "..u)
				assert(v.carePitch>=0 and v.activitySit,"should sit nose-down on the chute")
			end
			local tumble=4000+Catalog.phaseStart("slide","tumble")
			frame("slide",entry,tumble+.8-1e-3,false)
			assert((v.origin-Park.Slots.slide.chuteEnd).Magnitude<.05,"tumble should land on the chute end")
			frame("slide",entry,tumble+.4,false);assert(v.carePitch>1,"no forward roll")
			frame("slide",entry,tumble+.4,true);assert(v.carePitch==0,"Reduced Motion should not flip")
		end)

		test("sand and ball pets stand on the surface facing their play, and each cheer greets once",function()
			local sand=session(14,"sandbox",5000)
			frame("sand2",sand,5001,false)
			assert((v.origin-Data.spot("sand2")).Magnitude<1e-3 and v.yaw==Park.Slots.sand2.yaw,"sand spot")
			local ball=session(15,"ball",6000)
			frame("ball1",ball,6001,false)
			assert((v.origin-Data.spot("ball1")).Magnitude<1e-3 and v.yaw==Park.Slots.ball1.yaw,"ball spot")
			local greets=0;local greet=v.greet
			v.greet=function(self)greets+=1;return greet(self)end
			local cheer=6000+Catalog.phaseStart("ball","cheer")
			for i=0,10 do frame("ball1",ball,cheer+i*.1,false)end
			v.greet=greet
			assert(greets==1,"cheer greeted "..greets.." times")
		end)

		test("QA Q4: swing and see-saw riders wait in front of the seat and land back on that point",function()
			for _,pair in ipairs({{"swing1","swing"},{"swing2","swing"},{"seesaw1","seesaw"},{"seesaw2","seesaw"}})do
				local slotId,activityId=pair[1],pair[2]
				local slot=Park.Slots[slotId]
				local entry=session(20,activityId,8000)
				-- The wait point is in front of the seat, clear of it.
				local out=slot.approach-slot.seatGround
				assert(Vector2.new(out.X,out.Z).Magnitude>1,slotId.." waits under its seat")
				if activityId=="swing"then assert(out:Dot(Data.facing(slot.yaw))>1,slotId.." waits behind the swing")end
				frame(slotId,entry,8000.001,false)
				assert((v.origin-slot.approach).Magnitude<.05,slotId.." mount does not start where the pet waits")
				local cheer=8000+Catalog.phaseStart(activityId,"cheer")
				frame(slotId,entry,cheer-.001,false)
				assert((v.origin-slot.approach).Magnitude<.05,slotId.." hop does not land on the wait point")
				for i=1,13 do
					frame(slotId,entry,cheer+i*.1,false)
					assert(Vector2.new(v.origin.X-slot.approach.X,v.origin.Z-slot.approach.Z).Magnitude<.01,slotId.." walks during the cheer")
				end
			end
		end)

		test("QA Q4: the slide pet waits facing the ladder; the ladder rises toward the deck and the chute runs away",function()
			local slot=Park.Slots.slide
			local toDeck=Data.Slide.platform-slot.approach
			assert(Data.facing(slot.yaw):Dot(Vector3.new(toDeck.X,0,toDeck.Z).Unit)>.9,"the pet waits facing away from the ladder")
			assert((Data.Slide.ladder[1]-slot.approach).Magnitude<1e-3,"the climb starts at the wait point")
			local top,foot=Data.Slide.chute[1],Data.Slide.chute[#Data.Slide.chute]
			assert(top.Y>foot.Y+1.5 and Vector2.new(foot.X-slot.chuteEnd.X,foot.Z-slot.chuteEnd.Z).Magnitude<.3,"the chute does not run down to the chute end")
			assert((Vector2.new(foot.X,foot.Z)-Vector2.new(slot.approach.X,slot.approach.Z)).Magnitude>6,"chute foot beside the ladder")
		end)

		test("a pet whose partner left hops off on its own clock",function()
			local actor={action=Catalog.HopOffAction,startTime=7000,endTime=7000+Catalog.HopOffSeconds,actionId=5}
			v.origin=Park.Slots.seesaw1.approach
			assert(Pose.hopOff(v,actor,7000.45,false)and v.movementBob>0,"no hop")
			assert(not Pose.hopOff(v,actor,7002,false),"hop after its end")
			Pose.clear(v);assert(v.parkPose==false)
		end)
	end)
	v:destroy();folder:Destroy()
	assert(ok,err)
	return {passed=#cases,cases=cases}
end
