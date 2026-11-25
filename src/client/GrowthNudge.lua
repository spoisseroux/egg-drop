-- G2 (G2-FIRST-SESSION-LOOK 2026-11-25 sections 1c and 2): the garden pills after the first hello. Pure.
--  * ToyPillCopy: the toy pill's and its card's copy keys ("Hatch a toy for {pet}"; off = "Hatch your first egg").
--  * RoundTwoNudge: which round-two pill, if any. Due when the first-toy guide (FirstSpendGuide) is at `done` (after
--    the toy handoff, or after any other first hatch) or `earn` (no toy and too few Stars for one), on a save that
--    has never saved a field round (`stats.rounds == 0`) and is not a veteran. Never with the toy pill: that one is
--    the `purchase` stage. Copy:
--      bonus  "Round two: ★ {count} Welcome bonus"  guide done, StarterBonus on ({count} = StarterBonus's first bonus)
--      toy    "Round two: hatch a toy for {pet}"     guide at earn
--      plain  "Play round two on your Pocket Deck"   guide done, StarterBonus off
local Shared=game:GetService("ReplicatedStorage"):WaitForChild("Shared")
local Coach=require(Shared:WaitForChild("CoachMarks"))
local StarterBonus=require(Shared:WaitForChild("StarterBonus"))
local Nudge={}
Nudge.Delay=2.5 -- the pill waits this long in a free garden once it is due (after the last toast)

-- The toy pill: {pill, card} keys (NoticeCards id) and whether they take the pet's name.
function Nudge.toyCopy(flags)
	if flags and flags.ToyPillCopy==true then return{pill="notice.pill.firstToy",card="firstToy",named=true}end
	return{pill="notice.pill.firstSpend",card="firstSpend",named=false}
end
-- Has this save never saved a field round? (nil when the snapshot cannot say: no pill.) The public snapshot has no
-- lastAwardSeq; every saved field round writes lastRunReward, so an old save whose round counter started at 0 (which
-- StarterBonus does not pay) is told apart by it.
function Nudge.noFieldRound(state)
	local stats=type(state)=="table"and state.stats or nil
	if type(stats)~="table"then return nil end
	return(stats.rounds or 0)==0 and state.lastRunReward==nil
end
-- The round-two pill's variant ("bonus" | "toy" | "plain") or nil. `stage` = FirstSpendGuide.stage, `state` = the
-- owner snapshot, `started` = a field round started this session (the pill never comes back after it).
function Nudge.variant(stage,state,flags,started)
	if not(flags and flags.RoundTwoNudge==true)or started then return nil end
	if stage~="done"and stage~="earn"then return nil end
	if type(state)~="table"or Coach.veteran(state.totalWins)or Nudge.noFieldRound(state)~=true then return nil end
	if stage=="earn"then return "toy"end
	return if flags.StarterBonus==true then "bonus"else "plain"
end
-- The pill's text key and variables.
function Nudge.copy(variant,pet)
	if variant=="bonus"then return "coach.roundTwo.bonus",{count=StarterBonus.amount(0)}end
	if variant=="toy"then return "coach.roundTwo.toy",{pet=pet}end
	return "coach.roundTwo.plain",nil
end
return table.freeze(Nudge)
