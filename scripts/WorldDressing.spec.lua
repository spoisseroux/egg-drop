-- Ground dressing (batch 2026-11-13, W1): flat flower patches and frond bushes.
-- Client spec: require(PlayerScripts.Client.ZZSpecs.WorldDressing)(PlayerScripts.Client) in a v7 Play session.
-- Builds the flower parts into a private folder with stand-in textures; the live garden is not touched.
return function(client)
	local Shared=game:GetService("ReplicatedStorage").Shared
	local World=require(Shared.HollowWorldLayout)
	local Layout=require(Shared.GardenLayout)
	local Data=require(Shared.WorldV7Data)
	local Dressing=require(Shared.WorldDressing)
	local Flowers=require(client.WorldDressingClient)
	assert(World.WorldVersion=="v7","v7 world required")
	local cases,cleanup={},{}
	local function test(name,check)check();table.insert(cases,name)end
	local function flat(v)return Vector2.new(v.X,v.Z)end
	local stand={daisy="rbxassetid://1",tulip="rbxassetid://2",bellflower="rbxassetid://3",buttercup="rbxassetid://4",starbloom="rbxassetid://5"}

	local ok,err=pcall(function()
	test("phone-safe counts and known kinds",function()
		assert(#Dressing.Flowers>=100 and #Dressing.Flowers<=Dressing.MaxFlowers and Dressing.MaxFlowers<=150,"flowers "..#Dressing.Flowers)
		assert(#Dressing.Bushes>=20 and #Dressing.Bushes<=Dressing.MaxBushes and Dressing.MaxBushes<=44,"bushes "..#Dressing.Bushes)
		assert(Dressing.CullPhone<=90 and Dressing.CullDesktop>Dressing.CullPhone)
		local kinds={}
		for _,p in ipairs(Dressing.Flowers)do
			assert(Dressing.Kinds[p[6]],"kind "..tostring(p[6]));kinds[p[6]]=true
			assert(p[4]>=2.5 and p[4]<=5,"patch size "..p[4])
		end
		for k=1,#Dressing.Kinds do assert(kinds[k],"unused kind "..Dressing.Kinds[k])end
		for _,b in ipairs(Dressing.Bushes)do assert(Dressing.BushMeshes[Dressing.BushKinds[b[4]]],"bush kind")end
	end)

	test("deterministic: the baked tables match their checksum and two builds agree",function()
		assert(Dressing.checksum(Dressing.Flowers,Dressing.Bushes)==Dressing.Checksum,"tables edited by hand; rerun scripts/build_world_v7_dressing.py")
		local a,b=Flowers.build({textures=stand}),Flowers.build({textures=stand})
		assert(#a==#Dressing.Flowers and #a==#b)
		for i=1,#a do
			assert(a[i].part.CFrame==b[i].part.CFrame and a[i].part.Size==b[i].part.Size)
			table.insert(cleanup,a[i].part);table.insert(cleanup,b[i].part)
		end
		assert(#Flowers.build({textures={}})==0,"kinds without an uploaded texture are skipped")
	end)

	test("patches are flat, upward-facing decals on invisible, non-interactive parts",function()
		for i,patch in ipairs(Flowers.build({textures=stand}))do
			local part=patch.part;table.insert(cleanup,part)
			assert(part.Anchored and not part.CanCollide and not part.CanQuery and not part.CanTouch and not part.CastShadow and part.Transparency==1)
			local decal=part:FindFirstChildOfClass("Decal");assert(decal and decal.Face==Enum.NormalId.Top and decal.Texture~="")
			assert(part.CFrame.UpVector.Y>.93,"patch "..i.." tilts "..part.CFrame.UpVector.Y)
			assert(part.Size.Y<=.1,"thin")
		end
	end)

	test("patches lie on the ground (collision tiles) within a stud",function()
		local tiles={};for _,p in ipairs(workspace.EggDropLounge.World:GetChildren())do
			local info=Data.parts[p.Name];if info and info.region=="GroundCollision"then table.insert(tiles,p)end
		end
		local params=RaycastParams.new();params.FilterType=Enum.RaycastFilterType.Include;params.FilterDescendantsInstances=tiles
		local misses=0
		for _,p in ipairs(Dressing.Flowers)do
			local hit=workspace:Raycast(Vector3.new(p[1],p[2]+4,p[3]),Vector3.new(0,-8,0),params)
			if not hit or math.abs(hit.Position.Y-p[2])>1 then misses+=1 end
		end
		assert(misses<=#Dressing.Flowers*.05,"floating or buried patches "..misses)
	end)

	test("no flowers on water, the arrival path, the plaza, stations, the toy lawn or rest daises",function()
		local function inBox(point,center,size,yaw,margin)
			local q=(CFrame.new(center)*CFrame.Angles(0,yaw,0)):PointToObjectSpace(point)
			return math.abs(q.X)<=size.X*.5+margin and math.abs(q.Z)<=size.Z*.5+margin
		end
		local function routeDistance(point)
			local best=math.huge;local route=World.Routes.ArrivalToHub
			for i=2,#route do
				local a,b=route[i-1],route[i];local ab=b-a
				local t=math.clamp((point-a):Dot(ab)/ab:Dot(ab),0,1);best=math.min(best,(point-(a+ab*t)).Magnitude)
			end
			return best
		end
		for i,p in ipairs(Dressing.Flowers)do
			local at,r=Vector3.new(p[1],p[2],p[3]),p[4]*.5
			for _,w in ipairs(Data.wet)do
				assert(not inBox(at,Vector3.new(w.center[1],at.Y,w.center[3]),Vector3.new(w.size[1],0,w.size[3]),w.yaw or 0,r),"patch "..i.." in "..w.name)
			end
			for _,w in ipairs(World.Wet)do
				assert(not inBox(at,Vector3.new(w.center.X,at.Y,w.center.Y),Vector3.new(w.size.X,0,w.size.Y),w.yaw,r),"patch "..i.." in "..w.name)
			end
			assert(routeDistance(flat(at))>r+.5,"patch "..i.." on the arrival path")
			assert((flat(at)-flat(World.Hub)).Magnitude>15.5+r,"patch "..i.." on the plaza")
			for id,station in pairs(World.Stations)do
				local clear=if id=="ToyLawn"then 6 elseif id=="ArrivalDais"then 9 else Dressing.StationClearance
				assert((flat(at)-flat(station.Position)).Magnitude>=clear+r-.01,"patch "..i.." near "..id)
			end
			assert((flat(at)-flat(Layout.Toy)).Magnitude>r+4,"patch "..i.." on the toy lawn")
			for _,rest in ipairs(Layout.RestAnchors)do assert((flat(at)-flat(rest.position)).Magnitude>r+3,"patch "..i.." on "..rest.id)end
		end
		for i,b in ipairs(Dressing.Bushes)do
			local at=Vector2.new(b[1],b[3])
			for _,w in ipairs(Data.wet)do
				assert(not inBox(Vector3.new(b[1],0,b[3]),Vector3.new(w.center[1],0,w.center[3]),Vector3.new(w.size[1],0,w.size[3]),w.yaw or 0,0),"bush "..i.." in water")
			end
			for id,station in pairs(World.Stations)do assert((at-flat(station.Position)).Magnitude>Dressing.StationClearance,"bush "..i.." near "..id)end
		end
	end)

	test("culling parks far patches and stays inside the phone budget",function()
		local controller=Flowers.new({textures=stand,touch=true,parent=workspace,name="_WorldDressingSpec"})
		table.insert(cleanup,controller)
		assert(controller.distance==Dressing.CullPhone)
		local shown=controller:cull(Vector3.new(World.Hub.X,10,World.Hub.Z))
		assert(shown>0 and shown<#controller.patches,"shown "..shown)
		for _,patch in ipairs(controller.patches)do
			local near=(flat(patch.position)-flat(World.Hub)).Magnitude<=Dressing.CullPhone
			assert((patch.part.Parent~=nil)==near)
		end
		assert(controller:cull(Vector3.new(0,10,5000))==0)
		controller:destroy();assert(not controller.folder.Parent)
	end)
	end)
	for _,item in ipairs(cleanup)do
		if typeof(item)=="Instance"then item:Destroy()else item:destroy()end
	end
	assert(ok,err)
	return{passed=#cases,cases=cases}
end
