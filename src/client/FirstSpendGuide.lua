-- Optional first toy handoff. Snapshots/typed ToyIntent prove saves; this module
-- never changes balance, receipts, equipment or coach bits itself.
local Shared=game:GetService("ReplicatedStorage").Shared
local Toys=require(Shared.ToyCatalog)
local Eggs=require(Shared.EggCatalog)
local Guide={};Guide.__index=Guide
local Pets=require(Shared.PetCatalog)
-- The starter is the catalogue's first active pet (never a pet id written here).
local function ownsStarter(state)return Eggs.isOwned(state.inventoryMask or 0,(Pets.active[1]or Pets[1]).id)end
local function ownedToys(state)
	local n=0;for _,id in ipairs(Toys.PaidOrder)do if Toys.owns(state.toyUnlocks,id)then n+=1 end end;return n
end
local function purchaseProof(state)
	local pending,receipt=state.pendingToyResult,state.lastToyResult
	if type(pending)~="table"or type(receipt)~="table"then return nil end
	if type(pending.id)~="string"or pending.id==""or type(receipt.revision)~="number"or receipt.revision~=receipt.revision
		or type(receipt.balanceBefore)~="number"or type(receipt.balanceAfter)~="number"or receipt.balanceAfter~=receipt.balanceBefore-Toys.Cost
		or pending.id~=receipt.id or receipt.action~="toyBuy"or receipt.resultId~=pending.id or receipt.toyId~=pending.toyId
		or receipt.cost~=Toys.Cost or receipt.catalogVersion~=Toys.CatalogVersion or pending.catalogVersion~=Toys.CatalogVersion
		or receipt.revision~=pending.revision or type(state.revision)~="number"or state.revision<receipt.revision
		or not Toys.known(pending.toyId)or not Toys.owns(state.toyUnlocks,pending.toyId)then return nil end
	return pending
end
function Guide.stage(state,context)
	state,context=state or {},context or {}
	if not ownsStarter(state)then return "welcome"end
	if state.lastHatch then return "reveal"end
	if context.eligible~=true or(state.status and state.status~="Ready")then return "free"end
	local count=ownedToys(state)
	if count==1 then
		local proof=purchaseProof(state)
		if proof then return "receipt",proof end
	end
	if count>0 then return "done"end
	if state.pendingHueResult or state.pendingMaterialResult or state.pendingFeatureResult then return "free"end
	return if(state.nectar or 0)>=Toys.Cost then "purchase"else "earn"
end
function Guide.new(d)
	return setmetatable({d=d,state={},context={},generation=0,alive=true},Guide)
end
-- Call from EVERY explicit navigation route/tab/back/close/equip-pet change.
-- Internal handoff calls set an owned token rather than cancelling themselves.
function Guide:routeChanged(kind,reason)
	local flight=self.flight;local pending=self.d.intent and self.d.intent.pending;local value=pending and pending.value
	-- Hue's snapshot callback can close its completed receipt before ToyIntent
	-- consumes that same snapshot. This exact pending equip still owns the flight;
	-- only Saved + snapshot reconciliation below may advance it into the garden.
	if kind=="receipt-reconciled"and reason=="receipt-finished"and flight and self:valid(flight)
		and flight.phase=="equip"and type(flight.operationId)=="string"and pending and pending.action=="toyEquip"and type(value)=="table"
		and value.id==flight.operationId and value.petId==flight.petId and value.toyId==flight.toyId and value.resultId==flight.resultId then
		return self.generation
	end
	self.generation+=1;self.flight=nil;return self.generation
end
function Guide:valid(flight)return self.alive and self.flight==flight and self.generation==flight.generation end
function Guide:update(state,context)
	if not self.alive then return end
	if self.state.revision and state and state.revision and state.revision<self.state.revision then return end
	self.state,self.context=state or {},context or self.context
	local stage,proof=Guide.stage(self.state,self.context)
	self.stage,self.proof=stage,proof
	local flight=self.flight
	if not flight then return stage,proof end
	local receipt=self.state.lastToyResult
	-- Typed Intent already combines packet+snapshot proof; additionally bind exact
	-- operation, pet, toy and ack so an unrelated equip never starts navigation.
	if flight.phase=="equip"and self.d.intent.status=="Saved"and not self.d.intent.pending
		and receipt and receipt.id==flight.operationId and receipt.action=="toyEquip"and receipt.petId==flight.petId
		and receipt.toyId==flight.toyId and receipt.acknowledgedResultId==flight.resultId
		and((self.state.petToys or {})[flight.petId]or Toys.Default)==flight.toyId
		and(not self.state.pendingToyResult or self.state.pendingToyResult.id~=flight.resultId)then
		flight.phase="room"
		if self.d.enterRoom then self.d.enterRoom(flight.generation)end
	elseif self.d.intent.status=="Rejected"then self.flight=nil end
	return stage,proof
end
function Guide:openEggs()
	if not self.alive or self.stage~="purchase"or not self.d.openEggs then return false end
	-- Merely selects Toy Egg. Catalog choices/Back and purchase confirmation remain.
	return self.d.openEggs("toy")==true
end
function Guide:give(petId)
	if not self.alive or self.flight or self.stage~="receipt"or not self.proof then return false end
	if not Eggs.isOwned(self.state.inventoryMask or 0,petId)then return false end
	local proof=self.proof
	local actorIdentity=if self.d.actorIdentity then self.d.actorIdentity()else nil
	if self.d.actorIdentity and not actorIdentity then return false end
	local generation=self:routeChanged()
	local flight={generation=generation,phase="equip",petId=petId,toyId=proof.toyId,resultId=proof.id,
  actorIdentity=actorIdentity}
	self.flight=flight
	if not self.d.intent:equip(petId,proof.toyId,proof.id)then self.flight=nil;return false end
	local pending=self.d.intent.pending
	if not pending or pending.action~="toyEquip"then self.flight=nil;return false end
	flight.operationId=pending.value.id
	return true
end
-- Readiness, pet and mode come from current host/server state, never a timer.
function Guide:step(context)
	local flight=self.flight
	if not flight or not self:valid(flight)or flight.phase~="room"then return false end
	if flight.actorIdentity and context.actorIdentity and flight.actorIdentity~=context.actorIdentity then self:routeChanged();return false end
	if context.mode~="Room"or not context.ready or context.petId~=flight.petId or not context.actorReady then return false end
	-- An eligible host frame is only an opportunity. The normal play owner must
	-- confirm that it actually started; a quiet-window miss keeps the flight alive.
	flight.phase="playing"
	local played=self.d.play and self.d.play(flight.petId,flight.toyId,flight.generation)==true
	if not self:valid(flight)then return false end
	if not played then flight.phase="room";return false end
	flight.phase="done";self.flight=nil;return true
end
function Guide:destroy()self:routeChanged();self.alive=false end
Guide.purchaseProof=purchaseProof
return Guide
