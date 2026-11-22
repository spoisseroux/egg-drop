-- Stat medals (V3-LEVELS-BUILD-PLAN-2026-11-22, S4). Pure: a medal is derived from a level, so
-- nothing is saved for it. 24 per pet (six stats, four tiers). Tier ids and levels are append-only
-- and a level may only be lowered. Each medal is worth one Stat Egg (server: MedalEggs).
-- Badge ids stay nil until Spencer creates the three badges; a nil id is skipped.
local Shared=script.Parent
local Stats=require(Shared.StatCatalog)
local Medals={}
Medals.Tiers=table.freeze({
 table.freeze({id="sprout",level=25,rings=0,star=false,trim=false}),
 table.freeze({id="bloom",level=50,rings=1,star=false,trim=false}),
 table.freeze({id="fullBloom",level=75,rings=2,star=false,trim=true}),
 table.freeze({id="starbloom",level=99,rings=2,star=true,trim=true}),
})
Medals.Levels=table.freeze({25,50,75,99})
Medals.PerPet=#Stats.Order*#Medals.Tiers
-- Roblox badges for the first of a tier on the account (full bloom has none).
Medals.BadgeTiers=table.freeze({"sprout","bloom","starbloom"})
Medals.Badges=table.freeze({sprout=nil,bloom=nil,starbloom=nil})
local byId={};for index,tier in ipairs(Medals.Tiers)do byId[tier.id]=index end
function Medals.index(id)return byId[id]end

local function level(value)
 return if type(value)=="number"and value==value and value%1==0 and value>=1 and value<=Stats.MaxLevel then value else 0
end
-- How many medals a level has earned (0..4): also the index of its best tier.
function Medals.count(value)
 value=level(value)
 local n=0
 for _,tier in ipairs(Medals.Tiers)do if value>=tier.level then n+=1 end end
 return n
end
-- The best tier of a level, or nil below 25.
function Medals.tier(value)return Medals.Tiers[Medals.count(value)]end
-- One pet's six slots in panel order: {stat, count, tier or nil, next = the next tier's level or nil}.
function Medals.forPet(levels)
 local out={}
 for index,stat in ipairs(Stats.Order)do
  local n=Medals.count(type(levels)=="table"and levels[stat]or nil)
  local following=Medals.Tiers[n+1]
  out[index]={stat=stat,count=n,tier=Medals.Tiers[n],next=following and following.level or nil}
 end
 return out
end
-- Every medal of every owned pet. `levelsByPet` = {petId={statId=level}} (LevelGate.levels).
function Medals.earned(levelsByPet)
 local n=0
 if type(levelsByPet)=="table"then
  for _,levels in pairs(levelsByPet)do
   if type(levels)=="table"then for _,stat in ipairs(Stats.Order)do n+=Medals.count(levels[stat])end end
  end
 end
 return n
end
-- Medals in `after` that `before` did not have, pets by id then stats in panel order then tier:
-- {petId, stat, tier = tier id, level}. A pet missing from `before` counts as new there.
function Medals.crossed(before,after)
 local out,ids={},{}
 if type(after)~="table"then return out end
 for petId in pairs(after)do if type(petId)=="string"then table.insert(ids,petId)end end
 table.sort(ids)
 for _,petId in ipairs(ids)do
  local old=type(before)=="table"and type(before[petId])=="table"and before[petId]or {}
  for _,stat in ipairs(Stats.Order)do
   local from=Medals.count(old[stat])
   local to=Medals.count(type(after[petId])=="table"and after[petId][stat]or nil)
   for index=from+1,to do
    table.insert(out,{petId=petId,stat=stat,tier=Medals.Tiers[index].id,level=Medals.Tiers[index].level})
   end
  end
 end
 return out
end
return table.freeze(Medals)
