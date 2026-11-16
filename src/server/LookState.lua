-- Customization Egg working state (plan 2026-11-16 §2 and §3). Hatching v11, additive optional
-- fields only (missing is valid, as with playDate, coachMask and bond):
--   finishInventory = {gloss=n, matte=n, jelly=n}       missing: all zero
--   petFinish       = {[petId]={sheen=-3..3, jelly=0..3}} missing: no dose look
--   charmUnlocks    = {dot=true, ring=true, pebble=true} (subset; written at load, see HatchProgress)
--   lookCharmMisses = 0..MissesLimit                       missing: 0
--   lookFound       = 0..FoundLimit bitmask (LookEggCatalog.bit)
-- The egg's actions (lookBuy, finishUse, finishClear) live inside HueState: they share its
-- reservation, pending result, receipt ring and ack. This module holds their rules; HueState
-- runs the shared quote and receipt checks first.
-- Every bound used here is a frozen stored bound (LookEggCatalog header), never a tunable.
local Shared=game:GetService("ReplicatedStorage").Shared
local Look=require(Shared.LookEggCatalog)
local Hue=require(Shared.HueCatalog)
local Eggs=require(Shared.EggCatalog)
local State={}
local function copy(v)if type(v)~="table"then return v end;local r={};for k,x in pairs(v)do r[k]=copy(x)end;return r end
local function integer(n,maximum)return type(n)=="number"and n==n and n%1==0 and n>=0 and n<=maximum end
local function opaque(s)return type(s)=="string"and #s>0 and #s<=100 end
local function equal(a,b)
 if type(a)~=type(b)then return false end;if type(a)~="table"then return a==b end
 for k,v in pairs(a)do if not equal(v,b[k])then return false end end
 for k in pairs(b)do if a[k]==nil then return false end end;return true
end
local finishKeys={gloss=true,matte=true,jelly=true}
local common={id=true,action=true,quote=true,operationId=true,sequence=true,revision=true,catalogVersion=true,cost=true,balanceBefore=true,balanceAfter=true,outcome=true}
local extras={
 lookBuy={itemId=true,inventoryBefore=true,inventoryAfter=true,resultId=true,missesBefore=true,missesAfter=true,substitutedFrom=true,reason=true},
 finishUse={itemId=true,petId=true,finishBefore=true,finishAfter=true,inventoryBefore=true,inventoryAfter=true,acknowledgedResultId=true},
 finishClear={petId=true,axis=true,finishBefore=true,finishAfter=true},
}
State.Wire={
 lookBuy={id=true,catalogVersion=true,poolVersion=true,price=true,selectionMode=true,fixedItemId=true,missingCharms=true,charmMisses=true},
 finishUse={id=true,catalogVersion=true,petId=true,itemId=true,finish=true,pendingResultId=true},
 finishClear={id=true,catalogVersion=true,petId=true,axis=true,finish=true},
}
function State.isAction(action)return extras[action]~=nil end
-- A stored pet id: any short id string. Saves and quotes are never checked against the tunable
-- roster (Hue.Supported) or the ownership bits, so retiring or renaming a pet can never turn an
-- old save into InvalidData (code review 2026-11-16). Writes still require an owned pet.
function State.validPetId(id)return type(id)=="string"and #id>=1 and #id<=64 and string.match(id,"^[%w_]+$")~=nil end

-- Reads (a missing field reads as empty).
function State.inventory(state,itemId)
 local kind=Look.kind(itemId)
 if kind=="hue"then return(state.hueInventory or {})[itemId]or 0
 elseif kind=="finish"then local f=state.finishInventory;return if type(f)=="table"and type(f[itemId])=="number"then f[itemId]else 0
 elseif kind=="charm"then return if type(state.charmUnlocks)=="table"and state.charmUnlocks[Look.shape(itemId)]==true then 1 else 0 end
 return 0
end
function State.missing(state)return Look.missing(state.charmUnlocks)end
function State.misses(state)return if Look.validMisses(state.lookCharmMisses)then state.lookCharmMisses else 0 end
function State.finish(state,petId)
 local row=type(state.petFinish)=="table"and state.petFinish[petId]
 return if Look.validFinish(row)then {sheen=row.sheen,jelly=row.jelly}else {sheen=0,jelly=0}
end
function State.fixedNext(state)return Look.fixedNext(State.missing(state),State.misses(state),state.hueInventory,state.finishInventory)end

-- A drawn item belongs to the quote: a charm only if its shape was missing, a fixed quote only
-- its named item.
function State.validDraw(q,itemId)
 local kind=Look.kind(itemId);if not kind then return false end
 if kind=="charm"and table.find(q.missingCharms,Look.shape(itemId))==nil then return false end
 return q.selectionMode~="fixed"or itemId==q.fixedItemId
end
-- Content of a quote whose shared fields (id, revision, catalogVersion, exact keys) HueState checked.
function State.validQuote(q)
 if q.action=="lookBuy"then
  if not Look.PoolVersions[q.poolVersion]or not Look.Prices[q.price]or(q.selectionMode~="random"and q.selectionMode~="fixed")
   or not Look.validMissing(q.missingCharms)or not Look.validMisses(q.charmMisses)then return false end
  if q.selectionMode=="fixed"then return State.validDraw(q,q.fixedItemId)end
  return q.fixedItemId==nil
 elseif q.action=="finishUse"then
  return State.validPetId(q.petId)and Look.kind(q.itemId)=="finish"and Look.validFinish(q.finish)and(q.pendingResultId==nil or opaque(q.pendingResultId))
 elseif q.action=="finishClear"then
  return State.validPetId(q.petId)and(q.axis=="sheen"or q.axis=="jelly")and Look.validFinish(q.finish)
 end
 return false
end

-- Receipt content (HueState checked the shared fields, the quote and the balance arithmetic).
function State.validReceipt(r)
 local q=r.quote;local allowed=extras[q.action];if not allowed then return false end
 for key in pairs(r)do if not common[key]and not allowed[key]then return false end end
 if q.action=="lookBuy"then
  if not Look.validMisses(r.missesBefore)or not Look.validMisses(r.missesAfter)then return false end
  local kind=Look.kind(r.itemId);if not kind then return false end
  if r.substitutedFrom~=nil and(Look.kind(r.substitutedFrom)~="charm"or kind=="charm")then return false end
  if not State.validDraw(q,r.substitutedFrom or r.itemId)then return false end
  if r.outcome=="Refused"then
   if r.cost~=0 or r.resultId~=nil or r.missesAfter~=r.missesBefore then return false end
   if r.reason=="StackLimit"then
    return kind~="charm"and r.inventoryBefore==Look.StackLimit and r.inventoryAfter==r.inventoryBefore
   elseif r.reason=="NeedStars"then
    return r.substitutedFrom==nil and r.inventoryBefore==nil and r.inventoryAfter==nil and r.balanceBefore<q.price
   end
   return false
  end
  if r.outcome~="Applied"or r.reason~=nil or r.cost~=q.price or r.resultId~=r.id then return false end
  if kind=="charm"then return r.inventoryBefore==0 and r.inventoryAfter==1 and r.missesAfter==0 end
  return integer(r.inventoryBefore,Look.StackLimit-1)and r.inventoryAfter==r.inventoryBefore+1
 elseif q.action=="finishUse"then
  return r.outcome=="Applied"and r.reason==nil and r.cost==0 and r.petId==q.petId and r.itemId==q.itemId and equal(r.finishBefore,q.finish)
   and Look.stepValid(r.finishBefore,r.finishAfter,r.itemId)and integer(r.inventoryBefore,Look.StackLimit)and r.inventoryBefore>=1
   and r.inventoryAfter==r.inventoryBefore-1 and r.acknowledgedResultId==q.pendingResultId
 end
 if r.outcome~="Applied"or r.reason~=nil or r.cost~=0 or r.petId~=q.petId or r.axis~=q.axis or not equal(r.finishBefore,q.finish)or not Look.validFinish(r.finishAfter)then return false end
 local other=if q.axis=="sheen"then "jelly"else "sheen"
 return r.finishBefore[q.axis]~=0 and r.finishAfter[q.axis]==0 and r.finishAfter[other]==r.finishBefore[other]
end
-- A saved lookBuy reservation: its draw belongs to its quote.
function State.validReservation(reservation)return State.validDraw(reservation.quote,reservation.itemId)end

-- The optional top-level fields.
function State.valid(state)
 local f=state.finishInventory
 if f~=nil then
  if type(f)~="table"then return false end
  for key,n in pairs(f)do if not finishKeys[key]or not integer(n,Look.StackLimit)then return false end end
 end
 local p=state.petFinish
 if p~=nil then
  if type(p)~="table"then return false end
  for pet,row in pairs(p)do if not State.validPetId(pet)or not Look.validFinish(row)then return false end end
 end
 local u=state.charmUnlocks
 if u~=nil then
  if type(u)~="table"then return false end
  -- Keys are egg shape ids (PetCharmCatalog.EggShapes, a list that only ever grows).
  for shape,value in pairs(u)do if table.find(Look.EggShapes,shape)==nil or value~=true then return false end end
 end
 if state.lookCharmMisses~=nil and not Look.validMisses(state.lookCharmMisses)then return false end
 if state.lookFound~=nil and not integer(state.lookFound,Look.FoundLimit)then return false end
 return true
end

-- Reserve-time checks only (plan §3.2 step 3). `context` = {available, selectionMode} from the host.
function State.eligibility(state,quote,context)
 context=context or {}
 if context.available~=true then return false,"NotReady"end
 if quote.selectionMode~=context.selectionMode then return false,"PolicyChanged"end
 if quote.poolVersion~=Look.PoolVersion or quote.price~=Look.Price then return false,"PoolChanged"end
 if not equal(quote.missingCharms,State.missing(state))or quote.charmMisses~=State.misses(state)then return false,"PoolChanged"end
 if quote.selectionMode=="fixed"and quote.fixedItemId~=State.fixedNext(state)then return false,"PoolChanged"end
 if state.nectar<quote.price then return false,"NeedStars"end
 return true
end

local function setFinish(state,petId,row)
 local rows=copy(state.petFinish)or {}
 rows[petId]=if row.sheen==0 and row.jelly==0 then nil else {sheen=row.sheen,jelly=row.jelly}
 state.petFinish=rows
end
-- Settlement of the saved candidate. Total (plan R4): it checks nothing live (no switch, price,
-- policy or pool check) and always resolves, so a saved reservation can never get stuck. `r` is
-- the receipt HueState started (cost 0, outcome Applied, revision set).
function State.settle(state,candidate,r)
 local q=candidate.quote
 r.missesBefore=State.misses(state);r.itemId=candidate.itemId
 if state.nectar<q.price then r.outcome,r.reason,r.missesAfter="Refused","NeedStars",r.missesBefore;return end
 local itemId=candidate.itemId
 if Look.kind(itemId)=="charm"and State.inventory(state,itemId)>0 then
  -- Not reachable while the quote binds the pool; defended so the egg still gives something.
  r.substitutedFrom=itemId
  itemId=Look.fixedNext({},0,state.hueInventory,state.finishInventory)or Look.JarOrder[1]
  r.itemId=itemId
 end
 local kind=Look.kind(itemId);local before=State.inventory(state,itemId)
 if kind~="charm"and before>=Look.StackLimit then
  r.inventoryBefore,r.inventoryAfter,r.outcome,r.reason,r.missesAfter=before,before,"Refused","StackLimit",r.missesBefore;return
 end
 r.cost=q.price;r.balanceAfter=state.nectar-q.price;state.nectar=r.balanceAfter
 if kind=="hue"then state.hueInventory[itemId]=before+1
 elseif kind=="finish"then
  local stock=copy(state.finishInventory)or {}
  for _,id in ipairs(Look.FinishItems)do stock[id]=stock[id]or 0 end
  stock[itemId]=before+1;state.finishInventory=stock
 else
  local unlocks=copy(state.charmUnlocks)or {};unlocks[Look.shape(itemId)]=true;state.charmUnlocks=unlocks
 end
 r.inventoryBefore,r.inventoryAfter,r.resultId=before,before+1,q.id
 r.missesAfter=if kind=="charm"or #State.missing(state)==0 then 0 else math.min(r.missesBefore+1,Look.MissesLimit)
 state.lookCharmMisses=r.missesAfter
 state.lookFound=bit32.bor(if integer(state.lookFound,Look.FoundLimit)then state.lookFound else 0,Look.bit(itemId))
 state.pendingHueResult={id=q.id,itemId=itemId,quantity=1,inventoryAfter=r.inventoryAfter,catalogVersion=Hue.CatalogVersion,revision=r.revision}
end
-- One finish jar on one pet (mirrors hueUse, including the pending-result ack).
function State.finishUse(state,q,r)
 if not Eggs.isOwned(state.inventoryMask,q.petId)then return false,"Unowned"end
 local pending=state.pendingHueResult
 if pending then
  if q.pendingResultId~=pending.id or q.itemId~=pending.itemId then return false,"RevealPending"end
 elseif q.pendingResultId~=nil then return false,"ResultChanged"end
 local row=State.finish(state,q.petId)
 if not equal(row,q.finish)then return false,"FinishChanged"end
 local stock=State.inventory(state,q.itemId)
 if stock<1 then return false,"EmptyStock"end
 local after,why=Look.step(row,q.itemId);if not after then return false,why end
 local inventory=copy(state.finishInventory);inventory[q.itemId]=stock-1;state.finishInventory=inventory
 setFinish(state,q.petId,after)
 r.petId,r.itemId,r.finishBefore,r.finishAfter,r.inventoryBefore,r.inventoryAfter=q.petId,q.itemId,row,after,stock,stock-1
 r.acknowledgedResultId=q.pendingResultId;if pending then state.pendingHueResult=nil end
 return true
end
-- Free "Original" for one axis (mirrors hueClear).
function State.finishClear(state,q,r)
 if not Eggs.isOwned(state.inventoryMask,q.petId)then return false,"Unowned"end
 local row=State.finish(state,q.petId)
 if not equal(row,q.finish)then return false,"FinishChanged"end
 if row[q.axis]==0 then return false,"AlreadyOriginal"end
 local after=copy(row);after[q.axis]=0
 setFinish(state,q.petId,after)
 r.petId,r.axis,r.finishBefore,r.finishAfter=q.petId,q.axis,row,after
 return true
end

function State.public(state)
 local rows={}
 for pet in pairs(Hue.Supported)do if Eggs.isOwned(state.inventoryMask,pet)then rows[pet]=State.finish(state,pet)end end
 local stock={};for _,id in ipairs(Look.FinishItems)do stock[id]=State.inventory(state,id)end
 local unlocks={};for _,shape in ipairs(Look.EggShapes)do if type(state.charmUnlocks)=="table"and state.charmUnlocks[shape]==true then unlocks[shape]=true end end
 return {finishInventory=stock,petFinish=rows,charmUnlocks=unlocks,lookCharmMisses=State.misses(state),
  lookFound=if integer(state.lookFound,Look.FoundLimit)then state.lookFound else 0,lookPoolVersion=Look.PoolVersion}
end
return State
