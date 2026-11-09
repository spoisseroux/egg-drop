-- Real rig parts, isolated daylight input to the exact production face painter.
-- Does not alter Lighting, clock, ownership or pet geometry.
return function(client)
 local Face=require(client.PetFace);local Pets=require(game.ReplicatedStorage.Shared.PetCatalog)
 local folder=Instance.new("Folder");folder.Name="_PetNightFace";folder.Parent=workspace;local cases,views={},{}
 -- Native BasePart.Color truncates each channel to an 8-bit value. The
 -- requested channel can exceed readback by one step (plus float epsilon).
 -- Check the signed interval, so unexpectedly brighter output still fails.
 local function near(actual,target)
  local epsilon=.000001;local maximum=1/255+epsilon
  local r,g,b=target.R-actual.R,target.G-actual.G,target.B-actual.B
  return r>=-epsilon and r<maximum and g>=-epsilon and g<maximum and b>=-epsilon and b<maximum
 end
 local function make(pet,world)
  local family=pet.family or pet.id;local module=if family=="pip"then client.PipVisual elseif family=="puddle"then client.PuddleVisual else client.BonusPetVisual
  local v=require(module).new(folder,Vector3.new(2000,4.025,0),pet,if world then .72 else nil);table.insert(views,v);return v
 end
 local ok,err=pcall(function()
  for _,pet in ipairs(Pets.collection)do
   local v=make(pet,true);local body=v.model.PrimaryPart;local cf,size,color,material=body.CFrame,body.Size,body.Color,body.Material;local cheeks=0
   for _,entry in ipairs(v.pieces)do if entry.faceRole then
    Face.paint(entry,true,nil,1);assert(entry.part.Material==entry.faceBaseMaterial and near(entry.part.Color,entry.faceBaseColor))
    Face.paint(entry,true,nil,0)
    local base=entry.faceBaseColor;local expected=base
    local expectedMaterial=if entry.faceRole=="spark"and not entry.materialSurface then Enum.Material.Neon else entry.faceBaseMaterial
    assert(entry.part.Material==expectedMaterial and near(entry.part.Color,expected))
    local once=entry.part.Color
    for _=1,100 do Face.paint(entry,true,nil,0)end
    assert(entry.part.Color==once and entry.part.Material==expectedMaterial,"repeated night paint compounded or drifted")
    if entry.faceRole=="cheek"then
     cheeks+=1;local blush=base:Lerp(Color3.fromRGB(239,156,175),.5)
     Face.paint(entry,true,blush,0);assert(near(entry.part.Color,blush))
    end
    Face.paint(entry,true,nil,1);assert(entry.part.Material==entry.faceBaseMaterial and near(entry.part.Color,base))
   end end
   assert(cheeks==2 and body.CFrame==cf and body.Size==size and body.Color==color and body.Material==material)
   assert(not v.model:FindFirstChildWhichIsA("Light",true));table.insert(cases,pet.id.." bounded night face blush and exact day restoration")
  end
  for _,id in ipairs({"pip","puddle","wick"})do
   local v=make(Pets.byId[id],false)
   for _,entry in ipairs(v.pieces)do if entry.faceRole then Face.paint(entry,v.worldContext,nil,0);assert(entry.part.Material==entry.faceBaseMaterial and near(entry.part.Color,entry.faceBaseColor))end end
  end
  table.insert(cases,"default-scale cinematic faces ignore the world night treatment")
 end)
 for _,v in ipairs(views)do v:destroy()end;folder:Destroy();assert(ok,err);return cases
end
