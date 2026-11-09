-- One captured toy operation; exact bounded retries, no jobs or rewards.
local Intent={};Intent.__index=Intent
local sequence=0
local terminal={toyStart="Started",toyJoin="Joined",toyCancel="Cancelled"}
function Intent.new(send)return setmetatable({send=send},Intent)end
function Intent:request(kind,actor,actionId)
 if self.pending or not terminal[kind]or not actor then return false end
 sequence+=1
 local packet=table.freeze({kind=kind,seq=sequence,petId=actor.petId,characterId=actor.characterId,petGeneration=actor.petGeneration,actorGeneration=actor.generation,actionId=actionId})
 self.pending={packet=packet,age=0,retried=false};self.send(packet);return true
end
function Intent:result(packet)
 local p=self.pending
 if type(packet)~="table"or not p or packet.seq~=p.packet.seq or packet.kind~=p.packet.kind then return false end
 if packet.status~=terminal[p.packet.kind]and packet.status~="Rejected"then return false end
 self.lastResult=packet;self.pending=nil;return true
end
function Intent:step(dt)
 local p=self.pending;if not p then return end;p.age+=dt
 if p.age>=.75 and not p.retried then p.retried=true;self.send(p.packet)end
 if p.age>=2 then p.retryReady=true end
end
function Intent:retry()
 local p=self.pending;if not p or not p.retryReady then return false end
 p.age=0;p.retried=true;p.retryReady=false;self.send(p.packet);return true
end
function Intent:abandon()self.pending=nil end
return Intent
