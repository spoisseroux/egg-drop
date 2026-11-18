-- Client-run board B2 protocol (artifacts/qa-2026-11-17-v887/B2-plan.md), shared by the server
-- lockstep (src/server/ClientSimHost.lua) and the client driver (src/client/ClientRoundDriver.lua).
-- Pure: constants, the strict batch reader, the comparison hash and the reveal packets.
--
-- Wire (reliable RemoteEvent Remotes.BoardClientSim):
--   server -> client  ("start", {version, resetId, run, spec, queueLength, reveal})
--                     ("reveal", {resetId, run, from, tiers, stars})   drop indices from..from+#tiers-1
--                     ("ack", {resetId, run, n, tick})                 the last input n queued
--                     ("stop", {resetId, run, reason})
--   client -> server  {resetId, run, tick, inputs = {{n, tick, kind, aim?, item?}, ...}}
-- Every client message carries all unacked inputs (at most MaxBatchInputs); the server skips n it
-- already queued, so refusing any message never loses an honest client's input.
local Shared = script.Parent
local Config = require(Shared.BoardConfig)
local Sim = require(Shared.BoardSim)
local RoundSim = require(Shared.BoardRoundSim)

local L = {}
L.Version = 1
L.RemoteName = "BoardClientSim"
-- Simulation ticks per real second (Pace 1.3 / FixedStep 1/120 = 156).
L.TicksPerSecond = Config.Pace / Config.FixedStep
L.HeartbeatSeconds = 0.1
L.OverHeartbeatSeconds = 1
L.RateSlack = 1.05 -- the client may run at most 5% faster than wall time
L.LeadTicks = math.floor(1 * L.TicksPerSecond) -- steps may lead the wall-clock allowance by 1 s
L.StallSeconds = 3 -- no new reported tick this long while running = stalled (like a disconnect)
L.StallTicks = math.floor(3 * L.TicksPerSecond) -- the allowance never banks more than 3 s past the reports
L.AheadTicks = math.floor(3 * L.TicksPerSecond) -- a report beyond allowance + lead + 3 s is refused
L.SettleTakeoverSeconds = 3 -- stalled this long in Settling: the server finishes the settle itself
L.IdleSeconds = 300 -- stalled (not paused) this long in Board mode: the round ends (RoundSim.finish, pays 0)
L.PausedIdleSeconds = 1800 -- paused in Board mode this long: the same (a menu left open)
L.Reveal = 5 -- Next plus 4 more queue slots ahead of the drops
L.RevealQueued = 2 -- queued (received, not yet stepped) drops that also open the window
L.MaxBatchInputs = 16
L.MaxPending = 64 -- inputs queued on the server
L.MaxUnacked = 64 -- inputs the client keeps for resending
L.MessageRate, L.MessageBurst = 30, 60 -- client messages per second
L.MaxStepsPerFrame = 60 -- server steps per board per Heartbeat
L.Placeholder = 1 -- the tier the client holds for a queue slot not revealed yet

local KINDS = { drop = true, swap = true, pop = true, arm = true, pause = true, resume = true }
local INPUT_KEYS = { n = true, tick = true, kind = true, aim = true, item = true }
local PACKET_KEYS = { resetId = true, run = true, tick = true, inputs = true }

local function integer(n, minimum, maximum)
	return type(n) == "number" and n == n and n % 1 == 0 and n >= minimum and n <= maximum
end
L.integer = integer

-- Counts a table's keys, giving up past `limit` (an attacker's table can be large).
local function keyCount(value, limit)
	local count = 0
	for _ in pairs(value) do
		count += 1
		if count > limit then return count end
	end
	return count
end

local function readInput(input)
	if type(input) ~= "table" or keyCount(input, 5) > 5 then return nil end
	for key in pairs(input) do
		if not INPUT_KEYS[key] then return nil end
	end
	local n, tick, kind = input.n, input.tick, input.kind
	if not integer(n, 1, 2147483647) or not integer(tick, 0, RoundSim.MaxTicks) or type(kind) ~= "string" or not KINDS[kind] then
		return nil
	end
	local out = { n = n, tick = tick, kind = kind }
	if kind == "drop" then
		if not integer(input.aim, 0, Sim.AimSteps) or input.item ~= nil then return nil end
		out.aim = input.aim
	elseif kind == "arm" then
		if (input.item ~= "bomb" and input.item ~= "magnet") or input.aim ~= nil then return nil end
		out.item = input.item
	elseif input.aim ~= nil or input.item ~= nil then
		return nil
	end
	return out
end

-- A client message, checked for shape only (the server checks it against its round). Returns a
-- normalized copy {resetId, run, tick, inputs}, or nil plus a refusal reason. Never errors.
function L.readBatch(packet)
	if type(packet) ~= "table" or keyCount(packet, 4) > 4 then return nil, "Malformed" end
	for key in pairs(packet) do
		if not PACKET_KEYS[key] then return nil, "Malformed" end
	end
	local resetId, run, tick, inputs = packet.resetId, packet.run, packet.tick, packet.inputs
	if not integer(resetId, 0, 2 ^ 30) or not integer(run, 0, 2147483647) or not integer(tick, 0, RoundSim.MaxTicks) then
		return nil, "Malformed"
	end
	local out = { resetId = resetId, run = run, tick = tick, inputs = {} }
	if inputs == nil then return out end
	if type(inputs) ~= "table" then return nil, "Malformed" end
	local count = keyCount(inputs, L.MaxBatchInputs + 1)
	if count > L.MaxBatchInputs then return nil, "Size" end
	if #inputs ~= count then return nil, "Malformed" end
	local lastN, lastTick = 0, 0
	for index = 1, count do
		local input = readInput(inputs[index])
		if not input then return nil, "Malformed" end
		if input.n <= lastN or input.tick < lastTick then return nil, "Order" end
		if input.tick > tick then return nil, "Future" end
		lastN, lastTick = input.n, input.tick
		out.inputs[index] = input
	end
	return out
end

-- The comparison hash (server and client): BoardRoundSim's hash with every queue slot after the
-- drops so far masked (Placeholder, no star). Those slots are the only state the two hosts may
-- legitimately differ in (the client learns them a few ahead); the mask depends on host state only.
function L.hash(host)
	local board = host.board
	local queue, stars = board.queue, board.stars
	local first = board.drops + 1
	local saved = {}
	for slot = first, #queue do
		saved[slot] = { queue[slot], stars and stars[slot] }
		queue[slot] = L.Placeholder
		if stars then stars[slot] = false end
	end
	local ok, hash = pcall(RoundSim.hash, host)
	for slot = first, #queue do
		queue[slot] = saved[slot][1]
		if stars then stars[slot] = saved[slot][2] end
	end
	if not ok then error(hash) end
	return hash
end

-- Drop indices [from, to) of the host's queue as a reveal packet body (never past the queue end).
function L.revealSlice(host, from, to)
	local board = host.board
	local n = #board.queue
	to = math.min(to, n)
	local tiers, stars = {}, {}
	for index = from, to - 1 do
		local slot = index + 1
		table.insert(tiers, board.queue[slot])
		table.insert(stars, board.stars and board.stars[slot] or false)
	end
	return { from = from, tiers = tiers, stars = stars }
end

-- Client: the round spec from the start packet. Unknown queue slots hold Placeholder.
function L.clientSpec(packet)
	if type(packet) ~= "table" or type(packet.spec) ~= "table" or not integer(packet.queueLength, 1, RoundSim.MaxQueue) then
		return nil, "Start"
	end
	local spec = table.clone(packet.spec)
	spec.queue = table.create(packet.queueLength, L.Placeholder)
	spec.stars = table.create(packet.queueLength, false)
	return spec
end

-- Client: writes a reveal into the host's queue. Returns the new revealed count.
function L.applyReveal(host, revealed, reveal)
	if type(reveal) ~= "table" or not integer(reveal.from, 0, RoundSim.MaxQueue) or type(reveal.tiers) ~= "table" then
		return revealed
	end
	local board = host.board
	local n = #board.queue
	for k, tier in ipairs(reveal.tiers) do
		local index = reveal.from + k - 1
		-- Only slots not consumed yet: a consumed slot's star is already spent on both sides.
		if index >= board.drops and index < n and integer(tier, 1, #Config.Tiers) then
			local slot = index + 1
			board.queue[slot] = tier
			local star = type(reveal.stars) == "table" and reveal.stars[k] or false
			if board.stars then board.stars[slot] = if type(star) == "string" then star else false end
		end
	end
	return math.max(revealed, math.min(n, reveal.from + #reveal.tiers))
end

return table.freeze(L)
