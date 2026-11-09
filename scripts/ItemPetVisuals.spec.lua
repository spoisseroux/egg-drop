-- All seven existing silhouettes retain their face/sculpt identity through two channels.
return function(client)
 local readyFixture=assert(script.Parent:FindFirstChild("PetAssetsReadyFixture"),"Install the real authored-readiness QA helper beside this spec")
 require(readyFixture)(client)
 local Factory=require(client.PetFactory);local H=require(game.ReplicatedStorage.Shared.HueCatalog);local Pets=require(game.ReplicatedStorage.Shared.PetCatalog);local P=require(game.ReplicatedStorage.Shared.PetPalette)
 local cases={};local active={};local folder=Instance.new("Folder");folder.Name="_ItemPetVisuals";folder.Parent=workspace
 local ok,err=pcall(function()
  for _,pet in ipairs(Pets.collection)do
   local a={mainDoses=H.emptyCounts(),secondaryDoses=H.emptyCounts(),charmVisible=true}
   local v=Factory.new(folder,Vector3.new(0,4,0),pet,.72,a);table.insert(active,v);v.reducedEffects=true;v:update(0)
   local identity={};local count=#v.pieces
   for _,e in ipairs(v.pieces)do if not e.colorRole then identity[e.part]={name=e.part.Name,color=e.part.Color}end end
   a.mainDoses.rose=5;a.secondaryDoses.tide=5;v:applyAppearance(a);v:update(0)
   assert(#v.pieces==count and v.petId==pet.id and v.model.PrimaryPart,"geometry/identity changed "..pet.id)
   local body,secondary=0,0
   for _,e in ipairs(v.pieces)do
    if e.colorRole=="body"then body+=1;assert((e.color or e.part.Color)==H.ById.rose.color,"main dose missing "..pet.id.." "..e.part.Name)
    elseif e.colorRole=="secondary"then secondary+=1;assert((e.color or e.part.Color)==H.ById.tide.color,"secondary dose missing "..pet.id.." "..e.part.Name)end
   end
   assert(body>0 and secondary>0,"missing mapped role "..pet.id)
   for part,saved in pairs(identity)do assert(part.Parent==v.model and part.Name==saved.name and part.Color==saved.color,"face/sculpt identity changed "..pet.id.." "..saved.name)end
   local oldSecondary=P.resolve(pet.id,a).secondary;a.mainDoses=H.emptyCounts();v:applyAppearance(a);v:update(0)
   assert(P.resolve(pet.id,a).body==P.original(pet.id).body and P.resolve(pet.id,a).secondary==oldSecondary,"independent channel reset")
   a.charmVisible=false;v:applyAppearance(a);v:update(0);for _,e in ipairs(v.pieces)do if e.role=="charm"then assert(e.part.Transparency==1)end end
   assert(#v.model:GetDescendants()>0 and not v.model:FindFirstChildWhichIsA("PointLight",true),"per-pet lights")
   table.insert(cases,pet.id.." two mapped channels protected face/sculpt and independent reset/charm")
  end
 end)
 for _,v in ipairs(active)do v:destroy()end;folder:Destroy();assert(ok,err);return cases
end
