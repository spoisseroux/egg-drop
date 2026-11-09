-- Small original primitive props share a bounded, idempotent lifetime.
local Prop={}
function Prop.new(parent,name,scale)
 scale=if type(scale)=="number"and scale==scale and scale>0 and scale<100 then scale else 1
 local model=Instance.new("Model");model.Name=name
 local h={model=model,parts={},specs={},scale=scale,frame=CFrame.identity}
 function h:add(name,size,frame,color,shape)
  local p=Instance.new(if shape=="wedge"then "WedgePart"else "Part");p.Name=name
  p.Anchored=true;p.CanCollide=false;p.CanTouch=false;p.CanQuery=false;p.CastShadow=false;p.Material=Enum.Material.SmoothPlastic
  p.Color=color;p.Size=size*self.scale
  if shape=="sphere"then local mesh=Instance.new("SpecialMesh");mesh.MeshType=Enum.MeshType.Sphere;mesh.Parent=p end
  local cf=CFrame.new(frame.Position*self.scale)*frame.Rotation
  p.CFrame=self.frame*cf;p.Parent=model
  table.insert(self.parts,p);table.insert(self.specs,{part=p,frame=cf,size=p.Size})
  if not model.PrimaryPart then model.PrimaryPart=p end
  return p
 end
 function h:pivot(frame)
  if self.destroyed then return false end;self.frame=frame
  for _,e in ipairs(self.specs)do e.part.CFrame=frame*e.frame end;return true
 end
 function h:destroy()if self.destroyed then return end;self.destroyed=true;model:Destroy();table.clear(self.parts);table.clear(self.specs)end
 model.Parent=parent;return h
end
return Prop
