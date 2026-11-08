-- Server-observable contact continuity, not proof of human touch on a client rig.
-- All clocks/RNG/identity/state/storage and wire delivery are injected for tests.
local Contact={}
Contact.__index=Contact
Contact.Timeout=1.05
Contact.PulseInterval=.25
Contact.OpportunitySeconds=12
local function finiteVector(value)
	return typeof(value)=="Vector3"and value.X==value.X and value.Y==value.Y and value.Z==value.Z
		and math.abs(value.X)<math.huge and math.abs(value.Y)<math.huge and math.abs(value.Z)<math.huge
end
function Contact.new(options)
	return setmetatable({options=options,lastGeneration=0,lastBegin=-math.huge,lastReply=-math.huge,nextOpportunity=0},Contact)
end
function Contact:reply(packet,bounded)
	local now=self.options.now()
	if bounded and now-self.lastReply<.25 then return end
	self.lastReply=now;self.options.emit(packet)
end
function Contact:valid(lease,state,proofId)
	if not state or state.mode~="Room"or state.closing or state.conflict or not state.alive or not state.owned
		or state.petId~=lease.petId or state.character~=lease.character or state.root~=lease.root
		or state.epoch~=lease.epoch or not finiteVector(state.position)then return false end
	local delta=state.position-lease.startPosition
	if Vector2.new(delta.X,delta.Z).Magnitude>2 or math.abs(delta.Y)>2 or(state.position-lease.anchor).Magnitude>7 then return false end
	local ownedId=proofId or(self.issued and self.issued.lease==lease and self.issued.candidate.id)
	local ownPending=ownedId and state.pendingId==ownedId
	local cleanReady=state.ready and not state.busy and state.pendingId==nil
	return cleanReady or(ownPending and(state.status=="Ready"or state.status=="Retrying"))
end
function Contact:cancel(reason)
	local lease=self.lease;self.lease=nil
	if lease then self:reply({granted=false,requestGeneration=lease.generation,leaseId=lease.id,petId=lease.petId,reason=reason})end
end
function Contact:reconcile()
	if self.destroyed or not self.issued then return end
	local issued=self.issued;local state=self.options.read()
	local receipt=state and state.lastPetAward
	if receipt and receipt.id==issued.candidate.id and receipt.sequence==issued.candidate.sequence
		and receipt.day==issued.candidate.day and receipt.petId==issued.candidate.petId then
		self.issued=nil -- Consume before any delivery callback can re-enter.
		local lease=self.lease
		if lease==issued.lease and self.options.now()-lease.lastPulse<=Contact.Timeout and self:valid(lease,state,issued.candidate.id)then
			lease.windowStart=self.options.now()
			self:reply({status="Saved",requestGeneration=lease.generation,leaseId=lease.id,petId=lease.petId,
				receipt={id=receipt.id,sequence=receipt.sequence,day=receipt.day,petId=receipt.petId}})
		end
	elseif state and not state.busy and state.pendingId~=issued.candidate.id then
		self.issued=nil -- A definitive refusal, expiry, or unrecoverable fence loss.
		if self.lease==issued.lease then self.lease.windowStart=self.options.now()end
	end
end
function Contact:update()
	if self.destroyed then return end
	self:reconcile()
	local lease=self.lease;if not lease then return end
	if self.options.now()-lease.lastPulse>Contact.Timeout then self:cancel("Expired")
	elseif not self:valid(lease,self.options.read())then self:cancel("Unavailable")end
end
function Contact:begin(packet)
	if self.destroyed then return false end
	self:update()
	local valid=type(packet)=="table"and type(packet.requestGeneration)=="number"and packet.requestGeneration%1==0
		and packet.requestGeneration>=1 and packet.requestGeneration<=2147483647
		and type(packet.petId)=="string"and #packet.petId<=100
	if valid then for key in pairs(packet)do if key~="requestGeneration"and key~="petId"then valid=false end end end
	if not valid then self:reply({granted=false,requestGeneration=0,reason="Malformed"},true);return false end
	local now=self.options.now();local generation=packet.requestGeneration
	if generation==self.lastGeneration and self.lease and self.lease.petId==packet.petId then
		self:reply(self.lease.grant,true);return true
	end
	if generation<=self.lastGeneration or now-self.lastBegin<.5 then
		self:reply({granted=false,requestGeneration=generation,petId=packet.petId,reason="StaleOrLimited"},true);return false
	end
	self.lastGeneration,self.lastBegin=generation,now;self:cancel("Replaced")
	local state=self.options.read()
	if not state or not state.ready or state.busy or state.pendingId or state.conflict or state.closing or state.mode~="Room"or not state.alive
		or not state.owned or state.petId~=packet.petId or not finiteVector(state.position)then
		self:reply({granted=false,requestGeneration=generation,petId=packet.petId,reason="Unavailable"},true);return false
	end
	local anchor=self.options.anchor(state)
	if not finiteVector(anchor)or(state.position-anchor).Magnitude>7 then
		self:reply({granted=false,requestGeneration=generation,petId=packet.petId,reason="OutOfReach"},true);return false
	end
	local lease={id=self.options.guid(),generation=generation,petId=state.petId,character=state.character,
		root=state.root,epoch=state.epoch,anchor=anchor,startPosition=state.position,windowStart=now,lastPulse=now}
	lease.grant={granted=true,requestGeneration=generation,leaseId=lease.id,petId=lease.petId}
	self.lease=lease;self:reply(lease.grant);return true
end
function Contact:pulse(id)
	if self.destroyed or type(id)~="string"or #id>100 then return false end
	local lease=self.lease
	if not lease or lease.id~=id then return false end
	local now=self.options.now()
	if now-lease.lastPulse<Contact.PulseInterval then return false end
	self:update();if self.lease~=lease then return false end
	lease.lastPulse=now
	if self.issued then return true end
	local state=self.options.read()
	if state.capReached then self:cancel("DailyCap");return true end
	if now-lease.windowStart<Contact.OpportunitySeconds or now<self.nextOpportunity then return true end
	-- Consume the window and player spacing BEFORE RNG or a yielding write.
	lease.windowStart=now;self.nextOpportunity=now+Contact.OpportunitySeconds
	if self.options.random()>=.5 then return true end
	local candidate=self.options.candidate(lease)
	self.issued={lease=lease,candidate=candidate}
	self.options.award(candidate)
	self:reconcile()
	return true
end
function Contact:finish(id)
	if self.destroyed or type(id)~="string"then return false end
	if self.lease and self.lease.id==id then self:cancel("Ended");return true end
	return false
end
function Contact:destroy()
	self.destroyed=true;self.lease=nil;self.issued=nil
end
return Contact
