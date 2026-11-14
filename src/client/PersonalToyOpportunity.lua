-- Shared client cosmetic opportunity from the published actor only. Never extends
-- a server action, moves a pet, reserves equipment or changes gameplay state.
local Opportunity={}
local function finite(n)return type(n)=="number"and n==n and math.abs(n)<math.huge end
local function position(p)
 if typeof(p)=="Vector3"then return if finite(p.X)and finite(p.Y)and finite(p.Z)then p else nil end
 if type(p)=="table"and finite(p[1])and finite(p[2])and finite(p[3])then return Vector3.new(p[1],p[2],p[3])end
 return nil
end
function Opportunity.fromActor(actor,now)
 if type(actor)~="table"or not finite(now)or actor.mode~="Room"or not finite(actor.endTime)
  or actor.park~=nil or actor.parkId~=nil or actor.care~=nil or actor.peerId~=nil or actor.pairId~=nil
  or actor.toyRole~=nil or actor.toyReservation~=nil or actor.toyStartTime~=nil or actor.contact~=nil
  or actor.focus==true or actor.focused==true or actor.carried==true then return nil end
 local deadline,duration,quiet,guard,rest
 if actor.behavior=="follow"and(actor.action==nil or actor.action=="follow")then
  deadline,duration,quiet,guard,rest=actor.endTime+3.5,1.8,.75,.15,false
 elseif actor.behavior=="rest"and(actor.action=="wanderPause"or actor.action=="nookRest")then
  local a,b=position(actor.from),position(actor.to)
  if not a or not b or(a-b).Magnitude>.03 or not finite(actor.startTime)then return nil end
  if actor.action=="nookRest"and now-actor.startTime<.35 then return nil end
  deadline,duration,quiet,guard,rest=actor.endTime,.90,.15,.10,true
 else return nil end
 if deadline-now<=.05 then return nil end
 local token=tostring(actor.characterId)..":"..tostring(actor.petGeneration)..":"..tostring(actor.generation)..":"..tostring(actor.actionId)
 return deadline,duration,quiet,guard,rest,token
end
function Opportunity.apply(visual,actor,now)
 local deadline,duration,quiet,guard,rest,token=Opportunity.fromActor(actor,now)
 visual.personalOpportunityManaged=true
 visual.personalOpportunityReady=deadline~=nil
 visual.personalIdleUntil=deadline or 0
 visual.personalOpportunityDuration=duration or 1.8
 visual.personalOpportunityQuiet=quiet or .75
 visual.personalOpportunityGuard=guard or .15
 visual.personalRestAllowed=rest==true
 visual.personalOpportunityToken=token
 return deadline~=nil
end
return Opportunity
