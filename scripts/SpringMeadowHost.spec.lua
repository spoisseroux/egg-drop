-- Actual cached host validator on the shifted floor; controlled detached rays.
return function(server,hostSource)
 local Shared=game.ReplicatedStorage.Shared;local World=require(Shared.HollowWorldLayout)
 -- World 1 v7 (2026-11-12) has no Spring Meadow basin or loop; this spec covers the legacy world only.
 if not World.Spring then return{passed=0,cases={},skipped="no Spring Meadow in World "..tostring(World.WorldVersion)}end
 local W=require(Shared.GardenWalkability);local P=require(Shared.GardenPathPlanner);local A=require(Shared.GardenActivity)
 local L=require(Shared.GardenLayout);local G=require(server.GardenState)
 local first=assert(hostSource:find("local wanderScene",1,true));local last=assert(hostSource:find("local garden = GardenState.new",first,true))
 local module=Instance.new("ModuleScript");module.Name="_SpringHostFixture";module.Parent=server
 module.Source="return function(e)local workspace,GardenWalkability,GardenPathPlanner,GardenActivity,GardenLayout=e.workspace,e.walk,e.planner,e.activity,e.layout;local gardenScene\n"..hostSource:sub(first,last-1).."\nreturn validWander end"
 local install=require(module);module:Destroy()
 local room=Instance.new("Model");room.Name="EggDropLounge"
 local floor=Instance.new("Part");floor.Name="Floor";floor.Size=Vector3.new(World.Width,1,World.Depth);floor.CFrame=CFrame.new(0,3.5,World.FloorCenterZ);floor.Parent=room
 local water=Instance.new("Part");water.Name="SpringWater";water.Size=World.Spring.BasinSize;water.CFrame=CFrame.new(World.Spring.BasinCenter);water:SetAttribute("GardenWetRegion",true);water.Parent=room
 local env={blocked=false,groundY=World.FloorTop}
 local fake={FindFirstChild=function(_,name)return if name=="EggDropLounge"then room else nil end}
 function fake:Raycast(origin,direction)
  if math.abs(direction.X)<1e-8 and math.abs(direction.Z)<1e-8 and direction.Y<0 then return{Position=Vector3.new(origin.X,env.groundY,origin.Z),Material=Enum.Material.Grass,Instance=floor}end
  return if env.blocked then{Instance=floor,Position=origin}else nil
 end
 local validate=install({workspace=fake,walk=W,planner=P,activity=A,layout=L})
 local center=World.Spring.Rest
 local input={alive=true,owned=true,mode="Room",petId="pip",characterId=1,petGeneration=1,position=center+Vector3.new(0,3,-1),anchor=center+Vector3.new(0,0,-2),yaw=0}
 local cases={};local function test(name,run)run();table.insert(cases,name)end
 local ok,problem=pcall(function()
  test("actual host floor-local bounds admit both spring slots beyond the former south edge",function()
   for _,rest in ipairs({World.Spring.RestWest,World.Spring.RestEast})do local target=validate(input,rest,input.anchor);assert(target and(target-rest).Magnitude<.001)end
   assert(validate(input,Vector3.new(0,4.025,70),Vector3.new(0,4.025,68)))
  end)
  test("new south edge and unchanged north and east edges reject outside targets",function()
   for _,target in ipairs({Vector3.new(0,4.025,113),Vector3.new(0,4.025,-65),Vector3.new(81,4.025,87)})do assert(validate(input,target,input.anchor)==nil)end
  end)
  test("tagged spring footprint rejects a deceptive floor ray under its water",function()
   local target=Vector3.new(water.Position.X,4.025,water.Position.Z)
   assert(not W.segmentAllowed(target,target,{water})and validate(input,target,input.anchor)==nil)
  end)
  test("raised rock and blocked dry approach cannot validate as rest",function()
   env.groundY=5;assert(validate(input,World.Spring.RestWest,input.anchor)==nil);env.groundY=4
   env.blocked=true;assert(validate(input,World.Spring.RestWest,input.anchor)==nil);env.blocked=false
  end)
  test("actual coordinator and host preflight give two owners separate six-second rests",function()
   local now=0;local g=G.new({now=function()return now end,validWander=validate,
    planPath=function(from,to,v,speed,minimum,yaw,via,terminal)return P.plan(from,to,v,speed,minimum,yaw,via,terminal,{water})end})
   g:sync({[1]=table.clone(input),[2]=table.clone(input)});now=4;g:decide()
   local a,b=g.actors[1],g.actors[2];assert(a.action=="nookApproach"and b.action=="nookApproach"and a.restAnchorId~=b.restAnchorId)
   now=math.max(a.endTime,b.endTime)+.01;g:decide()
   assert(a.action=="nookRest"and b.action=="nookRest"and(g:position(a,now)-g:position(b,now)).Magnitude==5)
  end)
 end)
 room:Destroy();assert(ok,problem);return{passed=#cases,cases=cases,actualHostValidator=true}
end
