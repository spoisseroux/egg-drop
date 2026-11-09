-- Edit-only authoring helper. Root supplies actual uploaded owned image IDs.
-- Produces an unmounted pack for export; no mesh, camera, profile or runtime writes.
return function(parent, ids)
 local Run=game:GetService("RunService")
 assert(not Run:IsRunning(),"Pet material authoring is Edit-only")
 assert(typeof(parent)=="Instance" and type(ids)=="table","Explicit destination and uploaded IDs required")
 assert(not parent:FindFirstChild("PetMaterials"),"Existing PetMaterials must be reviewed explicitly; refusing replacement")
 local function uri(key)
  local value=ids[key]
  if type(value)=="number" then
   assert(value>0 and value%1==0 and value<=9007199254740991,"Invalid uploaded ID: "..key)
   value=string.format("%.0f",value)
  end
  assert(type(value)=="string","Missing uploaded ID: "..key)
  local id=string.match(value,"^([1-9]%d*)$") or string.match(value,"^rbxassetid://([1-9]%d*)$")
  assert(id,"Invalid uploaded ID: "..key)
  return "rbxassetid://"..id
 end
 local maps={white=uri("white"),metalness=uri("metalness"),bodyRoughness=uri("bodyRoughness"),eyeRoughness=uri("eyeRoughness")}
 local pack=Instance.new("Folder");pack.Name="PetMaterials";pack:SetAttribute("MaterialVersion",1)
 local ok,problem=pcall(function()
  for _,profile in ipairs({"Body","Eye","Charm","Catchlight"})do
   local surface=Instance.new("SurfaceAppearance");surface.Name=profile;surface.Parent=pack
   surface:SetAttribute("MaterialProfile",profile);surface:SetAttribute("MaterialVersion",1)
   surface.ColorMap=maps.white
   surface.MetalnessMap=maps.metalness
   surface.RoughnessMap=if profile=="Eye" or profile=="Catchlight" then maps.eyeRoughness else maps.bodyRoughness
   surface.EmissiveMaskContent=Content.fromUri(maps.white)
   -- Opaque-white pixels under stable Overlay avoid depending on beta Opaque mode.
   surface.AlphaMode=Enum.AlphaMode.Overlay
   surface.Color=Color3.new(1,1,1);surface.EmissiveTint=Color3.new(1,1,1)
   -- Runtime role owner applies calibrated day/night strengths after cloning.
   surface.EmissiveStrength=0
  end
  pack.Parent=parent
 end)
 if not ok then pack:Destroy();error(problem)end
 return pack,{version=1,profiles=4,maps=maps}
end
