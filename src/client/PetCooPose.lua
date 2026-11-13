-- Astra's relative overlay: no root/feet, authority, sound or independent clock.
local Data=require(script.Parent.CareFeedbackData)
local Pose={};local families={}
for id,entry in pairs(Data.families)do families[id]=entry;for _,related in ipairs(entry.related)do families[related]=entry end end
function Pose.family(id)return families[id]end
function Pose.sample(visual)
 local entry,start=visual.cooFamily,visual.cooStart
 if not visual.worldContext or not entry or not start or visual.petting or visual.focusPose or visual.gardenFocus or(visual.affection or 0)>.15 then return 0,0,0,0,1 end
 local face=visual.expression or "neutral"
 if face~="neutral"and face~="sleepy"and face~="content"and face~="dozy"then return 0,0,0,0,1 end
 if(visual.greeting or 2)<1.2 or(visual.gardenAction and visual.gardenAction~="wanderPause"and visual.gardenAction~="nookRest"and visual.gardenAction~="settle"and visual.gardenAction~="rest"and visual.gardenAction~="none")then return 0,0,0,0,1 end
 local t=(visual.cosmeticTime or visual.time or 0)-start
 if t<0 or t>=entry.duration then return 0,0,0,0,1 end
 local a,b=entry.pose[1],entry.pose[#entry.pose]
 for i=2,#entry.pose do if t<=entry.pose[i][1]then a,b=entry.pose[i-1],entry.pose[i];break end end
 local u=math.clamp((t-a[1])/math.max(.00001,b[1]-a[1]),0,1);u=u*u*(3-2*u)
 local roll,nod,hand,mouth,eye=a[2]+(b[2]-a[2])*u,a[3]+(b[3]-a[3])*u,a[4]+(b[4]-a[4])*u,a[5]+(b[5]-a[5])*u,a[6]+(b[6]-a[6])*u
 if visual.reducedEffects then return 0,0,0,mouth*.4,1-(1-eye)*.25 end
 return math.rad(roll),math.rad(nod),hand*(visual.worldScale or .72)/.72,mouth,eye
end
return Pose
