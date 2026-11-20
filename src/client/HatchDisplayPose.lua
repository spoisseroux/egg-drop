-- Pure receipt display timing. One host clock; no tasks, assets or rewards.
-- 2026-11-15 reveal redesign: the receipt unlocks with the name slam. Pets hand off to the
-- full-screen RevealStage at RevealStage.LeadIn (1.05) and its buttons open 1.0 s later; items
-- slam their name at 1.65 (HatchItemStage). The authored 4.4 s / 3.1 s sounds are unchanged.
-- v2 hatch (V2-HATCH-REDESIGN-2026-11-19, R1.1 / R1.3): the clock is per tier
-- (HatchRarityCue.timing). A Rare item's egg holds through a wind-up (lift 10 px, shiver,
-- freeze squash 114% x 86%) and bursts at 1.72; everything after the burst keeps its offset
-- from the burst, everything after the name its offset from the name. Squash keeps volume
-- and pivots at the foot (eggSX / eggSY, HatchDisplayScene). Reduced Motion is the 0.6 s
-- cross-fade (Rare 0.9 s) with the crack already drawn.
local Rarity=require(script.Parent.HatchRarityCue)
local Pose={BearDuration=4.4,ItemDuration=3.1,BearReady=2.05,ItemReady=1.65}
local function smooth(a,b,t)local u=math.clamp((t-a)/(b-a),0,1);return u*u*(3-2*u)end
local function pulse(t,a,b)return if t>a and t<b then math.sin(math.pi*(t-a)/(b-a))else 0 end
-- Motion spec curves (R1.3). spring: exp(-d x) cos(2 pi n x), x the share of `length`.
local function spring(t,length,n,d)
 if t<0 then return 1 end
 local x=t/length;if x>=1 then return 0 end
 return math.exp(-d*x)*math.cos(2*math.pi*n*x)*(1-x)
end
Pose.spring=spring
-- A squash that keeps volume (width x height = 1), from a height share.
local function squash(y)return 1/math.max(.2,y),y end
Pose.timing=Rarity.timing
function Pose.readyAt(kind,tier,reduced)return Rarity.timing(tier,kind,reduced).ready end
function Pose.durationOf(kind,tier,reduced)return Rarity.timing(tier,kind,reduced).duration end
function Pose.sample(age,kind,reduced,tier)
 local companion=kind=="companion"
 local T=Rarity.timing(tier,kind,reduced==true)
 local duration,ready=T.duration,T.ready
 local t=math.max(0,age or 0)
 if reduced then
  local cross=if companion then smooth(0,.15,t)else smooth(Rarity.Reduced.fadeFrom,Rarity.Reduced.fadeTo,t)
  local crack=if companion or t<Rarity.Reduced.crack then 0 else 1-cross
  return {age=t,duration=duration,ready=ready,tier=tier,receiptReady=t>=ready,inputLocked=t<ready,decorativeActive=t<duration,heroAlpha=cross,
   heroScale=.92+.08*cross,stretch=0,hop=0,eye=1,blink=1,headRoll=0,headYaw=0,handL=0,handR=0,ear=0,tail=0,
   shellAlpha=if companion then 0 else 1-cross,capAlpha=if companion then 0 else 1-cross,shellScale=if companion then .2 else 1,forward=.08*cross,
   opening=if companion then 1 else 0,rock=0,crack=crack,receiptAlpha=smooth(ready-.15,ready,t),toyTilt=0,toyYaw=0,
   eggSX=1,eggSY=1,eggLift=0,shiver=0,duck=false,reduced=true,jackpot=T.jackpot}
 end
 -- The egg's own clock (tb) holds at the end of the crack through the Rare wind-up; the
 -- name-relative clock (tr) keeps the old offsets from the name.
 local shift=T.burst-Rarity.Base.burst
 local tb=if t<.949 then t elseif t<.949+shift then .949 else t-shift
 local tr=t-(ready-(if companion then Pose.BearReady else Pose.ItemReady))
 local wave=pulse(tr,2.39,2.61)+pulse(tr,2.66,2.88)
 local eye=if tr<1.85 then 1.16 elseif tr<2.65 then .95 elseif tr<3.65 then .90 else 1
 local blink=1
 for _,at in ipairs({1.57,3.80})do
  local u=tr-at
  if u>=0 and u<.15 then blink=if u<.055 then 1-.94*smooth(0,.055,u)elseif u<.09 then .06 else .06+.94*smooth(.09,.15,u)end
 end
 local appear=1.10
 local scale=.72+.31*smooth(1.10,1.32,tb)-.03*smooth(1.32,1.48,tb)
 local u=math.max(0,tr-1.50)
 -- Egg squash (R1.3): 96% x 105% at each rock's peak, a crack pop 106% x 95% (spring n 1,
 -- d 6), and the Rare freeze 114% x 86%. (The landing squash belongs to the lid's egg, which
 -- lands before the hatch clock starts; a clock waiting at 0 shows the egg at rest.)
 local sy=1
 sy+=.05*(pulse(tb,.12,.31)+pulse(tb,.34,.62)+pulse(tb,.69,.94))*.5
 sy-=.05*spring(tb-.65,.26,1,6)
 local lift,shiver=0,0
 if T.jackpot then
  local J=Rarity.Jackpot
  local w=math.clamp((t-J.windup)/.20,0,1);w=1-2^(-10*w)
  local fall=smooth(J.burst,J.burst+.12,t)
  lift=w*(1-fall)
  shiver=if t>=J.windup and t<J.freeze then smooth(J.windup,J.freeze,t)else 0
  if t>=J.freeze and t<J.burst then local f=(t-J.freeze)/(J.burst-J.freeze);sy=1-.14*(1-(1-f)^2)end
 end
 local sx;sx,sy=squash(sy)
 return {age=t,duration=duration,ready=ready,tier=tier,jackpot=T.jackpot,receiptReady=t>=ready,inputLocked=t<ready,decorativeActive=t<duration,
  heroAlpha=smooth(appear,1.30,tb),heroScale=scale,
  stretch=if companion then .04*pulse(tr,1.97,2.30)-.06*pulse(tr,2.30,2.40)-.08*pulse(tr,1.85,1.97)else 0,
  hop=.035*pulse(tb,1.10,1.48)+(if companion then .11*pulse(tr,1.97,2.30)else 0),forward=.08*smooth(1.10,1.48,tb),eye=eye,blink=blink,
  headRoll=math.rad(8)*smooth(1.48,1.85,tr)*(1-smooth(2.95,3.65,tr))-math.rad(4)*wave,
  headYaw=math.rad(7)*(1-smooth(1.10,1.55,tb)),handL=.16,handR=.24+.95*wave,
  ear=if tr<2.65 then math.rad(10)else 0,tail=.12*math.sin(t*13)*(if tr>=1.85 and tr<2.65 then 1 else .25),
  shellAlpha=1-smooth(.98,1.18,tb),capAlpha=1-smooth(.96,1.10,tb),shellScale=1-.8*smooth(.95,1.18,tb),opening=smooth(.95,1.18,tb),
  rock=math.rad(2)*pulse(tb,.05,.12)+math.rad(-5)*pulse(tb,.12,.31)+math.rad(8)*pulse(tb,.34,.62)+math.rad(10)*pulse(tb,.69,.94),
  crack=if tb>=.65 and tb<.95 then smooth(.65,.93,tb)else 0,
  receiptAlpha=smooth(ready-.25,ready,t),
  toyTilt=math.rad(12)*math.exp(-u*2)*math.sin(u*math.pi*4)*(1-smooth(2.05,2.20,tr)),toyYaw=math.rad(18)*smooth(1.50,2.20,tr),
  eggSX=if tb<.95 or T.jackpot and t<T.burst then sx else 1,eggSY=if tb<.95 or T.jackpot and t<T.burst then sy else 1,eggLift=lift,shiver=shiver,
  duck=t>=.15 and t<ready+.45,reduced=false}
end
function Pose.settled(kind,reduced,tier)
 local T=Rarity.timing(tier,kind,reduced==true)
 return Pose.sample(T.duration,kind,reduced,tier)
end
return table.freeze(Pose)
