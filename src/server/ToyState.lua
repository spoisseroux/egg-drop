-- Typed v8 personal toy unlocks; only confirmed choices enter public appearance.
local Shared=game:GetService("ReplicatedStorage").Shared
local Catalog=require(Shared.ToyCatalog);local Eggs=require(Shared.EggCatalog)
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
local fields={toyBuy={id=true,catalogVersion=true,poolVersion=true,eligible=true},toyAck={id=true,catalogVersion=true,resultId=true},toyEquip={id=true,catalogVersion=true,petId=true,toyId=true,expectedToy=true,resultId=true}}
local function poolValid(list,version)
 local pool=Catalog.Pools[version]
 if not pool or type(list)~="table"or #list<1 or #list>#pool then return false end
 local previous="";for i=1,#list do local id=list[i];if type(id)~="string"or not table.find(pool,id)or id<=previous then return false end;previous=id end
 for k in pairs(list)do if not integer(k,#list)or k<1 then return false end end;return true
end
function State.isAction(action)return fields[action]~=nil end
function State.quote(action,value,revision)
 if not fields[action]or not exact(value,fields[action])or not integer(revision)or not opaque(value.id)or not value.id:match("^"..tostring(revision)..":toy%-[%w%-_]+$")or value.catalogVersion~=Catalog.CatalogVersion then return nil end
 local q=copy(value);q.action,q.revision=action,revision
 if action=="toyBuy"then if not poolValid(q.eligible,q.poolVersion)then return nil end
 elseif action=="toyAck"then if not opaque(q.resultId)then return nil end
 else
  if Eggs.bit(q.petId)==0 or not Catalog.known(q.toyId)or not Catalog.known(q.expectedToy)or(q.resultId~=nil and not opaque(q.resultId))then return nil end
 end
 return q
end
function State.same(a,b)return equal(a,b)end
function State.selected(state,petId)return(state.petToys or {})[petId]or Catalog.Default end
function State.upgrade(state)
 local upgraded=copy(state);upgraded.version=8;upgraded.toyUnlocks={};upgraded.petToys={};upgraded.toyReceipts={};upgraded.toyReceiptOrder={};return upgraded
end
function State.find(state,quote)
 local receipt=quote and(state.toyReceipts or {})[quote.id]
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
local receiptFields={id=true,action=true,quote=true,operationId=true,sequence=true,revision=true,catalogVersion=true,cost=true,balanceBefore=true,balanceAfter=true,toyId=true,petId=true,selectedBefore=true,selectedAfter=true,acknowledgedResultId=true,resultId=true}
local function receiptValid(r)
 if not exact(r,receiptFields)or not quoteValid(r.quote)or r.id~=r.quote.id or r.action~=r.quote.action or not opaque(r.operationId)or not integer(r.sequence)or r.sequence<1 or not integer(r.revision)or r.revision<=r.quote.revision or r.catalogVersion~=Catalog.CatalogVersion or not integer(r.balanceBefore)or not integer(r.balanceAfter)or not integer(r.cost)or r.balanceAfter~=r.balanceBefore-r.cost then return false end
 local q=r.quote
 if q.action=="toyBuy"then
  return r.cost==Catalog.Cost and table.find(q.eligible,r.toyId)~=nil and r.resultId==r.id and r.petId==nil and r.selectedBefore==nil and r.selectedAfter==nil and r.acknowledgedResultId==nil
 elseif q.action=="toyAck"then
  return r.cost==0 and r.acknowledgedResultId==q.resultId and r.toyId==nil and r.petId==nil and r.selectedBefore==nil and r.selectedAfter==nil and r.resultId==nil
 end
 return r.cost==0 and r.petId==q.petId and r.toyId==q.toyId and r.selectedBefore==q.expectedToy and r.selectedAfter==q.toyId and r.acknowledgedResultId==q.resultId and r.resultId==nil
end
function State.valid(state)
 if type(state.toyUnlocks)~="table"or type(state.petToys)~="table"or type(state.toyReceipts)~="table"or type(state.toyReceiptOrder)~="table"then return false end
 for id,value in pairs(state.toyUnlocks)do if not Catalog.known(id)or id==Catalog.Default or value~=true then return false end end
 for pet,id in pairs(state.petToys)do if not Eggs.isOwned(state.inventoryMask,pet)or not Catalog.owns(state.toyUnlocks,id)then return false end end
 local seen,count,sequence={},0,0
 for _,id in ipairs(state.toyReceiptOrder)do
  local r=state.toyReceipts[id]
  if not opaque(id)or seen[id]or not r or not receiptValid(r)or r.id~=id or r.sequence<=sequence or r.sequence>state.operationSeq or r.revision>state.revision then return false end
  if r.toyId and not Catalog.owns(state.toyUnlocks,r.toyId)then return false end
  if r.petId and not Eggs.isOwned(state.inventoryMask,r.petId)then return false end
  seen[id],count,sequence=true,count+1,r.sequence
 end
 if count>State.ReceiptLimit then return false end
 for k in pairs(state.toyReceiptOrder)do if not integer(k,count)or k<1 then return false end end
 for id in pairs(state.toyReceipts)do if not seen[id]then return false end end
 if state.lastToyResult then local r=state.toyReceipts[state.lastToyResult.id];if not r or not equal(r,state.lastToyResult)or state.toyReceiptOrder[count]~=r.id then return false end elseif count>0 then return false end
 local result=state.pendingToyResult
 if result then
  if not exact(result,{id=true,toyId=true,revision=true,catalogVersion=true})or result.catalogVersion~=Catalog.CatalogVersion then return false end
  local r=state.toyReceipts[result.id]
  if not r or r.action~="toyBuy"or r.toyId~=result.toyId or r.revision~=result.revision or r.resultId~=result.id then return false end
 end
 local reservation=state.toyReservation
 if reservation then
  if not exact(reservation,{quote=true,operationId=true,sequence=true,toyId=true})or not quoteValid(reservation.quote)or reservation.quote.action~="toyBuy"or not opaque(reservation.operationId)or reservation.sequence~=state.operationSeq+1 or reservation.quote.revision>state.revision or not table.find(reservation.quote.eligible,reservation.toyId)or not equal(reservation.quote.eligible,Catalog.remaining(state.toyUnlocks,reservation.quote.poolVersion))or state.toyReceipts[reservation.quote.id]or state.pendingToyResult or Guard.other(state,"toy")then return false end
 end
 return true
end
local function saveReceipt(state,receipt)
 state.toyReceipts[receipt.id]=receipt;table.insert(state.toyReceiptOrder,receipt.id)
 while #state.toyReceiptOrder>State.ReceiptLimit do
  local index=if state.pendingToyResult and state.toyReceiptOrder[1]==state.pendingToyResult.id then 2 else 1
  state.toyReceipts[table.remove(state.toyReceiptOrder,index)]=nil
 end
 state.lastToyResult=receipt
end
function State.purchaseEligibility(state,quote)
 if Guard.other(state,"toy")or state.pendingToyResult then return false,"RevealPending"end
 if state.toyReservation and(not quote or not equal(state.toyReservation.quote,quote))then return false,"PurchasePending"end
 local remaining=Catalog.remaining(state.toyUnlocks,quote and quote.poolVersion)
 if #remaining==0 then return false,"AllUnlocked"end
 if (state.inventoryMask or 0)==0 then return false,"MeetPipFirst"end
 if quote and not equal(quote.eligible,remaining)then return false,"PoolChanged"end
 if state.nectar<Catalog.Cost then return false,"NeedStars"end
 return true
end
function State.apply(state,candidate)
 local q=candidate.quote
 if not quoteValid(q)then return false,"InvalidToy"end
 if state.toyReservation and not equal(state.toyReservation,candidate)then return false,"PurchasePending"end
 if Guard.other(state,"toy")then return false,"RevealPending"end
 local r={id=q.id,action=q.action,quote=copy(q),operationId=candidate.operationId,sequence=candidate.sequence,revision=state.revision+1,catalogVersion=Catalog.CatalogVersion,cost=0,balanceBefore=state.nectar,balanceAfter=state.nectar}
 if q.action=="toyBuy"then
  if not state.toyReservation or not equal(state.toyReservation,candidate)then return false,"MissingReservation"end
  local ok,why=State.purchaseEligibility(state,q);if not ok then return false,why end
  if not table.find(q.eligible,candidate.toyId)or Catalog.owns(state.toyUnlocks,candidate.toyId)then return false,"PoolChanged"end
  r.toyId,r.resultId,r.cost=candidate.toyId,q.id,Catalog.Cost;r.balanceAfter=state.nectar-Catalog.Cost;state.nectar=r.balanceAfter
  state.toyUnlocks[candidate.toyId]=true;state.toyReservation=nil
  state.pendingToyResult={id=q.id,toyId=candidate.toyId,revision=r.revision,catalogVersion=Catalog.CatalogVersion}
 elseif q.action=="toyAck"then
  if not state.pendingToyResult or state.pendingToyResult.id~=q.resultId then return false,"ResultChanged"end
  r.acknowledgedResultId=q.resultId;state.pendingToyResult=nil
 else
  if not Eggs.isOwned(state.inventoryMask,q.petId)then return false,"Unowned"end
  if not Catalog.owns(state.toyUnlocks,q.toyId)then return false,"LockedToy"end
  if State.selected(state,q.petId)~=q.expectedToy then return false,"SelectionChanged"end
  if state.pendingToyResult and q.resultId~=state.pendingToyResult.id then return false,"RevealPending"end
  if q.resultId and(not state.pendingToyResult or state.pendingToyResult.id~=q.resultId or state.pendingToyResult.toyId~=q.toyId)then return false,"ResultChanged"end
  if q.toyId==q.expectedToy and not q.resultId then return false,"NoChange"end
  r.petId,r.toyId,r.selectedBefore,r.selectedAfter=q.petId,q.toyId,q.expectedToy,q.toyId
  state.petToys[q.petId]=q.toyId
  if q.resultId then r.acknowledgedResultId=q.resultId;state.pendingToyResult=nil end
 end
 saveReceipt(state,r);return true
end
function State.publicReceipt(receipt)
 if not receipt then return nil end;local r=copy(receipt);r.quote,r.operationId,r.sequence=nil,nil,nil;return r
end
function State.public(state)
 return {toyUnlocks=copy(state.toyUnlocks),petToys=copy(state.petToys),pendingToyResult=copy(state.pendingToyResult),lastToyResult=State.publicReceipt(state.lastToyResult),toyCatalogVersion=Catalog.CatalogVersion,toyPoolVersion=Catalog.PoolVersion}
end
return State
