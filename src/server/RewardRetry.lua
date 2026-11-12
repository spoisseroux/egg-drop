-- Round payout retry policy (Quests/difficulty review, fix 4). The award loop
-- used to retry every refusal forever, so a permanent refusal such as
-- BalanceLimit left payoutPending stuck and the board unable to replay. Pure,
-- so the host's loop is spec-checked.
local Retry = {}

-- Refusals that a retry can never turn into a save: the award itself is
-- invalid, the wallet is at its cap, the family/award moved under it, or the
-- session moved to another server.
Retry.Permanent = table.freeze({
	InvalidReward = true, InvalidSummary = true, BalanceLimit = true,
	FamilyChanged = true, AwardChanged = true, SessionLost = true, Released = true,
})

-- "Saved" (ok), "Permanent" (stop, clear pending, tell the player) or
-- "Transient" (DataStore error, busy, another operation pending: retry).
function Retry.classify(ok, reason)
	if ok then return "Saved" end
	if Retry.Permanent[reason] then return "Permanent" end
	return "Transient"
end

-- Backoff after the n-th consecutive transient failure: 2, 4, 8, 16, 30, 30... s.
function Retry.delay(failures)
	failures = math.max(1, math.floor(tonumber(failures) or 1))
	return math.min(30, 2 ^ failures)
end

return table.freeze(Retry)
