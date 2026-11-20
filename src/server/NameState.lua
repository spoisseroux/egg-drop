-- Pet names (v2, V2-CUTE-ICONS-AND-NAMES-2026-11-20 2.7). Optional, additive fields on the
-- hatching save (v11, no version bump), the StatEggState / StatState pattern:
--   names    = { owned = {"biscuit", ...}, starter = 1, serial = n,
--                receipts = { {op=..., kind="egg", digest=..., piece=..., cost=8, mode="f"}, ... } }
--   petNames = { [petId] = {"biscuit", "sprout"} }      one or two piece ids; missing = species name
-- Missing is valid (every save before this build). Unknown keys, unknown well-formed piece ids
-- and unknown receipt fields are kept (a later build may append pieces or fields).
--
-- Architect review (2026-11-20), applied:
--  * Every bound in `valid` is a frozen storage limit, never a rule: a pet may store up to 4 ids
--    (a rename writes at most 2), ids up to 40 characters, type and length only.
--  * Earned pieces are written into `owned` when reached (catchUp), never derived on read, so
--    retuning XP or the book can never take a name away. catchUp runs at load and inside every
--    transaction after its apply; the callers pcall it and restore on error, and it restores on
--    an invalid result itself, so it can never fail a load or an unrelated write.
--  * `owned` is never dropped as a whole: sanitize keeps known catalogue ids first; a save still
--    invalid drops receipts, then petNames, then owned (dropInvalid), each with a warning.
--  * Names Egg: receipt replay first (same digest AlreadySaved, else OperationConflict), then
--    PoolChanged, AllOwned, NeedStars, NameLimit. The quote key carries the pool count, the fixed
--    next id and `serial`, so a stale quote never charges.
local Shared=game:GetService("ReplicatedStorage").Shared
local Catalog=require(Shared.NameCatalog)
local StatCatalog=require(Shared.StatCatalog)
local Eggs=require(Shared.EggCatalog)
local Pets=require(Shared.PetCatalog)
local Stats=require(script.Parent.StatState)

local State={}
-- Frozen storage bounds (never tie these to rules or tuning).
State.OwnedStored=256
State.IdStored=40
State.PetLimit=32
State.PetPiecesStored=4
State.ReceiptStored=64
State.ReceiptKeep=32
State.SerialLimit=1000000
State.StarterLimit=1000

local function integer(value,maximum)
	return type(value)=="number"and value==value and value%1==0 and value>=0 and value<=maximum
end
local function id(value,length)return type(value)=="string"and #value>=1 and #value<=(length or State.IdStored)end
local function count(t)local n=0;for _ in pairs(t)do n+=1 end;return n end
local function isArray(t)return type(t)=="table"and count(t)==#t end
local function copy(v)if type(v)~="table"then return v end;local r={};for k,x in pairs(v)do r[k]=copy(x)end;return r end

-- Only the fields this build reads are checked (a later build may add receipt fields).
local function validReceipt(r)
	if type(r)~="table"or not id(r.op,80)or not id(r.kind,16)then return false end
	if r.digest~=nil and not(type(r.digest)=="string"and #r.digest<=160)then return false end
	return r.piece==nil or id(r.piece)
end
local function validOwned(list)
	if not isArray(list)or #list>State.OwnedStored then return false end
	for _,v in ipairs(list)do if not id(v)then return false end end
	return true
end
local function validPiecesList(list)
	if not isArray(list)or #list<1 or #list>State.PetPiecesStored then return false end
	for _,v in ipairs(list)do if not id(v)then return false end end
	return true
end
local namesChecks={
	owned=validOwned,
	starter=function(v)return integer(v,State.StarterLimit)end,
	serial=function(v)return integer(v,State.SerialLimit)end,
	receipts=function(list)
		if not isArray(list)or #list>State.ReceiptStored then return false end
		for _,r in ipairs(list)do if not validReceipt(r)then return false end end
		return true
	end,
}
local function validPetNames(map)
	if type(map)~="table"or count(map)>State.PetLimit then return false end
	for pet,list in pairs(map)do if not id(pet)or not validPiecesList(list)then return false end end
	return true
end

-- Tolerant: every field may be missing.
function State.valid(state)
	local names=state.names
	if names~=nil then
		if type(names)~="table"then return false end
		for key,check in pairs(namesChecks)do if names[key]~=nil and not check(names[key])then return false end end
	end
	if state.petNames~=nil and not validPetNames(state.petNames)then return false end
	return true
end

-- Known catalogue ids first (catalogue order), then unknown ones sorted: a trim never cuts a
-- paid or earned piece in favour of junk.
local function rankedOwned(list)
	local seen,known,unknown={}, {}, {}
	for _,v in ipairs(list)do
		if id(v)and not seen[v]then
			seen[v]=true
			if Catalog.ById[v]then table.insert(known,v)else table.insert(unknown,v)end
		end
	end
	table.sort(known,function(a,b)return Catalog.ById[a].index<Catalog.ById[b].index end)
	table.sort(unknown)
	for _,v in ipairs(unknown)do table.insert(known,v)end
	while #known>State.OwnedStored do table.remove(known)end
	return known
end
function State.sanitizeOwned(value)
	if type(value)~="table"then return nil end
	local list={}
	for _,v in ipairs(value)do table.insert(list,v)end
	-- Keep the saved order for ids already in a valid list (no churn); repair only when needed.
	if validOwned(value)then
		local seen,dupes={},false
		for _,v in ipairs(value)do if seen[v]then dupes=true end;seen[v]=true end
		if not dupes then return list end
	end
	return rankedOwned(list)
end
-- Load-time repair, one subfield at a time.
function State.sanitize(state)
	if type(state)~="table"then return end
	if state.names~=nil then
		if type(state.names)~="table"then state.names=nil
		else
			local names=state.names
			if names.owned~=nil then names.owned=State.sanitizeOwned(names.owned)end
			if names.starter~=nil and not namesChecks.starter(names.starter)then names.starter=nil end
			if names.serial~=nil and not namesChecks.serial(names.serial)then
				local v=names.serial
				names.serial=if type(v)=="number"and v==v and math.abs(v)~=math.huge then math.clamp(math.floor(v),0,State.SerialLimit)else nil
			end
			if names.receipts~=nil then
				local kept={}
				if type(names.receipts)=="table"then
					for _,r in ipairs(names.receipts)do if validReceipt(r)then table.insert(kept,r)end end
				end
				while #kept>State.ReceiptStored do table.remove(kept,1)end
				names.receipts=kept
			end
		end
	end
	if state.petNames~=nil then
		if type(state.petNames)~="table"then state.petNames=nil
		else
			local kept,n={},0
			local keys={}
			for pet in pairs(state.petNames)do if id(pet)then table.insert(keys,pet)end end
			table.sort(keys)
			for _,pet in ipairs(keys)do
				local list=state.petNames[pet]
				if n<State.PetLimit and validPiecesList(list)then kept[pet]=copy(list);n+=1 end
			end
			state.petNames=if next(kept)then kept else nil
		end
	end
end
-- After sanitize: a save that still does not validate loses receipts, then petNames, then owned
-- (never the load). Unreachable while sanitize is complete; logged if hit.
function State.dropInvalid(state)
	if type(state)~="table"or State.valid(state)then return end
	if type(state.names)=="table"and state.names.receipts~=nil then warn("Egg Drop: dropped names.receipts at load");state.names.receipts=nil end
	if State.valid(state)then return end
	if state.petNames~=nil then warn("Egg Drop: dropped petNames at load");state.petNames=nil end
	if State.valid(state)then return end
	if type(state.names)=="table"and state.names.owned~=nil then warn("Egg Drop: dropped names.owned at load");state.names.owned=nil end
	if State.valid(state)then return end
	warn("Egg Drop: dropped names at load");state.names=nil
end

-- Reads (a missing field reads as empty).
local function names(state)return if type(state.names)=="table"then state.names else {}end
function State.owned(state)local v=names(state).owned;return if validOwned(v)then v else {}end
function State.serial(state)local v=names(state).serial;return if namesChecks.serial(v)then v else 0 end
function State.receipts(state)local v=names(state).receipts;return if namesChecks.receipts(v)then v else {}end
function State.receipt(state,op)
	for _,r in ipairs(State.receipts(state))do if r.op==op then return r end end
	return nil
end
function State.petName(state,petId)
	local map=state.petNames
	local list=type(map)=="table"and map[petId]
	return if validPiecesList(list)then list else nil
end
local function writeNames(state,changes)
	local nextNames=copy(names(state))
	for key,value in pairs(changes)do nextNames[key]=value end
	state.names=nextNames
end

local function anyPetOwned(state)
	for _,pet in ipairs(Pets.collection)do if Eggs.isOwned(state.inventoryMask or 0,pet.id)then return true end end
	return false
end
-- The progress the earned rules read: levels of every owned pet (known pets only; StatState keeps
-- unknown ids) and the number of distinct claimed book milestones.
function State.progress(state)
	local levels={}
	for _,pet in ipairs(Pets.collection)do
		if Eggs.isOwned(state.inventoryMask or 0,pet.id)then
			local row={}
			for _,stat in ipairs(StatCatalog.Order)do row[stat]=StatCatalog.levelFor(Stats.xp(state,pet.id,stat))end
			table.insert(levels,row)
		end
	end
	local claimed=0
	local book=type(state.book)=="table"and state.book.claimed
	if type(book)=="table"then
		local seen={}
		for _,v in ipairs(book)do if type(v)=="string"and not seen[v]then seen[v]=true;claimed+=1 end end
	end
	return {levels=levels,claimed=claimed}
end

-- Grants the six starters (once any pet is owned) and every earned piece the save qualifies for.
-- Returns the ids added (catalogue order). Never leaves the save invalid: it restores the old
-- value if the result does not validate. Deterministic (no clock, no random): safe inside a
-- retried UpdateAsync callback.
function State.catchUp(state)
	if type(state)~="table"then return {}end
	if state.names~=nil and type(state.names)~="table"then return {}end
	if not anyPetOwned(state)then return {}end
	local owned=State.owned(state)
	local set=Catalog.ownedSet(owned)
	local add={}
	for _,v in ipairs(Catalog.starterIds())do if not set[v]then table.insert(add,v);set[v]=true end end
	for _,v in ipairs(Catalog.earnedIds(State.progress(state)))do if not set[v]then table.insert(add,v);set[v]=true end end
	local starterDone=names(state).starter~=nil
	if #add==0 and starterDone then return {}end
	local before=state.names
	local nextOwned=table.clone(owned)
	local added={}
	for _,v in ipairs(add)do
		if #nextOwned>=State.OwnedStored then break end
		table.insert(nextOwned,v);table.insert(added,v)
	end
	writeNames(state,{owned=nextOwned,starter=if starterDone then names(state).starter else 1})
	if not State.valid(state)then state.names=before;return {}end
	return added
end

-- The Names Egg pool and quote for this save and mode.
function State.quote(state,mode)
	local remaining=Catalog.remaining(State.owned(state))
	return {remaining=remaining,key=Catalog.quoteKey(mode,remaining,State.serial(state)),next=if mode~="random"then remaining[1]else nil}
end
local function pushReceipt(state,r)
	local list=copy(State.receipts(state))
	table.insert(list,r)
	while #list>State.ReceiptKeep do table.remove(list,1)end
	writeNames(state,{receipts=list})
end

-- One Names Egg, inside the transaction. c = {op, digest, mode, quoteKey, unit} (unit only in
-- random mode, drawn once at request time and frozen in the candidate).
function State.buy(state,c)
	local saved=State.receipt(state,c.op)
	if saved then return false,if saved.digest==c.digest then "AlreadySaved"else "OperationConflict"end
	local quote=State.quote(state,c.mode)
	if quote.key~=c.quoteKey then return false,"PoolChanged"end
	if #quote.remaining==0 then return false,"AllOwned"end
	if type(state.nectar)~="number"or state.nectar<Catalog.Price then return false,"NeedStars"end
	local owned=State.owned(state)
	if #owned>=State.OwnedStored then return false,"NameLimit"end
	local serial=State.serial(state)+1
	if serial>State.SerialLimit then return false,"NameLimit"end
	local piece=Catalog.pick(quote.remaining,c.mode,c.unit)
	if not piece then return false,"InvalidRoll"end
	state.nectar-=Catalog.Price
	local nextOwned=table.clone(owned);table.insert(nextOwned,piece)
	writeNames(state,{owned=nextOwned,serial=serial})
	pushReceipt(state,{op=c.op,kind="egg",digest=c.digest,piece=piece,cost=Catalog.Price,mode=if c.mode=="random"then "r"else "f"})
	return true
end

-- A rename, inside the transaction. c = {petId, ids} (0 ids clears to the species name).
function State.setName(state,c)
	if type(c.petId)~="string"or not Pets.byId[c.petId]then return false,"InvalidPet"end
	if not Eggs.isOwned(state.inventoryMask or 0,c.petId)then return false,"Unowned"end
	local ok,reason=Catalog.validChoice(c.ids,State.owned(state))
	if not ok then return false,reason end
	local map=copy(type(state.petNames)=="table"and state.petNames or {})
	if #c.ids==0 then map[c.petId]=nil
	else
		if map[c.petId]==nil and count(map)>=State.PetLimit then return false,"NameLimit"end
		map[c.petId]=table.clone(c.ids)
	end
	state.petNames=if next(map)then map else nil
	return true
end
function State.sameName(state,petId,ids)
	local current=State.petName(state,petId)or {}
	if #current~=#ids then return false end
	for i,v in ipairs(ids)do if current[i]~=v then return false end end
	return true
end

function State.publicReceipt(r)
	if type(r)~="table"then return nil end
	local result=copy(r);result.digest=nil;return result
end
-- For the owner's client: owned pieces, per-pet names, and the Names Egg card (the pool with its
-- real odds, or the fixed next piece for a restricted player), its quote key and the last receipt.
function State.public(state,mode)
	local quote=State.quote(state,mode)
	local petNames={}
	for _,pet in ipairs(Pets.collection)do
		if Eggs.isOwned(state.inventoryMask or 0,pet.id)then
			local list=State.petName(state,pet.id)
			if list then petNames[pet.id]=copy(list)end
		end
	end
	local receipts=State.receipts(state)
	return {
		version=Catalog.Version,poolVersion=Catalog.PoolVersion,price=Catalog.Price,mode=mode,
		owned=copy(State.owned(state)),petNames=petNames,
		remaining=quote.remaining,next=quote.next,quoteKey=quote.key,poolSize=#Catalog.EggOrder,
		last=State.publicReceipt(receipts[#receipts]),
	}
end
-- For other players: the board attribute Catalog.Attribute. Ids only, never text; owned pets only.
function State.publicNames(state)
	local pets={}
	if type(state)=="table"then
		for _,pet in ipairs(Pets.collection)do
			if Eggs.isOwned(state.inventoryMask or 0,pet.id)then
				local list=State.petName(state,pet.id)
				if list then pets[pet.id]=copy(list)end
			end
		end
	end
	return {v=1,pets=pets}
end

return State
