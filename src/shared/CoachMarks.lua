-- One-time coach cards and the first-session order (v1 track A, ONBOARDING-V1-SCOPE-2026-11-13
-- sections 1 and 2.3, accepted by Spencer 2026-11-13). Pure and shared: the server validates and
-- stores the bits, the client decides which card to show.
--
-- Save field: `coachMask` on the hatching save (v11), one integer of bits, each card shown once
-- ever. Optional and tolerant (no version bump): missing reads 0, a malformed value is dropped at
-- load (never a failed load), and bits a later build adds are kept (any integer 0..2^31-1 is
-- valid). Written only inside HatchProgress.transact (Hatching.coachMark), OR-only, so a retried
-- write can never clear a bit.
local Coach={}

-- Bit order is saved data: never renumber, only append.
Coach.Bits=table.freeze({
	fillLine=0,    -- the fill-line card on the deck, the first time the stack nears the line
	gardenIntro=1, -- the guided garden step after the Bear (machines, hub, first quest)
	hatch=2,       -- first visit: Hatch eggs
	style=3,       -- first visit: Deck style
	companions=4,  -- first visit: Companions (and the care machine)
	quests=5,      -- first visit: Quests
	book=6,        -- first visit: Collection book
	park=7,        -- first visit: Pet Park (the playground)
	item=8,        -- first round item on the belt
	questDone=9,   -- first quest complete
})
Coach.Order=table.freeze({"fillLine","gardenIntro","hatch","style","companions","quests","book","park","item","questDone"})
Coach.Max=2^31-1 -- the stored range (bits 0..30); unknown bits from a later build are kept

-- The Welcome round is the first Stars round: the starter grant pays this with the Bear,
-- in the same transaction (scope section 1, star budget: 6 welcome + 6 first round).
Coach.WelcomeStars=6
-- The guided garden step: one beat each, in this order (scope section 1, beats 5-8).
Coach.GardenBeats=table.freeze({"machines","hub","quest"})
-- A save with this many wins has learned the game before coaching existed: no cards.
Coach.VeteranWins=5

local function integer(value)
	return type(value)=="number"and value==value and value%1==0 and value>=0 and value<=Coach.Max
end
Coach.integer=integer

-- Tolerant save rules: nil is valid; anything else must be an integer 0..2^31-1.
function Coach.valid(state)
	local mask=state.coachMask
	return mask==nil or integer(mask)
end
-- Load-time repair: an invalid mask becomes nil (reads as 0), never a failed load.
function Coach.sanitize(value)
	if integer(value)then return value end
	return nil
end
-- The mask as a number (missing or malformed reads 0).
function Coach.mask(value)
	return if integer(value)then value else 0
end
function Coach.bit(id)
	local index=Coach.Bits[id]
	return if index then 2^index else nil
end
function Coach.has(mask,id)
	local b=Coach.bit(id)
	return b~=nil and bit32.band(Coach.mask(mask),b)~=0
end
function Coach.with(mask,id)
	local b=Coach.bit(id)
	if not b then return Coach.mask(mask)end
	return bit32.bor(Coach.mask(mask),b)
end
-- OR two masks (both sanitised).
function Coach.merge(mask,bits)
	return bit32.bor(Coach.mask(mask),Coach.mask(bits))
end
-- True when every bit of `bits` is already in `mask`.
function Coach.covers(mask,bits)
	bits=Coach.mask(bits)
	return bit32.band(Coach.mask(mask),bits)==bits
end
-- A request from the client: a known card id only (never raw bits).
function Coach.validId(id)
	return type(id)=="string"and #id<=20 and Coach.Bits[id]~=nil
end

-- ── First-session rules (client presentation; spec-checked) ─────────────────
-- ctx: {mask, totalWins, owned (pets), seen (session set of ids)}.
function Coach.veteran(totalWins)
	return type(totalWins)=="number"and totalWins>=Coach.VeteranWins
end
-- Should this one-time card show now? Never twice (saved bit or shown this session), never
-- for a veteran save, never before the first pet (the Welcome round has its own card).
function Coach.wants(id,ctx)
	ctx=ctx or {}
	if not Coach.Bits[id]then return false end
	if Coach.has(ctx.mask,id)then return false end
	if type(ctx.seen)=="table"and ctx.seen[id]then return false end
	if Coach.veteran(ctx.totalWins)then return false end
	return(ctx.owned or 0)>0
end
-- The first-session flow, in order: which step is the player on?
--   "welcome"  the Welcome round (no pet yet): merge to hatch the Bear, +6 Stars with it
--   "reveal"   the Bear is owned but its reveal is still open (lastHatch not acknowledged)
--   "garden"   the guided garden step is due (gardenIntro bit unset)
--   "free"     onboarding done: only the one-time cards remain
function Coach.stage(ctx)
	ctx=ctx or {}
	if(ctx.owned or 0)<=0 then return "welcome"end
	if ctx.revealPending then return "reveal"end
	if Coach.wants("gardenIntro",ctx)then return "garden"end
	return "free"
end
-- The garden step starts only once the player stands free in the garden: Room mode, no menu,
-- no reveal or greeting shot, after `settle` seconds there (the Bear's greeting plays first).
Coach.GardenSettle=2.5
function Coach.gardenReady(ctx)
	return ctx.canRoam==true and(ctx.roomFor or 0)>=Coach.GardenSettle and Coach.stage(ctx)=="garden"
end
-- The next garden beat after `beat` (nil = the first); nil when the step is done.
function Coach.nextBeat(beat)
	if beat==nil then return Coach.GardenBeats[1]end
	local index=table.find(Coach.GardenBeats,beat)
	return if index then Coach.GardenBeats[index+1]else nil
end
-- Fill line: the first field round (not Welcome) whose stack nears the line.
Coach.FillPressure=.25
function Coach.fillWanted(ctx)
	return ctx.phase~=nil and ctx.phase~="Welcome"and ctx.mode=="Board"and ctx.presented==true
		and ctx.over~=true and(ctx.pressure or 0)>=Coach.FillPressure and Coach.wants("fillLine",ctx)
end
-- Machine screens: which machine (bit id) does an open screen or a used station belong to?
Coach.Stations=table.freeze({Eggs="hatch",Customize="style",Journal="companions",Park="park"})
-- First quest complete: any daily or weekly quest ready or claimed in a snapshot.
function Coach.questDone(quests)
	if type(quests)~="table"then return false end
	for _,scope in ipairs({"daily","weekly"})do
		for _,row in ipairs(type(quests[scope])=="table"and quests[scope]or {})do
			if type(row)=="table"and(row.ready==true or row.claimed==true)then return true end
		end
	end
	return false
end

return table.freeze(Coach)
