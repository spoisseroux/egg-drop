-- Fixed authored presentation tiers. Never reads conditional odds or saved ownership.
-- 2026-11-15 (QA v685 H2/H3): every tier has its own look (light colour, beam, burst size)
-- and its own sound line, so Common, Uncommon and Rare read apart by eye and by ear.
-- Sounds are existing uploaded cues only, varied by pitch, gain and layering.
local Shared=game:GetService("ReplicatedStorage").Shared
local Features=require(Shared.FeatureCatalog);local Materials=require(Shared.MaterialCatalog)
local Toys=require(Shared.ToyCatalog);local Hues=require(Shared.HueCatalog);local Pets=require(Shared.PetCatalog)
local Policy={Cue="hatch_finish",AnswerEnd=1.45,MaxLateness=.10,BurstAt=.98,FlourishAfter=.45}
local Cue={};Cue.__index=Cue
local valid={Common=true,Uncommon=true,Rare=true,Neutral=true}
local materialTier=table.freeze({standard="Common",gloss="Common",matte="Common",jelly="Rare"})
local rarePets={};for _,pet in ipairs(Pets.rares)do rarePets[pet.id]=true end
local basePets={};for _,pet in ipairs(Pets)do basePets[pet.id]=true end
local function tier(row)return if row and valid[row.rarity]then row.rarity else "Neutral"end
function Policy.tier(kind,result)
 result=result or {}
 if kind=="material"then return if Materials.known(result.finishId)then materialTier[result.finishId]or "Neutral"else "Neutral"end
 if kind=="feature"then return tier(Features.ById[result.featureId])end
 if kind=="toy"then return tier(Toys.ById[result.toyId])end
 if kind=="hue"then return tier(Hues.Items[result.itemId])end
 if kind=="companion"then return if rarePets[result.petId]then "Rare"elseif basePets[result.petId]then "Common"else "Neutral"end
 return "Neutral"
end
-- Look per tier (HatchItemStage). Common is a soft cream-white, Uncommon green, Rare
-- blue-violet; rarer tiers get a wider beam, more rays and shards, and a stronger flash.
-- Neutral (an item with no authored tier) looks like Common and shows no tier word.
-- back / backDeep (QA R2): the lit backdrop behind the item on its card, top to bottom:
-- garden teal for Common, leaf green for Uncommon, violet for Rare.
local function look(color,second,beam,rays,shards,sparkles,rings,flash,shake,spin,back,backDeep)
 return table.freeze({color=Color3.fromHex(color),second=Color3.fromHex(second),beam=beam,rays=rays,shards=shards,
  sparkles=sparkles,rings=rings,flash=flash,shake=shake,spin=spin,back=Color3.fromHex(back),backDeep=Color3.fromHex(backDeep)})
end
Policy.Look=table.freeze({
 Common=look("#FFF1D6","#FFFFFF",.55,6,10,0,1,.22,2,0,"#7FE3D4","#1E8C92"),
 Neutral=look("#FFF1D6","#FFFFFF",.55,6,10,0,1,.22,2,0,"#7FE3D4","#1E8C92"),
 Uncommon=look("#57E08A","#C8FFD9",.80,10,18,6,1,.40,4,6,"#A6F27E","#27A45A"),
 Rare=look("#8E7CFF","#5CC8FF",1,16,30,12,2,.62,7,14,"#B9A9FF","#5340D8"),
})
-- Sound line per tier, in seconds on the hatch clock. `pre` notes play before the receipt
-- unlocks (the build-up and the burst); the rest answer the name slam at `readyAt`.
-- Gains are set against the hatch body sound, which is quiet (about -29 LUFS) until the
-- shell opens and loud (about -14 LUFS) from 1.5 to 2.0 s, right on the name slam. A note
-- there is masked, so each tier's answering flourish waits `FlourishAfter` for the body to
-- fall away; see artifacts/reveal-2026-11-15/audio/LOUDNESS.md.
local function st(n)return 2^(n/12)end
function Policy.events(classification,readyAt)
 local B=Policy.BurstAt
 if classification=="Uncommon"then return {
  {at=.30,cue="star_land",speed=st(0),gain=.40,pre=true},{at=.62,cue="star_land",speed=st(4),gain=.46,pre=true},
  {at=B,cue="reveal_shimmer",speed=1,gain=.55,pre=true},
  {at=readyAt,cue="name_slam",speed=1.06,gain=.90},{at=readyAt+Policy.FlourishAfter,cue="quest_complete",speed=1,gain=.85}}
 elseif classification=="Rare"then return {
  {at=.16,cue="star_land",speed=st(0),gain=.36,pre=true},{at=.36,cue="star_land",speed=st(4),gain=.40,pre=true},
  {at=.56,cue="star_land",speed=st(7),gain=.46,pre=true},{at=.76,cue="star_land",speed=st(12),gain=.52,pre=true},
  {at=.86,cue="streak_whoosh",speed=1,gain=.55,pre=true},
  {at=B,cue="reveal_shimmer",speed=st(3),gain=.80,pre=true},{at=B+.06,cue="new_best",speed=1,gain=.70,pre=true},
  {at=readyAt,cue="name_slam",speed=.94,gain=1},{at=readyAt+Policy.FlourishAfter,cue="stars_total",speed=st(2),gain=.80}}
 end
 return {{at=.34,cue="egg_wobble",speed=1,gain=.40,pre=true},{at=B,cue="egg_crack_glint",speed=1,gain=.50,pre=true},
  {at=readyAt,cue="name_slam",speed=1,gain=.90}}
end
function Policy.new(kind,result,readyAt)
 local classification=Policy.tier(kind,result)
 -- Pets keep the reveal stage's own sound line (RevealStage.Cues); items get the tier line.
 local events=if kind=="companion"then {}else Policy.events(classification,readyAt)
 return setmetatable({tier=classification,events=events,cursor=1,lastAge=0,readyAt=readyAt},Cue)
end
function Cue:cancel()self.cancelled=true;self.cursor=#self.events+1 end
-- Every event that came due since the last call. A pause, preload or skip (a jump over
-- 0.25 s) consumes what it crossed without playing it; nothing is backfilled later.
function Cue:due(age,disclosed,live)
 local out={}
 if self.cancelled then return out end
 if not live or type(age)~="number"or age~=age or age<self.lastAge then self:cancel();return out end
 local largeJump=age-self.lastAge>.25;self.lastAge=age
 while self.cursor<=#self.events and self.events[self.cursor].at<=age do
  local event=self.events[self.cursor];self.cursor+=1
  if not largeJump and(disclosed or event.pre or age>=self.readyAt)and age-event.at<=Policy.MaxLateness then table.insert(out,event)end
 end
 return out
end
-- The newest due event (the older single-note callers and specs).
function Cue:step(age,disclosed,live)
 local due=self:due(age,disclosed,live)
 return due[#due]
end
return table.freeze(Policy)
