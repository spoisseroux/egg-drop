-- UI scale space (beta 17 U4). A GuiObject's AbsoluteSize includes every UIScale on it and
-- its ancestors, but the offsets written into its children are scaled again by those same
-- UIScales. Geometry measured from AbsoluteSize and written back as offsets therefore lands
-- at scale^2: on a small window (the Hatch eggs panel scaled down to about 0.85) the egg
-- preview's bloom and shadow sat up and left of the 3D egg; on a big one (1.2) right of it.
-- These helpers turn AbsoluteSize back into the object's own (pre-UIScale) units.
local Space={}

-- The product of every UIScale on `object` and its ancestors, up to the LayerCollector.
-- Works on anything with Parent / IsA / FindFirstChildWhichIsA (specs pass plain tables).
function Space.scaleOf(object)
 local scale=1
 local node=object
 while node~=nil and not node:IsA("LayerCollector")do
  local ui=node:FindFirstChildWhichIsA("UIScale")
  if ui and type(ui.Scale)=="number"and ui.Scale>0 then scale*=ui.Scale end
  node=node.Parent
 end
 return scale
end

-- Pure: the size in the object's own units. Offset-only sizes are exact; anything with a
-- Scale part is AbsoluteSize divided by the accumulated UIScale.
function Space.localSize(size,absolute,scale)
 if size.X.Scale==0 and size.Y.Scale==0 and size.X.Offset>0 and size.Y.Offset>0 then return size.X.Offset,size.Y.Offset end
 if type(scale)~="number"or scale<=0 or scale~=scale then scale=1 end
 return absolute.X/scale,absolute.Y/scale
end

return Space
