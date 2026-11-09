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
-- Conservative per-axis displacement beyond an actual expression/greeting box.
-- Includes rotation of each corner, breathing and Dot's independent translation.
function Motion.padding(visual,entry)
 local scale=visual.scale or 1
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
 return pad
end
return Motion
