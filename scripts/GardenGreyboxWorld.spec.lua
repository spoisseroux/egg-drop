-- Greybox garden swap (2026-11-11): live lounge geometry, west crossing,
-- routes around the pond and terraces, and the unchanged single-bridge detour.
-- Run in a Server datamodel during Play: require(...)(game.ServerScriptService.Server)
local function legacy(server)
	local Shared=game.ReplicatedStorage.Shared
	local World=require(Shared.HollowWorldLayout)
	local Walk=require(Shared.GardenWalkability)
	local Planner=require(Shared.GardenPathPlanner)
	local A=require(Shared.GardenActivity)
	local room=workspace:WaitForChild("EggDropLounge",10);assert(room,"live lounge required")
	local wet={}
	for _,node in ipairs(room:GetDescendants())do
		if node:IsA("BasePart")and(node:GetAttribute("GardenWetRegion")==true or node:GetAttribute("GardenBlockedRegion")==true
			or node.Name=="Creek"or node.Name=="MeadowCreek"or node.Name=="OutlookPond"or node.Name=="LanternPool")then table.insert(wet,node)end
	end
	local cases={}
	local function test(name,run)run();table.insert(cases,name)end
	local Y=World.FloorTop+.025
	local function ground(x,z)return Vector3.new(x,Y,z)end
	local function plan(from,to)return Planner.plan(from,to,Vector3.zero,4,0,0,nil,Vector3.zero,wet)end
	local function arrives(path,to)
		local last=path[#path]
		return last and not last.safetyStop and(A.vector(last.to)-to).Magnitude<.05 and Walk.pathAllowed(path,wet)
	end
	local function usesDeck(path,id)
		local bridge=World.WalkableSpans[id]
		for _,leg in ipairs(path)do for _,key in ipairs({"from","to"})do
			local p=A.vector(leg[key])
			if math.abs(p.Y-Walk.top(bridge))<.08 and math.abs(p.X-bridge.center.X)<bridge.size.X*.5 and math.abs(p.Z-bridge.center.Z)<bridge.size.Z*.5 then return true end
		end end
		return false
	end

	test("floor covers the greybox and the hub stays at its authored coordinates",function()
		local floor=room.Floor
		assert(floor.Position==Vector3.new(-10.5,3.5,25)and floor.Size==Vector3.new(241,1,200))
		assert(room.HatchTop.Position==Vector3.new(0,4.115,-5),"hatch nest moved")
		assert(room:FindFirstChild("GreyboxTerraceLow")and room:FindFirstChild("GreyboxCliffNorth3")and room:FindFirstChild("GreyboxPond"))
		local boundaries=0
		for _,p in ipairs(room:GetChildren())do if p.Name=="GardenBoundary"then
			boundaries+=1;assert(p.CanCollide and p.Transparency==1 and p.Size.Y==40)
			if p.Size.X<1 then assert(math.abs(math.abs(p.Position.X+10.5)-120.1)<.001)else assert(math.abs(math.abs(p.Position.Z-25)-99.6)<.001)end
		end end
		assert(boundaries==4,"four boundaries")
		assert(not room:FindFirstChild("LanternPool")and not room:FindFirstChild("MeadowHill")and not room:FindFirstChild("GladeBenchSeat"))
	end)

	test("west bridge support matches the primary bridge height and is a registered crossing",function()
		local support=room.GreyboxBridgeSupport;local span=World.WalkableSpans.WestBridge
		assert(support:GetAttribute("GardenWalkableSpan")=="WestBridge"and support.Position==span.center and support.Size==span.size)
		assert(math.abs(Walk.top(span)-Walk.top(World.WalkableSpans.PrimaryBridge))<1e-6 and span.crossing and World.WalkableSpans.PrimaryBridge.crossing)
		local _,id=Walk.spanAt(Vector3.new(-83,Walk.top(span),35));assert(id=="WestBridge")
	end)

	test("pond and creek are wet; terrace, ramps, pillars and ledge are blocked for pets",function()
		for _,point in ipairs({ground(-85,-40),ground(-83,90),ground(90,5),ground(95,-50),ground(58,33),ground(-117,40),ground(-120,8)})do
			assert(not Walk.segmentAllowed(point,point,wet),"should be off-limits: "..tostring(point))
		end
		for _,point in ipairs({ground(0,30),ground(-100,35),ground(-110,-40),ground(50,-20)})do
			assert(Walk.segmentAllowed(point,point,wet),"should be open ground: "..tostring(point))
		end
	end)

	test("a pet follows from the hub across the west bridge into the west strip",function()
		local to=ground(-100,35);local path=plan(ground(0,30),to)
		assert(arrives(path,to)and usesDeck(path,"WestBridge"),"west crossing")
	end)

	test("the strip beside the pond is reachable around the pond corner",function()
		local to=ground(-110,-40);local path=plan(ground(0,30),to)
		assert(arrives(path,to)and usesDeck(path,"WestBridge"),"pond strip route")
	end)

	test("east of the hub creek to the west strip chains both bridges",function()
		local from,to=ground(30,0),ground(-100,35);local path=plan(from,to)
		assert(arrives(path,to)and usesDeck(path,"PrimaryBridge")and usesDeck(path,"WestBridge"),"two-bridge route")
	end)

	test("a pet walks around the low ramp instead of through it",function()
		local from,to=ground(60,15),ground(60,50);local path=plan(from,to)
		assert(arrives(path,to),"around ramp")
		assert(not usesDeck(path,"WestBridge")and not usesDeck(path,"PrimaryBridge"))
	end)

	test("graph waypoints stay on the floor, never along the cliff face past its edge",function()
		-- Code review repro: west of the pond to the open lawn east of it.
		local from,to=ground(-110,-70),ground(-50,-40);local path=plan(from,to)
		assert(arrives(path,to),"pond-west route")
		for _,leg in ipairs(path)do for _,key in ipairs({"from","to"})do
			local p=A.vector(leg[key])
			assert(math.abs(p.X-World.FloorCenterX)<=World.Width*.5-1.5 and math.abs(p.Z-World.FloorCenterZ)<=World.Depth*.5-1.5,"waypoint off the floor "..tostring(p))
		end end
	end)

	test("a short hop around the ramp beats a far bridge detour",function()
		local from,to=ground(55,25),ground(55,45);local path=plan(from,to)
		assert(arrives(path,to)and not usesDeck(path,"WestBridge")and not usesDeck(path,"PrimaryBridge"))
		local walked=0;for _,leg in ipairs(path)do walked+=(A.vector(leg.to)-A.vector(leg.from)).Magnitude end
		assert(walked<60,"walked "..walked)
	end)

	test("the single primary-bridge detour is unchanged for hub creek crossings",function()
		-- The original planner's targets for a westbound hub crossing.
		local bridge=World.WalkableSpans.PrimaryBridge;local top=Walk.top(bridge)
		local left,right=bridge.center.X-bridge.size.X*.5+.30,bridge.center.X+bridge.size.X*.5-.30
		local from,to=ground(26,-9.4),ground(10,-9.4)
		local path=plan(from,to);assert(arrives(path,to))
		local expected={ground(right+1,-9.4),Vector3.new(right,top,-9.4),Vector3.new(left,top,-9.4),ground(left-1,-9.4),to}
		-- Rebuild exactly as the original planner did and compare every leg.
		local original={};local position,v,heading=from,Vector3.zero,0
		for _,target in ipairs(expected)do
			local part=A.plan(position,target,v,4,0,heading)
			for _,leg in ipairs(part)do table.insert(original,leg)end
			local last=part[#part];heading=last.yaw+last.turn;position,v=target,Vector3.zero
		end
		assert(#path==#original,"leg count "..#path.." vs "..#original)
		for i,leg in ipairs(original)do
			assert((A.vector(path[i].from)-A.vector(leg.from)).Magnitude<1e-4 and(A.vector(path[i].to)-A.vector(leg.to)).Magnitude<1e-4,"leg "..i)
		end
	end)

	return{passed=#cases,cases=cases}
end

-- World 1 v7 (2026-11-12): the floating island replaces the greybox. Same
-- intent: the live lounge geometry, its supported crossing, wet and blocked
-- regions, and routes that stay on the ground and on the floor bounds.
local function v7(server)
	local Shared=game.ReplicatedStorage.Shared
	local World=require(Shared.HollowWorldLayout)
	local Walk=require(Shared.GardenWalkability)
	local Planner=require(Shared.GardenPathPlanner)
	local A=require(Shared.GardenActivity)
	local Layout=require(Shared.GardenLayout)
	local Data=require(Shared.WorldV7Data)
	local room=workspace:WaitForChild("EggDropLounge",10);assert(room,"live lounge required")
	local wet={}
	for _,node in ipairs(room:GetDescendants())do
		if node:IsA("BasePart")and(node:GetAttribute("GardenWetRegion")==true or node:GetAttribute("GardenBlockedRegion")==true)then table.insert(wet,node)end
	end
	local cases={}
	local function test(name,run)run();table.insert(cases,name)end
	local function ground(x,z)return Vector3.new(x,World.groundY(x,z)+.025,z)end
	local function plan(from,to)return Planner.plan(from,to,Vector3.zero,4,0,0,nil,Vector3.zero,wet)end
	local function arrives(path,to)
		local last=path[#path]
		return last and not last.safetyStop and(A.vector(last.to)-to).Magnitude<.05 and Walk.pathAllowed(path,wet)
	end
	local function usesDeck(path)
		local bridge=World.WalkableSpans.MainBridge
		for _,leg in ipairs(path)do for _,key in ipairs({"from","to"})do
			local p=A.vector(leg[key])
			if math.abs(p.Y-Walk.top(bridge))<.08 and math.abs(p.X-bridge.center.X)<bridge.size.X*.5 and math.abs(p.Z-bridge.center.Z)<bridge.size.Z*.5 then return true end
		end end
		return false
	end
	local function onFloor(path)
		for _,leg in ipairs(path)do for _,key in ipairs({"from","to"})do
			local p=A.vector(leg[key])
			if not(math.abs(p.X-World.FloorCenterX)<=World.Width*.5-1.5 and math.abs(p.Z-World.FloorCenterZ)<=World.Depth*.5-1.5)then return false end
		end end
		return true
	end

	test("the island replaces the greybox: bounds floor, meshes and no legacy scenery",function()
		local floor=room.Floor
		assert(floor.Position==Vector3.new(World.FloorCenterX,World.FloorTop-.5,World.FloorCenterZ)and floor.Size==Vector3.new(World.Width,1,World.Depth))
		assert(not floor.CanCollide and floor.Transparency==1,"floor is bounds only; the island meshes carry collision")
		assert(#room.World:GetChildren()==Data.meshParts+Data.collisionTiles,"mesh count "..#room.World:GetChildren())
		for _,name in ipairs({"GreyboxTerraceLow","GreyboxPond","HatchTop","GardenBoundary","SpringWater"})do assert(not room:FindFirstChild(name),"legacy part "..name)end
	end)

	test("ground tiles, rocks and architecture collide; leaves, water and decoration do not",function()
		for _,part in ipairs(room.World:GetChildren())do
			local info=Data.parts[part.Name];assert(info and part.Anchored,part.Name)
			assert(part:GetAttribute("WorldMesh")==true,part.Name)
			assert(part.CanCollide==info.collide,part.Name.." CanCollide")
			if info.region=="GroundCollision"then assert(part.Transparency==1)end
			if info.region=="Ground"or info.region=="Vegetation"or info.region=="Water"or info.region=="Backdrop"or info.motion then assert(not part.CanCollide,part.Name)end
		end
		for _,name in ipairs({"W7_Rocks__cliff_rock","W7_Rotunda__marble","W7_Bridge__marble","W7_Balustrades__marble","W7_Trunks__bark"})do assert(room.World[name].CanCollide,name)end
	end)

	test("perimeter wall, cave blocker and fall catch enclose the island",function()
		local walls=room.PerimeterWall:GetChildren();assert(#walls==#Data.perimeter and #walls>60)
		for _,w in ipairs(walls)do assert(w.CanCollide and w.Transparency==1 and w.Size.Y>=10,w.Name)end
		assert(room.CaveBlocker.CanCollide and room.CaveBlocker.Transparency==1)
		local catch=room.FallCatch;assert(catch.CanTouch and not catch.CanCollide and catch.Position.Y< -150 and catch.Size.X>=1400)
	end)

	test("the marble bridge support matches its registered crossing span",function()
		local span=World.WalkableSpans.MainBridge;local support=room.MainBridgeSupport
		assert(span.crossing and support:GetAttribute("GardenWalkableSpan")=="MainBridge"and support.Position==span.center and support.Size==span.size)
		local _,id=Walk.spanAt(Vector3.new(2.5,Walk.top(span),21));assert(id=="MainBridge")
	end)

	test("stream, pools and spring are wet; knoll and stairs are blocked; lawns are open",function()
		for _,entry in ipairs(Data.wet)do
			local p=ground(entry.center[1],entry.center[3]);assert(not Walk.segmentAllowed(p,p,wet),"should be wet "..entry.name)
		end
		for _,p in ipairs({ground(52,3),ground(-63,45),ground(-46,31.5),ground(-60,50)})do assert(not Walk.segmentAllowed(p,p,wet),"off-limits "..tostring(p))end
		for _,p in ipairs({ground(-30,4),ground(-90,0),ground(60,40),ground(96,60),ground(-20,-30),Layout.Toy})do assert(Walk.segmentAllowed(p,p,wet),"open "..tostring(p))end
		for _,rest in ipairs(Layout.RestAnchors)do assert(Walk.segmentAllowed(rest.position,rest.position,wet),rest.id)end
	end)

	test("a pet follows from the arrival dais to the hub across the bridge, and back",function()
		local a,b=ground(90,55),ground(-25,8)
		local path=plan(a,b);assert(arrives(path,b)and usesDeck(path)and onFloor(path),"westbound")
		path=plan(b,a);assert(arrives(path,a)and usesDeck(path)and onFloor(path),"eastbound")
	end)

	test("a pet walks around the knoll instead of over it",function()
		local from,to=ground(-92,20),ground(-40,62);local path=plan(from,to)
		assert(arrives(path,to)and not usesDeck(path)and onFloor(path),"around knoll")
	end)

	test("same-bank walks never detour over the bridge",function()
		local from,to=ground(-40,-30),ground(-20,30);local path=plan(from,to)
		assert(arrives(path,to)and not usesDeck(path))
		local walked=0;for _,leg in ipairs(path)do walked+=(A.vector(leg.to)-A.vector(leg.from)).Magnitude end
		assert(walked<90,"walked "..walked)
	end)

	return{passed=#cases,cases=cases}
end

return function(server,...)
	local World=require(game.ReplicatedStorage.Shared.HollowWorldLayout)
	if World.WorldVersion=="v7"then return v7(server,...)end
	return legacy(server,...)
end
