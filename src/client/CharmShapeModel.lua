-- A charm shape on its own (2026-11-16): the Snowflake, Ring, Pebble, Heart, Star or Leaf the
-- pet wears, as a small Model for the rare-charm reveal (inside the capsule) and the Customize
-- charm cards. Uses the same meshes as PetCharms: PetAssets.Bear.Bear__Charm<Name> and
-- PetCharmAssets.Ring; the Pebble is PetCharms' two soft spheres. Nil when a mesh is missing.
local Replicated=game:GetService("ReplicatedStorage")
local Catalog=require(Replicated.Shared.PetCharmCatalog)
local Shape={}
local meshNames={dot="Bear__CharmDot",heart="Bear__CharmHeart",star="Bear__CharmStar",leaf="Bear__CharmLeaf"}
local function ready(part)return part~=nil and part:IsA("MeshPart")and part.MeshId~=""end
local function finish(part,color)
 part.Anchored=true;part.CanCollide=false;part.CanTouch=false;part.CanQuery=false;part.CastShadow=false
 part.Material=Enum.Material.SmoothPlastic;part.Color=color;part.Transparency=0
 for _,child in ipairs(part:GetChildren())do if child:IsA("SurfaceAppearance")or child:IsA("Decal")then child:Destroy()end end
 return part
end
function Shape.build(shape,color)
 if not Catalog.known(shape)then return nil end
 color=color or Color3.fromHex("#FFCB3D")
 local model=Instance.new("Model");model.Name="CharmShape_"..shape;model:SetAttribute("CharmShape",shape)
 if shape=="ring"then
  local pack=Replicated:FindFirstChild("PetCharmAssets");local source=pack and pack:FindFirstChild("Ring")
  if not ready(source)then model:Destroy();return nil end
  local part=finish(source:Clone(),color);part.Name="Ring";part.CFrame=CFrame.identity;part.Parent=model
 elseif shape=="pebble"then
  -- PetCharms' Pebble: two soft spheres, the second a little up and to the side.
  for i,spec in ipairs({{Vector3.new(-.025,-.015,0),Vector3.new(.205,.155,.15),.12},{Vector3.new(.057,.014,-.006),Vector3.new(.130,.125,.137),-.32}})do
   local part=Instance.new("Part");local mesh=Instance.new("SpecialMesh");mesh.MeshType=Enum.MeshType.Sphere;mesh.Parent=part
   finish(part,color);part.Name="Pebble"..i;part.Size=spec[2];part.CFrame=CFrame.new(spec[1])*CFrame.Angles(0,0,spec[3]);part.Parent=model
  end
 else
  local assets=Replicated:FindFirstChild("PetAssets");local bear=assets and assets:FindFirstChild("Bear")
  local source=bear and meshNames[shape]and bear:FindFirstChild(meshNames[shape])
  if not ready(source)then model:Destroy();return nil end
  local part=finish(source:Clone(),color);part.Name=shape;part.CFrame=CFrame.identity;part.Parent=model
 end
 return model
end
-- Fits `model` into a box of `extent` studs (largest side) centred on `frame`.
function Shape.fit(model,frame,extent)
 local cf,size=model:GetBoundingBox()
 local scale=extent/math.max(size.X,size.Y,size.Z,1e-4)
 for _,part in ipairs(model:GetDescendants())do
  if part:IsA("BasePart")then
   local rel=cf:ToObjectSpace(part.CFrame)
   part.Size*=scale;part.CFrame=frame*CFrame.new(rel.Position*scale)*rel.Rotation
  end
 end
 return model
end
return Shape
