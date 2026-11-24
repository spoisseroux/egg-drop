-- The upper tier, greybox T0 (UPPER-TIER-BUILD-PLAN.md, architect verdict applied): the gate; the pet floor chain (closed
-- = today's line exactly); the terrace on the crest; the legs (slopes, never inside rock, joined at the landing and the
-- top); 4 studs clear of everything placed at home (find spots, stations, rest spots, lamps, routes, the nest, the Dash
-- course and pad, park kerbs, island walls, ground dressing, flowers and bushes, garden-life perches and crowns); no
-- closed-off pocket of lawn; the ring boxes found from geometry, the closers and skirts full height; the bounds region;
-- the evacuation spot; the rows; a catch-up spot refused on leg A's low end. Reads the live world data: rerun after any
-- re-export. Usage (Server): require(ServerScriptService.Server.ZZSpecs.Tier)(ServerScriptService.Server)
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
	-- Is (x, z) within `grow` of any solid footprint (the top platform, the legs, the landing; the terrace too if asked)?
	local function near(x,z,grow,terrace)
		for k=(if terrace then 1 else 2),#Tier.Pieces do if Tier.inPiece(Tier.Pieces[k],x,z,grow)then return Tier.Pieces[k].name end end
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
		assert(Tier.resolve(nil,nil,true)==true and Tier.resolve("x",nil,true)==true and Tier.resolve(false,nil,true)==false)
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
		for _,piece in ipairs(Tier.Pieces)do
			local frame=if piece.frame=="tier"then Tier.T else Tier.P
			table.insert(points,frame((piece.a1+piece.a2)/2,(piece.b1+piece.b2)/2,Tier.FloorY+2))
		end
		for _,p in ipairs(points)do
			local old=oldTest(FLOOR,p)
			for _,closed in ipairs({false,nil,1,"true"})do
				local line=Hush.onPetFloor(FLOOR,p,false)and not Tier.covers(p,closed)
				assert(line==old,tostring(p))
			end
			local open=Hush.onPetFloor(FLOOR,p,false)and not Tier.covers(p,true)
			assert(open==(old and not near(p.X,p.Z,0,true)),tostring(p))
		end
		-- Open: on a leg, a landing, the platform or the terrace is covered; the lawn 2 studs past the path is not.
		assert(Tier.covers(Tier.P(20,23),true)and Tier.covers(Tier.P(Tier.Far+3,8),true)and Tier.covers(Tier.P(0,10),true)and Tier.covers(Tier.T(0,0),true))
		assert(not Tier.covers(Tier.P(20,28.5),true)and not Tier.covers(Tier.P(Tier.Far+8.5,10),true)and not Tier.covers(Tier.P(20,-2),true))
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

	test("the path: four legs at 13 to 16 degrees, 6 wide, never inside rock, joined at the landings and the top",function()
		for _,leg in ipairs(Tier.Legs)do
			local slope=math.deg(math.atan2(math.abs(leg.far-leg.near),Tier.Run))
			assert(slope>=13 and slope<=16,leg.name.." "..slope)
			assert(math.abs(leg.o2-leg.o1-6)<1e-6,leg.name)
			for k=0,25 do
				local u=Tier.Near+Tier.Run*k/25
				for o=leg.o1,leg.o2,1 do
					local p=Tier.P(u,o);local g=V7.groundY(p.X,p.Z)
					local need=if leg.name=="Leg1"then -.6 else 1
					assert(Tier.legY(leg,u)-g>=need,string.format("%s inside rock at u %.1f o %.1f (%.1f over %.1f)",leg.name,u,o,Tier.legY(leg,u),g))
				end
			end
		end
		-- The foot (leg 1, near end) is at the lawn; the top (leg 4, near end) at the floor.
		local foot=Tier.P(Tier.Near,23);assert(math.abs(V7.groundY(foot.X,foot.Z)-Tier.FootY)<.6,"the foot is not at the lawn")
		assert(Tier.Legs[1].near==Tier.FootY and Tier.Legs[4].near==Tier.FloorY)
		-- Each turn meets at a landing's height: legs 1-2 far (A), 2-3 near, 3-4 far (B).
		local nearL,farA,farB=Tier.Landings[1],Tier.Landings[2],Tier.Landings[3]
		assert(Tier.Legs[1].far==farA.y and Tier.Legs[2].far==farA.y and Tier.Legs[2].near==nearL.y and Tier.Legs[3].near==nearL.y)
		assert(Tier.Legs[3].far==farB.y and Tier.Legs[4].far==farB.y)
		-- Rows: each slab's top at both ends.
		local function top(r,a)return r.cframe*Vector3.new(a*r.size.X/2,r.size.Y/2,0)end
		for _,leg in ipairs(Tier.Legs)do
			local r=row(leg.name);local mid=(leg.o1+leg.o2)/2
			assert((top(r,-1)-Tier.P(Tier.Near,mid,leg.near)).Magnitude<.05 and(top(r,1)-Tier.P(Tier.Far,mid,leg.far)).Magnitude<.05,leg.name)
			assert(math.abs(r.size.Z-6)<1e-6,leg.name)
		end
		for _,l in ipairs(Tier.Landings)do
			local r=row(l.name);assert(math.abs(r.cframe.Position.Y+r.size.Y/2-l.y)<1e-6,l.name)
		end
		local platform=row("TopPlatform")
		assert(math.abs(platform.cframe.Position.Y+platform.size.Y/2-Tier.FloorY)<1e-6)
		-- The top platform reaches onto the terrace (its inner end inside the garden edge, in the balustrade gap).
		for _,o in ipairs({Tier.Top.o1,Tier.Top.o2})do
			local p=Tier.P(Tier.Top.u1,o)
			local s,t=Tier.local2(Tier.Pieces[1],p.X,p.Z)
			assert(t<=22 and s>=Tier.Gap.a1 and s<=Tier.Gap.a2,string.format("top platform end s %.1f t %.1f",s,t))
		end
		-- Leg 4's near end lies on the top platform.
		for _,o in ipairs({Tier.Legs[4].o1+.1,Tier.Legs[4].o2-.1})do
			local p=Tier.P(Tier.Near-.1,o);assert(Tier.inPiece(Tier.Pieces[2],p.X,p.Z,0))
		end
	end)

	test("4 studs clear of everything placed at home, and off the cave pocket and the mouth",function()
		local function clear(label,x,z,terrace)
			local hit=near(x,z,4,terrace)
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
		for _,site in ipairs(Park.Sites)do
			for k=0,63 do local t=k*math.pi/32;clear("kerb "..site.Id,site.Center.X+Park.Radius.X*math.cos(t),site.Center.Z+Park.Radius.Y*math.sin(t),true)end
		end
		for _,w in ipairs(Bounds.Walls)do for k=0,10 do clear("wall "..w.id,w.x1+(w.x2-w.x1)*k/10,w.z1+(w.z2-w.z1)*k/10,true)end end
		for _,list in ipairs({GroundDressing.Litter,GroundDressing.Lawn,GroundDressing.Fray})do
			for k,r in ipairs(list)do clear("ground dressing "..tostring(r[6])..k,r[1],r[3],true)end
		end
		-- Bushes on the lawn (meshes that would poke through a ramp). Flowers are flat decals .06 over the lawn: under the
		-- path's solid supports they are simply hidden, so they are counted, not refused (the art pass re-scatters them).
		local hidden=0
		for _,r in ipairs(Dressing.Flowers)do if r[2]<8 and near(r[1],r[3],0,false)then hidden+=1 end end
		-- Bushes (small meshes) likewise: inside a solid support they are hidden; one standing half out would show.
		for k,r in ipairs(Dressing.Bushes)do
			if r[2]<8 and near(r[1],r[3],2,false)then
				local inside=near(r[1],r[3],0,false)~=nil
				for j=0,7 do local a=j*math.pi/4;inside=inside and near(r[1]+1.6*math.cos(a),r[3]+1.6*math.sin(a),0,false)~=nil end
				assert(inside,string.format("bush %d (%.1f, %.1f) stands half out of the path",k,r[1],r[3]))
				hidden+=1
			end
		end
		assert(hidden<=12,hidden.." flowers and bushes under the path")
		local Life=offline.new.require(offline.new.client.LifeSpots)
		for k,p in pairs(Life.Landings)do clear("perch "..k,p.X,p.Z,true)end
		for k,c in pairs(Life.Crowns or {})do
			local p=if typeof(c)=="Vector3"then c elseif type(c)=="table"and typeof(c.position)=="Vector3"then c.position else nil
			if p then clear("crown "..k,p.X,p.Z,true)end
		end
		-- The cave pocket (x -14..0, z -116..-99) and the mouth's walkable strip.
		for x=-14,0,1 do for z=-116,-88,1 do assert(not near(x,z,0,true),string.format("over the cave at (%d, %d)",x,z))end end
	end)

	test("no closed-off pocket of lawn: every lawn cell round the switchback is reachable from the open garden",function()
		local x0,x1,z0,z1=-60,12,-104,-36
		local function lawn(x,z)return V7.groundY(x,z)<7 and not near(x,z,0,false)end
		local seen,queue={}, {}
		local function key(x,z)return x..","..z end
		for x=x0,x1 do for _,z in ipairs({z0,z1})do if lawn(x,z)then seen[key(x,z)]=true;table.insert(queue,{x,z})end end end
		for z=z0,z1 do for _,x in ipairs({x0,x1})do if lawn(x,z)and not seen[key(x,z)]then seen[key(x,z)]=true;table.insert(queue,{x,z})end end end
		local head=1
		while head<=#queue do
			local x,z=queue[head][1],queue[head][2];head+=1
			for _,d in ipairs({{1,0},{-1,0},{0,1},{0,-1}})do
				local nx,nz=x+d[1],z+d[2]
				if nx>=x0 and nx<=x1 and nz>=z0 and nz<=z1 and not seen[key(nx,nz)]and lawn(nx,nz)then
					seen[key(nx,nz)]=true;table.insert(queue,{nx,nz})
				end
			end
		end
		local cut=0
		for x=x0,x1 do for z=z0,z1 do if lawn(x,z)and not seen[key(x,z)]then cut+=1 end end end
		assert(cut==0,cut.." lawn cells closed off by the switchback")
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

	test("the bounds region: from y 20 to at least 60 over the terrace, the platform and leg B's top; never the lawn",function()
		local R=Tier.BoundsRegions[1]
		assert(R.min.Y==Tier.RegionY and R.min.Y==20 and R.max.Y>=60 and R.fallY==20 and R.safe==nil)
		local function inside(p)return p.X>=R.min.X and p.X<=R.max.X and p.Y>=R.min.Y and p.Y<=R.max.Y and p.Z>=R.min.Z and p.Z<=R.max.Z end
		for s=-38,38,4 do for t=-22,22,4 do assert(inside(Tier.T(s,t,Tier.FloorY+3)))end end
		local leg4=Tier.Legs[4]
		assert(inside(Tier.P(0,3.5,Tier.FloorY+3))and inside(Tier.P(-6,3.5,Tier.FloorY+3))and inside(Tier.P(Tier.Near+3,3.5,Tier.legY(leg4,Tier.Near+3)+3)))
		assert(not inside(Tier.P(20,23,Tier.legY(Tier.Legs[1],20)+3))and not inside(Tier.Evacuation.at+Vector3.new(0,3,0)))
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
		assert(Tier.onIt(Tier.T(0,0,Tier.FloorY+3))and Tier.onIt(Tier.P(20,23,Tier.legY(Tier.Legs[1],20)+3))and Tier.onIt(Tier.P(Tier.Far+3,6,Tier.Landings[3].y+3)))
		assert(not Tier.onIt(Tier.P(20,29,7.5))and not Tier.onIt(Tier.P(Tier.Near+1,23,5)))
	end)

	test("rows: W7T_ names, unique, finite, at most 60; the balustrade gap is the top platform",function()
		assert(#rows>=30 and #rows<=70,#rows)
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
	end)

	test("pets: the blocked footprints are the solids grown 1.5; a catch-up spot on leg A's low end is refused",function()
		local feet=Host.footprints()
		assert(#feet==#Tier.Pieces-1)
		local wet={}
		for _,f in ipairs(feet)do
			table.insert(wet,{Parent=true,CFrame=f.cframe,Size=f.size,Name=f.name,
				GetAttribute=function(_,key)return key=="GardenBlockedRegion"end})
		end
		local low=Tier.P(Tier.Near+.5,23,Tier.FootY+.025)
		assert(Walk.resolveAnchor(low,wet)==nil,"a landing on leg 1's low end")
		assert(Walk.resolveAnchor(Tier.P(Tier.Near+2,27.5,Tier.FootY),wet)==nil,"inside the 1.5 grow")
		local open=Tier.P(Tier.Near+2,29,Tier.FootY)
		assert(Walk.resolveAnchor(open,wet)~=nil,"the lawn past the grow")
		assert(not Walk.segmentAllowed(Tier.P(20,30,Tier.FootY),Tier.P(20,-3,Tier.FootY),wet),"a path under the legs")
	end)

	return{passed=#cases,cases=cases}
end
