-- "Levels matter" switches (V3-LEVELS-BUILD-PLAN-2026-11-22). Shared and pure: FeatureFlags.LevelsMatter
-- is the build ceiling, and a part is on only on the beta place or in Studio. Off is exactly the game
-- before this build: shops, shelf weeks, Book totals, snapshots and writes. Missing flag = off.
--   Levels.on(part)   part is "track" (S1), "gates" (S2), "medals" (S4) or "juice" (S3)
-- There is no runtime switch yet: off needs a republish. Add one before a live publish.
local RunService=game:GetService("RunService")
local Flags=require(script.Parent.FeatureFlags)
local Levels={}
Levels.PlaceId=107705084891479 -- Pocket Pals Beta
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

-- Spec seam: every later Levels.on reads `env` until inject(nil). Refused outside Studio, so no code
-- path on a live server can turn a part on.
local injected=nil
function Levels.inject(env)
 if not RunService:IsStudio()then return false end
 injected=if type(env)=="table"then table.clone(env)else nil
 return true
end
function Levels.on(part)return Levels.ceiling(part,injected)end
-- "1010": the four parts in order, for cache keys that depend on them.
function Levels.key()
 local out={}
 for index,part in ipairs(Levels.Parts)do out[index]=if Levels.on(part)then "1"else "0"end
 return table.concat(out)
end
return table.freeze(Levels)
