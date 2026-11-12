-- Quest definitions (QUESTS-DIFFICULTY-PLAN section 2). Data only.
-- Daily: three pools (play, craft, skill) of 8, one quest drawn from each per
-- day, 4 Stars each (12 a day). Weekly: three pools of 4, one from each per
-- week, 10 Stars each (30 a week) plus WeeklyBonus for clearing all three.
-- Ids are never reused; bump CatalogVersion when a definition changes meaning.
--   metric: rounds | wins | cleanWins | score | chain | tierMade | goalsMet | heatsPlayed | templates
--   mode:   sum (add per run) | max (best single run) | set (bitmask; progress = bits set)
--   heat:   minimum heat a run must be played on to count (nil = any)
--   tier:   for tierMade, the tier the run must reach
local Catalog = {}
Catalog.CatalogVersion = 1
Catalog.DailyReward = 4
Catalog.WeeklyReward = 10
Catalog.WeeklyBonus = 5
Catalog.Pools = table.freeze({ "play", "craft", "skill" })
Catalog.PoolIndex = table.freeze({ play = 1, craft = 2, skill = 3 })
Catalog.HistoryLimit = 30

local function q(id, pool, title, sub, metric, mode, target, extra)
	local def = { id = id, pool = pool, title = title, sub = sub, metric = metric, mode = mode, target = target }
	for k, v in pairs(extra or {}) do def[k] = v end
	return def
end

local daily = {
	-- play
	q("d_rounds3", "play", "Finish 3 rounds", "Any difficulty, all 24 drops", "rounds", "sum", 3),
	q("d_wins2", "play", "Win 2 rounds", "Any difficulty", "wins", "sum", 2),
	q("d_rounds5", "play", "Finish 5 rounds", "Any difficulty, all 24 drops", "rounds", "sum", 5),
	q("d_heats2", "play", "Play two difficulties", "Finish a round on each", "heatsPlayed", "set", 2),
	q("d_win_medium", "play", "Win on Medium or higher", "Medium or Hard", "wins", "sum", 1, { heat = "medium" }),
	q("d_templates3", "play", "Play 3 goal types", "Finish rounds with different goals", "templates", "set", 3),
	q("d_goals4", "play", "Complete 4 goals", "Across any rounds", "goalsMet", "sum", 4),
	q("d_wins3", "play", "Win 3 rounds", "Any difficulty", "wins", "sum", 3),
	-- craft
	q("d_chain3", "craft", "Chain 3 merges", "In one round", "chain", "max", 3),
	q("d_chain4", "craft", "Chain 4 merges", "In one round", "chain", "max", 4),
	q("d_tidy1", "craft", "Win with a tidy stack", "Finish below the tidy line", "cleanWins", "sum", 1),
	q("d_tier4", "craft", "Make a tier IV", "In any round", "tierMade", "max", 1, { tier = 4 }),
	q("d_tidy2", "craft", "Win 2 tidy rounds", "Finish below the tidy line", "cleanWins", "sum", 2),
	q("d_goals6", "craft", "Complete 6 goals", "Across any rounds", "goalsMet", "sum", 6),
	q("d_chain3_medium", "craft", "Chain 3 on Medium", "Medium or Hard, one round", "chain", "max", 3, { heat = "medium" }),
	q("d_score400", "craft", "Score 400", "In one round", "score", "max", 400),
	-- skill
	q("d_score600", "skill", "Score 600", "In one round", "score", "max", 600),
	q("d_score800", "skill", "Score 800", "In one round", "score", "max", 800),
	q("d_win_hard", "skill", "Win on Hard", "Skill quest", "wins", "sum", 1, { heat = "hard" }),
	q("d_tier4_hard", "skill", "Make a tier IV on Hard", "Skill quest", "tierMade", "max", 1, { tier = 4, heat = "hard" }),
	q("d_chain5", "skill", "Chain 5 merges", "In one round", "chain", "max", 5),
	q("d_tier5", "skill", "Make a tier V", "In any round", "tierMade", "max", 1, { tier = 5 }),
	q("d_tidy_hard", "skill", "Tidy win on Hard", "Skill quest", "cleanWins", "sum", 1, { heat = "hard" }),
	q("d_goals_hard", "skill", "Complete 3 goals on Hard", "Across Hard rounds", "goalsMet", "sum", 3, { heat = "hard" }),
}
local weekly = {
	q("w_wins12", "play", "Win 12 rounds", "Any difficulty", "wins", "sum", 12),
	q("w_rounds20", "play", "Finish 20 rounds", "Any difficulty, all 24 drops", "rounds", "sum", 20),
	q("w_templates6", "play", "Play all 6 goal types", "Finish rounds with each goal", "templates", "set", 6),
	q("w_heats3", "play", "Play all three difficulties", "Finish a round on each", "heatsPlayed", "set", 3),
	q("w_tidy6", "craft", "Win 6 tidy rounds", "Finish below the tidy line", "cleanWins", "sum", 6),
	q("w_goals30", "craft", "Complete 30 goals", "Across any rounds", "goalsMet", "sum", 30),
	q("w_tier5", "craft", "Make a tier V", "In any round", "tierMade", "max", 1, { tier = 5 }),
	q("w_score800", "craft", "Score 800", "In one round", "score", "max", 800),
	q("w_hard3", "skill", "Win 3 on Hard", "Hard rounds", "wins", "sum", 3, { heat = "hard" }),
	q("w_hard_tidy2", "skill", "2 tidy wins on Hard", "Hard rounds", "cleanWins", "sum", 2, { heat = "hard" }),
	q("w_tier4_hard3", "skill", "Tier IV in 3 Hard rounds", "Hard rounds", "tierMade", "sum", 3, { tier = 4, heat = "hard" }),
	q("w_goals_hard12", "skill", "Complete 12 goals on Hard", "Hard rounds", "goalsMet", "sum", 12, { heat = "hard" }),
}

Catalog.Daily, Catalog.Weekly, Catalog.ById = {}, {}, {}
Catalog.DailyPools, Catalog.WeeklyPools = { play = {}, craft = {}, skill = {} }, { play = {}, craft = {}, skill = {} }
for index, def in ipairs(daily) do
	def.scope, def.reward, def.bit = "daily", Catalog.DailyReward, index -- bit 1..24 for weekUsed
	table.insert(Catalog.Daily, table.freeze(def))
	table.insert(Catalog.DailyPools[def.pool], Catalog.Daily[index])
	Catalog.ById[def.id] = Catalog.Daily[index]
end
for index, def in ipairs(weekly) do
	def.scope, def.reward, def.bit = "weekly", Catalog.WeeklyReward, index
	table.insert(Catalog.Weekly, table.freeze(def))
	table.insert(Catalog.WeeklyPools[def.pool], Catalog.Weekly[index])
	Catalog.ById[def.id] = Catalog.Weekly[index]
end
for _, pools in ipairs({ Catalog.DailyPools, Catalog.WeeklyPools }) do
	for key, list in pairs(pools) do pools[key] = table.freeze(list) end
	table.freeze(pools)
end
table.freeze(Catalog.Daily); table.freeze(Catalog.Weekly); table.freeze(Catalog.ById)

return table.freeze(Catalog)
