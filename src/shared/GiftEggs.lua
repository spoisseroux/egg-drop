-- The gift chain's free eggs (ONBOARDING-FUN-PASS section 2, switch Onboard "gifts"; Spencer: "Yes, all three";
-- artifacts/qa-2026-11-27-beta37/GIFT-CHAIN-PLAN.md and its architect review). Pure and shared: the server grants
-- (HatchProgress.giftEgg for Paint and Toy, StatEggState.buy for the Snack), the client only shows what the snapshot
-- (`public.gifts`) and the replies say.
--
-- Three free cranks, each once per save, each only when its trigger is true in the save:
--   paint  the egg in the nest tucked in (or one hatched); with the nest off, the first hello. A pots-only pool:
--          the four paint pots, 25% each (Pools.paint). Adds one pot (hueInventory) and its lookFound bit.
--   toy    after the Paint gift, and two rounds after the Bear (stats.rounds >= ToyRounds: the Welcome round is not
--          counted) or a later server day than the Paint gift. Unlocks one toy the save does not own; owning every toy
--          is AllOwned (the step is skipped, nothing given).
--   snack  after the Paint gift, once a Garden Dash race finished (any ribbon). A free Stat Egg through the existing
--          statEggBuy (free, gift) path; never the player's own banked or medal egg.
--
-- Save field `gifts` on the hatching save (v11, no version bump). It is never part of HatchProgress.valid and load
-- never repairs it (the NestState / DashState pattern): every read here is tolerant and FAILS CLOSED.
--   gifts = { v = 1,                                          the owed marker (the Bear's grant, switch on)
--             paint = {op, item, day, rev, seq, seen?},        a granted record (final: never removed or rewritten
--             toy   = {op, item, day, rev, seq, seen?},          except `seen` going true)
--             snack = {op, day, snackId, stat, size, petId},
--             fetch = true }                                   the "learned Fetch" card was shown
--   * Only new saves are owed (`v` written in the Bear's own transaction, as WelcomeGift.mark); older saves are not.
--   * Any malformed part (the table, `v`, a record, `fetch`) makes the whole field `broken`: every kind then reads as
--     granted, so nothing is ever paid from a damaged field, and nothing writes over it.
--   * Unknown keys (inside the field or a record) are newer data: kept, never a reason to fail.
--   * Older builds ignore the unknown top-level field and keep it when they save (GiftEggCrossVersion.spec); what a
--     gift adds (a pot, a toy unlock, a Stat Egg receipt) is in fields every build already accepts.
-- The Outfit gift (DailyRack "rack", ROTATION-BRIEF 4, ARCH-REVIEW-ROTATION 10 and 11): while the rack switch is on the
-- chain is Outfit -> Paint -> Toy -> Snack (Gifts.kinds(true)); off it is Paint -> Toy -> Snack exactly as before.
--   outfit  takes Paint's trigger (the tuck, or the first hello with the nest off). Not random: "A gift: Pom Beanie,
--           100%". Gives `beanie` (else the rig's first common Hat the pet lacks) to the pet that is out and wears it in
--           the same write; the pet must be owned and its closet under WearableState.Limit (128). Record
--           gifts.outfit = {op, item, day, rev, seq, pet, rounds, seen?}; `seen` latches through giftSeen (no coach bit).
--   paint   (rack on) after the Outfit record, two rounds after it (stats.rounds - outfit.rounds >= ToyRounds) or a later
--           server day. If the Outfit gift can never be given (no hat left, closet full) Paint keeps its own trigger.
--   toy     (rack on) the same rule counted from the Paint record (a Paint record without `rounds`, granted under the
--           old order, counts from zero: the old rule).
--   A save that got Paint under the old order is simply owed the Outfit gift next. A malformed `outfit` record closes
--   the Outfit gift alone (it reads as granted); the other kinds read on as before, so the switch off is unchanged.
local Shared=script.Parent
local Hue=require(Shared.HueCatalog)
local Toys=require(Shared.ToyCatalog)
local Coach=require(Shared.CoachMarks)
local Wear=require(Shared.WearableCatalog)
local Eggs=require(Shared.EggCatalog)
local Gifts={}
Gifts.Version=1
Gifts.Kinds=table.freeze({"paint","toy","snack"})
Gifts.Crankable=table.freeze({paint=true,toy=true,outfit=true}) -- the kinds HatchProgress.giftEgg grants (the Snack rides statEggBuy)
Gifts.RackKinds=table.freeze({"outfit","paint","toy","snack"}) -- the chain while DailyRack "rack" is on
Gifts.OutfitItem="beanie" -- the brief's Pom Beanie; else the rig's first common Hat the pet does not own
Gifts.OwnedLimit=Wear.OwnedLimit
-- The chain's kinds in order: the rack's while it is on, else Kinds.
function Gifts.kinds(rack)return if rack==true then Gifts.RackKinds else Gifts.Kinds end
Gifts.ToyRounds=2 -- saved stats.rounds: two field rounds after the Bear (the Welcome round is not counted)
Gifts.IdLimit=100 -- frozen: an op id's length
Gifts.ItemLimit=40 -- frozen: an item id's length
Gifts.StoredV=255 -- frozen: the most `v` a later build may write
Gifts.Pools=table.freeze({paint=Hue.RollOrder}) -- rose, tide, citrus, iris: 25% each
-- The server's request loop (GiftEggHost): a reveal or a save may still be in flight, so it tries again.
Gifts.Tries=8
Gifts.Gap=2
Gifts.Wait=table.freeze({RevealPending=true,Busy=true,Pending=true,Retrying=true,RevisionChanged=true})

local function integer(value,low,high)
	return type(value)=="number"and value==value and value%1==0 and value>=low and value<=high
end
local function text(value,limit)return type(value)=="string"and #value>=1 and #value<=limit end
local function canonicalDay(value)
	local number=if type(value)=="string"then tonumber(value)else nil
	return number~=nil and number==math.floor(number)and math.abs(number)<=1000000000 and tostring(number)==value
end
Gifts.canonicalDay=canonicalDay

-- A granted record's shape (only what this build reads; unknown keys are kept).
local function record(kind,r)
	if type(r)~="table"or not text(r.op,Gifts.IdLimit)or not canonicalDay(r.day)then return false end
	if r.seen~=nil and type(r.seen)~="boolean"then return false end
	if kind=="snack"then
		return r.snackId==nil or integer(r.snackId,1,1e15)
	end
	if r.rounds~=nil and not integer(r.rounds,0,1e15)then return false end
	return text(r.item,Gifts.ItemLimit)
end

-- The tolerant view: {owed, broken, records = {paint, toy, snack}, fetch}.
function Gifts.read(state)
	local g=type(state)=="table"and state.gifts or nil
	if g==nil then return {owed=false,broken=false,records={},fetch=false}end
	local broken={owed=false,broken=true,records={},fetch=true}
	if type(g)~="table"then return broken end
	if not integer(g.v,1,Gifts.StoredV)then return broken end
	if g.fetch~=nil and g.fetch~=true then return broken end
	local records={}
	for _,kind in ipairs(Gifts.Kinds)do
		local r=g[kind]
		if r~=nil then
			if not record(kind,r)then return broken end
			records[kind]=r
		end
	end
	-- The Outfit record is read on its own: a malformed one closes the Outfit gift only (`outfitBroken`), never the
	-- kinds a build without the rack reads, so the switch off reads exactly what it did before.
	local outfitBroken=false
	if g.outfit~=nil then
		if record("outfit",g.outfit)then records.outfit=g.outfit else outfitBroken=true end
	end
	return {owed=true,broken=false,records=records,fetch=g.fetch==true,outfitBroken=outfitBroken}
end
-- The granted record for `kind`, or nil (none, or a broken field: see granted()).
function Gifts.record(state,kind)
	local view=Gifts.read(state)
	return if view.broken then nil else view.records[kind]
end
-- Granted (or closed): a record is saved, or the field is broken (fail closed).
function Gifts.granted(state,kind)
	local view=Gifts.read(state)
	return view.broken or view.records[kind]~=nil or(kind=="outfit"and view.outfitBroken==true)
end
function Gifts.owed(state)return Gifts.read(state).owed end
-- Inside the Bear's grant: mark a brand-new save owed. Writes nothing when the field is already there (any value).
function Gifts.mark(state)
	if type(state)~="table"or state.gifts~=nil then return false end
	state.gifts={v=Gifts.Version}
	return true
end

-- Pure facts from a save. `mask`: coach bits the board holds but has not saved yet (optional).
function Gifts.facts(state,mask)
	state=if type(state)=="table"then state else {}
	local stats=if type(state.stats)=="table"then state.stats else {}
	local nest=if type(state.nest)=="table"then state.nest else nil
	local dash=if type(state.dash)=="table"then state.dash else nil
	local ribbons=dash and type(dash.ribbons)=="table"and dash.ribbons or {}
	local raced=false
	for _,count in pairs(ribbons)do if integer(count,1,1e9)then raced=true end end
	local merged=Coach.merge(Coach.mask(state.coachMask),Coach.mask(mask))
	return{
		pet=type(state.inventoryMask)=="number"and state.inventoryMask~=0,
		hello=Coach.has(merged,"needHi")or state.lastPetAward~=nil,
		tucked=nest~=nil and(nest.tucked==true or integer(nest.n,1,1e9)),
		rounds=if integer(stats.rounds,0,1e15)then stats.rounds else 0,
		raced=raced,
	}
end

-- The hat the Outfit gift gives `petId` on this save: Gifts.OutfitItem when the pet's rig has it and the pet lacks it,
-- else the first common Hat (a rig item, not a recolour) it lacks, else nil.
function Gifts.outfitItem(state,petId)
	if type(petId)~="string"then return nil end
	local items=Wear.forPet(petId,math.huge)
	local rows=type(state)=="table"and type(state.petWearables)=="table"and state.petWearables[petId]
	local owned=type(rows)=="table"and type(rows.owned)=="table"and rows.owned or {}
	local function free(id)return table.find(owned,id)==nil end
	local first=items.byId[Gifts.OutfitItem]
	if first and not first.variant and free(first.id)then return first.id end
	for _,item in ipairs(items.order)do
		if not item.variant and item.slot=="Hat"and item.tier=="common"and free(item.id)then return item.id end
	end
	return nil
end
-- Why the Outfit gift cannot be given to `petId` now (Unowned, AllOwned, ClosetFull), or nil when it can.
function Gifts.outfitBlock(state,petId)
	local mask=type(state)=="table"and state.inventoryMask or 0
	if type(petId)~="string"or not Eggs.isOwned(mask,petId)then return "Unowned"end
	if not Gifts.outfitItem(state,petId)then return "AllOwned"end
	local rows=type(state.petWearables)=="table"and state.petWearables[petId]
	local count=type(rows)=="table"and type(rows.owned)=="table"and #rows.owned or 0
	if count>=Gifts.OwnedLimit then return "ClosetFull"end
	return nil
end
-- Rounds since a record (its saved `rounds`, else zero: a record from before the rack counts from the start).
local function since(f,r)return f.rounds-(if type(r)=="table"and integer(r.rounds,0,1e15)then r.rounds else 0)end
local function laterDay(today,r)return canonicalDay(today)and tonumber(today)>tonumber(r.day)end

-- Pure: may `kind` be granted on this save now? -> true, or false and the reason. ctx = {nest (false: the nest is off
-- in this world), mask, rack (DailyRack "rack" on: the Outfit order), petId (the pet that is out, for the Outfit)}. `today` is the server day ("20000"). No veteran check: a save owed the chain (`v`) is a new
-- save by construction, and a few wins must never cancel its later gifts (architect review 2); the client's leads
-- skip veterans. Reasons: AlreadyGranted (a record, or a broken field), NotOwed, MeetPipFirst, NotDue, AllOwned,
-- InvalidGift. The Snack's deliverability (switch, pouch, stats) is the server's (HatchProgress.giftReady).
function Gifts.due(state,kind,today,ctx)
	ctx=ctx or {}
	local rack=ctx.rack==true
	if kind~="paint"and kind~="toy"and kind~="snack"and kind~="outfit"then return false,"InvalidGift"end
	if kind=="outfit"and not rack then return false,"NotReady"end
	if type(state)~="table"then return false,"NotOwed"end
	local view=Gifts.read(state)
	if view.broken or view.records[kind]or(kind=="outfit"and view.outfitBroken)then return false,"AlreadyGranted"end
	if not view.owed then return false,"NotOwed"end
	local f=Gifts.facts(state,ctx.mask)
	if not f.pet then return false,"MeetPipFirst"end
	local opening=if ctx.nest==false then f.hello else f.tucked
	if kind=="outfit"then
		if not opening then return false,"NotDue"end
		local block=Gifts.outfitBlock(state,ctx.petId)
		if block then return false,block end
		return true
	end
	if kind=="paint"then
		if rack then
			local outfit=view.records.outfit
			if outfit then
				if since(f,outfit)<Gifts.ToyRounds and not laterDay(today,outfit)then return false,"NotDue"end
				return true
			end
			-- No Outfit record: Paint waits for it, unless it can never be given (then Paint keeps its own trigger).
			if not view.outfitBroken then
				local block=Gifts.outfitBlock(state,ctx.petId)
				if block~="AllOwned"and block~="ClosetFull"then return false,"NotDue"end
			end
		end
		if not opening then return false,"NotDue"end
		return true
	end
	local paint=view.records.paint
	if not paint then return false,"NotDue"end
	if kind=="toy"then
		local rounds=if rack then since(f,paint)else f.rounds
		if rounds<Gifts.ToyRounds and not laterDay(today,paint)then return false,"NotDue"end
		if #Toys.remaining(state.toyUnlocks)==0 then return false,"AllOwned"end
		return true
	end
	if not f.raced then return false,"NotDue"end
	return true
end

-- The pot, toy or hat a gift gives (inside the write). c = {kind, unit (random accounts) or fixed = true, pet (outfit)}.
function Gifts.draw(state,c)
	if c.kind=="outfit"then return Gifts.outfitItem(state,c.pet)end
	if c.kind=="paint"then
		if c.fixed then return Hue.fixedNext(state.hueInventory)end
		local pool=Gifts.Pools.paint
		if type(c.unit)~="number"or c.unit~=c.unit or c.unit<0 or c.unit>=1 then return nil end
		return pool[math.min(#pool,math.floor(c.unit*#pool)+1)]
	elseif c.kind=="toy"then
		local remaining=Toys.remaining(state.toyUnlocks)
		if c.fixed then return Toys.fixedNext(remaining)end
		return Toys.roll(remaining,c.unit)
	end
	return nil
end
-- The odds a gift card shows: {id, percent} rows (whole numbers for the Paint Egg: 25 each; the Outfit gift's one hat,
-- 100%, for `petId`).
function Gifts.odds(kind,state,petId)
	if kind=="outfit"then
		local item=Gifts.outfitItem(state,petId)
		return if item then {{id=item,percent=100}}else {}
	end
	if kind=="paint"then
		local rows={}
		for _,id in ipairs(Gifts.Pools.paint)do table.insert(rows,{id=id,percent=100/#Gifts.Pools.paint})end
		return rows
	elseif kind=="toy"then
		local rows={}
		local remaining=Toys.remaining(type(state)=="table"and state.toyUnlocks or nil)
		for _,id in ipairs(remaining)do table.insert(rows,{id=id,percent=100/#remaining})end
		return rows
	end
	return {}
end

-- A copy of the field with `kind` set to `r` (never called on a broken field: due refuses first).
function Gifts.with(state,kind,r)
	local g=table.clone(state.gifts)
	g[kind]=r
	state.gifts=g
end
-- What the owner's client sees of a record.
function Gifts.publicRecord(kind,r)
	if type(r)~="table"then return nil end
	return {kind=kind,id=r.op,item=r.item,day=r.day,seen=r.seen==true,snackId=r.snackId,stat=r.stat,size=r.size,pet=r.pet}
end
-- The first granted Paint or Toy record (with `rack`, the Outfit first) the player has not seen yet, or nil.
function Gifts.unseen(state,rack)
	local view=Gifts.read(state)
	if view.broken then return nil end
	for _,kind in ipairs(if rack==true then {"outfit","paint","toy"}else {"paint","toy"})do
		local r=view.records[kind]
		if r and r.seen~=true then return kind,r end
	end
	return nil
end

return table.freeze(Gifts)
