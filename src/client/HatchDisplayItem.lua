-- Typed actual payload renderers. No ownership/receipt mutation or pet stand-in.
local Item={}
local function sphere(part)
 local mesh=part:FindFirstChildOfClass("SpecialMesh")
 return mesh and mesh.MeshType==Enum.MeshType.Sphere
end
function Item.lowest(part)
 local cf,half=part.CFrame,part.Size*.5
 if sphere(part)then
  local r,u,l=cf.RightVector,cf.UpVector,cf.LookVector
  local radius=math.sqrt((r.Y*half.X)^2+(u.Y*half.Y)^2+(l.Y*half.Z)^2)
  return cf.Position-(r*(half.X*half.X*r.Y)+u*(half.Y*half.Y*u.Y)+l*(half.Z*half.Z*l.Y))/math.max(1e-8,radius)
 end
 local low
 for x=-1,1,2 do for y=-1,1,2 do for z=-1,1,2 do
  local p=cf:PointToWorldSpace(half*Vector3.new(x,y,z));if not low or p.Y<low.Y then low=p end
 end end end
 return low
end
function Item.surfacePoints(part,padding)
 local points={};local half=part.Size*.5+Vector3.one*(padding or 0)
 if sphere(part)then
  for j=0,8 do local a=math.pi*j/8
   for k=0,15 do local b=math.pi*2*k/16
    table.insert(points,part.CFrame:PointToWorldSpace(half*Vector3.new(math.sin(a)*math.cos(b),math.cos(a),math.sin(a)*math.sin(b))))
   end
  end
 else
  for x=-1,1,2 do for y=-1,1,2 do for z=-1,1,2 do table.insert(points,part.CFrame:PointToWorldSpace(half*Vector3.new(x,y,z)))end end end
 end
 return points
end
function Item.create(world,gui,result,builder,height)
 local api,id
 if result.toyId then api=require(script.Parent.PetToyGeometry);id=result.toyId
 elseif result.featureId then api=require(script.Parent.PetFeatureGeometry);id=result.featureId end
 if api then
  local handle=if result.toyId then api.create(world,id,1)else api.create(world,id,1,1,Color3.fromHex("#95CDB9"))
  if handle then
   local _,size=handle.model:GetBoundingBox();local scale=height*1.45/math.max(.01,size.X,size.Y)
   local entries={}
   for _,part in ipairs(handle.model:GetDescendants())do if part:IsA("BasePart")then
    table.insert(entries,{part=part,frame=part.CFrame,size=part.Size})
   end end
   local self={model=handle.model,handle=handle,entries=entries,scale=scale,mode="Object3D"}
   function self:pose(sample)
    local rotation=CFrame.Angles(sample.toyTilt, sample.toyYaw, sample.toyTilt*.45)
    local factor=self.scale*sample.heroScale;local lowest
    for _,entry in ipairs(self.entries)do
     local p=entry.part;p.Size=entry.size*factor;p.CFrame=rotation*CFrame.new(entry.frame.Position*factor)*entry.frame.Rotation
     local point=Item.lowest(p);if not lowest or point.Y<lowest.Y then lowest=point end
    end
    local offset=Vector3.new(0,.0021-lowest.Y+(sample.hop or 0)*height,(sample.forward or 0)*height)
    for _,entry in ipairs(self.entries)do entry.part.CFrame+=offset end
    self.minimum=.0021+(sample.hop or 0)*height;self.contact=lowest+offset
   end
   function self:destroy()self.handle:destroy()end
   return self
  end
 end
 -- Hue keeps its actual flat native fruit art. Finish/unknown payloads use
 -- their existing host's actual renderer, never a fabricated awarded pet.
 local graphic=if builder then builder(gui,result,UDim2.fromScale(.15,.12),UDim2.fromScale(.7,.76),gui.ZIndex+1)else nil
 local scale=Instance.new("UIScale");scale.Parent=gui
 local self={graphic=graphic,scale=scale,mode="NativeItemArt"}
 function self:pose(sample)
  self.scale.Scale=sample.heroScale
  gui.Rotation=if result.itemId then math.deg(sample.toyYaw)*15/18 else 0
 end
 function self:destroy()if self.graphic then self.graphic:Destroy();self.graphic=nil end end
 return self
end
return Item
