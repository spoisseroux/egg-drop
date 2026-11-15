-- Say hello to another player's pet (QA v685 R6; VISITOR-PET-SCOPE 2026-11-14).
-- A separate, reward-free social action: it never touches PetContact, the wallet, bond
-- XP, quests or the save. The client names a target (owner, pet, character and pet
-- generation); every position, the consent flag and the busy state are the server's own.
--
-- options:
--   now()                 server clock
--   garden                GardenState (actors, inputs, position)
--   viewer(viewerId)      -> Vector3 of a live viewer character, or nil
--   allowed(ownerId)      -> false when the owner turned greetings off
--   clear(from,to)        -> false when something solid is between viewer and pet (optional)
--   publish(ownerId,hello) the accepted hello ({id,from,at,petId,petGeneration}), or nil to cancel
local Rules=require(game:GetService("ReplicatedStorage").Shared.PetHelloRules)
local Hello={};Hello.__index=Hello

function Hello.new(options)
 return setmetatable({options=options,serial=0,lastRequest={},viewerAt={},targetAt={},pairAt={},active={}},Hello)
end
local function reply(packet,status,reason,extra)
 local result={seq=if type(packet)=="table"and Rules.whole(packet.seq,1,2147483647)then packet.seq else 0,status=status,reason=reason}
 if extra then for key,value in pairs(extra)do result[key]=value end end
 return result
end
-- Returns a reply table, or nil when the request is dropped (spam closer than MinGap).
function Hello:request(viewerId,packet)
 local options=self.options;local now=options.now()
 if now-(self.lastRequest[viewerId]or -math.huge)<Rules.MinGap then return nil end
 self.lastRequest[viewerId]=now
 if not Rules.validPacket(packet)then return reply(packet,"Rejected","Malformed")end
 local ownerId=packet.ownerId
 if ownerId==viewerId then return reply(packet,"Rejected","Own")end
 local garden=options.garden
 local actor,input=garden.actors[ownerId],garden.inputs[ownerId]
 -- A replaced pet, a respawned owner or a pet swap refuses with "Stale": the card re-reads.
 if not actor or not input or not input.alive or not input.owned or actor.petId~=packet.petId or input.petId~=actor.petId
  or actor.characterId~=packet.characterId or input.characterId~=actor.characterId
  or actor.petGeneration~=packet.petGeneration or(input.petGeneration or 0)~=actor.petGeneration then return reply(packet,"Rejected","Stale")end
 if options.allowed and options.allowed(ownerId)==false then return reply(packet,"Rejected","Off")end
 local from=options.viewer(viewerId)
 if typeof(from)~="Vector3"then return reply(packet,"Rejected","Unavailable")end
 local at=garden:position(actor,now)
 if typeof(at)~="Vector3"or Vector2.new(from.X-at.X,from.Z-at.Z).Magnitude>Rules.HelloRange or math.abs(from.Y-at.Y)>Rules.HeightReach then return reply(packet,"Rejected","Far")end
 if not Rules.free(actor,now)then return reply(packet,"Rejected","Busy")end
 if options.clear and options.clear(from,at)==false then return reply(packet,"Rejected","Blocked")end
 local pairKey=viewerId..":"..ownerId
 local wait=math.max((self.viewerAt[viewerId]or -math.huge)+Rules.ViewerCooldown,(self.targetAt[ownerId]or -math.huge)+Rules.TargetCooldown,
  (self.pairAt[pairKey]or -math.huge)+Rules.PairCooldown)-now
 if wait>0 then return reply(packet,"Rejected","Cooldown",{retryIn=math.ceil(wait*10)/10})end
 self.serial+=1
 self.viewerAt[viewerId],self.targetAt[ownerId],self.pairAt[pairKey]=now,now,now
 local hello={id=self.serial,from=viewerId,at=now,petId=actor.petId,petGeneration=actor.petGeneration,characterId=actor.characterId,generation=actor.generation}
 self.active[ownerId]=hello
 if options.publish then options.publish(ownerId,{id=hello.id,from=viewerId,at=now,petId=hello.petId,petGeneration=hello.petGeneration})end
 return reply(packet,"Accepted",nil,{id=hello.id,at=now,duration=Rules.Duration})
end
-- The owner always wins: a running hello ends when the pet is replaced, the owner starts
-- anything with it (focus, carry, care, park, toy), or greetings are turned off.
function Hello:step()
 local options=self.options;local now=options.now()
 for ownerId,hello in pairs(self.active)do
  local actor=options.garden.actors[ownerId]
  local over=now-hello.at>=Rules.Duration
  local broken=not actor or actor.petId~=hello.petId or actor.petGeneration~=hello.petGeneration or actor.characterId~=hello.characterId
   or actor.mode~="Room"or actor.care~=nil or actor.pairId~=nil or actor.toyActionId~=nil
   or(type(actor.park)=="table"and actor.park.state~="idle")or(options.allowed and options.allowed(ownerId)==false)
  if over or broken then
   self.active[ownerId]=nil
   -- A finished wave leaves its record (clients time it out); a broken one is withdrawn.
   if broken and not over and options.publish then options.publish(ownerId,nil)end
  end
 end
end
function Hello:cancel(ownerId)
 if self.active[ownerId]then self.active[ownerId]=nil;if self.options.publish then self.options.publish(ownerId,nil)end end
end
-- Forget a leaving player and expire old pair entries (bounded memory).
function Hello:remove(userId)
 self:cancel(userId)
 self.lastRequest[userId],self.viewerAt[userId],self.targetAt[userId]=nil,nil,nil
 local now=self.options.now();local prefix,suffix=userId..":",":"..userId
 for key,at in pairs(self.pairAt)do
  if now-at>=Rules.PairCooldown or key:sub(1,#prefix)==prefix or key:sub(-#suffix)==suffix then self.pairAt[key]=nil end
 end
end
return Hello
