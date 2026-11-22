-- "Levels matter" switches (V3-LEVELS-BUILD-PLAN-2026-11-22). Shared and pure: FeatureFlags.LevelsMatter
-- is the build ceiling, and a part is on only on the beta place or in Studio, while the runtime switch
-- is on. Off is exactly the game before this build: shops, shelf weeks, Book totals, snapshots and
-- writes. Missing flag = off.
--   Levels.on(part)   part is "track" (S1), "gates" (S2), "medals" (S4) or "juice" (S3)
-- The runtime switch (server LevelsConfig; ConfigService key `levels_matter`, missing = on) is for all
-- four parts. The server reads its own resolved value, never an attribute; clients read the workspace
-- attribute the server writes, and a missing one (no such server code, or not started) is off.
local RunService=game:GetService("RunService")
local Flags=require(script.Parent.FeatureFlags)
local Levels={}
Levels.PlaceId=107705084891479 -- Pocket Pals Beta
Levels.Attribute="Levels_matter"
Levels.Key="levels_matter"
Levels.Parts=table.freeze({"track","gates","medals","juice"})
-- A part whose code has not landed in this build is false here (land order: S1, S2, S4, S3).
Levels.Shipped=table.freeze({track=true,gates=true,medals=true,juice=true})

-- Specs pass env = {flags, place, studio, shipped}; the game passes nothing.
function Levels.ceiling(part,env)
 env=env or {}
 if not table.find(Levels.Parts,part)or(env.shipped or Levels.Shipped)[part]~=true then return false end
 if(env.flags or Flags).LevelsMatter~=true then return false end
 local studio=env.studio
 if studio==nil then studio=RunService:IsStudio()end
 return(env.place or game.PlaceId)==Levels.PlaceId or studio==true
end

-- True when any part is allowed in this build and place: the switch has something to turn off.
function Levels.allowed(env)
 for _,part in ipairs(Levels.Parts)do if Levels.ceiling(part,env)then return true end end
 return false
end
-- Pure: the switch value. Anything but a boolean (missing, malformed) is the shipped default, on.
function Levels.resolve(configValue,override,ceiling)
 if ceiling==nil then ceiling=Levels.allowed()end
 if not ceiling then return false end
 if type(override)=="boolean"then return override end
 if type(configValue)=="boolean"then return configValue end
 return true
end
-- Server only (LevelsConfig): the resolved value every server check reads. Off until it is set.
local switch=false
function Levels.setSwitch(value)
 if not RunService:IsServer()then return false end
 switch=value==true
 return true
end
function Levels.switch()
 if RunService:IsServer()then return switch end
 return workspace:GetAttribute(Levels.Attribute)==true
end
-- Fires when the switch flips (the server also pushes a fresh snapshot to every player).
function Levels.changed()return workspace:GetAttributeChangedSignal(Levels.Attribute)end

-- Spec seam: every later Levels.on reads `env` (switch on unless env.switch==false) until inject(nil).
-- Refused outside Studio, so no code path on a live server can turn a part on.
local injected=nil
function Levels.inject(env)
 if not RunService:IsStudio()then return false end
 injected=if type(env)=="table"then table.clone(env)else nil
 return true
end
function Levels.on(part)
 if injected then return injected.switch~=false and Levels.ceiling(part,injected)end
 return Levels.ceiling(part)and Levels.switch()
end
-- "1010": the four parts in order, for cache keys that depend on them.
function Levels.key()
 local out={}
 for index,part in ipairs(Levels.Parts)do out[index]=if Levels.on(part)then "1"else "0"end
 return table.concat(out)
end
return table.freeze(Levels)
