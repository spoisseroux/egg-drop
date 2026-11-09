-- Transient ownership only: one existing actor, one exact bay claim, no rewards/transforms saved.
local Shared=game:GetService("ReplicatedStorage").Shared
local A=require(Shared.GardenActivity);local L=require(Shared.GardenCareLayout)
local Care={};Care.__index=Care
local kinds={carePickup=true,carePlace=true,careSetDown=true,careRelease=true,carePulse=true,careEquip=true}
local fields={"kind","seq","petId","characterId","petGeneration","actorGeneration","claimId","targetId","revision"}
local function equal(a,b)for _,key in ipairs(fields)do if a[key]~=b[key]then return false end end;return true end
local function horizontal(a,b)return Vector2.new(a.X-b.X,a.Z-b.Z).Magnitude end
local function integer(v)return type(v)=="number"and v==v and v%1==0 and v>=0 and v<=2147483647 end
function Care.valid(packet)
 return type(packet)=="table"and kinds[packet.kind]==true and integer(packet.seq)and packet.seq>0 and type(packet.petId)=="string"and integer(packet.characterId)and integer(packet.petGeneration)and integer(packet.actorGeneration)
end
function Care:replay(id,packet)
 local pending=self.equips[id]
 if pending and pending.packet.seq==packet.seq then return if equal(pending.packet,packet)then pending.response else self:response(packet,"Rejected","SequenceConflict")end
 local proofs=self.equipProofs[id];local proof=proofs and proofs.entries[packet.seq]
 if proof then return if equal(proof.packet,packet)then proof.response else self:response(packet,"Rejected","SequenceConflict")end
 local history=self.requests[id];local prior=history and history.entries[packet.seq]
 if prior then return if equal(prior.packet,packet)then prior.response else self:response(packet,"Rejected","SequenceConflict")end
 if history and packet.seq<=history.last then return self:response(packet,"Rejected","StaleSequence")end
end
function Care.new(garden,options)return setmetatable({garden=garden,options=options,requests={},equips={},equipProofs={},serial=0},Care)end
function Care.ownedMode(mode)return mode=="Carried"or mode=="Docked"or mode=="Placed"end
function Care:release(actor)
 local c=actor.care
 if c and self.bay and self.bay.ownerId==actor.ownerId and self.bay.id==c.claimId then self.bay=nil end
 actor.care=nil
end
function Care:hold(actor,input,state,position,claimId)
 self.garden:release(actor)
 actor.mode=state;actor.generation+=1;actor.path=nil;actor.actionId=self.garden:token()
 actor.behavior,actor.action="rest",if state=="Carried"then "carry"elseif state=="Docked"then "dock"else "placed"
 actor.from,actor.to=A.pack(position),A.pack(position);actor.startTime=self.options.now();actor.endTime=actor.startTime+1
 actor.yaw=if state=="Docked"then 0 else input.yaw or 0;actor.focusUntil=nil
 actor.care={state=state,claimId=claimId,holderId=actor.ownerId,characterId=actor.characterId,expiresAt=if state=="Carried"then self.options.now()+L.LeaseSeconds else nil}
 self.garden.dirty=true
end
function Care:follow(actor,input,point)
 self.garden:release(actor);actor.mode="Room";actor.from=A.pack(point);actor.to=A.pack(point);actor.path=nil
 self.garden:transition(actor,"follow",point,.2)
 actor.lastOwner=input.position;actor.idleSince=self.options.now()
end
function Care:tick(actor,input)
 local c=actor.care;if not c then return end
 local now=self.options.now()
 if c.state=="Carried"then
  actor.from,actor.to=A.pack(input.carryPosition or input.anchor),A.pack(input.carryPosition or input.anchor);actor.yaw=input.yaw or 0
  if now>(c.expiresAt or 0)then local point=self.options.place(input,input.anchor);if point then self:follow(actor,input,point)end end
 elseif c.state=="Docked"then
  if not self.bay or self.bay.id~=c.claimId or self.bay.ownerId~=actor.ownerId or now>self.bay.expiresAt or horizontal(input.position,L.Dock)>L.LeaveReach then
   local point=self.options.place(input,L.Dock)
   if point then self:follow(actor,input,point)else
    -- An unsafe floor never strands the bay: return to the live holder.
    self:hold(actor,input,"Carried",input.carryPosition or input.anchor)
   end
  end
 elseif c.state=="Placed"and horizontal(input.position,A.vector(actor.to))>L.PlacedReach then
  local point=self.options.place(input,A.vector(actor.to));if point then self:follow(actor,input,point)end
 end
end
function Care:response(packet,status,reason,claimId)
 return {kind=packet.kind,seq=packet.seq,status=status,reason=reason,claimId=claimId,petId=packet.petId,targetId=packet.targetId}
end
function Care:request(id,packet)
 if not Care.valid(packet)then return nil end
 local replay=self:replay(id,packet);if replay then return replay end
 local history=self.requests[id]
 if self.equips[id]and packet.kind=="careEquip"then return self:response(packet,"Rejected","Saving")end
 local actor,input=self.garden.actors[id],self.garden.inputs[id]
 local function reject(reason)return self:response(packet,"Rejected",reason)end
 if not actor or not input or not input.alive or not input.owned or input.mode~="Room"or packet.petId~=actor.petId or packet.characterId~=actor.characterId or packet.petGeneration~=actor.petGeneration or packet.actorGeneration~=actor.generation then return reject("IdentityChanged")end
 local response
 if packet.kind=="carePulse"then
  if actor.mode=="Carried"and actor.care and packet.claimId==nil then actor.care.expiresAt=self.options.now()+L.LeaseSeconds;return self:response(packet,"Accepted")end
  if not self.bay or self.bay.id~=packet.claimId or self.bay.ownerId~=id or actor.mode~="Docked"then return reject("ClaimChanged")end
  self.bay.expiresAt=self.options.now()+L.LeaseSeconds;return self:response(packet,"Accepted",nil,packet.claimId)
 end
 if packet.kind=="carePlace"then
  if actor.mode~="Carried"then return reject("NotCarrying")end
  if self.bay then return reject("BayOccupied")end
  if horizontal(input.position,L.Prompt)>L.Reach or math.abs(input.position.Y-L.Approach.Y)>5 or not self.options.validDock(input)then return reject("OutOfReach")end
  self.serial+=1;local token="bay-"..self.serial
  self:hold(actor,input,"Docked",L.Dock,token)
  self.bay={id=token,ownerId=id,petId=actor.petId,characterId=actor.characterId,petGeneration=actor.petGeneration,expiresAt=self.options.now()+L.LeaseSeconds}
  response=self:response(packet,"Accepted",nil,token)
 elseif packet.kind=="carePickup"then
  if actor.mode=="Carried"then return reject("AlreadyCarrying")end
  if actor.mode=="Docked"and(not actor.care or packet.claimId~=actor.care.claimId)then return reject("ClaimChanged")end
  local point=self.garden:position(actor,self.options.now())
  if horizontal(input.position,point)>L.Reach or math.abs(input.position.Y-point.Y)>5 then return reject("OutOfReach")end
  self:hold(actor,input,"Carried",input.carryPosition or input.anchor)
  response=self:response(packet,"Accepted")
 elseif packet.kind=="careSetDown"or packet.kind=="careRelease"then
  if not Care.ownedMode(actor.mode)then return reject("NotHeld")end
  if actor.mode=="Docked"and(not actor.care or packet.claimId~=actor.care.claimId)then return reject("ClaimChanged")end
  local point=self.options.place(input,self.garden:position(actor,self.options.now()))
  if not point then
   if packet.kind=="careRelease"then
    self:hold(actor,input,"Carried",input.carryPosition or self.garden:position(actor,self.options.now()))
   else return reject("NoDrySpace")end
  elseif packet.kind=="careSetDown"then self:hold(actor,input,"Placed",point)else self:follow(actor,input,point)end
  response=self:response(packet,"Accepted")
 elseif packet.kind=="careEquip"then
  if actor.mode~="Docked"or not self.bay or self.bay.id~=packet.claimId or self.bay.ownerId~=id or not self.options.equip then return reject("ClaimChanged")end
  response=self:response(packet,"Pending",nil,packet.claimId)
 else return reject("Unsupported")end
 local entry={packet=table.clone(packet),response=response,characterId=actor.characterId,petGeneration=actor.petGeneration,claimId=packet.claimId}
 if not history then history={last=0,entries={},order={}};self.requests[id]=history end
 history.last=packet.seq;history.entries[packet.seq]=entry;table.insert(history.order,packet.seq)
 if #history.order>32 then local oldest=table.remove(history.order,1);history.entries[oldest]=nil end
 if packet.kind=="careEquip"then
  local proofs=self.equipProofs[id]
  if not proofs then proofs={entries={},order={}};self.equipProofs[id]=proofs end
  proofs.entries[packet.seq]=entry;table.insert(proofs.order,packet.seq)
  if #proofs.order>32 then proofs.entries[table.remove(proofs.order,1)]=nil end
  self.equips[id]=entry
  local accepted,reason=self.options.equip(id,packet,entry)
  if not accepted then entry.response=self:response(packet,"Rejected",reason);self.equips[id]=nil end
 end
 return entry.response
end
function Care:complete(id,entry,status,petId,petGeneration)
 if self.equips[id]~=entry then return end;self.equips[id]=nil
 local actor,input=self.garden.actors[id],self.garden.inputs[id]
 if status=="Saved"and actor and input then
  local claim=self.bay
  local stay=claim and claim.id==entry.claimId and claim.ownerId==id and claim.characterId==entry.characterId and claim.petGeneration==entry.petGeneration and self.options.now()<=claim.expiresAt and actor.characterId==entry.characterId and actor.petGeneration==entry.petGeneration
  local point=if stay then L.Dock else self.options.place(input,input.anchor)
  self.garden:release(actor);actor.petId=petId;actor.petGeneration=petGeneration
  if stay then
   self:hold(actor,input,"Docked",point,claim.id);claim.petId,claim.petGeneration=petId,petGeneration;self.bay=claim
  elseif point then self:follow(actor,input,point)
  else self:hold(actor,input,"Carried",input.carryPosition or self.garden:position(actor,self.options.now()))end
 end
 entry.response=self:response(entry.packet,status,nil,if self.bay and self.bay.ownerId==id then self.bay.id else nil)
 if self.options.result then self.options.result(id,entry.response)end
end
function Care:snapshot()return self.bay and table.clone(self.bay)or nil end
return Care
