-- Studio Server (B1 of the client-run board, artifacts/qa-2026-11-17-v887/B1-plan.md).
-- Replays live field rounds recorded by src/server/RoundRecorder.lua through the shared round
-- host (BoardRoundSim) and compares three runs of each log:
--   live      what today's server path did (BoardSimulation, Vector2 float32, os.clock interval);
--   reference today's rule code (BoardRound, FieldRun, BoardItems.request/grant and the Heartbeat
--             merge loop, copied below) stepped on a BoardSim board (doubles);
--   host      BoardRoundSim on the same log.
--   old       the same rule code on today's BoardSimulation (Vector2): must equal live, which
--             proves the recorded log captured the round (ticks, aims, items, pauses).
-- reference vs host must agree exactly (same physics, so any difference is a rule bug).
-- live vs host differ only by float32 drift and the wall-clock interval; reported, not asserted.
-- The drop interval: live used os.clock (0.2 real s); the host counts 31 ticks. The comparisons
-- run with the interval off (intervalTicks 0) and separately count recorded gaps under 31 ticks.
-- Copy to src/server/ZZSpecs/BoardRoundParity.lua.
-- Usage: require(ServerScriptService.Server.ZZSpecs.BoardRoundParity)(ServerScriptService.Server [, records])
-- (records default: ServerStorage.EggDropRoundRecorder:Invoke("take"), finished rounds only).
return function(server, records)
	local Shared = game:GetService("ReplicatedStorage").Shared
	local Config = require(Shared.BoardConfig)
	local Sim = require(Shared.BoardSim)
	local RoundSim = require(Shared.BoardRoundSim)
	local Round = require(server.BoardRound)
	local FieldRun = require(server.FieldRun)
	local BoardItems = require(server.BoardItems)
	records = records or game:GetService("ServerStorage").EggDropRoundRecorder:Invoke("take")

	-- The host's tick constants against the server modules they replace.
	assert(RoundSim.SettleTicks == RoundSim.accumulatedTicks(FieldRun.SettleSeconds), "settle ticks")
	assert(RoundSim.Budget == FieldRun.Budget, "budget")

	-- Today's rules (the Heartbeat loop and acceptedDrop, init.server.lua) on BoardSim physics,
	-- or with `old` on today's BoardSimulation itself (Vector2): that run must equal the live
	-- recording, which proves the log (ticks, aims, items, pauses) captured the round.
	local Old = require(server.BoardSimulation)
	local function reference(spec, inputs, endTick, intervalTicks, old)
		local sim
		if old then
			sim = Old.new(spec.preset, spec.serial, { contactGate = spec.contactGate, kick = spec.kick, bounce = spec.bounce, starter = spec.starter })
			sim.queue = table.clone(spec.queue)
			sim.stars = {}
			for slot, star in ipairs(spec.stars) do if star then sim.stars[slot] = star end end
		else
			sim = Sim.new(spec.preset, spec.serial, { queue = spec.queue, stars = spec.stars, contactGate = spec.contactGate,
				kick = spec.kick, bounce = spec.bounce, starter = spec.starter })
		end
		local board = {
			mode = "Board", menuPaused = false, merges = 0, chain = 0, peakChain = 0, lastMerge = -math.huge,
			playTime = 0, maxTier = 0, itemKinds = 0, lastDropTick = nil, sim = sim,
			field = FieldRun.new({ descriptor = spec.descriptor, sequence = 1, heat = spec.heat }),
			round = Round.new(FieldRun.roundOptions(spec.heat)),
		}
		BoardItems.reset(board, spec.itemsOn)
		local tick = 0
		local merges, accepted, refused, overTick = {}, 0, 0, nil
		local function step()
			board.playTime += Config.FixedStep
			local merged = {}
			if old then
				Old.step(sim, Config.FixedStep, merged, nil)
			else
				Sim.step(sim, merged, nil)
				for _, egg in ipairs(sim.eggs) do egg.position = Vector2.new(egg.x, egg.y) end
			end
			tick += 1
			board.round:step(sim.eggs, Config.FixedStep, sim.drops)
			for _, merge in ipairs(merged) do
				if not old then merge.position = Vector2.new(merge.x, merge.y) end
				board.chain = if board.playTime - board.lastMerge <= 1.25 then board.chain + 1 else 1
				board.peakChain = math.max(board.peakChain, board.chain)
				board.maxTier = math.max(board.maxTier or 0, merge.tier)
				board.lastMerge = board.playTime
				board.merges += 1
				if merge.cleared then board.round.maxClears += 1 end
				board.round.score += Config.mergeScore(merge.tier, board.chain, merge.cleared)
				board.field:observe(merge, { sequence = 1, ordinal = board.merges, chain = board.chain, playTime = board.playTime })
				table.insert(merges, { tick = tick, tier = merge.tier, chain = board.chain, cleared = merge.cleared, score = board.round.score })
				for _, id in ipairs(merge.powerUps or {}) do BoardItems.grant(board, id) end
			end
			sim.bursts = nil
			board.field:expireChain(board.playTime, board.lastMerge)
			local result = board.field:step(sim.eggs, Config.FixedStep, sim.drops, board.round.over)
			if result then board.round.over = true; overTick = tick end
		end
		local function apply(input)
			local kind = input.kind
			if kind == "pause" or kind == "resume" then
				local paused = kind == "pause"
				if board.menuPaused == paused then return false end
				board.menuPaused = paused
				return true
			elseif kind == "drop" then
				local canDrop = if old then Old.canDrop(sim) else Sim.canDrop(sim)
				if board.menuPaused or board.round.over or not board.field:canDrop(sim.drops) or not canDrop
					or (board.lastDropTick and tick - board.lastDropTick < intervalTicks) then return false end
				board.lastDropTick = tick
				if old then return Old.drop(sim, input.rawAim or input.aim / Sim.AimSteps) end
				return Sim.drop(sim, input.aim / Sim.AimSteps)
			end
			local id = if kind == "arm" then input.item else kind
			local ok = BoardItems.request(board, { resetId = 1, seq = board.itemSeq, id = id },
				{ resetId = 1, ready = true, budget = board.field.budget })
			if ok then board.itemKinds = bit32.bor(board.itemKinds, 2 ^ (table.find({ "swap", "pop", "bomb", "magnet" }, id) - 1)) end
			return ok
		end
		for _, input in ipairs(inputs) do
			if not old then
				-- Pop picks its target by position: BoardItems uses BoardSimulation.popTarget (Vector2).
				for _, egg in ipairs(sim.eggs) do egg.position = Vector2.new(egg.x, egg.y) end
			end
			while tick < math.min(input.tick, endTick) and not board.round.over and not board.menuPaused do step() end
			if input.tick == tick and apply(input) then accepted += 1 else refused += 1 end
		end
		while tick < endTick and not board.round.over and not board.menuPaused do step() end
		local outcome = board.field.outcome
		return {
			merges = merges, accepted = accepted, refused = refused,
			result = { over = board.round.over, overTick = overTick, success = outcome ~= nil and outcome.success,
				reward = if outcome then outcome.reward else 0, reason = outcome and outcome.reason,
				goalsMet = board.field.rootStage, score = board.round.score, peakChain = board.peakChain,
				clears = board.round.maxClears, drops = sim.drops, merges = board.merges, maxTier = board.maxTier,
				itemsUsed = board.itemSeq, itemKinds = board.itemKinds },
		}
	end

	local keys = { "over", "overTick", "success", "reward", "reason", "goalsMet", "score", "peakChain", "clears",
		"drops", "merges", "maxTier", "itemsUsed", "itemKinds" }
	local outcomeKeys = { "success", "reward", "goalsMet", "reason" }
	local function diffs(a, b, list)
		local out = {}
		for _, key in ipairs(list or keys) do
			if a[key] ~= b[key] then table.insert(out, key .. " " .. tostring(a[key]) .. "/" .. tostring(b[key])) end
		end
		return out
	end
	local function firstMergeDiff(a, b, withTick)
		for index = 1, math.max(#a, #b) do
			local x, y = a[index], b[index]
			if not x or not y or x.tier ~= y.tier or x.chain ~= y.chain or (withTick and x.tick ~= y.tick) then return index end
		end
		return nil
	end

	local report = { rounds = {}, summary = {} }
	local totals = { rounds = 0, refExact = 0, liveExact = 0, liveOutcome = 0, liveScore = 0, liveMerges = 0, shortGaps = 0,
		hostInterval31Refused = 0, offGrid = 0, oldExact = 0, specSame = 0 }
	for index, record in ipairs(records) do
		if not record.result or #record.inputs == 0 then continue end
		totals.rounds += 1
		local spec, inputs, live = record.spec, record.inputs, record.result
		local endTick = live.overTick + 2400
		local host = assert(RoundSim.replay(spec, inputs, { intervalTicks = 0, endTick = endTick }))
		local ref = reference(spec, inputs, endTick, 0)
		local host31 = assert(RoundSim.replay(spec, inputs, { endTick = endTick }))
		local hostMerges = {}
		for _, merge in ipairs(host.merges) do
			table.insert(hostMerges, { tick = merge.tick, tier = merge.tier, chain = merge.chain, cleared = merge.cleared })
		end
		local refDiff = diffs(ref.result, host.result)
		local refMerge = firstMergeDiff(ref.merges, hostMerges, true)
		local exactRef = #refDiff == 0 and refMerge == nil and ref.accepted == host.accepted
		if exactRef then totals.refExact += 1 end
		-- The server's own spec builder must give the spec the recorder read off the live board.
		local built = RoundSim.fieldSpec(spec.preset, spec.serial, spec.descriptor, spec.heat, spec.itemsOn)
		local specSame = built.kick == spec.kick and built.bounce == spec.bounce and built.contactGate == spec.contactGate
			and built.budget == spec.budget and built.bonusHeight == spec.bonusHeight and #built.queue == #spec.queue
		for slot = 1, #spec.queue do
			if built.queue[slot] ~= spec.queue[slot] or built.stars[slot] ~= spec.stars[slot] then specSame = false end
		end
		if specSame then totals.specSame += 1 end
		local replayOld = reference(spec, inputs, endTick, 0, true)
		local oldDiff = diffs(live, replayOld.result)
		local oldMerge = firstMergeDiff(record.merges, replayOld.merges, true)
		if #oldDiff == 0 and oldMerge == nil then totals.oldExact += 1 end
		local liveDiff = diffs(live, host.result)
		local liveMerge = firstMergeDiff(record.merges, hostMerges, true)
		if #liveDiff == 0 and liveMerge == nil then totals.liveExact += 1 end
		if #diffs(live, host.result, outcomeKeys) == 0 then totals.liveOutcome += 1 end
		if live.score == host.result.score then totals.liveScore += 1 end
		if live.merges == host.result.merges then totals.liveMerges += 1 end
		local shortGaps, lastDrop = 0, nil
		for _, input in ipairs(inputs) do
			if input.kind == "drop" then
				if lastDrop and input.tick - lastDrop < RoundSim.DropIntervalTicks then shortGaps += 1 end
				lastDrop = input.tick
			end
		end
		totals.shortGaps += shortGaps
		totals.hostInterval31Refused += host31.reasons.Interval or 0
		totals.offGrid += record.offGrid or 0
		-- The first tick where live and host merges part (a merge at a different tick or tier).
		local firstLiveTick = liveMerge and (record.merges[liveMerge] or hostMerges[liveMerge] or {}).tick
		table.insert(report.rounds, {
			index = index, heat = spec.heat, template = spec.descriptor.id, itemsOn = spec.itemsOn,
			inputs = #inputs, hostAccepted = host.accepted, hostRefused = host.refused, refAccepted = ref.accepted,
			refExact = exactRef, refDiff = table.concat(refDiff, "; "), refFirstMerge = refMerge,
			specSame = specSame, oldExact = #oldDiff == 0 and oldMerge == nil, oldDiff = table.concat(oldDiff, "; "), oldFirstMerge = oldMerge,
			live = string.format("score %d/%d merges %d/%d chain %d/%d goals %d/%d reward %d/%d over %s/%s items %d/%d",
				live.score, host.result.score, live.merges, host.result.merges, live.peakChain, host.result.peakChain,
				live.goalsMet, host.result.goalsMet, live.reward, host.result.reward, tostring(live.overTick),
				tostring(host.result.overTick), live.itemsUsed, host.result.itemsUsed),
			liveDiff = table.concat(liveDiff, "; "), liveFirstMerge = liveMerge, liveFirstMergeTick = firstLiveTick,
			shortGaps = shortGaps, interval31Refused = host31.reasons.Interval or 0,
			hostReasons = game:GetService("HttpService"):JSONEncode(host.reasons),
		})
	end
	report.summary = totals
	return report
end
