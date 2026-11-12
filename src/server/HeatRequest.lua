-- Difficulty request rules (QUESTS-DIFFICULTY-PLAN section 1, "Flow"). Pure, so
-- the host's decision is spec-checked. The client only asks; the server stores
-- the choice and the run's heat is frozen at reset, before the first drop.
local Config = require(game:GetService("ReplicatedStorage").Shared.BoardConfig)
local Heat = {}

-- Guided first session: until the first saved win, a session's first three
-- rounds run Easy with no picker.
function Heat.guided(totalWins, settledRounds)
	return (totalWins or 0) == 0 and (settledRounds or 0) < 3
end

function Heat.runHeat(guided, nextHeat)
	if guided then return "easy" end
	return if Config.validHeat(nextHeat) then nextHeat else Config.DefaultHeat
end

-- state = { mode, ready, payoutPending, over, drops, field, guided, runHeat }
-- Returns "Store" (remember for the next reset), "Rebuild" (fresh field with
-- no drops: rebuild it now with the new heat) or a refusal reason.
function Heat.decide(state, value)
	if not Config.validHeat(value) then return "Invalid" end
	if state.payoutPending then return "PayoutPending" end
	if state.mode ~= "Board" or not state.ready then return "Unavailable" end
	if not (state.over or state.drops == 0) then return "Locked" end
	if state.guided and not state.over then return "Guided" end
	if state.field and not state.over and state.drops == 0 and state.runHeat ~= value then return "Rebuild" end
	return "Store"
end

return table.freeze(Heat)
