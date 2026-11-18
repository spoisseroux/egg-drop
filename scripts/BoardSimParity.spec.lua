-- Studio Server (B0 of the client-run board, artifacts/qa-2026-11-17-v887/B0-plan.md).
-- Plays SimCheck's three input logs through the live BoardSimulation (Vector2, float32) and the
-- new shared BoardSim (doubles) and reports how close the rounds are: merges, score (the server's
-- chain rule and Config.mergeScore), final balls, accepted drops, max tier, bursts, plus the tick
-- where the two first drift apart by 0.01 studs. Exact equality is NOT expected: Vector2 rounds
-- every step to float32, so chaotic contacts diverge; the rules and the feel must match.
-- Copy to src/server/ZZSpecs/BoardSimParity.lua.
-- Usage: require(ServerScriptService.Server.ZZSpecs.BoardSimParity)(ServerScriptService.Server)
return function(server)
	local Shared = game:GetService("ReplicatedStorage").Shared
	local Old = require(server.BoardSimulation)
	local Sim = require(Shared.BoardSim)
	local Check = require(Shared.SimCheck)
	local Config = require(Shared.BoardConfig)

	local function scorer()
		local s = { playTime = 0, lastMerge = -math.huge, chain = 0, score = 0, merges = 0, maxTier = 0, bursts = 0, chainPeak = 0 }
		function s.step(merged, bursts)
			s.playTime += Config.FixedStep
			for _, merge in ipairs(merged) do
				s.chain = if s.playTime - s.lastMerge <= 1.25 then s.chain + 1 else 1
				s.chainPeak = math.max(s.chainPeak, s.chain)
				s.lastMerge = s.playTime
				s.merges += 1
				s.maxTier = math.max(s.maxTier, merge.tier)
				s.score += Config.mergeScore(merge.tier, s.chain, merge.cleared)
			end
			if bursts then s.bursts += #bursts end
		end
		return s
	end
	local function applyOld(board, input)
		if input.kind == "drop" then return Old.drop(board, input.aim)
		elseif input.kind == "swap" then return Old.swapNext(board)
		elseif input.kind == "pop" then return Old.pop(board) ~= nil
		elseif input.kind == "arm" then
			if board.armed then return false end
			board.armed = input.item; return true
		end
		return false
	end

	local report = {}
	for logIndex, log in ipairs(Check.logs()) do
		local options = table.clone(log.options); options.seed = log.seed
		local old, new = Old.new(log.preset, 0, options), Sim.new(log.preset, 0, options)
		local so, sn = scorer(), scorer()
		local acceptedOld, acceptedNew, nextInput = 0, 0, 1
		local drift, firstMergeOld, firstMergeNew = nil, nil, nil
		local mergedOld, mergedNew = {}, {}
		for tick = 0, log.ticks - 1 do
			while log.inputs[nextInput] and log.inputs[nextInput].tick == tick do
				local input = log.inputs[nextInput]
				if applyOld(old, input) then acceptedOld += 1 end
				if Sim.apply(new, input) then acceptedNew += 1 end
				nextInput += 1
			end
			table.clear(mergedOld); table.clear(mergedNew)
			Old.step(old, Config.FixedStep, mergedOld, nil)
			Sim.step(new, mergedNew, nil)
			so.step(mergedOld, old.bursts); old.bursts = nil
			sn.step(mergedNew, new.bursts); new.bursts = nil
			if not firstMergeOld and #mergedOld > 0 then firstMergeOld = tick end
			if not firstMergeNew and #mergedNew > 0 then firstMergeNew = tick end
			if not drift then
				if #old.eggs ~= #new.eggs then drift = { tick = tick, why = "count" } else
					for index, egg in ipairs(old.eggs) do
						local other = new.eggs[index]
						if other.id ~= egg.id or math.abs(egg.position.X - other.x) > 0.01 or math.abs(egg.position.Y - other.y) > 0.01 then
							drift = { tick = tick, why = "ball " .. egg.id }; break
						end
					end
				end
			end
		end
		table.insert(report, {
			log = logIndex, preset = log.preset, ticks = log.ticks,
			old = { merges = so.merges, score = so.score, balls = #old.eggs, drops = old.drops, accepted = acceptedOld, maxTier = so.maxTier, bursts = so.bursts, chainPeak = so.chainPeak, firstMerge = firstMergeOld },
			new = { merges = sn.merges, score = sn.score, balls = #new.eggs, drops = new.drops, accepted = acceptedNew, maxTier = sn.maxTier, bursts = sn.bursts, chainPeak = sn.chainPeak, firstMerge = firstMergeNew },
			driftTick = drift and drift.tick, driftWhy = drift and drift.why,
		})
	end

	-- A single unobstructed drop per aim: how far apart float32 and doubles land after 0.5 s.
	local worst = 0
	for index = 0, Sim.AimSteps, 20 do
		local old = Old.new("Springy", 0, { starter = {} })
		local new = Sim.new("Springy", 0, { starter = {} })
		Old.drop(old, index / Sim.AimSteps); Sim.drop(new, index / Sim.AimSteps)
		for _ = 1, 60 do Old.step(old, Config.FixedStep, {}, nil); Sim.step(new) end
		local a, b = old.eggs[1], new.eggs[1]
		worst = math.max(worst, math.abs(a.position.X - b.x), math.abs(a.position.Y - b.y))
	end
	return { logs = report, singleDropWorstStuds = worst }
end
