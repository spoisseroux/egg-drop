-- Retained free Secondary-colored forms. Only the selected visible form enters any hull.
local Catalog=require(game:GetService("ReplicatedStorage").Shared.PetCharmCatalog)
local Charms={}
local function prepare(visual,shape)
 visual.charmFormsPrepared=visual.charmFormsPrepared or {dot=true}
 if visual.charmFormsPrepared[shape]then return end;visual.charmFormsPrepared[shape]=true
 local dot
 for _,entry in ipairs(visual.pieces)do if entry.role=="charm"and(entry.charmShape==nil or entry.charmShape=="dot")then entry.charmShape="dot";dot=dot or entry end end
 if not dot then return end
 local scale=visual.scale or 1;local anchor=dot.frame;local tilt=CFrame.Angles(math.rad(12),0,0)
 local function add(shape,index,offset,size,rotation)
  local part=Instance.new("Part");part.Name="Charm_"..shape..index;part.Anchored=true;part.CanCollide=false;part.CanTouch=false;part.CanQuery=false;part.CastShadow=true
  part.Material=Enum.Material.SmoothPlastic;part.Color=visual.secondaryColor;part.Size=size*scale;part.Transparency=1;part.Parent=visual.model
  local mesh=Instance.new("SpecialMesh");mesh.MeshType=Enum.MeshType.Sphere;mesh.Parent=part
  local frame=anchor*tilt*CFrame.new(offset*scale)*(rotation or CFrame.identity)
  table.insert(visual.pieces,{part=part,name=part.Name,channel="Charm",role="charm",charmShape=shape,colorRole="secondary",color=part.Color,faceBaseColor=part.Color,faceBaseMaterial=part.Material,frame=frame,size=part.Size})
 end
 -- Eight rounded tangential segments leave a real open center from front and three-quarter.
 if shape=="ring"then for i=1,8 do local angle=(i-1)*math.pi/4
  add("ring",i,Vector3.new(math.cos(angle)*.105,math.sin(angle)*.073,0),Vector3.new(.105,.050,.052),CFrame.Angles(0,0,angle+math.pi*.5))
 end else
 add("pebble",1,Vector3.new(-.025,-.015,0),Vector3.new(.205,.155,.15),CFrame.Angles(0,0,.12))
 add("pebble",2,Vector3.new(.057,.014,-.006),Vector3.new(.130,.125,.137),CFrame.Angles(0,0,-.32))
 end
end
function Charms.apply(visual,appearance)
 visual.charmVisible=type(appearance)~="table"or appearance.charmVisible~=false
 visual.charmShape=if type(appearance)=="table"and Catalog.validStored(appearance.charmShape)then appearance.charmShape else Catalog.Default
 visual.renderCharmShape=Catalog.renderShape(visual.charmShape)
 prepare(visual,visual.renderCharmShape)
 visual.model:SetAttribute("CharmVisible",visual.charmVisible);visual.model:SetAttribute("CharmShape",visual.charmShape)
 for _,entry in ipairs(visual.pieces)do if entry.role=="charm"then entry.part.Transparency=if Charms.isVisible(visual,entry)then 0 else 1 end end
 visual.poseDirty=true
end
function Charms.isVisible(visual,entry)return entry.role~="charm"or(visual.charmVisible~=false and(entry.charmShape or "dot")==(visual.renderCharmShape or "dot"))end
function Charms.pose(visual,frame,size,x,y,stretch,entry)
 -- Bob in the head attachment axes, so differently rotated arc segments stay together.
 local rotation=frame.Rotation*(if entry then entry.frame.Rotation:Inverse()else CFrame.identity)
 local offset=rotation*Vector3.new(x*(visual.scale or 1),y*(visual.scale or 1),0)
 local width=1/math.sqrt(stretch)
 if entry and (entry.charmShape or "dot")~="dot"then return frame+offset,size end
 return frame+offset,Vector3.new(size.X*width,size.Y*stretch,size.Z*width)
end
return Charms
