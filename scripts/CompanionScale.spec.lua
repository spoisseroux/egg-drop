-- Native model fixtures, isolated floor/roots. No character, inventory, input or camera mutation.
return function(client)
 local Pets=require(game.ReplicatedStorage.Shared.PetCatalog);local Follow=require(client.PetFollow)
 local folder=Instance.new("Folder");folder.Name="_CompanionScale";folder.Parent=workspace
 local cases,visuals={},{};local ground=Follow.ground
 local function test(name,run)run();table.insert(cases,name)end
 local function make(pet,scale)
  local family=pet.family or pet.id;local module=if family=="pip"then client.PipVisual elseif family=="puddle"then client.PuddleVisual else client.BonusPetVisual
  local v=require(module).new(folder,Vector3.new(2000,4.025,0),pet,scale);table.insert(visuals,v);return v
 end
 local function near(a,b,label)assert((a-b).Magnitude<.0002,label.." actual="..tostring(a).." expected="..tostring(b))end
 local function feet(v)
  for _,p in ipairs(v.model:GetChildren())do if p:IsA("BasePart")and(p.Name=="Slipper"or p.Name=="Foot")then
   local c,s=p.CFrame,p.Size;local half=(math.abs(c.RightVector.Y)*s.X+math.abs(c.UpVector.Y)*s.Y+math.abs(c.LookVector.Y)*s.Z)*.5
   assert(c.Y-half>=v.origin.Y-.0001,"foot below floor: "..v.model.Name)
  end end
 end
 local ok,problem=pcall(function()
  local floor=Instance.new("Part");floor.Name="Ground";floor.Size=Vector3.new(300,1,300);floor.CFrame=CFrame.new(2050,3.5,0);floor.Anchored=true;floor.Parent=folder
  for _,pet in ipairs(Pets.collection)do
   test(pet.id.." authored default1 and world.72 stay uniform through animated poses",function()
    local default=make(pet);assert(default.worldScale==1 and not default.worldContext);default:destroy()
    local full,small=make(pet,1),make(pet,.72);assert(full.worldScale==1 and full.worldContext and small.worldScale==.72)
    assert(#full.pieces==#small.pieces);local count=#small.model:GetDescendants()
    full:greet();small:greet()
    for _,dt in ipairs({0,.08,.13,.12,.2,.3,.4,1})do
     full.gaitPhase,small.gaitPhase=.8,.8;full.gaitWeight,small.gaitWeight=.7,.7;full:update(dt);small:update(dt)
     for i,e in ipairs(full.pieces)do local a,b=e.part,small.pieces[i].part
      assert(a.Name==b.Name);near(b.Size,a.Size*.72,pet.id.." size/"..a.Name)
      near(b.Position-small.origin,(a.Position-full.origin)*.72,pet.id.." offset/"..a.Name)
      near(b.CFrame.LookVector,a.CFrame.LookVector,pet.id.." rotation/"..a.Name)
     end
     feet(small)
    end
    assert(#small.model:GetDescendants()==count);full:destroy();small:destroy()
   end)
   test(pet.id.." travel gait rests snaps turns and respects reduced effects",function()
    local v=make(pet,.72);local root=Instance.new("Part");root.Anchored=true;root.CanCollide=false;root.CFrame=CFrame.new(2000,7,0);root.Parent=folder
    v.origin=Vector3.new(2002.6,4.025,3);local state=Follow.step(v,root,1/60);assert(v.gaitWeight==0 and v.gaitPhase==0)
    for _=1,40 do root.CFrame+=Vector3.new(.12,0,0);state=Follow.step(v,root,1/60,state);v:update(1/60);feet(v)end
    assert(v.gaitWeight>0 and v.gaitPhase>0,"movement did not drive gait: "..pet.id)
    local yaw=v.yaw;root.CFrame*=CFrame.Angles(0,math.pi/2,0);state=Follow.step(v,root,.1,state);assert(v.yaw~=yaw)
    for _=1,120 do state=Follow.step(v,root,.1,state);v:update(.1)end
    assert(v.gaitWeight==0 and v.gaitPhase==0,"stride persisted at rest")
    root.CFrame+=Vector3.new(100,0,0);state=Follow.step(v,root,.1,state);assert(v.gaitWeight==0 and v.gaitPhase==0)
    near(v.origin,Vector3.new((root.Position-root.CFrame.LookVector*3+root.CFrame.RightVector*2.6).X,4.025,(root.Position-root.CFrame.LookVector*3+root.CFrame.RightVector*2.6).Z),"far snap")
    local replacement=root:Clone();replacement.CFrame=root.CFrame;replacement.Parent=folder;v.gaitPhase,v.gaitWeight=2,1;state=Follow.step(v,replacement,.1,state);assert(v.gaitWeight==0 and v.gaitPhase==0 and state.root==replacement)
    v:greet();state=Follow.step(v,replacement,.1,state,true);v:update(.1);local frame=v.model.PrimaryPart.CFrame;v:update(.8)
    near(v.model.PrimaryPart.Position,frame.Position,"reduced body moved");near(v.model.PrimaryPart.CFrame.LookVector,frame.LookVector,"reduced body turned");assert(v.gaitWeight==0)
    root:Destroy();replacement:Destroy();v:destroy()
   end)
  end
  test("ground sampling stays10Hz without per-foot queries",function()
   local calls=0;local v=make(Pets.byId.pip,.72)
   Follow.ground=function(position,visual,...)if visual==v then calls+=1 end;return ground(position,visual,...)end
   local r=Instance.new("Part");r.Anchored=true;r.CanCollide=false;r.CFrame=CFrame.new(2000,7,0);r.Parent=folder;local state
   for _=1,60 do state=Follow.step(v,r,1/60,state)end
   Follow.ground=ground;assert(calls>=8 and calls<=11,"ground calls="..calls);r:Destroy();v:destroy()
  end)
  test("normal16stud movement is bounded to3.5cycles at15/30/60Hz",function()
   for _,fps in ipairs({15,30,60})do
    local v=make(Pets.byId.wick,.72);local r=Instance.new("Part");r.Anchored=true;r.CanCollide=false;r.CFrame=CFrame.new(2000,7,0);r.Parent=folder
    v.origin=Vector3.new(2002.6,4.025,3);local state=Follow.step(v,r,1/fps);local cycles=0
    for _=1,fps*2 do
     local previous=v.gaitPhase;r.CFrame+=Vector3.new(16/fps,0,0);state=Follow.step(v,r,1/fps,state)
     local advance=(v.gaitPhase-previous)%(math.pi*2);assert(advance<=3.5/fps*math.pi*2+.0001,"cadence cap exceeded at"..fps)
     cycles+=advance/(math.pi*2)
    end
    assert(cycles>1 and cycles<=7.0001,"normal travel cadence="..cycles);r:Destroy();v:destroy()
   end
  end)
  test("stride advances by rendered horizontal distance rather than wall clock",function()
   local v=make(Pets.byId.pip,.72);Follow.rest(v);assert(v.gaitWeight==0 and v.gaitPhase==0)
   v.reducedEffects=true;local before=#v.model:GetDescendants();for _=1,120 do v:update(1/15)end
   assert(v.gaitWeight==0 and v.gaitPhase==0 and #v.model:GetDescendants()==before);v:destroy()
  end)
 end)
 Follow.ground=ground;for _,v in ipairs(visuals)do v:destroy()end;folder:Destroy();assert(ok,problem)
 return{passed=#cases,cases=cases}
end
