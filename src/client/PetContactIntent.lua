-- Presentation-side lease owner. The server alone times, rolls and saves awards.
local Intent={};Intent.__index=Intent
function Intent.new(d)return setmetatable({d=d,generation=0,seen={},ring={},cursor=0,alive=true},Intent)end
-- QA Q2.7: a Saved receipt for a pet the owner just let go of still shows (the save
-- often lands a beat after the release). Kept until the next touch or this long.
Intent.LateSeconds=4
function Intent:cancel()
 local a=self.active;self.active=nil
 if a and a.lease then self.d.send("end",a.lease);self.recent={active=a,untilAt=self.d.now()+Intent.LateSeconds}end
end
function Intent:begin(petId,context)
 if not self.alive then return false end
 self:cancel();self.recent=nil;self.generation+=1
 self.active={generation=self.generation,petId=petId,context=context,nextPulse=0}
 self.d.send("begin",{requestGeneration=self.generation,petId=petId});return true
end
function Intent:current(a)return self.alive and self.active==a and self.d.eligible(a.context)end
function Intent:receive(packet)
 if not self.alive or type(packet)~="table"then return false end
 local a=self.active
 local matching=a and packet.requestGeneration==a.generation and packet.petId==a.petId and self:current(a)
 if packet.status=="Saved"and not matching then
  local r=self.recent
  if r and self.d.now()<=r.untilAt and r.active.lease and packet.leaseId==r.active.lease and packet.requestGeneration==r.active.generation and packet.petId==r.active.petId then
   a=r.active;matching=true;self.recent=nil
  end
 end
 if packet.status=="Saved"then
  local r=packet.receipt
  if not matching or packet.leaseId~=a.lease or not a.lease or type(r)~="table"or type(r.id)~="string"or r.id==""or r.petId~=a.petId or type(r.sequence)~="number"or r.sequence%1~=0 or r.sequence<1 or type(r.day)~="string"or self.seen[r.id]then return false end
  self.cursor=self.cursor%64+1;local old=self.ring[self.cursor];if old then self.seen[old]=nil end
  self.ring[self.cursor]=r.id;self.seen[r.id]=true
  self.d.saved(r,a.context);return true
 end
 if packet.granted==true and type(packet.leaseId)=="string"and packet.leaseId~=""then
  if not matching or a.denied or(a.lease and a.lease~=packet.leaseId)then self.d.send("end",packet.leaseId);return false end
  a.lease=packet.leaseId;return true
 end
 if matching and packet.granted==false then
  a.denied=true;a.lease=nil
  -- QA Q2.7: the day's five are used: say so (once per touch).
  if packet.reason=="DailyCap"and self.d.capped then self.d.capped(a.context)end
 end
 return false
end
function Intent:step()
 local a=self.active;if not a then return end
 if not self:current(a)then self:cancel();return end
 local now=self.d.now()
 if a.lease and now>=a.nextPulse then a.nextPulse=now+1/3;self.d.send("pulse",a.lease)end
end
function Intent:destroy()if not self.alive then return end;self:cancel();self.alive=false end
return Intent
