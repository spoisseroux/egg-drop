-- Garden Dash switches (V3-DASH-BUILD-PLAN-2026-11-22, slice S6), the Levels pattern with two keys. Shared and
-- pure: FeatureFlags.GardenDash is the build ceiling, and it opens only on the beta place or in Studio, while
-- the runtime switch is on. Off is exactly the game before this build: no remotes, gate, attributes, tags,
-- snapshot keys or writes. Missing flag = off.
--   Dash.on()       racing (ConfigService key `garden_dash`)
--   Dash.prizes()   Stars, ribbons and cups too (`garden_dash_prizes`); off alone, races still run and only the
--                   best Time Trial is saved
-- Both keys are off until the config has loaded once (server DashConfig). Then a missing `garden_dash` is on, but
-- prizes are only ever on by an explicit true: missing or malformed stays off. The server is on
-- only while its own resolved value and the attribute it published both say so. Clients read the workspace
-- attributes the server writes; a missing one (no such server code, or not started) is off.
local RunService=game:GetService("RunService")
local Flags=require(script.Parent.FeatureFlags)
local Dash={}
Dash.PlaceId=107705084891479 -- Pocket Pals Beta
Dash.Features=table.freeze({"race","prizes"})
Dash.Attributes=table.freeze({race="Dash_race",prizes="Dash_prizes"})
Dash.Keys=table.freeze({race="garden_dash",prizes="garden_dash_prizes"})
-- What a missing or malformed value means, per part.
Dash.Default=table.freeze({race=true,prizes=false})
function Dash.attribute(feature)return Dash.Attributes[feature]end
function Dash.key(feature)return Dash.Keys[feature]end

-- Specs pass env = {flags, place, studio} (or inject it, below); the game passes nothing.
local injected=nil
function Dash.ceiling(env)
	env=env or injected or {}
	if(env.flags or Flags).GardenDash~=true then return false end
	local studio=env.studio
	if studio==nil then studio=RunService:IsStudio()end
	return(env.place or game.PlaceId)==Dash.PlaceId or studio==true
end
-- Pure: a switch value. Anything but a boolean (missing, malformed) is the part's shipped default.
function Dash.resolve(configValue,override,ceiling,feature)
	if ceiling==nil then ceiling=Dash.ceiling()end
	if not ceiling then return false end
	if type(override)=="boolean"then return override end
	if type(configValue)=="boolean"then return configValue end
	return Dash.Default[feature or"race"]==true
end
-- Server only (DashConfig): the resolved values every server check reads. Off until they are set.
local switches={race=false,prizes=false}
function Dash.setSwitch(feature,value)
	if not RunService:IsServer()or switches[feature]==nil then return false end
	switches[feature]=value==true
	return true
end
function Dash.switch(feature)
	if RunService:IsServer()and switches[feature]~=true then return false end
	return workspace:GetAttribute(Dash.Attributes[feature])==true
end
function Dash.changed(feature)return workspace:GetAttributeChangedSignal(Dash.Attributes[feature or"race"])end

-- Spec seam: every later ceiling(), on() and prizes() reads `env` (race and prizes on unless env says false) until inject(nil).
-- Refused outside Studio, so no code path on a live server can turn a part on.
function Dash.inject(env)
	if not RunService:IsStudio()then return false end
	injected=if type(env)=="table"then table.clone(env)else nil
	return true
end
function Dash.on()
	if injected then return injected.race~=false and Dash.ceiling(injected)end
	return Dash.ceiling()and Dash.switch("race")
end
function Dash.prizes()
	if injected then return Dash.on()and injected.prizes~=false end
	return Dash.on()and Dash.switch("prizes")
end
return table.freeze(Dash)
