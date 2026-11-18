-- Studio-only round recorder (B1 of the client-run board, artifacts/qa-2026-11-17-v887/B1-plan.md).
-- Records each live field round as a BoardRoundSim spec plus the tick-stamped inputs the live
-- server accepted, and what today's path made of them (merges, score, chain, goals, round over),
-- so scripts/BoardRoundParity.spec.lua can replay the log through the round host and compare.
-- init.server.lua requires this only in Studio; it records only while the ServerStorage
-- attribute `RoundRecorder` is true. Round tick = board.simTick - the tick at reset (BoardNet S0:
-- one per fixed step), so pauses, Room mode and the nursery-save wait leave no gap.
-- ServerStorage.EggDropRoundRecorder:Invoke("take") returns the rounds (oldest first),
-- ("clear") forgets them.
local ServerStorage = game:GetService("ServerStorage")
local Shared = game:GetService("ReplicatedStorage").Shared
local Sim = require(Shared.BoardSim)
local Objectives = require(Shared.FieldObjectives)

local Recorder = {}
Recorder.MaxRounds = 32
local rounds = {}
local owners = setmetatable({}, { __mode = "kv" }) -- record -> board, for an unfinished round's tick

local function copy(value)
	if type(value) ~= "table" then return value end
	local result = {}
	for key, item in pairs(value) do result[key] = copy(item) end
	return result
end

local function tickOf(board, record)
	return (board.simTick or 0) - record.startTick
end

-- After reset(): a fresh field board. Welcome and non-field rounds are not recorded.
function Recorder.begin(board)
	board.roundRecord = nil
	if ServerStorage:GetAttribute("RoundRecorder") ~= true or not board.field or board.welcome or not board.sim.queue then return end
	local sim = board.sim
	local queue = table.clone(sim.queue)
	-- BoardSimulation keeps a sparse slot -> item map; the host takes a dense array (false = none).
	local stars = table.create(#queue, false)
	if sim.stars then
		for slot = 1, #queue do stars[slot] = sim.stars[slot] or false end
	end
	local options = Objectives.simulationOptions(board.field.descriptor, sim.preset, board.runHeat)
	local record = {
		sequence = board.runSequence, startTick = board.simTick or 0, n = 0,
		spec = {
			preset = sim.preset, serial = sim.serial, queue = queue, stars = stars,
			contactGate = sim.contactGate == true, kick = options.kick, bounce = options.bounce, starter = {},
			heat = board.runHeat, descriptor = copy(board.field.descriptor), itemsOn = board.itemsOn == true,
			budget = board.field.budget, bonusHeight = board.field.bonusHeight,
		},
		inputs = {}, merges = {}, bursts = 0, offGrid = 0,
	}
	board.roundRecord = record
	owners[record] = board
	table.insert(rounds, record)
	while #rounds > Recorder.MaxRounds do table.remove(rounds, 1) end
end

local function input(board, entry)
	local record = board.roundRecord
	if not record or record.result then return end
	record.n += 1
	entry.n, entry.tick = record.n, tickOf(board, record)
	table.insert(record.inputs, entry)
end

-- An accepted drop (the float aim the live board used, and its grid index for the host).
function Recorder.drop(board, aim)
	local record = board.roundRecord
	if not record or record.result then return end
	local index = Sim.aimIndex(aim)
	if index and index / Sim.AimSteps ~= aim then record.offGrid += 1 end
	input(board, { kind = "drop", aim = index, rawAim = aim })
end

-- An accepted item use (BoardItems.request said ok).
function Recorder.item(board, id)
	if id == "swap" or id == "pop" then input(board, { kind = id })
	else input(board, { kind = "arm", item = id }) end
end

function Recorder.pause(board, paused)
	input(board, { kind = if paused then "pause" else "resume" })
end

-- One merge after the live loop scored it.
function Recorder.merge(board, merge, chain)
	local record = board.roundRecord
	if not record or record.result then return end
	table.insert(record.merges, {
		tick = tickOf(board, record), tier = merge.tier, chain = chain, cleared = merge.cleared == true,
		x = merge.position.X, y = merge.position.Y, score = board.round.score,
		stars = if merge.powerUps then #merge.powerUps else 0,
	})
end

function Recorder.burst(board, count)
	local record = board.roundRecord
	if record and not record.result then record.bursts += count end
end

-- The field ended (FieldRun:step returned its outcome).
function Recorder.finish(board)
	local record = board.roundRecord
	if not record or record.result then return end
	local outcome = board.field.outcome
	record.result = {
		over = true, overTick = tickOf(board, record), success = outcome.success, reward = outcome.reward,
		reason = outcome.reason, goalsMet = outcome.rootStage, maxHeight = outcome.maxHeight,
		score = board.round.score, peakChain = board.peakChain, clears = board.round.maxClears,
		drops = board.sim.drops, merges = board.merges, maxTier = board.maxTier, itemsUsed = board.itemSeq,
		itemKinds = board.itemKinds, belt = table.concat(board.belt or {}, ","), balls = #board.sim.eggs,
	}
end

local hook = Instance.new("BindableFunction")
hook.Name = "EggDropRoundRecorder"
hook.OnInvoke = function(action)
	if action == "clear" then table.clear(rounds); return true end
	if action == "take" then
		local out = {}
		for _, record in ipairs(rounds) do
			local item = copy(record)
			local board = owners[record]
			-- Unfinished (live or abandoned) rounds: how far the live board got.
			if not record.result and board and board.roundRecord == record then item.endTick = tickOf(board, record) end
			table.insert(out, item)
		end
		return out
	end
	return nil
end
hook.Parent = ServerStorage

return Recorder
