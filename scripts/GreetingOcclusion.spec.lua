-- Real focus collector/planner, isolated geometry. No live camera or avatar writes.
return function(client)
 local Room=require(client.RoomView);local Shot=require(client.PetGreetingShot)
 local holder=Instance.new("Folder");holder.Name="_GreetingOcclusionFixture";holder.Parent=workspace
 local cases={};local function test(name,f)f();table.insert(cases,name)end
 local root=Vector3.new(-5.5,6.998,4)
 local function scene()
  local room=Instance.new("Model");room.Parent=holder
  local floor=Instance.new("Part");floor.Name="Floor";floor.Anchored=true;floor.CanCollide=false;floor.Size=Vector3.new(160,1,128);floor.CFrame=CFrame.new(0,3.5,0);floor.Parent=room
  return room,floor
 end
 local function args(floor)return{rootPosition=root,actualOrigin=Vector3.new(-2.9,4.025,7),forward=Vector3.new(0,0,-1),size=Vector3.new(1.5,1.6,1),centerOffset=Vector3.new(0,.8,0),aspect=827/412,viewportHeight=412,safeTopInset=88,
  floor={cf=floor.CFrame,size=floor.Size},ground=function()return 4.025 end,clear=function()return true end}end
 local ok,problem=pcall(function()
  test("tiny nonqueryable nested grass around the first lens forces a clear alternate bearing",function()
   local room,floor=scene();local options=args(floor);local first=assert(Shot.plan(options))
   local nested=Instance.new("Model");nested.Parent=room
   local grass=Instance.new("Part");grass.Name="GroundFoliage";grass.Anchored=true;grass.Size=Vector3.new(.75,.75,.25);grass.CFrame=first.camera;grass.Material=Enum.Material.Grass;grass.CanCollide=false;grass.CanQuery=false;grass.Parent=nested
   assert(grass.Size.Magnitude<2,"fixture must expose the retired size cutoff")
   local blocks=Room.greetingVisualBlocks(room,floor,root,20)
   assert(#blocks==1 and blocks[1].source==grass and Shot.segmentBlocked(first.camera.Position,first.target,blocks))
   options.clear=function(position,target)return not Shot.segmentBlocked(position,target,blocks)end
   local plan=assert(Shot.plan(options),"tiny leaf removed every safe focus angle")
   assert(plan.bearing~=first.bearing and not Shot.segmentBlocked(plan.camera.Position,plan.target,blocks))
   assert((plan.origin-root).Magnitude<=Shot.StageReach and plan.fov==43)
  end)
  test("ground, invisible geometry and distant decor stay outside the focus index",function()
   local room,floor=scene()
   for _,entry in ipairs({{root,1},{Vector3.new(1000,5,0),0}})do
    local p=Instance.new("Part");p.Anchored=true;p.CanCollide=false;p.Size=Vector3.one;p.Position=entry[1];p.Transparency=entry[2];p.Parent=room
   end
   local locallyHidden=Instance.new("Part");locallyHidden.Anchored=true;locallyHidden.CanCollide=false;locallyHidden.Position=root;locallyHidden.LocalTransparencyModifier=1;locallyHidden.Parent=room
   assert(#Room.greetingVisualBlocks(room,floor,root,20)==0)
  end)
  test("primitive mesh Scale and Offset use the actual near rendered bounds",function()
   local room,floor=scene();local p=Instance.new("Part");p.Anchored=true;p.CanCollide=false;p.Size=Vector3.new(.1,.2,.1);p.Position=Vector3.new(200,5,0);p.CanQuery=false;p.Parent=room
   local mesh=Instance.new("SpecialMesh");mesh.MeshType=Enum.MeshType.Sphere;mesh.Scale=Vector3.new(10,4,2);mesh.Offset=Vector3.new(-200,0,0);mesh.Parent=p
   local blocks=Room.greetingVisualBlocks(room,floor,Vector3.new(0,7,0),3)
   assert(#blocks==1 and(blocks[1].CFrame.Position-Vector3.new(0,5,0)).Magnitude<1e-6)
   assert((blocks[1].Size-Vector3.new(1,.8,.2)).Magnitude<1e-6)
   assert(Shot.segmentBlocked(Vector3.new(0,5,1),Vector3.new(0,5,-1),blocks))
  end)
  test("an unobstructed focus retains its original camera, reach and framing",function()
   local room,floor=scene();local options=args(floor);local original=assert(Shot.plan(options));local blocks=Room.greetingVisualBlocks(room,floor,root,20)
   options.clear=function(position,target)return not Shot.segmentBlocked(position,target,blocks)end
   local plan=assert(Shot.plan(options));assert(plan.bearing==original.bearing and(plan.camera.Position-original.camera.Position).Magnitude<1e-6 and(plan.origin-original.origin).Magnitude<1e-6)
  end)
 end)
 holder:Destroy();assert(ok,problem);return{passed=#cases,cases=cases,actualCollector=true,actualPlanner=true,liveCameraChanged=false}
end
