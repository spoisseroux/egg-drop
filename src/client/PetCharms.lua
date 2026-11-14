-- Retained forms. One shared torus request; no load callback retains a pet/model.
local Replicated=game:GetService("ReplicatedStorage")
local Catalog=require(Replicated.Shared.PetCharmCatalog)
local Readiness=require(script.Parent.PetAssetReadiness)
local Charms={RingMask="rbxassetid://102662383486040"}
local ringSource,ringSignature,ringTicket
local function source()
 local pack=Replicated:FindFirstChild("PetCharmAssets");local mesh=pack and pack:FindFirstChild("Ring")
 if not mesh or not mesh:IsA("MeshPart")or mesh.MeshId==""or mesh.MeshSize.Magnitude<=0 then return nil end
 return mesh,mesh.MeshId..tostring(mesh.Size)..tostring(mesh:GetAttribute("ArtVersion"))
end
local function requestRing()
 local mesh,signature=source();if not mesh then return nil end
 if mesh~=ringSource or signature~=ringSignature then
  if ringTicket then ringTicket:cancel()end
  ringSource,ringSignature=mesh,signature
  ringTicket=Readiness.shared:request("CareHaloRing",mesh,signature,{mesh},2,function()end)
 end
 Readiness.shared:step()
 return if Readiness.shared:ready("CareHaloRing",mesh,signature)then mesh else nil
end
-- Authored charm meshes (slice D: Heart, Star) live beside the Bear's own charm mesh in
-- PetAssets.Bear, at the same place and facing as the default charm, so one is drawn at the
-- default charm's frame. Nil when the place does not have the mesh.
local function authored(shape)
 local entry=Catalog.ById[shape];local name=entry and entry.mesh
 if not name then return nil end
 local assets=Replicated:FindFirstChild("PetAssets");local bear=assets and assets:FindFirstChild("Bear")
 local mesh=bear and bear:FindFirstChild(name)
 if not mesh or not mesh:IsA("MeshPart")or mesh.MeshId==""or mesh.MeshSize.Magnitude<=0 then return nil end
 return mesh
end
Charms.authored=authored
local function add(visual,shape,index,part,offset,size,rotation,backend)
 local dot
 for _,entry in ipairs(visual.pieces)do if entry.role=="charm"and(entry.charmShape or "dot")=="dot"then entry.charmShape="dot";dot=entry;break end end
 if not dot then part:Destroy();return end
 local scale=visual.scale or 1
 part.Name="Charm_"..shape..index;part.Anchored=true;part.CanCollide=false;part.CanTouch=false;part.CanQuery=false;part.CastShadow=backend~="mask"
 part.Material=Enum.Material.SmoothPlastic;part.Color=visual.secondaryColor;part.Size=size*scale;part.Transparency=1;part.Parent=visual.model
 local frame=dot.frame*(if shape=="pebble"then CFrame.Angles(math.rad(12),0,0)else CFrame.identity)*CFrame.new(offset*scale)*(rotation or CFrame.identity)
 local entry={part=part,name=part.Name,channel="Charm",role="charm",charmShape=shape,charmBackend=backend,colorRole="secondary",color=part.Color,faceBaseColor=part.Color,faceBaseMaterial=part.Material,frame=frame,size=part.Size}
 if backend=="mask"then
  entry.baseTransparency=1;entry.decals={}
  for _,face in ipairs({Enum.NormalId.Top,Enum.NormalId.Bottom})do
   local decal=Instance.new("Decal");decal.Name="ContinuousRing";decal.Face=face;decal.Texture=Charms.RingMask;decal.Color3=visual.secondaryColor;decal.Transparency=1;decal.Parent=part;table.insert(entry.decals,decal)
  end
 end
 table.insert(visual.pieces,entry);return entry
end
local function prepare(visual,shape)
 visual.charmFormsPrepared=visual.charmFormsPrepared or {dot=true}
 if visual.charmFormsPrepared[shape]then return end;visual.charmFormsPrepared[shape]=true
 if shape=="ring"then
  add(visual,"ring","Mask",Instance.new("Part"),Vector3.zero,Vector3.new(.259,.004,.259),nil,"mask")
  requestRing()
 elseif Catalog.ById[shape]and Catalog.ById[shape].mesh then
  -- Heart / Star: the authored mesh, tinted with the secondary colour like every charm.
  local mesh=authored(shape)
  if mesh then add(visual,shape,"Mesh",mesh:Clone(),Vector3.zero,mesh.Size,nil,"authored")end
 else
  for i,spec in ipairs({{Vector3.new(-.025,-.015,0),Vector3.new(.205,.155,.15),.12},{Vector3.new(.057,.014,-.006),Vector3.new(.130,.125,.137),-.32}})do
   local part=Instance.new("Part");local mesh=Instance.new("SpecialMesh");mesh.MeshType=Enum.MeshType.Sphere;mesh.Parent=part
   add(visual,"pebble",i,part,spec[1],spec[2],CFrame.Angles(0,0,spec[3]))
  end
 end
end
function Charms.step(visual)
 if visual.destroyed or visual.renderCharmShape~="ring"or visual.charmRingBound then return end
 local mesh=requestRing();if not mesh then return end
 -- Commit on the visual's own update; callbacks never retain a visual.
 if add(visual,"ring","Mesh",mesh:Clone(),Vector3.zero,Vector3.new(.259,.259,.049),CFrame.Angles(math.pi/2,0,0),"mesh")then visual.charmRingBound=true;visual.poseDirty=true end
end
function Charms.apply(visual,appearance)
 -- Pets start with no charm: only an explicit choice shows it.
 visual.charmVisible=type(appearance)=="table"and appearance.charmVisible==true
 visual.charmShape=if type(appearance)=="table"and Catalog.validStored(appearance.charmShape)then appearance.charmShape else Catalog.Default
 visual.renderCharmShape=Catalog.renderShape(visual.charmShape)
 -- An earned shape whose mesh is not in this place shows the default charm, never nothing.
 if Catalog.ById[visual.renderCharmShape].mesh and not authored(visual.renderCharmShape)then visual.renderCharmShape=Catalog.Default end
 prepare(visual,visual.renderCharmShape)
 visual.model:SetAttribute("CharmVisible",visual.charmVisible);visual.model:SetAttribute("CharmShape",visual.charmShape)
 for _,entry in ipairs(visual.pieces)do if entry.role=="charm"then
  local hidden=not Charms.isVisible(visual,entry);entry.part.Transparency=if hidden then 1 else entry.baseTransparency or 0;Charms.paintVisibility(entry,hidden,visual.secondaryColor)
 end end
 visual.poseDirty=true
end
function Charms.isVisible(visual,entry)
 if entry.role~="charm"then return true end
 if visual.charmVisible==false or(entry.charmShape or "dot")~=(visual.renderCharmShape or "dot")then return false end
 if entry.charmBackend=="mask"then return not visual.charmRingBound end
 if entry.charmBackend=="mesh"then return visual.charmRingBound==true end
 return true
end
function Charms.paintVisibility(entry,hidden,color)
 if not entry.decals then return end
 for _,decal in ipairs(entry.decals)do
  local alpha=if hidden then 1 else 0
  if decal.Transparency~=alpha then decal.Transparency=alpha end
  if decal.Color3~=color then decal.Color3=color end
 end
end
function Charms.pose(visual,frame,size,x,y,stretch,entry)
 local rotation=frame.Rotation*(if entry then entry.frame.Rotation:Inverse()else CFrame.identity)
 local offset=rotation*Vector3.new(x*(visual.scale or 1),y*(visual.scale or 1),0)
 local width=1/math.sqrt(stretch)
 if entry and(entry.charmShape or "dot")~="dot"then return frame+offset,size end
 return frame+offset,Vector3.new(size.X*width,size.Y*stretch,size.Z*width)
end
return Charms
