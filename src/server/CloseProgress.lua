-- Drain retained writes and the earned round before releasing its fenced lease.
local Close = {}
function Close.drain(hatching, handle, payout, options)
	options = options or {}
	local now, wait = options.now or os.clock, options.wait or task.wait
	local deadline = now() + (options.timeout or 20)
	local backoff = .5
	while now() < deadline do
		if handle.busy then
			wait(.1)
		elseif handle.pending then
			hatching.retry(handle)
			wait(.1)
		elseif payout and not payout.saved then
			local ok = hatching.award(handle, payout.sequence, payout.amount, payout.summary)
			if ok then payout.saved = true else wait(.25) end
		else
			if options.profileFlush then
				local ok, reason = options.profileFlush()
				if not ok then
					wait(if reason == "Busy" then .1 else backoff)
					if reason ~= "Busy" then backoff = math.min(2, backoff * 2) end
					continue
				end
			end
			if now() >= deadline then break end
			if handle.status and handle.status ~= "Ready" and handle.status ~= "Retrying" then
				return true, "NoAcquiredLease"
			end
			return hatching.release(handle)
		end
	end
	-- Do not hand an unfinished operation to a second live writer. The lease
	-- expires naturally if Roblox cannot accept a write before shutdown.
	return false, "CloseTimeout"
end
return Close
