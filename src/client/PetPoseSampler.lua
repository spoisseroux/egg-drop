-- Cached expressive poses, fresh root/heading and planted feet every rendered frame.
-- One host render clock; cadence can be 12/15 or 0 for the comparison control.
local Bounds=require(script.Parent.PetRigBounds)
local Sampler={DefaultCadence=15}
local tau=math.pi*2
local function footSide(entry)
 local channel=entry.channel
 if channel=="FootL"or entry.role=="footLeft"or entry.foot=="footLeft"then return -1 end
 if channel=="FootR"or entry.role=="footRight"or entry.foot=="footRight"then return 1 end
 return nil
end
local function rootOf(v)return CFrame.new(v.origin)*CFrame.Angles(0,v.yaw or 0,0)*CFrame.Angles(v.carePitch or 0,0,0)end
function Sampler.attach(visual)
 if visual.sampledPose then return visual end;visual.sampledPose=true;visual.poseCadence=Sampler.DefaultCadence
 local original=visual.update;local greet=visual.greet
 function visual:greet()self.poseDirty=true;return greet(self)end
 local function plant(self,slot,frame,root)
  local side=slot.side;if not side or not self.worldContext then return frame end
  if self.careState=="Carried"or self.careState=="Docked"then slot.anchor=nil;slot.stance=nil;slot.walking=false;return frame end
  local weight=self.gaitWeight or 0;local focus=self.focusPose or self.gardenFocus or self.gardenAction=="focus"
  local scale=self.worldScale or 1
  if focus or self.gardenAction=="greet"or self.gardenAction=="shove"then slot.anchor=nil;slot.stance=nil;slot.walking=false;return frame end
  local rest=slot.rest;local base=root*rest
  if self.gardenPivot then
   slot.walking=false
   local phase=math.clamp(self.gardenPivotPhase or 0,0,1);local turn=self.gardenPivotTurn or 0
   local halfTurn=math.abs(turn)>math.pi*.65;local beats=if halfTurn then 2 else 1
   local beat=math.min(beats-1,math.floor(phase*beats));local u=math.clamp(phase*beats-beat,0,1)
   local initialSupport=if turn>=0 then -1 else 1;local support=if beat%2==0 then initialSupport else -initialSupport
   local smooth=phase*phase*(3-2*phase)
   if not self.pivotStartYaw then self.pivotStartYaw=(self.yaw or 0)-turn*smooth end
   if slot.pivotBeat~=beat then
    slot.pivotBeat=beat;slot.pivotFrom=slot.lastPlaced or frame.Position
    slot.pivotSupport=slot.pivotFrom;slot.pivotYawFrom=self.yaw or 0
   end
   local endYaw=self.pivotStartYaw+turn*(beat+1)/beats
   local target=(CFrame.new(self.origin)*CFrame.Angles(0,endYaw,0)*rest).Position
   local position
   if side==support then position=slot.pivotSupport
   else
    local ease=u*u*(3-2*u)
    position=slot.pivotFrom:Lerp(target,ease)+Vector3.new(0,math.sin(math.pi*u)*(if self.reducedEffects then .035 else .14)*scale,0)
   end
   local half=slot.entry.part.Size.Y*.5;position=Vector3.new(position.X,math.max(self.origin.Y+half,position.Y),position.Z)
   slot.lastPlaced=position;slot.anchor=position;slot.lastPlant=position;slot.stance=side==support
   local footYaw=if side==support then slot.pivotYawFrom else slot.pivotYawFrom+(endYaw-slot.pivotYawFrom)*(u*u*(3-2*u))
   return CFrame.new(position)*CFrame.Angles(0,footYaw,0)*rest.Rotation
  elseif slot.pivotBeat then slot.pivotBeat=nil;slot.pivotFrom=nil;slot.pivotSupport=nil;slot.stance=nil end
  local heading=Vector3.new(math.sin(self.yaw or 0),0,math.cos(self.yaw or 0))
  local walking=weight>=.035
  if walking and not slot.walking then slot.stance=nil;slot.anchor=nil end
  slot.walking=walking
  local phase=((self.gaitPhase or 0)/tau+(if side<0 then 0 else .5))%1
  local stance=phase<.58 or weight<.035
  if stance then
   if not slot.stance or not slot.anchor then
    local ahead=if weight>.035 then .26*scale else 0
    slot.anchor=base.Position+heading*ahead;slot.anchorYaw=self.yaw or 0
   end
   local gap=Vector3.new(slot.anchor.X-base.X,0,slot.anchor.Z-base.Z)
   if gap.Magnitude>.72*scale then
    -- A discontinuity or teleported owner releases the old stance explicitly.
    slot.anchor=base.Position;slot.anchorYaw=self.yaw or 0
   end
   slot.stance=true
   local half=slot.entry.part.Size.Y*.5
   local y=math.max(self.origin.Y+half,slot.anchor.Y)
   local cf=CFrame.new(slot.anchor.X,y,slot.anchor.Z)*CFrame.Angles(0,slot.anchorYaw,0)*rest.Rotation
   slot.lastPlant=cf.Position;slot.lastPlaced=cf.Position;return cf
  end
  if slot.stance then slot.swingFrom=slot.lastPlant or frame.Position;slot.stance=false end
  local u=math.clamp((phase-.58)/.42,0,1);local smooth=u*u*(3-2*u)
  local target=base.Position+heading*.26*scale
  local start=slot.swingFrom or(base.Position-heading*.45*scale)
  local position=start:Lerp(target,smooth)+Vector3.new(0,math.sin(math.pi*u)*(if self.reducedEffects then .035 else .15)*scale,0)
  local half=slot.entry.part.Size.Y*.5;position=Vector3.new(position.X,math.max(self.origin.Y+half,position.Y),position.Z)
  slot.lastPlaced=position;return CFrame.new(position)*root.Rotation*rest.Rotation
 end
 function visual:update(dt)
  if self.commitReadyRig then self:commitReadyRig()end
  if self.sampledRigRevision~=self.rigRevision then self.poseSlots=nil;self.poseBucket=nil;self.poseStateKey=nil;self.pivotStartYaw=nil;self.sampledRigRevision=self.rigRevision end
  dt=if type(dt)=="number"and dt==dt and dt>=0 and dt<math.huge then dt else 0
  self.poseElapsed=(self.poseElapsed or 0)+dt;self.poseClock=(self.poseClock or 0)+dt
  local cadence=self.poseCadence or Sampler.DefaultCadence;local bucket=if cadence>0 then math.floor((self.cosmeticTime or self.poseClock)*cadence+1e-6)else -1
  local stateKey=tostring(self.reducedEffects)..":"..tostring(self.focusPose)..":"..tostring(self.expression)..":"..tostring(self.gardenAction)..":"..tostring(self.charmVisible)..":"..tostring(self.renderCharmShape)..":"..tostring(self.petting)
  local root=rootOf(self)
  if not self.gardenPivot then self.pivotStartYaw=nil end
  if not self.poseSlots or cadence<=0 or self.poseDirty or bucket~=self.poseBucket or stateKey~=self.poseStateKey then
   original(self,self.poseElapsed);self.poseElapsed=0;self.poseBucket=bucket;self.poseStateKey=stateKey;self.poseDirty=false
   local slots=self.poseSlots or {};self.poseSlots=slots
   for i,entry in ipairs(self.pieces)do
    local slot=slots[i]or{entry=entry,side=footSide(entry)};slots[i]=slot
    slot.localFrame=root:ToObjectSpace(entry.part.CFrame)
    if slot.side and not slot.rest then
     local frame=entry.frame or entry.offset;local scale=self.scale or self.worldScale or 1
     slot.rest=CFrame.new(frame.Position*(if self.scale then 1 else scale))*frame.Rotation
    end
   end
   self.model:SetAttribute("PoseCadence",cadence)
   self.poseSamples=(self.poseSamples or 0)+1
  end
  Bounds.begin(self);self.bodyHull=self.bodyHull or {};Bounds.begin(self.bodyHull)
  for _,slot in ipairs(self.poseSlots)do
   local entry=slot.entry;local part=entry.part;local frame=root*slot.localFrame
   frame=plant(self,slot,frame,root);part.CFrame=frame
   -- A temporary alpha ring uses a transparent carrier with visible decals.
   -- Its semantic visibility still contributes to the portrait bounds.
   if part.Transparency<1 or(entry.decals and not entry.renderHidden)then Bounds.include(self,frame,part.Size);if entry.role~="charm"then Bounds.include(self.bodyHull,frame,part.Size)end end
  end
  Bounds.finish(self);Bounds.finish(self.bodyHull);self.bodyBoundsFrame,self.bodyBoundsSize=self.bodyHull.rigBoundsFrame,self.bodyHull.rigBoundsSize
 end
 visual.poseDirty=true;visual:update(0);return visual
end
return Sampler
