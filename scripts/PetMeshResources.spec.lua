-- Healthy source resource bounds and a nonempty-but-wrong-resource regression.
return function(client)
 local assets=game.ReplicatedStorage:FindFirstChild("PetAssets");assert(assets)
 local Visual=require(client.GardenPetVisual);local Pets=require(game.ReplicatedStorage.Shared.PetCatalog);local cases={}
 for _,name in ipairs({"Tikket","Nuum","Vezzi","Kiprik","Nolli"})do
  local model=assets:FindFirstChild(name);assert(model,"missing template "..name)
  for _,part in ipairs(model:GetDescendants())do if part:IsA("MeshPart")then
   local expected=part.Size*100
   assert(part.MeshId~=""and(part.MeshSize-expected).Magnitude<math.max(.001,expected.Magnitude*.00001),"resource bounds scaled with physical Size "..part.Name)
  end end
 end
 table.insert(cases,"all five source templates retain100x resource bounds with garden-size physical parts")
 local source=assets.Tikket;local original=source:FindFirstChild("Tikket__Body");assert(original)
 local wrong=assets.Zivvi:FindFirstChild("Zivvi__Body"):Clone();wrong.Name=original.Name;wrong.CFrame=original.CFrame;wrong.Size=original.Size
 local folder=Instance.new("Folder");folder.Name="_WrongResourceBound";folder.Parent=workspace;original.Parent=folder;wrong.Parent=source
 local v;local ok,err=pcall(function()
  assert(wrong.MeshSize.Magnitude>0 and wrong.MeshId~="")
  v=Visual.new(folder,Vector3.new(0,4,0),Pets.byId.wick,.72,{charmVisible=false})
  assert(v.backend=="NativeRecipe","wrong nonzero mesh bounds rendered as authored template")
 end)
 if v then v:destroy()end;wrong:Destroy();original.Parent=source;folder:Destroy();assert(ok,err)
 table.insert(cases,"wrong nonzero resource bounds reject the whole imported backend before cloning")
 return cases
end
