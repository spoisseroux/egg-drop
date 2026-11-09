-- One listener-owned incidental voice, driven by Room's existing update; never previews.
local Pose=require(script.Parent.PetCooPose)
local Coos={};Coos.__index=Coos;Coos.Range=28
local quiet={wanderPause=true,nookRest=true,settle=true,rest=true,none=true}
local function eligible(v,camera,listener)
 if not v or v.destroyed or not v.worldContext or not v.model.Parent or not Pose.family(v.petId)then return false end
 if v.petting or v.focused or v.focusPose or v.gardenFocus or(v.affection or 0)>.15 or(v.gaitWeight or 0)>.08 then return false end
 if v.gardenAction and not quiet[v.gardenAction]then return false end
 if(v.greeting or 2)<1.2 then return false end
 if v.expression~="neutral"and v.expression~="sleepy"then return false end
 local distance=(v.origin-listener).Magnitude;if distance>=Coos.Range then return false end
 if camera then local point,visible=camera:WorldToViewportPoint(v.origin+Vector3.new(0,.7,0));if not visible or point.Z<=0 then return false end end
 return true,distance
end
function Coos.new(audio,options)
 options=options or {};local random=Random.new()
 return setmetatable({audio=audio,token={},wait=options.wait or function()return random:NextNumber(35,75)end},Coos)
end
function Coos:cancel()
 if self.active then
  self.audio:stopOwner(self.token)
  self.active.visual.cooStart,self.active.visual.cooFamily=nil,nil;self.active.visual.poseDirty=true
 end
 self.active=nil
end
function Coos:step(now,context,owner,visitors)
 if self.destroyed then return end
 local audio=self.audio
 if self.listenerIdentity~=context.identity then self:cancel();self.nextAt=nil;self.listenerIdentity=context.identity end
 local enabled=context.enabled and context.listener~=nil and audio.deviceActive~=false and audio.group.Volume>0
  and not(audio.petSpeechBusy and audio:petSpeechBusy(self.token))
 if not enabled then self:cancel();self.nextAt=nil;return end
 if self.active then
  local a=self.active;local valid=eligible(a.visual,context.camera,context.listener)
  if not valid or a.visual.model~=a.model or a.visual.lastGeneration~=a.generation or(a.root and not a.root.Parent)or(a.board and a.board:GetAttribute("Mode")~="Room")or now>=a.untilTime then self:cancel()end
  return
 end
 -- The listener's quiet-room interval survives ordinary pet walking. At a due
 -- beat no eligible speaker means skip, never wait/queue for a pause to end.
 if not self.nextAt then self.nextAt=now+self.wait();return end
 if now<self.nextAt then return end
 self.nextAt=now+self.wait()
 local candidate,distance,candidateRoot,candidateBoard
 if eligible(owner,context.camera,context.listener)then candidate,distance=owner,0 else
  for _,entry in pairs(visitors or {})do if not entry.board or entry.board:GetAttribute("Mode")=="Room"then
   local allowed,gap=eligible(entry.visual,context.camera,context.listener)
   if allowed and(not candidate or gap<distance)then candidate,distance,candidateRoot,candidateBoard=entry.visual,gap,entry.root,entry.board end
  end end
 end
 if not candidate then return end
 local family=Pose.family(candidate.petId)
 local gain=.18*(if candidate==owner then 1 else math.clamp(1-distance/Coos.Range,0,1))
 if not audio:play(family.cueFallback,family.fallbackPitch,gain,self.token)then return end
 candidate.cooStart,candidate.cooFamily=now,family;candidate.poseDirty=true
 self.active={visual=candidate,model=candidate.model,generation=candidate.lastGeneration,untilTime=now+family.duration,root=candidateRoot,board=candidateBoard}
end
function Coos:destroy()if self.destroyed then return end;self:cancel();self.destroyed=true;self.nextAt=nil end
Coos.eligible=eligible
return Coos
