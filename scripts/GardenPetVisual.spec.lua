-- Production imported babies and exact no-dependency native recipe fallback.
return function(client)
 local readyFixture=assert(script.Parent:FindFirstChild("PetAssetsReadyFixture"),"Install the real authored-readiness QA helper beside this spec")
 require(readyFixture)(client)
 local Factory=require(client.PetFactory);local Visual=require(client.GardenPetVisual)
 local Pets=require(game.ReplicatedStorage.Shared.PetCatalog);local Bounds=require(client.PetRigBounds)
 local folder=Instance.new("Folder");folder.Name="_GardenPetVisual";folder.Parent=workspace
 local cases,views={},{};local function test(name,run)run();table.insert(cases,name)end
 local function make(id,native,appearance)
  local v=Visual.new(folder,Vector3.new(2000,4.025,0),Pets.byId[id],.72,appearance,{native=native});table.insert(views,v);return v
 end
 local function entry(v,name)for _,p in ipairs(v.pieces)do if p.name==name then return p end end;error(name.." missing")end
 local ok,err=pcall(function()
  for _,id in ipairs({"pip","puddle"})do
   test(id.." authored imported + native have proper size, forward face and bounded static allocation",function()
    for _,native in ipairs({false,true})do
     local v=make(id,native,{charmVisible=false});assert(v.backend==(if native then "NativeRecipe"else "AuthoredMesh"))
     assert(v.secondaryColor==Color3.fromHex(v.definition.palette.secondary),"focus Dot must use the authored secondary palette")
     local cf,size=Bounds.getBody(v);assert(size.Y>=1.35 and size.Y<=1.65,"garden body height "..size.Y)
     assert(entry(v,"EyeL").part.Position.Z>v.origin.Z,"eyes must face +Z")
     assert(entry(v,"Body").part.CanQuery and v.model.PrimaryPart==entry(v,"Body").part)
     local count=#v.model:GetDescendants();local pieces=#v.pieces
     v:greet();for _=1,120 do v:update(1/60)end
     assert(#v.model:GetDescendants()==count and #v.pieces==pieces)
     for _,p in ipairs(v.pieces)do assert(p.part.Anchored and not p.part.CanCollide and not p.part.CanTouch);if p.role=="charm"then assert(not p.part.CanQuery and p.part.Transparency==1)end end
    end
   end)
   test(id.." six expressions remain distinct with charms off and reduced static motion",function()
    for _,native in ipairs({false,true})do
     local v=make(id,native,{charmVisible=false});v.reducedEffects=true
     local signatures={}
     for _,name in ipairs({"neutral","curious","startled","pleased","sleepy","affectionate"})do
      v.expression=name;v:update(0)
      local eye=entry(v,"EyeL").part;local hand=entry(v,"HandL").part
      local mouth=entry(v,"MouthO").part;assert(mouth:FindFirstChildWhichIsA("SpecialMesh"),"ellipsoid mouth needs a free-axis sphere mesh")
      local signature=tostring(eye.Size)..tostring(hand.CFrame)..tostring(entry(v,"MouthSmile").part.Transparency)..tostring(entry(v,"MouthSmile").part.Size)
      assert(not signatures[signature],name.." repeats another expression");signatures[signature]=true
      assert(entry(v,"MouthO").part.Transparency==(if name=="startled"then 0 else 1))
      local cf=hand.CFrame;v:update(1);assert(hand.CFrame==cf,"reduced static pose drift")
     end
    end
   end)
   test(id.." charm toggles framing without changing the body hit hull or authority",function()
    local v=make(id,false,{charmVisible=false});local bodyCF,bodySize=Bounds.getBody(v);local _,before=Bounds.get(v)
    v:applyAppearance({charmVisible=true});local afterCF,afterSize=Bounds.getBody(v);local _,all=Bounds.get(v)
    assert(bodyCF==afterCF and bodySize==afterSize and all.Y>before.Y)
    v:applyAppearance({charmVisible=false});assert(entry(v,"CharmDot").part.Transparency==1)
   end)
   test(id.." action generations do not replay greetings or take pose ownership",function()
    local v=make(id,false);v.focusPose=true;local origin,yaw=v.origin,v.yaw
    local sample={action="greet",phase=.4,expression="curious",actionId=1,generation=4}
    v:applyGardenPose(sample);v:update(.2);local greeting=v.greeting;v:applyGardenPose(sample)
    assert(v.greeting==greeting and v.origin==origin and v.yaw==yaw and v.focusPose)
    sample.actionId=2;v:applyGardenPose(sample);assert(v.greeting==0)
   end)
  end
  test("all seven authored aliases retain identity bits, ordering and rarity",function()
   assert(Pets.byId.pip.name=="Zivvi"and Pets.byId.puddle.name=="Ovelle"and #Pets.collection==7)
   for i,pet in ipairs(Pets.collection)do
    assert(pet.index==i);local v=Factory.new(folder,Vector3.new(2000,4,0),pet,.72);table.insert(views,v)
    assert(v.model:GetAttribute("RigId")~=nil and v.definition.legacyId==pet.id)
   end
  end)
  test("a named but empty imported resource rejects the entire backend for a faithful native fallback",function()
   local assets=game.ReplicatedStorage:FindFirstChild("PetAssets");assert(assets)
   local source=assets:FindFirstChild("Zivvi");assert(source)
   local original=source:FindFirstChild("Zivvi__Body");assert(original and original:IsA("MeshPart"))
   local placeholder=Instance.new("MeshPart");placeholder.Name=original.Name;placeholder.Size=original.Size;placeholder.CFrame=original.CFrame
   original.Parent=folder;placeholder.Parent=source
   local made;local success,why=pcall(function()
    made=Factory.new(folder,Vector3.new(2000,4,0),Pets.byId.pip,.72,{charmVisible=false});table.insert(views,made)
    assert(made.backend=="NativeRecipe","empty mesh must not count as a real imported baby")
    local _,size=Bounds.getBody(made);assert(size.Y>=1.35 and size.Y<=1.65)
   end)
   placeholder:Destroy();original.Parent=source;assert(success,why)
  end)
  test("twenty complete create/update/destroy cycles release every model",function()
   for i=1,20 do local v=Factory.new(folder,Vector3.new(2000,4,0),Pets.byId[if i%2==0 then "pip"else "puddle"],.72);v:update(.1);local m=v.model;v:destroy();assert(m.Parent==nil)end
  end)
 end)
 for _,v in ipairs(views)do v:destroy()end;folder:Destroy();assert(ok,err);return cases
end
