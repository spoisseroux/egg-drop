-- A confirmed secondary-colored Dot. Hidden dots never enter any hit hull.
local Charms={}
function Charms.apply(visual,appearance)
 visual.charmVisible=type(appearance)~="table"or appearance.charmVisible~=false
 visual.model:SetAttribute("CharmVisible",visual.charmVisible)
 for _,entry in ipairs(visual.pieces)do if entry.role=="charm"then entry.part.Transparency=if visual.charmVisible then 0 else 1 end end
end
function Charms.isVisible(visual,entry)return entry.role~="charm"or visual.charmVisible~=false end
return Charms
