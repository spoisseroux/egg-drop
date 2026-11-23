-- Face identity remains shaded independently of grouped pigment surface fills.
local Clock=require(script.Parent.HollowClock)
local Night=require(script.Parent.PetNightSurfaces)
local Hour=require(game:GetService("ReplicatedStorage"):WaitForChild("Shared"):WaitForChild("GardenHour"))
local Face={}
function Face.daylight()return Clock.lastDaylight or 1 end
-- Garden hour slice E (GARDEN-HOUR-BUILD-PLAN-2026-11-23, architect review): pets stay awake through the hour's night.
-- The mood rules (PetExpression.garden, PetIdleBeats night weights, PetCooScheduler NightWait) read this, never the
-- light: while GardenHour.on() it never drops below AwakeFloor (= their .3 night tests). Glow and face paint keep
-- reading Face.daylight(). Off: the daylight passed in, unchanged.
Face.AwakeFloor=.3
function Face.mood(daylight,hourOn)
 if hourOn==true and type(daylight)=="number"and daylight<Face.AwakeFloor then return Face.AwakeFloor end
 return daylight
end
-- `daylight` defaults to Face.daylight(); RoomView's coos pass HollowClock.daylight() (the coo clock it reads today).
function Face.moodDaylight(daylight)
 if daylight==nil then daylight=Face.daylight()end
 return Face.mood(daylight,Hour.on())
end
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
