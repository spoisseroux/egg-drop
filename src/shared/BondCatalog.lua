-- Bond levels (overnight 2026-11-14, slice F; SYSTEMS-SCOPE 5, VISUAL-BRIEF 5). Pure data
-- and maths shared by the server (BondState stores xp per pet) and the client (pips, tricks).
--
--   Bond.level(xp)      1..MaxLevelShipped: the highest shipped level whose threshold xp reaches
--   Bond.progress(xp)   {level, xp, floor, next, fraction, capped} toward the next shipped level
--   Bond.unlock(level)  the trick a level unlocks
--   Bond.trickLevel(xp, heartLevel)  tricks unlocked (1..MaxLevelShipped): the better of the Bond
--                       level and the Heart level (Levels matter, 2026-11-22). Both unlock a prefix of
--                       Unlocks, so nobody loses a trick. HeartLevels may only be lowered.
--
-- XP keeps accruing past the last shipped level (to MaxXP), so raising MaxLevelShipped
-- needs no migration: the display simply caps at the shipped level until then.
-- Every number here is [PLACEHOLDER] until tuned (SYSTEMS-SCOPE 8 #13).
--
-- Follow-up 2026-11-14: levels 6..10 ship (Version 2, MaxLevelShipped 10). The save is
-- unchanged (xp per pet, v11): a pet that already had 350+ xp simply reads its new level.
local Levels=require(script.Parent.Levels)
local Bond={Version=2,MaxXP=100000,MaxLevelShipped=10}
-- xp needed to BE each level.
-- Levels 1..5: 25 / 50 / 75 / 100 apart. Levels 6..10 [PLACEHOLDER, gentle]: 100, then a
-- flat 125 apart, so at about 35 xp a day each late level is 3 to 4 days and level 10
-- is about 24 days of play (casual, 13 xp a day: about 9 weeks).
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
 -- Levels 6..10 [PLACEHOLDER routines for Astra's review]: existing idle beats only, no new
 -- poses or models (VISUAL-BRIEF 5).
 table.freeze({level=6,id="peekaboo",copy="bond.trick.l6",beats=table.freeze({"look","wave"})}),
 table.freeze({level=7,id="cosy",copy="bond.trick.l7",beats=table.freeze({"yawn","stretch","sit"})}),
 table.freeze({level=8,id="sneezy",copy="bond.trick.l8",beats=table.freeze({"sneeze","wiggle","wiggle"})}),
 table.freeze({level=9,id="showoff",copy="bond.trick.l9",beats=table.freeze({"scratch","stretch","wave"}),hearts=true}),
 table.freeze({level=10,id="bestFriends",copy="bond.trick.l10",beats=table.freeze({"wave","wiggle","wiggle","stretch","sit"}),hearts=true}),
})
-- The Heart level that unlocks each trick (V2-SCOPE 10.2).
Bond.HeartLevels=table.freeze({1,5,10,14,18,22,25,28,31,33})
do
 assert(#Bond.HeartLevels==Bond.MaxLevelShipped and Bond.HeartLevels[1]==1,"BondCatalog: Heart levels")
 for index=2,#Bond.HeartLevels do assert(Bond.HeartLevels[index]>Bond.HeartLevels[index-1],"BondCatalog: Heart levels must rise")end
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
-- Tricks a Heart level unlocks (0 for anything but a whole level of 1 or more).
function Bond.heartTricks(heartLevel)
 if type(heartLevel)~="number"or heartLevel~=heartLevel then return 0 end
 local n=0
 for index,need in ipairs(Bond.HeartLevels)do if heartLevel>=need then n=index end end
 return n
end
-- With the track off this is exactly Bond.level(xp).
function Bond.trickLevel(xp,heartLevel)
 local level=Bond.level(xp)
 if not Levels.on("track")then return level end
 return math.max(level,Bond.heartTricks(heartLevel))
end
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
