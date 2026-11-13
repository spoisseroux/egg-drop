-- Studio Client. The forgiving pet click target (Spencer 2026-11-13): one invisible
-- box around the whole local pet carries the ClickDetector. It encloses the rig and
-- follows it, has the right flags, is ignored by ground/path raycasts, writes
-- nothing while the pet is still, goes with the pet, and only the local pet has one.
-- Usage: require(PlayerScripts.Client.ZZSpecs.PetClickTarget)(PlayerScripts.Client, PlayerGui)
return function(client,parent)
 local Target=require(client.PetClickTarget)
 local Factory=require(client.PetFactory)
 local Players=game:GetService("Players")
 local Pets=require(game:GetService("ReplicatedStorage").Shared.PetCatalog)
 local cases={};local function test(name,run)run();table.insert(cases,name)end
 local folder=Instance.new("Folder");folder.Name="_PetClickTargetSpec";folder.Parent=workspace
 local made={}
 local function newPet(position)
  local pet=Factory.new(folder,position,Pets.collection[1],.72,{},{native=true})
  pet.origin=position;pet.poseDirty=true;pet:update(0)
  table.insert(made,pet);return pet
 end
 local function encloses(part,pet)
  local half=part.Size*.5;local centre=part.Position;local count=0
  for _,entry in ipairs(pet.pieces)do
   local p=entry.part
   if p.Transparency<1 then
    count+=1
    for x=-1,1,2 do for y=-1,1,2 do for z=-1,1,2 do
     local corner=p.CFrame:PointToWorldSpace(p.Size*Vector3.new(x,y,z)*.5)-centre
     if math.abs(corner.X)>half.X+.06 or math.abs(corner.Y)>half.Y+.06 or math.abs(corner.Z)>half.Z+.06 then return false,p.Name end
    end end end
   end
  end
  return count>0,"no visible pieces"
 end
 local ok,problem=pcall(function()
  test("flags: invisible, anchored, no collide/touch, queryable, massless, inside the pet model; detector starts off",function()
   local pet=newPet(Vector3.new(0,400,0));local h=Target.attach(pet)
   local p=h.part
   assert(p.Name==Target.Name and p.Parent==pet.model and p:GetAttribute("PetClickTarget")==true)
   assert(p.Transparency==1 and p.Anchored and not p.CanCollide and not p.CanTouch and p.CanQuery and p.Massless and not p.CastShadow)
   assert(h.click:IsA("ClickDetector")and h.click.Parent==p and h.click.MaxActivationDistance==0)
   assert(Target.Reach>=16,"reach longer than the 9 stud prompt")
  end)
  test("encloses the whole rig with margin, at least MinSize a side, and follows it",function()
   local pet=newPet(Vector3.new(20,400,0));local h=Target.attach(pet)
   local fine,why=encloses(h.part,pet);assert(fine,"box misses "..tostring(why))
   local _,size=require(client.PetRigBounds).get(pet)
   assert(h.part.Size.X>=size.X*Target.Margin-.1 and h.part.Size.Y>=size.Y*Target.Margin-.1 and h.part.Size.Z>=size.Z*Target.Margin-.1,"margin")
   assert(h.part.Size.X>=Target.MinSize and h.part.Size.Y>=Target.MinSize and h.part.Size.Z>=Target.MinSize,"minimum size")
   pet.origin=Vector3.new(32,401,6);pet.yaw=1.1;pet.poseDirty=true;pet:update(0);Target.sync(h)
   fine,why=encloses(h.part,pet);assert(fine,"box left the moved pet behind "..tostring(why))
  end)
  test("a still pet writes nothing (no per-frame property churn)",function()
   local pet=newPet(Vector3.new(40,400,0));local h=Target.attach(pet)
   local writes=0
   local a=h.part:GetPropertyChangedSignal("CFrame"):Connect(function()writes+=1 end)
   local b=h.part:GetPropertyChangedSignal("Size"):Connect(function()writes+=1 end)
   for _=1,30 do Target.sync(h)end
   a:Disconnect();b:Disconnect()
   assert(writes==0,"writes while still: "..writes)
  end)
  test("ground/path raycasts never stop on the box",function()
   local pet=newPet(Vector3.new(60,400,0));local h=Target.attach(pet)
   local params=RaycastParams.new();params.RespectCanCollide=true;params.FilterType=Enum.RaycastFilterType.Include;params.FilterDescendantsInstances={folder}
   local hit=workspace:Raycast(h.part.Position+Vector3.new(0,20,0),Vector3.new(0,-40,0),params)
   assert(hit==nil or hit.Instance~=h.part,"RespectCanCollide ray hit the box")
   local exclude=RaycastParams.new();exclude.FilterDescendantsInstances={pet.model}
   hit=workspace:Raycast(h.part.Position+Vector3.new(0,20,0),Vector3.new(0,-40,0),exclude)
   assert(hit==nil or not hit.Instance:IsDescendantOf(pet.model),"pet-excluding ray hit the box")
  end)
  test("goes with the pet",function()
   local pet=newPet(Vector3.new(80,400,0));local h=Target.attach(pet)
   pet:destroy();assert(h.part.Parent==nil,"box outlived the pet")
   Target.sync(h) -- no error after the pet is gone
  end)
  test("live garden: only the local pet has a box (visitor pets are not pettable)",function()
   local me=Players.LocalPlayer.UserId
   for _,model in ipairs(workspace:GetDescendants())do
    if model:IsA("Model")and model:GetAttribute("CompanionOwnerId")~=nil and not model:IsDescendantOf(folder)then
     local box=model:FindFirstChild(Target.Name)
     if model:GetAttribute("LocalCompanion")==true and model:GetAttribute("CompanionOwnerId")==me then
      assert(box and box:FindFirstChildOfClass("ClickDetector"),"local pet "..model.Name.." has no click box")
     else
      assert(box==nil,"visitor pet "..model.Name.." has a click box")
     end
    end
   end
  end)
 end)
 for _,pet in ipairs(made)do if not pet.destroyed then pet:destroy()end end
 folder:Destroy()
 assert(ok,problem)
 return{passed=#cases,cases=cases}
end
