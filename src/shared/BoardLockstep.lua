-- Client-run board B2 protocol (artifacts/qa-2026-11-17-v887/B2-plan.md), shared by the server
-- lockstep (src/server/ClientSimHost.lua) and the client driver (src/client/ClientRoundDriver.lua).
-- Pure: constants, the strict batch reader, the comparison hash and the reveal packets.
--
-- Wire (reliable RemoteEvent Remotes.BoardClientSim):
--   server -> client  ("start", {version, resetId, run, spec, queueLength, reveal})
--                     ("reveal", {resetId, run, from, tiers, stars})   drop indices from..from+#tiers-1
--                     ("ack", {resetId, run, n, tick})                 the last input n queued
--                     ("stop", {resetId, run, reason})
--                     ("hash", {resetId, run, tick, hash, over?})     B4: checkpoint every HashTicks, and the round end
--                     ("state", {resetId, run, tick, hash, n, revealed, join?, pending?, data})  B4: full host state
--   client -> server  {resetId, run, tick, inputs = {{n, tick, kind, aim?, item?}, ...}, want?, over?}
--                     {join = resetId, run}                             B4: no round for the open session
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
-- B3: no accepted client message this long after the start (host still at tick 0, nothing queued):
-- the server plays the round on today's path (a client whose driver or mirror cannot start).
L.HelloSeconds = 5
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
-- B4 verify / rollback / rejoin (artifacts/qa-2026-11-17-v887/B4-plan.md).
L.HashTicks = 32 -- checkpoint hash every 32 ticks (0.205 s)
L.RingTicks = math.floor(3 * L.TicksPerSecond) -- the client keeps 3 s of checkpoint hashes
L.ResyncSeconds = 1 -- at most one full state a second per round
L.MaxResyncs = 3 -- a round that needs a 4th full state falls back to the server-run path
L.WantRetrySeconds = 2 -- the client asks again when no state came for this long (a want refused for Rate)
L.LateInputSeconds = 2 -- server-run: the client's inputs made before it saw the stop count this long
L.ReplayStepsPerFrame = 48 -- replay steps per client Heartbeat (a long replay never hitches one frame)
L.MaxCorrection = 0.5 -- studs a drawn ball may be eased per frame after a rollback
L.PopDistance = 4 -- a correction farther than this is redrawn at once (a different merge), not slid
L.JoinWaitSeconds = 1 -- an open session with no driver round this long: ask to join
L.JoinRetrySeconds = 2
L.MaxJoins, L.JoinSeconds = 5, 2 -- server: joins per round, and apart
L.MaxStateBytes = 12 * 1024

local KINDS = { drop = true, swap = true, pop = true, arm = true, pause = true, resume = true }
local INPUT_KEYS = { n = true, tick = true, kind = true, aim = true, item = true }
local PACKET_KEYS = { resetId = true, run = true, tick = true, inputs = true, want = true, over = true }

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
	if type(packet) ~= "table" or keyCount(packet, 6) > 6 then return nil, "Malformed" end
	for key in pairs(packet) do
		if not PACKET_KEYS[key] then return nil, "Malformed" end
	end
	local resetId, run, tick, inputs = packet.resetId, packet.run, packet.tick, packet.inputs
	if not integer(resetId, 0, 2 ^ 30) or not integer(run, 0, 2147483647) or not integer(tick, 0, RoundSim.MaxTicks) then
		return nil, "Malformed"
	end
	-- B4: `want` = a checkpoint tick whose hash did not match (asks for the server's state);
	-- `over` = true once the client's host ended its round (at `tick`).
	if packet.want ~= nil and not integer(packet.want, 0, RoundSim.MaxTicks) then return nil, "Malformed" end
	if packet.over ~= nil and packet.over ~= true then return nil, "Malformed" end
	local out = { resetId = resetId, run = run, tick = tick, inputs = {}, want = packet.want, over = packet.over == true }
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

-- B4: a join request {join = resetId, run}. Returns resetId, run or nil.
function L.readJoin(packet)
	if type(packet) ~= "table" or packet.join == nil or keyCount(packet, 2) ~= 2 or not integer(packet.join, 0, 2 ^ 30)
		or not integer(packet.run, 0, 2147483647) then
		return nil
	end
	return packet.join, packet.run
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

-- ── B4: full host state (server -> client) ────────────────────────────────
-- A tagged binary encoding of the plain host table: every double bit-exact ("<d"), integers as i32,
-- strings interned, tables as key / value pairs (arrays in index order). The host is plain data with no
-- shared or cyclic tables (BoardRoundSim); a repeated table, a function or depth > 8 is an error.
-- Queue and star slots past `revealed` are masked, so the state never shows more than the reveals did.
local TAG_FALSE, TAG_TRUE, TAG_INT, TAG_NUM, TAG_STR, TAG_REF, TAG_TABLE = 1, 2, 3, 4, 5, 6, 7

local function encodeValue(value, out, strings, seen, depth)
	local kind = type(value)
	if value == false then table.insert(out, string.pack("<B", TAG_FALSE))
	elseif value == true then table.insert(out, string.pack("<B", TAG_TRUE))
	elseif kind == "number" then
		-- -0 and non-integers keep their exact bits (architect review: -0 % 1 == 0).
		if value % 1 == 0 and value >= -2147483648 and value <= 2147483647 and not (value == 0 and 1 / value < 0) then
			table.insert(out, string.pack("<Bi4", TAG_INT, value))
		else
			table.insert(out, string.pack("<Bd", TAG_NUM, value))
		end
	elseif kind == "string" then
		local index = strings[value]
		if index then table.insert(out, string.pack("<BI2", TAG_REF, index))
		else
			assert(#value <= 255, "state string too long")
			strings.n += 1
			strings[value] = strings.n
			table.insert(out, string.pack("<Bs1", TAG_STR, value))
		end
	elseif kind == "table" then
		assert(depth <= 8 and not seen[value], "state is not a plain tree")
		seen[value] = true
		local count, n = 0, #value
		for _ in pairs(value) do count += 1 end
		table.insert(out, string.pack("<BI2", TAG_TABLE, count))
		for index = 1, n do
			encodeValue(index, out, strings, seen, depth + 1)
			encodeValue(value[index], out, strings, seen, depth + 1)
		end
		for key, item in pairs(value) do
			if not (type(key) == "number" and key % 1 == 0 and key >= 1 and key <= n) then
				encodeValue(key, out, strings, seen, depth + 1)
				encodeValue(item, out, strings, seen, depth + 1)
			end
		end
	else
		error("state holds a " .. kind)
	end
end

-- (buffer, bytes) for the host, or nil plus a reason (too large, not plain data). Never errors.
function L.encodeState(host, revealed)
	local ok, result = pcall(function()
		local copy = RoundSim.snapshot(host)
		local board = copy.board
		for slot = (revealed or 0) + 1, #board.queue do
			board.queue[slot] = L.Placeholder
			if board.stars then board.stars[slot] = false end
		end
		local out = {}
		encodeValue(copy, out, { n = 0 }, {}, 0)
		return table.concat(out)
	end)
	if not ok then return nil, "Encode" end
	if #result > L.MaxStateBytes then return nil, "Size" end
	return buffer.fromstring(result), #result
end

local function decodeValue(bytes, offset, strings, depth)
	local tag
	tag, offset = string.unpack("<B", bytes, offset)
	if tag == TAG_FALSE then return false, offset
	elseif tag == TAG_TRUE then return true, offset
	elseif tag == TAG_INT then return string.unpack("<i4", bytes, offset)
	elseif tag == TAG_NUM then return string.unpack("<d", bytes, offset)
	elseif tag == TAG_STR then
		local value
		value, offset = string.unpack("<s1", bytes, offset)
		table.insert(strings, value)
		return value, offset
	elseif tag == TAG_REF then
		local index
		index, offset = string.unpack("<I2", bytes, offset)
		return assert(strings[index], "bad string ref"), offset
	elseif tag == TAG_TABLE then
		assert(depth <= 8, "state too deep")
		local count
		count, offset = string.unpack("<I2", bytes, offset)
		local value = {}
		for _ = 1, count do
			local key, item
			key, offset = decodeValue(bytes, offset, strings, depth + 1)
			item, offset = decodeValue(bytes, offset, strings, depth + 1)
			value[key] = item
		end
		return value, offset
	end
	error("bad state tag " .. tostring(tag))
end

-- The host from a state buffer, or nil plus a reason. Never errors.
function L.decodeState(data)
	if type(data) ~= "buffer" or buffer.len(data) > L.MaxStateBytes then return nil, "Data" end
	local ok, host = pcall(function()
		local bytes = buffer.tostring(data)
		local value, offset = decodeValue(bytes, 1, {}, 0)
		assert(offset == #bytes + 1, "trailing bytes")
		return value
	end)
	if not ok or type(host) ~= "table" or type(host.board) ~= "table" or type(host.board.eggs) ~= "table" then return nil, "Decode" end
	return host
end

return table.freeze(L)
