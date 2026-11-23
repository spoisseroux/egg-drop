-- Pets catch up (beta (12) QA G1): the gate, the far and stuck rules, the rate limits, the landing rings and the
-- landing rules (safe ground, island walls, the course and pad only while racing). Pure; no instances.
-- Usage (Server): require(ServerScriptService.Server.ZZSpecs.PetCatchup)(ServerScriptService.Server); offline in
-- scripts/run_dash_server_specs.py.
return function(_server)
	local Shared=game:GetService("ReplicatedStorage").Shared
	local Catchup=require(Shared.PetCatchup)
	local Bounds=require(Shared.IslandBounds)
	local Course=require(Shared.DashCourse)
	local cases={}
	local function test(name,run)run();table.insert(cases,name)end
	local LIVE=96451847774961

	test("gate: flag and the beta place or Studio; live never; the switch is off until set",function()
		local flags={PetCatchup=true}
		assert(Catchup.ceiling({flags=flags,place=Catchup.PlaceId,studio=false}))
		assert(Catchup.ceiling({flags=flags,place=0,studio=true}))
		assert(not Catchup.ceiling({flags=flags,place=LIVE,studio=false}),"live")
		assert(not Catchup.ceiling({flags={},place=Catchup.PlaceId,studio=true}),"flag missing")
		for _,row in ipairs({{nil,nil,true},{false,nil,false},{true,false,false},{"x",nil,true},{false,true,true}})do
			assert(Catchup.resolve(row[1],row[2],true)==row[3])
		end
		assert(Catchup.resolve(true,true,false)==false,"ceiling closed: off whatever is set")
	end)
	test("far: over Far for FarHold at the decide cadence; a dip under Far starts again; a gap in decides resets",function()
		local t={}
		local at=Vector3.new(0,0,0)
		assert(Catchup.step(t,0,Catchup.Far+5,at,true)==nil)
		assert(Catchup.step(t,1,Catchup.Far+5,at+Vector3.new(5,0,0),true)==nil,"1 s")
		assert(Catchup.step(t,1.5,Catchup.Far+5,at+Vector3.new(10,0,0),true)=="far","1.5 s")
		t={}
		Catchup.step(t,0,Catchup.Far+5,at,false);Catchup.step(t,.5,Catchup.Far-1,at,false)
		assert(Catchup.step(t,1.5,Catchup.Far+5,at,false)==nil,"a dip restarts the hold")
		t={}
		Catchup.step(t,0,Catchup.Far+5,at,false)
		assert(Catchup.step(t,10,Catchup.Far+5,at,false)==nil,"a stall (switch off) resets")
		assert(Catchup.step(t,10.5,Catchup.Far+5,at,false)==nil and Catchup.step(t,11.5,Catchup.Far+5,at,false)=="far")
	end)
	test("stuck: over StuckNear, the pet itself still for StuckSeconds; moving or greeting is never stuck",function()
		local t={}
		local at=Vector3.new(3,0,3)
		for k=0,7 do assert(Catchup.step(t,k*.5,15,at,true)==nil,"before 4 s")end
		assert(Catchup.step(t,4,15,at,true)=="stuck")
		t={}
		for k=0,20 do assert(Catchup.step(t,k*.5,15,at+Vector3.new(k*.6,0,0),true)==nil,"walking (1.2 studs/s) is progress")end
		t={}
		for k=0,20 do assert(Catchup.step(t,k*.5,15,at,false)==nil,"a greeting is never stuck")end
		t={}
		for k=0,20 do assert(Catchup.step(t,k*.5,Catchup.StuckNear-1,at,true)==nil,"near is not stuck")end
	end)
	test("rate: Cooldown after a hop, Retry after no landing, Burst hops in a minute -> BurstQuiet",function()
		local t={}
		local at=Vector3.zero
		for k=0,3 do Catchup.step(t,k*.5,Catchup.Far+1,at,false)end
		assert(Catchup.done(t,1.5,false)==nil and t.nextAt==1.5+Catchup.Retry)
		assert(Catchup.step(t,2,Catchup.Far+1,at,false)==nil,"retry wait")
		assert(Catchup.step(t,3.5,Catchup.Far+1,at,false)=="far")
		assert(Catchup.done(t,3.5,true)==nil and t.nextAt==3.5+Catchup.Cooldown and t.farSince==nil)
		local now,result=3.5,nil
		for _=2,Catchup.Burst do now+=Catchup.Cooldown;result=Catchup.done(t,now,true)end
		assert(result=="burst"and t.quietUntil==now+Catchup.BurstQuiet,"the loop guard")
		for k=1,10 do Catchup.step(t,now+k*.5,Catchup.Far+1,at,false)end
		assert(Catchup.step(t,now+Catchup.BurstQuiet-1,Catchup.Far+1,at,false)==nil,"quiet")
	end)
	test("landing rings: the anchor, then 8 bearings at 2.5 and 4 studs, the one behind the owner first",function()
		local anchor=Vector3.new(10,4,10)
		local list=Catchup.candidates(anchor,Vector3.new(0,0,-1)) -- facing -Z: behind is +Z
		assert(#list==1+2*Catchup.Bearings and list[1]==anchor)
		local behind=list[2]-anchor
		assert(math.abs(behind.Magnitude-2.5)<1e-6 and behind.Z>2.4,"behind the owner first")
		assert(math.abs((list[1+Catchup.Bearings+1]-anchor).Magnitude-4)<1e-6)
		for _,p in ipairs(list)do assert(p.Y==anchor.Y and Catchup.flat(p,anchor)<=4+1e-6)end
		assert(#Catchup.candidates(anchor,nil)==#list,"no facing: still every ring")
	end)
	test("landing rules: safe ground, WallKeep from every island wall, the course and pad only while racing",function()
		assert(not Catchup.clear(0/0,0,false)and not Catchup.clear("x",0,false))
		-- Find cells by search over the walk map (no hand-typed coordinates that a re-export would move).
		local open,nearWall,nearCourse,onPad
		local pad={x=Course.Pad.x/100,z=Course.Pad.z/100,r=Course.Pad.r/100}
		for x=-120,120 do
			for z=-120,120 do
				if Bounds.safeCell(x,z)then
					local wall=math.huge
					for _,w in ipairs(Bounds.Walls)do wall=math.min(wall,Bounds.distance(w,x,z))end
					local course=Catchup.courseDistance(x,z)
					local padD=math.sqrt((x-pad.x)^2+(z-pad.z)^2)
					if not open and wall>10 and course>10 and padD>pad.r+5 then open={x,z}end
					if not nearWall and wall<Catchup.WallKeep then nearWall={x,z}end
					if not nearCourse and course<2 and wall>10 and padD>pad.r+5 then nearCourse={x,z}end
					if not onPad and padD<pad.r and wall>10 then onPad={x,z}end
				end
			end
		end
		assert(open and nearCourse,"the walk map has open lawn and course cells")
		assert(Catchup.clear(open[1],open[2],false)and Catchup.clear(open[1],open[2],true),"open lawn")
		if nearWall then local ok,why=Catchup.clear(nearWall[1],nearWall[2],false);assert(not ok and why=="wall",why)end
		assert(Catchup.clear(nearCourse[1],nearCourse[2],false),"no race: the course is lawn")
		local ok,why=Catchup.clear(nearCourse[1],nearCourse[2],true);assert(not ok and why=="course",why)
		if onPad then
			assert(Catchup.clear(onPad[1],onPad[2],false)or Catchup.courseDistance(onPad[1],onPad[2])<Catchup.CourseKeep)
			assert(not Catchup.clear(onPad[1],onPad[2],true),"the pad while racing")
		end
		-- Off the island: never.
		local off,whyOff=Catchup.clear(5000,5000,false);assert(not off and whyOff=="ground")
	end)
	return{passed=#cases,cases=cases}
end
