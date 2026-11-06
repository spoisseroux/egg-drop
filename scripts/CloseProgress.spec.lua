return function(Close)
	local clock, calls, failures = 0, {}, 2
	local h = { pending = true }
	local payout = { sequence = 4, amount = 8, summary = { family = "pip" } }
	local api = {
		retry = function(handle) table.insert(calls, "retry"); handle.pending = nil; return true end,
		award = function(handle, sequence, amount, summary)
			assert(sequence == 4 and amount == 8 and summary.family == "pip")
			table.insert(calls, "award")
			failures -= 1
			return failures < 0
		end,
		release = function() assert(payout.saved); table.insert(calls, "release"); return true end,
	}
	local options = { now = function() return clock end, wait = function(dt) clock += dt end, timeout = 2 }
	assert(Close.drain(api, h, payout, options))
	assert(table.concat(calls, ",") == "retry,award,award,award,release")
	local released = false
	clock = 0
	api.retry = function() return false end
	api.release = function() released = true end
	local ok, reason = Close.drain(api, { pending = true }, nil, options)
	assert(not ok and reason == "CloseTimeout" and not released)
	return { passed = 2, cases = { "drain pending and earned payout before release", "failed drain keeps lease fenced" } }
end
