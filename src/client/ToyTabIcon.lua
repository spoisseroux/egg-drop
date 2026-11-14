-- QA v2 R4.5: the Customize Toys icon (a chew bone). The drawing now lives in DeckKit's
-- vector icon table (`Kit.icon(parent, "toy", ...)`, R3); this thin wrapper keeps the
-- old requires and API working.
local Kit=require(script.Parent.DeckKit)
local Icon={Name="toy"}
function Icon.knobs()return Kit.toyKnobs()end
function Icon.draw(h)return Kit.VectorIcons.toy(h)end
function Icon.register()return Kit.VectorIcons~=nil and Kit.VectorIcons[Icon.Name]~=nil end
return Icon
