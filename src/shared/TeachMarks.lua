-- The lessons remembered (artifacts/qa-2026-11-27-beta42/TEACH-MORE-BRIEF.md section 3, ARCH-REVIEW-TEACH; Spencer's beta
-- 42 note 8: "we also need to remember when a player has completed the onboarding so they dont have to repeat it on every
-- update"). Shared and pure: the server validates, latches and stores the bits, the client reads them.
--
-- Save fields (hatching v11, no version bump), both CoachMarks' rules exactly: optional and tolerant (missing reads 0, a
-- malformed value is dropped at load, never a failed load), OR-only, any integer 0..2^31-1 valid (bits a later build adds
-- are kept). Older servers keep both: `transact` and `acquire` clone the whole previous root and `valid()` ignores keys it
-- does not know. A save rebuilt from scratch loses them: at worst a repeat lesson.
--   teachMask    one bit per lesson, tour and tip (a latch: set the first time its fact is true), `done` (graduated) and
--                `needs` (the Bear's need bubbles are over: only BearNeeds honours it)
--   teachParked  two bits per lesson, a thermometer of the sessions it was ignored in (ARCH-REVIEW-TEACH 10); the third
--                ignored session latches the lesson itself in teachMask
-- Written only inside HatchProgress (Hatching.coachMark with the coach bits, the fact-making transactions' latch, the
-- acquire backfill); the latch and the backfill run only while Onboard `teach` is on, so off leaves every save as it was.
local Coach=require(script.Parent.CoachMarks)
local Teach={}

-- Bit order is saved data: never renumber, only append.
Teach.Bits=table.freeze({
	dress=0,deck=1,menu=2,park=3,dash=4,          -- the five lessons built in part 2 (their latches)
	deckTour=5,tipChain=6,tipNext=7,tipGoal=8,    -- the first field round's tour and its three tips
	level=9,quests=10,reset=11,snacks=12,stats=13,wardrobe=14,
	parked1=15, -- reserved, unused
	done=16,    -- graduated: no lesson, tour or lesson tip again, in this build or any later one
	needs=17,   -- the need bubbles are over (ARCH-REVIEW-TEACH 3: "You're all set!" is not graduation)
})
-- Every lesson the course holds, in order. Graduation "finished" is every one of these latched (or its feature off on that
-- place): a lesson a later build adds reaches players still in the course only.
Teach.Course=table.freeze({"dress","reset","deck","deckTour","level","menu","quests","park","dash","snacks","stats","wardrobe"})
-- The lessons that can be ignored (parked), each with its slot in teachParked (bits 2*slot and 2*slot+1). The tour and the
-- level step never park (they wait for the player); tips never ask.
Teach.Parkable=table.freeze({dress=0,reset=1,deck=2,menu=3,quests=4,park=5,dash=6,snacks=7,stats=8,wardrobe=9})
Teach.ParkSessions=3 -- ignored in this many sessions: latched (a garden-only player would get it forever)
Teach.MovedOn=12     -- saved stats.rounds at or above this: graduated ("moved on"; a play count, not a clock)
Teach.Reasons=table.freeze({finished=true,skipped=true,veteran=true,movedOn=true})
Teach.ClientReasons=table.freeze({finished=true,skipped=true}) -- the server decides veteran and moved on itself
Teach.Max=Coach.Max

local integer=Coach.integer
Teach.integer=integer
function Teach.valid(state)
	return(state.teachMask==nil or integer(state.teachMask))and(state.teachParked==nil or integer(state.teachParked))
end
function Teach.sanitize(value)return if integer(value)then value else nil end
function Teach.mask(value)return if integer(value)then value else 0 end
function Teach.bit(id)
	local index=Teach.Bits[id]
	return if index then 2^index else nil
end
function Teach.has(mask,id)
	local b=Teach.bit(id)
	return b~=nil and bit32.band(Teach.mask(mask),b)~=0
end
function Teach.with(mask,id)
	local b=Teach.bit(id)
	if not b then return Teach.mask(mask)end
	return bit32.bor(Teach.mask(mask),b)
end
function Teach.merge(a,b)return bit32.bor(Teach.mask(a),Teach.mask(b))end
function Teach.covers(mask,bits)
	bits=Teach.mask(bits)
	return bit32.band(Teach.mask(mask),bits)==bits
end
-- A latch the client may ask for by name: a known id, never `done` (asked with a reason) or the reserved bit.
function Teach.validId(id)
	return type(id)=="string"and #id<=20 and Teach.Bits[id]~=nil and id~="done"and id~="parked1"
end
-- The teachMark request (a string): "<id>", "done:<finished|skipped>" or "park:<lesson>".
-- -> {kind = "mark" | "done" | "park", id, reason}, or nil.
function Teach.parse(value)
	if type(value)~="string"or #value>32 then return nil end
	local reason=string.match(value,"^done:(%a+)$")
	if reason then return if Teach.ClientReasons[reason]then {kind="done",id="done",reason=reason}else nil end
	local parked=string.match(value,"^park:(%a+)$")
	if parked then return if Teach.Parkable[parked]~=nil then {kind="park",id=parked}else nil end
	if Teach.validId(value)then return {kind="mark",id=value}end
	return nil
end
-- The switch: requests are refused while Onboard `teach` is off (required lazily: this module stays pure in specs).
function Teach.allows()
	local ok,on=pcall(function()return require(script.Parent.Onboard).on("teach")end)
	return ok and on==true
end

-- ── The ignore thermometer ─────────────────────────────────────────────────────────────────────────────────────────
function Teach.parkCount(parked,id)
	local slot=Teach.Parkable[id]
	if slot==nil then return 0 end
	local m=Teach.mask(parked)
	return(if bit32.band(m,2^(2*slot))~=0 then 1 else 0)+(if bit32.band(m,2^(2*slot+1))~=0 then 1 else 0)
end
-- One more ignored session for `id`: -> parkBits, teachBits (one of them 0). The third latches the lesson.
function Teach.parkStep(parked,id)
	local slot=Teach.Parkable[id]
	if slot==nil then return 0,0 end
	local n=Teach.parkCount(parked,id)
	if n+1>=Teach.ParkSessions then return 0,Teach.bit(id)end
	local m=Teach.mask(parked)
	local low=2^(2*slot)
	return(if bit32.band(m,low)==0 then low else 2^(2*slot+1)),0
end

-- ── Facts read from the save ───────────────────────────────────────────────────────────────────────────────────────
function Teach.painted(state)
	for _,row in pairs(type(state.petHues)=="table"and state.petHues or {})do
		if type(row)=="table"then
			for _,channel in pairs(row)do
				if type(channel)=="table"then for _,n in pairs(channel)do if type(n)=="number"and n>0 then return true end end end
			end
		end
	end
	return false
end
-- A pot used on a pet at some point (a saved hueUse receipt that was not the Reset Hue; the ring keeps the latest).
function Teach.potUsed(state)
	for _,r in pairs(type(state.hueItemReceipts)=="table"and state.hueItemReceipts or {})do
		if type(r)=="table"and type(r.quote)=="table"and r.quote.action=="hueUse"and r.itemId~=nil and r.itemId~="reset"then return true end
	end
	return false
end
function Teach.snacked(state)
	for _,row in pairs(type(state.petBoosts)=="table"and state.petBoosts or {})do
		if type(row)=="table"then for _,queue in pairs(row)do if type(queue)=="table"and #queue>0 then return true end end end
	end
	return false
end
function Teach.raced(state)
	local dash=type(state.dash)=="table"and state.dash or nil
	for _,n in pairs(dash and type(dash.ribbons)=="table"and dash.ribbons or {})do if type(n)=="number"and n>0 then return true end end
	return false
end
function Teach.rounds(state)
	local stats=type(state.stats)=="table"and state.stats or {}
	return tonumber(stats.rounds)or 0
end
-- Owned a pet before the gift chain existed (or with its switch off): never owed it, so never in the course.
function Teach.veteran(state)
	if(tonumber(state.inventoryMask)or 0)<=0 then return false end -- a brand-new save is marked owed at its Bear
	local ok,view=pcall(function()return require(script.Parent.GiftEggs).read(state)end)
	if not ok or type(view)~="table"then return false end
	return view.owed~=true and view.broken~=true
end
-- The need bubbles are over: a veteran's wins, or the guide's three truly done (Pet, Play, and the nest when there is one).
function Teach.needsOver(state)
	if Coach.veteran(tonumber(state.totalWins)or 0)then return true end
	local mask=state.coachMask
	if not(Coach.has(mask,"needHi")and Coach.has(mask,"needDeck"))then return false end
	return state.nest==nil or Coach.has(mask,"needNest")
end

-- The latches a write must carry (ARCH-REVIEW-TEACH 1): facts that can later turn false (Back to white, a boost used up,
-- a ribbon rolled off) and moved on. Called inside every HatchProgress transaction after its apply. -> bits added.
function Teach.latch(state)
	if type(state)~="table"then return 0 end
	local before=Teach.mask(state.teachMask)
	local m=before
	if Teach.painted(state)then m=Teach.with(m,"dress")end
	if Teach.snacked(state)then m=Teach.with(m,"snacks")end
	if Teach.raced(state)then m=Teach.with(m,"dash")end
	if Teach.rounds(state)>=Teach.MovedOn then m=Teach.with(m,"done")end
	if m==before then return 0 end
	state.teachMask=m
	return m-before
end
-- The load-time rules (ARCH-REVIEW-TEACH 2), inside the acquire callback: OR-only, idempotent, no write of their own.
-- -> bits added.
function Teach.backfill(state)
	if type(state)~="table"then return 0 end
	state.teachMask=Teach.sanitize(state.teachMask)
	state.teachParked=Teach.sanitize(state.teachParked)
	local before=Teach.mask(state.teachMask)
	local m=before
	local rounds=Teach.rounds(state)
	local stats=type(state.stats)=="table"and state.stats or {}
	local function set(id,when)if when then m=Teach.with(m,id)end end
	set("done",Teach.veteran(state)or rounds>=Teach.MovedOn)
	set("dress",Teach.painted(state)or Teach.potUsed(state))
	set("menu",Coach.has(state.coachMask,"menuSeen"))
	set("park",(tonumber(stats.fetches)or 0)>0)
	set("dash",Teach.raced(state))
	set("snacks",Teach.snacked(state))
	set("deck",rounds>=1)
	set("deckTour",rounds>=1);set("tipNext",rounds>=1);set("tipGoal",rounds>=1)
	set("level",rounds>=2)
	set("quests",Coach.has(state.coachMask,"quests")or Coach.has(state.coachMask,"questDone"))
	set("needs",Teach.needsOver(state))
	if m==before then return 0 end
	state.teachMask=m
	return m-before
end
-- Why a save is graduated now (for the TeachGraduated event), or nil.
function Teach.graduated(mask)return Teach.has(mask,"done")end

return table.freeze(Teach)
