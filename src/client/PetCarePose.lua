local Data=require(game:GetService("ReplicatedStorage").Shared.GardenCarePoseData)
local Pose={}
local function extents(visual)
 local key=tostring(visual.rigRevision)..":"..tostring(visual.renderCharmShape)..":"..tostring(visual.charmVisible)..":"..tostring(visual.featureRevision)
 if visual.careBoundsKey==key then return visual.careBounds end
 local low,high=Vector3.new(math.huge,math.huge,math.huge),Vector3.new(-math.huge,-math.huge,-math.huge)
 local rear,top=0,0;local tilt=CFrame.Angles(0,math.rad(Data.hold.facingYawToAvatarDegrees),0)*CFrame.Angles(math.rad(Data.families[visual.petId][1]),0,0)
 for _,e in ipairs(visual.pieces)do if e.part.Transparency<.99 then
  for x=-1,1,2 do for y=-1,1,2 do for z=-1,1,2 do
   local p=e.frame:PointToWorldSpace(e.size*Vector3.new(x,y,z)*.5)
   if e.role=="charm"then p+=Vector3.new(0,visual.featureHaloLift or 0,0)end
   local q=tilt:PointToWorldSpace(p)
   top=math.max(top,q.Y)
   if e.role~="charm"then
    rear=math.max(rear,-q.Z);low=Vector3.new(math.min(low.X,p.X),math.min(low.Y,p.Y),math.min(low.Z,p.Z));high=Vector3.new(math.max(high.X,p.X),math.max(high.Y,p.Y),math.max(high.Z,p.Z))
   end
  end end end
 end end
 local result={top=top,rear=rear,size=high-low};visual.careBoundsKey=key;visual.careBounds=result;return result
end
function Pose.blend(visual,target,dt)
 visual.careElapsed=(visual.careElapsed or 0)+(dt or 1)
 local u=if visual.reducedEffects then 1 else math.clamp(visual.careElapsed/Data.hold.transitionSeconds,0,1);u=u*u*(3-2*u)
 return (visual.careFrom or target):Lerp(target,u)
end
function Pose.carried(visual,character,dt)
 local torso=character and(character:FindFirstChild("UpperTorso")or character:FindFirstChild("Torso"))
 if not torso then return false end
 local head=character:FindFirstChild("Head");local row=Data.bounds[visual.petId];local hold=Data.hold
 local measured=extents(visual);local top=measured.top
 local chin=if head then head.Position.Y-head.Size.Y*.5 else torso.Position.Y+torso.Size.Y*.5
 local sole=math.min(torso.Position.Y-hold.baseSoleBelowTorsoY,chin-hold.chinClearanceStud-top-hold.visibleCharmMotionReserveStud)
 local forward=torso.Size.Z*.5+measured.rear+hold.forwardClearanceStud
 local target=torso.Position+torso.CFrame.LookVector*forward+torso.CFrame.RightVector*hold.sideStud
 visual.origin=Pose.blend(visual,Vector3.new(target.X,sole,target.Z),dt)
 local look=torso.CFrame.LookVector;visual.yaw=math.atan2(look.X,look.Z)+math.rad(hold.facingYawToAvatarDegrees)
 return true
end
function Pose.set(visual,state)
 local previous=visual.careState;visual.careState=state
 local row=Data.families[visual.petId]
 visual.carePitch=if state=="Carried"then math.rad(row[1])else 0
 visual.careHeadRoll=if state=="Carried"then math.rad(row[2])elseif state=="Docked"then math.rad(row[8])else 0
 visual.careHeadPitch=if state=="Carried"then math.rad(row[3])else 0
 visual.careHand=if state=="Carried"then row[4]else 0
 visual.careBodyLower=if state=="Docked"then row[7]else 0
 visual.careFootForward=if state=="Carried"then row[5]else 0
 visual.careFootLift=if state=="Carried"then row[6]else 0
 if previous~=state then visual.poseSlots=nil;visual.poseDirty=true;visual.careFrom=visual.origin;visual.careElapsed=0 end
end
function Pose.targets(visual)
 local bounds=extents(visual).size;local width,height=bounds.X,bounds.Y
 local frame=CFrame.new(visual.origin)*CFrame.Angles(0,visual.yaw,0);local points={}
 for i,key in ipairs({"left","right"})do local p=Data.hold.reachTarget[key]
  points[i]=frame:PointToWorldSpace(Vector3.new(p[1]*width,p[2]*height+(if i==1 then Data.hold.reachTarget.leftHeightExtraStud else 0),p[3]))
 end
 return points
end
return Pose
