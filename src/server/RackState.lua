-- The daily rack's save field and its one write (DailyRack; ROTATION-BRIEF section 5, ARCH-REVIEW-ROTATION 1-3, 5;
-- slice 2: ROTATION-2-BRIEF, ARCH-REVIEW-ROTATION-2 5, 6, 9). Three eggs share one write; each egg is an entry in
-- State.Eggs (its price, switch, view and grant):
--   outfit     the Outfit Egg (DailyRack.view): an item appended to petWearables[pet].owned (WearableState.grant)
--   toycolour  the Toy Colour Egg (ToySkins.view): a skin in rack.toy.owned
--   deck       the Deck Egg (DeckRack.view): an existing plate or ball theme id appended to state.faceplates or
--              state.ballThemes.owned, ownership re-checked inside the write (a duplicate ball theme fails BallThemeState.valid
--              on every build), refusing ShelfFull at either list's 64 limit
-- Hatching v11, one optional top-level field, never part of HatchProgress.valid and never repaired at load (the `gifts`
-- pattern): every read is tolerant and FAILS CLOSED, unknown keys (inside the field or `last`) are newer data and kept.
--   rack = { v = 1,
--            last = {op, egg, pet, item, rarity, day, seen?},   the last egg opened (its reveal can replay)
--            ops  = {opId, ...},                                the last OpsKept request ids (idempotency, every egg)
--            toy  = {owned = {skinId = true}, worn = {toyId = skinId}} }   ToySkins.read: malformed refuses toy actions only
-- A malformed field (outside `toy`) is `broken`: every egg refuses (RackBroken) and nothing is written over it.
local Shared=game:GetService("ReplicatedStorage").Shared
local Rack=require(Shared.DailyRack)
local Skins=require(Shared.ToySkins)
local DeckRack=require(Shared.DeckRack)
local Eggs=require(Shared.EggCatalog)
local Toys=require(Shared.ToyCatalog)
local BallThemes=require(Shared.BallThemes)
local Wearables=require(script.Parent.WearableState)
local Guard=require(script.Parent.HatchGuard)
local State={}
State.Version=1
State.StoredV=255 -- frozen: the most `v` a later build may write
State.OpsKept=16 -- the ops this build keeps (newest last)
State.OpsLimit=64 -- frozen: the most ops a stored field may hold (a later build may keep more)
State.IdLimit=100 -- frozen: a request id's length
State.ItemLimit=32 -- frozen: an item id's length (WearableVariants.IdLimit)
State.EggLimit=16 -- frozen: `last.egg`'s length (review 9)

local function integer(value,low,high)return type(value)=="number"and value==value and value%1==0 and value>=low and value<=high end
local function text(value,limit)return type(value)=="string"and #value>=1 and #value<=limit end
local function copy(v)if type(v)~="table"then return v end;local r={};for k,x in pairs(v)do r[k]=copy(x)end;return r end
State.opaque=function(value)return text(value,State.IdLimit)end

local function validLast(r)
	return type(r)=="table"and text(r.op,State.IdLimit)and text(r.egg,State.EggLimit)and text(r.pet,40)and text(r.item,State.ItemLimit)
		and text(r.rarity,16)and integer(r.day,-1e9,1e9)and(r.seen==nil or type(r.seen)=="boolean")
end
-- The tolerant view: {present, broken, last, ops (list), toy (ToySkins.read)}. `toy` is read on its own (review 9).
function State.read(state)
	local r=type(state)=="table"and state.rack or nil
	if r==nil then return {present=false,broken=false,ops={},toy=Skins.read(nil)}end
	local broken={present=true,broken=true,ops={},toy={present=true,broken=true,owned={},worn={},count=0}}
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
	return {present=true,broken=false,last=r.last,ops=ops or {},toy=Skins.read(r.toy)}
end
function State.broken(state)return State.read(state).broken end
-- The toy colours on this save (ToySkins.read; a broken rack is a broken toy view too).
function State.toy(state)return State.read(state).toy end
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

-- The eggs (review 5): one shared write, a per-egg entry. view(state, c) -> view (DailyRack.view shape) and the refusal
-- before the roll, if any; grant(state, c, item) -> ok, why (inside the write; the caller debits and records).
State.Eggs={}
State.Eggs.outfit={price=Rack.Price,switch="rack",
	view=function(state,c)
		local row=Wearables.row(state,c.petId)
		local view=Rack.view(c.petId,c.day,row.owned,c.mode,c.wings==true)
		return view,if #row.owned>=Wearables.Limit then "ClosetFull"else nil
	end,
	grant=function(state,c,item)
		local ok,why=Wearables.grant(state,c.petId,item,c.equip==true)
		return ok,why
	end,
	rarity=function(c,item)return Rack.rarityOf(c.petId,c.day,item,c.wings==true)end}
State.Eggs.toycolour={price=Skins.Price,switch="toys",
	view=function(state,c)
		local toy=State.toy(state)
		if toy.broken then return nil,"RackBroken"end
		local view=Skins.view(c.day,state.toyUnlocks,toy.owned,c.mode)
		return view,if toy.count>=Skins.OwnedLimit then "ShelfFull"else nil
	end,
	grant=function(state,c,item)
		local toy=State.toy(state)
		local row=Skins.ById[item]
		if toy.broken then return false,"RackBroken"end
		if not row or not Toys.owns(state.toyUnlocks,row.toy)then return false,"LockedToy"end
		if toy.owned[item]then return false,"AlreadyOwned"end
		if toy.count>=Skins.OwnedLimit then return false,"ShelfFull"end
		local field=if type(state.rack)=="table"then copy(state.rack)else {}
		local stored=if type(field.toy)=="table"then field.toy else {}
		stored.owned=if type(stored.owned)=="table"then stored.owned else {}
		stored.owned[item]=true
		if c.equip==true then
			stored.worn=if type(stored.worn)=="table"then stored.worn else {}
			stored.worn[row.toy]=item
		end
		field.toy=stored
		state.rack=field
		return true
	end,
	rarity=function(c,item)return Skins.rarityOf(c.day,item)end}
State.Eggs.deck={price=DeckRack.Price,switch="deck",
	view=function(state,c)
		local balls=state.ballThemes
		local view=DeckRack.view(c.day,state.faceplates,balls and balls.owned,c.mode)
		return view,if view.full then "ShelfFull"else nil
	end,
	-- Review 6: ownership re-checked here, on the save being written, and the 64 limits enforced for each list.
	grant=function(state,c,item)
		local kind=DeckRack.kindOf(item)
		if kind=="plate"then
			local owned=if type(state.faceplates)=="table"then state.faceplates else {}
			if table.find(owned,item)then return false,"AlreadyOwned"end
			if #owned>=DeckRack.PlateLimit then return false,"ShelfFull"end
			owned=table.clone(owned);table.insert(owned,item);state.faceplates=owned
			return true
		elseif kind=="ball"then
			local row=if type(state.ballThemes)=="table"then copy(state.ballThemes)else {owned={"smileys","marbles"},equipped=BallThemes.Default}
			row.owned=if type(row.owned)=="table"then row.owned else {}
			if BallThemes.owns(row.owned,item)or table.find(row.owned,item)then return false,"AlreadyOwned"end
			if #row.owned>=DeckRack.BallLimit then return false,"ShelfFull"end
			table.insert(row.owned,item);state.ballThemes=row
			return true
		end
		return false,"InvalidRack"
	end,
	rarity=function(c,item)return DeckRack.rarityOf(c.day,item)end}
function State.price(egg)local entry=State.Eggs[egg];return entry and entry.price end
function State.switch(egg)local entry=State.Eggs[egg];return entry and entry.switch end

-- The outfit view for one pet (the snapshot and the specs). `wings` as DailyRack.view.
function State.view(state,petId,day,mode,wings)
	local row=Wearables.row(state,petId)
	return Rack.view(petId,day,row.owned,mode,wings),row
end

-- The write (inside UpdateAsync, and on a clone before it). c = {op, egg, petId, day, price, mode, poolKey, unit?, equip,
-- wings?} frozen in the candidate: a retry rolls the same unit over the same pool. No egg = outfit (an older candidate).
-- Refusals, in order: RevealPending (another reservation or reveal is open: Guard.other), RackBroken (never written over;
-- a broken rack.toy refuses the toy egg alone), AlreadySaved (the op is in `ops`), Unowned (the pet), PriceChanged,
-- PoolChanged, RackDone (every pick owned), ClosetFull / ShelfFull (the cap), NeedStars, then the grant's own refusals
-- (AlreadyOwned, LockedToy, ShelfFull: owned since the view, re-checked on this save).
function State.apply(state,c)
	local egg=c.egg or "outfit"
	local entry=State.Eggs[egg]
	if not entry then return false,"InvalidRack"end
	if Guard.other(state,nil)then return false,"RevealPending"end
	local read=State.read(state)
	if read.broken then return false,"RackBroken"end
	if State.find(state,c.op)then return false,"AlreadySaved"end
	if not Eggs.isOwned(state.inventoryMask,c.petId)then return false,"Unowned"end
	if c.price~=entry.price then return false,"PriceChanged"end
	local view,full=entry.view(state,c)
	if not view then return false,full end
	if view.poolKey~=c.poolKey then return false,"PoolChanged"end
	if view.rest then return false,"RackDone"end
	if full then return false,full end
	if state.nectar<c.price then return false,"NeedStars"end
	local item,rarity=Rack.roll(view,c.unit)
	if not item then return false,"InvalidRoll"end
	rarity=rarity or entry.rarity(c,item)
	local granted,why=entry.grant(state,c,item)
	if not granted then return false,why end
	state.nectar-=c.price
	local field=if type(state.rack)=="table"then copy(state.rack)else {}
	field.v=if integer(field.v,1,State.StoredV)then field.v else State.Version
	local ops=table.clone(read.ops)
	table.insert(ops,c.op)
	while #ops>State.OpsKept do table.remove(ops,1)end
	field.ops=ops
	field.last={op=c.op,egg=egg,pet=c.petId,item=item,rarity=rarity,day=c.day}
	state.rack=field
	return true
end

-- toySkinWear (ROTATION-2-BRIEF 1 "Ops"): c = {toyId, skinId (or "none": the original colour)}. One write; refuses
-- RackBroken (the rack or rack.toy malformed, never written over), LockedToy (the toy is not unlocked), NotOwned (the
-- skin), InvalidSkin (not this toy's), NoChange. Account-wide: the toy wears it for every pet.
function State.toyWearResult(state,c)
	local read=State.read(state)
	if read.broken or read.toy.broken then return nil,"RackBroken"end
	if type(c)~="table"or not Toys.known(c.toyId)or c.toyId==Toys.Default then return nil,"InvalidSkin"end
	if not Toys.owns(state.toyUnlocks,c.toyId)then return nil,"LockedToy"end
	local skin=c.skinId
	if skin~="none"then
		local row=Skins.ById[skin]
		if not row or row.toy~=c.toyId then return nil,"InvalidSkin"end
		if not read.toy.owned[skin]then return nil,"NotOwned"end
	end
	local current=read.toy.worn[c.toyId]
	local wanted=if skin=="none"then nil else skin
	if current==wanted then return nil,"NoChange"end
	return wanted
end
function State.applyToyWear(state,c)
	local wanted,why=State.toyWearResult(state,c)
	if why then return false,why end
	local field=if type(state.rack)=="table"then copy(state.rack)else {}
	field.v=if integer(field.v,1,State.StoredV)then field.v else State.Version
	local stored=if type(field.toy)=="table"then field.toy else {}
	stored.worn=if type(stored.worn)=="table"then stored.worn else {}
	stored.worn[c.toyId]=wanted
	field.toy=stored
	state.rack=field
	return true
end

-- What the owner's client sees of the last egg (`kind` for a Deck Egg pick: "plate" | "ball").
function State.publicLast(r)
	if type(r)~="table"then return nil end
	return {id=r.op,egg=r.egg,pet=r.pet,item=r.item,rarity=r.rarity,day=r.day,seen=r.seen==true,
		kind=if r.egg=="deck"then DeckRack.kindOf(r.item)else nil}
end
-- The snapshot (owner only, the rack switch on). pets: every owned pet with wearables. See DailyRack.view for a view.
--   {day, price, mode, broken, last?, outfit = view of `outPet` (or nil), pets = {[petId] = view},
--    toy? (rack_toys on) = {price, mode, rest, next?, total, poolKey, items, owned = {skinId = true}, worn = {toyId = skinId},
--          broken, full},
--    deck? (rack_deck on) = {price, mode, rest, next?, total, poolKey, items, full, closet = true}}
-- Each outfit view also carries `full` (the closet is at WearableState.Limit: the egg refuses ClosetFull); on a wings
-- day (rack_wings on) its `sparkle` may be Angel Wings (sparkle.wings = true).
function State.public(state,day,restricted,outPet,pets)
	local view=State.read(state)
	local mode=selectionMode(restricted)
	local wings=Rack.on("wings")
	local out={day=day,price=Rack.Price,mode=mode,broken=view.broken,last=State.publicLast(view.last),pets={}}
	for _,petId in ipairs(pets or {})do
		if Eggs.isOwned(state.inventoryMask,petId)and Rack.period(petId)then
			local egg,row=State.view(state,petId,day,mode,wings)
			egg.full=#row.owned>=Wearables.Limit
			if view.broken then egg.rest=true end
			out.pets[petId]=egg
		end
	end
	out.outfit=if type(outPet)=="string"then out.pets[outPet]else nil
	if Rack.on("toys")then
		local toy=view.toy
		local egg=Skins.view(day,state.toyUnlocks,toy.owned,mode)
		egg.price=Skins.Price
		egg.broken=toy.broken
		egg.full=toy.count>=Skins.OwnedLimit
		if view.broken or toy.broken then egg.rest=true end
		local owned={};for id in pairs(toy.owned)do owned[id]=true end
		local worn={};for toyId,id in pairs(toy.worn)do worn[toyId]=id end
		egg.owned=owned;egg.worn=worn
		out.toy=egg
	end
	if Rack.on("deck")then
		local balls=state.ballThemes
		local egg=DeckRack.view(day,state.faceplates,balls and balls.owned,mode)
		egg.price=DeckRack.Price
		egg.closet=true
		if view.broken then egg.rest=true end
		out.deck=egg
	end
	return out
end
return State
