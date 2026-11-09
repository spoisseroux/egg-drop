-- Native fallback and avatar joint geometry only, no network/profile writes.
return function(client)
 local Pose=require(client.PetCarePose);local Arms=require(client.AvatarCarePose);local Factory=require(client.PetFactory)
 local Pets=require(game.ReplicatedStorage.Shared.PetCatalog);local folder=Instance.new("Folder");folder.Parent=workspace
 local cases={};local visuals={};local avatars={};local function test(name,run)run();table.insert(cases,name)end
 local function avatar(r15)
  local model=Instance.new("Model");model.Name=if r15 then "_R15Care"else "_R6Care";model.Parent=folder
  local function part(name,size,position)local p=Instance.new("Part");p.Name=name;p.Size=size;p.CFrame=CFrame.new(position);p.Anchored=true;p.CanCollide=false;p.Parent=model;return p end
  local torso=part(if r15 then "UpperTorso"else "Torso",Vector3.new(2,2,1),Vector3.new(0,7,0));part("Head",Vector3.new(2,1,1),Vector3.new(0,8.5,0))
  for _,label in ipairs({"Left","Right"})do local sign=if label=="Left"then -1 else 1
   local upper=part(if r15 then label.."UpperArm"else label.." Arm",Vector3.new(1,2,1),Vector3.new(sign*1.5,7,0))
   local shoulder=Instance.new("Motor6D");shoulder.Name=label..(if r15 then "Shoulder"else " Shoulder");shoulder.Part0=torso;shoulder.Part1=upper;shoulder.C0=CFrame.new(sign,1,0);shoulder.C1=CFrame.new(0,1,0);shoulder.Parent=if r15 then upper else torso
   if r15 then local lower=part(label.."LowerArm",Vector3.one,Vector3.new(sign*1.5,5.5,0));local elbow=Instance.new("Motor6D");elbow.Name=label.."Elbow";elbow.Part0=upper;elbow.Part1=lower;elbow.Parent=lower end
  end
  table.insert(avatars,model);return model,torso
 end
 local ok,problem=pcall(function()
  for _,r15 in ipairs({false,true})do
   test((if r15 then "R15"else "R6").." all seven held babies keep visible charm under chin without scaling or changing identity",function()
    local character,torso=avatar(r15);local chin=character.Head.Position.Y-character.Head.Size.Y*.5
    for _,pet in ipairs(Pets.collection)do
     local v=Factory.new(folder,Vector3.zero,pet,.72,{charmVisible=true,charmShape="ring"},{native=true});table.insert(visuals,v);local model=v.model;local size=v.pieces[1].size
     Pose.set(v,"Carried");assert(Pose.carried(v,character));v:update(0)
     assert(v.model==model and v.pieces[1].size==size and v.origin.Y<torso.Position.Y)
     local top=-math.huge
     for _,e in ipairs(v.pieces)do if e.part.Transparency<.99 then for x=-1,1,2 do for y=-1,1,2 do for z=-1,1,2 do top=math.max(top,e.part.CFrame:PointToWorldSpace(e.part.Size*Vector3.new(x,y,z)*.5).Y)end end end end end
     assert(top<=chin-.09,pet.id.." visible carried geometry crosses chin clearance")
    end
   end)
  end
  test("carried feet move with holder and never retain world plant anchors",function()
   local character=avatar(false);local v=visuals[1];Pose.set(v,"Carried");Pose.carried(v,character);v:update(0)
   local origin=v.origin;character.Torso.CFrame+=Vector3.new(3,0,0);Pose.carried(v,character);v:update(1/60)
   assert((v.origin-origin).Magnitude>2.9)
   for _,slot in ipairs(v.poseSlots)do if slot.side then assert(not slot.anchor and not slot.stance)end end
  end)
  test("both avatar joint adapters restore exact captured animation transforms on leave",function()
   for _,r15 in ipairs({false,true})do local character=avatar(r15);local p=Arms.new();local frames={}
    for _,m in ipairs(character:GetDescendants())do if m:IsA("Motor6D")then m.Transform=CFrame.Angles(.04,.03,.02);frames[m]=m.Transform end end
    local torso=character:FindFirstChild("UpperTorso")or character.Torso;local before=torso.CFrame
    p:hold(character,{Vector3.new(-.4,5.8,-1.2),Vector3.new(.4,5.7,-1.2)});assert(next(p.active))
    p:restore();for m,frame in pairs(frames)do
     local delta=frame:ToObjectSpace(m.Transform);local _,angle=delta:ToAxisAngle()
     local beforeValues,afterValues={frame:GetComponents()},{m.Transform:GetComponents()};local difference=0
     for i=1,12 do difference=math.max(difference,math.abs(beforeValues[i]-afterValues[i]))end
     assert(difference<=1e-7,string.format("%s %s restore differs: position %.12g angle %.12g maxcomponent %.12g; before %s after %s",if r15 then "R15"else "R6",m:GetFullName(),delta.Position.Magnitude,angle,difference,tostring(frame),tostring(m.Transform)))
    end
    assert(torso.CFrame==before,"carry arm overlay moved torso");p:destroy()
   end
  end)
  test("reduced hold transfer is immediate and release resets pose without touching palette",function()
   local v=visuals[1];local character=avatar(false);v.reducedEffects=true;Pose.set(v,nil);Pose.set(v,"Carried");Pose.carried(v,character,0)
   assert(v.careElapsed==0 and v.origin.Y>0);local color=v.colors.body
   Pose.set(v,nil);assert(v.carePitch==0 and v.careHand==0 and v.careFootLift==0 and v.colors.body==color)
  end)
  test("dock pose changes upper body only and keeps fixed sole datum",function()
   local v=visuals[2];Pose.set(v,"Docked");v.origin=Vector3.new(11.75,5.18,-4.2);v.yaw=0;v:update(0)
   assert(v.origin==Vector3.new(11.75,5.18,-4.2)and v.carePitch==0 and v.careBodyLower>0)
   for _,slot in ipairs(v.poseSlots)do if slot.side then assert(not slot.anchor)end end
  end)
 end)
 for _,v in ipairs(visuals)do v:destroy()end;folder:Destroy();assert(ok,problem);return {passed=#cases,cases=cases}
end
