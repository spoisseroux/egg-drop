-- Authored five-family replacement keeps account IDs, channels and no-asset fallback.
return function(client)
 local readyFixture=assert(script.Parent:FindFirstChild("PetAssetsReadyFixture"),"Install the real authored-readiness QA helper beside this spec")
 require(readyFixture)(client)
 local Visual=require(client.GardenPetVisual);local Factory=require(client.PetFactory)
 local Shared=game.ReplicatedStorage.Shared;local Pets=require(Shared.PetCatalog);local Hue=require(Shared.HueCatalog);local Palette=require(Shared.PetPalette)
 local cases,views={},{};local folder=Instance.new("Folder");folder.Name="_NewBabyRigs";folder.Parent=workspace
 local identities={{"wick","Tikket","tikket"},{"orbit","Nuum","nuum"},{"bloom_pip","Vezzi","vezzi"},{"foxfire_wick","Kiprik","kiprik"},{"eclipse_orbit","Nolli","nolli"}}
 local function entry(v,name)for _,e in ipairs(v.pieces)do if e.name==name then return e end end;error(name.." missing")end
 local ok,err=pcall(function()
  for _,identity in ipairs(identities)do
   local id,name,rig=table.unpack(identity);local pet=Pets.byId[id]
   assert(pet.name==name and pet.id==id and pet.index>=3,"saved identity/order changed")
   local v=Visual.new(folder,Vector3.new(0,4,0),pet,.72,{charmVisible=false},{native=true});table.insert(views,v)
   v.reducedEffects=true;v:update(0)
   assert(v.backend=="NativeRecipe"and v.definition.id==rig and v.model.PrimaryPart==entry(v,"Body").part)
   assert(v.bodyBoundsSize.Y>1 and v.bodyBoundsSize.Y<1.8,"family silhouette scale "..id)
   assert(entry(v,"EyeL").part.Position.Z>entry(v,"Head").part.Position.Z,"forward face "..id)
   local left,right=entry(v,"FootL"),entry(v,"FootR");assert(left.part.Position.X<right.part.Position.X and left.channel=="FootL"and right.channel=="FootR")
   local faceColors={};for _,e in ipairs(v.pieces)do if e.colorRole~="body"and e.colorRole~="secondary"then faceColors[e]=e.color end end
   local count=#v.pieces;local descendants=#v.model:GetDescendants()
   local a={charmVisible=false,mainDoses=Hue.emptyCounts(),secondaryDoses=Hue.emptyCounts()};a.mainDoses.rose=5;a.secondaryDoses.tide=5;v:applyAppearance(a)
   assert(#v.pieces==count and #v.model:GetDescendants()==descendants,"dose rebuilt geometry")
   for _,e in ipairs(v.pieces)do
    if e.colorRole=="body"then assert(e.color==Hue.ById.rose.color)
    elseif e.colorRole=="secondary"then assert(e.color==Hue.ById.tide.color,"secondary sculpt was mistaken for blush "..e.name)
    else assert(e.color==faceColors[e],"protected pigment changed "..e.name)end
    if e.role=="charm"then assert(e.part.Transparency==1 and not e.part.CanQuery)end
   end
   a.mainDoses=Hue.emptyCounts();v:applyAppearance(a);assert(v.colors.body==Palette.original(id).body and v.colors.secondary==Hue.ById.tide.color)
   table.insert(cases,name.." faithful asset-free silhouette, stable ID and independent saved channels")
   local signatures={}
   for _,expression in ipairs({"neutral","curious","startled","pleased","sleepy","affectionate"})do
    v.expression=expression;v:update(0)
    local eye,hand,mouth=entry(v,"EyeL").part,entry(v,"HandL").part,entry(v,"MouthSmile").part
    local signature=tostring(eye.Size)..tostring(hand.CFrame)..tostring(mouth.Size)..tostring(mouth.Transparency)
    assert(not signatures[signature],expression.." expression collision "..id);signatures[signature]=true
    assert(entry(v,"MouthO").part.Transparency==(if expression=="startled"then 0 else 1))
    local frame=hand.CFrame;v:update(1);assert(frame==hand.CFrame,"reduced pose drift")
   end
   local production=Factory.new(folder,Vector3.new(0,4,0),pet,.72,{charmVisible=false});table.insert(views,production)
   assert(production.definition.id==rig and production.sampledPose and production.model:GetAttribute("RigId")==rig)
   table.insert(cases,name.." six distinct reduced poses and production sampled semantic rig")
  end
 end)
 for _,v in ipairs(views)do v:destroy()end;folder:Destroy();assert(ok,err);return cases
end
