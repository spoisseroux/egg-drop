-- Pets never walk through the garden's solid props (GARDEN-PLAY-BRIEF-2 section 4; Spencer, beta 35 note 4). Pure: the
-- one keep-out list (GardenKeepOut) and the server planner with it (GardenPathPlanner / GardenWalkability) over the v7
-- world's own wet and blocked boxes, built here as parts the way LoungeWorldV7Art builds them. 200 seeded garden walks
-- (follow-length and across-the-garden) are walked at 0.05 s steps: no sample stands inside a solid prop's keep-out.
-- Usage (Server): require(ServerScriptService.Server.ZZSpecs.GardenKeepOut)(ServerScriptService.Server)
return function(_server,offline)
	local Shared=game:GetService("ReplicatedStorage").Shared
	local KeepOut=require(Shared.GardenKeepOut)
	local Walk=require(Shared.GardenWalkability)
	local Planner=require(Shared.GardenPathPlanner)
	local A=require(Shared.GardenActivity)
	local World=require(Shared.HollowWorldLayout)
	local Data=require(Shared.WorldV7Data)
	local Clear=require(Shared.GardenClearance)
	local Alive=require(Shared.Alive)
	local Flags=require(Shared.FeatureFlags)
	local cases={}
	local function test(name,run)run();table.insert(cases,name)end
	local new=offline and offline.Instance and offline.Instance.new or Instance.new

	-- The world's wet and blocked boxes, as the server builds them (LoungeWorldV7Art: PetRegions).
	local folder=new("Folder")
	local boxes={}
	local function region(cf,size,attribute)
		local p=new("Part")
		p.CFrame,p.Size=cf,size
		p:SetAttribute(attribute,true)
		p.Parent=folder
		table.insert(boxes,p)
	end
	for _,entry in ipairs(Data.wet)do
		local c,s=entry.center,entry.size
		region(CFrame.new(c[1],c[2],c[3])*CFrame.Angles(0,entry.yaw or 0,0),Vector3.new(s[1],.2,s[3]),"GardenWetRegion")
	end
	for _,entry in ipairs(World.Wet)do
		region(CFrame.new(entry.center.X,World.FloorTop-.7,entry.center.Y)*CFrame.Angles(0,entry.yaw,0),Vector3.new(entry.size.X,.2,entry.size.Y),"GardenWetRegion")
	end
	for _,entry in ipairs(World.Blocked)do
		region(CFrame.new(entry.center.X,World.FloorTop+.5,entry.center.Y)*CFrame.Angles(0,entry.yaw,0),Vector3.new(entry.size.X,1,entry.size.Y),"GardenBlockedRegion")
	end
	local regions=KeepOut.regions(nil)
	local wet=table.clone(boxes)
	for _,r in ipairs(regions)do table.insert(wet,r)end
	local function flat(a,b)return Vector2.new(a.X-b.X,a.Z-b.Z).Magnitude end

	test("one list: every tree trunk, lamp, the fountain, the crag egg, the gourd arch, the tray; ids unique",function()
		local all=KeepOut.all()
		local ids,trunks,lamps,soft={},0,0,0
		for _,e in ipairs(all)do
			assert(not ids[e.id],"duplicate "..e.id);ids[e.id]=true
			assert(e.kind=="solid"or e.kind=="soft",e.id)
			assert(type(e.r)=="number"and e.r>0 and e.r<5,e.id)
			if string.sub(e.id,1,6)=="trunk "then trunks+=1 end
			if string.sub(e.id,1,5)=="lamp "then lamps+=1 end
			if e.kind=="soft"then soft+=1 end
		end
		local Kit=require(Shared.WorldAeroKit)
		assert(trunks==#Kit.crowns and trunks>=20,"trunks "..trunks)
		assert(lamps==#World.Lamps,"lamps "..lamps)
		for _,id in ipairs({"fountain","wobble egg","rattle_gourds",require(Shared.CrunchToys).Places.tray.id})do assert(ids[id],id)end
		assert(soft==2+6,"the two leaf heaps and six pods squash: "..soft)
		for _,e in ipairs(all)do
			if e.id=="leaf_heap_1"or e.id=="leaf_heap_2"or string.sub(e.id,1,8)=="pop_pod_"then assert(e.kind=="soft",e.id)end
		end
		-- A prop that is not built keeps nothing out.
		local none=KeepOut.solids(function()return false end)
		for _,e in ipairs(none)do assert(e.feature==nil,e.id.." is behind "..tostring(e.feature))end
		assert(#KeepOut.solids(nil)==#none+3,"wobble, gourds and tray behind their switches")
		local radius={}
		for _,e in ipairs(all)do radius[e.id]=e.r end
		for _,r in ipairs(regions)do assert(r.KeepOut==true and r.Parent==true and math.abs(r.R-(radius[r.Name]+KeepOut.Clearance))<1e-9,r.Name)end
	end)

	test("no keep-out covers a spot pets must reach: rest daises, the spawn, the hub, the care cradle, the nest, parks, rests",function()
		local spots={["spawn"]=World.Spawn.Position,hub=World.Hub}
		for name,at in pairs(World.Rest or {})do spots["rest "..name]=at end
		local Care=require(Shared.GardenCareLayout)
		spots["care dock"],spots["care approach"]=Care.Dock,Care.Approach
		spots.nest=require(Shared.Nest).Spot
		local Layout=require(Shared.GardenLayout)
		for name,at in pairs(Layout)do if typeof(at)=="Vector3"then spots["layout "..name]=at end end
		for _,park in ipairs(Clear.parks())do spots["park "..park.name]=Vector3.new(park.x,0,park.z)end
		local TierPets=require(Shared.TierPets)
		for _,row in ipairs(TierPets.TerraceRests)do spots["terrace "..row[1]]=Vector3.new(row[2],0,row[3])end
		for name,at in pairs(spots)do
			for _,r in ipairs(regions)do
				assert(flat(at,Vector3.new(r.X,0,r.Z))>=r.R+.5,string.format("%s inside %s (%.2f < %.2f)",name,r.Name,flat(at,Vector3.new(r.X,0,r.Z)),r.R+.5))
			end
		end
	end)

	test("the rules: a segment through a prop is refused, a goal against one is moved just outside, a hull round one fails",function()
		local tree
		for _,r in ipairs(regions)do if string.sub(r.Name,1,6)=="trunk "then tree=r;break end end
		local y=World.groundY(tree.X,tree.Z)
		local west,east=Vector3.new(tree.X-4,y,tree.Z),Vector3.new(tree.X+4,y,tree.Z)
		assert(not Walk.segmentAllowed(west,east,{tree}),"through the trunk")
		assert(Walk.segmentAllowed(west,west+Vector3.new(0,0,1),{tree}),"beside it")
		local inside=Vector3.new(tree.X+.2,y,tree.Z+.1)
		local moved,changed=Walk.resolveAnchor(inside,{tree})
		assert(changed and moved and math.abs(flat(moved,Vector3.new(tree.X,0,tree.Z))-(tree.R+Walk.PushPast))<1e-6,"pushed out")
		-- Four control points round the trunk: every chord misses it, the curve goes round it.
		local leg={from=A.pack(west+Vector3.new(0,0,-tree.R-.2)),to=A.pack(east+Vector3.new(0,0,-tree.R-.2)),
			v0=A.pack(Vector3.new(0,0,30)),v1=A.pack(Vector3.new(0,0,-30)),duration=1}
		assert(not Walk.pathAllowed({leg},{tree}),"a hull round the trunk")
		-- No circles: the split is the list itself, the planner is the old one.
		local b,c=Walk.split(boxes)
		assert(b==boxes and #c==0)
		local b2,c2=Walk.split(wet)
		assert(#b2==#boxes and #c2==#regions)
		-- A pet already inside a keep-out (it stood there before the prop was built) walks out of it, never held.
		local path=Planner.plan(inside,east,Vector3.zero,6,0,0,nil,Vector3.zero,{tree})
		local last=path[#path]
		assert(not last.safetyStop and flat(A.vector(last.to),east)<.05,"walked out")
		-- A walk across it goes round it.
		path=Planner.plan(west,east,Vector3.zero,6,0,0,nil,Vector3.zero,{tree})
		last=path[#path]
		assert(not last.safetyStop and flat(A.vector(last.to),east)<.05 and #path>1,"round the trunk")
	end)

	test("200 garden walks never pass through a solid prop (samples every 0.05 s), and most still get there",function()
		local random=Random.new(20261126)
		local function lawn()
			for _=1,400 do
				local x,z=random:NextNumber(-95,125),random:NextNumber(-80,78)
				if Clear.groundKnown(x,z)and math.abs(x-World.FloorCenterX)<=World.Width*.5-2 and math.abs(z-World.FloorCenterZ)<=World.Depth*.5-2 then
					local p=Vector3.new(x,World.groundY(x,z)+.025,z)
					if Walk.segmentAllowed(p,p,wet)then return p end
				end
			end
			error("no lawn point")
		end
		-- Half the walks start beside a prop and end across it (the case that used to clip), half anywhere.
		local solids=KeepOut.solids(nil)
		local reached,crossings,worst,legs=0,0,math.huge,0
		for n=1,200 do
			local from,to
			if n%2==0 then
				local e=solids[(n//2)%#solids+1]
				local a=random:NextNumber(0,math.pi*2)
				local d=e.r+KeepOut.Clearance+random:NextNumber(.4,3)
				local function at(angle,dist)
					local x,z=e.x+math.cos(angle)*dist,e.z+math.sin(angle)*dist
					return Vector3.new(x,World.groundY(x,z)+.025,z)
				end
				from,to=at(a,d),at(a+math.pi+random:NextNumber(-.4,.4),d+random:NextNumber(0,2))
				if not(Walk.segmentAllowed(from,from,wet)and Walk.segmentAllowed(to,to,wet))then from,to=lawn(),nil end
			else
				from=lawn()
			end
			if not to then
				for _=1,50 do
					local p=lawn()
					if n%4==1 or flat(p,from)<=30 then to=p;break end
				end
				to=to or lawn()
			end
			local velocity=if n%3==0 then Vector3.new(random:NextNumber(-2,2),0,random:NextNumber(-2,2))else Vector3.zero
			local path=Planner.plan(from,to,velocity,6,0,random:NextNumber(-math.pi,math.pi),nil,Vector3.zero,wet)
			assert(#path>0,"a plan")
			legs+=#path
			for _,leg in ipairs(path)do
				local t=0
				while true do
					local p=A.legPose(leg,t)
					for _,e in ipairs(solids)do
						local d=flat(p,Vector3.new(e.x,0,e.z))
						worst=math.min(worst,d-e.r)
						if d<e.r+KeepOut.Clearance-1e-3 then crossings+=1 end
					end
					if t>=leg.duration then break end
					t=math.min(leg.duration,t+.05)
				end
			end
			local last=path[#path]
			if not last.safetyStop and flat(A.vector(last.to),to)<.2 then reached+=1 end
		end
		assert(crossings==0,crossings.." samples inside a solid prop's keep-out")
		assert(worst>=KeepOut.Clearance-1e-3,"closest approach "..worst)
		assert(reached>=180,"only "..reached.." of 200 walks got there")
		table.insert(cases,string.format("    (%d reached, %d legs, closest %.2f studs off a prop's edge)",
			reached,legs,worst))
	end)

	test("the switch: Alive `keepout` (AliveKeepOut), beta and Studio only, never live",function()
		assert(table.find(Alive.Features,KeepOut.Feature)and Flags.AliveKeepOut==true)
		assert(Alive.ceiling("keepout",{AliveKeepOut=true},Alive.PlaceId,false)==true)
		assert(Alive.ceiling("keepout",{AliveKeepOut=true},96451847774961,false)==false,"never on live")
	end)

	return {passed=#cases,cases=cases}
end
