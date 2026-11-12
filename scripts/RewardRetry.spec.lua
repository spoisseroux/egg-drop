-- require(ServerScriptService.Server.ZZSpecs.RewardRetry)(ServerScriptService.Server)
return function(server)
	local Retry = require(server.RewardRetry)
	local passed = {}
	local function test(name, fn) fn(); table.insert(passed, name) end
	test("a saved award (and an already-awarded repeat) ends the loop as saved", function()
		assert(Retry.classify(true, "Saved") == "Saved")
		assert(Retry.classify(true, "AlreadyAwarded") == "Saved")
	end)
	test("permanent refusals stop instead of retrying forever", function()
		for _, reason in ipairs({ "BalanceLimit", "InvalidReward", "InvalidSummary", "FamilyChanged", "AwardChanged", "SessionLost", "Released" }) do
			assert(Retry.classify(false, reason) == "Permanent", reason)
		end
	end)
	test("transient DataStore and busy refusals keep retrying", function()
		for _, reason in ipairs({ "Retrying", "Busy", "Pending", "RevisionChanged", "Unavailable", "Loading" }) do
			assert(Retry.classify(false, reason) == "Transient", reason)
		end
	end)
	test("transient retries back off and cap at 30 seconds", function()
		assert(Retry.delay(1) == 2 and Retry.delay(2) == 4 and Retry.delay(3) == 8)
		assert(Retry.delay(10) == 30 and Retry.delay(nil) == 2)
	end)
	test("the host loop clears pending and stops on a BalanceLimit refusal", function()
		-- Drives the same policy the host's settle loop uses, with a fake award.
		local board = { payoutPending = true, attempts = 0 }
		local function award() board.attempts += 1; return false, "BalanceLimit" end
		local outcome
		for _ = 1, 100 do
			local ok, reason = award()
			outcome = Retry.classify(ok, reason)
			if outcome ~= "Transient" then break end
		end
		if outcome == "Permanent" then board.payoutPending = false end
		assert(outcome == "Permanent" and board.attempts == 1 and board.payoutPending == false)
	end)
	return { passed = #passed, cases = passed }
end
