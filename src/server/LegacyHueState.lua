-- Pure validation and mutations inside HatchProgress's existing leased transaction.
local Shared=game:GetService("ReplicatedStorage").Shared
local Catalog=require(Shared.HueCatalog)
local Hue=table.clone(Catalog);Hue.Supported=Catalog.LegacySupported
local Eggs=require(Shared.EggCatalog)
local State={}
local function integer(n,max)return type(n)=="number"and n%1==0 and n>=0 and n<=(max or 1000000000)end
local function exact(value,keys)
 if type(value)~="table"then return false end
 for key in pairs(value)do if not keys[key]then return false end end;return true
end
local function choice(row,slot,id)
 return id==(if slot=="body"then "original"else "default")or(Hue.ById[id]~=nil and row.ranks[id]>0)
end
local quoteKeys={id=true,action=true,petId=true,hue=true,rank=true,body=true,secondary=true,revision=true}
local function legacyQuote(action,value,revision)
 if not integer(revision)or(action~="hue"and action~="hueEquip")or type(value)~="table"then return nil end
 local keys=if action=="hue"then{id=true,petId=true,hue=true,rank=true}else{id=true,petId=true,body=true,secondary=true}
 if not exact(value,keys)or type(value.id)~="string"or #value.id>100 or #value.id<4
  or not string.match(value.id,"^"..tostring(revision)..":[%w%-_]+$")or not Hue.Supported[value.petId]then return nil end
 local q={id=value.id,action=action,petId=value.petId,revision=revision}
 if action=="hue"then
  if not Hue.ById[value.hue]or not integer(value.rank,3)then return nil end
  q.hue,q.rank=value.hue,value.rank
 else
  if value.body==nil and value.secondary==nil then return nil end
  if value.body~=nil and value.body~="original"and not Hue.ById[value.body]then return nil end
  if value.secondary~=nil and value.secondary~="default"and not Hue.ById[value.secondary]then return nil end
  q.body,q.secondary=value.body,value.secondary
 end
 return q
end
function State.same(a,b)
 if type(a)~="table"or type(b)~="table"then return false end
 for key in pairs(quoteKeys)do if a[key]~=b[key]then return false end end;return true
end
local function validRow(row)
 if not exact(row,{ranks=true,body=true,secondary=true})or not exact(row.ranks,{rose=true,tide=true,citrus=true,iris=true})then return false end
 for _,item in ipairs(Hue.Order)do if not integer(row.ranks[item.id],3)then return false end end
 return choice(row,"body",row.body)and choice(row,"secondary",row.secondary)
end
local function validReceipt(receipt)
 if not exact(receipt,{id=true,action=true,petId=true,quote=true,operationId=true,sequence=true,revision=true,balanceBefore=true,balanceAfter=true,
  cost=true,hue=true,oldRank=true,newRank=true,secondaryUnlocked=true,body=true,secondary=true})or type(receipt.quote)~="table"then return false end
 local q=receipt.quote;local value={id=q.id,petId=q.petId,hue=q.hue,rank=q.rank,body=q.body,secondary=q.secondary}
 -- Reconstruct only action-specific wire fields.
 if q.action=="hue"then value.body,value.secondary=nil,nil else value.hue,value.rank=nil,nil end
 local canonical=legacyQuote(q.action,value,q.revision)
 if not exact(q,quoteKeys)or not canonical or not State.same(q,canonical)or receipt.id~=q.id or receipt.action~=q.action or receipt.petId~=q.petId
  or type(receipt.operationId)~="string"or #receipt.operationId<1 or #receipt.operationId>100
  or not integer(receipt.sequence)or receipt.sequence<1 or not integer(receipt.revision)or receipt.revision~=q.revision+1
  or not integer(receipt.balanceBefore)or not integer(receipt.balanceAfter)then return false end
 if receipt.body~="original"and not Hue.ById[receipt.body]then return false end
 if receipt.secondary~="default"and not Hue.ById[receipt.secondary]then return false end
 if q.action=="hue"then
  return receipt.hue==q.hue and receipt.oldRank==q.rank and q.rank<3 and receipt.newRank==q.rank+1
   and receipt.cost==8 and receipt.balanceBefore>=8 and receipt.balanceAfter==receipt.balanceBefore-8
   and receipt.body==q.hue and receipt.secondaryUnlocked==(q.rank==0)
 end
 return receipt.cost==0 and receipt.balanceBefore==receipt.balanceAfter and receipt.hue==nil and receipt.oldRank==nil and receipt.newRank==nil
  and receipt.secondaryUnlocked==nil and(q.body==nil or q.body==receipt.body)and(q.secondary==nil or q.secondary==receipt.secondary)
end
function State.validLegacy(state)
 if state.hues~=nil then
  if type(state.hues)~="table"then return false end
  for pet,row in pairs(state.hues)do if not Hue.Supported[pet]or not validRow(row)or not Eggs.isOwned(state.inventoryMask,pet)then return false end end
 end
 local count,slots=0,{}
 if state.hueReceipts~=nil then
  if type(state.hueReceipts)~="table"then return false end
  for id,r in pairs(state.hueReceipts)do
   count+=1;if count>24 or not validReceipt(r)or r.action~="hue"or id~=r.id or r.sequence>state.operationSeq then return false end
   local slot=r.petId..":"..r.hue..":"..r.newRank
   if slots[slot]or Hue.get(state.hues,r.petId).ranks[r.hue]<r.newRank then return false end;slots[slot]=true
  end
 end
 for pet,row in pairs(state.hues or {})do
  for _,hue in ipairs(Hue.Order)do for rank=1,row.ranks[hue.id]do
   if not slots[pet..":"..hue.id..":"..rank]then return false end
  end end
 end
 if state.lastHueResult~=nil then
  local r=state.lastHueResult;if not validReceipt(r)or r.sequence>state.operationSeq then return false end
  if r.action=="hue"then
   local paid=state.hueReceipts and state.hueReceipts[r.id]
   if not paid or not State.same(paid.quote,r.quote)then return false end
   for key,value in pairs(paid)do if key~="quote"and r[key]~=value then return false end end
  end
 end
 return true
end

local wireKeys={
 hueBuy={id=true},hueApply={id=true,token=true,petId=true,hue=true,rank=true},
 hueEquip={id=true,petId=true,body=true,secondary=true},hueMix={id=true,petId=true,pair=true},hueReset={id=true,petId=true},
}
local allQuoteKeys={id=true,action=true,petId=true,hue=true,rank=true,body=true,secondary=true,revision=true,token=true,pair=true}
local function opaque(id)return type(id)=="string"and #id>0 and #id<=100 end
function State.isAction(action)return action=="hue"or wireKeys[action]~=nil end
function State.quote(action,value,revision)
 if action=="hue"then return legacyQuote(action,value,revision)end
 local keys=wireKeys[action]
 if not keys or not integer(revision)or not exact(value,keys)or not opaque(value.id)
  or not string.match(value.id,"^"..tostring(revision)..":[%w%-_]+$")then return nil end
 local q={id=value.id,action=action,revision=revision}
 if action=="hueBuy"then return q end
 if not Hue.Supported[value.petId]then return nil end;q.petId=value.petId
 if action=="hueApply"then
  if not opaque(value.token)or not Hue.ById[value.hue]or not integer(value.rank,3)then return nil end
  q.token,q.hue,q.rank=value.token,value.hue,value.rank
 elseif action=="hueEquip"then
  if value.body==nil and value.secondary==nil then return nil end
  if value.body~=nil and value.body~="original"and not Hue.ById[value.body]then return nil end
  if value.secondary~=nil and value.secondary~="default"and not Hue.ById[value.secondary]then return nil end
  q.body,q.secondary=value.body,value.secondary
 elseif action=="hueMix"then
  if not Hue.Mixes[value.pair]then return nil end;q.pair=value.pair
 end
 return q
end
function State.same(a,b)
 if type(a)~="table"or type(b)~="table"then return false end
 for k in pairs(allQuoteKeys)do if a[k]~=b[k]then return false end end
 return exact(a,allQuoteKeys)and exact(b,allQuoteKeys)
end
local receiptKeys={id=true,action=true,petId=true,quote=true,operationId=true,sequence=true,revision=true,balanceBefore=true,balanceAfter=true,
 cost=true,hue=true,oldRank=true,newRank=true,secondaryUnlocked=true,body=true,secondary=true,bodyMix=true,token=true,purchaseId=true}
local function validNewReceipt(r)
 if not exact(r,receiptKeys)or type(r.quote)~="table"then return false end
 local q=r.quote;local fields={}
 for k in pairs(wireKeys[q.action]or {})do fields[k]=q[k]end
 local canonical=State.quote(q.action,fields,q.revision)
 if not canonical or not State.same(q,canonical)or r.id~=q.id or r.action~=q.action or r.petId~=q.petId
  or not opaque(r.operationId)or not integer(r.sequence)or r.sequence<1 or not integer(r.revision)or r.revision~=q.revision+1
  or not integer(r.balanceBefore)or not integer(r.balanceAfter)then return false end
 if q.action=="hueBuy"then
  return r.cost==8 and r.balanceBefore>=8 and r.balanceAfter==r.balanceBefore-8 and r.token==r.operationId and r.purchaseId==r.id
   and r.body==nil and r.secondary==nil and r.bodyMix==nil and r.hue==nil and r.oldRank==nil and r.newRank==nil and r.secondaryUnlocked==nil
 end
 if r.cost~=0 or r.balanceAfter~=r.balanceBefore or(r.body~="original"and not Hue.ById[r.body])
  or(r.secondary~="default"and not Hue.ById[r.secondary])or(r.bodyMix~=nil and not Hue.Mixes[r.bodyMix])then return false end
 if q.action=="hueApply"then
  return r.token==q.token and opaque(r.purchaseId)and r.hue==q.hue and r.oldRank==q.rank and q.rank<3 and r.newRank==q.rank+1
   and r.body==q.hue and r.bodyMix==nil and r.secondaryUnlocked==(q.rank==0)
 end
 if r.token~=nil or r.purchaseId~=nil or r.hue~=nil or r.oldRank~=nil or r.newRank~=nil or r.secondaryUnlocked~=nil then return false end
 if q.action=="hueReset"then return r.body=="original"and r.secondary=="default"and r.bodyMix==nil end
 if q.action=="hueMix"then return r.bodyMix==q.pair end
 return q.action=="hueEquip"and(q.body==nil or(q.body==r.body and r.bodyMix==nil))and(q.secondary==nil or q.secondary==r.secondary)
end
local function validCurrentRow(row)
 if not exact(row,{ranks=true,body=true,secondary=true,mix=true})then return false end
 local plain={ranks=row.ranks,body=row.body,secondary=row.secondary}
 if not validRow(plain)then return false end
 if row.mix~=nil then local recipe=Hue.Mixes[row.mix];if not recipe or row.ranks[recipe.a]<1 or row.ranks[recipe.b]<1 then return false end end
 return true
end
function State.valid(state)
 if type(state)~="table"or(state.hues~=nil and type(state.hues)~="table")then return false end
 local slots,tokens,ids,count={},{},{},0
 for pet,row in pairs(state.hues or {})do
  if not Hue.Supported[pet]or not validCurrentRow(row)or not Eggs.isOwned(state.inventoryMask,pet)then return false end
 end
 if state.hues~=nil and type(state.hues)~="table"then return false end
 if state.hueReceipts~=nil and type(state.hueReceipts)~="table"then return false end
 if type(state.hueAssignments)~="table"then return false end
 for _,ledger in ipairs({state.hueReceipts or {},state.hueAssignments})do for id,r in pairs(ledger)do
  local old=ledger==state.hueReceipts
  if count>=24 or type(r)~="table"or id~=r.id or not(if old then validReceipt(r)and r.action=="hue"else validNewReceipt(r)and r.action=="hueApply")or r.sequence>state.operationSeq or ids[id]then return false end
  local slot=r.petId..":"..r.hue..":"..r.newRank
  if slots[slot]or Hue.get(state.hues,r.petId).ranks[r.hue]<r.newRank then return false end
  if not old then if tokens[r.token]then return false end;tokens[r.token]=r end
  slots[slot],ids[id],count=true,r,count+1
 end end
 for pet,row in pairs(state.hues or {})do for _,h in ipairs(Hue.Order)do for rank=1,row.ranks[h.id]do
  if not slots[pet..":"..h.id..":"..rank]then return false end
 end end end
 local purchase=state.hueLastPurchase
 if purchase~=nil then
  if not validNewReceipt(purchase)or purchase.action~="hueBuy"or purchase.sequence>state.operationSeq or ids[purchase.id]then return false end
  local used=tokens[purchase.token];if used and used.purchaseId~=purchase.id then return false end
  ids[purchase.id]=purchase
 end
 local held=state.heldHueEgg
 if held~=nil then
  if not exact(held,{token=true,purchaseId=true})or not purchase or held.token~=purchase.token or held.purchaseId~=purchase.id or tokens[held.token]then return false end
 elseif purchase and not tokens[purchase.token]then return false
 end
 local last=state.lastHueResult
 if last~=nil then
  if not(validReceipt(last)or validNewReceipt(last))or last.sequence>state.operationSeq then return false end
  local saved=ids[last.id]
  if last.action=="hue"or last.action=="hueApply"or last.action=="hueBuy"then
   if not saved or not State.same(saved.quote,last.quote)then return false end
   for k,v in pairs(saved)do if k~="quote"and last[k]~=v then return false end end
   for k,v in pairs(last)do if k~="quote"and saved[k]~=v then return false end end
  elseif saved then return false end
 end
 return true
end
function State.find(state,q)
 local receipt=(state.hueReceipts or {})[q.id]or(state.hueAssignments or {})[q.id]
 if not receipt and state.hueLastPurchase and state.hueLastPurchase.id==q.id then receipt=state.hueLastPurchase end
 if not receipt and state.lastHueResult and state.lastHueResult.id==q.id then receipt=state.lastHueResult end
 if receipt then return receipt,State.same(receipt.quote,q)end
 return nil
end
function State.proof(state,candidate)
 local receipt,same=State.find(state,candidate.quote)
 return same==true and receipt.operationId==candidate.operationId and receipt.sequence==candidate.sequence
end
function State.apply(state,candidate)
 local q=candidate.quote
 if q.action=="hue"then return false,"LegacyPurchaseClosed"end
 if state.lastHatch then return false,"RevealPending"end
 local receipt={id=q.id,action=q.action,petId=q.petId,quote=table.clone(q),operationId=candidate.operationId,sequence=candidate.sequence,
  revision=state.revision+1,balanceBefore=state.nectar,balanceAfter=state.nectar,cost=0}
 if q.action=="hueBuy"then
  if state.heldHueEgg then return false,"EggHeld"end
  if not Hue.capacity(state)then return false,"NoCapacity"end
  if state.nectar<8 then return false,"NeedStars"end
  receipt.cost,receipt.balanceAfter,receipt.token,receipt.purchaseId=8,state.nectar-8,candidate.operationId,q.id
  state.nectar-=8;state.heldHueEgg={token=receipt.token,purchaseId=q.id};state.hueLastPurchase=receipt
 else
  if not Eggs.isOwned(state.inventoryMask,q.petId)then return false,"Unowned"end
  local row=Hue.get(state.hues,q.petId)
  if q.action=="hueApply"then
   local held=state.heldHueEgg
   if not held or held.token~=q.token then return false,"WrongEgg"end
   if row.ranks[q.hue]~=q.rank then return false,"RankChanged"end
   if q.rank>=3 then return false,"MaxRank"end
   receipt.hue,receipt.oldRank,receipt.newRank,receipt.secondaryUnlocked=q.hue,q.rank,q.rank+1,q.rank==0
   receipt.token,receipt.purchaseId=held.token,held.purchaseId
   row.ranks[q.hue]+=1;row.body,row.mix=q.hue,nil;state.heldHueEgg=nil
   state.hueAssignments[q.id]=receipt
  elseif q.action=="hueEquip"then
   if q.body~=nil and not choice(row,"body",q.body)then return false,"LockedHue"end
   if q.secondary~=nil and not choice(row,"secondary",q.secondary)then return false,"LockedHue"end
   if q.body~=nil then row.body,row.mix=q.body,nil end
   if q.secondary~=nil then row.secondary=q.secondary end
  elseif q.action=="hueMix"then
   local mix=Hue.Mixes[q.pair]
   if row.ranks[mix.a]<1 or row.ranks[mix.b]<1 then return false,"LockedHue"end
   row.mix=q.pair
  elseif q.action=="hueReset"then row.body,row.secondary,row.mix="original","default",nil
  else return false,"InvalidHue"end
  receipt.body,receipt.secondary,receipt.bodyMix=row.body,row.secondary,row.mix
  state.hues=state.hues or {};state.hues[q.petId]=row
 end
 state.lastHueResult=receipt
 return true
end
function State.publicReceipt(receipt)
 if not receipt then return nil end
 local result={};for _,key in ipairs({"id","action","petId","hue","oldRank","newRank","cost","balanceBefore","balanceAfter","revision","body","secondary","bodyMix","secondaryUnlocked","token","purchaseId"})do result[key]=receipt[key]end
 return result
end
return State
