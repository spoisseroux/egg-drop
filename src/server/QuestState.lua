-- Saved quests inside the fenced hatching record (hatching v9,
-- QUESTS-DIFFICULTY-PLAN sections 3 to 5). Progress only ever comes from the
-- server's round summary inside HatchProgress.award; claims and the daily reroll
-- are HatchProgress transactions. Every write path rolls the calendar first
-- (auto-crediting finished, unclaimed quests). public() previews read-only.
local Shared = game:GetService("ReplicatedStorage").Shared
local Catalog = require(Shared.QuestCatalog)
local Rules = require(Shared.QuestRules)
local Rotation = require(Shared.QuestRotation)
local EggCatalog = require(Shared.EggCatalog)
local Quests = {}

local function integer(value, minimum, maximum)
	return type(value) == "number" and value == value and value % 1 == 0 and value >= minimum and value <= maximum
end
local function canonical(value)
	local n = if type(value) == "string" then tonumber(value) else nil
	return n ~= nil and n % 1 == 0 and math.abs(n) <= 1000000000 and tostring(n) == value
end

local function validBlock(block, scope)
	if type(block) ~= "table" or type(block.ids) ~= "table" or type(block.prog) ~= "table" or #block.ids ~= 3 or #block.prog ~= 3
		or not integer(block.claimed, 0, 7) then return false end
	for slot = 1, 3 do
		local def = Catalog.ById[block.ids[slot]]
		if not def or def.scope ~= scope or def.pool ~= Catalog.Pools[slot] or not Rules.validProgress(def, block.prog[slot]) then return false end
	end
	if scope == "daily" then return type(block.rerolled) == "boolean" end
	return type(block.bonus) == "boolean" and (not block.bonus or block.claimed == 7)
end

function Quests.valid(record)
	if type(record) ~= "table" or record.v ~= 1 or record.catalog ~= Catalog.CatalogVersion
		or not canonical(record.day) or not canonical(record.week) or tonumber(record.week) ~= Rotation.week(tonumber(record.day))
		or not integer(record.weekUsed, 0, bit32.lshift(1, 24) - 1)
		or not validBlock(record.daily, "daily") or not validBlock(record.weekly, "weekly")
		or type(record.history) ~= "table" or #record.history > Catalog.HistoryLimit then return false end
	for key in pairs(record.history) do if not integer(key, 1, Catalog.HistoryLimit) then return false end end
	for _, entry in ipairs(record.history) do
		if type(entry) ~= "table" or not canonical(entry.d) or type(entry.id) ~= "string"
			or not (Catalog.ById[entry.id] or entry.id == "weekly_bonus") or not integer(entry.s, 0, 1000) or type(entry.a) ~= "boolean" then
			return false
		end
	end
	return true
end

-- On load and at every roll: a malformed record, an unknown id or an older
-- catalogue becomes a fresh draw for today. Old saves never crash.
function Quests.sanitize(record, day, userId)
	if Quests.valid(record) then return record end
	return Rotation.fresh(userId, tonumber(day))
end

local function copy(record)
	local r = table.clone(record)
	r.daily = table.clone(record.daily); r.daily.ids = table.clone(record.daily.ids); r.daily.prog = table.clone(record.daily.prog)
	r.weekly = table.clone(record.weekly); r.weekly.ids = table.clone(record.weekly.ids); r.weekly.prog = table.clone(record.weekly.prog)
	r.history = table.clone(record.history)
	return r
end
local function bit(slot) return bit32.lshift(1, slot - 1) end

-- Inside award: roll to the run's transaction day, then count the run toward
-- its own start day (dailies) and start week (weeklies) only.
-- Returns record, Stars auto-credited by the roll, and the slots that moved.
function Quests.onRun(record, run, day, userId, multiplier)
	local rolled, credited = Rotation.roll(record, day, userId, multiplier)
	local q, moved = copy(rolled), {}
	if type(run) ~= "table" or type(run.day) ~= "string" then return q, credited, moved end
	local runDay = tonumber(run.day)
	for _, entry in ipairs({ { scope = "daily", ok = run.day == q.day }, { scope = "weekly", ok = runDay and Rotation.week(runDay) == tonumber(q.week) } }) do
		if entry.ok then
			local block = q[entry.scope]
			for slot, id in ipairs(block.ids) do
				local def = Catalog.ById[id]
				if bit32.band(block.claimed, bit(slot)) == 0 then
					local before = block.prog[slot]
					local after = Rules.progress(def, before, run)
					if after ~= before then
						block.prog[slot] = after
						table.insert(moved, { scope = entry.scope, slot = slot, id = id, count = Rules.count(def, after), target = def.target,
							done = Rules.complete(def, after), was = Rules.complete(def, before) })
					end
				end
			end
		end
	end
	return q, credited, moved
end

-- candidate = { scope = "daily"|"weekly", slot = 0..3, period = day or week string, multiplier, day, userId }
-- Mutates `state` (a transaction copy). slot 0 is the weekly bonus.
function Quests.claim(state, c)
	local rolled, credited = Rotation.roll(state.quests, c.day, c.userId, c.multiplier)
	local q = copy(rolled)
	local scope, slot = c.scope, c.slot
	if (scope ~= "daily" and scope ~= "weekly") or not integer(slot, 0, 3) or (slot == 0 and scope ~= "weekly") then return false, "InvalidQuest" end
	if c.period ~= (if scope == "daily" then q.day else q.week) then return false, "PeriodChanged" end
	local block, stars, id = q[scope], 0, nil
	if slot == 0 then
		if block.bonus then return false, "AlreadyClaimed" end
		if block.claimed ~= 7 then return false, "NotComplete" end
		block.bonus, stars, id = true, Catalog.WeeklyBonus * c.multiplier, "weekly_bonus"
	else
		local def = Catalog.ById[block.ids[slot]]
		if bit32.band(block.claimed, bit(slot)) ~= 0 then return false, "AlreadyClaimed" end
		if not Rules.complete(def, block.prog[slot]) then return false, "NotComplete" end
		block.claimed = bit32.bor(block.claimed, bit(slot))
		stars, id = def.reward * c.multiplier, def.id
	end
	if state.nectar + stars + credited > 1000000000 then return false, "BalanceLimit" end
	Rotation.pushHistory(q, { d = q.day, id = id, s = stars, a = false })
	state.quests, state.nectar = q, state.nectar + stars + credited
	state.lastQuestClaim = { scope = scope, slot = slot, period = c.period, id = id, stars = stars }
	return true
end

-- candidate = { slot = 1..3, day, multiplier, userId }. One free reroll a day,
-- on an unstarted, unclaimed slot, to another quest from the same pool.
function Quests.reroll(state, c)
	local rolled, credited = Rotation.roll(state.quests, c.day, c.userId, c.multiplier)
	local q = copy(rolled)
	if not integer(c.slot, 1, 3) then return false, "InvalidQuest" end
	if c.period ~= q.day then return false, "DayChanged" end
	local block = q.daily
	if block.rerolled then return false, "NoReroll" end
	if block.prog[c.slot] ~= 0 then return false, "Started" end
	if bit32.band(block.claimed, bit(c.slot)) ~= 0 then return false, "Claimed" end
	local def, used = Rotation.drawDaily(c.userId, q.day, Catalog.Pools[c.slot], q.weekUsed, block.ids, 1)
	block.ids[c.slot], block.prog[c.slot], block.rerolled, q.weekUsed = def.id, 0, true, used
	if state.nectar + credited > 1000000000 then return false, "BalanceLimit" end
	state.quests, state.nectar = q, state.nectar + credited
	return true
end

local function dayStart(day) return day * 86400 - EggCatalog.DayOffsetSeconds end

-- Owner snapshot. Rewards are shown with the pass multiplier applied.
function Quests.public(record, day, userId, multiplier, now)
	multiplier = if multiplier == 2 then 2 else 1
	if not Quests.valid(record) then return nil end
	local q = Rotation.roll(record, day, userId, multiplier)
	local function rows(scope)
		local block, list = q[scope], {}
		for slot, id in ipairs(block.ids) do
			local def = Catalog.ById[id]
			local claimed = bit32.band(block.claimed, bit(slot)) ~= 0
			local complete = Rules.complete(def, block.prog[slot])
			table.insert(list, { slot = slot, id = id, title = def.title, sub = def.sub, pool = def.pool, metric = def.metric,
				heat = def.heat, progress = Rules.count(def, block.prog[slot]), target = def.target,
				reward = def.reward * multiplier, claimed = claimed, ready = complete and not claimed,
				canReroll = scope == "daily" and not block.rerolled and block.prog[slot] == 0 and not claimed })
		end
		return list
	end
	local history = {}
	for index = #q.history, 1, -1 do
		local entry = q.history[index]
		local def = Catalog.ById[entry.id]
		table.insert(history, { d = entry.d, id = entry.id, s = entry.s, a = entry.a,
			title = if def then def.title elseif entry.id == "weekly_bonus" then "All three weekly quests" else entry.id,
			weekly = def == nil or def.scope == "weekly" })
	end
	local d, w = tonumber(q.day), tonumber(q.week)
	return {
		day = q.day, week = q.week, multiplier = multiplier,
		daily = rows("daily"), weekly = rows("weekly"), history = history,
		dailyClaimed = q.daily.claimed, weeklyClaimed = q.weekly.claimed,
		rerollLeft = if q.daily.rerolled then 0 else 1,
		bonus = { reward = Catalog.WeeklyBonus * multiplier, claimed = q.weekly.bonus, ready = q.weekly.claimed == 7 and not q.weekly.bonus },
		bonusReady = q.weekly.claimed == 7 and not q.weekly.bonus,
		resetIn = math.max(0, dayStart(d + 1) - now), weekResetIn = math.max(0, dayStart((w + 1) * 7 - 3) - now),
	}
end

return table.freeze(Quests)
