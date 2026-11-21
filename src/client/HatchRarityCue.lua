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
-- Round 3 (Fable brief 3): earned pets (the Bunny) hatch as Rare; the Bear stays Common.
for _,pet in ipairs(Pets.earned or {})do rarePets[pet.id]=true end
local basePets={};for _,pet in ipairs(Pets)do basePets[pet.id]=true end
local statTier=table.freeze({nibble="Common",snack="Uncommon",feast="Rare"})
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
 -- v2 Stat Egg: the snack's size is its tier (Nibble Common, Snack Uncommon, Feast Rare).
 if kind=="stat"then return statTier[result.size]or "Neutral"end
 return "Neutral"
end
-- Look per tier (HatchItemStage). Common is a soft cream-white, Uncommon green, Rare
-- blue-violet; rarer tiers get a wider beam, more rays and shards, and a stronger flash.
-- Neutral (an item with no authored tier) looks like Common and shows no tier word.
-- back / backDeep (QA R2): the lit backdrop behind the item on its card, top to bottom.
-- v850 phone notes (Spencer never wants the "sad blue-ish" teal): Common is the warm house
-- cream to peach (DeckKit.WarmWell), Uncommon stays leaf green, Rare violet.
local function look(color,second,beam,rays,shards,sparkles,rings,flash,shake,spin,back,backDeep)
 return table.freeze({color=Color3.fromHex(color),second=Color3.fromHex(second),beam=beam,rays=rays,shards=shards,
  sparkles=sparkles,rings=rings,flash=flash,shake=shake,spin=spin,back=Color3.fromHex(back),backDeep=Color3.fromHex(backDeep)})
end
Policy.Look=table.freeze({
 Common=look("#FFF1D6","#FFFFFF",.55,6,10,0,1,.22,2,0,"#FFE2B8","#E9946A"),
 Neutral=look("#FFF1D6","#FFFFFF",.55,6,10,0,1,.22,2,0,"#FFE2B8","#E9946A"),
 Uncommon=look("#57E08A","#C8FFD9",.80,10,18,6,1,.40,4,6,"#A6F27E","#27A45A"),
 Rare=look("#8E7CFF","#5CC8FF",1,16,30,12,2,.62,7,14,"#B9A9FF","#5340D8"),
})
-- v2 Pop-Out Stage (R1.2, 2.3): the vibrant preview stage per tier, never deck-tinted.
-- core/edge: the radial fill; ray: the 12 light rays; floor: the light pool; deep: the 30%
-- vignette; pattern: the edge pattern (dots, stripes, diamonds). spin: ray turn (deg/s).
-- stones/sparkles: burst confetti (Common stays inside the well); escape: share that leaves
-- the well; bloom: the one bloom's peak opacity inside the well; checker: px/s at the burst.
local function stage(core,edge,ray,floor,deep,pattern,spin,stones,sparkles,escape,bloom,checker,push,tip,pull)
 return table.freeze({core=Color3.fromHex(core),edge=Color3.fromHex(edge),ray=Color3.fromHex(ray),floor=Color3.fromHex(floor),
  deep=Color3.fromHex(deep),pattern=pattern,spin=spin,stones=stones,sparkles=sparkles,escape=escape,bloom=bloom,checker=checker,push=push,tip=tip,pull=pull})
end
Policy.Stage=table.freeze({
 Common=stage("#FF9A2E","#F0541E","#FFBC47","#FFF3C4","#A8300E","dots",0,4,2,0,.20,8,.04,0,0),
 Neutral=stage("#FF9A2E","#F0541E","#FFBC47","#FFF3C4","#A8300E","dots",0,4,2,0,.20,8,.04,0,0),
 Uncommon=stage("#58C92F","#16994A","#9BE23A","#F6FFC4","#0B6B36","stripes",18,8,6,.5,.35,16,.04,2,.06),
 Rare=stage("#E845C8","#6B3BEA","#FF79D9","#FFE9F8","#3B1FA0","diamonds",12,20,10,1,.60,48,.04,2,.10),
})
-- The tier's sound on the hatch clock: one event, `pre` (it plays before the receipt
-- unlocks), at the burst less the sting's lead-in. Played at speed 1 always: the stings
-- are tuned as one family. The hatch body is quiet (about -29 LUFS) until the shell opens,
-- so the pop is clear at the burst; the Rare chime then rings through the body's own hit.
-- The accent voice is stopped at readyAt + AnswerEnd, after the longest sting has ended.
-- v2 hatch (V2-HATCH-REDESIGN-2026-11-19 R1.1, R1.4): one clock per tier. Common, Uncommon
-- and untiered items keep today's beats (burst 0.98, name 1.65); a Rare item is a jackpot: a
-- wind-up and a freeze move its burst to 1.72, and the cannons and the "RARE!" stamp move its
-- name to 3.15. Pets keep their clock (the Bear is Common; the legacy rares are never hatched
-- in v2). Reduced Motion: a 0.6 s cross-fade (Rare 0.9 s) whose sting still plays; the clock
-- runs on (decorative only) until the sound has rung out.
Policy.Base=table.freeze({burst=.98,ready=1.65,duration=3.1,petReady=2.05,petDuration=4.4})
Policy.Jackpot=table.freeze({windup=.95,freeze=1.60,burst=1.72,pop=1.80,cannonL=1.95,cannonR=2.07,stamp=2.30,seat=2.80,seatEnd=3.14,
 name=3.15,duration=4.6,layerAt=.67,stingAt=1.02,stingGain=.80,layerGain=.72,layerLength=3.45,reducedReady=.9,reducedStamp=.45,reducedDuration=3.5})
Policy.Reduced=table.freeze({ready=.6,stingAt=.30,duration=1.6,crack=.15,fadeFrom=.30,fadeTo=.45})
-- Pure: the hatch clock for one result. {burst, ready, duration, quiet (accent voice stops),
-- bodyAt (the hatch body sound starts; its own pop sits 0.98 s in), jackpot, reduced}.
local timingCache={}
local timingOf
function Policy.timing(tier,kind,reduced)
 local pet=kind=="companion"
 local key=(if tier=="Rare"then "R"else "o")..(if pet then "p"else "i")..(if reduced then "r"else "f")
 local hit=timingCache[key]
 if hit then return hit end
 hit=timingOf(tier,pet,reduced);timingCache[key]=hit
 return hit
end
function timingOf(tier,pet,reduced)
 local jackpot=tier=="Rare"and not pet
 local B,J,R=Policy.Base,Policy.Jackpot,Policy.Reduced
 if reduced then
  if pet then return table.freeze({burst=0,ready=.15,duration=.15,quiet=.15,bodyAt=0,jackpot=false,reduced=true})end
  local ready=if jackpot then J.reducedReady else R.ready
  local duration=if jackpot then J.reducedDuration else R.duration
  return table.freeze({burst=R.fadeFrom,ready=ready,duration=duration,quiet=duration,bodyAt=0,jackpot=jackpot,reduced=true})
 end
 if pet then return table.freeze({burst=B.burst,ready=B.petReady,duration=B.petDuration,quiet=B.petReady+Policy.AnswerEnd,bodyAt=0,jackpot=false,reduced=false})end
 if jackpot then return table.freeze({burst=J.burst,ready=J.name,duration=J.duration,quiet=J.duration,bodyAt=J.burst-B.burst,jackpot=true,reduced=false})end
 return table.freeze({burst=B.burst,ready=B.ready,duration=B.duration,quiet=B.ready+Policy.AnswerEnd,bodyAt=0,jackpot=false,reduced=false})
end
function Policy.burstAt(tier,kind)return Policy.timing(tier,kind,false).burst end
-- The jackpot's two voices (uploaded 2026-11-19 from artifacts/v2-hatch-redesign-2026-11-19/audio):
-- hatch_jackpot plays under the approved Rare sting, hatch_jackpot_calm under Reduced Motion.
Policy.JackpotCue="hatch_jackpot";Policy.JackpotCalmCue="hatch_jackpot_calm"
-- Round 3 (Fable, CREATIVE-BRIEF 2): one sound line for every egg, pets included. The tier
-- sting is the hatch's sound; three wobbles on the rock peaks and the crack glint lead into it.
-- The old body cues (hatch_display_<kind>) play at BodyGain (0: off; they covered the sting).
Policy.BodyGain=0
Policy.Foley=table.freeze({
 table.freeze({at=.21,cue="egg_wobble",speed=1.00,gain=.28}),table.freeze({at=.48,cue="egg_wobble",speed=1.08,gain=.34}),
 table.freeze({at=.81,cue="egg_wobble",speed=1.16,gain=.40}),table.freeze({at=.65,cue="egg_crack_glint",speed=1,gain=.45}),
})
-- The tier line with the foley merged in, in time order (Policy.new).
local function withFoley(events)
 local out={}
 for _,f in ipairs(Policy.Foley)do table.insert(out,{at=f.at,cue=f.cue,speed=f.speed,gain=f.gain,pre=true})end
 for _,e in ipairs(events)do table.insert(out,e)end
 table.sort(out,function(a,b)return a.at<b.at end)
 return out
end
function Policy.events(classification,readyAt,reduced,kind)
 local s=Policy.Sting[classification]or Policy.Sting.Common
 local J=Policy.Jackpot
 local jackpot=classification=="Rare"and kind~="companion"
 if reduced then
  -- Sound is not motion: the tier's sting still plays (R1.1). The calm layer leads the
  -- Rare; the others pop on the cross-fade.
  if jackpot then return {{at=0,cue=Policy.JackpotCalmCue,speed=1,gain=J.layerGain,pre=true},{at=0,cue=s.cue,speed=1,gain=J.stingGain,pre=true}}end
  return {{at=Policy.Reduced.stingAt,cue=s.cue,speed=1,gain=s.gain,pre=true}}
 end
 if jackpot then
  -- Both hits land on the burst (1.72) and the fanfare chord on the stamp (2.30).
  return {{at=J.layerAt,cue=Policy.JackpotCue,speed=1,gain=J.layerGain,pre=true},{at=J.stingAt,cue=s.cue,speed=1,gain=J.stingGain,pre=true}}
 end
 return {{at=Policy.BurstAt-s.hit,cue=s.cue,speed=1,gain=s.gain,pre=true}}
end
function Policy.new(kind,result,readyAt,reduced)
 local classification=Policy.tier(kind,result)
 -- Round 3: pets get the tier line too (the Bear's rarity_common lands as the shell opens);
 -- RevealStage.Cues stay as the entrance after it.
 -- The egg foley leads in (not under Reduced Motion); Policy.events stays the tier's own line.
 local events=Policy.events(classification,readyAt,reduced,kind)
 if not reduced then events=withFoley(events)end
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
