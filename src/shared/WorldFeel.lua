-- World feel (beta 14 QA W4; artifacts/qa-2026-11-23-beta14/WORLD-AND-NEST-LOOK.md section 2): the island reads bigger
-- without rescaling it. Shared and pure, the Dash pattern with two keys. FeatureFlags.WorldFeel is the build ceiling,
-- and it opens only on the beta place or in Studio, while each runtime switch is on:
--   WorldFeel.on("feel")  the lower arrival camera, the zoom cap and the haze (ConfigService `world_feel`)
--   WorldFeel.on("walk")  the garden walk speed 14, to test (`world_walk`; revert at once if it feels sluggish)
-- Both are off until the config has loaded once (server WorldFeelConfig), then a missing or malformed key is on. Off
-- writes nothing: the camera, zoom, walk speed and Atmosphere are exactly the game before this build.
local RunService=game:GetService("RunService")
local Flags=require(script.Parent.FeatureFlags)
local Feel={}
Feel.PlaceId=107705084891479 -- Pocket Pals Beta
Feel.Features=table.freeze({"feel","walk"})
Feel.Attributes=table.freeze({feel="Feel_feel",walk="Feel_walk"})
Feel.Keys=table.freeze({feel="world_feel",walk="world_walk"})
-- The numbers (Fable): the arrival camera about 17 degrees down (was about 25), the zoom cap, the walk speed (never
-- under 13), the haze added to Atmosphere.Density on the garden-hour path.
Feel.Arrival=Vector3.new(4,3.5,11)
Feel.ArrivalOff=Vector3.new(5,6,12)
Feel.MaxZoom=22
Feel.Walk=14
Feel.WalkFloor=13
Feel.Haze=.05

function Feel.attribute(feature)return Feel.Attributes[feature]end
function Feel.key(feature)return Feel.Keys[feature]end
local injected=nil
-- Specs pass env = {flags, place, studio} (or inject it); the game passes nothing.
function Feel.ceiling(env)
	env=env or injected or {}
	if(env.flags or Flags).WorldFeel~=true then return false end
	local studio=env.studio
	if studio==nil then studio=RunService:IsStudio()end
	return(env.place or game.PlaceId)==Feel.PlaceId or studio==true
end
-- Pure: a switch value. Anything but a boolean is on (inside the ceiling).
function Feel.resolve(configValue,override,ceiling)
	if ceiling==nil then ceiling=Feel.ceiling()end
	if not ceiling then return false end
	if type(override)=="boolean"then return override end
	if type(configValue)=="boolean"then return configValue end
	return true
end
-- Server only (WorldFeelConfig): the resolved values. Off until they are set.
local switches={feel=false,walk=false}
function Feel.setSwitch(feature,value)
	if not RunService:IsServer()or switches[feature]==nil then return false end
	switches[feature]=value==true
	return true
end
function Feel.on(feature)
	if injected then return injected[feature]~=false and Feel.ceiling(injected)end
	if not Feel.ceiling()or Feel.Attributes[feature]==nil then return false end
	if RunService:IsServer()and switches[feature]~=true then return false end
	return workspace:GetAttribute(Feel.Attributes[feature])==true
end
function Feel.changed(feature)return workspace:GetAttributeChangedSignal(Feel.Attributes[feature])end
-- What the game uses (each answers the off value when its switch is off).
function Feel.arrival()return if Feel.on("feel")then Feel.Arrival else Feel.ArrivalOff end
function Feel.haze()return if Feel.on("feel")then Feel.Haze else 0 end
-- Spec seam, refused outside Studio.
function Feel.inject(env)
	if not RunService:IsStudio()then return false end
	injected=if type(env)=="table"then table.clone(env)else nil
	return true
end
return table.freeze(Feel)
