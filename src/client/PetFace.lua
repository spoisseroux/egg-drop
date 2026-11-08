-- Existing named face details only. No light, geometry or per-frame rig scan.
local Clock=require(script.Parent.HollowClock)
local Face={}
function Face.daylight()return Clock.lastDaylight or 1 end
function Face.paint(entry,worldContext,color,daylight)
 local role=entry.faceRole;if not role then return end
 local night=worldContext==true and daylight<.35
 local base=color or entry.faceBaseColor
 local tint=if night and role=="cheek"then Color3.new(base.R*.55,base.G*.55,base.B*.55)else base
 local material=if night then Enum.Material.Neon else entry.faceBaseMaterial
 if entry.faceColor~=tint then entry.part.Color=tint;entry.faceColor=tint end
 if entry.faceMaterial~=material then entry.part.Material=material;entry.faceMaterial=material end
end
return Face
