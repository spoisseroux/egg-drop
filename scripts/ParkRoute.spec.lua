-- Park walk routes (beta (34) QA, Spencer: "the pet walks thru the slide meshes etc to walk back to the ladder to go up
-- it"). Pure: every site's footprints (ParkRoute) cover its toys' meshes and scale with the Top Lawn's x1.25 toys; then
-- every walk leg a park pet takes is walked at 0.08 s steps on every site layout (the arrival, the old grove, the
-- Hollow, the Top Lawn): slot to slot, the chute's end to every slot, rim entry points in and out, seeded mingle
-- strolls, and the slide's walk back to the ladder inside its play path. No sample may stand inside a toy's footprint
-- except within Near studs of the entered (or left) toy's own play spot.
-- Usage (Server): require(ServerScriptService.Server.ZZSpecs.ParkRoute)(ServerScriptService.Server)
return function(server,offline)
	local Shared=game:GetService("ReplicatedStorage").Shared
	local Park=require(Shared.ParkLayout)
	local Data=require(Shared.ParkPoseData)
	local Route=require(Shared.ParkRoute)
	local A=require(Shared.GardenActivity)
	local Catalog=require(Shared.ParkActivities)
	local Director=require(server.ParkDirector)
	local cases={}
	local function test(name,run)run();table.insert(cases,name)end
	local NEAR=2 -- studs from a toy's own play spot a walk may stand inside that toy's footprint
	local STEP=.08 -- a stroll moves under .4 studs a step; the thinnest footprint is 1.4 across with its margin

	local function unscaled(spec)local copy=table.clone(spec);copy.toyScale=nil;return table.freeze(copy)end
	local SITES={
		{"arrival",Park},
		{"grove",Park.build(Park.Specs.grove)},
		{"hollow",Park.build(Park.Specs.hollow)},
		{"topLawn",Park.build(Park.Specs.topLawn)},
		{"topLawn x1",Park.build(unscaled(Park.Specs.topLawn))},
	}
	local GROUPS={SwingSet="swing",Slide="slide",SeeSaw="seesaw",Sandbox="sandbox",BallCorner="ball"}
	local function v2(p)return Vector2.new(p.X,p.Z)end
	local function byEquipment(site)
		local out={}
		for _,f in ipairs(Route.footprints(site))do if f.kind=="toy"then out[f.equipment]=f end end
		return out
	end

	test("footprints: one per toy, each covering every one of its meshes; benches and dressing stones too",function()
		for _,row in ipairs(SITES)do
			local name,site=row[1],row[2]
			local toys=byEquipment(site)
			for _,id in ipairs({"swing","slide","seesaw","sandbox","ball"})do assert(toys[id],name.." has no "..id.." footprint")end
			for _,entry in ipairs(Data.forSite(site).layout().static)do
				local id=GROUPS[entry.group]
				if not id then continue end
				local cf,half=entry.cframe,entry.size*.5
				for _,sx in ipairs({-1,1})do for _,sz in ipairs({-1,1})do
					local corner=cf:PointToWorldSpace(Vector3.new(sx*half.X,0,sz*half.Z))
					assert(Route.insidePoly(toys[id].poly,v2(corner),-1e-3),string.format("%s: %s's %s corner outside its footprint",name,id,entry.mesh))
				end end
			end
			local benches,stones=0,0
			for _,f in ipairs(Route.footprints(site))do
				if f.kind=="bench"then benches+=1 elseif f.kind=="dressing"then stones+=1 end
			end
			assert(benches==#site.Benches,name.." benches")
			local keep=0;for _,zone in ipairs(site.Keepout)do if zone.dressing then keep+=1 end end
			assert(stones==keep,name.." dressing stones")
		end
	end)

	test("the Top Lawn's footprints are x1.25 of its unscaled toys' (Park.ToyScale)",function()
		local scaled,plain=byEquipment(SITES[4][2]),byEquipment(SITES[5][2])
		for id,f in pairs(scaled)do
			local g=plain[id]
			assert(math.abs(f.rect.half.X-g.rect.half.X*1.25)<1e-4 and math.abs(f.rect.half.Y-g.rect.half.Y*1.25)<1e-4,id.." footprint is not x1.25")
		end
	end)

	-- Walk a path at STEP seconds; every sample inside a toy footprint must be within NEAR of an allowed {equipment,
	-- point}. Also inside the park (1.5 studs of slack for the edge steps) when `keepIn`. Returns the samples.
	local function walk(site,label,path,allowed,from,to,keepIn)
		local total=0
		for _,leg in ipairs(path)do total+=leg.duration end
		local actor={from=path[1].from,to=path[#path].to,path=path,startTime=0,endTime=math.max(total,.001),action="wander",behavior="investigate"}
		local toys=Route.footprints(site)
		local t=from or 0
		local stop=to or total
		local count=0
		while t<=stop+1e-9 do
			local p=A.sample(actor,t).position
			for _,f in ipairs(toys)do
				if f.kind=="toy"and Route.insidePoly(f.poly,v2(p),1e-6)then
					local ok=false
					for _,allow in ipairs(allowed)do
						if allow[1]==f.equipment and(v2(p)-v2(allow[2])).Magnitude<=NEAR then ok=true;break end
					end
					assert(ok,string.format("%s: at %.2f s the walk stands inside the %s at (%.2f, %.2f)",label,t,f.equipment,p.X,p.Z))
				end
			end
			if keepIn then assert(site.inside(p,1.5),string.format("%s: at %.2f s the walk leaves the park at (%.2f, %.2f)",label,t,p.X,p.Z))end
			count+=1;t+=STEP
		end
		return count
	end
	-- The places a park pet walks between: every slot's approach (entered by its own toy), the chute's end (left by the
	-- slide), the rim entry points a pet walks in to, and seeded standable mingle spots.
	local function stations(site)
		local out={}
		for _,id in ipairs(site.SlotOrder)do
			local slot=site.Slots[id]
			table.insert(out,{label=id,point=slot.approach,toy=slot.equipment})
		end
		table.insert(out,{label="chuteEnd",point=site.Slots.slide.chuteEnd,toy="slide"})
		local D=Director.forSite(site)
		for k=0,7 do
			local a=k*math.pi/4+.2
			local owner=Vector3.new(site.Center.X+site.Radius.X*.9*math.cos(a),site.Center.Y,site.Center.Z+site.Radius.Y*.9*math.sin(a))
			local entry=D.entryPoint(owner)
			if D.standable(entry)then table.insert(out,{label="entry"..k,point=entry})end
		end
		local seed=20261126
		local function random()seed=(seed*1103515245+12345)%2147483648;return seed/2147483648 end
		local found=0
		for _=1,400 do
			if found>=10 then break end
			local a,r=random()*math.pi*2,math.sqrt(random())
			local x,z=site.Center.X+site.Radius.X*r*math.cos(a),site.Center.Z+site.Radius.Y*r*math.sin(a)
			local p=Vector3.new(x,site.ground(x,z),z)
			if site.inside(p,-2)and site.clearOfKeepout(p,.5)and D.standable(p)then found+=1;table.insert(out,{label="mingle"..found,point=p})end
		end
		return out
	end

	test("every leg between the places a park pet walks keeps out of every toy but the one it enters or leaves",function()
		local routes,samples,detours=0,0,0
		for _,row in ipairs(SITES)do
			local name,site=row[1],row[2]
			local list=stations(site)
			assert(#list>=20,name.." has too few walk stations")
			for _,a in ipairs(list)do for _,b in ipairs(list)do
				if a==b then continue end
				local path,seconds,routed=Route.plan(site,a.point,b.point,Vector3.zero,site.WalkSpeed,0)
				assert(routed,string.format("%s: no way round from %s to %s",name,a.label,b.label))
				local last=path[#path]
				assert((A.vector(last.to)-b.point).Magnitude<.1,name..": "..a.label.." -> "..b.label.." ends short")
				local allowed={}
				if a.toy then table.insert(allowed,{a.toy,a.point})end
				if b.toy then table.insert(allowed,{b.toy,b.point})end
				samples+=walk(site,name.." "..a.label.." -> "..b.label,path,allowed,nil,nil,true)
				routes+=1
				if #path>3 then detours+=1 end
			end end
		end
		assert(routes>1000 and detours>0,"routes "..routes.." detours "..detours)
	end)

	test("the slide's walk back to the ladder goes round the slide, in its 3.4 s phase, ending turned to the ladder",function()
		local slide=Catalog.ById.slide
		for _,row in ipairs(SITES)do
			local name,site=row[1],row[2]
			local slot=site.Slots.slide
			local D=Director.forSite(site)
			for _,yaw in ipairs({0,slot.yaw,slot.yaw+math.pi})do
				local path,position,heading=D.playPath(slot,slide,yaw)
				local total=0
				for _,leg in ipairs(path)do total+=leg.duration end
				assert(math.abs(total-slide.duration)<1e-6,name..": the play path lasts "..total)
				assert((position-slot.chuteEnd).Magnitude<1e-6,name..": the play ends off the chute's end (the cheer)")
				-- Walk both return phases: the first ends at the ladder, the second at the chute's end (the cheer).
				local start=Catalog.phaseStart(slide,"return")
				local phase
				for _,step in ipairs(slide.phases)do if step.name=="return"then phase=step end end
				walk(site,name.." slide return",path,{{"slide",slot.chuteEnd},{"slide",slot.approach}},start,start+phase.duration,true)
				local actor={from=path[1].from,to=path[#path].to,path=path,startTime=0,endTime=total,action="parkSlide",behavior="play"}
				local back=A.sample(actor,start+phase.duration-.01)
				assert((back.position-slot.approach).Magnitude<.05,name..": not back at the ladder when the climb starts")
				local turn=math.atan2(math.sin(back.yaw-slot.yaw),math.cos(back.yaw-slot.yaw))
				assert(math.abs(turn)<.05,string.format("%s: faces %.2f, not the ladder (%.2f), as the climb starts",name,back.yaw,slot.yaw))
				-- The walk is a trot, not a teleport.
				local fastest,at=0,A.sample(actor,start).position
				for t=start+STEP,start+phase.duration,STEP do
					local p=A.sample(actor,t).position
					fastest=math.max(fastest,(v2(p)-v2(at)).Magnitude/STEP);at=p
				end
				assert(fastest<14,string.format("%s: the walk back peaks at %.1f studs/s",name,fastest))
				local _=heading
			end
		end
	end)

	test("review B35: a walk back that cannot fit its phase never overruns it (the straight move instead)",function()
		local slide=Catalog.ById.slide
		for _,row in ipairs(SITES)do
			local name,site=row[1],row[2]
			local slot=site.Slots.slide
			-- The slide's timeline with the walk back squeezed to 0.3 s: no route round fits that.
			local phases={}
			for index,step in ipairs(slide.phases)do
				phases[index]=if step.name=="return"then table.freeze({name=step.name,action=step.action,duration=.3})else step
			end
			local total=0;for _,step in ipairs(phases)do total+=step.duration end
			local squeezed={id="slide",phases=phases,duration=total}
			local path=Director.forSite(site).playPath(slot,squeezed,slot.yaw)
			local sum=0;for _,leg in ipairs(path)do sum+=leg.duration end
			assert(math.abs(sum-total)<1e-6,name..": the play path lasts "..sum.." of "..total)
			local start=0;for _,step in ipairs(phases)do if step.name=="return"then break end;start+=step.duration end
			local actor={from=path[1].from,to=path[#path].to,path=path,startTime=0,endTime=sum,action="parkSlide",behavior="play"}
			assert((A.sample(actor,start+.3-1e-4).position-slot.approach).Magnitude<.05,name..": not at the ladder when the climb starts")
		end
	end)

	test("review B35: a director builds its park's route graphs when it is made, not on the first walk",function()
		local site=Park.build(Park.Specs.hollow)
		assert(not Route.prepared(site),"a fresh layout has no graphs yet")
		Director.forSite(site).new({options={now=function()return 0 end},actors={},inputs={}},{random=function()return .5 end})
		assert(Route.prepared(site),"Director.new did not build them")
		assert(Route.prepare(site)==false,"built twice")
	end)

	test("review B35: a mingle walk is taken only when it ends at the spot with no safety stop (Director.reaches)",function()
		local D=Director.forSite(Park)
		local at=Park.Center
		local path=A.plan(at,at+Vector3.new(3,0,0),Vector3.zero,4,0,0,nil,Vector3.zero)
		assert(D.reaches(path,at+Vector3.new(3,0,0)))
		assert(not D.reaches(path,at+Vector3.new(4,0,0)),"ends short")
		local stopped=table.clone(path);stopped[1]=table.clone(path[1]);stopped[1].safetyStop=true
		assert(not D.reaches(stopped,at+Vector3.new(3,0,0)),"a safety stop")
		assert(not D.reaches(nil,at)and not D.reaches({},at))
	end)

	test("the old straight walk back crossed the slide (the bug this fixes)",function()
		for _,row in ipairs(SITES)do
			local site=row[2]
			local slot=site.Slots.slide
			assert(not Route.segmentClear(site,slot.chuteEnd,slot.approach),row[1]..": the straight line misses the slide?")
		end
	end)

	test("greeting spots and the director's walk: standable means off every footprint with the margin",function()
		for _,row in ipairs(SITES)do
			local site=row[2]
			local D=Director.forSite(site)
			for _,slotId in ipairs(site.SlotOrder)do
				local slot=site.Slots[slotId]
				-- A slot's approach is its own toy's: never a place to send a wandering pet.
				if #Route.at(site,slot.approach,true)>0 then assert(not D.standable(slot.approach))end
			end
			assert(D.standable(site.Center)==(#Route.at(site,site.Center,true)==0))
		end
	end)

	return {passed=#cases,cases=cases}
end
