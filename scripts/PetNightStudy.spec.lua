-- Current grouped role fill regression. Historical screenshots remain controls.
return function(client)
 local Visual=require(client.GardenPetVisual);local Face=require(client.PetFace)
 local Pets=require(game.ReplicatedStorage.Shared.PetCatalog);local Palette=require(game.ReplicatedStorage.Shared.PetPalette)
 local folder=Instance.new("Folder");folder.Name="_PetNightStudy";folder.Parent=workspace
 local cases={};local active={};local function near(a,b)return math.max(math.abs(a.R-b.R),math.abs(a.G-b.G),math.abs(a.B-b.B))<.005 end
 local ok,problem=pcall(function()
  for _,id in ipairs({"pip","puddle"})do
   local v=Visual.new(folder,Vector3.new(2000,4.025,0),Pets.byId[id],.72,nil,{native=true});table.insert(active,v)
   local head,body,eye
   for _,e in ipairs(v.pieces)do if e.name=="Head"then head=e elseif e.name=="Body"then body=e elseif e.name=="EyeL"then eye=e end end
   local protected,frame,size=eye.part.Color,head.part.CFrame,head.part.Size
   for _,appearance in ipairs({{body="original",bodyRank=0},{body="rose",bodyRank=3,secondary="tide"},{body="rose",bodyRank=2,bodyMix="rose:tide"}})do
    v:applyAppearance(appearance);local palette=Palette.resolve(id,appearance);Face.paintSurface(head,v,0);Face.paintSurface(body,v,0)
    assert(v.nightGroups and v.nightGroups.body.fill.Enabled and v.nightGroups.secondary.fill.Enabled)
    assert(near(v.nightGroups.body.fill.FillColor,palette.body)and near(v.nightGroups.secondary.fill.FillColor,palette.secondary))
    assert(head.part.Material==Enum.Material.SmoothPlastic and body.part.Material==Enum.Material.SmoothPlastic and not head.nightHeadLift)
    assert(eye.part.Parent==v.model and eye.part.Color==protected and head.part.CFrame==frame and head.part.Size==size)
    Face.paintSurface(head,v,.30);assert(v.nightGroups.body.fill.Enabled)
    Face.paintSurface(head,v,1);assert(not v.nightGroups.body.fill.Enabled and near(head.part.Color,palette.body))
   end
   local preview=Visual.new(folder,Vector3.zero,Pets.byId[id],nil,nil,{native=true});table.insert(active,preview)
   for _,entry in ipairs(preview.pieces)do Face.paintSurface(entry,preview,0)end
   assert(not preview.nightGroups and not preview.model:FindFirstChildWhichIsA("Highlight",true),"viewport uses independent lighting")
   assert(not v.model:FindFirstChildWhichIsA("Light",true))
   table.insert(cases,id.." grouped colored fills preserve shaded geometry/face and bypass viewport")
  end
 end)
 for _,v in ipairs(active)do v:destroy()end;folder:Destroy();assert(ok,problem);return{passed=#cases,cases=cases}
end
