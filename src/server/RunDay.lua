-- The quest day a field run counts toward (Quests/difficulty review, fix 1).
-- A run belongs to the UTC day of its FIRST DROP, not the day its board was
-- reset: a fresh board left sitting across 05:00 UTC must count toward the day
-- the player actually started it. Pure, so the host's stamp is spec-checked.
local RunDay = {}

-- Called after every accepted drop with the drop count after it. The first drop
-- (0 -> 1) stamps today; later drops keep the stamp. A missing stamp past the
-- first drop (should not happen) is repaired with today rather than left nil.
function RunDay.onDrop(runDay, dropsAfter, today)
	if dropsAfter == 1 or runDay == nil then return today end
	return runDay
end

-- The day written into the award summary. A run that settles without a stamp
-- (no drops) falls back to the settlement day.
function RunDay.forSummary(runDay, today)
	return if runDay ~= nil then runDay else today
end

return table.freeze(RunDay)
