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
	-- Settling first (Garden Dash) comes out of the drain's 20 s: both stay under BindToClose's 25 s.
	assert(Close.remaining(0) == 20 and Close.remaining(5) == 15 and Close.remaining(30) == 2 and Close.remaining(-1) == 20)
	for spent = 0, 23 do assert(spent + Close.remaining(spent) <= 25) end
	clock = 0
	assert(not Close.drain(api, { pending = true }, nil, { now = options.now, wait = options.wait, timeout = Close.remaining(6) }))
	assert(clock >= 14 and clock < 14.5)
	return { passed = 3, cases = { "drain pending and earned payout before release", "failed drain keeps lease fenced", "settle time comes out of the drain" } }
end
