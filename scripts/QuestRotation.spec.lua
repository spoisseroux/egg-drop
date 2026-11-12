-- require(ZZSpecs.QuestRotation)() in any datamodel (shared modules only).
-- Covers QuestCatalog, QuestRules and QuestRotation (plan section 8).
return function()
	local Shared = game:GetService("ReplicatedStorage").Shared
	local Catalog = require(Shared.QuestCatalog)
	local Rules = require(Shared.QuestRules)
	local Rotation = require(Shared.QuestRotation)
	local Daily = require(Shared.DailyContracts)
	local passed = {}
	local function test(name, fn) fn(); table.insert(passed, name) end
	local function run(over)
		local s = { success = true, clean = false, score = 300, chain = 2, drops = 24, heat = "medium", maxTier = 3, goalsMet = 2, templateId = "bank_pair" }
		for k, v in pairs(over or {}) do s[k] = v end
		return s
	end

	test("catalog: 8 dailies per pool at 4, 12 weeklies at 10, unique ids and bits", function()
		local seen = {}
		for _, pool in ipairs(Catalog.Pools) do
			assert(#Catalog.DailyPools[pool] == 8 and #Catalog.WeeklyPools[pool] == 4)
			for _, def in ipairs(Catalog.DailyPools[pool]) do assert(def.reward == 4 and def.scope == "daily") end
		end
		assert(#Catalog.Daily == 24 and #Catalog.Weekly == 12 and Catalog.WeeklyBonus == 5)
		for _, def in ipairs(Catalog.Daily) do assert(not seen[def.id] and def.bit >= 1 and def.bit <= 24); seen[def.id] = true end
		for _, def in ipairs(Catalog.Weekly) do assert(not seen[def.id] and def.reward == 10); seen[def.id] = true end
		assert(3 * Catalog.DailyReward == 12 and 3 * Catalog.WeeklyReward == 30)
	end)

	test("rules: every metric, minimum heat and full rounds only", function()
		local by = Catalog.ById
		assert(Rules.progress(by.d_rounds3, 0, run()) == 1 and Rules.progress(by.d_rounds3, 0, run({ success = false })) == 1)
		assert(Rules.progress(by.d_rounds3, 0, run({ drops = 11 })) == 0, "overflowed rounds never count")
		assert(Rules.progress(by.d_wins2, 1, run()) == 2 and Rules.progress(by.d_wins2, 2, run()) == 2 and Rules.progress(by.d_wins2, 0, run({ success = false })) == 0)
		assert(Rules.progress(by.d_tidy1, 0, run()) == 0 and Rules.progress(by.d_tidy1, 0, run({ clean = true })) == 1)
		assert(Rules.progress(by.d_score400, 120, run({ score = 350 })) == 350 and Rules.progress(by.d_score400, 350, run({ score = 900 })) == 400)
		assert(Rules.progress(by.d_chain4, 3, run({ chain = 2 })) == 3 and Rules.progress(by.d_chain4, 3, run({ chain = 6 })) == 4)
		assert(Rules.progress(by.d_tier4, 0, run({ maxTier = 3 })) == 0 and Rules.progress(by.d_tier4, 0, run({ maxTier = 4 })) == 1)
		assert(Rules.progress(by.d_goals4, 3, run({ goalsMet = 3 })) == 4)
		local heats = Rules.progress(by.d_heats2, 0, run({ heat = "easy" }))
		heats = Rules.progress(by.d_heats2, heats, run({ heat = "easy" })); assert(Rules.count(by.d_heats2, heats) == 1)
		heats = Rules.progress(by.d_heats2, heats, run({ heat = "hard" })); assert(Rules.count(by.d_heats2, heats) == 2 and Rules.complete(by.d_heats2, heats))
		local t = 0
		for _, id in ipairs({ "bank_pair", "bank_pair", "lantern_chain", "mirror_marks" }) do t = Rules.progress(by.d_templates3, t, run({ templateId = id })) end
		assert(Rules.count(by.d_templates3, t) == 3 and Rules.validProgress(by.d_templates3, t))
		-- Minimum heat.
		assert(Rules.progress(by.d_win_hard, 0, run({ heat = "medium" })) == 0 and Rules.progress(by.d_win_hard, 0, run({ heat = "hard" })) == 1)
		assert(Rules.progress(by.d_win_medium, 0, run({ heat = "easy" })) == 0 and Rules.progress(by.d_win_medium, 0, run({ heat = "hard" })) == 1)
		assert(Rules.progress(by.d_tier4_hard, 0, run({ heat = "medium", maxTier = 5 })) == 0)
		assert(not Rules.validProgress(by.d_wins2, 3) and not Rules.validProgress(by.d_wins2, -1) and not Rules.validProgress(by.d_wins2, 0.5))
	end)

	test("rotation is deterministic per user and day, and differs between users", function()
		local a, b = Rotation.fresh(42, 20404), Rotation.fresh(42, 20404)
		assert(table.concat(a.daily.ids, ",") == table.concat(b.daily.ids, ",") and table.concat(a.weekly.ids, ",") == table.concat(b.weekly.ids, ","))
		for i, pool in ipairs(Catalog.Pools) do
			assert(Catalog.ById[a.daily.ids[i]].pool == pool and Catalog.ById[a.weekly.ids[i]].pool == pool)
		end
		local differs = false
		for user = 1, 20 do
			if table.concat(Rotation.fresh(user, 20404).daily.ids, ",") ~= table.concat(a.daily.ids, ",") then differs = true end
		end
		assert(differs)
		assert(Rotation.fresh(-1, 20404).daily.ids[1] ~= nil, "Studio's negative ids are fine")
	end)

	test("Monday boundary and the shared 05:00 UTC clock", function()
		-- 1970-01-05 was a Monday: days 4..10 share a week.
		assert(Rotation.week(3) == 0 and Rotation.week(4) == 1 and Rotation.week(10) == 1 and Rotation.week(11) == 2)
		local monday = os.time({ year = 2026, month = 11, day = 9, hour = 12 })
		local day = tonumber(Daily.dayOf(monday))
		assert(Rotation.week(day) ~= Rotation.week(day - 1) and Rotation.week(day) == Rotation.week(day + 6))
		-- 04:59 UTC is still yesterday; 05:00 UTC is a new day.
		local midnight = 86400 * 20404
		assert(Daily.dayOf(midnight + 5 * 3600 - 1) ~= Daily.dayOf(midnight + 5 * 3600))
	end)

	-- 8 per pool = 7 days + one reroll per pool before anything can repeat.
	test("no daily repeats within a week, with one reroll in each pool", function()
		for user = 1, 25 do
			local week = 4 + 7 * 2900 -- a Monday
			local record = Rotation.fresh(user, week)
			local seen = {}
			for offset = 0, 6 do
				if offset > 0 then record = Rotation.roll(record, week + offset, user, 1) end
				for slot, id in ipairs(record.daily.ids) do
					assert(not seen[id], "repeat " .. id .. " on day " .. offset)
					seen[id] = true
					assert(Catalog.ById[id].pool == Catalog.Pools[slot])
				end
				-- Reroll one pool per day on days 0..2, like the server does (salt 1).
				if offset <= 2 then
					local slot = offset + 1
					local others = { record.daily.ids[1], record.daily.ids[2], record.daily.ids[3] }
					local def, used = Rotation.drawDaily(user, record.day, Catalog.Pools[slot], record.weekUsed, others, 1)
					assert(not seen[def.id], "reroll repeat")
					seen[def.id] = true
					record.weekUsed = used
					record.daily.ids[slot] = def.id
				end
			end
		end
	end)

	test("pool fallback after the week's pool is spent avoids today's slots only", function()
		local all = bit32.lshift(1, 24) - 1
		local taken = { "d_rounds3" }
		for _ = 1, 20 do
			local def, used = Rotation.drawDaily(7, 20404, "play", all, taken, 0)
			assert(def.pool == "play" and def.id ~= "d_rounds3" and used == all)
		end
	end)

	test("week change resets weekUsed and redraws weeklies; rollback changes nothing", function()
		local monday = 4 + 7 * 2900
		local record = Rotation.fresh(9, monday + 6)
		assert(record.weekUsed ~= 0)
		local nextWeek, _, changed = Rotation.roll(record, monday + 7, 9, 1)
		assert(changed and nextWeek.week == tostring(Rotation.week(monday + 7)) and nextWeek.weekly.claimed == 0)
		assert(Rules.popcount(nextWeek.weekUsed) == 3)
		local same, credited, moved = Rotation.roll(nextWeek, monday + 2, 9, 1)
		assert(same == nextWeek and credited == 0 and not moved)
	end)

	test("rollover auto-credits finished, unclaimed quests once, doubled by the pass", function()
		local record = Rotation.fresh(5, 4 + 7 * 2900)
		local d1 = Catalog.ById[record.daily.ids[1]]
		record.daily.prog[1] = Rules.maxStored(d1) -- finished, unclaimed
		record.daily.claimed = 4 -- slot 3 claimed by hand already
		local d3 = Catalog.ById[record.daily.ids[3]]
		record.daily.prog[3] = Rules.maxStored(d3)
		local nextDay, credited = Rotation.roll(record, tonumber(record.day) + 1, 5, 2)
		assert(credited == 8, credited)
		assert(#nextDay.history == 1 and nextDay.history[1].a == true and nextDay.history[1].s == 8 and nextDay.history[1].id == d1.id)
		assert(#record.history == 0, "the input record is never mutated")
		-- Weekly: all three finished on Sunday; Monday credits 30 + the 5 bonus.
		local sunday = Rotation.fresh(5, 4 + 7 * 2900 + 6)
		for slot, id in ipairs(sunday.weekly.ids) do sunday.weekly.prog[slot] = Rules.maxStored(Catalog.ById[id]) end
		local monday, total = Rotation.roll(sunday, 4 + 7 * 2901, 5, 1)
		assert(total == 35 and monday.history[#monday.history].id == "weekly_bonus")
		local again, none = Rotation.roll(monday, 4 + 7 * 2901, 5, 1)
		assert(none == 0 and again == monday)
	end)

	test("history is a ring of at most 30", function()
		local record = Rotation.fresh(1, 20404)
		for i = 1, 45 do Rotation.pushHistory(record, { d = "20404", id = "d_wins2", s = i, a = false }) end
		assert(#record.history == 30 and record.history[1].s == 16 and record.history[30].s == 45)
	end)
	return { passed = #passed, cases = passed }
end
