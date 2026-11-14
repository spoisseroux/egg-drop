-- The UI handoff asks the existing cosmetic owner for an opportunity. Its
-- confirmation is an actual active prop on the same clock as normal rendering.
local Host={}
function Host.identity(actor)
 return actor and actor.characterId~=nil and actor.petGeneration~=nil
  and(tostring(actor.characterId)..":"..tostring(actor.petGeneration))or nil
end
function Host.ready(visual,actor,flight)
 local identity=Host.identity(actor)
 return visual~=nil and not visual.destroyed and visual.personalToyId==flight.toyId
  and visual.personalPlayEnabled==true and visual.personalOpportunityReady==true
  and actor~=nil and actor.mode=="Room"and not actor.park and not actor.care
  and identity~=nil and visual.personalActorIdentity==identity
end
function Host.try(guide,visual,toyId,Play,serverNow)
 local flight=guide.flight
 if not flight or flight.toyId~=toyId or not visual or visual.destroyed or visual.personalToyId~=toyId then return false end
 if flight.actorIdentity and visual.personalActorIdentity~=flight.actorIdentity then return false end
 local clock=visual.cosmeticTime
 local now=if type(clock)=="number"and clock==clock and math.abs(clock)<math.huge then clock else serverNow
 local observed=Play.sample(visual,now)
 if not(observed~=nil and visual.personalToyActive==true)then
  if not visual.personalQuietSince then return false end
  if not flight.opportunityOffered then
   flight.opportunityOffered=true;visual.personalNextOpportunity=now
  end
  observed=Play.sample(visual,now)
 end
 local playing=observed~=nil and visual.personalToyActive==true
 if playing and visual.model then visual.model:SetAttribute("OnboardingToyBeat",toyId)end
 return playing
end
return Host
