-- Typed once-rolled toy operations. A packet and owner snapshot jointly prove save.
local Shared=game:GetService("ReplicatedStorage").Shared
local Catalog=require(Shared.ToyCatalog);local Eggs=require(Shared.EggCatalog)
local Intent={};Intent.__index=Intent
local function pendingResult(s)return s.lastHatch or s.pendingHueResult or s.pendingMaterialResult or s.pendingToyResult or s.pendingFeatureResult end
local function matches(p,r)
 if type(r)~="table"or r.id~=p.value.id or r.action~=p.action or r.petId~=p.value.petId or r.catalogVersion~=Catalog.CatalogVersion
  or type(r.revision)~="number"or r.revision<=p.revision then return false end
 if p.action=="toyBuy"then return type(r.balanceBefore)=="number"and type(r.balanceAfter)=="number"and r.cost==Catalog.Cost and r.resultId==r.id and table.find(p.value.eligible,r.toyId)~=nil and r.balanceBefore==p.balanceBefore and r.balanceAfter==r.balanceBefore-Catalog.Cost end
 if p.action=="toyAck"then return r.cost==0 and r.acknowledgedResultId==p.value.resultId end
 return r.cost==0 and r.toyId==p.value.toyId and r.selectedBefore==p.value.expectedToy and r.selectedAfter==p.value.toyId and r.acknowledgedResultId==p.value.resultId
end
local function snapshotMatches(s,p,r)
 if p.action=="toyBuy"then return Catalog.owns(s.toyUnlocks,r.toyId)end
 if p.action=="toyAck"then return not s.pendingToyResult or s.pendingToyResult.id~=p.value.resultId end
 return ((s.petToys or {})[p.value.petId]or Catalog.Default)==r.selectedAfter
end
function Intent.new(d)return setmetatable({d=d,state={},status="Ready",alive=true},Intent)end
function Intent:notify()if self.alive and self.d.changed then self.d.changed(self)end end
function Intent:waitFor(p)
 p.waitEpoch=(p.waitEpoch or 0)+1;local epoch=p.waitEpoch
 local delay=self.d.delay or task.delay;delay(8,function()if self.alive and self.pending==p and p.waitEpoch==epoch then self.status="Retrying";self.message="Try again.";self:notify()end end)
end
function Intent:reconcile()
 local p=self.pending;if not p then return end
 local latest=self.state.lastToyResult;local r=if latest and latest.id==p.value.id then latest else p.savedReceipt
 if matches(p,r)and(self.state.revision or -1)>=r.revision and snapshotMatches(self.state,p,r)then self.pending=nil;self.receipt=r;self.status="Saved";self.message=nil end
end
function Intent:update(s)
 if not self.alive or(type(s)=="table"and type(s.revision)=="number"and type(self.state.revision)=="number"and s.revision<self.state.revision)then return false end
 self.state=s or {};self:reconcile();self:notify();return true
end
function Intent:ready()
 return self.alive and not self.pending and(not self.d.available or self.d.available())and not self.state.lastHatch and(not self.state.status or self.state.status=="Ready")
end
function Intent:begin(action,values)
 if not self:ready()then return false end
 local revision=self.state.revision or 0;local value=table.clone(values);value.id=tostring(revision)..":toy-"..self.d.id();value.catalogVersion=Catalog.CatalogVersion
 self.pending={action=action,value=value,revision=revision,balanceBefore=self.state.nectar or 0};self.status="Pending";self.message=nil;self:waitFor(self.pending);self:notify();self.d.send(action,value,revision);return true
end
function Intent:buy()
 if pendingResult(self.state)then self.message="Store or use your saved egg first.";self:notify();return false end
 local eligible=Catalog.remaining(self.state.toyUnlocks);table.sort(eligible)
 if #eligible==0 then self.message="All toys owned";self:notify();return false end
 if(self.state.nectar or 0)<Catalog.Cost then self.message="You need more Stars.";self:notify();return false end
 return self:begin("toyBuy",{poolVersion=Catalog.PoolVersion,eligible=eligible})
end
function Intent:ack(resultId)
 local r=self.state.pendingToyResult;if not r or r.id~=resultId then return false end
 return self:begin("toyAck",{resultId=resultId})
end
function Intent:equip(petId,toyId,resultId)
 if not Eggs.isOwned(self.state.inventoryMask or 0,petId)or not Catalog.owns(self.state.toyUnlocks,toyId)then return false end
 local r=self.state.pendingToyResult
 if resultId and(not r or r.id~=resultId or r.toyId~=toyId)then return false end
 if pendingResult(self.state)and not resultId then return false end
 local expected=(self.state.petToys or {})[petId]or Catalog.Default;if expected==toyId and not resultId then return false end
 return self:begin("toyEquip",{petId=petId,toyId=toyId,expectedToy=expected,resultId=resultId})
end
function Intent:receive(packet)
 local p=self.pending
 if not self.alive or type(packet)~="table"or not p or packet.id~=p.value.id or packet.action~=p.action or packet.petId~=p.value.petId then return false end
 if p.savedReceipt and packet.status~="Saved"then return false end
 if packet.status=="Saved"then
  if not matches(p,packet.receipt)then return false end
  p.savedReceipt=packet.receipt;self.status="Pending";self:waitFor(p);self:reconcile()
 elseif packet.status=="Retrying"then self.status="Retrying";self.message="Try again."
 elseif packet.status=="Rejected"then self.pending=nil;self.status="Rejected";self.message=if packet.reason=="AllOwned"then "All toys owned"elseif packet.reason=="Insufficient"or packet.reason=="NeedStars"then "You need more Stars."else "This toy was not changed. Review your items."
 else return false end
 self:notify();return true
end
function Intent:retry()
 local p=self.pending;if not p or self.status~="Retrying"then return false end
 self.status="Pending";self.message=nil;self:waitFor(p);self:notify();self.d.send(p.action,p.value,p.revision);return true
end
function Intent:destroy()self.alive=false;self.pending=nil end
return Intent
