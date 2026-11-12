-- Analytic cosmetics sampled by the existing renderer owner. No tasks or clocks.
local Motion={Version=1,Breath=.014,BodyStretch=.012,HeadAngle=math.rad(2),DotRise=.045,DotSide=.018,DotStretch=.04}
local tau=math.pi*2
local function smooth(t)return t*t*(3-2*t)end
local function seedOf(visual)
 local seed=visual.cosmeticSeed or 0
 local rig=if visual.definition and visual.definition.id=="ovelle"then 317 else 0
 return ((math.abs(seed)+rig)%997)/997
end
local function glance(time)
 local cycle=math.floor(time/10.4);local phase=time%10.4
 local amount=if phase<3.2 then 0 elseif phase<5.6 then smooth((phase-3.2)/2.4)elseif phase<8 then 1 else 1-smooth((phase-8)/2.4)
 return amount*(if cycle%2==0 then 1 else -1)
end
function Motion.sample(visual,expression)
 if visual.reducedEffects or visual.idleMotionFrozen then return 1,0,0,0,0,0,0,1 end
 local seed=seedOf(visual)
 local time=(visual.cosmeticTime or visual.time or 0)+seed*17.3
 local breath=math.sin(time*tau/3.2)
 local look=glance(time)
 local blink=1
 if expression~="sleepy"and expression~="affectionate"then
  local phase=(time+seed*2.7)%(3.2+seed*2.2)
  if phase<.055 then blink=1-.94*smooth(phase/.055)
  elseif phase<.09 then blink=.06
  elseif phase<.15 then blink=.06+.94*smooth((phase-.09)/.06)end
 end
 local dotPhase=(time-.25)*tau/3.2
 local stretch=1+Motion.DotStretch*math.sin(dotPhase+math.pi*.5)
 return blink,breath*Motion.Breath,breath*Motion.BodyStretch,look*Motion.HeadAngle,look*Motion.HeadAngle*.5,
  math.sin(dotPhase*.5)*Motion.DotSide,math.sin(dotPhase)*Motion.DotRise,stretch
end
-- Ears and tail (C1). State lives on the visual and advances only with the
-- renderer's dt. Tail: about 1 Hz on neutral, about 3 Hz when pleased or
-- affectionate, still when sleepy. Ears: perk +10° curious, droop -15° sleepy,
-- and one ear flicks once every 4-9 s (seeded per pet). Reduced Effects freezes
-- everything at rest. Returns ear roll (L, R) and tail yaw in radians.
Motion.EarPerk,Motion.EarDroop,Motion.EarFlick,Motion.EarFlickTime=math.rad(10),math.rad(15),math.rad(12),.22
Motion.TailWag,Motion.TailCalm,Motion.TailHappy=math.rad(18),1,3
Motion.EarMax=Motion.EarDroop+Motion.EarFlick
local tailRate={pleased=Motion.TailHappy,affectionate=Motion.TailHappy,sleepy=0}
function Motion.appendages(visual,expression,dt)
 -- Frozen (capture) and reduced frames rest at zero without touching the live
 -- state, so a focus capture restores the exact in-flight pose afterwards.
 if visual.reducedEffects or visual.idleMotionFrozen then return 0,0,0 end
 dt=math.clamp(dt or 0,0,.25)
 local rate=tailRate[expression]or Motion.TailCalm
 if visual.wagBoost then rate=math.max(rate,visual.wagBoost)end
 local amp=visual.tailAmp or 0
 amp+=((if rate>0 then 1 else 0)-amp)*math.min(1,dt*6)
 visual.tailAmp=amp
 visual.tailPhase=((visual.tailPhase or 0)+dt*rate*tau)%tau
 local tail=math.sin(visual.tailPhase)*Motion.TailWag*amp
 local target=if expression=="curious"then Motion.EarPerk elseif expression=="sleepy"then -Motion.EarDroop else 0
 local pose=visual.earPose or 0
 pose+=(target-pose)*math.min(1,dt*5)
 visual.earPose=pose
 local time=visual.time or 0
 if not visual.earRandom then
  visual.earRandom=Random.new(math.floor(seedOf(visual)*997)+7)
  visual.nextEarFlick=time+4+visual.earRandom:NextNumber()*5
 end
 if time>=(visual.nextEarFlick or 0)then
  visual.earFlickStart,visual.earFlickSide=time,if visual.earRandom:NextNumber()<.5 then -1 else 1
  visual.nextEarFlick=time+4+visual.earRandom:NextNumber()*5
 end
 local flickL,flickR=0,0
 local start=visual.earFlickStart
 if start then
  local t=(time-start)/Motion.EarFlickTime
  if t>=1 or t<0 then visual.earFlickStart=nil
  else
   local flick=math.sin(t*math.pi)*Motion.EarFlick
   if visual.earFlickSide<0 then flickL=flick else flickR=flick end
  end
 end
 return pose+flickL,pose+flickR,tail
end
-- Wings (authored WingL/WingR S1-S5). Each wing lifts about its own root anchor:
-- a gentle ±10° idle flap on a 1.8 s cycle, the right wing a beat behind the
-- left; pleased/affectionate faces (deck cheers, petting) flap quicker and a
-- little wider; sleepy barely stirs. Amplitude and rate ease between moods, the
-- phase only advances with dt, and Reduced Effects rests them at zero.
Motion.WingIdle,Motion.WingExcited,Motion.WingSleepy=math.rad(10),math.rad(14),math.rad(2)
Motion.WingIdleRate,Motion.WingExcitedRate,Motion.WingSleepyRate=1/1.8,2.6,.3
Motion.WingLag=.45
Motion.WingMax=Motion.WingExcited
local wingExcited={pleased=true,affectionate=true}
function Motion.wings(visual,expression,dt)
 if visual.reducedEffects or visual.idleMotionFrozen then return 0,0 end
 dt=math.clamp(dt or 0,0,.25)
 local excited=wingExcited[expression]==true or visual.petting==true
 local amp,rate
 if excited then amp,rate=Motion.WingExcited,Motion.WingExcitedRate
 elseif expression=="sleepy"then amp,rate=Motion.WingSleepy,Motion.WingSleepyRate
 else amp,rate=Motion.WingIdle,Motion.WingIdleRate end
 local k=math.min(1,dt*4)
 local a=(visual.wingAmp or amp)+(amp-(visual.wingAmp or amp))*k
 local r=(visual.wingRate or rate)+(rate-(visual.wingRate or rate))*k
 visual.wingAmp,visual.wingRate=a,r
 local phase=((visual.wingPhase or seedOf(visual)*tau)+dt*r*tau)%tau
 visual.wingPhase=phase
 return math.sin(phase)*a,math.sin(phase-Motion.WingLag)*a
end
-- Conservative per-axis displacement beyond an actual expression/greeting box.
-- Includes rotation of each corner, breathing and Dot's independent translation.
function Motion.padding(visual,entry)
 local scale=visual.scale or 1
 local anchors=visual.definition and visual.definition.anchors
 if entry.name=="Tail"and anchors and anchors.Tail then
  local a=anchors.Tail;local pivot=Vector3.new(a[1],a[2],a[3])*scale
  local radius=(entry.frame.Position-pivot).Magnitude+entry.size.Magnitude*.5
  local turn=2*radius*math.sin(Motion.TailWag*.5)
  return Vector3.new(turn,entry.size.Y*Motion.BodyStretch*.5,turn)
 end
 if entry.wingSide and anchors then
  local a=anchors["Wing"..entry.wingSide]
  if a then
   local pivot=Vector3.new(a[1],a[2],a[3])*scale
   local radius=(entry.frame.Position-pivot).Magnitude+entry.size.Magnitude*.5
   local turn=2*radius*math.sin(Motion.WingMax*.5)
   return Vector3.new(turn,turn+entry.size.Y*Motion.BodyStretch*.5,turn)
  end
 end
 if entry.channel=="Body"then return Vector3.new(0,entry.size.Y*Motion.BodyStretch*.5,0)end
 local name=entry.name
 local head=entry.channel=="Head"or entry.channel=="Face"or entry.channel=="Charm"
  or string.find(name,"Eye")or string.find(name,"Glint")or string.find(name,"Mouth")or string.find(name,"Teeth")or string.find(name,"Cheek")
 if not head then return Vector3.zero end
 local anchor=visual.definition.anchors.Head
 local pivot=Vector3.new(anchor[1],anchor[2],anchor[3])*scale
 local radius=(entry.frame.Position-pivot).Magnitude+entry.size.Magnitude*.5
 local turn=2*radius*math.sin(Motion.HeadAngle*1.5*.5)
 local pad=Vector3.new(turn,turn+Motion.Breath*scale,turn)
 if entry.role=="charm"then
  local diameter=math.max(entry.size.X,entry.size.Y,entry.size.Z)
  local squash=diameter*Motion.DotStretch*.55
  -- The authored Dot frame also follows the expression's head tilt.
  pad+=Vector3.one*((Motion.DotSide+Motion.DotRise)*scale+squash)
 end
 local ear=if string.find(name,"^Ear")then(if string.sub(name,-1)=="L"then "EarL"else "EarR")else nil
 if ear and anchors and anchors[ear]then
  local a=anchors[ear];local pivot=Vector3.new(a[1],a[2],a[3])*scale
  local radius=(entry.frame.Position-pivot).Magnitude+entry.size.Magnitude*.5
  local turn=2*radius*math.sin(Motion.EarMax*.5)
  pad+=Vector3.new(turn,turn,turn)
 end
 return pad
end
return Motion
