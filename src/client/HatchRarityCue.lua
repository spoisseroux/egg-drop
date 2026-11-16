-- Fixed authored presentation tiers. Never reads conditional odds or saved ownership.
-- 2026-11-15 (QA v685 H2/H3): every tier has its own look (light colour, beam, burst size)
-- and its own sound, so Common, Uncommon and Rare read apart by eye and by ear.
-- 2026-11-15 (QA v735 H3): the sound is one original sting per tier (rarity_common, a light
-- pop; rarity_uncommon, a brighter pop with a chime and glitter; rarity_rare, a harp rise
-- into a big chime), synthesised by scripts/synth_hatch_rarity.py. They replace the lines
-- that were layered from older cues.
local Shared=game:GetService("ReplicatedStorage").Shared
local Features=require(Shared.FeatureCatalog);local Materials=require(Shared.MaterialCatalog)
local Toys=require(Shared.ToyCatalog);local Hues=require(Shared.HueCatalog);local Pets=require(Shared.PetCatalog)
local Look=require(Shared.LookEggCatalog)
-- Customization Egg tiers [PLACEHOLDER] (plan §5.5): hue jars Common, Gloss and Matte
-- Uncommon, Jelly and every charm Rare.
local lookTier=table.freeze({hue="Common",gloss="Uncommon",matte="Uncommon",jelly="Rare",charm="Rare"})
local Policy={Cue="hatch_finish",AnswerEnd=1.45,MaxLateness=.10,BurstAt=.98}
-- One sting per tier. `hit` is where the pop sits inside the file: the sting starts that
-- long before the burst, so the pop lands on it (Rare's rise leads in for 0.70 s).
-- `length` is the file's length; `gain` steps the tiers apart in loudness too.
local function sting(cue,hit,length,gain)return table.freeze({cue=cue,hit=hit,length=length,gain=gain})end
Policy.Sting=table.freeze({
 Common=sting("rarity_common",0,.50,.55),Neutral=sting("rarity_common",0,.50,.55),
 Uncommon=sting("rarity_uncommon",0,1.25,.75),Rare=sting("rarity_rare",.70,2.70,1),
})
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
 if kind=="hue"then
  local k=Look.kind(result.itemId)
  if k=="finish"then return lookTier[result.itemId]end
  if k=="charm"then return lookTier.charm end
  return tier(Hues.Items[result.itemId])
 end
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
-- The tier's sound on the hatch clock: one event, `pre` (it plays before the receipt
-- unlocks), at the burst less the sting's lead-in. Played at speed 1 always: the stings
-- are tuned as one family. The hatch body is quiet (about -29 LUFS) until the shell opens,
-- so the pop is clear at the burst; the Rare chime then rings through the body's own hit.
-- The accent voice is stopped at readyAt + AnswerEnd, after the longest sting has ended.
function Policy.events(classification,readyAt)
 local s=Policy.Sting[classification]or Policy.Sting.Common
 return {{at=Policy.BurstAt-s.hit,cue=s.cue,speed=1,gain=s.gain,pre=true}}
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
