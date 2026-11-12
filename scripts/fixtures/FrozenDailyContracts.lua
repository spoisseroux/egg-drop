local Catalog = require(game:GetService("ReplicatedStorage").Shared.EggCatalog)

local Daily = {
	Definitions = {
		{ id = "runs", title = "Win 2 rounds", hint = "Complete both goals in 24 drops without overflow", target = 2, reward = 4, bit = 1 },
		{ id = "chain", title = "Chain 3 merges", hint = "Build a chain of 3 in a full round", target = 3, reward = 3, bit = 2 },
		{ id = "score", title = "Score 500", hint = "Earn 500 points in a full round", target = 500, reward = 3, bit = 4 },
	},
}

function Daily.dayOf(now)
	return tostring(math.floor((now + Catalog.DayOffsetSeconds) / 86400))
end

function Daily.empty(day)
	return { day = day, progress = { runs = 0, chain = 0, score = 0 }, claimedMask = 0 }
end

function Daily.public(record, day)
	local active = if record and tonumber(record.day) >= tonumber(day) then record else Daily.empty(day)
	local rows = {}
	for _, item in ipairs(Daily.Definitions) do
		table.insert(rows, { id = item.id, title = item.title, hint = item.hint, target = item.target,
			reward = item.reward, progress = math.min(item.target, active.progress[item.id]),
			claimed = bit32.band(active.claimedMask, item.bit) ~= 0 })
	end
	return rows
end

function Daily.apply(record, summary, currentDay)
	-- Runs belong to their start day. Neither reconnect nor a delayed retry can
	-- turn yesterday's run into today's contract progress. Clock rollback cannot reset claims.
	if summary.day ~= currentDay or tonumber(record.day) > tonumber(currentDay) or summary.drops ~= 24 then
		return record, 0, {}
	end
	if record.day ~= currentDay then record = Daily.empty(currentDay) end
	local p = record.progress
	p.runs = math.min(2, p.runs + (if summary.success then 1 else 0))
	p.chain = math.max(p.chain, math.min(summary.chain, 3))
	p.score = math.max(p.score, math.min(summary.score, 500))
	local reward, completed = 0, {}
	for _, item in ipairs(Daily.Definitions) do
		if p[item.id] >= item.target and bit32.band(record.claimedMask, item.bit) == 0 then
			record.claimedMask = bit32.bor(record.claimedMask, item.bit)
			reward += item.reward
			table.insert(completed, item.id)
		end
	end
	return record, reward, completed
end

return Daily
