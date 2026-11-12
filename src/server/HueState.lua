-- v6 item transactions. Historical paid proofs remain immutable in LegacyHueState.
local Shared=game:GetService("ReplicatedStorage").Shared
local Hue=require(Shared.HueCatalog)
local Eggs=require(Shared.EggCatalog)
local Legacy=require(script.Parent.LegacyHueState)
local Guard=require(script.Parent.HatchGuard)
local State={ReceiptLimit=64}
local function copy(v)if type(v)~="table"then return v end;local r={};for k,x in pairs(v)do r[k]=copy(x)end;return r end
local function integer(n,maximum)return type(n)=="number"and n==n and n%1==0 and n>=0 and n<=(maximum or 1000000000)end
local function opaque(s)return type(s)=="string"and #s>0 and #s<=100 end
local function exact(v,keys)if type(v)~="table"then return false end;for k in pairs(v)do if not keys[k]then return false end end;return true end
local function equal(a,b)
 if type(a)~=type(b)then return false end;if type(a)~="table"then return a==b end
 for k,v in pairs(a)do if not equal(v,b[k])then return false end end
 for k in pairs(b)do if a[k]==nil then return false end end;return true
end
local function oldView(state)local v=table.clone(state);if state.version==6 or state.version==7 or state.version==8 or state.version==9 then v.lastHueResult=state.legacyLastHueResult end;return v end
function State.validLegacy(state)return Legacy.validLegacy(state)end
function State.validV5(state)return Legacy.valid(state)end
function State.row(state,petId)
 return copy(state.petHues and state.petHues[petId]or{main=Hue.emptyCounts(),secondary=Hue.emptyCounts(),legacyLocked={main=false,secondary=false}})
end
function State.upgrade(state)
 local nextState=copy(state);nextState.version=6
 nextState.legacyLastHueResult=copy(state.lastHueResult);nextState.lastHueResult=nil
 nextState.hueInventory={rose=0,tide=0,citrus=0,iris=0,reset=0};nextState.petHues={};nextState.hueItemReceipts={};nextState.hueReceiptOrder={}
 if next(state.hues or {})or state.heldHueEgg then
  nextState.hueMigrationId="v5:"..state.revision..":"..state.operationSeq
  nextState.legacyHueEgg=copy(state.heldHueEgg)
 end
 nextState.hueMigrationAcknowledged=nextState.hueMigrationId==nil
 for petId in pairs(state.hues or {})do
  local old=Hue.get(state.hues,petId);local row=State.row(nextState,petId)
  row.main=Hue.mappedCounts(old,"main",old.mix or old.body)or Hue.emptyCounts()
  row.secondary=Hue.mappedCounts(old,"secondary",old.secondary)or Hue.emptyCounts()
  nextState.petHues[petId]=row
 end
 return nextState
end
local wire={
 hueBuy={id=true,catalogVersion=true},hueStore={id=true,catalogVersion=true,resultId=true},
 hueUse={id=true,catalogVersion=true,itemId=true,petId=true,channel=true,counts=true,pendingResultId=true},
 hueLegacyRedeem={id=true,catalogVersion=true,migrationId=true,token=true,purchaseId=true,itemId=true},
 hueLegacyPreset={id=true,catalogVersion=true,migrationId=true,petId=true,channel=true,presetId=true,counts=true,locked=true},
 hueMigrationAck={id=true,catalogVersion=true,migrationId=true},
}
local retired={hue=true,hueApply=true,hueEquip=true,hueMix=true,hueReset=true}
function State.isAction(action)return wire[action]~=nil or retired[action]==true end
function State.quote(action,value,revision)
 -- v250 hueBuy has no catalogVersion; its exact saved proof is still replayable.
 if retired[action]or(action=="hueBuy"and type(value)=="table"and value.catalogVersion==nil)then return Legacy.quote(action,value,revision)end
 local keys=wire[action]
 if not keys or not exact(value,keys)or not integer(revision)or not opaque(value.id)
  or not string.match(value.id,"^"..tostring(revision)..":[%w%-_]+$")or value.catalogVersion~=Hue.CatalogVersion then return nil end
 local q=copy(value);q.action,q.revision=action,revision
 if action=="hueBuy"then return q end
 if action=="hueStore"then return if opaque(q.resultId)then q else nil end
 if action=="hueMigrationAck"then return if opaque(q.migrationId)then q else nil end
 if action=="hueLegacyRedeem"then
  return if opaque(q.migrationId)and opaque(q.token)and opaque(q.purchaseId)and Hue.ById[q.itemId]then q else nil
 end
 if not Hue.Supported[q.petId]or(q.channel~="main"and q.channel~="secondary")or not Hue.validCounts(q.counts)then return nil end
 if action=="hueUse"then
  if not Hue.Items[q.itemId]or(q.pendingResultId~=nil and not opaque(q.pendingResultId))then return nil end
 else
  if not opaque(q.migrationId)or not opaque(q.presetId)or type(q.locked)~="boolean"then return nil end
 end
 return q
end
function State.same(a,b)return equal(a,b)end
local function quoteValid(q)
 if type(q)~="table"or not wire[q.action]or q.catalogVersion~=Hue.CatalogVersion then return false end
 local fields={};for k in pairs(wire[q.action])do fields[k]=q[k]end
 local canonical=State.quote(q.action,fields,q.revision);return canonical~=nil and equal(canonical,q)
end
function State.find(state,q)
 if not q then return nil end
 local r=(state.hueItemReceipts or {})[q.id]
 if not r and state.legacyHueRedemption and state.legacyHueRedemption.id==q.id then r=state.legacyHueRedemption end
 if not r then r=Legacy.find(oldView(state),q)end
 if r then return r,equal(r.quote,q)end
 return nil
end
function State.proof(state,candidate)
 local receipt,same=State.find(state,candidate.quote)
 return same==true and receipt.operationId==candidate.operationId and receipt.sequence==candidate.sequence
end
local receiptKeys={id=true,action=true,quote=true,operationId=true,sequence=true,revision=true,catalogVersion=true,cost=true,balanceBefore=true,balanceAfter=true,
 outcome=true,reason=true,petId=true,itemId=true,channel=true,countsBefore=true,countsAfter=true,inventoryBefore=true,inventoryAfter=true,
 resultId=true,acknowledgedResultId=true,presetId=true,migrationId=true,token=true,purchaseId=true}
local function validReceipt(r)
 if not exact(r,receiptKeys)or not quoteValid(r.quote)or r.id~=r.quote.id or r.action~=r.quote.action or not opaque(r.operationId)
  or not integer(r.sequence)or r.sequence<1 or not integer(r.revision)or r.revision<=r.quote.revision
  or r.catalogVersion~=Hue.CatalogVersion or not integer(r.balanceBefore)or not integer(r.balanceAfter)
  or not integer(r.cost)or r.balanceAfter~=r.balanceBefore-r.cost then return false end
 local q=r.quote
 local extra={}
 if q.action=="hueBuy"then extra={itemId=true,inventoryBefore=true,inventoryAfter=true,resultId=true,reason=true}
 elseif q.action=="hueLegacyRedeem"then extra={itemId=true,inventoryBefore=true,inventoryAfter=true,resultId=true,migrationId=true,token=true,purchaseId=true}
 elseif q.action=="hueUse"then extra={itemId=true,petId=true,channel=true,countsBefore=true,countsAfter=true,inventoryBefore=true,inventoryAfter=true,acknowledgedResultId=true}
 elseif q.action=="hueStore"then extra={acknowledgedResultId=true}
 elseif q.action=="hueLegacyPreset"then extra={petId=true,channel=true,countsBefore=true,countsAfter=true,presetId=true,migrationId=true}end
 if q.action=="hueMigrationAck"then extra={migrationId=true}end
 for _,key in ipairs({"reason","petId","itemId","channel","countsBefore","countsAfter","inventoryBefore","inventoryAfter","resultId","acknowledgedResultId","presetId","migrationId","token","purchaseId"})do
  if r[key]~=nil and not extra[key]then return false end
 end
 if r.outcome=="Refused"then return q.action=="hueBuy"and r.cost==0 and r.reason=="StackLimit"and r.resultId==nil and Hue.Items[r.itemId]~=nil and integer(r.inventoryBefore,Hue.StackLimit)and r.inventoryBefore==Hue.StackLimit and r.inventoryAfter==r.inventoryBefore end
 if r.outcome~="Applied"or r.reason~=nil then return false end
 if q.action=="hueBuy"or q.action=="hueLegacyRedeem"then
  if r.cost~=(if q.action=="hueBuy"then Hue.Cost else 0)or not Hue.Items[r.itemId]or not integer(r.inventoryBefore,Hue.StackLimit-1)
   or r.inventoryAfter~=r.inventoryBefore+1 or r.resultId~=r.id then return false end
  if q.action=="hueLegacyRedeem"and(r.itemId~=q.itemId or r.token~=q.token or r.purchaseId~=q.purchaseId or r.migrationId~=q.migrationId)then return false end
 elseif q.action=="hueUse"then
  if r.cost~=0 or r.petId~=q.petId or r.itemId~=q.itemId or r.channel~=q.channel or not equal(r.countsBefore,q.counts)or not Hue.validCounts(r.countsAfter)
   or not integer(r.inventoryBefore,Hue.StackLimit)or r.inventoryBefore<1 or r.inventoryAfter~=r.inventoryBefore-1
   or r.acknowledgedResultId~=q.pendingResultId then return false end
  local expected=copy(q.counts)
  if q.itemId=="reset"then if Hue.doseStrength(expected)==0 then return false end;expected=Hue.emptyCounts()
  else if expected[q.itemId]>=5 then return false end;expected[q.itemId]+=1 end
  if not equal(expected,r.countsAfter)then return false end
 elseif q.action=="hueStore"then
  if r.cost~=0 or r.acknowledgedResultId~=q.resultId then return false end
 elseif q.action=="hueLegacyPreset"then
  if r.cost~=0 or r.petId~=q.petId or r.channel~=q.channel or r.presetId~=q.presetId or r.migrationId~=q.migrationId
   or not equal(r.countsBefore,q.counts)or not Hue.validCounts(r.countsAfter)or q.locked then return false end
 elseif q.action=="hueMigrationAck"then
  if r.cost~=0 or r.migrationId~=q.migrationId then return false end
 else return false end
 return true
end
function State.validHistorical(state)
 if type(state)~="table"then return false end
 -- v7 adds an independent Material namespace; frozen v6 Hue rules validate
 -- the same working fields without rewriting a historical quote or receipt.
 if state.version==7 then state=table.clone(state);state.version=6 end
 if state.version~=6 then return Legacy.valid(state)end
 if not Legacy.valid(oldView(state))or not exact(state.hueInventory,{rose=true,tide=true,citrus=true,iris=true,reset=true})or type(state.petHues)~="table"
  or type(state.hueItemReceipts)~="table"or type(state.hueReceiptOrder)~="table"then return false end
 for _,id in ipairs(Hue.ItemOrder)do if not integer(state.hueInventory[id],Hue.StackLimit)then return false end end
 for pet,row in pairs(state.petHues)do
  if not Hue.Supported[pet]or not Eggs.isOwned(state.inventoryMask,pet)or not exact(row,{main=true,secondary=true,legacyLocked=true})
   or not Hue.validCounts(row.main)or not Hue.validCounts(row.secondary)or not exact(row.legacyLocked,{main=true,secondary=true})
   or type(row.legacyLocked.main)~="boolean"or type(row.legacyLocked.secondary)~="boolean"then return false end
 end
 local historical=next(state.hues or {})~=nil or state.heldHueEgg~=nil
 if historical and not opaque(state.hueMigrationId)then return false end
 for pet in pairs(state.hues or {})do if not state.petHues[pet]then return false end end
 if type(state.hueMigrationAcknowledged)~="boolean"or(state.hueMigrationId~=nil and not opaque(state.hueMigrationId))
  or(state.hueMigrationId==nil and not state.hueMigrationAcknowledged)then return false end
 local held=state.legacyHueEgg
 if held and(not state.hueMigrationId or not equal(held,state.heldHueEgg))then return false end
 local redeemed=state.legacyHueRedemption
 if state.heldHueEgg then
  if (held~=nil)==(redeemed~=nil)then return false end
  if redeemed and(not validReceipt(redeemed)or redeemed.action~="hueLegacyRedeem"or redeemed.migrationId~=state.hueMigrationId
   or redeemed.token~=state.heldHueEgg.token or redeemed.purchaseId~=state.heldHueEgg.purchaseId or redeemed.sequence>state.operationSeq or redeemed.revision>state.revision)then return false end
 elseif redeemed or held then return false end
 local seen,count,sequence={},0,0
 for index,id in ipairs(state.hueReceiptOrder)do
  if not integer(index,State.ReceiptLimit)or seen[id]then return false end
  local r=state.hueItemReceipts[id]
  if not opaque(id)or not r or not validReceipt(r)or r.id~=id or r.sequence<=sequence or r.sequence>state.operationSeq or r.revision>state.revision
   or Legacy.find(oldView(state),r.quote)then return false end
  if r.petId and not Eggs.isOwned(state.inventoryMask,r.petId)then return false end
  if r.action=="hueLegacyPreset"then
   local expected=Hue.mappedCounts(Hue.get(state.hues,r.petId),r.channel,r.presetId)
   if not state.hueMigrationId or r.migrationId~=state.hueMigrationId or not expected or not equal(expected,r.countsAfter)then return false end
  end
  if r.action=="hueLegacyRedeem"then local archived=state.heldHueEgg
   if not archived or r.migrationId~=state.hueMigrationId or r.token~=archived.token or r.purchaseId~=archived.purchaseId or state.legacyHueEgg or not equal(r,redeemed)then return false end
  end
  if r.action=="hueMigrationAck"and(r.migrationId~=state.hueMigrationId or not state.hueMigrationAcknowledged)then return false end
  seen[id],count,sequence=true,count+1,r.sequence
 end
 for k in pairs(state.hueReceiptOrder)do if not integer(k,count)or k<1 then return false end end
 for id in pairs(state.hueItemReceipts)do if not seen[id]then return false end end
 if count>State.ReceiptLimit then return false end
 if state.lastHueResult~=nil then
  if type(state.lastHueResult)~="table"then return false end
  local r=state.hueItemReceipts[state.lastHueResult.id];if not r or not equal(r,state.lastHueResult)or state.hueReceiptOrder[count]~=r.id then return false end
 elseif count>0 then return false end
 local p=state.pendingHueResult
 if p then
  if not exact(p,{id=true,itemId=true,quantity=true,inventoryAfter=true,catalogVersion=true,revision=true})or p.quantity~=1 or p.catalogVersion~=Hue.CatalogVersion then return false end
  local r=state.hueItemReceipts[p.id]
  if not r or r.outcome~="Applied"or(r.action~="hueBuy"and r.action~="hueLegacyRedeem")or r.resultId~=p.id or r.itemId~=p.itemId or r.inventoryAfter~=p.inventoryAfter or r.revision~=p.revision then return false end
 end
 local reservation=state.hueReservation
 if reservation then
  if not exact(reservation,{quote=true,operationId=true,sequence=true,itemId=true})or not quoteValid(reservation.quote)or reservation.quote.action~="hueBuy"
   or not opaque(reservation.operationId)or not Hue.Items[reservation.itemId]or reservation.sequence~=state.operationSeq+1
   or reservation.quote.revision>state.revision or state.hueItemReceipts[reservation.quote.id]or state.pendingHueResult or state.lastHatch then return false end
 end
 return true
end
function State.valid(state)
 if state.version==8 or state.version==9 then state=table.clone(state);state.version=7 end
 return State.validHistorical(state)
end
local function saveReceipt(state,r)
 state.hueItemReceipts[r.id]=r;table.insert(state.hueReceiptOrder,r.id)
 while #state.hueReceiptOrder>State.ReceiptLimit do
  local index=1;if state.pendingHueResult and state.hueReceiptOrder[index]==state.pendingHueResult.id then index=2 end
  local id=table.remove(state.hueReceiptOrder,index);state.hueItemReceipts[id]=nil
 end
 state.lastHueResult=r
end
function State.purchaseEligibility(state)
 if Guard.other(state,"hue")or state.pendingHueResult then return false,"RevealPending"end
 local owned=false;for pet in pairs(Hue.Supported)do if Eggs.isOwned(state.inventoryMask,pet)then owned=true;break end end
 if not owned then return false,"MeetPipFirst"end
 if state.nectar<Hue.Cost then return false,"NeedStars"end
 return true
end
function State.apply(state,candidate)
 local q=candidate.quote
 if q.catalogVersion~=Hue.CatalogVersion or not wire[q.action]then return false,"LegacyPurchaseClosed"end
 if state.hueReservation and not equal(state.hueReservation,candidate)then return false,"PurchasePending"end
 if Guard.other(state,"hue")then return false,"RevealPending"end
 local r={id=q.id,action=q.action,quote=copy(q),operationId=candidate.operationId,sequence=candidate.sequence,revision=state.revision+1,
  catalogVersion=Hue.CatalogVersion,cost=0,balanceBefore=state.nectar,balanceAfter=state.nectar,outcome="Applied"}
 if q.action=="hueBuy"or q.action=="hueLegacyRedeem"then
  if state.pendingHueResult then return false,"RevealPending"end
  local itemId=candidate.itemId
  if q.action=="hueBuy"then
   if not state.hueReservation or not equal(state.hueReservation,candidate)then return false,"MissingReservation"end
   local ok,why=State.purchaseEligibility(state);if not ok then return false,why end
  else
   local held=state.legacyHueEgg
   if q.migrationId~=state.hueMigrationId or not held or held.token~=q.token or held.purchaseId~=q.purchaseId then return false,"WrongEgg"end
   itemId=q.itemId;r.migrationId,r.token,r.purchaseId=q.migrationId,q.token,q.purchaseId
  end
  if not Hue.Items[itemId]then return false,"InvalidItem"end
  r.itemId,r.inventoryBefore=itemId,state.hueInventory[itemId]
  if r.inventoryBefore>=Hue.StackLimit then
   if q.action~="hueBuy"then return false,"StackLimit"end
   r.inventoryAfter,r.outcome,r.reason=r.inventoryBefore,"Refused","StackLimit";state.hueReservation=nil;saveReceipt(state,r);return true
  end
  r.inventoryAfter,r.resultId=r.inventoryBefore+1,q.id
  if q.action=="hueBuy"then r.cost=Hue.Cost;r.balanceAfter=state.nectar-Hue.Cost;state.nectar=r.balanceAfter;state.hueReservation=nil
  else state.legacyHueEgg=nil;state.legacyHueRedemption=copy(r) end
  state.hueInventory[itemId]=r.inventoryAfter
  state.pendingHueResult={id=q.id,itemId=itemId,quantity=1,inventoryAfter=r.inventoryAfter,catalogVersion=Hue.CatalogVersion,revision=r.revision}
 elseif q.action=="hueStore"then
  if not state.pendingHueResult or state.pendingHueResult.id~=q.resultId then return false,"ResultChanged"end
  r.acknowledgedResultId=q.resultId;state.pendingHueResult=nil
 elseif q.action=="hueMigrationAck"then
  if q.migrationId~=state.hueMigrationId then return false,"MigrationChanged"end
  if state.hueMigrationAcknowledged then return false,"AlreadyAcknowledged"end
  state.hueMigrationAcknowledged=true;r.migrationId=q.migrationId
 else
  if not Eggs.isOwned(state.inventoryMask,q.petId)then return false,"Unowned"end
  local row=State.row(state,q.petId)
  if not Hue.equalCounts(row[q.channel],q.counts)then return false,"CountsChanged"end
  r.petId,r.channel,r.countsBefore=q.petId,q.channel,copy(row[q.channel])
  if q.action=="hueUse"then
   local pending=state.pendingHueResult
   if pending then
    if q.pendingResultId~=pending.id or q.itemId~=pending.itemId then return false,"RevealPending"end
   elseif q.pendingResultId~=nil then return false,"ResultChanged"end
   if state.hueInventory[q.itemId]<1 then return false,"EmptyStock"end
   if q.itemId=="reset"then
    if Hue.doseStrength(row[q.channel])==0 then return false,"AlreadyOriginal"end
    row[q.channel]=Hue.emptyCounts();row.legacyLocked[q.channel]=false
   else
    if row[q.channel][q.itemId]>=5 then return false,"MaxDose"end
    row[q.channel][q.itemId]+=1;row.legacyLocked[q.channel]=true
   end
   r.itemId=q.itemId;r.inventoryBefore=state.hueInventory[q.itemId];r.inventoryAfter=r.inventoryBefore-1;state.hueInventory[q.itemId]=r.inventoryAfter
   r.acknowledgedResultId=q.pendingResultId;if pending then state.pendingHueResult=nil end
  elseif q.action=="hueLegacyPreset"then
   if state.pendingHueResult then return false,"RevealPending"end
   if q.migrationId~=state.hueMigrationId or not state.hueMigrationId then return false,"NoLegacyLibrary"end
   if q.locked~=row.legacyLocked[q.channel]or row.legacyLocked[q.channel]then return false,"LegacyLocked"end
   local mapped=Hue.mappedCounts(Hue.get(state.hues,q.petId),q.channel,q.presetId)
   if not mapped then return false,"LockedHue"end
   if Hue.equalCounts(mapped,row[q.channel])then return false,"NoChange"end
   row[q.channel]=mapped;r.presetId,r.migrationId=q.presetId,q.migrationId
  else return false,"InvalidHue"end
  r.countsAfter=copy(row[q.channel]);state.petHues[q.petId]=row
 end
 saveReceipt(state,r);return true
end
function State.publicReceipt(r)
 if not r then return nil end
 if not r.catalogVersion then return Legacy.publicReceipt(r)end
 local result=copy(r);result.quote,result.operationId,result.sequence=nil,nil,nil;return result
end
function State.public(state)
 local presets={}
 if state.hueMigrationId then for pet in pairs(state.hues or {})do local p=Hue.presets(state.hues,pet);if #p.main>0 then presets[pet]=p end end end
 local rows={}
 for pet in pairs(Hue.Supported)do if Eggs.isOwned(state.inventoryMask,pet)then rows[pet]=State.row(state,pet)end end
 return{hueInventory=copy(state.hueInventory),petHues=rows,pendingHueResult=copy(state.pendingHueResult),hueMigrationId=state.hueMigrationId,
  legacyHuePresets=presets,legacyHueEgg=copy(state.legacyHueEgg),hueMigrationAcknowledged=state.hueMigrationAcknowledged}
end
return State
