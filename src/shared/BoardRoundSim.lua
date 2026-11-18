-- Round host (B1 of the client-run board, artifacts/qa-2026-11-17-v887/B1-plan.md). Owns one
-- BoardSim board plus everything beside it that changes play or rewards today: the item belt,
-- item uses and grants, the chain window, the score, the overflow grace, the field goals and
-- the round end. Pure and shared (server and client), plain data only (no metatables, no
-- closures), so snapshot/restore are deep copies and the whole state hashes.
--
-- Everything counts ticks (1 tick = Config.FixedStep = 1/120 simulation seconds). The host never
-- reads a clock; Config.Pace (simulation seconds per real second) belongs to the driver.
-- A round is reproducible from (spec, inputs): the spec carries the ball queue and star slots as
-- data (made once on the server, `plan`), never a seed. Inputs are {n, tick, kind, ...}, applied
-- after `tick` steps and before step tick+1. `apply` refuses (never errors on) bad inputs.
--
-- Rules and order are today's Heartbeat loop in src/server/init.server.lua (acceptedDrop, the
-- item request, Round:step, the merge loop, FieldRun observe/expireChain/step), with seconds
-- turned into ticks. Timers that today sum FixedStep into a float (overflow grace, the 1.4 s
-- warm-up, the 3 s settle) use the tick count at which that float sum first reaches the limit,
-- so they match today to the tick (grace 2.4 s = 289 ticks, not 288). Not used by the live game
-- yet (FeatureFlags.DeckClientSim). The Welcome round is not a host round.
local Shared = script.Parent
local Config = require(Shared.BoardConfig)
local Items = require(Shared.RoundItems)
local Objectives = require(Shared.FieldObjectives)
local Sim = require(Shared.BoardSim)

local RoundSim = {}
RoundSim.Version = 1

local FIXED = Config.FixedStep
local MAX_EGGS = Config.MaxEggs
local SPAWN_Y = Config.SpawnY
local TIER_COUNT = #Config.Tiers

-- The step count at which a float accumulator of FixedStep (today's `x += dt`) reaches `seconds`.
local function accumulatedTicks(seconds)
	local total, count = 0, 0
	while total < seconds do
		total += FIXED
		count += 1
	end
	return count
end
RoundSim.accumulatedTicks = accumulatedTicks

-- 0.2 real s x Pace 1.3 = 0.26 sim s = 31.2 ticks: 31 on purpose (an integer; one tick looser
-- than 0.26 s). Today's wall-clock check can admit fewer ticks when the server lags (the
-- 11-step cap per frame squeezes 0.2 real s); from B2 on, ticks decide.
RoundSim.DropIntervalTicks = math.floor(Config.DropInterval * Config.Pace / FIXED)
-- Chain window: today `playTime - lastMerge <= 1.25` on two running float sums of FixedStep.
-- At a 150-tick gap that difference lands on either side of 1.25 depending on the start tick,
-- so the host keeps the same two doubles (playTime, lastMergeTime) and the same comparison
-- (IEEE addition is exact and identical on every side). ChainTicks is the nominal window.
RoundSim.ChainSeconds = 1.25
RoundSim.ChainTicks = math.floor(RoundSim.ChainSeconds / FIXED + 0.5)
-- BoardRound: a ball counts for the overflow line once in play 1.4 s (or once in the tray).
RoundSim.WarmupTicks = accumulatedTicks(1.4)
-- FieldRun.SettleSeconds (3, simulation seconds) after the last drop.
RoundSim.SettleTicks = accumulatedTicks(3)
RoundSim.Budget = 24 -- FieldRun.Budget
RoundSim.WinReward, RoundSim.TidyBonus = 6, 2
RoundSim.ZoneEpsilon = 1e-6 -- FieldRun: inclusive zone edges
-- Bounds for untrusted logs (B2 replays the client's inputs).
RoundSim.MaxTicks = 120 * 600
RoundSim.MaxInputs = 512
RoundSim.MaxInputsPerTick = 16
RoundSim.MaxQueue = 64

local ITEM_CODE, ITEM_BIT = {}, {}
for index, id in ipairs(Items.Order) do
	ITEM_CODE[id] = index
	ITEM_BIT[id] = 2 ^ (index - 1) -- swap 1, pop 2, bomb 4, magnet 8 (Nursery.itemKindBit)
end
local PHASE_CODE = { Playing = 1, Settling = 2, Complete = 3 }
local GOAL_KINDS = { merge = true, count = true, chain = true }

local function integer(n, minimum, maximum)
	return type(n) == "number" and n == n and n % 1 == 0 and n >= minimum and n <= maximum
end
local function finite(n, minimum, maximum)
	return type(n) == "number" and n == n and n >= minimum and n <= maximum
end

local function copy(value)
	if type(value) ~= "table" then return value end
	local result = {}
	for key, item in pairs(value) do result[key] = copy(item) end
	return result
end

-- ── Round start ───────────────────────────────────────────────────────────

-- Server only: the ball queue and the star slots for a seed, the same streams as today's
-- BoardSimulation.new (4 shuffled bags; RoundItems.plan). Returned as data for the spec.
function RoundSim.plan(seed, bag, heat, itemsOn)
	local board = Sim.new(Config.DefaultPreset, 0, { seed = seed, bag = bag, starter = {},
		powerUps = if itemsOn then heat else nil })
	local stars = board.stars or table.create(#board.queue, false)
	return table.clone(board.queue), table.clone(stars)
end

-- Server only: a field round's spec, as reset() builds today's board (FieldObjectives options,
-- the run heat, items on/off). `serial` continues the previous board's ball ids.
function RoundSim.fieldSpec(preset, serial, descriptor, heat, itemsOn)
	local options = Objectives.simulationOptions(descriptor, preset, heat)
	local queue, stars = RoundSim.plan(options.seed, options.bag, heat, itemsOn)
	return {
		preset = preset, serial = serial or 0, queue = queue, stars = stars,
		contactGate = options.contactGate == true, kick = options.kick, bounce = options.bounce, starter = {},
		heat = Config.heat(heat).key, descriptor = copy(descriptor), itemsOn = itemsOn == true,
		budget = RoundSim.Budget, bonusHeight = Config.heat(heat).bonusHeight,
	}
end

-- What the client may see at round start (B2 reveals the tiers a few ahead, never the queue).
function RoundSim.publicSpec(spec)
	local public = copy(spec)
	public.queue, public.stars = nil, nil
	return public
end

local function validGoal(goal)
	if type(goal) ~= "table" or not GOAL_KINDS[goal.kind] or not integer(goal.target, 1, 10) then return false end
	if goal.tier ~= nil and not integer(goal.tier, 1, TIER_COUNT) then return false end
	if goal.minTier ~= nil and not integer(goal.minTier, 1, TIER_COUNT) then return false end
	local zone = goal.zone
	if type(zone) ~= "table" then return false end
	if zone.min ~= nil and not finite(zone.min, -100, 100) then return false end
	if zone.max ~= nil and not finite(zone.max, -100, 100) then return false end
	return true
end

-- Returns nil plus a reason for a spec the host cannot run.
function RoundSim.validSpec(spec)
	if type(spec) ~= "table" then return nil, "Spec" end
	if type(spec.preset) ~= "string" or not Config.Presets[spec.preset] then return nil, "Preset" end
	if not integer(spec.serial, 0, 2 ^ 30) then return nil, "Serial" end
	local queue = spec.queue
	if type(queue) ~= "table" or #queue < 1 or #queue > RoundSim.MaxQueue then return nil, "Queue" end
	for index = 1, #queue do
		if not integer(queue[index], 1, TIER_COUNT) then return nil, "Queue" end
	end
	if spec.stars ~= nil then
		if type(spec.stars) ~= "table" then return nil, "Stars" end
		for index = 1, #queue do
			local star = spec.stars[index]
			if star ~= false and not Items.valid(star) then return nil, "Stars" end
		end
	end
	if type(spec.contactGate) ~= "boolean" or not finite(spec.kick, 0, 50) or not finite(spec.bounce, 0, 2) then
		return nil, "Physics"
	end
	if type(spec.starter) ~= "table" or #spec.starter > 8 then return nil, "Starter" end
	for _, seed in ipairs(spec.starter) do
		if type(seed) ~= "table" or not finite(seed.x, -Config.Width / 2, Config.Width / 2)
			or not integer(seed.tier, 1, TIER_COUNT) then return nil, "Starter" end
	end
	if not Config.validHeat(spec.heat) then return nil, "Heat" end
	local descriptor = spec.descriptor
	if type(descriptor) ~= "table" or type(descriptor.title) ~= "string" or type(descriptor.id) ~= "string"
		or type(descriptor.goals) ~= "table" or #descriptor.goals < 1 or #descriptor.goals > 3 then return nil, "Field" end
	for _, goal in ipairs(descriptor.goals) do
		if not validGoal(goal) then return nil, "Goal" end
	end
	if type(spec.itemsOn) ~= "boolean" or not integer(spec.budget, 1, RoundSim.MaxQueue)
		or not finite(spec.bonusHeight, -100, 100) then return nil, "Field" end
	return true
end

-- options (trusted, never from a client): intervalTicks (the parity reference turns the
-- wall-clock interval off to compare rules alone).
function RoundSim.new(spec, options)
	local ok, reason = RoundSim.validSpec(spec)
	if not ok then return nil, reason end
	options = options or {}
	local board = Sim.new(spec.preset, spec.serial, {
		queue = spec.queue, stars = spec.stars or table.create(#spec.queue, false),
		contactGate = spec.contactGate, kick = spec.kick, bounce = spec.bounce, starter = spec.starter,
	})
	for _, egg in ipairs(board.eggs) do egg.bornTick, egg.enteredTray = 0, false end
	local heat = Config.heat(spec.heat)
	local goals = {}
	for index, goal in ipairs(spec.descriptor.goals) do
		goals[index] = {
			kind = goal.kind, tier = goal.tier, minTier = goal.minTier, target = goal.target,
			zoneMin = goal.zone.min, zoneMax = goal.zone.max,
		}
	end
	return {
		version = RoundSim.Version, board = board,
		heat = heat.key, templateId = spec.descriptor.id, title = spec.descriptor.title,
		-- FieldRun.roundOptions(heat): the line, its grace and when the meter arms.
		overflowY = heat.overflowY, graceTicks = accumulatedTicks(heat.grace), armAfter = heat.armAfter, warningMargin = 2,
		budget = spec.budget, bonusHeight = spec.bonusHeight, itemsOn = spec.itemsOn,
		intervalTicks = options.intervalTicks or RoundSim.DropIntervalTicks,
		goals = goals,
		-- Input bookkeeping.
		lastN = 0, inputCount = 0, tickInputsAt = -1, tickInputs = 0,
		paused = false, over = false, overTick = nil, outcome = nil,
		lastDropTick = nil,
		-- Items (BoardItems): belt, accepted uses, kinds used (bits).
		belt = {}, itemSeq = 0, itemKinds = 0,
		-- Score and chain (the Heartbeat merge loop).
		score = 0, merges = 0, chain = 0, peakChain = 0, lastMergeTick = nil, maxTier = 0, clears = 0,
		playTime = 0, lastMergeTime = nil, -- today's float clocks for the chain window (see ChainSeconds)
		-- Overflow (BoardRound). danger and settledHeight are presentation, outside the hash.
		overflowTicks = 0, danger = 0, settledHeight = 0,
		-- Field (FieldRun).
		phase = "Playing", stage = 0, progress = 0, chainIdentity = nil, settleTicks = 0,
	}
end

-- ── Inputs ───────────────────────────────────────────────────────────────

local function grant(host, id)
	if not host.itemsOn or not Items.valid(id) then return nil end
	if #host.belt >= Items.BeltSize then return "full" end
	table.insert(host.belt, id)
	return "granted"
end

-- BoardItems.request without the network checks (throttle, resetId, item seq).
local function useItem(host, id)
	local board = host.board
	if not host.itemsOn then return false, "Off" end
	if host.over or host.phase == "Complete" then return false, "NotLive" end
	local slot = table.find(host.belt, id)
	if not slot then return false, "NotOnBelt" end
	if board.armed then return false, "Armed" end
	local drops, result = board.drops, { id = id }
	if id == "swap" then
		-- Next and Then must both be inside the budget.
		if drops + 2 > host.budget or not Sim.swapNext(board) then return false, "Budget" end
	elseif id == "pop" then
		local target = Sim.pop(board)
		if not target then return false, "Empty" end
		result.eggId, result.x, result.y, result.lostStar = target.id, target.x, target.y, target.powerUp
	else
		-- Bomb and Magnet ride on the next ball, so one must still be coming.
		if drops + 1 > host.budget or host.phase ~= "Playing" or not Sim.arm(board, id) then return false, "Budget" end
	end
	table.remove(host.belt, slot)
	host.itemSeq += 1
	host.itemKinds = bit32.bor(host.itemKinds, ITEM_BIT[id])
	return true, result
end

-- acceptedDrop: the same checks in the same order (the interval latch is taken before the
-- spawn check, as today).
local function drop(host, aim, tick)
	local board = host.board
	if not integer(aim, 0, Sim.AimSteps) then return false, "Aim" end
	if host.paused then return false, "Paused" end
	if host.over then return false, "RoundOver" end
	if host.phase ~= "Playing" or board.drops >= host.budget then return false, "Budget" end
	if not Sim.canDrop(board) then return false, "Gate" end
	if host.lastDropTick and tick - host.lastDropTick < host.intervalTicks then return false, "Interval" end
	host.lastDropTick = tick
	if not Sim.drop(board, aim / Sim.AimSteps) then
		return false, if #board.eggs >= MAX_EGGS then "Full" else "Spawn"
	end
	local dropped = board.eggs[#board.eggs]
	dropped.bornTick, dropped.enteredTray = tick, false
	return true, { id = dropped.id, tier = dropped.tier, powerUp = dropped.powerUp, mark = dropped.mark }
end

-- One input. Returns true plus a result table, or false plus a reason. Never errors.
function RoundSim.apply(host, input)
	if type(input) ~= "table" then return false, "Malformed" end
	local n, tick, kind = input.n, input.tick, input.kind
	if not integer(n, 1, 2147483647) or not integer(tick, 0, 2147483647) or type(kind) ~= "string" then
		return false, "Malformed"
	end
	if n <= host.lastN then return false, "Duplicate" end
	local now = host.board.tick
	if tick < now then return false, "Late" end
	if tick > now then return false, "Early" end
	-- `resume` skips the caps: inputs after a pause share its tick, so refused taps there must
	-- never lock the board paused for good (code review 2026-11-17).
	if kind ~= "resume" then
		if host.inputCount >= RoundSim.MaxInputs then return false, "TooMany" end
		if host.tickInputsAt == tick and host.tickInputs >= RoundSim.MaxInputsPerTick then return false, "TooMany" end
	end
	if host.tickInputsAt ~= tick then host.tickInputsAt, host.tickInputs = tick, 0 end
	host.lastN = n
	host.inputCount += 1
	host.tickInputs += 1
	if kind == "drop" then return drop(host, input.aim, tick)
	elseif kind == "swap" then return useItem(host, "swap")
	elseif kind == "pop" then return useItem(host, "pop")
	elseif kind == "arm" then
		if input.item ~= "bomb" and input.item ~= "magnet" then return false, "Malformed" end
		return useItem(host, input.item)
	elseif kind == "pause" or kind == "resume" then
		local paused = kind == "pause"
		if host.over then return false, "RoundOver" end
		if host.paused == paused then return false, "Same" end
		host.paused = paused
		return true, {}
	end
	return false, "Malformed"
end

-- ── Step ─────────────────────────────────────────────────────────────────

-- Round:step in ticks (over is decided here and by the field below).
local function overflowRules(host, tick)
	local board = host.board
	local line = host.overflowY
	local overflowing, maximum, resting = false, 0, 0
	for _, egg in ipairs(board.eggs) do
		local age = tick - egg.bornTick
		local top = egg.y + egg.radius
		egg.enteredTray = egg.enteredTray or top < line
		-- Fresh airborne drops do not start the meter (BoardRound).
		if egg.enteredTray or age >= RoundSim.WarmupTicks then
			if top > maximum then maximum = top end
			if top >= line then overflowing = true end
			if (egg.hasContact or age >= RoundSim.WarmupTicks) and top > resting then resting = top end
		end
	end
	host.settledHeight = maximum
	local armed = board.drops >= host.armAfter or maximum >= SPAWN_Y - 1
	host.overflowTicks = if armed and overflowing then host.overflowTicks + 1 else 0
	local margin = host.warningMargin
	host.danger = if not armed then 0 else math.max(host.overflowTicks / host.graceTicks,
		math.clamp((resting - line + margin) / margin, 0, 0.85))
	if host.overflowTicks >= host.graceTicks or #board.eggs >= MAX_EGGS then host.over = true end
end

-- FieldRun:observe (ordinal = merges this round, so always rising).
local function observe(host, merge, ordinal, chain)
	local goal = host.goals[host.stage + 1]
	if host.phase == "Complete" or not goal then return false end
	if goal.kind == "merge" then
		if goal.tier and merge.tier ~= goal.tier or goal.minTier and merge.tier < goal.minTier then return false end
		local x, epsilon = merge.x, RoundSim.ZoneEpsilon
		if goal.zoneMin and x < goal.zoneMin - epsilon or goal.zoneMax and x > goal.zoneMax + epsilon then return false end
		host.progress += 1
	elseif goal.kind == "count" then
		host.progress += 1
	else
		local identity = ordinal - chain + 1
		host.progress = if identity == host.chainIdentity then host.progress + 1 else 1
		host.chainIdentity = identity
	end
	if host.progress >= goal.target then
		host.stage += 1
		host.progress, host.chainIdentity = 0, nil
	end
	return true
end

-- FieldRun:expireChain.
local function expireChain(host)
	local goal = host.goals[host.stage + 1]
	if goal and goal.kind == "chain" and host.progress > 0 and host.playTime - host.lastMergeTime > RoundSim.ChainSeconds then
		host.progress, host.chainIdentity = 0, nil
		return true
	end
	return false
end

-- FieldRun:step. Overflow ends the field at once; the budget starts the settle.
local function fieldStep(host, tick)
	if host.phase == "Complete" then return end
	local board = host.board
	local overflow = host.over
	if overflow then
		host.phase = "Complete"
	elseif board.drops >= host.budget then
		if host.phase ~= "Settling" then
			host.phase, host.settleTicks = "Settling", 0
		else
			host.settleTicks += 1
		end
		if host.settleTicks >= RoundSim.SettleTicks then host.phase = "Complete" end
	end
	if host.phase ~= "Complete" then return end
	local maxHeight = 0
	for _, egg in ipairs(board.eggs) do
		local top = egg.y + egg.radius
		if top > maxHeight then maxHeight = top end
	end
	local success = not overflow and host.stage == #host.goals
	local reward = if success then RoundSim.WinReward + (if maxHeight <= host.bonusHeight then RoundSim.TidyBonus else 0) else 0
	host.outcome = {
		success = success, reward = reward, rootStage = host.stage, maxHeight = maxHeight,
		reason = if overflow then "Overflow" elseif success then host.title .. " complete" else host.title .. " incomplete",
	}
	host.over, host.overTick = true, tick
end

-- B2 timeout (B2-plan.md): the server ends a round that never ends (no progress for
-- BoardLockstep.IdleSeconds in Board mode while drops are left). Never a win: success false,
-- reward 0, so stalling can never trade the overflow risk for a payout. Returns false when over.
function RoundSim.finish(host)
	if host.over then return false end
	local maxHeight = 0
	for _, egg in ipairs(host.board.eggs) do
		local top = egg.y + egg.radius
		if top > maxHeight then maxHeight = top end
	end
	host.phase = "Complete"
	host.outcome = { success = false, reward = 0, rootStage = host.stage, maxHeight = maxHeight,
		reason = host.title .. " incomplete", timedOut = true }
	host.over, host.overTick = true, host.board.tick
	return true
end

-- One fixed step. Returns nil while paused or over, else an events table:
-- { tick, merges = {merge records + tick, chain, points, observed, grants}, bursts, over }.
-- Merge records are BoardSim's (x, y, tier, id, firstId, secondId, cleared, powerUps, ...).
-- `impacts` (optional, B3 presentation): receives BoardSim's strongest impact per ball id this
-- step. Write-only: it never feeds back into the state or the hash.
function RoundSim.step(host, impacts)
	if host.paused or host.over then return nil end
	local board = host.board
	local before = board.tick
	host.playTime += FIXED
	local merged = Sim.step(board, {}, impacts)
	local tick = board.tick
	-- Balls made during this step (merge results) start their age here.
	for _, egg in ipairs(board.eggs) do
		if egg.bornTick == nil then egg.bornTick, egg.enteredTray = before, false end
	end
	overflowRules(host, tick)
	for _, merge in ipairs(merged) do
		host.chain = if host.lastMergeTime and host.playTime - host.lastMergeTime <= RoundSim.ChainSeconds then host.chain + 1 else 1
		if host.chain > host.peakChain then host.peakChain = host.chain end
		if merge.tier > host.maxTier then host.maxTier = merge.tier end
		host.lastMergeTick, host.lastMergeTime = tick, host.playTime
		host.merges += 1
		if merge.cleared then host.clears += 1 end
		local points = Config.mergeScore(merge.tier, host.chain, merge.cleared)
		host.score += points
		merge.tick, merge.chain, merge.points = tick, host.chain, points
		merge.observed = observe(host, merge, host.merges, host.chain)
		if merge.powerUps then
			merge.grants = {}
			for _, id in ipairs(merge.powerUps) do
				local granted = grant(host, id)
				if granted then table.insert(merge.grants, { id = id, kind = granted }) end
			end
		end
	end
	-- Bomb bursts happen inside the step, outside the merges: nothing scores.
	local bursts = board.bursts
	board.bursts = nil
	expireChain(host)
	fieldStep(host, tick)
	return { tick = tick, merges = merged, bursts = bursts, over = host.over }
end

-- ── Result, hash, snapshot, replay ───────────────────────────────────────

-- The round's payout inputs (settleReward's summary and Nursery.award's amount); family, day
-- and boost stay on the server. PocketTrials only ORs thresholds on chain, score and clears,
-- which only rise, so the final peaks are enough.
function RoundSim.result(host)
	local outcome = host.outcome
	return {
		over = host.over, overTick = host.overTick, ticks = host.board.tick,
		success = outcome ~= nil and outcome.success, reward = if outcome then outcome.reward else 0,
		tidy = outcome ~= nil and outcome.success and outcome.reward == RoundSim.WinReward + RoundSim.TidyBonus,
		reason = outcome and outcome.reason, goalsMet = host.stage, maxHeight = outcome and outcome.maxHeight,
		score = host.score, peakChain = host.peakChain, clears = host.clears, drops = host.board.drops,
		merges = host.merges, maxTier = host.maxTier, itemsUsed = host.itemSeq, itemKinds = host.itemKinds,
		heat = host.heat, templateId = host.templateId, phase = host.phase,
	}
end

local function flag(value) return if value then 1 else 0 end

-- BoardSim's canonical bytes plus every host field that decides play or rewards.
function RoundSim.encode(host)
	local board = host.board
	local parts = { Sim.encode(board) }
	table.insert(parts, string.pack("<i4i4i4i4i4BBBB", host.version, host.lastN, host.inputCount,
		host.tickInputsAt, host.tickInputs, flag(host.paused), flag(host.over), PHASE_CODE[host.phase] or 0, flag(host.itemsOn)))
	table.insert(parts, string.pack("<i4i4i4i4i4i4i4i4i4i4i4",
		host.lastDropTick or -1, host.intervalTicks, host.itemSeq, host.itemKinds, host.score, host.merges,
		host.chain, host.peakChain, host.lastMergeTick or -1, host.maxTier, host.clears))
	table.insert(parts, string.pack("<i4i4i4i4i4i4i4i4i4i4", host.overflowTicks, host.graceTicks, host.armAfter,
		host.budget, host.stage, host.progress, host.chainIdentity or -1, host.settleTicks, host.overTick or -1, #host.goals))
	table.insert(parts, string.pack("<dddBd", host.overflowY, host.warningMargin, host.bonusHeight,
		flag(host.lastMergeTime), host.lastMergeTime or 0))
	table.insert(parts, string.pack("<d", host.playTime))
	table.insert(parts, string.pack("<B", #host.belt))
	for _, id in ipairs(host.belt) do table.insert(parts, string.pack("<B", ITEM_CODE[id] or 255)) end
	table.insert(parts, string.pack("<i4", #board.eggs))
	for _, egg in ipairs(board.eggs) do
		table.insert(parts, string.pack("<i4i4B", egg.id, egg.bornTick or -1, flag(egg.enteredTray)))
	end
	return table.concat(parts)
end

function RoundSim.hash(host)
	return Sim.hashBytes(RoundSim.encode(host))
end

function RoundSim.snapshot(host) return copy(host) end
function RoundSim.restore(snapshot) return copy(snapshot) end

-- Replays (spec, inputs) from a fresh host. inputs must be ordered (n rising, tick
-- non-decreasing); anything else is refused, never asserted. Steps to the round end, to
-- options.endTick, or to options.maxTicks (capped at RoundSim.MaxTicks), whichever is first.
-- options: hashEvery (60), endTick, maxTicks, intervalTicks, onStep(host, events),
-- yieldEvery + yield. Returns nil, reason for a bad spec, else
-- { host, hashes, final, merges = {...}, bursts, accepted, refused, reasons = {reason=count},
--   refusals = {{index, n, tick, kind, reason}}, result }.
function RoundSim.replay(spec, inputs, options)
	options = options or {}
	local host, why = RoundSim.new(spec, { intervalTicks = options.intervalTicks })
	if not host then return nil, why end
	if type(inputs) ~= "table" then return nil, "Inputs" end
	local maxTicks = math.min(if integer(options.maxTicks, 0, RoundSim.MaxTicks) then options.maxTicks else RoundSim.MaxTicks, RoundSim.MaxTicks)
	local endTick = if integer(options.endTick, 0, maxTicks) then options.endTick else maxTicks
	local hashEvery = options.hashEvery or 60
	local out = { host = host, hashes = {}, merges = {}, bursts = 0, accepted = 0, refused = 0, reasons = {}, refusals = {} }
	local board = host.board
	local function advance(target)
		while board.tick < target and not host.over and not host.paused do
			local events = RoundSim.step(host)
			if not events then break end
			for _, merge in ipairs(events.merges) do table.insert(out.merges, merge) end
			if events.bursts then out.bursts += #events.bursts end
			if options.onStep then options.onStep(host, events) end
			if board.tick % hashEvery == 0 then table.insert(out.hashes, RoundSim.hash(host)) end
			if options.yield and options.yieldEvery and board.tick % options.yieldEvery == 0 then options.yield() end
		end
	end
	for index, input in ipairs(inputs) do
		if index > RoundSim.MaxInputs then
			out.reasons.TooMany = (out.reasons.TooMany or 0) + (#inputs - RoundSim.MaxInputs)
			out.refused += #inputs - RoundSim.MaxInputs
			break
		end
		local tick = type(input) == "table" and input.tick
		if integer(tick, 0, 2147483647) then advance(math.min(tick, endTick)) end
		local ok, reason = RoundSim.apply(host, input)
		if ok then out.accepted += 1 else
			out.refused += 1
			out.reasons[reason] = (out.reasons[reason] or 0) + 1
			if #out.refusals < 64 then
				table.insert(out.refusals, { index = index, n = type(input) == "table" and input.n or nil,
					tick = if integer(tick, 0, 2147483647) then tick else nil, kind = type(input) == "table" and type(input.kind) == "string" and input.kind or nil, reason = reason })
			end
		end
	end
	advance(endTick)
	out.final = RoundSim.hash(host)
	out.result = RoundSim.result(host)
	return out
end

return table.freeze(RoundSim)
