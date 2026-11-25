-- Welcome bonus (growth cuts 2026-11-25, GROWTH-CUTS-LOOK section 3): a flat extra on the first three finished
-- field rounds of a brand-new save (+12, +4, +4), 20 Stars per save at most, win or lose. Not multiplied by
-- difficulty, the 2x Stars pass or Supporter. Pure and shared: the server pays it inside the round's award
-- transaction (HatchProgress.award), the client reads `lastRunReward.starter` for the payout row.
--
-- Save field: `starterRounds` on the hatching save (v11), the bonus rounds already paid. Optional and tolerant
-- (no version bump, as `coachMask`): nil is valid, any integer 0..255 is valid (a later build may count further;
-- this one reads at most 3), a malformed value is dropped at load. Written only inside the award transaction and
-- only when a bonus is paid, so a retried or ambiguous write resumes the same operation and can never pay twice.
-- A save without the field is new only when it has never saved a round (`stats.rounds == 0` and
-- `lastAwardSeq == 0`); any other save reads 3, so existing players get nothing.
local Bonus={}
Bonus.Rewards=table.freeze({12,4,4})
Bonus.Rounds=#Bonus.Rewards
Bonus.Cap=20
Bonus.Stored=255 -- frozen stored bound for `starterRounds`; never tuned

local function integer(value,maximum)
	return type(value)=="number"and value==value and value%1==0 and value>=0 and value<=maximum
end

function Bonus.valid(state)
	local value=state.starterRounds
	return value==nil or integer(value,Bonus.Stored)
end
-- Load-time repair: an invalid value becomes nil (then read by the rule below), never a failed load.
function Bonus.sanitize(value)
	return if integer(value,Bonus.Stored)then value else nil
end
-- Bonus rounds already paid (0..Rounds), read from the save before this round is counted.
function Bonus.paid(state)
	if type(state)~="table"then return Bonus.Rounds end
	local value=state.starterRounds
	if integer(value,Bonus.Stored)then return math.min(value,Bonus.Rounds)end
	local stats=state.stats
	local rounds=if type(stats)=="table"then stats.rounds else nil
	if rounds==0 and state.lastAwardSeq==0 then return 0 end
	return Bonus.Rounds
end
-- Stars for the bonus round after `paid` (0-based), clamped so the whole run never passes Cap.
function Bonus.amount(paid)
	local due=Bonus.Rewards[paid+1]
	if not due then return 0 end
	local before=0
	for index=1,paid do before+=Bonus.Rewards[index]end
	return math.max(0,math.min(due,Bonus.Cap-before))
end
-- Inside the award transaction, BEFORE Lifetime.recordRun: the Stars this round's bonus pays (0 for none), and the
-- save's counter moved on. Writes nothing when nothing is due.
function Bonus.apply(state)
	local paid=Bonus.paid(state)
	if paid>=Bonus.Rounds then return 0 end
	local amount=Bonus.amount(paid)
	state.starterRounds=paid+1
	return amount
end

return table.freeze(Bonus)
