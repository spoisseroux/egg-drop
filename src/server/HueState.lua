-- Pure validation and mutations inside HatchProgress's existing leased transaction.
local Shared=game:GetService("ReplicatedStorage").Shared
local Hue=require(Shared.HueCatalog)
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
function State.quote(action,value,revision)
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
 local canonical=State.quote(q.action,value,q.revision)
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
function State.valid(state)
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
function State.find(state,q)
 local receipt=state.hueReceipts and state.hueReceipts[q.id]
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
 if state.lastHatch then return false,"RevealPending"end
 if not Eggs.isOwned(state.inventoryMask,q.petId)then return false,"Unowned"end
 local row=Hue.get(state.hues,q.petId)
 local receipt={id=q.id,action=q.action,petId=q.petId,quote=table.clone(q),operationId=candidate.operationId,sequence=candidate.sequence,
  revision=state.revision+1,balanceBefore=state.nectar,balanceAfter=state.nectar,cost=0}
 if q.action=="hue"then
  if row.ranks[q.hue]~=q.rank then return false,"RankChanged"end
  if q.rank>=3 then return false,"MaxRank"end
  if state.nectar<8 then return false,"NeedStars"end
  receipt.hue,receipt.oldRank,receipt.newRank,receipt.cost,receipt.secondaryUnlocked=q.hue,q.rank,q.rank+1,8,q.rank==0
  state.nectar-=8;row.ranks[q.hue]+=1;row.body=q.hue;receipt.balanceAfter=state.nectar
 else
  if q.body~=nil and not choice(row,"body",q.body)then return false,"LockedHue"end
  if q.secondary~=nil and not choice(row,"secondary",q.secondary)then return false,"LockedHue"end
  row.body,row.secondary=q.body or row.body,q.secondary or row.secondary
 end
 receipt.body,receipt.secondary=row.body,row.secondary
 state.hues=state.hues or {};state.hues[q.petId]=row
 if q.action=="hue"then state.hueReceipts=state.hueReceipts or {};state.hueReceipts[q.id]=receipt end
 state.lastHueResult=receipt
 return true
end
function State.publicReceipt(receipt)
 if not receipt then return nil end
 local result={};for _,key in ipairs({"id","action","petId","hue","oldRank","newRank","cost","balanceBefore","balanceAfter","revision","body","secondary","secondaryUnlocked"})do result[key]=receipt[key]end
 return result
end
return State
