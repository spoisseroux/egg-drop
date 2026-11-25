-- The upper tier (UPPER-TIER-BUILD-PLAN.md, architect verdict applied; the way up is the island's cliff path,
-- CLIFF-DEN-BUILD.md): the gate (missing = on); the pet floor chain (closed = today's line exactly; open: the terrace and
-- the path off the lawn); the terrace on the crest; the cliff path from the lawn to the balustrade gap, walkable; the
-- terrace 4 studs clear of everything placed at home; the ring boxes found from geometry, the closers and skirts full
-- height; the bounds region; the evacuation spot; the rows; a catch-up spot refused on the path's treads. Reads the live
-- world data and CliffDenData: rerun after any re-export. Usage (Server): require(ServerScriptService.Server.ZZSpecs.Tier)(ServerScriptService.Server)
-- Offline: python scripts/run_dash_server_specs.py
return function(server,offline)
	local Shared=game:GetService("ReplicatedStorage").Shared
	local Tier=require(Shared.Tier)
	local Hush=require(Shared.Hush)
	local Greybox=require(Shared.TierGreybox)
	local Bounds=require(Shared.IslandBounds)
	local Data=require(Shared.WorldV7Data)
	local V7=require(Shared.HollowWorldLayout).V7
	local Spots=require(Shared.FindSpots)
	local Course=require(Shared.DashCourse)
	local Nest=require(Shared.Nest)
	local Park=require(Shared.ParkLayout)
	local GroundDressing=require(Shared.GroundDressing)
	local Dressing=require(Shared.WorldDressing)
	local Walk=require(Shared.GardenWalkability)
	local Host=require(server.TierHost)
	local DenLayout=require(Shared.DenLayout)
	local cases={}
	local function test(name,run)run();table.insert(cases,name)end
	local LIVE=96451847774961
	local FLOOR={CFrame=CFrame.new(V7.FloorCenterX,V7.FloorTop-.5,V7.FloorCenterZ),Size=Vector3.new(V7.Width,1,V7.Depth)}
	local function oldTest(floor,p)
		local at=floor.CFrame:PointToObjectSpace(p)
		return not(math.abs(at.X)>floor.Size.X*.5-1 or math.abs(at.Z)>floor.Size.Z*.5-1)
	end
	local aside,before,after=Tier.ringAside(Data.perimeter)
	local rows=Greybox.rows(Tier.closers(Data.perimeter,before,after))
	local function row(name)for _,r in ipairs(rows)do if r.name=="W7T_"..name then return r end end return nil end
	-- Is (x, z) within `grow` of the terrace (if asked) or of the cliff path where it has left the lawn?
	local PATH=Tier.path()
	assert(PATH,"CliffDenData's path")
	local function near(x,z,grow,terrace)
		if terrace and Tier.inPiece(Tier.Pieces[1],x,z,grow)then return "Terrace"end
		local y=Tier.onPath(x,z,grow)
		if y and y>=Tier.FootY+Tier.PathLift then return "Path"end
		return nil
	end
	-- The raw 4-stud grid (nil off it or where unknown).
	local G=Data.ground
	local function cell(x,z)
		local i,k=math.floor((x-G.x0)/G.step+.5),math.floor((z-G.z0)/G.step+.5)
		if i<0 or k<0 or i>=G.nx or k>=G.nz then return nil end
		local v=G.h[k*G.nx+i+1];return if v>-900 then v else nil
	end

	test("the ceiling: the flag and the beta place or Studio; live never; a missing or malformed switch is on",function()
		local F={Tier=true}
		assert(Tier.ceiling({flags=F,studio=false,place=Tier.PlaceId})and Tier.ceiling({flags=F,studio=true,place=1}))
		assert(not Tier.ceiling({flags=F,studio=false,place=LIVE})and not Tier.ceiling({flags={},studio=true}))
		assert(Tier.resolve(nil,nil,true)==true and Tier.resolve("x",nil,true)==true and Tier.resolve(true,nil,true)==true and Tier.resolve(false,nil,true)==false and Tier.resolve(nil,false,true)==false)
		assert(Tier.resolve(true,true,false)==false and Tier.Key=="garden_tier"and Tier.Attribute=="Tier_on")
		Tier.inject({flags=F,studio=false,place=LIVE});assert(not Tier.on())
		Tier.inject({flags=F,studio=true,on=false});assert(not Tier.on())
		Tier.inject(nil)
	end)

	test("the pet floor chain: closed (false, nil, not true) is today's Floor test exactly; open drops every footprint",function()
		local points={}
		for x=-130,130,2.5 do for z=-110,100,2.5 do table.insert(points,Vector3.new(x,4,z))end end
		for _,dx in ipairs({-.001,0,.001})do
			table.insert(points,Vector3.new(V7.FloorCenterX+V7.Width/2-1+dx,4,0))
			table.insert(points,Vector3.new(0,4,V7.FloorCenterZ-V7.Depth/2+1-dx))
		end
		local nan=0/0
		table.insert(points,Vector3.new(nan,4,0));table.insert(points,Vector3.new(0,nan,nan));table.insert(points,Vector3.new(-30,4,nan))
		table.insert(points,Tier.T(0,0,Tier.FloorY+2))
		for k=1,#PATH.points,4 do table.insert(points,PATH.points[k]+Vector3.new(0,3,0))end
		for _,p in ipairs(points)do
			local old=oldTest(FLOOR,p)
			for _,closed in ipairs({false,nil,1,"true"})do
				local line=Hush.onPetFloor(FLOOR,p,false)and not Tier.covers(p,closed)
				assert(line==old,tostring(p))
			end
			local open=Hush.onPetFloor(FLOOR,p,false)and not Tier.covers(p,true)
			assert(open==(old and not near(p.X,p.Z,0,true)),tostring(p))
		end
		-- Open: the terrace and the path up the cliff are covered; the path's foot on the lawn and the lawn beside it are not.
		assert(Tier.covers(Tier.T(0,0),true)and Tier.covers(PATH.points[20],true)and Tier.covers(PATH.points[#PATH.points-1],true))
		assert(not Tier.covers(PATH.points[1],true)and not Tier.covers(PATH.points[1]+Vector3.new(4,0,10),true))
		assert(not Tier.covers(Vector3.new(nan,0,0),true)and not Tier.covers("x",true))
	end)

	test("the terrace: no crest ground pokes through the floor (y 29); the garden edge stands on the cliff top",function()
		for s=-38,38,2 do
			for t=-22,22,2 do
				local p=Tier.T(s,t);local g=cell(p.X,p.Z)
				assert(g==nil or g<Tier.FloorY-.5,string.format("crest %.1f at s %d t %d",g or 0,s,t))
			end
			local edge=Tier.T(s,22);local g=V7.groundY(edge.X,edge.Z)
			assert(g>=12,string.format("the garden edge at s %d is over ground %.1f (the lawn)",s,g))
		end
		assert(Tier.FloorY==29 and Tier.Length==76 and Tier.Width==44)
	end)

	test("the cliff path: from the lawn by the den up to the balustrade gap on the garden edge, walkable, 6 wide",function()
		local pts=PATH.points
		local foot,top=pts[1],pts[#pts]
		assert(math.abs(foot.Y-Tier.FootY)<.1 and math.abs(V7.groundY(foot.X,foot.Z)-Tier.FootY)<.8,"the foot is not at the lawn")
		assert(math.abs(top.Y-Tier.FloorY)<.05,"the path does not arrive at the floor")
		local s,t=Tier.local2(Tier.Pieces[1],top.X,top.Z)
		assert(s>Tier.Gap.a1+2 and s<Tier.Gap.a2-2 and math.abs(t-22)<.5,string.format("arrival s %.1f t %.1f",s,t))
		local Cliff=require(Shared.CliffDenData)
		assert(Tier.Gap.a1==Cliff.terrace.gap.s[1]and Tier.Gap.a2==Cliff.terrace.gap.s[2],"Tier.Gap is CliffDenData.terrace.gap")
		for k=1,#pts-1 do
			local a,b=pts[k],pts[k+1]
			local run=Vector2.new(b.X-a.X,b.Z-a.Z).Magnitude
			assert(math.deg(math.atan2(math.abs(b.Y-a.Y),run))<=30,"step "..k.." is steeper than 30 degrees")
			assert(PATH.widths[k]>=5.9,"narrower than 6 at "..k)
		end
		-- Every point but the last few (the steps through the notch onto the edge) is outside the terrace footprint.
		for k=1,#pts-3 do assert(not Tier.inPiece(Tier.Pieces[1],pts[k].X,pts[k].Z,0),"point "..k.." is under the terrace")end
	end)

	test("the terrace 4 studs clear of everything placed at home (the path's own checks: cliff_den_checks.py)",function()
		local function clear(label,x,z,terrace)
			local hit=if Tier.inPiece(Tier.Pieces[1],x,z,4)then "Terrace"else nil
			assert(not hit,string.format("%s (%.1f, %.1f) is within 4 studs of %s",label,x,z,tostring(hit)))
		end
		for k,s in ipairs(Spots)do clear("find "..k,s.x/100,s.z/100,true)end
		for id,cf in pairs(V7.Stations)do clear("station "..id,cf.Position.X,cf.Position.Z,true)end
		for id,at in pairs(V7.Rest)do clear("rest "..id,at.X,at.Z,true)end
		for k,l in ipairs(V7.Lamps)do clear("lamp "..k,l.X,l.Z,true)end
		for id,route in pairs(V7.Routes)do for k,p in ipairs(route)do clear("route "..id..k,p.X,p.Y,true)end end
		clear("nest",Nest.Spot.X,Nest.Spot.Z,true)
		for _,list in ipairs({Course.Main,Course.Branch})do for k=1,#list,4 do clear("dash d="..list[k],list[k+1]/100,list[k+3]/100,true)end end
		clear("dash pad",Course.Pad.x/100,Course.Pad.z/100,true)
		-- Every park site, whichever the place switch picked: the arrival, the old grove (live) and the Hollow (beta).
		local sites={Park,Park.build(Park.Specs.grove),Park.build(Park.Specs.hollow)}
		for _,site in ipairs(sites)do
			for k=0,63 do local t=k*math.pi/32;clear("kerb "..site.Id,site.Center.X+site.Radius.X*math.cos(t),site.Center.Z+site.Radius.Y*math.sin(t),true)end
			if site.Natural then
				-- The Hollow (no kerb): its slot approaches 4 studs clear, its keepout circles 4 past their own radius.
				for id,slot in pairs(site.Slots)do clear("hollow approach "..id,slot.approach.X,slot.approach.Z,true)end
				for _,zone in ipairs(site.Keepout)do
					assert(not Tier.inPiece(Tier.Pieces[1],zone.center.X,zone.center.Y,4+zone.radius),
						string.format("hollow keepout (%.1f, %.1f) is within 4 studs of the terrace",zone.center.X,zone.center.Y))
				end
			end
		end
		for _,w in ipairs(Bounds.Walls)do for k=0,10 do clear("wall "..w.id,w.x1+(w.x2-w.x1)*k/10,w.z1+(w.z2-w.z1)*k/10,true)end end
		for _,list in ipairs({GroundDressing.Litter,GroundDressing.Lawn,GroundDressing.Fray})do
			for k,r in ipairs(list)do clear("ground dressing "..tostring(r[6])..k,r[1],r[3],true)end
		end
		local Life=offline.new.require(offline.new.client.LifeSpots)
		for k,p in pairs(Life.Landings)do clear("perch "..k,p.X,p.Z,true)end
		for k,c in pairs(Life.Crowns or {})do
			local p=if typeof(c)=="Vector3"then c elseif type(c)=="table"and typeof(c.position)=="Vector3"then c.position else nil
			if p then clear("crown "..k,p.X,p.Z,true)end
		end
	end)

	test("the ring: the boxes that stand aside are found from geometry; the closers meet the neighbours; skirts reach down",function()
		assert(#aside>=8 and before and after)
		-- Contiguous, and exactly the boxes whose centre line comes within 1 stud of the terrace or the top platform.
		for k=2,#aside do assert(aside[k]==aside[k-1]+1)end
		for i,entry in ipairs(Data.perimeter)do
			local c,size,yaw=entry.center,entry.size,entry.yaw or 0
			local ux,uz=math.cos(yaw),-math.sin(yaw)
			local meets=false
			for k=-8,8 do
				local x,z=c[1]+ux*size[1]/2*k/8,c[3]+uz*size[1]/2*k/8
				if Tier.inPiece(Tier.Pieces[1],x,z,1)then meets=true end
			end
			assert(meets==(table.find(aside,i)~=nil),"ring box "..i)
		end
		assert(not table.find(aside,before)and not table.find(aside,after))
		-- Each closer starts on its neighbour's end and ends on the end wall; it stands SkirtY..WallTop.
		local closers=Tier.closers(Data.perimeter,before,after)
		assert(#closers==2)
		for k,closer in ipairs(closers)do
			local entry=Data.perimeter[closer.ring]
			local c,size,yaw=entry.center,entry.size,entry.yaw or 0
			local ux,uz=math.cos(yaw),-math.sin(yaw)
			local e1=Vector3.new(c[1]+ux*size[1]/2,0,c[3]+uz*size[1]/2);local e2=Vector3.new(c[1]-ux*size[1]/2,0,c[3]-uz*size[1]/2)
			assert(math.min((closer.from-e1).Magnitude,(closer.from-e2).Magnitude)<.5)
			local s,t=Tier.local2(Tier.Pieces[1],closer.to.X,closer.to.Z)
			assert(math.abs(math.abs(s)-37.5)<.05 and math.abs(t)<=21.5)
			local r=row("EndCloser"..k)
			assert(r and not r.visible and r.collide)
			assert(math.abs(r.cframe.Position.Y-r.size.Y/2-Tier.SkirtY)<1e-6 and math.abs(r.cframe.Position.Y+r.size.Y/2-Tier.WallTop)<1e-6)
		end
		-- Skirts and closers reach below the ground under them (the outer corners read -4..+3) and the walls up to 40.
		for _,name in ipairs({"SkirtOuter","SkirtNorthEast","SkirtSouthWest"})do
			local r=row(name);assert(math.abs(r.cframe.Position.Y-r.size.Y/2-Tier.SkirtY)<1e-6,name)
		end
		for s=-38,38,2 do
			for _,t in ipairs({-22,-21})do
				local p=Tier.T(s,t);local g=cell(p.X,p.Z)
				if g then assert(g>Tier.SkirtY+1,string.format("the outer skirt does not reach the ground at s %d (%.1f)",s,g))end
			end
		end
		for _,name in ipairs({"RimOuterStop","RimNorthEastStop","RimSouthWestStop","BalustradeNorthStop","BalustradeSouthStop"})do
			local r=row(name);assert(math.abs(r.cframe.Position.Y+r.size.Y/2-Tier.WallTop)<1e-6 and Tier.WallTop>=40,name)
		end
	end)

	test("the bounds region: from y 20 to at least 60 over the terrace; never the lawn; the path is inside the ring",function()
		local R=Tier.BoundsRegions[1]
		assert(R.min.Y==Tier.RegionY and R.min.Y==20 and R.max.Y>=60 and R.fallY==20 and R.safe==nil)
		local function inside(p)return p.X>=R.min.X and p.X<=R.max.X and p.Y>=R.min.Y and p.Y<=R.max.Y and p.Z>=R.min.Z and p.Z<=R.max.Z end
		for s=-38,38,4 do for t=-22,22,4 do assert(inside(Tier.T(s,t,Tier.FloorY+3)))end end
		assert(not inside(Tier.Evacuation.at+Vector3.new(0,3,0)))
		for k,p in ipairs(PATH.points)do
			assert(not Bounds.gone(p+Vector3.new(0,3,0))and not Bounds.gone(p+Vector3.new(0,3,0),Tier.BoundsRegions),"path point "..k.." reads as gone")
		end
		-- Up there you are not gone; under y 20 out past the ring you are.
		assert(not Bounds.gone(Tier.T(0,-18,Tier.FloorY+3),Tier.BoundsRegions)and Bounds.gone(Tier.T(0,-18,Tier.FloorY+3)))
		assert(Bounds.gone(Tier.T(0,-18,15),Tier.BoundsRegions))
	end)

	test("the evacuation spot: inside the home Floor, on safe ground, under no footprint, not up there",function()
		local e=Tier.Evacuation
		for _,offset in ipairs(Tier.EvacuationOffsets)do
			local frame=CFrame.lookAt(e.at,Vector3.new(e.facing.X,e.at.Y,e.facing.Z))*CFrame.new(offset)
			local p=frame.Position
			local at=string.format("(%.1f, %.1f)",p.X,p.Z)
			assert(oldTest(FLOOR,p),"outside the home Floor "..at)
			assert(Bounds.safeCell(p.X,p.Z),"not safe ground "..at)
			assert(not near(p.X,p.Z,Tier.Grow+.5,true),"by the path "..at)
			assert(not Tier.onIt(p+Vector3.new(0,3,0)),"up there "..at)
		end
		assert(Tier.onIt(Tier.T(0,0,Tier.FloorY+3))and Tier.onIt(Tier.T(36,20,Tier.FloorY+3)))
		-- Not the terrace, but moved too while off the lawn (code review: the gates are built across the path).
		for k=1,#PATH.points-3,6 do assert(not Tier.onIt(PATH.points[k]+Vector3.new(0,3,0)),"path point "..k)end
		assert(Tier.onPathUp(PATH.points[20]+Vector3.new(0,3,0))and Tier.onPathUp(PATH.points[47]+Vector3.new(0,3,0)))
		assert(not Tier.onPathUp(PATH.points[1]+Vector3.new(0,3,0))and not Tier.onPathUp(PATH.points[20]+Vector3.new(0,-12,0)))
		assert(not Tier.onPathUp(e.at+Vector3.new(0,3,0)))
		-- Clear of the den: its waiting area and the doorstep.
		local Den=DenLayout.fromData(require(Shared.CliffDenData))
		assert(Den and not DenLayout.inWait(Den,e.at+Vector3.new(0,3,0),1)and(e.at-Den.doorstep.at).Magnitude>6)
	end)

	test("Fable R8 FIX 1: home's palette, matte: the lawn top, cliff-grey faces and a low stone lip (Fable cliff-den fix 8)",function()
		local Look=Greybox.Look
		local function is(r,colour,material)return r.color==colour and r.material==material end
		local counted=0
		for _,r in ipairs(rows)do
			local name=string.sub(r.name,5)
			if not r.visible or r.light then continue end
			counted+=1
			if name=="Floor"then
				assert(is(r,Look.lawn,"Grass"),name)
			elseif string.match(name,"^Balustrade")then
				assert(is(r,Look.cliff,"Slate"),name) -- Fable cliff-den fix 8: a low stone lip
			elseif name=="FaceGarden"then
				assert(is(r,Look.face,"Slate"),name)
			elseif string.match(name,"^Skirt")or string.match(name,"^Rim")then
				assert(is(r,Look.cliff,"Slate"),name)
			elseif string.match(name,"^Clump")then
				assert(is(r,Look.cliff,"Slate"),name)
			else
				assert(string.match(name,"^Pad")or name=="TreePole",name.." has no palette rule")
			end
		end
		assert(counted>=14)
		-- Nothing glossy: no visible row on SmoothPlastic but the pads and the pole; no neon, no glass.
		for _,r in ipairs(rows)do
			if r.visible and r.material then assert(r.material~="Neon"and r.material~="Glass"and r.material~="SmoothPlastic",r.name)end
		end
	end)

	test("rows: W7T_ names, unique, finite, at most 40; the balustrade gap is where the cliff path arrives; the gates",function()
		assert(#rows>=20 and #rows<=40,#rows)
		local seen={}
		for _,r in ipairs(rows)do
			assert(string.sub(r.name,1,4)=="W7T_"and not seen[r.name],r.name);seen[r.name]=true
			for _,v in ipairs({r.size.X,r.size.Y,r.size.Z})do assert(v==v and v>0 and v<120,r.name)end
			local p=r.cframe.Position
			assert(p.X==p.X and p.Y==p.Y and p.Z==p.Z,r.name)
			if not r.visible then assert(r.collide or r.light,r.name)end
		end
		local north,south=row("BalustradeNorth"),row("BalustradeSouth")
		local function sRange(r)
			local s1=Tier.local2(Tier.Pieces[1],(r.cframe*Vector3.new(-r.size.X/2,0,0)).X,(r.cframe*Vector3.new(-r.size.X/2,0,0)).Z)
			local s2=Tier.local2(Tier.Pieces[1],(r.cframe*Vector3.new(r.size.X/2,0,0)).X,(r.cframe*Vector3.new(r.size.X/2,0,0)).Z)
			return math.min(s1,s2),math.max(s1,s2)
		end
		local _,n2=sRange(north);local s1=sRange(south)
		assert(math.abs(n2-Tier.Gap.a1)<.05 and math.abs(s1-Tier.Gap.a2)<.05 and Tier.Gap.a2-Tier.Gap.a1>=7)
		-- Fable cliff-den fix 8: the lip 1.4 high; nothing over the floor + 5 within 14 studs of the gap.
		local top=north.cframe.Position.Y+north.size.Y/2
		assert(math.abs(top-(Tier.FloorY+Greybox.Lip))<1e-6 and Greybox.Lip==1.4)
		for _,r in ipairs(rows)do
			if r.visible and r.cframe.Position.Y+r.size.Y/2>Tier.FloorY+5 then
				for _,sx in ipairs({-1,1})do for _,sz in ipairs({-1,1})do
					local c=r.cframe*Vector3.new(sx*r.size.X/2,0,sz*r.size.Z/2)
					local s=Tier.local2(Tier.Pieces[1],c.X,c.Z)
					assert(s<=Tier.Gap.a1-14+.01 or s>=Tier.Gap.a2+14-.01,r.name.." stands tall by the gap (s "..s..")")
				end end
			end
		end
		local gates=Greybox.gates(Tier.gates())
		assert(#gates==2)
		for _,g in ipairs(gates)do assert(not g.visible and g.collide and g.size.Z>=PATH.widths[1]+2,g.name)end
	end)

	test("pets: the blocked footprints cover the path off the lawn; a catch-up spot under a tread is refused; the lawn is not",function()
		local feet=Host.footprints()
		assert(#feet>=8)
		local wet={}
		for _,f in ipairs(feet)do
			table.insert(wet,{Parent=true,CFrame=f.cframe,Size=f.size,Name=f.name,
				GetAttribute=function(_,key)return key=="GardenBlockedRegion"end})
		end
		for k=8,#PATH.points-2,5 do
			local p=PATH.points[k]
			assert(Walk.resolveAnchor(Vector3.new(p.X,Tier.FootY,p.Z),wet)==nil,"a landing under path point "..k)
		end
		assert(Walk.resolveAnchor(Tier.Evacuation.at,wet)~=nil,"the lawn at the evacuation spot")
	end)

	return{passed=#cases,cases=cases}
end
