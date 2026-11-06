-- Presentation must never reuse a prior run's equal-value receipt or promotion.
local Receipt = {}
function Receipt.select(state, sequence, status, isOver)
	if not isOver or status ~= "Saved" or type(sequence) ~= "number" then return nil end
	local reward = state and state.lastRunReward
	if type(reward) ~= "table" or reward.sequence ~= sequence then return nil end
	return reward
end
return Receipt
