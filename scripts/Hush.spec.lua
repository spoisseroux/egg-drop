-- The Hush greybox (HUSH-GREYBOX-BUILD-PLAN.md): the gate, the pet floor test (off is exactly the old Floor test), the
-- regions, doors and landings against the live world data (WorldV7Data, HollowWorldLayout.V7, IslandBounds, the find
-- spots, the Dash course, the nest), and the greybox rows (names, sizes, floors under every arrival, the walls round the
-- hollow, the ramp). Rerun after any world re-export: the clearance cases read the world data, not copied numbers.
-- Usage (Server): require(ServerScriptService.Server.ZZSpecs.Hush)(ServerScriptService.Server)
-- Offline: python scripts/run_dash_server_specs.py
return function(server)
	local Shared=game:GetService("ReplicatedStorage").Shared
	local Hush=require(Shared.Hush)
	local Rows=require(Shared.HushGreybox)
	local Bounds=require(Shared.IslandBounds)
	local Data=require(Shared.WorldV7Data)
	local V7=require(Shared.HollowWorldLayout).V7
	local Spots=require(Shared.FindSpots)
	local Course=require(Shared.DashCourse)
	local Nest=require(Shared.Nest)
	local cases={}
	local function test(name,run)run();table.insert(cases,name)end
	local LIVE=96451847774961
	-- The v7 Floor part as LoungeWorldV7Art makes it.
	local FLOOR={CFrame=CFrame.new(V7.FloorCenterX,V7.FloorTop-.5,V7.FloorCenterZ),Size=Vector3.new(V7.Width,1,V7.Depth)}
	local function oldTest(floor,p)
		local at=floor.CFrame:PointToObjectSpace(p)
		return not(math.abs(at.X)>floor.Size.X*.5-1 or math.abs(at.Z)>floor.Size.Z*.5-1)
	end
	local function inPetFloor(p)for _,b in ipairs(Hush.PetFloors)do if Hush.inBox(b,p)then return true end end return false end

	test("the ceiling: the flag and the beta place or Studio; live never; a missing or malformed switch is on",function()
		local F={Hush=true}
		assert(Hush.ceiling({flags=F,studio=false,place=Hush.PlaceId})and Hush.ceiling({flags=F,studio=true,place=1}))
		assert(not Hush.ceiling({flags=F,studio=false,place=LIVE})and not Hush.ceiling({flags={},studio=true}))
		assert(not Hush.ceiling({flags={Hush=false},studio=true,place=Hush.PlaceId}))
		assert(Hush.resolve(nil,nil,true)==true and Hush.resolve("x",nil,true)==true and Hush.resolve(false,nil,true)==false)
		assert(Hush.resolve(false,true,true)==true and Hush.resolve(true,false,true)==false and Hush.resolve(true,true,false)==false)
		assert(Hush.PlaceId==107705084891479 and Hush.Key=="garden_hush"and Hush.Attribute=="Hush_on")
		Hush.inject({flags=F,studio=false,place=LIVE});assert(not Hush.on())
		Hush.inject({flags=F,studio=true,on=false});assert(not Hush.on())
		Hush.inject({flags=F,studio=true});assert(Hush.on())
		Hush.inject(nil)
	end)

	test("the pet floor test: closed (false or nil) is the old Floor test exactly; open adds the Hush floors and nothing else",function()
		local floors={FLOOR,{CFrame=CFrame.new(3,4,-7)*CFrame.Angles(0,.4,0),Size=Vector3.new(50,1,30)}}
		local points={}
		for x=-130,130,2.5 do for z=-110,100,2.5 do table.insert(points,Vector3.new(x,4,z))end end
		-- The exact edges (Size/2 - 1) and a hair either side, and NaN.
		for _,dx in ipairs({-.001,0,.001})do
			table.insert(points,Vector3.new(V7.FloorCenterX+V7.Width/2-1+dx,4,0))
			table.insert(points,Vector3.new(0,4,V7.FloorCenterZ-V7.Depth/2+1-dx))
		end
		local nan=0/0
		table.insert(points,Vector3.new(nan,4,0));table.insert(points,Vector3.new(0,nan,nan))
		for _,p in ipairs({Hush.Doors.north.arrival.Position,Hush.Doors.north.landing,Hush.at(0,60,0),Hush.at(5,130,0)})do table.insert(points,p)end
		for _,floor in ipairs(floors)do
			for _,p in ipairs(points)do
				local old=oldTest(floor,p)
				assert(Hush.onPetFloor(floor,p,false)==old and Hush.onPetFloor(floor,p,nil)==old and Hush.onPetFloor(floor,p,1)==old,tostring(p))
				assert(Hush.onPetFloor(floor,p,true)==(old or inPetFloor(p)),tostring(p))
			end
		end
		assert(Hush.onPetFloor(FLOOR,Hush.at(0,60,0),true)and not Hush.onPetFloor(FLOOR,Hush.at(0,60,0),false))
		-- No Underway pet floor (spec G0): the pocket is neither home Floor nor Hush.
		assert(not Hush.onPetFloor(FLOOR,Vector3.new(-7,4,-108),true))
	end)

	test("regions: the hollow is outside the island's ring and clear of every colliding world part; the pocket is inside the ring",function()
		assert(Hush.regionAt(Hush.at(0,60,0))=="hush"and Hush.regionAt(Vector3.new(-7,5,-108))=="underway")
		assert(Hush.regionAt(Vector3.new(0,5,0))==nil and Hush.regionAt(Vector3.new(-7,5,-95))==nil)
		local H=Hush.Hollow
		for x=H.min.X,H.max.X,4 do for z=H.max.Z,H.min.Z,-4 do
			assert(not Bounds.inside(x,z)and Bounds.ringDistance(x,z)>Bounds.Margin,string.format("hollow (%d, %d) is on the island",x,z))
		end end
		for x=-12,-2,2 do for z=-100,-114,-2 do assert(Bounds.inside(x,z),string.format("pocket (%d, %d) is outside the ring",x,z))end end
		-- Every colliding world part's bounds stay out of the hollow; so do the island's underside and the drift rocks.
		local function overlap(c,s)
			return c[1]+s[1]/2>H.min.X and c[1]-s[1]/2<H.max.X and c[2]+s[2]/2>H.min.Y and c[2]-s[2]/2<H.max.Y
				and c[3]+s[3]/2>H.min.Z and c[3]-s[3]/2<H.max.Z
		end
		local checked=0
		for name,part in pairs(Data.parts)do
			if part.collide or part.region=="Underside"or string.find(part.region or "","DriftRocks")or part.region=="Ground"then
				checked+=1
				assert(not overlap(part.center,part.size),name.." reaches into the Hush")
			end
		end
		assert(checked>20)
		local catch=Data.fallCatch
		assert(H.min.X>catch.center[1]-catch.size[1]/2 and H.max.X<catch.center[1]+catch.size[1]/2)
		assert(H.min.Z>catch.center[3]-catch.size[3]/2 and Hush.FallY>catch.center[2]+catch.size[2]/2)
	end)

	test("doors: arrivals clear of every trigger, on their side; landings and the evacuation where the plan puts them",function()
		local north,home=Hush.Doors.north,Hush.Doors.home
		assert(Hush.inBox(Hush.Pocket,north.trigger.min)and Hush.inBox(Hush.Pocket,north.trigger.max))
		assert(Hush.inBox(Hush.Hollow,home.trigger.min)and Hush.inBox(Hush.Hollow,home.trigger.max))
		local function gap(b,p)
			local dx=math.max(b.min.X-p.X,0,p.X-b.max.X)
			local dz=math.max(b.min.Z-p.Z,0,p.Z-b.max.Z)
			return math.sqrt(dx*dx+dz*dz)
		end
		for _,offset in ipairs(Hush.ArrivalOffsets)do
			local a=(north.arrival*CFrame.new(offset)).Position
			assert(Hush.regionAt(a)=="hush"and inPetFloor(a)and Hush.safeCell(a.X,a.Z))
			assert(gap(home.trigger,a)>=3.5 and gap(north.trigger,a)>50,tostring(a))
			local b=(home.arrival*CFrame.new(offset)).Position
			assert(Hush.regionAt(b)=="underway"and gap(north.trigger,b)>=3.5,tostring(b))
			local e=(Hush.Evacuation.arrival*CFrame.new(offset)).Position
			assert(Hush.regionAt(e)==nil and oldTest(FLOOR,e),tostring(e))
			-- Pet landings: in the Hush on a pet floor and safe ground; home ones inside the home Floor, never a Hush floor.
			local l=north.landing+north.arrival:VectorToWorldSpace(offset)
			assert(inPetFloor(l)and Hush.safeCell(l.X,l.Z),tostring(l))
			for _,spot in ipairs({home.landing+home.arrival:VectorToWorldSpace(offset),
				Hush.Evacuation.landing+Hush.Evacuation.arrival:VectorToWorldSpace(offset)})do
				assert(oldTest(FLOOR,spot)and not inPetFloor(spot)and Hush.regionAt(spot)==nil,tostring(spot))
				assert(Bounds.safeCell(spot.X,spot.Z),"not safe home ground: "..tostring(spot))
			end
		end
		-- Arrivals face the way you were walking: north into the Hush, south out of the pocket.
		assert(north.arrival.LookVector.Z<-.99 and home.arrival.LookVector.Z>.99 and Hush.Evacuation.arrival.LookVector.Z>.99)
		assert(not Hush.safeCell(0/0,0)and not Hush.safeCell(0,0)and not Hush.safeCell(-7,-108))
	end)

	test("nothing placed at home is near the pocket; no island wall crosses the mouth's walkable strip",function()
		local P=Hush.Pocket
		local function gap(x,z)
			local dx=math.max(P.min.X-x,0,x-P.max.X)
			local dz=math.max(P.min.Z-z,0,z-P.max.Z)
			return math.sqrt(dx*dx+dz*dz)
		end
		for k,s in ipairs(Spots)do assert(gap(s.x/100,s.z/100)>=6,"find spot "..k)end
		for _,list in ipairs({Course.Main,Course.Branch})do
			for k=1,#list,4 do assert(gap(list[k+1]/100,list[k+3]/100)>=6,"dash d="..list[k])end
		end
		assert(gap(Course.Pad.x/100,Course.Pad.z/100)>=6 and gap(Nest.Spot.X,Nest.Spot.Z)>=6)
		for id,cf in pairs(V7.Stations)do assert(gap(cf.Position.X,cf.Position.Z)>=6,id)end
		for _,w in ipairs(Bounds.Walls)do
			for t=0,1,.02 do
				local x,z=w.x1+(w.x2-w.x1)*t,w.z1+(w.z2-w.z1)*t
				assert(not(x>=-12 and x<=-3 and z<=-88 and z>=-116),w.id.." crosses the mouth")
			end
		end
	end)

	-- Axis-aligned rows (all but the ramp): is p inside, grown by `pad`?
	local function inside(row,p,pad)
		pad=pad or 0
		local c,s=row.cframe.Position,row.size/2
		return math.abs(p.X-c.X)<=s.X+pad and math.abs(p.Y-c.Y)<=s.Y+pad and math.abs(p.Z-c.Z)<=s.Z+pad
	end
	local function solidAt(p)
		for _,row in ipairs(Rows)do if row.collide and row.name~="W7H_Ramp"and not row.angled and inside(row,p)then return row end end
		return nil
	end
	test("greybox rows: W7H_ names, unique, finite, at most 60; lights are inert; nothing textured",function()
		assert(#Rows>=30 and #Rows<=60,#Rows)
		local seen={}
		for _,row in ipairs(Rows)do
			assert(string.sub(row.name,1,4)=="W7H_"and not seen[row.name],row.name);seen[row.name]=true
			for _,v in ipairs({row.size.X,row.size.Y,row.size.Z})do assert(v==v and v>0 and v<200,row.name)end
			local p=row.cframe.Position
			assert(p.X==p.X and p.Y==p.Y and p.Z==p.Z and math.abs(p.X)<500 and math.abs(p.Z)<500,row.name)
			assert(type(row.color)=="string"and #row.color==7,row.name)
			if row.light then assert(not row.collide and not row.visible,row.name)end
			if not row.visible then assert(row.light or row.collide,row.name.." is invisible and does nothing")end
		end
	end)

	test("greybox: a floor under every Hush arrival and landing; walls all round the hollow but the tunnel and shelf gaps",function()
		local north=Hush.Doors.north
		for _,offset in ipairs(Hush.ArrivalOffsets)do
			for _,feet in ipairs({(north.arrival*CFrame.new(offset)).Position,north.landing+north.arrival:VectorToWorldSpace(offset)})do
				local row=solidAt(feet-Vector3.new(0,.1,0))
				assert(row and row.visible,"no floor under "..tostring(feet))
				assert(math.abs(row.cframe.Position.Y+row.size.Y/2-feet.Y)<.05,"floor not at the feet: "..row.name)
				assert(not solidAt(feet+Vector3.new(0,3,0)),"inside a solid at "..tostring(feet))
			end
		end
		-- The return trigger is in the open tunnel, in front of its end wall.
		local t=Hush.Doors.home.trigger
		assert(not solidAt((t.min+t.max)/2)and solidAt(Vector3.new(-7,(t.min.Y+t.max.Y)/2,t.max.Z+.6)))
		-- Walls: west and east all along; north except the shelf gap (closed by the shelf's stop); south except the tunnel.
		for v=-3,127 do
			assert(solidAt(Hush.at(-77,v,20))and solidAt(Hush.at(77,v,20)),"side wall open at v "..v)
		end
		for u=-78,78 do
			local north=solidAt(Hush.at(u,126,20))
			if u>-5 and u<15 then assert(not north and solidAt(Hush.at(u,138.3,10)),"shelf at u "..u)
			else assert(north,"north wall open at u "..u)end
			-- The tunnel's flared mouth is the Sill's width at the wall face (Fable R5).
			local south=solidAt(Hush.at(u,-2,Hush.SillH+4))
			if u>-7 and u<7 then assert(not south and solidAt(Hush.at(u,-2,Hush.SillH-1))and solidAt(Hush.at(u,-2,Hush.SillH+12)),"tunnel gap at u "..u)
			else assert(south,"south wall open at u "..u)end
		end
		-- 40 high everywhere a wall stands.
		assert(solidAt(Hush.at(-77,60,39.5))and not solidAt(Hush.at(-77,60,40.5)))
	end)

	test("greybox: the ramp's top runs from the Sill's east edge down to the floor; the Sill is 6 up",function()
		local ramp
		for _,row in ipairs(Rows)do if row.name=="W7H_Ramp"then ramp=row end end
		assert(ramp)
		local half=(ramp.size.X-1)/2
		local top=ramp.cframe*Vector3.new(-half,ramp.size.Y/2,0)
		local foot=ramp.cframe*Vector3.new(half,ramp.size.Y/2,0)
		assert((top-Hush.at(8,5,Hush.SillH)).Magnitude<.05 and(foot-Hush.at(Hush.RampFootU,5,0)).Magnitude<.05,tostring(top).." "..tostring(foot))
		local slope=math.deg(math.atan2(Hush.SillH,Hush.RampFootU-8))
		assert(Hush.SillH>=10 and slope>=11 and slope<=14,slope) -- Fable R5: look down from +10; about 13 degrees
		local sill=solidAt(Hush.at(0,5,Hush.SillH-.1))
		assert(sill and sill.name=="W7H_Sill"and math.abs(sill.cframe.Position.Y+sill.size.Y/2-Hush.at(0,0,Hush.SillH).Y)<1e-6)
	end)

	test("greybox: the tunnel's flare is sealed: its walls meet the straight walls and the wall face; its roof covers it",function()
		local flares={}
		for _,row in ipairs(Rows)do if row.angled then flares[row.name]=row end end
		for _,side in ipairs({-1,1})do
			local row=flares[if side<0 then "W7H_TunnelFlareWest"else "W7H_TunnelFlareEast"]
			assert(row)
			local back=row.cframe*Vector3.new(0,0,row.size.Z/2)
			local front=row.cframe*Vector3.new(0,0,-row.size.Z/2)
			assert((back-Hush.at(side*3.5,-8,Hush.SillH+4)).Magnitude<.05 and(front-Hush.at(side*7.5,0,Hush.SillH+4)).Magnitude<.05)
			assert(row.size.Y==8)
			-- The straight wall ends where the flare starts; the wall face starts where it ends.
			assert(solidAt(Hush.at(side*3.5,-8.2,Hush.SillH+4))and solidAt(Hush.at(side*7.5,-.2,Hush.SillH+4)))
			-- Roofed over the whole flare (the mouth roof, then the lintel).
			for v=-7.5,-.5,1 do assert(solidAt(Hush.at(side*(3+(v+8)*.5),v,Hush.SillH+8.5)),"open roof at v "..v)end
		end
	end)

	test("greybox: five clumps 18 to 24 wide and 14 high, clear of the pool, the ramp, the Sill, the doors and each other",function()
		assert(#Hush.Clumps==5)
		local pool={u1=-22,v1=65,u2=22,v2=91}
		local keep={pool,{u1=-8,v1=0,u2=Hush.RampFootU+2,v2=12},{u1=-5,v1=116,u2=15,v2=138}}
		local function apart(a,b,gap)return a.u2+gap<=b.u1 or b.u2+gap<=a.u1 or a.v2+gap<=b.v1 or b.v2+gap<=a.v1 end
		for k,c in ipairs(Hush.Clumps)do
			local long=math.max(c.u2-c.u1,c.v2-c.v1)
			assert(long>=18 and long<=24,c.name)
			assert(c.u1>=-73 and c.u2<=73 and c.v1>=12 and c.v2<=122,c.name.." is not on the floor")
			for _,area in ipairs(keep)do assert(apart(c,area,3),c.name)end
			for j=k+1,#Hush.Clumps do assert(apart(c,Hush.Clumps[j],8),c.name)end
			local row
			for _,r in ipairs(Rows)do if r.name=="W7H_"..c.name then row=r end end
			assert(row and row.collide and math.abs(row.size.Y-Hush.ClumpHeight)<1e-6 and Hush.ClumpHeight==14,c.name)
			local mid=Hush.at((c.u1+c.u2)/2,(c.v1+c.v2)/2,0)
			assert(not Hush.safeCell(mid.X,mid.Z)and not Hush.safeCell(Hush.at(c.u1-1,c.v1,0).X,Hush.at(c.u1-1,c.v1,0).Z),c.name)
			assert(Hush.safeCell(Hush.at(c.u1-2,c.v1,0).X,Hush.at(c.u1-2,c.v1,0).Z),c.name)
		end
	end)

	return{passed=#cases,cases=cases}
end
