-- Exact quoted operations. World colors always come from confirmed snapshots.
local Shared=game:GetService("ReplicatedStorage").Shared
local Hues=require(Shared.HueCatalog)
local Eggs=require(Shared.EggCatalog)
local Intent={};Intent.__index=Intent
local messages={RevisionChanged="Your pet or Stars changed. Review the updated preview.",RankChanged="This baby’s rank changed. Review the updated preview.",RevealPending="Finish your pending companion hatch first.",NeedStars="You need more Stars.",Unowned="Choose a baby you own.",LockedHue="This color is not unlocked for this baby.",Stale="Your pet or Stars changed. Review the updated preview.",Insufficient="You need more Stars.",MaxRank="This direction is already max rank.",NotOwned="Choose a baby you own.",Unsupported="Hue Eggs are for Zivvi and Ovelle.",PendingHatch="Finish your pending companion hatch first.",Locked="This color is not unlocked for this baby.",Malformed="That choice could not be saved. Try again.",SessionLost="Reconnect to confirm your saved Stars and colors.",Unavailable="Saving is unavailable. Your confirmed colors are unchanged."}
function Intent.new(d)return setmetatable({d=d,state={},status="Ready"},Intent)end
function Intent:notify()if self.d.changed then self.d.changed(self)end end
function Intent:record()return self.state.lastHueResult end
function Intent:reconcile()
 local pending=self.pending;if not pending then return end
 local latest=self:record();local receipt=if latest and latest.id==pending.value.id then latest else pending.savedReceipt
 if receipt and type(receipt.revision)=="number"and(self.state.revision or -1)>=receipt.revision then
  self.pending=nil;self.status="Saved";self.message="Saved";self.receipt=receipt
 end
end
function Intent:update(state)
 if type(state)=="table"and type(state.revision)=="number"and type(self.state.revision)=="number"and state.revision<self.state.revision then return false end
 self.state=state or {}
 local receipt=self:record()
 if receipt and receipt.id and receipt.id~=self.lastRecordId then self.lastRecordId=receipt.id;self.receipt=receipt end
 self:reconcile();self:notify()
end
function Intent:ready(petId)
 if self.pending then return false,"Saving this change…"end
 if self.d.available and not self.d.available()then return false,"Wait for your saved progress to be ready."end
 if self.state.lastHatch then return false,messages.PendingHatch end
 if self.state.status and self.state.status~="Ready"then return false,"Wait for your current save to finish."end
 if not Hues.Supported[petId]then return false,messages.Unsupported end
 if not Eggs.isOwned(self.state.inventoryMask or 0,petId)then return false,messages.NotOwned end
 return true
end
function Intent:begin(action,petId,values)
 local ready,reason=self:ready(petId);if not ready then self.message=reason;self:notify();return false end
 local revision=self.state.revision or 0
 local value=table.clone(values);value.id=tostring(revision)..":"..self.d.id();value.petId=petId
 self.pending={action=action,value=value,revision=revision};self.status="Pending";self.message="Saving this change…"
 self:notify();self.d.send(action,value,revision);return true
end
function Intent:buy(petId,hue)
 local record=Hues.get(self.state.hues,petId);local offer=Hues.ById[hue]
 if not offer then return false end
 local rank=record.ranks[hue]or 0
 if rank>=Hues.MaxRank then self.message=messages.MaxRank;self:notify();return false end
 if(self.state.nectar or 0)<offer.cost then self.message=messages.Insufficient;self:notify();return false end
 return self:begin("hue",petId,{hue=hue,rank=rank})
end
function Intent:equip(petId,kind,id)
 if kind~="body"and kind~="secondary"then return false end
 local record=Hues.get(self.state.hues,petId)
 if id~=(if kind=="body"then "original"else "default")and(record.ranks[id]or 0)<1 then self.message=messages.Locked;self:notify();return false end
 return self:begin("hueEquip",petId,{[kind]=id})
end
function Intent:receive(packet)
 local pending=self.pending
 if type(packet)~="table"then return false end
 if pending and pending.savedReceipt and packet.status~="Saved"then return false end
 if type(packet)~="table"or not pending or packet.id~=pending.value.id or packet.petId~=pending.value.petId or packet.action~=pending.action then return false end
 if packet.status=="Retrying"then self.status="Retrying";self.message="Save is pending. Retry the same change."
 elseif packet.status=="Rejected"then self.pending=nil;self.status="Rejected";self.message=messages[packet.reason]or "That change was not saved. Review your current pet and Stars."
 elseif packet.status=="Saved"then
  local receipt=packet.receipt
  if type(receipt)~="table"or receipt.id~=pending.value.id or receipt.petId~=pending.value.petId
      or receipt.action~=pending.action or type(receipt.revision)~="number"then return false end
  pending.savedReceipt=receipt
  self.status="Saved";self.message="Saved. Updating your confirmed colors…"
  -- A coalesced snapshot or an old paid replay can have a newer latest record.
  -- Receipt proof plus a confirmed revision fence does not require it to rewind.
  self:reconcile()
 else return false end
 self:notify();return true
end
function Intent:retry()
 if not self.pending or self.status~="Retrying"then return false end
 local p=self.pending;self.status="Pending";self.message="Saving this change…";self:notify();self.d.send(p.action,p.value,p.revision);return true
end
return Intent
