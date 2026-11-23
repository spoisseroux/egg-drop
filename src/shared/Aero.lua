-- Frutiger Aero "Medium" switch (WORLD-PLAN-2026-11-22 section 9). Shared and pure, like Alive and Levels:
-- FeatureFlags.AeroWorld is the build ceiling, only the beta place or Studio passes it, and the server's
-- resolved value (AeroConfig; ConfigService key `aero_world`) reaches clients as one workspace attribute.
-- Looks only, so nothing on the server reads it. A missing attribute is off.
local RunService=game:GetService("RunService")
local Flags=require(script.Parent.FeatureFlags)
local Aero={}
Aero.PlaceId=107705084891479 -- Pocket Pals Beta
Aero.Attribute="AeroWorld"
Aero.Key="aero_world"
-- Which crowns: "lime" (the default, and anything unknown) or "coral".
Aero.TreesAttribute="AeroWorldTrees"
Aero.Trees=table.freeze({"lime","coral"})

-- Specs pass env = {flags, place, studio}; the game passes nothing (one frozen empty table: on() is asked per frame
-- through GardenHour.on(), so it allocates nothing).
local NoEnv=table.freeze({})
function Aero.ceiling(env)
	env=env or NoEnv
	if(env.flags or Flags).AeroWorld~=true then return false end
	local studio=env.studio
	if studio==nil then studio=RunService:IsStudio()end
	return(env.place or game.PlaceId)==Aero.PlaceId or studio==true
end
-- Pure: anything but a boolean (missing, malformed) is the shipped default, on.
function Aero.resolve(configValue,override,ceiling)
	if ceiling==nil then ceiling=Aero.ceiling()end
	if not ceiling then return false end
	if type(override)=="boolean"then return override end
	if type(configValue)=="boolean"then return configValue end
	return true
end
function Aero.on()return Aero.ceiling()and workspace:GetAttribute(Aero.Attribute)==true end
function Aero.changed()return workspace:GetAttributeChangedSignal(Aero.Attribute)end
function Aero.trees()
	local value=workspace:GetAttribute(Aero.TreesAttribute)
	return if value~=nil and table.find(Aero.Trees,value)then value else Aero.Trees[1]
end
function Aero.treesChanged()return workspace:GetAttributeChangedSignal(Aero.TreesAttribute)end
return table.freeze(Aero)
