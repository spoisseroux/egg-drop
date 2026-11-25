-- The first hello (G2-FIRST-SESSION-LOOK 2026-11-25 section 1b, switch FeatureFlags.FirstHelloBonus): the first paid
-- pet on a new save pays +2 Stars on top of its usual +1, once per save, ever. Flat: no 2x pass, no Supporter.
-- Pure and shared: the server pays it inside the petting award transaction (HatchProgress.awardPet) and writes the
-- receipt's `hello`; the client only shows what that receipt says.
--
-- Save field: `firstHello` on the hatching save (v11), the Stars the first hello paid. Optional and tolerant (no
-- version bump, as `starterRounds`): nil is valid, any integer 0..255 is valid, a malformed value is dropped at load.
-- Any present value means done. A save without it is due only when it has never been paid for a pet
-- (`lastPetAward == nil`: once a pet is paid the receipt is never cleared) and has never saved a field round
-- (`stats.rounds == 0` and `lastAwardSeq == 0`). So every existing player who has played gets nothing.
-- (The spec's third rule, "gardenIntro already set", is left out on purpose: G1's say-hi line saves gardenIntro the
-- moment it shows, before a new player can reach the pet, so it would refuse every new save.)
local Hello={}
Hello.Bonus=2
Hello.Stored=255 -- frozen stored bound for `firstHello`; never tuned

local function integer(value,maximum)
	return type(value)=="number"and value==value and value%1==0 and value>=0 and value<=maximum
end
Hello.integer=integer

function Hello.valid(state)
	local value=state.firstHello
	return value==nil or integer(value,Hello.Stored)
end
-- Load-time repair: an invalid value becomes nil (then read by the rule below), never a failed load.
function Hello.sanitize(value)
	return if integer(value,Hello.Stored)then value else nil
end
-- Is the first hello still owed on this save snapshot? Read BEFORE this award writes `lastPetAward`.
function Hello.due(state)
	if type(state)~="table"or state.firstHello~=nil or state.lastPetAward~=nil then return false end
	local stats=state.stats
	return type(stats)=="table"and stats.rounds==0 and state.lastAwardSeq==0
end
-- Inside the award transaction, before `lastPetAward` is written: the extra Stars this pet pays (0 for none), with
-- the save marked. Writes nothing when nothing is due.
function Hello.apply(state)
	if not Hello.due(state)then return 0 end
	state.firstHello=Hello.Bonus
	return Hello.Bonus
end

return table.freeze(Hello)
