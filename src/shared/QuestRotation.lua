-- Quest rotation (QUESTS-DIFFICULTY-PLAN sections 3 and 4). Pure and
-- deterministic: the same user, day, week and saved state always draw the same
-- quests. One clock with the daily gift (DailyContracts.dayOf, 05:00 UTC); the
-- week starts on Monday: week = (day + 3) // 7.
local Shared = script.Parent
local Catalog = require(Shared.QuestCatalog)
local Rules = require(Shared.QuestRules)
local Rotation = {}

function Rotation.week(day)
	return (tonumber(day) + 3) // 7
end

function Rotation.seed(userId, period, pool, salt)
	userId = tonumber(userId) or 0
	return ((userId % 2147483629) * 31 + period * 7 + pool + (salt or 0) * 1009) % 2147483647
end

-- One daily quest from `pool`: never one already drawn this week (weekUsed) or
-- already in today's slots; once the pool is spent, only avoid today's slots.
function Rotation.drawDaily(userId, day, pool, weekUsed, taken, salt)
	local list = Catalog.DailyPools[pool]
	local function pick(filter)
		local candidates = {}
		for _, def in ipairs(list) do
			if not table.find(taken, def.id) and filter(def) then table.insert(candidates, def) end
		end
		return candidates
	end
	local candidates = pick(function(def) return bit32.band(weekUsed, bit32.lshift(1, def.bit - 1)) == 0 end)
	if #candidates == 0 then candidates = pick(function() return true end) end
	local random = Random.new(Rotation.seed(userId, tonumber(day), Catalog.PoolIndex[pool], salt))
	local def = candidates[random:NextInteger(1, #candidates)]
	return def, bit32.bor(weekUsed, bit32.lshift(1, def.bit - 1))
end

function Rotation.drawWeekly(userId, week, pool)
	local list = Catalog.WeeklyPools[pool]
	local random = Random.new(Rotation.seed(userId, tonumber(week), Catalog.PoolIndex[pool] + 3, 0))
	return list[random:NextInteger(1, #list)]
end

local function drawDays(record, userId)
	local ids, used = {}, record.weekUsed
	for _, pool in ipairs(Catalog.Pools) do
		local def
		def, used = Rotation.drawDaily(userId, record.day, pool, used, ids, 0)
		table.insert(ids, def.id)
	end
	record.daily = { ids = ids, prog = { 0, 0, 0 }, claimed = 0, rerolled = false }
	record.weekUsed = used
end
local function drawWeek(record, userId)
	local ids = {}
	for _, pool in ipairs(Catalog.Pools) do table.insert(ids, Rotation.drawWeekly(userId, record.week, pool).id) end
	record.weekly = { ids = ids, prog = { 0, 0, 0 }, claimed = 0, bonus = false }
	record.weekUsed = 0
end

function Rotation.fresh(userId, day)
	day = tonumber(day)
	local record = { v = 1, catalog = Catalog.CatalogVersion, day = tostring(day), week = tostring(Rotation.week(day)), history = {} }
	drawWeek(record, userId)
	drawDays(record, userId)
	return record
end

function Rotation.pushHistory(record, entry)
	table.insert(record.history, entry)
	while #record.history > Catalog.HistoryLimit do table.remove(record.history, 1) end
end

local function claimedBit(mask, slot) return bit32.band(mask, bit32.lshift(1, slot - 1)) ~= 0 end
Rotation.claimedBit = claimedBit

-- Credit what was finished but never claimed in a closing period. Marks the
-- slots claimed so a second pass over the same record never pays again.
local function credit(record, scope, multiplier)
	local block, total = record[scope], 0
	for slot, id in ipairs(block.ids) do
		local def = Catalog.ById[id]
		if def and not claimedBit(block.claimed, slot) and Rules.complete(def, block.prog[slot]) then
			local stars = def.reward * multiplier
			block.claimed = bit32.bor(block.claimed, bit32.lshift(1, slot - 1))
			total += stars
			Rotation.pushHistory(record, { d = record.day, id = id, s = stars, a = true })
		end
	end
	if scope == "weekly" and not block.bonus and block.claimed == 7 then
		local stars = Catalog.WeeklyBonus * multiplier
		block.bonus = true
		total += stars
		Rotation.pushHistory(record, { d = record.day, id = "weekly_bonus", s = stars, a = true })
	end
	return total
end

-- Move the record to `day` (a number or numeric string). Returns a new record,
-- the Stars auto-credited for finished-but-unclaimed quests, and whether it
-- changed. A clock rollback (stored day later than `day`) changes nothing.
function Rotation.roll(record, day, userId, multiplier)
	day = tonumber(day)
	multiplier = if multiplier == 2 then 2 else 1
	local current = tonumber(record.day)
	if day <= current then return record, 0, false end
	local nextRecord = table.clone(record)
	nextRecord.daily = table.clone(record.daily); nextRecord.daily.prog = table.clone(record.daily.prog)
	nextRecord.weekly = table.clone(record.weekly); nextRecord.weekly.prog = table.clone(record.weekly.prog)
	nextRecord.history = table.clone(record.history)
	local credited = credit(nextRecord, "daily", multiplier)
	local week = Rotation.week(day)
	if week > tonumber(record.week) then
		credited += credit(nextRecord, "weekly", multiplier)
		nextRecord.week = tostring(week)
		drawWeek(nextRecord, userId)
	end
	nextRecord.day = tostring(day)
	drawDays(nextRecord, userId)
	return nextRecord, credited, true
end

return table.freeze(Rotation)
