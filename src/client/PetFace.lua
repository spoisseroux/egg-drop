-- Face identity remains shaded independently of grouped pigment surface fills.
local Clock=require(script.Parent.HollowClock)
local Night=require(script.Parent.PetNightSurfaces)
local Face={}
function Face.daylight()return Clock.lastDaylight or 1 end
function Face.paint(entry,worldContext,color,daylight)
 local role=entry.faceRole;if not role then return end
 local base=color or entry.faceBaseColor
 -- PBR emission is owned separately; expression/blink owns mark visibility.
 local tint=base
 local material=if role=="spark"and not entry.materialSurface and worldContext==true and daylight<.35 then Enum.Material.Neon else entry.faceBaseMaterial
 if entry.faceColor~=tint then entry.part.Color=tint;entry.faceColor=tint end
 if entry.faceMaterial~=material then entry.part.Material=material;entry.faceMaterial=material end
end
function Face.paintSurface(entry,visual,daylight)Night.paint(entry,visual,daylight)end
return Face
