-- Typed v7 permanent unlocks. Frozen Hue inventories/receipts remain separate.
local Shared=game:GetService("ReplicatedStorage").Shared
local Catalog=require(Shared.MaterialCatalog);local Eggs=require(Shared.EggCatalog)
local Guard=require(script.Parent.HatchGuard)
local State={ReceiptLimit=Catalog.ReceiptLimit}
local function copy(v)if type(v)~="table"then return v end;local r={};for k,x in pairs(v)do r[k]=copy(x)end;return r end
local function equal(a,b)
 if type(a)~=type(b)then return false end;if type(a)~="table"then return a==b end
 for k,v in pairs(a)do if not equal(v,b[k])then return false end end;for k in pairs(b)do if a[k]==nil then return false end end;return true
end
local function integer(v,max)return type(v)=="number"and v==v and v%1==0 and v>=0 and v<=(max or 1000000000)end
local function opaque(v)return type(v)=="string"and #v>0 and #v<=100 end
local function exact(v,keys)if type(v)~="table"then return false end;for k in pairs(v)do if not keys[k]then return false end end;return true end
local fields={materialBuy={id=true,catalogVersion=true,poolVersion=true,eligible=true},materialAck={id=true,catalogVersion=true,resultId=true},materialEquip={id=true,catalogVersion=true,petId=true,finishId=true,expectedFinish=true,resultId=true}}
local function poolValid(list,version)
 local pool=Catalog.Pools[version]
 if not pool or type(list)~="table"or #list<1 or #list>#pool then return false end
 local previous="";for i,id in ipairs(list)do if not table.find(pool,id)or id<=previous then return false end;previous=id end
 for k in pairs(list)do if not integer(k,#list)or k<1 then return false end end;return true
end
function State.isAction(action)return fields[action]~=nil end
function State.quote(action,value,revision)
 if not fields[action]or not exact(value,fields[action])or not integer(revision)or not opaque(value.id)or not value.id:match("^"..tostring(revision)..":[%w%-_]+$")or value.catalogVersion~=Catalog.CatalogVersion then return nil end
 local q=copy(value);q.action,q.revision=action,revision
 if action=="materialBuy"then if not poolValid(q.eligible,q.poolVersion)then return nil end
 elseif action=="materialAck"then if not opaque(q.resultId)then return nil end
 else
  if Eggs.bit(q.petId)==0 or not Catalog.known(q.finishId)or not Catalog.known(q.expectedFinish)or(q.resultId~=nil and not opaque(q.resultId))then return nil end
 end
 return q
end
function State.same(a,b)return equal(a,b)end
function State.selected(state,petId)return(state.petMaterials or {})[petId]or Catalog.Default end
function State.upgrade(state)
 local upgraded=copy(state);upgraded.version=7;upgraded.materialUnlocks={};upgraded.petMaterials={};upgraded.materialReceipts={};upgraded.materialReceiptOrder={};return upgraded
end
function State.find(state,quote)
 local receipt=quote and(state.materialReceipts or {})[quote.id]
 return receipt,receipt~=nil and equal(receipt.quote,quote)
end
function State.proof(state,candidate)
 local receipt,same=State.find(state,candidate.quote)
 return same==true and receipt.operationId==candidate.operationId and receipt.sequence==candidate.sequence
end
local function quoteValid(q)
 if type(q)~="table"or not fields[q.action]then return false end
 local value={};for key in pairs(fields[q.action])do value[key]=q[key]end
 local canonical=State.quote(q.action,value,q.revision);return canonical~=nil and equal(q,canonical)
end
local receiptFields={id=true,action=true,quote=true,operationId=true,sequence=true,revision=true,catalogVersion=true,cost=true,balanceBefore=true,balanceAfter=true,finishId=true,petId=true,selectedBefore=true,selectedAfter=true,acknowledgedResultId=true,resultId=true}
local function receiptValid(r)
 if not exact(r,receiptFields)or not quoteValid(r.quote)or r.id~=r.quote.id or r.action~=r.quote.action or not opaque(r.operationId)or not integer(r.sequence)or r.sequence<1 or not integer(r.revision)or r.revision<=r.quote.revision or r.catalogVersion~=Catalog.CatalogVersion or not integer(r.balanceBefore)or not integer(r.balanceAfter)or not integer(r.cost)or r.balanceAfter~=r.balanceBefore-r.cost then return false end
 local q=r.quote
 if q.action=="materialBuy"then
  return r.cost==Catalog.Cost and table.find(q.eligible,r.finishId)~=nil and r.resultId==r.id and r.petId==nil and r.selectedBefore==nil and r.selectedAfter==nil and r.acknowledgedResultId==nil
 elseif q.action=="materialAck"then
  return r.cost==0 and r.acknowledgedResultId==q.resultId and r.finishId==nil and r.petId==nil and r.selectedBefore==nil and r.selectedAfter==nil and r.resultId==nil
 end
 return r.cost==0 and r.petId==q.petId and r.finishId==q.finishId and r.selectedBefore==q.expectedFinish and r.selectedAfter==q.finishId and r.acknowledgedResultId==q.resultId and r.resultId==nil
end
function State.valid(state)
 if type(state.materialUnlocks)~="table"or type(state.petMaterials)~="table"or type(state.materialReceipts)~="table"or type(state.materialReceiptOrder)~="table"then return false end
 for id,value in pairs(state.materialUnlocks)do if not Catalog.known(id)or id==Catalog.Default or value~=true then return false end end
 for pet,id in pairs(state.petMaterials)do if not Eggs.isOwned(state.inventoryMask,pet)or not Catalog.owns(state.materialUnlocks,id)then return false end end
 local seen,count,sequence={},0,0
 for _,id in ipairs(state.materialReceiptOrder)do
  local r=state.materialReceipts[id]
  if not opaque(id)or seen[id]or not r or not receiptValid(r)or r.id~=id or r.sequence<=sequence or r.sequence>state.operationSeq or r.revision>state.revision then return false end
  if r.finishId and not Catalog.owns(state.materialUnlocks,r.finishId)then return false end
  if r.petId and not Eggs.isOwned(state.inventoryMask,r.petId)then return false end
  seen[id],count,sequence=true,count+1,r.sequence
 end
 if count>State.ReceiptLimit then return false end
 for k in pairs(state.materialReceiptOrder)do if not integer(k,count)or k<1 then return false end end
 for id in pairs(state.materialReceipts)do if not seen[id]then return false end end
 if state.lastMaterialResult then local r=state.materialReceipts[state.lastMaterialResult.id];if not r or not equal(r,state.lastMaterialResult)or state.materialReceiptOrder[count]~=r.id then return false end elseif count>0 then return false end
 local result=state.pendingMaterialResult
 if result then
  if not exact(result,{id=true,finishId=true,revision=true,catalogVersion=true})or result.catalogVersion~=Catalog.CatalogVersion then return false end
  local r=state.materialReceipts[result.id]
  if not r or r.action~="materialBuy"or r.finishId~=result.finishId or r.revision~=result.revision or r.resultId~=result.id then return false end
 end
 local reservation=state.materialReservation
 if reservation then
  if not exact(reservation,{quote=true,operationId=true,sequence=true,finishId=true})or not quoteValid(reservation.quote)or reservation.quote.action~="materialBuy"or not opaque(reservation.operationId)or reservation.sequence~=state.operationSeq+1 or reservation.quote.revision>state.revision or not table.find(reservation.quote.eligible,reservation.finishId)or not equal(reservation.quote.eligible,Catalog.remaining(state.materialUnlocks,reservation.quote.poolVersion))or state.materialReceipts[reservation.quote.id]or state.pendingMaterialResult or state.pendingHueResult or state.hueReservation or state.lastHatch then return false end
 end
 return true
end
local function saveReceipt(state,receipt)
 state.materialReceipts[receipt.id]=receipt;table.insert(state.materialReceiptOrder,receipt.id)
 while #state.materialReceiptOrder>State.ReceiptLimit do
  local index=if state.pendingMaterialResult and state.materialReceiptOrder[1]==state.pendingMaterialResult.id then 2 else 1
  state.materialReceipts[table.remove(state.materialReceiptOrder,index)]=nil
 end
 state.lastMaterialResult=receipt
end
function State.purchaseEligibility(state,quote)
 if Guard.other(state,"material")or state.pendingMaterialResult then return false,"RevealPending"end
 if state.materialReservation and(not quote or not equal(state.materialReservation.quote,quote))then return false,"PurchasePending"end
 local remaining=Catalog.remaining(state.materialUnlocks,quote and quote.poolVersion)
 if #remaining==0 then return false,"AllUnlocked"end
 if (state.inventoryMask or 0)==0 then return false,"MeetPipFirst"end
 if quote and not equal(quote.eligible,remaining)then return false,"PoolChanged"end
 if state.nectar<Catalog.Cost then return false,"NeedStars"end
 return true
end
function State.apply(state,candidate)
 local q=candidate.quote
 if not quoteValid(q)then return false,"InvalidMaterial"end
 if state.materialReservation and not equal(state.materialReservation,candidate)then return false,"PurchasePending"end
 if Guard.other(state,"material")then return false,"RevealPending"end
 local r={id=q.id,action=q.action,quote=copy(q),operationId=candidate.operationId,sequence=candidate.sequence,revision=state.revision+1,catalogVersion=Catalog.CatalogVersion,cost=0,balanceBefore=state.nectar,balanceAfter=state.nectar}
 if q.action=="materialBuy"then
  if not state.materialReservation or not equal(state.materialReservation,candidate)then return false,"MissingReservation"end
  local ok,why=State.purchaseEligibility(state,q);if not ok then return false,why end
  if not table.find(q.eligible,candidate.finishId)or Catalog.owns(state.materialUnlocks,candidate.finishId)then return false,"PoolChanged"end
  r.finishId,r.resultId,r.cost=candidate.finishId,q.id,Catalog.Cost;r.balanceAfter=state.nectar-Catalog.Cost;state.nectar=r.balanceAfter
  state.materialUnlocks[candidate.finishId]=true;state.materialReservation=nil
  state.pendingMaterialResult={id=q.id,finishId=candidate.finishId,revision=r.revision,catalogVersion=Catalog.CatalogVersion}
 elseif q.action=="materialAck"then
  if not state.pendingMaterialResult or state.pendingMaterialResult.id~=q.resultId then return false,"ResultChanged"end
  r.acknowledgedResultId=q.resultId;state.pendingMaterialResult=nil
 else
  if not Eggs.isOwned(state.inventoryMask,q.petId)then return false,"Unowned"end
  if not Catalog.owns(state.materialUnlocks,q.finishId)then return false,"LockedMaterial"end
  if State.selected(state,q.petId)~=q.expectedFinish then return false,"SelectionChanged"end
  if q.resultId and(not state.pendingMaterialResult or state.pendingMaterialResult.id~=q.resultId or state.pendingMaterialResult.finishId~=q.finishId)then return false,"ResultChanged"end
  if q.finishId==q.expectedFinish and not q.resultId then return false,"NoChange"end
  r.petId,r.finishId,r.selectedBefore,r.selectedAfter=q.petId,q.finishId,q.expectedFinish,q.finishId
  state.petMaterials[q.petId]=q.finishId
  if q.resultId then r.acknowledgedResultId=q.resultId;state.pendingMaterialResult=nil end
 end
 saveReceipt(state,r);return true
end
function State.publicReceipt(receipt)
 if not receipt then return nil end;local r=copy(receipt);r.quote,r.operationId,r.sequence=nil,nil,nil;return r
end
function State.public(state)
 return {materialUnlocks=copy(state.materialUnlocks),petMaterials=copy(state.petMaterials),pendingMaterialResult=copy(state.pendingMaterialResult),lastMaterialResult=State.publicReceipt(state.lastMaterialResult),materialCatalogVersion=Catalog.CatalogVersion,materialPoolVersion=Catalog.PoolVersion}
end
return State
