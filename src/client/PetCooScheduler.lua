-- One listener-owned incidental voice, driven by Room's existing update; never previews.
-- Retuned by FEEL-ALIVE-DIRECTION-2026-11-13 B2: a scheduled coo every 14-28 s by
-- day (40-70 s at night) at volume 0.30, voiced by mood (curious pet_coo_1, happy
-- pet_coo_2, sleepy pet_coo_3) at one pitch per family. Pets can also ask for a
-- coo (visual.pendingCoo = cue: a sit landing, a stretch or yawn ending, look-at-
-- owner, the owner back from the deck); those obey 6 s per pet and 2.5 s between
-- any two coos. The voice is AmbientAudio when it has the coo cues, otherwise the
-- old family cue on BoardAudio.
local Pose=require(script.Parent.PetCooPose)
local Coos={};Coos.__index=Coos;Coos.Range=28
Coos.Gain=.30;Coos.DayWait={14,28};Coos.NightWait={40,70};Coos.Night=.3
Coos.PetGap=6;Coos.AnyGap=2.5;Coos.RequestLife=1.5
-- One voice per family from the same three files (Bear, Ovelle, Tikket, Nuum).
Coos.Pitch={pip=1,puddle=.92,wick=1.12,orbit=.84}
Coos.Mood={curious="pet_coo_1",startled="pet_coo_1",pleased="pet_coo_2",joy="pet_coo_2",affectionate="pet_coo_2",content="pet_coo_2",sleepy="pet_coo_3",dozy="pet_coo_3"}
local quiet={wanderPause=true,nookRest=true,settle=true,rest=true,none=true}
local faces={neutral=true,sleepy=true,content=true,dozy=true}
local function visible(v,camera,listener)
 local distance=(v.origin-listener).Magnitude;if distance>=Coos.Range then return false end
 if camera then local point,shown=camera:WorldToViewportPoint(v.origin+Vector3.new(0,.7,0));if not shown or point.Z<=0 then return false end end
 return true,distance
end
local function eligible(v,camera,listener)
 if not v or v.destroyed or not v.worldContext or not v.model.Parent or not Pose.family(v.petId)then return false end
 if v.petting or v.focused or v.focusPose or v.gardenFocus or(v.affection or 0)>.15 or(v.gaitWeight or 0)>.08 then return false end
 if v.gardenAction and not quiet[v.gardenAction]then return false end
 if(v.greeting or 2)<1.2 then return false end
 if not faces[v.expression or "neutral"]then return false end
 return visible(v,camera,listener)
end
-- A requested coo may come with a non-resting face (joy, a stretch); it still needs
-- a real, visible, unpetted pet in range.
local function requestable(v,camera,listener)
 if not v or v.destroyed or not v.worldContext or not v.model.Parent or not Pose.family(v.petId)then return false end
 if v.petting or v.focused or v.focusPose or v.gardenFocus then return false end
 return visible(v,camera,listener)
end
function Coos.new(audio,options)
 options=options or {};local random=Random.new()
 return setmetatable({audio=audio,voice=options.voice,token={},spoken={},
  wait=options.wait or function(daylight)
   local band=if type(daylight)=="number"and daylight<Coos.Night then Coos.NightWait else Coos.DayWait
   return random:NextNumber(band[1],band[2])
  end},Coos)
end
-- Which voice speaks: AmbientAudio with the mood cues, else BoardAudio's family cue.
function Coos:speaker()
 local voice=self.voice
 if voice and not voice.destroyed and voice.has and voice:has("pet_coo_1")then return voice,true end
 return self.audio,false
end
function Coos.cue(visual,family,moodVoice,requested)
 if not moodVoice then return family.cueFallback,family.fallbackPitch end
 local cue=requested or Coos.Mood[visual.expression or "neutral"]or "pet_coo_1"
 local alias=Pose.family(visual.petId)
 local pitch=Coos.Pitch[visual.petId]
 if not pitch then for id,entry in pairs(Coos.Pitch)do if Pose.family(id)==alias then pitch=entry;break end end end
 return cue,pitch or 1
end
function Coos:cancel()
 if self.active then
  local speaker=self.active.speaker or self.audio
  speaker:stopOwner(self.token)
  self.active.visual.cooStart,self.active.visual.cooFamily=nil,nil;self.active.visual.poseDirty=true
 end
 self.active=nil
end
function Coos:speak(now,candidate,distance,owner,root,board,requested)
 local speaker,moodVoice=self:speaker()
 local family=Pose.family(candidate.petId)
 local gain=Coos.Gain*(if candidate==owner then 1 else math.clamp(1-distance/Coos.Range,0,1))
 local cue,pitch=Coos.cue(candidate,family,moodVoice,requested)
 if not speaker:play(cue,pitch,gain,self.token)then return false end
 candidate.cooStart,candidate.cooFamily=now,family;candidate.poseDirty=true
 self.spoken[candidate]=now;self.lastAt=now
 self.active={visual=candidate,model=candidate.model,generation=candidate.lastGeneration,untilTime=now+family.duration,root=root,board=board,speaker=speaker,requested=requested~=nil}
 return true
end
-- Requests: the first pending, eligible, unthrottled pet speaks; stale ones expire.
function Coos:requests(now,context,owner,visitors)
 local list={}
 if owner then table.insert(list,{visual=owner})end
 for _,entry in pairs(visitors or {})do if not entry.board or entry.board:GetAttribute("Mode")=="Room"then table.insert(list,entry)end end
 for _,entry in ipairs(list)do
  local v=entry.visual
  if v and v.pendingCoo then
   v.pendingCooAt=v.pendingCooAt or now
   if now-v.pendingCooAt>Coos.RequestLife then v.pendingCoo,v.pendingCooAt=nil,nil
   elseif not self.active and now-(self.lastAt or -math.huge)>=Coos.AnyGap and now-(self.spoken[v]or -math.huge)>=Coos.PetGap then
    local ok,distance=requestable(v,context.camera,context.listener)
    if ok then
     local cue=v.pendingCoo;v.pendingCoo,v.pendingCooAt=nil,nil
     if self:speak(now,v,if v==owner then 0 else distance,owner,entry.root,entry.board,cue)then return true end
    end
   end
  end
 end
 return false
end
function Coos:step(now,context,owner,visitors)
 if self.destroyed then return end
 local speaker=self:speaker()
 if self.listenerIdentity~=context.identity then self:cancel();self.nextAt=nil;self.listenerIdentity=context.identity end
 local enabled=context.enabled and context.listener~=nil and speaker.deviceActive~=false and speaker.group.Volume>0
  and not(speaker.petSpeechBusy and speaker:petSpeechBusy(self.token))
 if not enabled then
  self:cancel();self.nextAt=nil
  if owner then owner.pendingCoo=nil end
  for _,entry in pairs(visitors or {})do if entry.visual then entry.visual.pendingCoo=nil end end
  return
 end
 if self.active then
  local a=self.active;local check=if a.requested then requestable else eligible
  local valid=check(a.visual,context.camera,context.listener)
  if not valid or a.visual.model~=a.model or a.visual.lastGeneration~=a.generation or(a.root and not a.root.Parent)or(a.board and a.board:GetAttribute("Mode")~="Room")or now>=a.untilTime then self:cancel()end
  return
 end
 if self:requests(now,context,owner,visitors)then return end
 -- The listener's quiet-room interval survives ordinary pet walking. At a due
 -- beat no eligible speaker means skip, never wait/queue for a pause to end.
 if not self.nextAt then self.nextAt=now+self.wait(context.daylight);return end
 if now<self.nextAt then return end
 self.nextAt=now+self.wait(context.daylight)
 if now-(self.lastAt or -math.huge)<Coos.AnyGap then return end
 local candidate,distance,candidateRoot,candidateBoard
 if eligible(owner,context.camera,context.listener)then candidate,distance=owner,0 else
  for _,entry in pairs(visitors or {})do if not entry.board or entry.board:GetAttribute("Mode")=="Room"then
   local allowed,gap=eligible(entry.visual,context.camera,context.listener)
   if allowed and(not candidate or gap<distance)then candidate,distance,candidateRoot,candidateBoard=entry.visual,gap,entry.root,entry.board end
  end end
 end
 if not candidate then return end
 self:speak(now,candidate,distance,owner,candidateRoot,candidateBoard)
end
function Coos:destroy()if self.destroyed then return end;self:cancel();self.destroyed=true;self.nextAt=nil end
Coos.eligible=eligible
Coos.requestable=requestable
return Coos
