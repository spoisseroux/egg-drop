-- The Outfit Egg's save field and its one write (DailyRack; ROTATION-BRIEF section 5, ARCH-REVIEW-ROTATION 1-3, 5).
-- Hatching v11, one optional top-level field, never part of HatchProgress.valid and never repaired at load (the `gifts`
-- pattern): every read is tolerant and FAILS CLOSED, unknown keys (inside the field or `last`) are newer data and kept.
--   rack = { v = 1,
--            last = {op, egg, pet, item, rarity, day, seen?},   the last egg opened (its reveal can replay)
--            ops  = {opId, ...},                                the last OpsKept request ids (idempotency)
--            toy  = {...} }                                     reserved for the toy colours (lane D); kept untouched
-- What the egg gives goes in petWearables[pet].owned, a field every build accepts (older builds hold an unknown id and
-- draw nothing for it). A malformed field is `broken`: the egg refuses (RackBroken) and nothing is written over it.
local Shared=game:GetService("ReplicatedStorage").Shared
local Rack=require(Shared.DailyRack)
local Eggs=require(Shared.EggCatalog)
local Wearables=require(script.Parent.WearableState)
local Guard=require(script.Parent.HatchGuard)
local State={}
State.Version=1
State.StoredV=255 -- frozen: the most `v` a later build may write
State.OpsKept=16 -- the ops this build keeps (newest last)
State.OpsLimit=64 -- frozen: the most ops a stored field may hold (a later build may keep more)
State.IdLimit=100 -- frozen: a request id's length
State.ItemLimit=32 -- frozen: an item id's length (WearableVariants.IdLimit)

local function integer(value,low,high)return type(value)=="number"and value==value and value%1==0 and value>=low and value<=high end
local function text(value,limit)return type(value)=="string"and #value>=1 and #value<=limit end
local function copy(v)if type(v)~="table"then return v end;local r={};for k,x in pairs(v)do r[k]=copy(x)end;return r end
State.opaque=function(value)return text(value,State.IdLimit)end

local function validLast(r)
	return type(r)=="table"and text(r.op,State.IdLimit)and text(r.egg,16)and text(r.pet,40)and text(r.item,State.ItemLimit)
		and text(r.rarity,16)and integer(r.day,-1e9,1e9)and(r.seen==nil or type(r.seen)=="boolean")
end
-- The tolerant view: {present, broken, last, ops (list)}.
function State.read(state)
	local r=type(state)=="table"and state.rack or nil
	if r==nil then return {present=false,broken=false,ops={}}end
	local broken={present=true,broken=true,ops={}}
	if type(r)~="table"or not integer(r.v,1,State.StoredV)then return broken end
	if r.last~=nil and not validLast(r.last)then return broken end
	local ops=r.ops
	if ops~=nil then
		if type(ops)~="table"then return broken end
		local count=0
		for key in pairs(ops)do count+=1;if type(key)~="number"then return broken end end
		if count~=#ops or count>State.OpsLimit then return broken end
		for _,id in ipairs(ops)do if not text(id,State.IdLimit)then return broken end end
	end
	return {present=true,broken=false,last=r.last,ops=ops or {}}
end
function State.broken(state)return State.read(state).broken end
-- A request already saved? -> the `last` record when it was the last one, true when it is in `ops`, else nil.
function State.find(state,op)
	local view=State.read(state)
	if view.broken or not text(op,State.IdLimit)then return nil end
	if view.last and view.last.op==op then return view.last end
	if table.find(view.ops,op)then return true end
	return nil
end
local function selectionMode(restricted)return if restricted==false then "random"else "fixed"end
State.selectionMode=selectionMode

-- The bound request (architect review 2) against a save and a day: true, or false and the refusal. No charge either way.
function State.view(state,petId,day,mode)
	local row=Wearables.row(state,petId)
	return Rack.view(petId,day,row.owned,mode),row
end

-- The write (inside UpdateAsync, and on a clone before it). c = {op, egg, petId, day, price, mode, poolKey, unit?, equip}
-- frozen in the candidate: a retry rolls the same unit over the same pool. Refusals, in order: RevealPending (another
-- reservation or reveal is open: Guard.other), RackBroken (never written over), AlreadySaved (the op is in `ops`),
-- Unowned, PriceChanged, PoolChanged, RackDone (every pick owned), ClosetFull (WearableState.Limit), NeedStars.
function State.apply(state,c)
	if Guard.other(state,nil)then return false,"RevealPending"end
	local view=State.read(state)
	if view.broken then return false,"RackBroken"end
	if State.find(state,c.op)then return false,"AlreadySaved"end
	if not Eggs.isOwned(state.inventoryMask,c.petId)then return false,"Unowned"end
	if c.price~=Rack.Price then return false,"PriceChanged"end
	local egg,row=State.view(state,c.petId,c.day,c.mode)
	if egg.poolKey~=c.poolKey then return false,"PoolChanged"end
	if egg.rest then return false,"RackDone"end
	if #row.owned>=Wearables.Limit then return false,"ClosetFull"end
	if state.nectar<c.price then return false,"NeedStars"end
	local item,rarity=Rack.roll(egg,c.unit)
	if not item then return false,"InvalidRoll"end
	rarity=rarity or Rack.rarityOf(c.petId,c.day,item)
	local granted,why=Wearables.grant(state,c.petId,item,c.equip==true)
	if not granted then return false,why end
	state.nectar-=c.price
	local field=if type(state.rack)=="table"then copy(state.rack)else {}
	field.v=if integer(field.v,1,State.StoredV)then field.v else State.Version
	local ops=table.clone(view.ops)
	table.insert(ops,c.op)
	while #ops>State.OpsKept do table.remove(ops,1)end
	field.ops=ops
	field.last={op=c.op,egg=c.egg,pet=c.petId,item=item,rarity=rarity,day=c.day}
	state.rack=field
	return true
end

-- What the owner's client sees of the last egg.
function State.publicLast(r)
	if type(r)~="table"then return nil end
	return {id=r.op,egg=r.egg,pet=r.pet,item=r.item,rarity=r.rarity,day=r.day,seen=r.seen==true}
end
-- The snapshot (owner only, the rack switch on). pets: every owned pet with wearables. See DailyRack.view for a view.
--   {day, price, mode, broken, last?, outfit = view of `outPet` (or nil), pets = {[petId] = view}}
-- Each view also carries `full` (the closet is at WearableState.Limit: the egg refuses ClosetFull).
function State.public(state,day,restricted,outPet,pets)
	local view=State.read(state)
	local mode=selectionMode(restricted)
	local out={day=day,price=Rack.Price,mode=mode,broken=view.broken,last=State.publicLast(view.last),pets={}}
	for _,petId in ipairs(pets or {})do
		if Eggs.isOwned(state.inventoryMask,petId)and Rack.period(petId)then
			local egg,row=State.view(state,petId,day,mode)
			egg.full=#row.owned>=Wearables.Limit
			if view.broken then egg.rest=true end
			out.pets[petId]=egg
		end
	end
	out.outfit=if type(outPet)=="string"then out.pets[outPet]else nil
	return out
end
return State
