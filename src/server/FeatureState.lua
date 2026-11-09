-- Consumable cosmetic stock and separately earned/shown stages, all receipt bound.
local Shared=game:GetService("ReplicatedStorage").Shared
local Catalog=require(Shared.FeatureCatalog);local Eggs=require(Shared.EggCatalog)
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
local wire={featureBuy={id=true,catalogVersion=true,poolVersion=true},featureAck={id=true,catalogVersion=true,resultId=true},
 featureUse={id=true,catalogVersion=true,petId=true,featureId=true,expectedStage=true,pendingResultId=true},
 featureShow={id=true,catalogVersion=true,petId=true,featureId=true,expectedStage=true,expectedVisible=true,stage=true}}
function State.isAction(action)return wire[action]~=nil end
function State.quote(action,value,revision)
 if not wire[action]or not exact(value,wire[action])or not integer(revision)or not opaque(value.id)or not value.id:match("^"..tostring(revision)..":feature%-[%w%-_]+$")or value.catalogVersion~=Catalog.CatalogVersion then return nil end
 local q=copy(value);q.action,q.revision=action,revision
 if action=="featureBuy"then if q.poolVersion~=Catalog.PoolVersion then return nil end
 elseif action=="featureAck"then if not opaque(q.resultId)then return nil end
 else
  if Eggs.bit(q.petId)==0 or not Catalog.known(q.featureId)or not integer(q.expectedStage,Catalog.MaxStage)then return nil end
  if action=="featureUse"then if q.pendingResultId~=nil and not opaque(q.pendingResultId)then return nil end
  elseif not integer(q.stage,Catalog.MaxStage)or not integer(q.expectedVisible,Catalog.MaxStage)then return nil end
 end
 return q
end
function State.same(a,b)return equal(a,b)end
function State.row(state,petId)return copy((state.petFeatures or{})[petId]or Catalog.emptyRow())end
function State.upgrade(state)
 local s=copy(state);s.version=8;s.featureStock=Catalog.emptyStock();s.petFeatures={};s.featureReceipts={};s.featureReceiptOrder={};return s
end
function State.find(state,q)local r=q and(state.featureReceipts or{})[q.id];return r,r~=nil and equal(r.quote,q)end
function State.proof(state,candidate)local r,same=State.find(state,candidate.quote);return same==true and r.operationId==candidate.operationId and r.sequence==candidate.sequence end
local function quoteValid(q)
 if type(q)~="table"or not wire[q.action]then return false end
 local value={};for k in pairs(wire[q.action])do value[k]=q[k]end;local canonical=State.quote(q.action,value,q.revision);return canonical~=nil and equal(q,canonical)
end
local receiptKeys={id=true,action=true,quote=true,operationId=true,sequence=true,revision=true,catalogVersion=true,cost=true,balanceBefore=true,balanceAfter=true,outcome=true,reason=true,
 featureId=true,petId=true,inventoryBefore=true,inventoryAfter=true,earnedBefore=true,earnedAfter=true,visibleBefore=true,visibleAfter=true,resultId=true,acknowledgedResultId=true}
local function receiptValid(r)
 if not exact(r,receiptKeys)or not quoteValid(r.quote)or r.id~=r.quote.id or r.action~=r.quote.action or not opaque(r.operationId)or not integer(r.sequence)or r.sequence<1 or not integer(r.revision)or r.revision<=r.quote.revision or r.catalogVersion~=Catalog.CatalogVersion or not integer(r.cost)or not integer(r.balanceBefore)or not integer(r.balanceAfter)or r.balanceAfter~=r.balanceBefore-r.cost then return false end
 local q=r.quote;local extra={}
 if q.action=="featureBuy"then extra={featureId=true,inventoryBefore=true,inventoryAfter=true,resultId=true,reason=true}
 elseif q.action=="featureAck"then extra={acknowledgedResultId=true}
 else extra={featureId=true,petId=true,earnedBefore=true,earnedAfter=true,visibleBefore=true,visibleAfter=true};if q.action=="featureUse"then extra.inventoryBefore=true;extra.inventoryAfter=true;extra.acknowledgedResultId=true end end
 for _,key in ipairs({"featureId","petId","inventoryBefore","inventoryAfter","earnedBefore","earnedAfter","visibleBefore","visibleAfter","resultId","acknowledgedResultId","reason"})do if r[key]~=nil and not extra[key]then return false end end
 if r.outcome=="Refused"then return q.action=="featureBuy"and r.cost==0 and r.reason=="StackLimit"and Catalog.known(r.featureId)and r.inventoryBefore==Catalog.StackLimit and r.inventoryAfter==r.inventoryBefore and r.resultId==nil end
 if r.outcome~="Applied"or r.reason~=nil then return false end
 if q.action=="featureBuy"then return r.cost==Catalog.Cost and Catalog.known(r.featureId)and integer(r.inventoryBefore,Catalog.StackLimit-1)and r.inventoryAfter==r.inventoryBefore+1 and r.resultId==r.id end
 if r.cost~=0 then return false end
 if q.action=="featureAck"then return r.acknowledgedResultId==q.resultId end
 if r.petId~=q.petId or r.featureId~=q.featureId or r.earnedBefore~=q.expectedStage or not integer(r.visibleBefore,r.earnedBefore)then return false end
 if q.action=="featureUse"then return r.earnedBefore<5 and r.earnedAfter==r.earnedBefore+1 and r.visibleAfter==r.earnedAfter and integer(r.inventoryBefore,Catalog.StackLimit)and r.inventoryBefore>0 and r.inventoryAfter==r.inventoryBefore-1 and r.acknowledgedResultId==q.pendingResultId end
 return r.earnedAfter==r.earnedBefore and r.visibleBefore==q.expectedVisible and r.visibleAfter==q.stage and q.stage<=r.earnedBefore
end
function State.valid(state)
 if not exact(state.featureStock,{horns=true,claws=true,wings=true})or type(state.petFeatures)~="table"or type(state.featureReceipts)~="table"or type(state.featureReceiptOrder)~="table"then return false end
 for _,id in ipairs(Catalog.Order)do if not integer(state.featureStock[id],99)then return false end end
 for pet,row in pairs(state.petFeatures)do
  if not Eggs.isOwned(state.inventoryMask,pet)or not exact(row,{horns=true,claws=true,wings=true})then return false end
  for _,id in ipairs(Catalog.Order)do local feature=row[id];if not exact(feature,{earned=true,visible=true})or not integer(feature.earned,5)or not integer(feature.visible,feature.earned)then return false end end
 end
 local seen,count,seq={},0,0
 for _,id in ipairs(state.featureReceiptOrder)do
  local r=state.featureReceipts[id];if not opaque(id)or seen[id]or not r or not receiptValid(r)or r.id~=id or r.sequence<=seq or r.sequence>state.operationSeq or r.revision>state.revision or(r.petId and not Eggs.isOwned(state.inventoryMask,r.petId))then return false end
  seen[id],count,seq=true,count+1,r.sequence
 end
 if count>State.ReceiptLimit then return false end
 for k in pairs(state.featureReceiptOrder)do if not integer(k,count)or k<1 then return false end end
 for id in pairs(state.featureReceipts)do if not seen[id]then return false end end
 if state.lastFeatureResult then local r=state.featureReceipts[state.lastFeatureResult.id];if not r or not equal(r,state.lastFeatureResult)or state.featureReceiptOrder[count]~=r.id then return false end elseif count>0 then return false end
 local p=state.pendingFeatureResult
 if p then
  if not exact(p,{id=true,featureId=true,quantity=true,inventoryAfter=true,catalogVersion=true,revision=true})or p.quantity~=1 or p.catalogVersion~=Catalog.CatalogVersion then return false end
  local r=state.featureReceipts[p.id];if not r or r.action~="featureBuy"or r.outcome~="Applied"or r.resultId~=p.id or r.featureId~=p.featureId or r.inventoryAfter~=p.inventoryAfter or r.revision~=p.revision then return false end
 end
 local reservation=state.featureReservation
 if reservation and(not exact(reservation,{quote=true,operationId=true,sequence=true,featureId=true})or not quoteValid(reservation.quote)or reservation.quote.action~="featureBuy"or not opaque(reservation.operationId)or not Catalog.known(reservation.featureId)or reservation.sequence~=state.operationSeq+1 or reservation.quote.revision>state.revision or state.featureReceipts[reservation.quote.id]or p or Guard.other(state,"feature"))then return false end
 return true
end
local function saveReceipt(state,r)
 state.featureReceipts[r.id]=r;table.insert(state.featureReceiptOrder,r.id)
 while #state.featureReceiptOrder>State.ReceiptLimit do local index=if state.pendingFeatureResult and state.featureReceiptOrder[1]==state.pendingFeatureResult.id then 2 else 1;state.featureReceipts[table.remove(state.featureReceiptOrder,index)]=nil end
 state.lastFeatureResult=r
end
function State.purchaseEligibility(state,q)
 if Guard.other(state,"feature")or state.pendingFeatureResult then return false,"RevealPending"end
 if state.featureReservation and(not q or not equal(state.featureReservation.quote,q))then return false,"PurchasePending"end
 if Catalog.full(state.featureStock)then return false,"AllStacksFull"end
 if(state.inventoryMask or 0)==0 then return false,"MeetPipFirst"end
 if state.nectar<Catalog.Cost then return false,"NeedStars"end;return true
end
function State.apply(state,candidate)
 local q=candidate.quote;if not quoteValid(q)then return false,"InvalidFeature"end
 if state.featureReservation and not equal(state.featureReservation,candidate)then return false,"PurchasePending"end
 if Guard.other(state,"feature")then return false,"RevealPending"end
 local r={id=q.id,action=q.action,quote=copy(q),operationId=candidate.operationId,sequence=candidate.sequence,revision=state.revision+1,catalogVersion=Catalog.CatalogVersion,cost=0,balanceBefore=state.nectar,balanceAfter=state.nectar,outcome="Applied"}
 if q.action=="featureBuy"then
  if not state.featureReservation or not equal(state.featureReservation,candidate)then return false,"MissingReservation"end
  local ok,why=State.purchaseEligibility(state,q);if not ok then return false,why end
  if not Catalog.known(candidate.featureId)then return false,"InvalidFeature"end
  r.featureId,r.inventoryBefore=candidate.featureId,state.featureStock[candidate.featureId]
  state.featureReservation=nil
  if r.inventoryBefore==99 then r.inventoryAfter=r.inventoryBefore;r.outcome,r.reason="Refused","StackLimit";saveReceipt(state,r);return true end
  r.inventoryAfter,r.resultId,r.cost=r.inventoryBefore+1,q.id,Catalog.Cost;r.balanceAfter=state.nectar-r.cost;state.nectar=r.balanceAfter;state.featureStock[r.featureId]=r.inventoryAfter
  state.pendingFeatureResult={id=q.id,featureId=r.featureId,quantity=1,inventoryAfter=r.inventoryAfter,catalogVersion=Catalog.CatalogVersion,revision=r.revision}
 elseif q.action=="featureAck"then
  if not state.pendingFeatureResult or state.pendingFeatureResult.id~=q.resultId then return false,"ResultChanged"end
  r.acknowledgedResultId=q.resultId;state.pendingFeatureResult=nil
 else
  if not Eggs.isOwned(state.inventoryMask,q.petId)then return false,"Unowned"end
  local row=State.row(state,q.petId);local feature=row[q.featureId]
  if feature.earned~=q.expectedStage then return false,"StageChanged"end
  r.petId,r.featureId,r.earnedBefore,r.visibleBefore=q.petId,q.featureId,feature.earned,feature.visible
  local pending=state.pendingFeatureResult
  if pending and(q.action~="featureUse"or q.pendingResultId~=pending.id or q.featureId~=pending.featureId)then return false,"RevealPending"end
  if q.action=="featureUse"then
   if q.pendingResultId and(not pending or pending.id~=q.pendingResultId)then return false,"ResultChanged"end
   if feature.earned>=5 then return false,"MaxStage"end
   if state.featureStock[q.featureId]<1 then return false,"EmptyStock"end
   feature.earned+=1;feature.visible=feature.earned
   r.inventoryBefore=state.featureStock[q.featureId];r.inventoryAfter=r.inventoryBefore-1;state.featureStock[q.featureId]=r.inventoryAfter
   r.acknowledgedResultId=q.pendingResultId;if pending then state.pendingFeatureResult=nil end
  else
   if feature.visible~=q.expectedVisible then return false,"VisibilityChanged"end
   if q.stage>feature.earned then return false,"StageLocked"end
   if q.stage==feature.visible then return false,"NoChange"end;feature.visible=q.stage
  end
  r.earnedAfter,r.visibleAfter=feature.earned,feature.visible;state.petFeatures[q.petId]=row
 end
 saveReceipt(state,r);return true
end
function State.publicReceipt(r)if not r then return nil end;local p=copy(r);p.quote,p.operationId,p.sequence=nil,nil,nil;return p end
function State.public(state)return{featureStock=copy(state.featureStock),petFeatures=copy(state.petFeatures),pendingFeatureResult=copy(state.pendingFeatureResult),lastFeatureResult=State.publicReceipt(state.lastFeatureResult),featureCatalogVersion=Catalog.CatalogVersion,featurePoolVersion=Catalog.PoolVersion}end
return State
