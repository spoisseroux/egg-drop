-- The Sleepy Nest on the save (ONBOARDING-V3-PLAN-2026-11-23 section 2 and the architect review, slice C). One optional,
-- additive field on the hatching save (no version bump), written only inside HatchProgress.transact (Hatching.nestLand,
-- Hatching.nestClaim, Hatching.nestTuck):
--   nest = {at, n, gift, op, receipt, tucked, pet}
--   at       unix seconds (server clock) the egg in the nest landed; ready Nest.Seconds later
--   n        eggs hatched so far (the egg in the nest is egg n + 1)
--   gift     what this egg was given at land: an item id string (hat, neck piece, toy, the Nest Charm) or a Stars number
--            (the egg's total Stars when the item was owned, missing or a Stars row)
--   op       the last claim written: the proof it committed (exactly once under retry, replay and two sessions)
--   receipt  what that claim paid {op, egg, kind, item, stars, pet}
--   tucked   Tuck in pressed for this egg
--   pet      the pet stored at land (hat and neck pieces are per pet)
--   closed   true once a malformed count was repaired (kept on every later write; never the Nest Charm)
-- Never part of HatchProgress.valid, never sanitised at load (FindsState pattern): it fails closed. A missing field is "no
-- egg yet" (n = 0); a malformed `n` reads as Nest.WeekLength (week done: after-week eggs only, and never the charm: the
-- repair is saved as `closed = true` with the next write and kept on every later one, so a clean-looking n never earns
-- it); a
-- malformed `at`, or one more than Nest.FutureSlack ahead, has no egg until a fresh land write that keeps `n`; a malformed
-- gift pays only its row's own Stars; a malformed receipt reads as none.
local Shared=game:GetService("ReplicatedStorage").Shared
local Nest=require(Shared.Nest)
local Pets=require(Shared.PetCatalog)
local Eggs=require(Shared.EggCatalog)
local Toys=require(Shared.ToyCatalog)
local Wear=require(Shared.WearableCatalog)
local Wearables=require(script.Parent.WearableState)

local State={}
-- Set by NestHost when it stops itself after repeated errors: no `public.nest` until the next mount.
State.halted=false
State.BalanceLimit=1000000000
State.Slots=table.freeze({hat="Hat",neck="Neck"})

local function finite(value)
	return type(value)=="number"and value==value and value~=math.huge and value~=-math.huge
end
local function integer(value,low,high)
	return finite(value)and value%1==0 and value>=low and value<=high
end
local function op(value)return type(value)=="string"and #value>=1 and #value<=100 end
local function itemId(value)return type(value)=="string"and #value>=1 and #value<=64 end
local function petOf(value)return if type(value)=="string"and Pets.byId[value]~=nil then value else nil end

-- The wardrobe item an egg row gives a pet: the cheapest common piece in the row's slot with no level gate and no
-- recolour, catalogue order breaking a tie. nil when the pet's rig sells none.
function State.wardrobePick(kind,petId)
	local slot=State.Slots[kind]
	if not slot or petOf(petId)==nil then return nil end
	local best=nil
	for _,item in ipairs(Wear.forPet(petId).order)do
		if item.slot==slot and item.tier=="common"and item.gate==nil and item.variant~=true
			and(best==nil or item.price<best.price)then best=item end
	end
	return best
end
-- A stored wardrobe id for this pet and slot (any week: rendering a saved id never depends on the clock).
local function wardrobeItem(kind,petId,id)
	local item=petOf(petId)and itemId(id)and Wear.forPet(petId,math.huge).byId[id]
	return if item and item.slot==State.Slots[kind]then item else nil
end
local function swapStars(price)
	return if integer(price,1,1000000000)then math.min(price,Nest.OwnedCap)else Nest.OwnedCap
end

-- What an egg row gives, decided at land against `state` and the pet stored then: the gift value to save.
function State.pick(state,row,petId)
	if row.kind=="hat"or row.kind=="neck"then
		local item=State.wardrobePick(row.kind,petId)
		if not item then return row.stars+Nest.OwnedCap end
		if not Eggs.isOwned(state.inventoryMask or 0,petId)or Wearables.owns(state,petId,item.id)then return row.stars+swapStars(item.price)end
		return item.id
	elseif row.kind=="toy"then
		local nextToy=Toys.fixedNext(Toys.remaining(state.toyUnlocks))
		return if nextToy then nextToy else row.stars+Nest.ToyOwnedStars
	elseif row.kind=="charm"then
		return Nest.Charm
	end
	return row.stars
end

-- The gift as it stands now: {kind, item, stars} (an item the pet already owns, or one that cannot be given, shows as
-- kind "stars" with its swapped Stars added). Never errors; a malformed stored gift pays the row's own Stars.
function State.resolve(state,entry)
	local row=Nest.gift(entry.n)
	local gift=entry.gift
	if row.kind=="stars"then return{kind="stars",stars=row.stars}end
	if row.kind=="charm"then return{kind="charm",item=Nest.Charm,stars=row.stars}end
	if row.kind=="hat"or row.kind=="neck"then
		if type(gift)=="string"then
			local item=wardrobeItem(row.kind,entry.pet,gift)
			if not item then return{kind="stars",stars=row.stars}end
			if not Eggs.isOwned(state.inventoryMask or 0,entry.pet)or Wearables.owns(state,entry.pet,item.id)
				or #Wearables.row(state,entry.pet).owned>=Wearables.Limit then
				return{kind="stars",stars=row.stars+swapStars(item.price)}
			end
			return{kind=row.kind,item=item.id,stars=row.stars}
		end
		return{kind="stars",stars=if integer(gift,row.stars,row.stars+Nest.OwnedCap)then gift else row.stars}
	end
	if row.kind=="toy"then
		if type(gift)=="string"then
			if not Toys.known(gift)or gift==Toys.Default then return{kind="stars",stars=row.stars}end
			if Toys.owns(state.toyUnlocks,gift)then return{kind="stars",stars=row.stars+Nest.ToyOwnedStars}end
			return{kind="toy",item=gift,stars=row.stars}
		end
		return{kind="stars",stars=if integer(gift,row.stars,row.stars+Nest.ToyOwnedStars)then gift else row.stars}
	end
	return{kind="stars",stars=row.stars}
end

local function receiptOf(value)
	if type(value)~="table"or not op(value.op)or not integer(value.egg,1,1000000000)or not integer(value.stars,0,1000)then return nil end
	local kind=value.kind
	if kind~="stars"and kind~="hat"and kind~="neck"and kind~="toy"and kind~="charm"then return nil end
	if kind~="stars"and not itemId(value.item)then return nil end
	return{op=value.op,egg=value.egg,kind=kind,item=if kind~="stars"then value.item else nil,stars=value.stars,pet=petOf(value.pet)}
end

-- A repaired copy of the field at `now`; never errors. `at` is nil when there is no usable egg.
--   {at?, n, gift, tucked, pet?, op?, receipt?, raw = the field was there}
function State.read(state,now)
	local raw=type(state)=="table"and state.nest or nil
	if raw==nil then return{n=0,tucked=false,raw=false}end
	-- Not a table: malformed, so closed (week done) and no egg until a land write.
	if type(raw)~="table"then return{n=Nest.WeekLength,tucked=false,raw=true,closed=true}end
	local out={n=Nest.count(raw.n),raw=true}
	-- A count that was (or is) malformed stays closed: the Nest Charm is never earned from a repaired n.
	out.closed=raw.closed==true or Nest.count(raw.n)~=raw.n
	if Nest.sane(raw,now)then out.at=raw.at end
	out.gift=raw.gift
	out.pet=petOf(raw.pet)
	out.tucked=out.at~=nil and raw.tucked==true
	if op(raw.op)then out.op=raw.op end
	out.receipt=receiptOf(raw.receipt)
	return out
end
-- Is there an egg growing (or ready) at `now`?
function State.landed(state,now)return State.read(state,now).at~=nil end
-- The Nest Charm (an earned rule, no saved data): only a well-formed count of seven or more earns it. A malformed `n`
-- reads as a finished week for the eggs, never as the charm.
function State.charmEarned(state)
	local raw=type(state)=="table"and state.nest or nil
	return type(raw)=="table"and raw.closed~=true and integer(raw.n,Nest.WeekLength,math.huge)
end

local function write(state,entry)
	state.nest={at=entry.at,n=entry.n,gift=entry.gift,op=entry.op,receipt=entry.receipt,tucked=entry.tucked==true,pet=entry.pet,
		closed=if entry.closed then true else nil}
end
local function ownedPet(state,petId)
	return petOf(petId)~=nil and Eggs.isOwned(state.inventoryMask or 0,petId)
end

-- candidate = {id, petId}: an egg lands now for the pet (stored with it), keeping `n`. Refused (nothing written) while an
-- egg is already growing or ready ("Growing"). `now` is read inside the write.
function State.land(state,candidate,now)
	if type(state)~="table"or type(candidate)~="table"or not op(candidate.id)or not finite(now)then return false,"InvalidNest"end
	if not ownedPet(state,candidate.petId)then return false,"NoPet"end
	local entry=State.read(state,now)
	if entry.at~=nil then return false,"Growing"end
	entry.at=now
	entry.pet=candidate.petId
	entry.gift=State.pick(state,Nest.gift(entry.n),candidate.petId)
	entry.tucked=false
	write(state,entry)
	return true
end

-- candidate = {id, n}: Tuck in for the egg the host saw (n is its count). Refused when that egg is gone or tucked already.
function State.tuck(state,candidate,now)
	if type(state)~="table"or type(candidate)~="table"or not op(candidate.id)or not integer(candidate.n,0,math.huge)or not finite(now)then return false,"InvalidNest"end
	local entry=State.read(state,now)
	if entry.at==nil then return false,"NoEgg"end
	if entry.n~=candidate.n then return false,"Changed"end
	if entry.tucked then return false,"Tucked"end
	entry.tucked=true
	write(state,entry)
	return true
end

local function grantWardrobe(state,petId,id)
	local item=Wear.forPet(petId,math.huge).byId[id]
	local row=Wearables.row(state,petId)
	table.insert(row.owned,id)
	local rows=table.clone(state.petWearables or {})
	rows[petId]=row
	state.petWearables=rows
	-- The hat (or neck piece) goes on at once.
	local worn=item and Wearables.equipResult(state,petId,item.slot,id)
	if worn then
		rows=table.clone(state.petWearables)
		rows[petId]=worn
		state.petWearables=rows
	end
end

-- candidate = {id, n, petId}: hatch the egg the host saw (n == captured n) when it is ready at `now`, inside the write.
-- Pays the gift (an item, or its Stars), counts the egg, and lands the next one for `petId` (the companion when the claim
-- was accepted; the stored pet when that is no longer owned). A toy gift refuses "Busy" while a toy purchase is reserved
-- or its result is waiting (never grants then). Refused claims write nothing.
function State.claim(state,candidate,now)
	if type(state)~="table"or type(candidate)~="table"or not op(candidate.id)or not integer(candidate.n,0,math.huge)or not finite(now)then return false,"InvalidNest"end
	local entry=State.read(state,now)
	if entry.at==nil then return false,"NoEgg"end
	if entry.n~=candidate.n then return false,"Changed"end
	if not Nest.ready(entry,now)then return false,"NotReady"end
	local gift=State.resolve(state,entry)
	if gift.kind=="toy"and(state.toyReservation~=nil or state.pendingToyResult~=nil)then return false,"Busy"end
	if gift.kind=="hat"or gift.kind=="neck"then grantWardrobe(state,entry.pet,gift.item)
	elseif gift.kind=="toy"then
		local unlocks=table.clone(state.toyUnlocks or {})
		unlocks[gift.item]=true
		state.toyUnlocks=unlocks
		-- The pet plays with it at once (as a confirmed Give to {pet}).
		if ownedPet(state,entry.pet)then
			local toys=table.clone(state.petToys or {})
			toys[entry.pet]=gift.item
			state.petToys=toys
		end
	end
	local stars=math.max(0,math.min(gift.stars,State.BalanceLimit-state.nectar))
	state.nectar+=stars
	local egg=entry.n+1
	local pet=if ownedPet(state,candidate.petId)then candidate.petId else entry.pet
	entry.receipt={op=candidate.id,egg=egg,kind=gift.kind,item=gift.item,stars=stars,pet=entry.pet}
	entry.op=candidate.id
	entry.n=egg
	entry.at=now
	entry.pet=pet
	entry.gift=State.pick(state,Nest.gift(egg),pet)
	entry.tucked=false
	write(state,entry)
	return true
end

function State.committed(state,operationId)
	return type(state)=="table"and type(state.nest)=="table"and state.nest.op~=nil and state.nest.op==operationId
end
function State.receipt(state,operationId)
	local proof=if State.committed(state,operationId)then receiptOf(state.nest.receipt)else nil
	return if proof and proof.op==operationId then proof else nil
end
-- What the owner's client is told about a claim (no op).
function State.publicReceipt(receipt)
	if type(receipt)~="table"then return nil end
	return{egg=receipt.egg,kind=receipt.kind,item=receipt.item,stars=receipt.stars,pet=receipt.pet}
end
-- The `public.nest` snapshot (Nest.PublicShape) at `now`, or nil when there is no egg yet.
function State.public(state,now)
	local entry=State.read(state,now)
	if entry.at==nil then return nil end
	local left=Nest.left(entry,now)
	return{at=entry.at,readyAt=entry.at+Nest.Seconds,left=left,ready=left<=0,n=entry.n,egg=entry.n+1,
		week=Nest.weekDone(entry.n),gift=State.resolve(state,entry),tucked=entry.tucked,pet=entry.pet or""}
end

return State
