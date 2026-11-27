-- Alive pass switches (ALIVE-BUILD-PLAN-2026-11-22, revisions 1 and 2). Shared and pure: the server
-- writes one boolean workspace attribute per feature (AliveConfig); everyone else only reads them.
-- Beta and Studio only until PlaceId changes: the ceiling is false on every other place.
local RunService=game:GetService("RunService")
local Flags=require(script.Parent.FeatureFlags)
local Alive={}
Alive.PlaceId=107705084891479 -- Pocket Pals Beta
-- Beta 14 (GARDEN-LIFE-BUILD-PLAN, architect r1): `scene` is the W3 additions (the big breath, chimes, dapple, koi, the
-- far flock, lamps and the shooting star, dragonflies, ground plates); `snack` is my pet's Dewdrop snack alone.
-- Beta 17 (WORLD-ALIVE-LOOK 1.3 D): `windbed` is the continuous wind bed (AmbientAudio) for Spencer to hear first; it is
-- the one feature whose missing value is OFF (Alive.Defaults).
-- ASMR-AND-SCALE-LOOK 1 and 2: `asmr` is the ASMR hatch (HatchAsmr: layered cracks and the pop) and the vibration
-- (Haptics: the hatch beats, Pocket Deck merges, the Vibration setting). Missing = on.
-- Beta 34 notes (GARDEN-PLAY-BRIEF 3): `wobble` is the Wobble Egg on the crag (WobbleEggClient). Missing = on.
-- GARDEN-PLAY-BRIEF 1 and 2: `balls` is the five Bumble balls (BumbleBalls, BumbleBallHost, BumbleBallsClient). Missing = on.
-- GARDEN-PLAY-BRIEF 2026-11-26: `crunch` is the crunchy toys round the garden (CrunchToysClient), `air` the drift
-- balloons (since GARDEN-PLAY-BRIEF-2 section 6: hot-air balloons, three with a mascot) and seed fluff over it
-- (DriftLanternsClient). Missing = on.
-- GARDEN-PLAY-BRIEF-2 (beta 35 notes 4 and 8): `fruit` is the 3D fruit, the tree shake, the five-bite snack and its Heart
-- XP (GardenFruit, FruitHost); `keepout` is the pets going round the garden's solid props (GardenKeepOut). Missing = on.
-- AERO-JUICE-BRIEF (beta 36) section 3: `aerohatch` is the Sky / Meadow / Aurora hatch and reveal cards (HatchAero,
-- HatchItemStage, RevealStage); off is the old orange sunburst look. Missing = on.
-- AERO-JUICE-BRIEF 2 (beta 36 notes): `deckjuice` is the Pocket Deck juice pass (AeroJuice: the merge's impact frame,
-- hold, beads, layered sound, combos, drop and land, idle life, rolling counters, glints). Missing = on. The Aero Glass
-- default ball palette is not behind it: it is simply the new default.
-- ONBOARDING-V3-BRIEF section 4 (beta 37 notes): `pet2` is the cuter petting screen (PetCuddle, PetCuddleUI: the mitten,
-- the Happy heart, the lean, the glass plates, the spots). Missing = on. Off = the petting screen exactly as before.
Alive.Features=table.freeze({"springs","menus","close","wind","life","scene","snack","windbed","asmr","wobble","balls","crunch","air",
 "fruit","keepout","aerohatch","deckjuice","pet2"})
local FlagNames=table.freeze({springs="AliveSprings",menus="AliveMenus",close="AliveClose",wind="AliveWind",life="AliveLife",
 scene="AliveScene",snack="AliveSnack",windbed="AliveWindbed",asmr="AliveAsmr",wobble="AliveWobble",balls="AliveBalls",
 crunch="AliveCrunch",air="AliveAir",fruit="AliveFruit",keepout="AliveKeepOut",aerohatch="AliveAeroHatch",deckjuice="AliveDeckJuice",pet2="AlivePet2"})
-- What a missing or malformed config value means, where it is not on.
Alive.Defaults=table.freeze({windbed=false})

function Alive.attribute(feature)return "Alive_"..feature end
function Alive.key(feature)return "alive_"..feature end
-- Specs pass flags, place and studio; the game passes nothing.
function Alive.ceiling(feature,flags,place,studio)
 local name=FlagNames[feature]
 if not name or(flags or Flags)[name]~=true then return false end
 if studio==nil then studio=RunService:IsStudio()end
 return(place or game.PlaceId)==Alive.PlaceId or studio==true
end
-- A missing or malformed value (anything but a boolean) is the shipped default: on (Alive.Defaults: off for windbed).
function Alive.resolve(feature,configValue,override,ceiling)
 if ceiling==nil then ceiling=Alive.ceiling(feature)end
 if not ceiling then return false end
 if type(override)=="boolean"then return override end
 if type(configValue)=="boolean"then return configValue end
 return Alive.Defaults[feature]~=false
end
-- A missing attribute is off: the server always writes booleans, so absence means no kill switch.
function Alive.on(feature)
 return Alive.ceiling(feature)and workspace:GetAttribute(Alive.attribute(feature))==true
end
function Alive.changed(feature)return workspace:GetAttributeChangedSignal(Alive.attribute(feature))end
return Alive
