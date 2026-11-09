-- A confirmed secondary-colored Dot. Hidden dots never enter any hit hull.
local Charms={}
function Charms.apply(visual,appearance)
 visual.charmVisible=type(appearance)~="table"or appearance.charmVisible~=false
 visual.model:SetAttribute("CharmVisible",visual.charmVisible)
 for _,entry in ipairs(visual.pieces)do if entry.role=="charm"then entry.part.Transparency=if visual.charmVisible then 0 else 1 end end
end
function Charms.isVisible(visual,entry)return entry.role~="charm"or visual.charmVisible~=false end
function Charms.pose(visual,frame,size,x,y,stretch)
 -- Separate movement from the head, retaining its authored attachment orientation.
 -- Volume stays constant as the Dot softly squashes at the turn of its bob.
 local width=1/math.sqrt(stretch)
 return frame*CFrame.new(x*(visual.scale or 1),y*(visual.scale or 1),0),
  Vector3.new(size.X*width,size.Y*stretch,size.Z*width)
end
return Charms
