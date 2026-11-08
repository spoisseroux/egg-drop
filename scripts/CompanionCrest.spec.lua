-- Native pet geometry + isolated projection math; never changes CurrentCamera or character.
-- Root separately captures actual Billboard occlusion/focus with the native camera.
return function(client)
 local Pets=require(game.ReplicatedStorage.Shared.PetCatalog);local Prestige=require(client.PetPrestige);local Shot=require(client.PetGreetingShot)
 local Bounds=require(client.PetRigBounds)
 local folder=Instance.new("Folder");folder.Name="_CompanionCrest";folder.Parent=workspace
 local cases,visuals={},{}
 local function test(name,run)run();table.insert(cases,name)end
 local function make(pet,rank)
  local family=pet.family or pet.id;local module=if family=="pip"then client.PipVisual elseif family=="puddle"then client.PuddleVisual else client.BonusPetVisual
  local v=require(module).new(folder,Vector3.new(0,4.025,0),pet,.72);Prestige.attach(v,pet,rank,false);table.insert(visuals,v);return v
 end
 local function projection(frame,viewport)
  local camera={CFrame=frame,ViewportSize=viewport,FieldOfView=43}
  function camera:WorldToViewportPoint(world)
   local p=self.CFrame:PointToObjectSpace(world);local depth=-p.Z;local scale=viewport.Y/(2*math.tan(math.rad(self.FieldOfView)*.5))
   return Vector3.new(viewport.X*.5+p.X/depth*scale,viewport.Y*.5-p.Y/depth*scale,depth)
  end
  return camera
 end
 local function top(v,camera)
  local cf,s=Bounds.get(v);local result=math.huge
  for x=-1,1,2 do for y=-1,1,2 do for z=-1,1,2 do result=math.min(result,camera:WorldToViewportPoint(cf:PointToWorldSpace(s*Vector3.new(x,y,z)*.5)).Y)end end end
  return result
 end
 local function clear(v,camera,label)
  Prestige.updateBadge(v,camera);local badge=v.prestigeBadge
  assert(badge.Enabled,"crest hidden in supported framing: "..label)
  local pixel=camera:WorldToViewportPoint(v.model.PrimaryPart.Position+badge.StudsOffsetWorldSpace)
  assert(pixel.Y+13<=top(v,camera)-4.9,"crest intersects full animated silhouette: "..label)
  assert(pixel.Y-13>=game:GetService("GuiService"):GetGuiInset().Y+3.9,"crest crosses native safe top: "..label)
  assert(badge.Size==UDim2.fromOffset(46,26)and not badge.AlwaysOnTop and badge.MaxDistance==30)
 end
 local ok,problem=pcall(function()
  test("focus softens only plate and border then restores exact authored transparency",function()
   local v=make(Pets.byId.pip,1)
   local camera=projection(CFrame.lookAt(Vector3.new(0,8,12),Vector3.new(0,5.2,0)),Vector2.new(733,307))
   local plate,stroke=v.prestigePlate,v.prestigeStroke;local plateAlpha,strokeAlpha=plate.BackgroundTransparency,stroke.Transparency
   local preference=math.clamp(game:GetService("GuiService").PreferredTransparency,0,1)
   v.focused=true;Prestige.updateBadge(v,camera);assert(math.abs(plate.BackgroundTransparency-.62*preference)<.000001 and math.abs(stroke.Transparency-.45*preference)<.000001)
   for _=1,30 do Prestige.updateBadge(v,camera)end
   v.focused=false;Prestige.updateBadge(v,camera);assert(plate.BackgroundTransparency==plateAlpha and stroke.Transparency==strokeAlpha)
   assert(v.prestigeBadge.Crest.Rank.TextTransparency==0);v:destroy()
  end)
  for _,pet in ipairs(Pets.collection)do
   test(pet.id.." ranked focus reserves complete animated crown and plate at three aspects",function()
    local v=make(pet,1);v.focusPose=true;assert(not v.masteryEmitter and Prestige.crestReserve(v)==32)
    for _,viewport in ipairs({Vector2.new(1649,971),Vector2.new(733,307),Vector2.new(385,703)})do
     local topInset,bottomInset=game:GetService("GuiService"):GetGuiInset()
     local bounds,size=Bounds.get(v);local args={size=size,silhouette=Shot.captureSilhouette(v,bounds),centerOffset=CFrame.Angles(0,v.yaw or 0,0):VectorToObjectSpace(bounds.Position-v.origin),rootPosition=Vector3.new(0,7,0),forward=Vector3.new(0,0,-1),aspect=viewport.X/viewport.Y,
      crestPixelReserve=32,viewportHeight=viewport.Y,safeTopInset=topInset.Y,safeBottomInset=bottomInset.Y,safeLeftInset=topInset.X,safeRightInset=bottomInset.X,animationTopReserve=.55*v.worldScale,floor={cf=CFrame.new(0,3.5,0),size=Vector3.new(112,1,96)},ground=function()return 4.025 end,clear=function()return true end}
     local plan=Shot.plan(args);assert(plan,"no ranked focus plan: "..pet.id..tostring(viewport));local reach=Shot.maximumReach(size,args.aspect,32,viewport.Y,args.safeTopInset,args.animationTopReserve)
     assert((plan.camera.Position-args.rootPosition).Magnitude<=reach,"rank headroom exceeded existing candidate bound")
     v.origin,v.yaw=plan.origin,plan.yaw;v.greeting=if pet.id=="pip"or pet.family=="pip"or pet.id=="puddle"then 3 else 0;v:update(0)
     local camera=projection(plan.camera,viewport);clear(v,camera,pet.id..tostring(viewport).." rest")
     v:greet();for frame=1,90 do v:update(1/60);clear(v,camera,pet.id..tostring(viewport).." greeting@"..frame)end
    end
    v:destroy()
   end)
  end
  test("invisible Puddle ripple cannot move badge/framing while tail and crown remain included",function()
   local v=make(Pets.byId.puddle,1);v.greeting=3;v:update(0)
   local camera=projection(CFrame.lookAt(Vector3.new(0,8,12),Vector3.new(0,5.2,0)),Vector2.new(733,307));clear(v,camera,"Puddle hull")
   local before,size=Bounds.get(v);local offset=v.prestigeBadge.StudsOffsetWorldSpace
   for _,e in ipairs(v.pieces)do if e.role=="ripple"then e.part.Size=Vector3.new(100,20,100);e.part.CFrame=CFrame.new(100,100,100);e.part.Transparency=1 end end
   local after,afterSize=Bounds.get(v);assert(before==after and size==afterSize)
   Prestige.updateBadge(v,camera);assert(v.prestigeBadge.StudsOffsetWorldSpace==offset,"FX changed badge")
   local tail;for _,e in ipairs(v.pieces)do if e.part.Name=="TailDrop"then tail=e;break end end
   tail.frame+=Vector3.new(0,4,0);v:update(0);local raised,raisedSize=Bounds.get(v)
   assert(raised.Y+raisedSize.Y*.5>before.Y+size.Y*.5+1,"tail excluded from visible hull");v:destroy()
   local crown=make(Pets.byId.bloom_pip,1);local cf,s=Bounds.get(crown);crown.model.WideLeaf.CFrame+=Vector3.new(0,4,0);local changed,cs=Bounds.get(crown)
   assert(changed.Y+cs.Y*.5>cf.Y+s.Y*.5+1,"crown excluded from visible hull");crown:destroy()
  end)
  test("rank0 has no plate; rankI updates before the no-emitter return",function()
   local v=make(Pets.byId.pip,0);assert(not v.prestigeBadge and Prestige.crestReserve(v)==0);v:destroy()
   v=make(Pets.byId.foxfire_wick,1);local camera=workspace.CurrentCamera;assert(camera and camera.ViewportSize.Y>0)
   local bounds=Bounds.get(v);v.origin+=camera.CFrame:PointToWorldSpace(Vector3.new(0,-.2,-10))-bounds.Position;v:update(0)
   Prestige.update(v,0,true);assert(v.prestigeBadge.Enabled and not v.masteryEmitter)
   local center=camera:WorldToViewportPoint(v.model.PrimaryPart.Position+v.prestigeBadge.StudsOffsetWorldSpace)
   assert(center.Y+13<=top(v,camera)-4.9,"actual native projection crest overlap");v:destroy()
  end)
  test("ranked badge hides out of range/behind/offscreen then restores without allocations",function()
   local v=make(Pets.byId.orbit,3);v.greeting=0;v:update(0)
   local camera=projection(CFrame.lookAt(Vector3.new(0,8,12),Vector3.new(0,5.2,0)),Vector2.new(733,307));clear(v,camera,"visible")
   local count=#v.model:GetDescendants();local origin=v.origin
   for _,position in ipairs({Vector3.new(0,4,-60),Vector3.new(0,4,80),Vector3.new(0,100,0)})do v.origin=position;v:update(0);Prestige.updateBadge(v,camera);assert(not v.prestigeBadge.Enabled)end
   v.origin=origin;v:update(0);clear(v,camera,"restored");assert(#v.model:GetDescendants()==count);v:destroy()
  end)
 end)
 for _,v in ipairs(visuals)do v:destroy()end;folder:Destroy();assert(ok,problem);return{passed=#cases,cases=cases}
end
