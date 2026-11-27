-- Paint pots (PAINT-SHINE-DRESS-PLAN): the client side of `potBuy`. One buy in flight; a captured operation is retried
-- verbatim (same id); only a saved revision counts. Replies arrive on Remotes.PotResult, snapshots through update().
-- Buy and paint (architect review, answer 3): two saves chained here. `buy(itemId, then)` keeps `then` and calls it
-- once the pot is saved AND a snapshot at or past the receipt's revision has arrived (so the next hueUse carries the
-- new counts and revision). A failure between leaves a bought jar, never a loss.
-- NotReady (the switch flipped off) clears the purchase in flight and any chained paint.
local Shared=game:GetService("ReplicatedStorage"):WaitForChild("Shared")
local Pots=require(Shared:WaitForChild("PaintPotCatalog"))
local Copy=require(Shared:WaitForChild("UICopy"))
local Intent={};Intent.__index=Intent
local function reasonText(reason)
	local key="paint.reason."..tostring(reason)
	return if Copy.has(key)then Copy.get(key)else Copy.get("paint.reason.OperationConflict")
end
function Intent.new(d)return setmetatable({d=d or {},state={},status="Ready"},Intent)end
function Intent:notify()if self.d.changed then self.d.changed(self)end end
function Intent:finish(receipt)
	local p=self.pending;self.pending=nil;self.status="Saved";self.message=nil;self.receipt=receipt
	local thenDo=p and p.thenDo
	if thenDo then(self.d.defer or task.defer)(thenDo,receipt)end -- deferred: never inside the snapshot that settled it
end
function Intent:reconcile()
	local p=self.pending;if not p then return end
	local latest=self.state.lastPotResult
	local receipt=if type(latest)=="table"and latest.id==p.value.id then latest else p.savedReceipt
	if receipt and type(receipt.revision)=="number"and(self.state.revision or -1)>=receipt.revision then self:finish(receipt)end
end
function Intent:update(state)
	if type(state)=="table"and type(state.revision)=="number"and type(self.state.revision)=="number"and state.revision<self.state.revision then return false end
	self.state=state or {};self:reconcile();self:notify();return true
end
-- Pure: the reason a buy cannot start now, or nil. The wallet is the published one; the save's NeedStars is the check.
function Intent.blocked(state,itemId,pending)
	state=state or {}
	if pending then return "Busy"end
	if not Pots.isItem(itemId)then return "InvalidPot"end
	if state.lastHatch then return "RevealPending"end
	if state.status and state.status~="Ready"then return "Busy"end
	if(state.nectar or 0)<Pots.Price then return "NeedStars"end
	return nil
end
function Intent:buy(itemId,thenDo)
	local why=Intent.blocked(self.state,itemId,self.pending)
	if why then self.reason=why;self.message=reasonText(why);self:notify();return false end
	local revision=self.state.revision or 0
	local value={id=tostring(revision)..":pot-"..tostring(self.d.id and self.d.id()or os.clock()),itemId=itemId,price=Pots.Price}
	self.pending={action="potBuy",value=value,revision=revision,thenDo=thenDo};self.status="Pending";self.message=nil;self.reason=nil
	self:notify()
	if self.d.send then self.d.send("potBuy",value,revision)end
	return true
end
function Intent:receive(packet)
	local p=self.pending;if type(packet)~="table"or not p then return false end
	if packet.id~=p.value.id or packet.action~="potBuy"then return false end
	if p.savedReceipt and packet.status~="Saved"then return false end
	if packet.status=="Retrying"then self.status="Retrying";self.message=reasonText("Retrying")
	elseif packet.status=="Rejected"then
		-- NotReady included: the purchase in flight and its chained paint are dropped.
		self.pending=nil;self.status="Rejected";self.reason=packet.reason;self.message=reasonText(packet.reason)
	elseif packet.status=="Saved"then
		local r=packet.receipt
		if type(r)~="table"or r.id~=p.value.id or type(r.revision)~="number"then return false end
		p.savedReceipt=r;self.status="Saved";self.message=nil;self:reconcile()
	else return false end
	self:notify();return true
end
function Intent:retry()
	if not self.pending or self.status~="Retrying"then return false end
	local p=self.pending;self.status="Pending";self.message=nil;self:notify()
	if self.d.send then self.d.send(p.action,p.value,p.revision)end
	return true
end
-- Drop a chained paint (the screen closed, the pet or target changed); the pot itself still saves.
function Intent:cancelChain()if self.pending then self.pending.thenDo=nil end end
return Intent
