-- Typed feature stock, growth and visibility. Saved replies never preview a grant.
local Shared=game:GetService("ReplicatedStorage").Shared
local Catalog=require(Shared.FeatureCatalog);local Eggs=require(Shared.EggCatalog)
local Intent={};Intent.__index=Intent
local function pendingResult(s)return s.lastHatch or s.pendingHueResult or s.pendingMaterialResult or s.pendingToyResult or s.pendingFeatureResult end
local function row(s,pet,id)return ((s.petFeatures or {})[pet]or Catalog.emptyRow())[id]or{earned=0,visible=0}end
local function matches(p,r)
 if type(r)~="table"or r.id~=p.value.id or r.action~=p.action or r.petId~=p.value.petId or r.catalogVersion~=Catalog.CatalogVersion
  or type(r.revision)~="number"or r.revision<=p.revision then return false end
 if p.action=="featureBuy"then
  if not Catalog.ById[r.featureId]or r.inventoryBefore~=(p.stockBefore[r.featureId]or 0)or r.balanceBefore~=p.balanceBefore or type(r.inventoryBefore)~="number"or type(r.inventoryAfter)~="number"or type(r.balanceBefore)~="number"or type(r.balanceAfter)~="number"then return false end
  if r.outcome=="Refused"then return r.reason=="StackLimit"and r.cost==0 and r.inventoryBefore==Catalog.StackLimit and r.inventoryAfter==r.inventoryBefore and r.balanceAfter==r.balanceBefore and r.resultId==nil end
  return r.outcome=="Applied"and r.cost==Catalog.Cost and r.resultId==r.id and r.inventoryAfter==r.inventoryBefore+1 and r.balanceAfter==r.balanceBefore-Catalog.Cost
 end
 if p.action=="featureAck"then return r.cost==0 and r.acknowledgedResultId==p.value.resultId end
 if r.outcome~="Applied"or r.cost~=0 or r.featureId~=p.value.featureId or r.earnedBefore~=p.value.expectedStage then return false end
 if p.action=="featureUse"then return type(r.inventoryBefore)=="number"and type(r.inventoryAfter)=="number"and r.inventoryBefore==(p.stockBefore[p.value.featureId]or 0)and r.visibleBefore==p.visibleBefore and r.earnedAfter==r.earnedBefore+1 and r.visibleAfter==r.earnedAfter and r.inventoryAfter==r.inventoryBefore-1 and r.acknowledgedResultId==p.value.pendingResultId end
 return r.earnedAfter==r.earnedBefore and r.visibleBefore==p.value.expectedVisible and r.visibleAfter==p.value.stage
end
local function snapshotMatches(s,p,r)
 if p.action=="featureBuy"then return ((s.featureStock or {})[r.featureId]or 0)==r.inventoryAfter end
 if p.action=="featureAck"then return not s.pendingFeatureResult or s.pendingFeatureResult.id~=p.value.resultId end
 local now=row(s,p.value.petId,p.value.featureId)
 return now.earned==r.earnedAfter and now.visible==r.visibleAfter and(p.action~="featureUse"or((s.featureStock or {})[r.featureId]or 0)==r.inventoryAfter)
end
function Intent.new(d)return setmetatable({d=d,state={},status="Ready",alive=true},Intent)end
function Intent:notify()if self.alive and self.d.changed then self.d.changed(self)end end
function Intent:waitFor(p)
 p.waitEpoch=(p.waitEpoch or 0)+1;local epoch=p.waitEpoch
 local delay=self.d.delay or task.delay;delay(8,function()if self.alive and self.pending==p and p.waitEpoch==epoch then self.status="Retrying";self.message="Try again.";self:notify()end end)
end
function Intent:reconcile()
 local p=self.pending;if not p then return end
 local latest=self.state.lastFeatureResult;local r=if latest and latest.id==p.value.id then latest else p.savedReceipt
 if matches(p,r)and(self.state.revision or -1)>=r.revision and snapshotMatches(self.state,p,r)then
  self.pending=nil;self.receipt=r;self.status=if r.outcome=="Refused"then "Rejected"else "Saved";self.message=if r.outcome=="Refused"then "This stack is full. No Stars were used."else nil
 end
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
 local revision=self.state.revision or 0;local value=table.clone(values);value.id=tostring(revision)..":feature-"..self.d.id();value.catalogVersion=Catalog.CatalogVersion
 self.pending={action=action,value=value,revision=revision,balanceBefore=self.state.nectar or 0,stockBefore=table.clone(self.state.featureStock or {}),visibleBefore=if value.petId and value.featureId then row(self.state,value.petId,value.featureId).visible else nil};self.status="Pending";self.message=nil;self:waitFor(self.pending);self:notify();self.d.send(action,value,revision);return true
end
function Intent:buy()
 if pendingResult(self.state)then self.message="Store or use your saved egg first.";self:notify();return false end
 local allFull=true;for _,id in ipairs(Catalog.Order)do if((self.state.featureStock or {})[id]or 0)<Catalog.StackLimit then allFull=false end end
 if allFull then self.message="All feature stacks are full";self:notify();return false end
 if(self.state.nectar or 0)<Catalog.Cost then self.message="You need more Stars.";self:notify();return false end
 return self:begin("featureBuy",{poolVersion=Catalog.PoolVersion})
end
function Intent:ack(resultId)
 local r=self.state.pendingFeatureResult;if not r or r.id~=resultId then return false end
 return self:begin("featureAck",{resultId=resultId})
end
function Intent:use(petId,featureId,resultId)
 if not Eggs.isOwned(self.state.inventoryMask or 0,petId)or not Catalog.ById[featureId]then return false end
 local now=row(self.state,petId,featureId)
 if now.earned>=Catalog.MaxStage or((self.state.featureStock or {})[featureId]or 0)<1 then return false end
 local r=self.state.pendingFeatureResult
 if resultId and(not r or r.id~=resultId or r.featureId~=featureId)then return false end
 if pendingResult(self.state)and not resultId then return false end
 return self:begin("featureUse",{petId=petId,featureId=featureId,expectedStage=now.earned,pendingResultId=resultId})
end
function Intent:show(petId,featureId,stage)
 if not Eggs.isOwned(self.state.inventoryMask or 0,petId)or not Catalog.ById[featureId]or pendingResult(self.state)then return false end
 local now=row(self.state,petId,featureId)
 if type(stage)~="number"or stage%1~=0 or stage<0 or stage>now.earned or stage==now.visible then return false end
 return self:begin("featureShow",{petId=petId,featureId=featureId,stage=stage,expectedVisible=now.visible,expectedStage=now.earned})
end
function Intent:receive(packet)
 local p=self.pending
 if not self.alive or type(packet)~="table"or not p or packet.id~=p.value.id or packet.action~=p.action or packet.petId~=p.value.petId then return false end
 if p.savedReceipt and packet.status~="Saved"then return false end
 if packet.status=="Saved"then
  if not matches(p,packet.receipt)then return false end
  p.savedReceipt=packet.receipt;self.status="Pending";self:waitFor(p);self:reconcile()
 elseif packet.status=="Retrying"then self.status="Retrying";self.message="Try again."
 elseif packet.status=="Rejected"then self.pending=nil;self.status="Rejected";self.message=if packet.reason=="Max"or packet.reason=="Capped"then "Max · 5/5 grown"elseif packet.reason=="Insufficient"or packet.reason=="NeedStars"then "You need more Stars."else "This feature was not changed. Review your items."
 else return false end
 self:notify();return true
end
function Intent:retry()
 local p=self.pending;if not p or self.status~="Retrying"then return false end
 self.status="Pending";self.message=nil;self:waitFor(p);self:notify();self.d.send(p.action,p.value,p.revision);return true
end
function Intent:destroy()self.alive=false;self.pending=nil end
return Intent
