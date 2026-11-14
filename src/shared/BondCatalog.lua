-- Bond levels (overnight 2026-11-14, slice F; SYSTEMS-SCOPE 5, VISUAL-BRIEF 5). Pure data
-- and maths shared by the server (BondState stores xp per pet) and the client (pips, tricks).
--
--   Bond.level(xp)      1..MaxLevelShipped: the highest shipped level whose threshold xp reaches
--   Bond.progress(xp)   {level, xp, floor, next, fraction, capped} toward the next shipped level
--   Bond.unlock(level)  the trick a level unlocks
--
-- XP keeps accruing past the last shipped level (to MaxXP), so raising MaxLevelShipped later
-- needs no migration: the display simply caps at the shipped level until then.
-- Every number here is [PLACEHOLDER] until tuned (SYSTEMS-SCOPE 8 #13).
local Bond={Version=1,MaxXP=100000,MaxLevelShipped=5}
-- xp needed to BE each level. Levels 6..10 are reserved for a later update.
Bond.Thresholds=table.freeze({0,25,75,150,250,350,475,600,725,850})
-- XP sources (the server adds these inside transactions that already exist).
Bond.XP=table.freeze({pet=1,round=2,win=3,playDate=5})
-- One unlock per shipped level: local presentation only, built from existing poses
-- (PetIdleBeats / PetSitPose). `copy` is the UICopy key of its name (bond.trick.l<level>, lane U).
Bond.Unlocks=table.freeze({
 table.freeze({level=1,id="hello",copy="bond.trick.l1",beats=table.freeze({"wave"})}),
 table.freeze({level=2,id="sit",copy="bond.trick.l2",beats=table.freeze({"sit"})}),
 table.freeze({level=3,id="wiggle",copy="bond.trick.l3",beats=table.freeze({"wiggle","wiggle"})}),
 table.freeze({level=4,id="stretch",copy="bond.trick.l4",beats=table.freeze({"stretch","sit"})}),
 table.freeze({level=5,id="hop",copy="bond.trick.l5",beats=table.freeze({"stretch","wiggle","wave"}),hearts=true}),
})
do
 assert(Bond.Thresholds[1]==0 and Bond.MaxLevelShipped>=1 and Bond.MaxLevelShipped<=#Bond.Thresholds,"BondCatalog: bad level range")
 for index=2,#Bond.Thresholds do
  assert(Bond.Thresholds[index]>Bond.Thresholds[index-1],"BondCatalog: thresholds must rise")
 end
 assert(Bond.Thresholds[#Bond.Thresholds]<=Bond.MaxXP and #Bond.Unlocks==Bond.MaxLevelShipped,"BondCatalog: unlocks and levels disagree")
end

-- Any stored value as a whole xp in 0..MaxXP (missing or malformed reads 0).
function Bond.clamp(xp)
 if type(xp)~="number"or xp~=xp or xp<=0 then return 0 end
 return math.min(Bond.MaxXP,math.floor(xp))
end
function Bond.level(xp)
 xp=Bond.clamp(xp)
 local level=1
 for index=2,Bond.MaxLevelShipped do
  if xp>=Bond.Thresholds[index]then level=index else break end
 end
 return level
end
-- xp needed to be `level` (nil outside 1..#Thresholds).
function Bond.threshold(level)return Bond.Thresholds[level]end
function Bond.progress(xp)
 xp=Bond.clamp(xp)
 local level=Bond.level(xp)
 local floor=Bond.Thresholds[level]
 if level>=Bond.MaxLevelShipped then
  return {level=level,xp=xp,floor=floor,next=nil,fraction=1,capped=true}
 end
 local goal=Bond.Thresholds[level+1]
 return {level=level,xp=xp,floor=floor,next=goal,fraction=math.clamp((xp-floor)/(goal-floor),0,1),capped=false}
end
function Bond.unlock(level)return Bond.Unlocks[level]end
-- Every unlock the xp has reached, in level order.
function Bond.unlocked(xp)
 local result={}
 for index=1,Bond.level(xp)do table.insert(result,Bond.Unlocks[index])end
 return result
end
-- The bond map of a save or snapshot ({petId = xp}) read for one pet.
function Bond.xpOf(bond,petId)
 return Bond.clamp(type(bond)=="table"and type(petId)=="string"and bond[petId]or 0)
end
return table.freeze(Bond)
