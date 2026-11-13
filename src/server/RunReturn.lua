-- Server-state only. A return/retry is the sole trigger; saving never starts a run.
local Return = {}

local function available(board, ready)
	local handle = board.nursery
	return ready and not board.closing and not board.nurseryBusy and not board.payoutPending
		and handle and handle.status == "Ready" and not handle.busy and not handle.pending
		and handle.state and not handle.state.lastHatch
end

function Return.classify(board, ready, ownsPip)
	if not available(board, ready) then return "Preserve" end
	if not board.field then return if ownsPip then "FirstField" else "Preserve" end
	if not ownsPip then return "Preserve" end
	if not board.round or not board.round.over then return "Preserve" end
	local earned, receipt = board.earnedPayout, board.nursery.state.lastRunReward
	if earned and earned.saved == true and earned.sequence == board.runSequence
		and receipt and receipt.sequence == board.runSequence then return "FreshField" end
	-- A permanently refused payout (e.g. BalanceLimit) is final: the run may end.
	if earned and earned.refused and earned.sequence == board.runSequence then return "FreshField" end
	return "Preserve"
end

function Return.enter(board, ready, ownsPip, initialize)
	if board.mode ~= "Room" then return false end
	local decision = Return.classify(board, ready, ownsPip)
	if decision == "Preserve" then return false end
	initialize(board, board.sim.preset)
	return true
end

function Return.retry(board, ready, ownsPip, expectedSequence, initialize)
	-- Require the sequence observed at the intent, including welcome retries.
	if board.mode ~= "Board" or not board.round or not board.round.over or type(expectedSequence) ~= "number"
		or expectedSequence ~= expectedSequence or expectedSequence < 1
		or expectedSequence % 1 ~= 0 or expectedSequence ~= board.runSequence then return false end
	local decision = Return.classify(board, ready, ownsPip)
	local welcome = not board.field and not ownsPip and board.round and board.round.over
		and available(board, ready)
	if decision == "Preserve" and not welcome then return false end
	initialize(board, board.sim.preset)
	return true
end

-- Pocket Menu "Restart round" (UI-SPEC-COMPACT-FRAME 9, decision 6): forfeit a live
-- run that has started. No payout and no settlement: the run never ended. The
-- caller re-initialises the same field template with a fresh seed, so a learned
-- egg queue cannot be replayed. An empty board is already fresh (refused).
function Return.restart(board, ready, ownsPip, expectedSequence, initialize)
	if board.mode ~= "Board" or not board.field or not board.round or board.round.over
		or not ownsPip or board.payoutPending or type(expectedSequence) ~= "number"
		or expectedSequence ~= expectedSequence or expectedSequence % 1 ~= 0 or expectedSequence ~= board.runSequence or not board.sim or (board.sim.drops or 0) <= 0 then return false end
	if not available(board, ready) then return false end
	initialize(board, board.sim.preset)
	return true
end

return Return
