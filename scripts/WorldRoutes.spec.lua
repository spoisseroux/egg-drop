-- Actual authored geometry, fresh source/config; geometry is not a native walk.
return function(server,artSource)
	assert(type(artSource)=="string","Actual LoungeArt source required")
	local lighting=game:GetService("Lighting")
	local properties={"ClockTime","Brightness","Ambient","OutdoorAmbient","ColorShift_Top","EnvironmentDiffuseScale","EnvironmentSpecularScale","ShadowSoftness"}
	local saved={};for _,key in ipairs(properties)do saved[key]=lighting[key]end
	local air=lighting:FindFirstChildOfClass("Atmosphere")
	local grade=lighting:FindFirstChild("SproutHollowGrade")
	local effects={}
	for _,entry in ipairs({{air,{"Density","Offset","Color","Decay","Haze","Glare"}},{grade,{"Contrast","Saturation","TintColor"}}})do
		if entry[1]then local values={};for _,key in ipairs(entry[2])do values[key]=entry[1][key]end;effects[entry[1]]=values end
	end
	local shared=game.ReplicatedStorage.Shared:Clone();shared.Name="_WorldRoutesShared";shared.Parent=server
	local layout=require(shared.HollowWorldLayout)
    local gardenLayout=require(shared.GardenLayout)
	local realGame=game
	local fakeGame={}
	function fakeGame:GetService(name)if name=="ReplicatedStorage"then return{Shared=shared}end;return realGame:GetService(name)end
	local module=Instance.new("ModuleScript");module.Name="_WorldRoutesFactory"
	module.Source="return function(e) local game,script,require=e.game,e.script,e.require\n"..artSource.."\nend"
	module.Parent=server;local ok,factory=pcall(require,module);module:Destroy();assert(ok,factory)
	local art=factory({game=fakeGame,script=server.LoungeArt,require=require})
	local room=Instance.new("Model");room.Name="_WorldRoutesFixture";room.Parent=server
	local parts,cases={},{}
	local function part(parent,name,size,cf,color,collides)
		local value=Instance.new("Part");value.Name,value.Size,value.CFrame,value.Color=name,size,cf,color
		value.Anchored,value.CanCollide=true,collides==true;value.Parent=parent;table.insert(parts,value);return value
	end
	local function test(name,check)check();table.insert(cases,name)end
	local function near(a,b)return(a-b).Magnitude<.001 end
	local function contains(p,point)
		local q=p.CFrame:PointToObjectSpace(Vector3.new(point.X,p.Position.Y,point.Y))
		return math.abs(q.X)<=p.Size.X*.5+.001 and math.abs(q.Z)<=p.Size.Z*.5+.001
	end
	local function blocks(p,point)
		-- Sweep an upright avatar clearance capsule through every local axis.
		-- X/Z-only tests are invalid for vertically rotated cylinder trunks.
		local a=p.CFrame:PointToObjectSpace(Vector3.new(point.X,4.65,point.Y))
		local b=p.CFrame:PointToObjectSpace(Vector3.new(point.X,8,point.Y))
		local delta=b-a;local extent=p.Size*.5+Vector3.new(.65,.65,.65)
		local lo,hi=0,1
		for _,axis in ipairs({"X","Y","Z"})do
			if math.abs(delta[axis])<.000001 then
				if math.abs(a[axis])>extent[axis]then return false end
			else
				local first,last=(-extent[axis]-a[axis])/delta[axis],(extent[axis]-a[axis])/delta[axis]
				if first>last then first,last=last,first end
				lo,hi=math.max(lo,first),math.min(hi,last);if lo>hi then return false end
			end
		end
		return true
	end
	local success,problem=pcall(function()
		art.build(room,part)
		test("floor and four boundaries align with the greybox collision envelope",function()
			local floor=room.Floor;assert(floor.CanCollide and floor.CanQuery and floor.Size==Vector3.new(241,1,200))
			assert(floor.Position==Vector3.new(-10.5,3.5,25)and floor.Position.Y+floor.Size.Y*.5==4 and floor:GetAttribute("PlayableWidth")==241 and floor:GetAttribute("PlayableDepth")==200)
			local boundaries=0
			for _,p in ipairs(parts)do if p.Name=="GardenBoundary"then
				boundaries+=1;assert(p.CanCollide and p.Transparency==1 and p.Size.Y==40)
				if p.Size.X<1 then assert(math.abs(math.abs(p.Position.X+10.5)-120.1)<.001 and p.Size.Z==200 and p.Position.Z==25)
				else assert(math.abs(math.abs(p.Position.Z-25)-99.6)<.001 and p.Size.X==241 and p.Position.X==-10.5)end
			end end;assert(boundaries==4)
		end)
		test("greybox landscape replaces the lantern boardwalk, orchard glade and outer hills",function()
			for _,p in ipairs(parts)do
				assert(not p:GetAttribute("HollowRouteSolid"),"retired boardwalk solid "..p.Name)
				for _,name in ipairs({"LanternPool","LanternBoardwalkDeck","GladeBenchSeat","MeadowHill","DistantCrown","BoundaryStone","HollowRouteFork"})do assert(p.Name~=name,"retired part "..name)end
			end
			assert(room:FindFirstChild("GreyboxTerraceLow")and room:FindFirstChild("GreyboxBridgeSupport")and room:FindFirstChild("GreyboxPond"))
			local banked=0;for _,p in ipairs(parts)do if p:GetAttribute("HollowBankPlant")then banked+=1 end end
			assert(banked==13,"expected all six shrub lobes and seven flower parts banked together")
		end)
		test("all route centerlines stay inside ground and clear above-ground colliders",function()
			for _,route in pairs(layout.Routes)do for i=2,#route do
				local a,b=route[i-1],route[i];local delta=b-a;local normal=Vector2.new(-delta.Y,delta.X).Unit
				for step=0,math.ceil(delta.Magnitude)do
					local center=a:Lerp(b,math.min(1,step/delta.Magnitude))
					for _,side in ipairs({-1.6,0,1.6})do
						local point=center+normal*side;assert(contains(room.Floor,point))
						for _,p in ipairs(parts)do
							if p.CanCollide and p.Name~="Floor"and not p:GetAttribute("HollowRouteSolid")and p.Name~="GardenBoundary"then
								assert(not blocks(p,point),p.Name.." blocks route at "..tostring(point).." collider="..tostring(p.Position))
							end
						end
					end
				end
			end end
		end)
		test("hub stations and tree root stay authored while bridge gains4.5usable clearance",function()
			assert(near(room.CustomizeTop.Position,Vector3.new(-11,6.51,-6.3)))
			assert(near(room.JournalTop.Position,Vector3.new(11,6.51,-6.3)))
			assert(near(room.EggsSign.Position,Vector3.new(0,5.5,-3.5)))
			local stations=0;for _,p in ipairs(room:GetDescendants())do if p:IsA("ProximityPrompt")then stations+=1 end end;assert(stations==3)
			local tree,bridge=false,false
			for _,p in ipairs(parts)do
				if p.Name=="HatchTreeTrunk"and p.CanCollide then tree=true;assert(p.Position.X<0 and p.Position.Z< -10)end
				if p.Name=="BridgeRail"and math.abs(p.Position.X-17.6)<.001 then bridge=true;assert(math.abs(p.Position.Z+11.88)<.001 or math.abs(p.Position.Z+6.92)<.001)end
			end;assert(tree and bridge)
			local support=room.GardenBridgeSupport;assert(support.CanCollide and support.CanQuery and support.Size.Z==4.5 and support:GetAttribute("GardenWalkableSpan")=="PrimaryBridge")
			assert(room.NookSupport.CanCollide and room.NookSupport:GetAttribute("GardenWalkableSpan")=="RestNook")
			-- The shared-toy return gate was retired with the shared world ball (v389).
			assert(not room:FindFirstChild("ReturnGateEdge"))
		end)
        test("bench-apron toy anchors stay where the hub expects them",function()
            local toy=gardenLayout.Toy
            assert(near(toy,Vector3.new(-2,4.025,17.5)))
            assert(near(gardenLayout.ToyWest,toy+Vector3.new(-2.4,0,0))and near(gardenLayout.ToyEast,toy+Vector3.new(2.4,0,0)))
        end)
        test("toy reach excludes every spawn and station while both natural owner lanes stay clear",function()
            local toy=gardenLayout.Toy
            for row=0,1 do for column=-2,2 do
                local spawn=Vector2.new(column*5.5,4+row*5)
                assert((spawn-Vector2.new(toy.X,toy.Z)).Magnitude>8.5,"toy priority overlaps a fresh spawn")
            end end
            for _,node in ipairs(room:GetDescendants())do
                if node:IsA("ProximityPrompt")and node:GetAttribute("PocketClubStation")then
                    local at=node.Parent.Position;assert(Vector2.new(at.X-toy.X,at.Z-toy.Z).Magnitude>7+node.MaxActivationDistance,"toy and station activation disks overlap")
                end
            end
            for _,point in ipairs({Vector2.new(-4.8,20),Vector2.new(.8,20)})do
                assert((point-Vector2.new(toy.X,toy.Z)).Magnitude<7)
                assert(contains(room.Floor,point))
                for _,p in ipairs(parts)do if p.CanCollide and p~=room.Floor then assert(not blocks(p,point),"owner lane blocked by "..p.Name)end end
            end
        end)
		test("eight visible lamps use only four managed shadowless lights including original",function()
			local lamps,lights=0,0
			for _,p in ipairs(room:GetDescendants())do
				if p:GetAttribute("HollowLampFixture")then lamps+=1;assert(p:IsA("BasePart")and p.Material==Enum.Material.Neon)end
				if p:IsA("PointLight")then lights+=1;assert(p:GetAttribute("HollowLamp")and not p.Shadows)end
			end;assert(lamps==8 and lights==4)
		end)
        test("south meadow crosses the former wall on two dry eight-stud walking lanes",function()
            local walk=require(shared.GardenWalkability);local wet={}
            for _,p in ipairs(parts)do if p:GetAttribute("GardenWetRegion")or p.Name=="Creek"or p.Name=="MeadowCreek"or p.Name=="OutlookPond"or p.Name=="LanternPool"then table.insert(wet,p)end end
            local crossings=0
            for _,route in ipairs({layout.Routes.SpringApproach,layout.Routes.SpringLoop})do for i=2,#route do
                local a,b=route[i-1],route[i];local delta=b-a;local normal=Vector2.new(-delta.Y,delta.X).Unit
                if(a.Y<64 and b.Y>64)or(b.Y<64 and a.Y>64)then crossings+=1 end
                for step=0,math.ceil(delta.Magnitude*2)do
                    local center=a:Lerp(b,math.min(1,step/(delta.Magnitude*2)))
                    for _,side in ipairs({-4,0,4})do
                        local point=center+normal*side;assert(contains(room.Floor,point))
                        local position=Vector3.new(point.X,4.025,point.Y)
                        assert(walk.segmentAllowed(position,position,wet),"wet walking shoulder")
                        for _,p in ipairs(parts)do if p.CanCollide and p~=room.Floor then assert(not blocks(p,point),"spring lane blocked by "..p.Name.." at "..tostring(point))end end
                    end
                end
            end end
            assert(crossings==2,"both independent branches must cross old Z64")
            assert(contains(room.Floor,Vector2.new(-10,124))and not contains(room.Floor,Vector2.new(-10,126)))
        end)
        test("spring lawn and rest remain supported and clear while the actual wet basin is behind them",function()
            local spring=layout.Spring;local water=room.SpringWater
            assert(water:GetAttribute("GardenWetRegion")==true and water.Position==spring.BasinCenter and water.Size==spring.BasinSize)
            assert(water.Position.Z-water.Size.Z*.5>96,"basin must stay behind the dry lawn")
            assert(near(gardenLayout.RestAnchors[2].position,spring.RestWest)and near(gardenLayout.RestAnchors[3].position,spring.RestEast))
            assert((spring.RestWest-spring.RestEast).Magnitude==5)
            for _,x in ipairs({-7,0,7})do for _,z in ipairs({-6,0,6})do
                local point=spring.LawnCenter+Vector2.new(x,z);assert(contains(room.Floor,point))
                for _,p in ipairs(parts)do if p.CanCollide and p~=room.Floor then assert(not blocks(p,point),"rest lawn blocked by "..p.Name)end end
            end end
        end)
        test("spring endpoints and moving pet control hulls use actual dry authored geometry",function()
            local planner=require(shared.GardenPathPlanner);local walk=require(shared.GardenWalkability);local A=require(shared.GardenActivity);local wet={}
            for _,p in ipairs(parts)do if p:GetAttribute("GardenWetRegion")or p.Name=="Creek"or p.Name=="MeadowCreek"or p.Name=="OutlookPond"or p.Name=="LanternPool"then table.insert(wet,p)end end
            local route=layout.Routes.SpringLoop
            for _,direction in ipairs({1,-1})do for i=1,#route-1 do
                local a,b=route[i],route[i+1];if direction<0 then a,b=b,a end
                local from,to=Vector3.new(a.X,4.025,a.Y),Vector3.new(b.X,4.025,b.Y)
                local velocity=(to-from).Unit*16
                local path,seconds=planner.plan(from,to,velocity,18,0,math.atan2(velocity.X,velocity.Z),nil,velocity,wet)
                assert(walk.pathAllowed(path,wet))
                for _,leg in ipairs(path)do assert(not leg.safetyStop,"safe dry route unexpectedly held")end
                local actor={path=path,from=A.pack(from),to=A.pack(to),startTime=0,endTime=seconds}
                for step=0,100 do local pose=A.sample(actor,seconds*step/100);assert(math.abs(pose.position.Y-4.025)<.001 and pose.velocity.Magnitude<=18.001)end
            end end
        end)
        test("bounded new parts and three asymmetric shelves add no light or interaction",function()
            local count,shelves,prompts=0,{},0
            for _,p in ipairs(parts)do if p:GetAttribute("SpringMeadowPart")then
                count+=1
                if p.Name=="SpringShelf"then table.insert(shelves,p.Size.Y)end
                assert(#p:GetChildren()==0 or not p:FindFirstChildOfClass("PointLight"))
                for _,node in ipairs(p:GetDescendants())do if node:IsA("ProximityPrompt")then prompts+=1 end end
            end end
            table.sort(shelves);assert(#shelves==3 and shelves[1]==4 and shelves[2]==7 and shelves[3]==11)
            assert(count>30 and count<=65,"spring net part budget="..count);assert(prompts==0)
        end)
        test("rest preflight rejects the actual sill braking excursion that a dry chord misses",function()
            local planner=require(shared.GardenPathPlanner);local walk=require(shared.GardenWalkability);local A=require(shared.GardenActivity)
            local from=Vector3.new(-12.5,4.025,94.5);local target=layout.Spring.RestWest
            local wet={room.SpringWater};local solids={}
            for _,p in ipairs(parts)do if p.CanCollide and p.Name~="Floor"then table.insert(solids,p)end end
            assert(walk.segmentAllowed(from,target,wet),"fixture chord must be dry")
            local path=planner.plan(from,target,Vector3.new(0,0,18),3,0,0,nil,Vector3.zero,wet)
            assert(walk.pathAllowed(path,wet),"fixture must expose solid clearance, not wet rejection")
            assert(not planner.restPathClear(path,solids),"incoming brake crossed actual BasinSill")
            local safe=planner.plan(target-Vector3.new(0,0,2),target,Vector3.zero,3,0,0,nil,Vector3.zero,wet)
            assert(planner.restPathClear(safe,solids),"ordinary dry rest approach should remain eligible")
            -- The wide Nuum/Nolli bodies need more than .6 horizontal radius.
            local obstacle=Instance.new("Part");obstacle.Size=Vector3.new(.2,2,2);obstacle.CFrame=CFrame.new(.85,5,0);obstacle.Parent=room
            local widePath=A.plan(Vector3.new(0,4.025,-1),Vector3.new(0,4.025,1),Vector3.zero,3,0,0)
            local wideClear=planner.restPathClear(widePath,{obstacle});obstacle:Destroy()
            assert(not wideClear,"1.6-stud body could clip a solid only .75 from its centerline")
        end)
		test("eighteen stable-name ambient parts retain one bounded glint in the new meadow",function()
			local count=0
			for _,p in ipairs(parts)do if p:GetAttribute("HollowAmbientKind")then
				count+=1;assert(p.Name:sub(1,14)=="HollowAmbient_"and p.Anchored and not p.CanCollide and not p.CanTouch and not p.CanQuery,p.Name.." name/collision flags")
				assert(p:GetAttribute("HollowRestCFrame")==p.CFrame,p.Name.." rest CFrame mismatch: "..tostring(p:GetAttribute("HollowRestCFrame")).." actual="..tostring(p.CFrame))
				assert(p:GetAttribute("HollowRestTransparency")==p.Transparency,p.Name.." rest transparency mismatch: "..tostring(p:GetAttribute("HollowRestTransparency")).." actual="..tostring(p.Transparency))
				assert(p:GetAttribute("HollowAmbientPeriod")>0 and typeof(p:GetAttribute("HollowAmbientAmplitude"))=="Vector3",p.Name.." period/amplitude")
				local phase=p:GetAttribute("HollowAmbientPhase");assert(phase>=0 and phase<1,p.Name.." phase cycles")
			end end;assert(count==18,"ambient count="..count)
			assert(room:FindFirstChild("HollowAmbient_CreekLawnGlint")and room:FindFirstChild("HollowAmbient_BenchPennant"))
		end)
	end)
	room:Destroy();shared:Destroy()
	for key,value in pairs(saved)do lighting[key]=value end
	for effect,values in pairs(effects)do for key,value in pairs(values)do effect[key]=value end end
	if not air then local item=lighting:FindFirstChildOfClass("Atmosphere");if item then item:Destroy()end end
	if not grade then local item=lighting:FindFirstChild("SproutHollowGrade");if item then item:Destroy()end end
	assert(success,problem)
	return{passed=#cases,cases=cases,evidence="actual source-generated collision geometry; native walking/camera/performance remain separate"}
end
