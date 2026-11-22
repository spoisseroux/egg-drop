-- Level gates (V3-LEVELS-BUILD-PLAN-2026-11-22, S2). Pure. A catalogue row's `gate` is {stat, level}
-- (any owned pet at that level) or {total} (one owned pet's total level). Gates never close again
-- once met: XP never falls, and a shipped gate may only be loosened (lower level), never raised.
-- The server checks the save (StatState.publicLevels); a client check is for the chip only.
--
-- `levels` is always { [petId] = { [statId] = level } } for owned pets; Gate.levels makes it from a
-- snapshot's petStats.pets, StatState.publicLevels().pets or the PublicStats attribute's pets.
-- Anything malformed counts as not met (fail closed).
local Shared=script.Parent
local Stats=require(Shared.StatCatalog)
local Levels=require(Shared.Levels)
local Gate={}
Gate.Reason="NeedsLevel"
Gate.TotalMax=#Stats.Order*Stats.MaxLevel

local function integer(value,low,high)
 return type(value)=="number"and value==value and value%1==0 and value>=low and value<=high
end
-- A well-formed gate: exactly {stat, level} or exactly {total}.
function Gate.valid(gate)
 if type(gate)~="table"then return false end
 for key in pairs(gate)do if key~="stat"and key~="level"and key~="total"then return false end end
 if gate.total~=nil then
  return gate.stat==nil and gate.level==nil and integer(gate.total,#Stats.Order+1,Gate.TotalMax)
 end
 return type(gate.stat)=="string"and Stats.ById[gate.stat]~=nil and integer(gate.level,2,Stats.MaxLevel)
end

-- {petId={statId=level}} from any of the shapes above ({level={}}, {levels={}} or plain rows).
function Gate.levels(pets)
 local result={}
 if type(pets)~="table"then return result end
 for petId,row in pairs(pets)do
  if type(petId)=="string"and type(row)=="table"then
   local source=if type(row.level)=="table"then row.level elseif type(row.levels)=="table"then row.levels else row
   local clean={}
   for _,stat in ipairs(Stats.Order)do
    if integer(source[stat],1,Stats.MaxLevel)then clean[stat]=source[stat]end
   end
   result[petId]=clean
  end
 end
 return result
end
function Gate.total(row)
 local total=0
 if type(row)=="table"then
  for _,stat in ipairs(Stats.Order)do if integer(row[stat],1,Stats.MaxLevel)then total+=row[stat]end end
 end
 return total
end
-- The best owned pet for a gate: {have, need, petId (nil when no pet), met, stat or total}.
function Gate.progress(levels,gate)
 if not Gate.valid(gate)then return {have=0,need=math.huge,met=false}end
 local need=gate.total or gate.level
 local have,best=0,nil
 local ids={}
 if type(levels)=="table"then for petId in pairs(levels)do if type(petId)=="string"then table.insert(ids,petId)end end end
 table.sort(ids)
 for _,petId in ipairs(ids)do
  local row=levels[petId]
  local value=if gate.total then Gate.total(row)
   elseif type(row)=="table"and integer(row[gate.stat],1,Stats.MaxLevel)then row[gate.stat]else 0
  if value>have then have,best=value,petId end
 end
 return {have=have,need=need,petId=best,met=have>=need,stat=gate.stat,total=gate.total}
end
-- No gate is always met; a malformed gate or levels table never is.
function Gate.met(levels,gate)
 if gate==nil then return true end
 return Gate.progress(levels,gate).met
end
-- Off: a gated row is not for sale at all (NotForSale), whatever the levels.
function Gate.listed(gate)return gate==nil or Levels.on("gates")end
return table.freeze(Gate)
