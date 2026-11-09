-- Astra-approved shaded-head production material; old Neon remains a fixture comparison.
-- No Lighting, saved colors, or authored geometry mutation.
return function(client)
 local Visual=require(client.GardenPetVisual);local Face=require(client.PetFace)
 local Pets=require(game.ReplicatedStorage.Shared.PetCatalog);local Palette=require(game.ReplicatedStorage.Shared.PetPalette)
 local folder=Instance.new("Folder");folder.Name="_PetNightStudy";folder.Parent=workspace
 local cases={};local function near(a,b)return math.max(math.abs(a.R-b.R),math.abs(a.G-b.G),math.abs(a.B-b.B))<1/255+.000001 end
 local ok,problem=pcall(function()
  for _,id in ipairs({"pip","puddle"})do
   local v=Visual.new(folder,Vector3.new(2000,4.025,0),Pets.byId[id],.72,nil,{native=true})
   assert(v.nightTreatment=="shadedHead","approved default must use the shaded head")
   local head,body,protected
   for _,entry in ipairs(v.pieces)do
    if entry.name=="Head"then head=entry elseif entry.name=="Body"then body=entry elseif entry.name=="EyeL"then protected=entry end
   end
   local protectedColor,frame,size=protected.part.Color,head.part.CFrame,head.part.Size
   for _,appearance in ipairs({{body="original",bodyRank=0},{body="rose",bodyRank=3,secondary="tide"},{body="rose",bodyRank=2,bodyMix="rose:tide"}})do
    v:applyAppearance(appearance)
    local palette=Palette.resolve(id,appearance)
    Face.paintSurface(head,v,0);Face.paintSurface(body,v,0)
    local lift=head.nightHeadLift
    assert(lift and lift.Parent==v.model and lift.Adornee==head.part and lift.Enabled)
    assert(lift.DepthMode==Enum.HighlightDepthMode.Occluded and math.abs(lift.FillTransparency-.70)<.000001 and lift.OutlineTransparency==1)
    assert(near(lift.FillColor,palette.body)and near(head.part.Color,palette.body)and head.part.Material==Enum.Material.SmoothPlastic)
    assert(body.part.Material==Enum.Material.Neon and not body.nightHeadLift)
    assert(protected.part.Color==protectedColor and head.part.CFrame==frame and head.part.Size==size)
    Face.paintSurface(head,v,.29);assert(lift.Enabled,"night material hysteresis must be shared")
    Face.paintSurface(head,v,1);assert(not lift.Enabled and head.part.Material==Enum.Material.SmoothPlastic and near(head.part.Color,palette.body))
   end
   v.nightTreatment="selectiveNeon";Face.paintSurface(head,v,0)
   assert(head.part.Material==Enum.Material.Neon and not head.nightHeadLift.Enabled)
   assert(not v.model:FindFirstChildWhichIsA("Light",true))
   local model=v.model;v:destroy();assert(model.Parent==nil)
   table.insert(cases,id.." shaded candidate owns one head lift and preserves neutral vivid mixed day/night geometry")
  end
 end)
 folder:Destroy();assert(ok,problem);return{passed=#cases,cases=cases}
end
