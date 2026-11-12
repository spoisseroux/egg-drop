local Catalog = require(script.Parent.EggCatalog)

-- The daily contracts were retired by hatching v9 (QUESTS-DIFFICULTY-PLAN
-- section 6); quests replace them. Only the shared day clock remains: it rolls
-- at 05:00 UTC (EggCatalog.DayOffsetSeconds) for the gift, petting and quests.
local Daily = {}

function Daily.dayOf(now)
	return tostring(math.floor((now + Catalog.DayOffsetSeconds) / 86400))
end

return Daily
