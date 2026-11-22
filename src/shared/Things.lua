-- Things to do switches (V3-THINGS-TO-DO-PLAN-2026-11-22), the Dash pattern. Shared and pure: FeatureFlags.ThingsToDo
-- is the build ceiling, and it opens only on the beta place or in Studio, while the runtime switch is on. Off is
-- exactly the game before this build: six hub tiles, the same tips, tour and stations, no instances, no frame work,
-- and the new coach ids are refused. Missing flag = off.
--   Things.on()     the Pocket menu tile, its page and the Show me trail (ConfigService key `things_to_do`)
--   Things.tips()   the onboarding lines too (`things_tips`; needs the first)
-- Both keys are off until the config has loaded once (server ThingsConfig), then missing or malformed = on. The
-- server is on only while its own resolved value and the attribute it published both say so. Clients read the
-- workspace attributes the server writes; a missing one (no such server code, or not started) is off.
local RunService=game:GetService("RunService")
local Flags=require(script.Parent.FeatureFlags)
local Things={}
Things.PlaceId=107705084891479 -- Pocket Pals Beta
Things.Features=table.freeze({"page","tips"})
Things.Attributes=table.freeze({page="Things_page",tips="Things_tips"})
Things.Keys=table.freeze({page="things_to_do",tips="things_tips"})
function Things.attribute(feature)return Things.Attributes[feature]end
function Things.key(feature)return Things.Keys[feature]end

-- Specs pass env = {flags, place, studio} (or inject it, below); the game passes nothing.
local injected=nil
function Things.ceiling(env)
	env=env or injected or {}
	if(env.flags or Flags).ThingsToDo~=true then return false end
	local studio=env.studio
	if studio==nil then studio=RunService:IsStudio()end
	return(env.place or game.PlaceId)==Things.PlaceId or studio==true
end
-- Pure: a switch value. Anything but a boolean (missing, malformed) is the shipped default, on.
function Things.resolve(configValue,override,ceiling)
	if ceiling==nil then ceiling=Things.ceiling()end
	if not ceiling then return false end
	if type(override)=="boolean"then return override end
	if type(configValue)=="boolean"then return configValue end
	return true
end
-- Server only (ThingsConfig): the resolved values every server check reads. Off until they are set.
local switches={page=false,tips=false}
function Things.setSwitch(feature,value)
	if not RunService:IsServer()or switches[feature]==nil then return false end
	switches[feature]=value==true
	return true
end
function Things.switch(feature)
	if RunService:IsServer()and switches[feature]~=true then return false end
	return workspace:GetAttribute(Things.Attributes[feature])==true
end
function Things.changed(feature)return workspace:GetAttributeChangedSignal(Things.Attributes[feature or"page"])end

-- Spec seam: every later ceiling(), on() and tips() reads `env` (page and tips on unless env says false) until inject(nil).
-- Refused outside Studio, so no code path on a live server can turn a part on.
function Things.inject(env)
	if not RunService:IsStudio()then return false end
	injected=if type(env)=="table"then table.clone(env)else nil
	return true
end
function Things.on()
	if injected then return injected.page~=false and Things.ceiling(injected)end
	return Things.ceiling()and Things.switch("page")
end
function Things.tips()
	if injected then return Things.on()and injected.tips~=false end
	return Things.on()and Things.switch("tips")
end
-- May a coach card that belongs to a part ("page" or "tips") be shown and saved now?
function Things.allows(part)
	if part=="tips"then return Things.tips()end
	return Things.on()
end
return table.freeze(Things)
