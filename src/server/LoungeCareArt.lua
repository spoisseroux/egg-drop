local Data=require(game:GetService("ReplicatedStorage").Shared.GardenCareArtData)
return function(room)
 local model=Instance.new("Model");model.Name="CareMachine";model.Parent=room
 local origin=Vector3.new(table.unpack(Data.station.sole))
 for _,entry in ipairs(Data.parts)do
  local part=Instance.new("Part");part.Name=entry.name;part.Anchored=true;part.CanCollide=entry.canCollide==true;part.CanQuery=entry.canQuery==true;part.CanTouch=false
  part.Size=Vector3.new(table.unpack(entry.size));local r=entry.rotation or {0,0,0}
  part.CFrame=CFrame.new(origin+Vector3.new(table.unpack(entry.center)))*CFrame.Angles(math.rad(r[1]),math.rad(r[2]),math.rad(r[3]))
  if entry.shape=="ellipsoid"then local mesh=Instance.new("SpecialMesh");mesh.MeshType=Enum.MeshType.Sphere;mesh.Parent=part
  elseif entry.shape=="cylinderY"then
   local mesh=Instance.new("CylinderMesh");mesh.Parent=part
  end
  part.Color=Color3.fromHex(entry.color);part.Material=Enum.Material[entry.material or "SmoothPlastic"]
  part.Transparency=entry.transparency or 0;part.Reflectance=entry.reflectance or Data.render.defaultReflectance;part.CastShadow=entry.castShadow~=false
  part:SetAttribute("CareRestColor",entry.color);part:SetAttribute("CareOccupiedColor",entry.occupiedColor);part.Parent=model
 end
 return model
end
