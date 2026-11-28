-- The "+5 ★ welcome gift" on "You're all set!" (ONBOARDING-V3-BRIEF section 3; Spencer OK'd it 2026-11-27 on beta
-- (38)). Pure and shared: the server pays it (HatchProgress.welcomeGift, inside one UpdateAsync); the client only
-- shows what the server's reply says (AllSetCard). Beta and Studio only, with the Onboard "allset2" switch.
--
-- Save field: `welcomeGift` on the hatching save (v11, no version bump; the FirstHello pattern). Optional and
-- tolerant: nil is valid, any whole number 0..Stored is valid, anything else is dropped at load (never a failed load).
--   nil  not owed: every save from before this build, and any save whose Bear came while `allset2` was off. So
--        returning and veteran saves never get it.
--   0    owed: written in the Bear's own grant (HatchProgress.grantStarter) on a brand-new save while `allset2` is on.
--   n>0  paid (the Stars it paid). Final: nothing ever writes 0 or nil over it, so it pays once per save, ever.
-- Older builds ignore the unknown field (HatchProgress.validBase reads named fields only) and keep it when they save
-- (WelcomeGiftCrossVersion.spec).
--
-- Paid only when the guide's three facts are truly done in the SAVE (BearNeeds.trulyDone, server side):
--   Pet    the `needHi` coach bit (saved, or queued on the board: the server already accepted it) or a paid pet
--   Nest   the egg in the nest tucked in, or one hatched (`nest.tucked`, `nest.n` > 0); not asked when the nest is off
--   Stars  a deck round played after the Bear: saved `stats.rounds` >= Rounds (the Welcome round is not counted)
-- and never on a veteran save (Coach.veteran), as the guide itself.
local Coach=require(script.Parent.CoachMarks)
local Gift={}
Gift.Bonus=5
Gift.Owed=0
Gift.Stored=255 -- frozen stored bound for `welcomeGift`; never tuned
Gift.Rounds=1 -- BearNeeds.Rounds: a round after the Bear (the Welcome round is not counted)
-- The server's request loop (WelcomeGiftHost): the facts may still be saving when the card shows (the coach bit's
-- quiet window, a round's payout), so it tries again every Gap s, at most Tries times.
Gift.Tries=12
Gift.Gap=2

local function integer(value,maximum)
	return type(value)=="number"and value==value and value%1==0 and value>=0 and value<=maximum
end
Gift.integer=integer

function Gift.valid(state)
	local value=state.welcomeGift
	return value==nil or integer(value,Gift.Stored)
end
-- Load-time repair: an invalid value becomes nil (not owed: it fails closed, never pays), never a failed load.
function Gift.sanitize(value)
	return if integer(value,Gift.Stored)then value else nil
end
function Gift.owed(state)return type(state)=="table"and state.welcomeGift==Gift.Owed end
function Gift.paid(state)return type(state)=="table"and integer(state.welcomeGift,Gift.Stored)and state.welcomeGift>0 end
-- Inside the Bear's grant: mark a brand-new save as owed. Writes nothing when the field is already there.
function Gift.mark(state)
	if type(state)~="table"or state.welcomeGift~=nil then return false end
	state.welcomeGift=Gift.Owed
	return true
end
-- Pure: the guide's three facts from a save. `mask`: coach bits the server holds but has not saved yet (optional).
function Gift.facts(state,mask)
	state=if type(state)=="table"then state else {}
	local merged=Coach.merge(Coach.mask(state.coachMask),Coach.mask(mask))
	local stats=if type(state.stats)=="table"then state.stats else {}
	local nest=if type(state.nest)=="table"then state.nest else nil
	return{
		pet=Coach.has(merged,"needHi")or state.lastPetAward~=nil,
		nest=nest~=nil and(nest.tucked==true or(integer(nest.n,1e9)and nest.n>0)),
		stars=integer(stats.rounds,1e15)and stats.rounds>=Gift.Rounds,
	}
end
-- Pure: may the gift be paid on this save now? -> true, or false and the reason:
--   AlreadyGranted (paid before), NotOwed (an old save, or its Bear came with the switch off), Veteran, NotDone.
-- nestRequired false: the nest is off in this world, so Pet and Stars only (as BearNeeds.trulyDone).
function Gift.due(state,nestRequired,mask)
	if type(state)~="table"then return false,"NotOwed"end
	if Gift.paid(state)then return false,"AlreadyGranted"end
	if not Gift.owed(state)then return false,"NotOwed"end
	if Coach.veteran(state.totalWins)then return false,"Veteran"end
	local f=Gift.facts(state,mask)
	if not f.pet or not f.stars or(nestRequired~=false and not f.nest)then return false,"NotDone"end
	return true
end
-- Inside the gift's transaction, after due: the Stars it pays, with the save marked paid.
function Gift.apply(state)
	state.welcomeGift=Gift.Bonus
	state.nectar+=Gift.Bonus
	return Gift.Bonus
end
-- Reasons the request loop waits on (the facts or the save may still be on their way, another reveal or reservation is
-- open: RevealPending; a write that would not validate yet: InvalidData); any other refusal is final for that ask.
Gift.Wait=table.freeze({NotDone=true,Busy=true,Pending=true,Retrying=true,RevisionChanged=true,RevealPending=true,InvalidData=true})
-- The client asks again from the snapshot (code review 2026-11-27: an owed save must never stay owed for good): while the
-- save is owed and the three facts are done, the card's own ask gets AskAfter s, then one ask every AskEvery s.
Gift.AskAfter=30
Gift.AskEvery=20
-- Pure: should the client ask now? `clock` = {doneSince, lastAsk} (kept by the caller; this updates doneSince).
-- `state` is the owner snapshot (welcomeGift, coachMask, nest, stats, totalWins, lastPetAward).
function Gift.shouldAsk(state,nestRequired,mask,clock,now)
	if not Gift.due(state,nestRequired,mask)then clock.doneSince=nil;return false end
	clock.doneSince=clock.doneSince or now
	if now-clock.doneSince<Gift.AskAfter then return false end
	return clock.lastAsk==nil or now-clock.lastAsk>=Gift.AskEvery
end

return table.freeze(Gift)
