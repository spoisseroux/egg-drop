-- Paint pots (PAINT-SHINE-DRESS-PLAN, architect review 2026-11-27). One optional, additive field on the hatching save
-- (v11, no version bump; the StatEggState pattern):
--   paintPots = { receipts = { {op, itemId, price, inventoryAfter, revision, sequence, digest}, ... } }   oldest first
-- A bought pot is one more hue jar: `hueInventory[itemId] += 1` and `nectar -= price`, both fields every build already
-- validates, so older builds (which ignore unknown top-level fields) load these saves with jars and Stars intact.
-- Newer data is accepted (review item 4): unknown keys inside paintPots and inside a receipt are kept, an unknown item
-- id or a price this build does not sell is kept, and nothing here is an exact key set or a closed list of ops. Only
-- the shape this build needs to prove a replay is checked; sanitize repairs the rest at load, never failing it.
local Shared=game:GetService("ReplicatedStorage").Shared
local Pots=require(Shared.PaintPotCatalog)
local Hue=require(Shared.HueCatalog)
local Eggs=require(Shared.EggCatalog)
local Guard=require(script.Parent.HatchGuard)
local State={}
State.Action="potBuy"
local function integer(n,maximum)return type(n)=="number"and n==n and n%1==0 and n>=0 and n<=(maximum or 1e15)end
local function text(s,limit)return type(s)=="string"and #s>0 and #s<=limit end
function State.isAction(action)return action==State.Action end

-- The request: exactly {id, itemId, price} from this build's client; the id carries the revision it was made at.
function State.quote(action,value,revision)
	if action~=State.Action or type(value)~="table"or not integer(revision)then return nil end
	for key in pairs(value)do if key~="id"and key~="itemId"and key~="price"then return nil end end
	if not text(value.id,Pots.IdLimit)or not string.match(value.id,"^"..tostring(revision)..":[%w%-_]+$")then return nil end
	if not Pots.isItem(value.itemId)or not integer(value.price,1000000)or value.price<1 then return nil end
	return {action=action,id=value.id,itemId=value.itemId,price=value.price,revision=revision}
end
function State.digest(quote)return Pots.digest(quote.itemId,quote.price)end

-- Reads (a missing field reads as empty). A receipt only needs a string op and digest to prove a replay.
local function receipt(r)return type(r)=="table"and text(r.op,Pots.IdLimit)and text(r.digest,Pots.DigestLimit)end
local function receipts(state)
	local p=type(state)=="table"and state.paintPots
	return if type(p)=="table"and type(p.receipts)=="table"then p.receipts else {}
end
-- The saved receipt for a quote's id, and whether it is the same request (digest).
function State.find(state,quote)
	if type(quote)~="table"then return nil end
	for _,r in ipairs(receipts(state))do
		if receipt(r)and r.op==quote.id then return r,r.digest==State.digest(quote)end
	end
	return nil
end
-- Proof that this pending operation committed (HatchProgress.committed).
function State.proof(state,candidate)
	for _,r in ipairs(receipts(state))do
		if receipt(r)and r.op==candidate.quote.id and r.digest==candidate.digest and r.sequence==candidate.sequence then return true end
	end
	return false
end

-- Validation (fenced, valid): tolerant of newer data, strict only where a replay is proved.
function State.valid(state)
	local p=state.paintPots
	if p==nil then return true end
	if type(p)~="table"then return false end
	local list=p.receipts
	if list==nil then return true end
	if type(list)~="table"or #list>Pots.StoredLimit then return false end
	local count=0
	for key in pairs(list)do if type(key)~="number"or key%1~=0 or key<1 then return false end;count+=1 end
	if count~=#list then return false end
	for _,r in ipairs(list)do if not receipt(r)then return false end end
	return true
end
-- Load repair (beside Names.sanitize): drops what is not a receipt, keeps unknown keys, keeps the newest StoredLimit.
function State.sanitize(state)
	if type(state)~="table"or state.paintPots==nil then return end
	local p=state.paintPots
	if type(p)~="table"then state.paintPots=nil;return end
	local kept={}
	if type(p.receipts)=="table"then
		local keys={}
		for key in pairs(p.receipts)do if type(key)=="number"and key%1==0 and key>=1 then table.insert(keys,key)end end
		table.sort(keys)
		for _,key in ipairs(keys)do local r=p.receipts[key];if receipt(r)then table.insert(kept,r)end end
	end
	while #kept>Pots.StoredLimit do table.remove(kept,1)end
	local repaired=table.clone(p);repaired.receipts=kept;state.paintPots=repaired
end

-- One pot, inside UpdateAsync (and once before it on a copy, as transact does). A refusal writes nothing.
function State.apply(state,candidate)
	local q=candidate.quote
	-- Review item 2: any reservation or reveal still open (a Paint Egg settling, a pet hatch) refuses the pot, so the
	-- pot never advances operationSeq under a saved reservation.
	if Guard.other(state,"pot")then return false,"RevealPending"end
	local owned=false
	for pet in pairs(Hue.Supported)do if Eggs.isOwned(state.inventoryMask,pet)then owned=true;break end end
	if not owned then return false,"MeetPipFirst"end
	if type(state.hueInventory)~="table"then return false,"InvalidData"end
	local before=state.hueInventory[q.itemId]or 0
	if not integer(before,Hue.StackLimit)then return false,"InvalidData"end
	if before>=Hue.StackLimit then return false,"StackLimit"end
	if not integer(state.nectar)or state.nectar<q.price then return false,"NeedStars"end
	state.nectar-=q.price
	local stock=table.clone(state.hueInventory);stock[q.itemId]=before+1;state.hueInventory=stock
	local p=if type(state.paintPots)=="table"then table.clone(state.paintPots)else {}
	local list=if type(p.receipts)=="table"then table.clone(p.receipts)else {}
	table.insert(list,{op=q.id,itemId=q.itemId,price=q.price,inventoryAfter=before+1,revision=state.revision+1,sequence=candidate.sequence,digest=candidate.digest})
	while #list>Pots.ReceiptLimit do table.remove(list,1)end
	p.receipts=list;state.paintPots=p
	return true
end

-- What the owner's client sees of a receipt.
function State.publicReceipt(r)
	if not receipt(r)then return nil end
	return {id=r.op,action=State.Action,itemId=r.itemId,price=r.price,inventoryAfter=r.inventoryAfter,revision=r.revision,outcome="Applied"}
end
-- Snapshot fields: only when a pot was ever bought (off parity: nothing new in an untouched snapshot).
function State.public(state)
	local list=receipts(state)
	local last=list[#list]
	if not last then return {}end
	return {lastPotResult=State.publicReceipt(last)}
end
return State
