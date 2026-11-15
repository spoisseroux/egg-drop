-- Pure receipt display timing. One host clock; no tasks, assets or rewards.
-- 2026-11-15 reveal redesign: the receipt unlocks with the name slam. Pets hand off to the
-- full-screen RevealStage at RevealStage.LeadIn (1.05) and its buttons open 1.0 s later; items
-- slam their name at 1.65 (HatchItemStage). The authored 4.4 s / 3.1 s sounds are unchanged.
local Pose={BearDuration=4.4,ItemDuration=3.1,BearReady=2.05,ItemReady=1.65}
local function smooth(a,b,t)local u=math.clamp((t-a)/(b-a),0,1);return u*u*(3-2*u)end
local function pulse(t,a,b)return if t>a and t<b then math.sin(math.pi*(t-a)/(b-a))else 0 end
function Pose.sample(age,kind,reduced)
 local companion=kind=="companion";local duration=if companion then Pose.BearDuration else Pose.ItemDuration
 local ready=if companion then Pose.BearReady else Pose.ItemReady
 local t=math.max(0,age or 0)
 if reduced then
  return {age=t,duration=duration,receiptReady=t>=.15,inputLocked=t<.15,decorativeActive=t<.15,heroAlpha=smooth(0,.15,t),
   heroScale=.92+.08*smooth(0,.15,t),stretch=0,hop=0,eye=1,blink=1,headRoll=0,headYaw=0,handL=0,handR=0,ear=0,tail=0,
   shellAlpha=0,capAlpha=0,shellScale=.2,forward=.08,opening=1,rock=0,crack=0,receiptAlpha=smooth(0,.15,t),toyTilt=0,toyYaw=0,duck=false,reduced=true}
 end
 local wave=pulse(t,2.39,2.61)+pulse(t,2.66,2.88)
 local eye=if t<1.85 then 1.16 elseif t<2.65 then .95 elseif t<3.65 then .90 else 1
 local blink=1
 for _,at in ipairs({1.57,3.80})do
  local u=t-at
  if u>=0 and u<.15 then blink=if u<.055 then 1-.94*smooth(0,.055,u)elseif u<.09 then .06 else .06+.94*smooth(.09,.15,u)end
 end
 local appear=1.10
 local scale=.72+.31*smooth(1.10,1.32,t)-.03*smooth(1.32,1.48,t)
 local u=math.max(0,t-1.50)
 return {age=t,duration=duration,receiptReady=t>=ready,inputLocked=t<ready,decorativeActive=t<duration,
  heroAlpha=smooth(appear,1.30,t),heroScale=scale,
  stretch=if companion then .04*pulse(t,1.97,2.30)-.06*pulse(t,2.30,2.40)-.08*pulse(t,1.85,1.97)else 0,
  hop=.035*pulse(t,1.10,1.48)+(if companion then .11*pulse(t,1.97,2.30)else 0),forward=.08*smooth(1.10,1.48,t),eye=eye,blink=blink,
  headRoll=math.rad(8)*smooth(1.48,1.85,t)*(1-smooth(2.95,3.65,t))-math.rad(4)*wave,
  headYaw=math.rad(7)*(1-smooth(1.10,1.55,t)),handL=.16,handR=.24+.95*wave,
  ear=if t<2.65 then math.rad(10)else 0,tail=.12*math.sin(t*13)*(if t>=1.85 and t<2.65 then 1 else .25),
  shellAlpha=1-smooth(.98,1.18,t),capAlpha=1-smooth(.96,1.10,t),shellScale=1-.8*smooth(.95,1.18,t),opening=smooth(.95,1.18,t),
  rock=math.rad(-5)*pulse(t,.12,.31)+math.rad(8)*pulse(t,.34,.62)+math.rad(10)*pulse(t,.69,.94),
  crack=if t>=.65 and t<.95 then smooth(.65,.93,t)else 0,
  receiptAlpha=smooth(ready-.25,ready,t),
  toyTilt=math.rad(12)*math.exp(-u*2)*math.sin(u*math.pi*4)*(1-smooth(2.05,2.20,t)),toyYaw=math.rad(18)*smooth(1.50,2.20,t),
  duck=t>=.15 and t<ready+.45,reduced=false}
end
function Pose.settled(kind,reduced)return Pose.sample(if reduced then .15 elseif kind=="companion"then 4.4 else 3.1,kind,reduced)end
return table.freeze(Pose)
