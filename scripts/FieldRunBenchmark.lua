-- Run from Studio Edit with the production modules supplied in dependencies.
-- This uses the actual solver; only the input strategies differ.
local Benchmark = {}

local function matchingAim(sim, field, Simulation, Config)
	local nextTarget = field:target()
	local targetDistance = math.max(3.7, field.zoneBound + 0.5)
	local target = if nextTarget then nextTarget.side * targetDistance else targetDistance
	if not nextTarget then
		local left, right = 0, 0
		for _, egg in ipairs(sim.eggs) do
			if egg.position.X < 0 then left += 2 ^ (egg.tier - 1) else right += 2 ^ (egg.tier - 1) end
		end
		target = if left <= right then -3.7 else 3.7
	end
	local tier = Simulation.nextTier(sim)
	local best, distance = nil, math.huge
	for _, egg in ipairs(sim.eggs) do
		if egg.tier == tier and egg.position.X * target > 0 then
			local delta = math.abs(egg.position.X - target)
			if delta < distance then best, distance = egg, delta end
		end
	end
	local x = if best then best.position.X else target
	local span = Config.Width / 2 - Config.Tiers[tier].radius
	return math.clamp(0.5 + x / (2 * span), 0, 1)
end

local function rolloutAim(sim, field, Simulation, Round, FieldRun, Config, horizon)
	-- Work the marked region first; once both roots are restored, consolidate.
	local target = field:target()
	if target and target.tier == 3 then return matchingAim(sim, field, Simulation, Config) end
	local candidates = { matchingAim(sim, field, Simulation, Config) }
	if target then
		local span = Config.Width / 2 - Config.Tiers[Simulation.nextTier(sim)].radius
		local direction = target.side
		for index = 0, 6 do
			local x = direction * (FieldRun.ZoneBound + 1 + index * 0.4)
			table.insert(candidates, math.clamp(0.5 + x / (span * 2), 0.02, 0.98))
		end
	else
		for index = 0, 10 do table.insert(candidates, 0.04 + index * 0.092) end
	end
	local bestAim, bestValue = candidates[1], -math.huge
	for _, aim in ipairs(candidates) do
		local copy = table.clone(sim)
		copy.eggs = {}
		for _, egg in ipairs(sim.eggs) do table.insert(copy.eggs, table.clone(egg)) end
		if not Simulation.drop(copy, aim) then continue end
		local run = FieldRun.new({ minTier = field.minTier, targets = field.targets })
		run.rootStage = field.rootStage
		local round = Round.new(FieldRun.roundOptions())
		local merged, merges = {}, 0
		for _ = 1, math.ceil(horizon / Config.FixedStep) do
			table.clear(merged)
			Simulation.step(copy, Config.FixedStep, merged)
			for _, merge in ipairs(merged) do
				merges += merge.tier
				run:observe(merge)
			end
			round:step(copy.eggs, Config.FixedStep, copy.drops)
			if round.over then break end
		end
		local maximum, squares = 0, 0
		for _, egg in ipairs(copy.eggs) do
			local top = egg.position.Y + egg.radius
			maximum = math.max(maximum, top)
			squares += top * top
		end
		local value = run.rootStage * 2000 + merges * 30 - maximum * 32 - squares * 0.8
			- #copy.eggs * 4 - (if round.over then 20000 else 0)
		if value > bestValue then bestValue, bestAim = value, aim end
	end
	return bestAim
end

function Benchmark.run(dependencies, options)
	options = options or {}
	local Simulation, Round, FieldRun, Config = dependencies.Simulation, dependencies.Round, dependencies.FieldRun, dependencies.Config
	local count = options.count or 30
	local firstSeed = options.firstSeed or 40001
	local cadence = options.cadence or 1.25
	local resetSeconds = options.resetSeconds or Config.ResetInterval
	local contactGate = options.contactGate ~= false
	local strategies = options.strategies or { "center", "random", "heuristic", "fastCenter", "fastRandom" }
	local results = { seeds = count, firstSeed = firstSeed, cadence = cadence, resetSeconds = resetSeconds,
		kick = options.kick or 6, contactGate = contactGate, zoneBound = FieldRun.ZoneBound,
		trayWidth = Config.Width, cleanHeight = FieldRun.BonusHeight, roundOptions = options.roundOptions or FieldRun.roundOptions(),
		targets = options.targets or (if options.mastery then FieldRun.MasteryTargets else {
			{ side = -1, tier = options.minTier or FieldRun.MinTier }, { side = 1, tier = options.minTier or FieldRun.MinTier },
		}), rows = {}, samples = {} }
	for _, strategy in ipairs(strategies) do
		local row = { strategy = strategy, wins = 0, nectar = 0, seconds = 0, score = 0, overflows = 0, drops = 0, maxHeight = 0, attempts = 0, threatenedRuns = 0, warningSeconds = 0 }
		for index = 0, count - 1 do
			local seed = firstSeed + index
			local sim = Simulation.new("Springy", 0, { seed = seed, starter = options.starter or {}, kick = options.kick or 6,
				contactGate = contactGate })
			local round, field = Round.new(options.roundOptions or FieldRun.roundOptions()), FieldRun.new({ minTier = options.minTier,
				targets = options.targets or (if options.mastery then FieldRun.MasteryTargets else nil) })
			local random = Random.new(seed + 71831)
			local merged = {}
			local now, nextDrop, lastMerge, chain, attempts = 0, 0, -math.huge, 0, 0
			local maxDanger, warningSeconds = 0, 0
			local interval = if strategy == "fastCenter" or strategy == "fastRandom" then Config.DropInterval else cadence
			local deadline = 180
			while not field.outcome and now < deadline do
				if now + 1e-7 >= nextDrop and field:canDrop(sim.drops) then
					attempts += 1
					local aim = if strategy == "random" or strategy == "fastRandom" then random:NextNumber()
						elseif strategy == "heuristic" then rolloutAim(sim, field, Simulation, Round, FieldRun, Config, interval) else 0.5
					Simulation.drop(sim, aim)
					nextDrop = now + interval
				end
				table.clear(merged)
				Simulation.step(sim, Config.FixedStep, merged)
				for _, merge in ipairs(merged) do
					chain = if now - lastMerge <= 1.25 then chain + 1 else 1
					lastMerge = now
					round.score += 10 * (merge.tier + math.min(chain - 1, 9)) + (if merge.cleared then 100 else 0)
					field:observe(merge)
				end
				round:step(sim.eggs, Config.FixedStep, sim.drops)
				maxDanger = math.max(maxDanger, round.danger)
				if round.danger >= 0.1 then warningSeconds += Config.FixedStep end
				field:step(sim.eggs, Config.FixedStep, sim.drops, round.over)
				now += Config.FixedStep
			end
			assert(field.outcome, "Benchmark run did not terminate")
			local outcome = field.outcome
			row.wins += if outcome.success then 1 else 0
			row.nectar += outcome.reward
			row.seconds += now + resetSeconds
			row.score += round.score
			row.overflows += if round.over then 1 else 0
			row.threatenedRuns += if maxDanger >= 0.5 then 1 else 0
			row.warningSeconds += warningSeconds
			row.drops += sim.drops
			row.attempts += attempts
			row.maxHeight += outcome.maxHeight
			table.insert(results.samples, { seed = seed, strategy = strategy, success = outcome.success,
				reward = outcome.reward, seconds = now + resetSeconds, score = round.score,
					drops = sim.drops, attempts = attempts, height = outcome.maxHeight, rootStage = outcome.rootStage, overflow = round.over,
					maxDanger = maxDanger, warningSeconds = warningSeconds })
			if options.yieldEach ~= false then task.wait() end
		end
		row.completionRate = row.wins / count
		row.nectarPerMinute = row.nectar / row.seconds * 60
		row.meanScore, row.meanHeight, row.meanDrops = row.score / count, row.maxHeight / count, row.drops / count
		results.rows[strategy] = row
	end
	local heuristic, center = results.rows.heuristic, results.rows.center
	local spam = if results.rows.fastCenter.nectarPerMinute >= results.rows.fastRandom.nectarPerMinute
		then results.rows.fastCenter else results.rows.fastRandom
	results.spamStrategy = spam.strategy
	results.completionAdvantage = heuristic.completionRate - center.completionRate
	results.randomCompletionAdvantage = heuristic.completionRate - results.rows.random.completionRate
	results.rewardRateRatio = if spam.nectarPerMinute == 0 then (if heuristic.nectarPerMinute > 0 then "infinite" else 0)
		else heuristic.nectarPerMinute / spam.nectarPerMinute
	results.gatePassed = results.completionAdvantage >= 0.25 and heuristic.nectarPerMinute > 0
		and (spam.nectarPerMinute == 0 or heuristic.nectarPerMinute >= spam.nectarPerMinute * 1.5)
	return results
end

function Benchmark.spec(dependencies)
	local Simulation, FieldRun = dependencies.Simulation, dependencies.FieldRun
	local first = Simulation.new("Springy", 0, { seed = 123, starter = {}, kick = 6 })
	local second = Simulation.new("Springy", 0, { seed = 123, starter = {} })
	assert(#first.queue == 24 and #first.eggs == 0)
	for index = 1, 24 do assert(first.queue[index] == second.queue[index], "Seed queue changed") end
	for index = 1, 24, 6 do
		local one, two = 0, 0
		for slot = index, index + 5 do
			if first.queue[slot] == 1 then one += 1 elseif first.queue[slot] == 2 then two += 1 end
		end
		assert(one == 4 and two == 2, "Bag composition changed")
	end
	local field = FieldRun.new()
	local outside = FieldRun.ZoneBound + 0.1
	field:observe({ tier = 3, position = Vector2.new(outside, 0) })
	assert(field.rootStage == 0, "Right before left must not count")
	field:observe({ tier = 2, position = Vector2.new(-outside, 0) })
	assert(field.rootStage == 0, "Tier II must not count")
	field:observe({ tier = 3, position = Vector2.new(-outside, 0) })
	field:observe({ tier = 3, position = Vector2.new(outside, 0) })
	assert(field.rootStage == 2)
	assert(field:step({}, 1, 24, false) == nil and not field:canDrop(24))
	for _ = 1, 3 do assert(field:step({}, 1, 24, false) == nil) end
	local result = field:step({}, 1, 24, false)
	assert(result.success and result.reward == 8, "Settlement award missing")
	assert(field:step({}, 100, 24, true) == result, "Terminal result changed")
	local failed = FieldRun.new()
	failed:observe({ tier = 3, position = Vector2.new(-outside, 0) })
	failed:observe({ tier = 3, position = Vector2.new(outside, 0) })
	assert(failed:step({}, 0.01, 24, true).reward == 0, "Overflow must not award nectar")
	local gated = Simulation.new("Springy", 0, { seed = 123, starter = {}, contactGate = true })
	assert(Simulation.drop(gated, 0), "First drop blocked")
	assert(not Simulation.canDrop(gated), "Falling piece did not gate next drop")
	assert(not Simulation.drop(gated, 0.5) and gated.drops == 1, "Rejected drop consumed budget")
	local merged = {}
	for _ = 1, 6 do table.clear(merged) Simulation.step(gated, 1 / 120, merged) end
	assert(not Simulation.canDrop(gated), "Vertical wall contact must not open the gate")
	for _ = 1, 216 do
		if Simulation.canDrop(gated) then break end
		table.clear(merged) Simulation.step(gated, 1 / 120, merged)
	end
	assert(Simulation.canDrop(gated) and gated.dropAge > 0.35, "First physical contact never opened the gate")
	local legacy = Simulation.new("Springy", 0, { starter = {} })
	Simulation.drop(legacy, 0.5)
	assert(Simulation.canDrop(legacy), "Legacy drop behavior changed")
	local Round = dependencies.Round
	local pressure = Round.new(FieldRun.roundOptions())
	local line = pressure.overflowY
	local piece = { position = Vector2.new(0, line + 0.5), radius = 0.7 }
	pressure:step({piece}, 0.5, 12)
	assert(pressure.overflowTime == 0 and not pressure.over, "Fresh airborne drop starts danger")
	piece.roundAge = 2
	pressure:step({piece}, 1, 12)
	assert(not pressure.over and pressure.danger > 0, "Warning grace missing")
	piece.position = Vector2.new(0, line - 1)
	pressure:step({piece}, 0.1, 12)
	assert(pressure.overflowTime == 0 and not pressure.over, "Rescue merge cannot cancel danger")
	piece.position = Vector2.new(0, line + 0.5)
	pressure:step({piece}, pressure.grace - 0.01, 12)
	assert(not pressure.over, "Overflow grace shortened")
	pressure:step({piece}, 0.02, 12)
	assert(pressure.over, "Persistent pile cannot overflow")
	local early = Round.new(FieldRun.roundOptions())
	local jam = { position = Vector2.new(0, dependencies.Config.SpawnY), radius = 0.7, roundAge = 2 }
	early:step({jam}, early.grace + 0.01, 4)
	assert(early.over, "Early spawn blockage can deadlock a run")
	local legacyRound = Round.new()
	assert(legacyRound.overflowY == dependencies.Config.OverflowY and legacyRound.grace == dependencies.Config.OverflowGrace,
		"Field pressure changed the welcome board")
	return "FieldRun bags, ordered roots, settlement, readiness, overflow rescue/grace and early spawn-jam recovery passed"
end

return Benchmark
