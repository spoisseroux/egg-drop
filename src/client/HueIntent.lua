-- A captured operation is retried verbatim. Only a saved revision paints a pet.
local Shared=game:GetService("ReplicatedStorage").Shared
local Hues=require(Shared.HueCatalog)
local Eggs=require(Shared.EggCatalog)
local Intent={};Intent.__index=Intent
local messages={RevisionChanged="Your inventory changed. Review the updated counts.",Stale="Your inventory changed. Review the updated counts.",NeedStars="You need more Stars.",Insufficient="You need more Stars.",NotOwned="Choose a pet you own.",Unowned="Choose a pet you own.",Unsupported="This pet cannot use this item yet.",PendingHatch="Finish your pending companion hatch first.",RevealPending="Finish your pending companion hatch first.",PendingResult="Store or use your pending item first.",EmptyStock="There are no jars of this item left.",NoStock="There are no jars of this item left.",Capped="This hue is already 5/5 on this channel.",NoChange="This channel is already original.",SessionLost="Reconnect to confirm your saved items and colors.",Unavailable="Saving is unavailable. Your confirmed items are safe."}
messages.EmptyStock,messages.NoStock,messages.Capped,messages.NoChange="No Items","No Items","Max","Original"
function Intent.new(d)return setmetatable({d=d,state={},status="Ready"},Intent)end
function Intent:notify()if self.d.changed then self.d.changed(self)end end
function Intent:record()return self.state.lastHueResult end
function Intent:reconcile()
 local p=self.pending;if not p then return end
 local latest=self:record();local receipt=if latest and latest.id==p.value.id then latest else p.savedReceipt
 if receipt and type(receipt.revision)=="number"and(self.state.revision or -1)>=receipt.revision then
  self.pending=nil;self.status=if receipt.outcome=="Refused"then "Rejected"else "Saved";self.message=if receipt.outcome=="Refused"then "This stack is full. No Stars were used."else nil;self.receipt=receipt
 end
end
function Intent:update(state)
 if type(state)=="table"and type(state.revision)=="number"and type(self.state.revision)=="number"and state.revision<self.state.revision then return false end
 self.state=state or {};self:reconcile();self:notify();return true
end
function Intent:ready(petId)
 if self.pending then return false,"Saving this change…"end
 if self.d.available and not self.d.available()then return false,"Wait for your saved progress to be ready."end
 if self.state.lastHatch then return false,messages.PendingHatch end
 if self.state.status and self.state.status~="Ready"then return false,"Wait for your current save to finish."end
 if petId then
  if not Hues.Supported[petId]then return false,messages.Unsupported end
  if not Eggs.isOwned(self.state.inventoryMask or 0,petId)then return false,messages.NotOwned end
 end
 return true
end
function Intent:begin(action,petId,values)
 local ready,reason=self:ready(petId);if not ready then self.message=reason;self:notify();return false end
 local revision=self.state.revision or 0;local value=table.clone(values)
 value.id=tostring(revision)..":"..self.d.id();value.petId=petId;value.catalogVersion=Hues.CatalogVersion
 self.pending={action=action,value=value,revision=revision};self.status="Pending";self.message=nil
 self:notify();self.d.send(action,value,revision);return true
end
function Intent:hatch()
 if self.state.pendingHueResult then self.message=messages.PendingResult;self:notify();return false end
 if(self.state.nectar or 0)<Hues.Cost then self.message=messages.Insufficient;self:notify();return false end
 return self:begin("hueBuy",nil,{})
end
function Intent:store(resultId)
 local result=self.state.pendingHueResult
 if not result or result.id~=resultId then return false end
 return self:begin("hueStore",nil,{resultId=resultId})
end
function Intent:use(petId,channel,itemId,resultId)
 if channel~="main"and channel~="secondary"then return false end
 local record=self.state.petHues and self.state.petHues[petId]
 local counts=table.clone(record and record[channel]or Hues.emptyCounts())
 return self:begin("hueUse",petId,{itemId=itemId,channel=channel,counts=counts,pendingResultId=resultId})
end
function Intent:ackMigration()return self:begin("hueMigrationAck",nil,{migrationId=self.state.hueMigrationId})end
function Intent:legacyRedeem(itemId)
 local egg=self.state.legacyHueEgg;if not egg then return false end
 return self:begin("hueLegacyRedeem",nil,{migrationId=self.state.hueMigrationId,token=egg.token,purchaseId=egg.purchaseId,itemId=itemId})
end
function Intent:legacyPreset(petId,channel,presetId)
 local record=self.state.petHues and self.state.petHues[petId]
 return self:begin("hueLegacyPreset",petId,{migrationId=self.state.hueMigrationId,channel=channel,presetId=presetId,locked=false,counts=table.clone(record and record[channel]or Hues.emptyCounts())})
end
function Intent:receive(packet)
 local p=self.pending;if type(packet)~="table"or not p then return false end
 if packet.id~=p.value.id or packet.petId~=p.value.petId or packet.action~=p.action then return false end
 if p.savedReceipt and packet.status~="Saved"then return false end
 if packet.status=="Retrying"then self.status="Retrying";self.message="Save is pending. Retry the same change."
 elseif packet.status=="Rejected"then self.pending=nil;self.status="Rejected";self.message=messages[packet.reason]or "That change was not saved. Review your current inventory."
 elseif packet.status=="Saved"then
  local r=packet.receipt
  if type(r)~="table"or r.id~=p.value.id or r.action~=p.action or r.petId~=p.value.petId or type(r.revision)~="number"then return false end
  p.savedReceipt=r;self.status="Saved";self.message=nil;self:reconcile()
 else return false end
 self:notify();return true
end
function Intent:retry()
 if not self.pending or self.status~="Retrying"then return false end
 local p=self.pending;self.status="Pending";self.message=nil;self:notify();self.d.send(p.action,p.value,p.revision);return true
end
return Intent
