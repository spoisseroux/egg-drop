-- Lifecycle/opacity ownership only; native GPU appearance is a separate gate.
return function(client,parent)
 local Materials=require(client.PetMaterials)
 local source=assert(game.ReplicatedStorage:FindFirstChild("PetMaterials"))
 local twoSource=assert(game.ReplicatedStorage:FindFirstChild("PetMaterialsTwoTone"))
 local folder=Instance.new("Folder");folder.Name="_JellyMaterials";folder.Parent=parent or workspace
 local pack,two=source:Clone(),twoSource:Clone();pack.Parent=folder;two.Parent=folder
 local function candidate(from,name,destination)
  assert(destination~=from,"candidate replacement must only edit a disposable cloned pack")
  for _,child in ipairs(destination:GetChildren())do
   if child.Name==name or child:GetAttribute("MaterialProfile")==name then child:Destroy()end
  end
  local p=assert(Materials.template(from,if name=="BodyJelly"then "BodyGloss"else "BodyTwoToneGloss")):Clone()
  p.Name=name;p:SetAttribute("MaterialProfile",name);p:SetAttribute("NativeVerified",true);p.Parent=destination;return p
 end
 local main=candidate(source,"BodyJelly",pack);local gradient=candidate(twoSource,"BodyTwoToneJelly",two)
 local owner=Materials.new({templates=pack,twoToneTemplates=two})
 local cases={};local function test(name,run)run();table.insert(cases,name)end
 local function make(name,role,colorRole)
  local model=Instance.new("Model");model.Parent=folder
  local part=Instance.new("MeshPart");part.Name=name;part.Anchored=true;part.Parent=model
  local e={part=part,name=name,role=role,colorRole=colorRole or"body",color=Color3.fromRGB(211,55,118),faceBaseMaterial=Enum.Material.SmoothPlastic}
  local v={model=model,appearance={finish="jelly"},definition={pieces={{name=name}}},twoTone=true,secondaryColor=Color3.fromRGB(30,100,220),materialsEnabled=true}
  return e,v
 end
 local ok,problem=pcall(function()
 test("verified pair preserves Overlay pigment and exact body head ear secondary alpha",function()
  for name,alpha in pairs({Body=.15,Head=.08,HandL=.15,FootR=.15,EarL=.12,Tail=.12,Muzzle=.08,EarInnerR=.08})do
   local e,v=make(name,nil,if name=="Muzzle"or name=="EarInnerR"then"secondary"else"body")
   assert(owner:paint(e,v,1));assert(math.abs(Materials.transparency(e,v,false)-alpha)<1e-8,name)
   if e.colorRole=="body"then assert(e.materialProfile=="BodyTwoToneJelly"and e.materialSurface.Color==v.secondaryColor and e.materialSurface.AlphaMode==Enum.AlphaMode.Overlay)end
  end
 end)
 test("faces accessories features charms and unknown core pieces remain opaque",function()
  for _,args in ipairs({{"Body","attachment","body"},{"Head","feature","body"},{"CharmDot","charm","secondary"},{"UnknownCore",nil,"body"},{"MouthSmile",nil,"mouth"},{"EyeL",nil,"face"}})do
   local e,v=make(args[1],args[2],args[3]);owner:paint(e,v,0)
   assert(Materials.transparency(e,v,false)==0,args[1].." ghosted")
   assert(Materials.transparency(e,v,true)==1,"hidden expression/attachment was unhidden")
  end
 end)
 test("missing or unverified paired profile falls back opaque and recovers once",function()
  local e,v=make("Body");gradient:SetAttribute("NativeVerified",false)
  local matches=0;for _,child in ipairs(two:GetChildren())do if child.Name=="BodyTwoToneJelly"or child:GetAttribute("MaterialProfile")=="BodyTwoToneJelly"then matches+=1;assert(child:GetAttribute("NativeVerified")==false)end end
  assert(matches==1,"fixture must not leave a second verified Jelly candidate")
  assert(owner:paint(e,v,0)and e.materialProfile=="BodyTwoTone"and Materials.transparency(e,v,false)==0)
  gradient:SetAttribute("NativeVerified",true);assert(owner:paint(e,v,0)and e.materialProfile=="BodyTwoToneJelly")
  local surface=e.materialSurface
  for _=1,30 do assert(owner:paint(e,v,0)and e.materialSurface==surface)end
  v.materialsEnabled=false;assert(not owner:paint(e,v,0)and Materials.transparency(e,v,false)==0)
 end)
 test("detached or failed material binding cannot leave a translucent body",function()
  local e,v=make("Body");assert(owner:paintSafely(e,v,1)and Materials.transparency(e,v,false)>.1)
  local surface=e.materialSurface;surface.Parent=nil
  assert(Materials.transparency(e,v,false)==0,"detached SurfaceAppearance granted Jelly alpha")
  surface:Destroy();e.materialSurface=nil
  assert(Materials.transparency(e,v,false)==0,"stale profile without a surface granted alpha")
  -- Force a real native property-write failure after a valid Jelly bind.
  assert(owner:paintSafely(e,v,1));e.color="invalid Color3"
  assert(not owner:paintSafely(e,v,1)and e.materialFailure and e.materialSurface==nil and e.materialProfile==nil)
  assert(Materials.transparency(e,v,false)==0,"failed material retained alpha")
  e.materialProfile="BodyTwoToneJelly";e.materialsEnabled=false;v.materialsEnabled=false
  assert(not owner:paintSafely(e,v,1)and e.materialProfile==nil,"release kept stale profile when surface already nil")
 end)
 test("authored opacity composes once and Standard restore leaves Hue untouched",function()
  local e,v=make("Body");e.baseTransparency=.4;assert(owner:paint(e,v,1))
  assert(math.abs(Materials.transparency(e,v,false)-.49)<1e-8 and e.baseTransparency==.4)
  local colors=e.color;local secondary=v.secondaryColor;v.appearance.finish="standard"
  assert(owner:paint(e,v,1)and e.materialProfile=="BodyTwoTone"and Materials.transparency(e,v,false)==.4)
  assert(e.color==colors and v.secondaryColor==secondary and e.materialSurface.Color==secondary)
 end)
 end)
 folder:Destroy();assert(ok,problem);return{passed=#cases,cases=cases,gpuAppearanceClaim=false}
end
