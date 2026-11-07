-- Puddle's floor ripple is visual FX, not part of its subject silhouette.
-- Only its world renderer accumulates this cache in the existing pose loop.
local Bounds={}
function Bounds.begin(visual)
 visual.rigMinX,visual.rigMinY,visual.rigMinZ=math.huge,math.huge,math.huge
 visual.rigMaxX,visual.rigMaxY,visual.rigMaxZ=-math.huge,-math.huge,-math.huge
end
function Bounds.include(visual,cf,size)
 local r,u,l=cf.RightVector,cf.UpVector,cf.LookVector
 local x=(math.abs(r.X)*size.X+math.abs(u.X)*size.Y+math.abs(l.X)*size.Z)*.5
 local y=(math.abs(r.Y)*size.X+math.abs(u.Y)*size.Y+math.abs(l.Y)*size.Z)*.5
 local z=(math.abs(r.Z)*size.X+math.abs(u.Z)*size.Y+math.abs(l.Z)*size.Z)*.5
 visual.rigMinX,visual.rigMinY,visual.rigMinZ=math.min(visual.rigMinX,cf.X-x),math.min(visual.rigMinY,cf.Y-y),math.min(visual.rigMinZ,cf.Z-z)
 visual.rigMaxX,visual.rigMaxY,visual.rigMaxZ=math.max(visual.rigMaxX,cf.X+x),math.max(visual.rigMaxY,cf.Y+y),math.max(visual.rigMaxZ,cf.Z+z)
end
function Bounds.finish(visual)
 visual.rigBoundsFrame=CFrame.new((visual.rigMinX+visual.rigMaxX)*.5,(visual.rigMinY+visual.rigMaxY)*.5,(visual.rigMinZ+visual.rigMaxZ)*.5)
 visual.rigBoundsSize=Vector3.new(visual.rigMaxX-visual.rigMinX,visual.rigMaxY-visual.rigMinY,visual.rigMaxZ-visual.rigMinZ)
end
function Bounds.get(visual)
 if visual.rigBoundsFrame and visual.rigBoundsSize then return visual.rigBoundsFrame,visual.rigBoundsSize end
 return visual.model:GetBoundingBox()
end
return Bounds
