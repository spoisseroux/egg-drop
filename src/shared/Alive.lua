-- Alive pass switches (ALIVE-BUILD-PLAN-2026-11-22, revisions 1 and 2). Shared and pure: the server
-- writes one boolean workspace attribute per feature (AliveConfig); everyone else only reads them.
-- Beta and Studio only until PlaceId changes: the ceiling is false on every other place.
local RunService=game:GetService("RunService")
local Flags=require(script.Parent.FeatureFlags)
local Alive={}
Alive.PlaceId=107705084891479 -- Pocket Pals Beta
-- Beta 14 (GARDEN-LIFE-BUILD-PLAN, architect r1): `scene` is the W3 additions (the big breath, chimes, dapple, koi, the
-- far flock, lamps and the shooting star, dragonflies, ground plates); `snack` is my pet's Dewdrop snack alone.
Alive.Features=table.freeze({"springs","menus","close","wind","life","scene","snack"})
local FlagNames=table.freeze({springs="AliveSprings",menus="AliveMenus",close="AliveClose",wind="AliveWind",life="AliveLife",
 scene="AliveScene",snack="AliveSnack"})

function Alive.attribute(feature)return "Alive_"..feature end
function Alive.key(feature)return "alive_"..feature end
-- Specs pass flags, place and studio; the game passes nothing.
function Alive.ceiling(feature,flags,place,studio)
 local name=FlagNames[feature]
 if not name or(flags or Flags)[name]~=true then return false end
 if studio==nil then studio=RunService:IsStudio()end
 return(place or game.PlaceId)==Alive.PlaceId or studio==true
end
-- A missing or malformed value (anything but a boolean) is the shipped default: on.
function Alive.resolve(feature,configValue,override,ceiling)
 if ceiling==nil then ceiling=Alive.ceiling(feature)end
 if not ceiling then return false end
 if type(override)=="boolean"then return override end
 if type(configValue)=="boolean"then return configValue end
 return true
end
-- A missing attribute is off: the server always writes booleans, so absence means no kill switch.
function Alive.on(feature)
 return Alive.ceiling(feature)and workspace:GetAttribute(Alive.attribute(feature))==true
end
function Alive.changed(feature)return workspace:GetAttributeChangedSignal(Alive.attribute(feature))end
return Alive
