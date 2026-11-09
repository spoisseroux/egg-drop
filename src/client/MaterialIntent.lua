-- The owner snapshot and exact receipt confirm cosmetic unlocks and selections.
local Shared=game:GetService("ReplicatedStorage").Shared
local Catalog=require(Shared.MaterialCatalog);local Eggs=require(Shared.EggCatalog)
local Intent={};Intent.__index=Intent
local messages={Insufficient="You need more Stars.",NeedStars="You need more Stars.",AllOwned="All materials owned",Full="All materials owned",Unavailable="Materials are not ready yet.",NotOwned="Choose a pet you own.",Locked="You do not own this material yet.",Stale="Your items changed. Choose again.",RevisionChanged="Your items changed. Choose again.",PendingResult="Store or use your saved egg first."}
local function matches(p,r)
 if type(r)~="table"or r.id~=p.value.id or r.action~=p.action or r.petId~=p.value.petId or type(r.revision)~="number"or r.revision<=p.revision or r.catalogVersion~=Catalog.CatalogVersion then return false end
 if p.action=="materialBuy"then return r.cost==Catalog.Cost and table.find(p.value.eligible,r.finishId)~=nil and r.resultId==r.id end
 if p.action=="materialAck"then return r.cost==0 and r.acknowledgedResultId==p.value.resultId end
 return r.cost==0 and r.finishId==p.value.finishId and r.selectedBefore==p.value.expectedFinish and r.selectedAfter==p.value.finishId and r.acknowledgedResultId==p.value.resultId
end
function Intent.new(d)return setmetatable({d=d,state={},status="Ready",alive=true},Intent)end
function Intent:notify()if self.alive and self.d.changed then self.d.changed(self)end end
function Intent:waitFor(pending)
 pending.waitEpoch=(pending.waitEpoch or 0)+1;local epoch=pending.waitEpoch
 local delay=self.d.delay or task.delay;delay(8,function()if self.alive and self.pending==pending and pending.waitEpoch==epoch then self.status="Retrying";self.message="Try again.";self:notify()end end)
end
function Intent:reconcile()
 local pending=self.pending;if not pending then return end
 local latest=self.state.lastMaterialResult
 local receipt=if latest and latest.id==pending.value.id then latest else pending.savedReceipt
 if matches(pending,receipt)and(self.state.revision or -1)>=receipt.revision then
  self.pending=nil;self.receipt=receipt;self.status="Saved";self.message=nil
 end
end
function Intent:update(state)
 if not self.alive then return false end
 if type(state)=="table"and type(state.revision)=="number"and type(self.state.revision)=="number"and state.revision<self.state.revision then return false end
 self.state=state or {};self:reconcile();self:notify();return true
end
function Intent:ready()
 if not self.alive or self.pending then return false end
 if self.d.available and not self.d.available()then return false end
 return not self.state.lastHatch and(not self.state.status or self.state.status=="Ready")
end
function Intent:begin(action,values)
 if not self:ready()then return false end
 local revision=self.state.revision or 0;local value=table.clone(values)
 value.id=tostring(revision)..":"..self.d.id();value.catalogVersion=Catalog.CatalogVersion
 self.pending={action=action,value=value,revision=revision};self.status="Pending";self.message=nil
 self:waitFor(self.pending);self:notify();self.d.send(action,value,revision);return true
end
function Intent:buy()
 if not self.state.materialAvailable then self.message=messages.Unavailable;self:notify();return false end
 if self.state.pendingHueResult or self.state.pendingMaterialResult then self.message=messages.PendingResult;self:notify();return false end
 local eligible=Catalog.remaining(self.state.materialUnlocks);table.sort(eligible)
 if #eligible==0 then self.message="All materials owned";self:notify();return false end
 if(self.state.nectar or 0)<Catalog.Cost then self.message=messages.Insufficient;self:notify();return false end
 return self:begin("materialBuy",{poolVersion=Catalog.PoolVersion,eligible=eligible})
end
function Intent:ack(resultId)
 local result=self.state.pendingMaterialResult;if not result or result.id~=resultId then return false end
 return self:begin("materialAck",{resultId=resultId})
end
function Intent:equip(petId,finishId,resultId)
 if not Eggs.isOwned(self.state.inventoryMask or 0,petId)or not Catalog.owns(self.state.materialUnlocks,finishId)then return false end
 local expected=(self.state.petMaterials or {})[petId]or Catalog.Default
 if expected==finishId and resultId==nil then return false end
 if resultId and(not self.state.pendingMaterialResult or self.state.pendingMaterialResult.id~=resultId or self.state.pendingMaterialResult.finishId~=finishId)then return false end
 return self:begin("materialEquip",{petId=petId,finishId=finishId,expectedFinish=expected,resultId=resultId})
end
function Intent:receive(packet)
 local pending=self.pending
 if not self.alive or type(packet)~="table"or not pending or packet.id~=pending.value.id or packet.action~=pending.action or packet.petId~=pending.value.petId then return false end
 if pending.savedReceipt and packet.status~="Saved"then return false end
 if packet.status=="Retrying"then self.status="Retrying";self.message="Try again."
 elseif packet.status=="Rejected"then self.pending=nil;self.status="Rejected";self.message=messages[packet.reason]or "Could not change this material. Try again."
 elseif packet.status=="Saved"then
  local receipt=packet.receipt
  if not matches(pending,receipt)then return false end
  pending.savedReceipt=receipt;self.status="Saved";self.message=nil;self:waitFor(pending);self:reconcile()
 else return false end
 self:notify();return true
end
function Intent:retry()
 if not self.pending or self.status~="Retrying"then return false end
 local pending=self.pending;self.status="Pending";self.message=nil;self:waitFor(pending);self:notify();self.d.send(pending.action,pending.value,pending.revision);return true
end
function Intent:destroy()self.alive=false;self.pending=nil end
return Intent
