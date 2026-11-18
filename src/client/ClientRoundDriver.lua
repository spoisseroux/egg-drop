-- Client-run board B2, minimal client driver (artifacts/qa-2026-11-17-v887/B2-plan.md). When the
-- server runs a field round in lockstep (it sends "start" on Remotes.BoardClientSim), this steps its
-- own BoardRoundSim from the same public spec at Config.Pace, turns taps, item uses and pauses into
-- tick-stamped inputs, and sends them with a 10 Hz heartbeat of its tick. Rendering is unchanged in
-- B2: the deck still draws the server's Parts / snapshot stream (B3 draws this host).
--
-- An input is sent only when this host accepted it, or refused it with Full / Spawn (those take the
-- drop-interval latch, so the server must see them); any other refusal restores the host's input
-- counters, so it never reaches the server or the hash. Every message carries all inputs the server
-- has not acked yet (at most BoardLockstep.MaxBatchInputs), so a refused or lost message loses nothing.
-- Leaving Board mode pauses the host (an input), as the server froze the board there before.
--
-- B3 (B3-plan.md): the deck's mirror (ClientBoardMirror) attaches as the view: it gets every step
-- (beforeStep / afterStep with the step's events and impacts), every applied input and the stop,
-- and draws this host. Drops wait for the server's hello ack (so a no-hello fallback never takes a
-- ball the player saw), and taps after the local round end are refused here, never sent on today's path.
--
-- B4 (B4-plan.md): the server's checkpoint hashes are compared with a 3 s ring of this host's; on a
-- mismatch the driver asks for the server's state, restores it and replays its own input log over a
-- few frames (at most L.ReplayStepsPerFrame steps each) while the live host keeps running, then swaps
-- the corrected host in (the mirror eases the drawn balls). A driver with no round for the open
-- session (folder attribute ClientSimRound) asks to join it and continues from the server's state.
local Players = game:GetService("Players")
local ReplicatedStorage = game:GetService("ReplicatedStorage")
local RunService = game:GetService("RunService")
local Shared = ReplicatedStorage:WaitForChild("Shared")
local Flags = require(Shared.FeatureFlags)
local Config = require(Shared.BoardConfig)
local Sim = require(Shared.BoardSim)
local RoundSim = require(Shared.BoardRoundSim)
local L = require(Shared.BoardLockstep)

local Driver = {}
local FIXED = Config.FixedStep
local MAX_FRAME_STEPS = 20
local studio = RunService:IsStudio()
local started = false
local remote, folder = nil, nil
local round = nil -- the live lockstep round, or nil
local view = nil -- B3: the deck's mirror (step, input and stop hooks), or nil
local impacts = {} -- B3: reused per step, only while a view is attached
local menuPaused = false -- the deck's own pause wish (menus, carousel)
local join = { waitSince = nil, sentAt = -math.huge } -- B4: asking to join an open session
-- Studio test knobs (exploit specs): rate multiplies the clock; freeze stops stepping and sending;
-- hold buffers outgoing messages (a send blackout) until released. B4: perturb moves the newest ball
-- once (a forced desync), perturbEvery each Heartbeat (repeated desync).
local test = { rate = 1, freeze = false, hold = false, held = {}, perturb = nil, perturbEvery = nil }

local function newStats()
	return { sent = 0, messages = 0, accepted = 0, latched = 0, localRefused = {}, acks = 0, hashes = {}, steps = 0,
		checks = 0, matched = 0, mismatches = 0, skipped = 0, missing = 0, wants = 0, states = 0, restoreBad = {},
		replays = 0, replaySteps = 0, replayFramesMax = 0, replayStepsFrameMax = 0, rollbacks = 0, abandoned = 0,
		recoverMs = {}, joins = 0, joinsSent = 0, perturbs = 0 }
end
local lastStats = newStats()

local function fire(packet)
	if test.hold then table.insert(test.held, packet); return end
	remote:FireServer(packet)
end

-- want (B4): a checkpoint tick whose hash did not match.
local function sendNow(want)
	local state = round
	if not state or state.joining then return end
	local host = state.host
	local inputs, tick = {}, host.board.tick
	for index, input in ipairs(state.unacked) do
		if index > L.MaxBatchInputs then
			-- Truncated: report only up to the first input left out, so the server never passes it.
			tick = input.tick
			break
		end
		inputs[index] = { n = input.n, tick = input.tick, kind = input.kind, aim = input.aim, item = input.item }
	end
	-- B4: a corrected host that ended earlier never reports a lower tick than already reported.
	tick = math.max(tick, state.reportedTick)
	state.reportedTick = tick
	fire({ resetId = state.resetId, run = state.run, tick = tick, inputs = inputs, want = want,
		over = if host.over then true else nil })
	state.sentAt = os.clock()
	state.stats.messages += 1
end

local function refuseLocal(state, reason)
	state.stats.localRefused[reason] = (state.stats.localRefused[reason] or 0) + 1
	return false, reason
end

-- Applies one input to this host; logs and sends it if the server must see it.
local function submit(state, input)
	local host = state.host
	-- B4: a joined round first applies the inputs the server still had queued (their ticks).
	if state.joining or #state.future > 0 then return refuseLocal(state, "Joining") end
	if #state.unacked >= L.MaxUnacked then return refuseLocal(state, "Backlog") end
	-- B4: numbered past every n sent, never from a corrected host's lastN (it may be lower).
	input.n, input.tick = math.max(host.lastN, state.nextN) + 1, host.board.tick
	local saved = { host.lastN, host.inputCount, host.tickInputsAt, host.tickInputs }
	local ok, result = RoundSim.apply(host, input)
	if not ok and result ~= "Full" and result ~= "Spawn" then
		host.lastN, host.inputCount, host.tickInputsAt, host.tickInputs = saved[1], saved[2], saved[3], saved[4]
		return refuseLocal(state, result)
	end
	if ok then state.stats.accepted += 1 else state.stats.latched += 1 end
	state.stats.sent += 1
	state.nextN = input.n
	table.insert(state.unacked, input)
	table.insert(state.log, input)
	sendNow()
	if view and view.input then view.input(state, input, ok, result) end
	return ok, result
end

local function active()
	return round ~= nil and not round.joining and not round.host.over
end

-- B3: a round exists but cannot take this tap (over, or no hello yet): refused here, never sent on
-- today's path. Nil when no lockstep round runs.
local function closedTap(state)
	if not state then return nil end
	if state.joining then return refuseLocal(state, "Joining") end
	if state.host.over then return refuseLocal(state, "RoundOver") end
	return nil
end

-- ── Public: the deck's taps (init.client.lua). nil = no lockstep round (use today's path). ──

function Driver.drop(aim)
	local state = round
	if not active() then return closedTap(state) end
	if not state.hello then return refuseLocal(state, "Hello") end
	local index = Sim.aimIndex(aim)
	if not index then return refuseLocal(state, "Aim") end
	-- The ball's queue slot must be revealed (the server reveals a few ahead of its drops).
	if state.host.board.drops >= state.revealed then return refuseLocal(state, "Unrevealed") end
	return submit(state, { kind = "drop", aim = index })
end

function Driver.item(id)
	local state = round
	if not active() then return closedTap(state) end
	if not state.hello then return refuseLocal(state, "Hello") end
	if id == "swap" then
		if state.host.board.drops + 2 > state.revealed then return refuseLocal(state, "Unrevealed") end
		return submit(state, { kind = "swap" })
	elseif id == "pop" then return submit(state, { kind = "pop" })
	elseif id == "bomb" or id == "magnet" then return submit(state, { kind = "arm", item = id })
	end
	return refuseLocal(state, "Item")
end

local function syncPause(state)
	local want = menuPaused or (folder ~= nil and folder:GetAttribute("Mode") ~= "Board")
	if state.host.paused ~= want and not state.host.over then
		submit(state, { kind = if want then "pause" else "resume" })
	end
end

function Driver.pause(paused)
	menuPaused = paused == true
	if active() then syncPause(round) end
end

function Driver.isActive() return active() end

-- ── B3: the deck's view ───────────────────────────────────────────────────

-- hooks: beforeStep(state), afterStep(state, events, impacts), input(state, input, ok, result),
-- stop(state, reason); B4: rollback(state, oldHost), replayed(state, events). One view; attach(nil) detaches.
function Driver.attach(hooks) view = hooks end
-- The round the deck draws (nil while a join waits for the server's state).
function Driver.round() return if round and not round.joining then round else nil end
-- The fraction of a fixed step the clock has run past the last step (render interpolation);
-- 1 while paused or over (the last step is the drawn state).
function Driver.alpha()
	local state = round
	if not state or state.joining or state.host.paused or state.host.over or test.freeze then return 1 end
	return math.clamp(state.acc / FIXED, 0, 1)
end
function Driver.sentCount() return lastStats.sent end

-- ── B4: verify and rollback ───────────────────────────────────────────────

local function record(state, host)
	local tick = host.board.tick
	if tick % L.HashTicks == 0 then
		local ring, ticks = state.ring, state.ringTicks
		if ring[tick] == nil then table.insert(ticks, tick) end
		ring[tick] = L.hash(host)
		while ticks[1] and ticks[1] < tick - L.RingTicks do
			ring[table.remove(ticks, 1)] = nil
		end
	end
	if tick % 60 == 0 and studio then state.stats.hashes[tostring(tick)] = L.hash(host) end
end

local function push(list, value)
	if #list >= 32 then table.remove(list, 1) end
	table.insert(list, value)
end

-- The server's checkpoint (or round end) hash at `packet.tick`.
local function verify(state, packet)
	local stats = state.stats
	if state.joining or state.want or state.replay or #state.future > 0 then
		stats.skipped += 1
		-- Code review: the round-end hash is sent once; it is checked again after the swap.
		if packet.over then state.overPacket = packet end
		return
	end
	if type(packet.tick) ~= "number" or type(packet.hash) ~= "string" then return end
	local mine
	if packet.over then
		-- The server's round ended at this tick: the same only if this host ended there with that hash.
		local host = state.host
		mine = if host.over and host.overTick == packet.tick then state.final else false
	else
		mine = state.ring[packet.tick]
		if mine == nil then stats.missing += 1; return end
	end
	stats.checks += 1
	if mine == packet.hash then
		stats.matched += 1
		state.verified = packet.tick
		return
	end
	stats.mismatches += 1
	stats.wants += 1
	state.want = { tick = packet.tick, at = os.clock() }
	state.mismatchAt = state.mismatchAt or os.clock()
	state.mismatchTick = math.min(state.mismatchTick or packet.tick, packet.tick)
	sendNow(packet.tick)
end

local function firstLogIndex(log, lastN)
	for index, input in ipairs(log) do
		if input.n > lastN then return index end
	end
	return #log + 1
end

-- The server's full state: a rollback (replay job) or, for a join, the round's host.
local function restore(state, packet)
	local stats = state.stats
	local host, why = L.decodeState(packet.data)
	if host and L.hash(host) ~= packet.hash then host, why = nil, "Hash" end
	if not host then
		stats.restoreBad[why or "Decode"] = (stats.restoreBad[why or "Decode"] or 0) + 1
		state.want = nil -- the next mismatch asks again (the server falls back past L.MaxResyncs)
		if state.joining then round = nil end
		return
	end
	stats.states += 1
	-- Slots revealed after the server encoded the state (none: the remote is ordered) come from here.
	local revealed = type(packet.revealed) == "number" and packet.revealed or 0
	local live = state.host.board
	for slot = math.max(revealed, host.board.drops) + 1, math.min(state.revealed, #host.board.queue) do
		host.board.queue[slot] = live.queue[slot]
		if host.board.stars and live.stars then host.board.stars[slot] = live.stars[slot] end
	end
	if packet.join then
		state.host, state.joining, state.hello = host, false, true
		state.log, state.unacked, state.future = {}, {}, {}
		state.nextN = host.lastN
		for _, input in ipairs(type(packet.pending) == "table" and packet.pending or {}) do
			table.insert(state.future, input)
			table.insert(state.log, input)
			if input.n > state.nextN then state.nextN = input.n end
		end
		state.acc, state.reportedTick, state.final, state.result = 0, host.board.tick, nil, nil
		stats.joins += 1
		syncPause(state)
		sendNow()
		return
	end
	stats.replays += 1
	-- Hashes this host made after the last checkpoint before the mismatch up to the server's tick are
	-- of the wrong timeline (the replay rewrites the ones after it): dropped from the ring and the
	-- Studio record.
	local from = (state.mismatchTick or host.board.tick) - L.HashTicks + 1
	local to = host.board.tick
	for tick = from - from % L.HashTicks, to, L.HashTicks do state.ring[tick] = nil end
	for key in pairs(stats.hashes) do
		local tick = tonumber(key)
		if tick and tick >= from and tick <= to then
			stats.hashes[key] = nil
			stats.hashesDropped = (stats.hashesDropped or 0) + 1
		end
	end
	state.want = nil
	state.replay = { host = host, index = firstLogIndex(state.log, host.lastN), frames = 0, steps = 0, from = host.board.tick }
end

-- Steps the replay toward the live tick (at most L.ReplayStepsPerFrame this frame); swaps it in
-- once it has caught up with the live host and applied every logged input.
local function advanceReplay(state)
	local job = state.replay
	local rhost, log = job.host, state.log
	local stats = state.stats
	local target = state.host.board.tick
	local steps = 0
	job.frames += 1
	while true do
		local input = log[job.index]
		-- Code review: never into a round that already ended (the server queues nothing after it).
		while input and not rhost.over and input.tick <= rhost.board.tick do
			RoundSim.apply(rhost, input) -- refusals are the rules' own, as on the server
			job.index += 1
			input = log[job.index]
		end
		if rhost.over or rhost.board.tick >= target then break end
		if rhost.paused then
			-- Paused with nothing left to resume it before the live tick: it cannot catch up.
			stats.abandoned += 1
			state.replay = nil
			return
		end
		if steps >= L.ReplayStepsPerFrame then
			stats.replaySteps += steps
			if steps > stats.replayStepsFrameMax then stats.replayStepsFrameMax = steps end
			job.steps += steps
			return
		end
		local events = RoundSim.step(rhost)
		if not events then break end
		steps += 1
		record(state, rhost)
		if view and view.replayed then view.replayed(state, events) end
	end
	stats.replaySteps += steps
	job.steps += steps
	if steps > stats.replayStepsFrameMax then stats.replayStepsFrameMax = steps end
	if job.frames > stats.replayFramesMax then stats.replayFramesMax = job.frames end
	local old = state.host
	state.host, state.replay = rhost, nil
	state.final = if rhost.over then L.hash(rhost) else nil
	state.result = if rhost.over then RoundSim.result(rhost) else nil
	stats.rollbacks += 1
	stats.lastRollbackAt = os.clock()
	if state.mismatchAt then
		push(stats.recoverMs, (os.clock() - state.mismatchAt) * 1000)
		state.mismatchAt, state.mismatchTick = nil, nil
	end
	stats.lastReplay = { from = job.from, to = rhost.board.tick, steps = job.steps, frames = job.frames }
	if view and view.rollback then view.rollback(state, old) end
	if rhost.over then sendNow() end
	local overPacket = state.overPacket
	if overPacket then
		state.overPacket = nil
		verify(state, overPacket)
	end
end

-- ── Server messages ───────────────────────────────────────────────────────

local function onMessage(kind, packet)
	if type(packet) ~= "table" then return end
	if kind == "start" then
		local spec, why = L.clientSpec(packet)
		local host = spec and RoundSim.new(spec)
		if not host then
			warn("[ClientSim] cannot start the round host:", why or "Spec")
			round = nil
			return
		end
		-- A join continues the same round: its Studio counters carry on.
		local key = tostring(packet.resetId) .. ":" .. tostring(packet.run)
		local roundStats = if packet.join == true and lastStats.round == key then lastStats else newStats()
		roundStats.round = key
		round = {
			host = host, resetId = packet.resetId, run = packet.run, revealed = 0,
			unacked = {}, acc = 0, sentAt = -math.huge, startedAt = os.clock(), stats = roundStats,
			-- B4
			log = {}, nextN = 0, ring = {}, ringTicks = {}, future = {}, want = nil, replay = nil,
			reportedTick = 0, joining = packet.join == true,
		}
		lastStats = round.stats
		round.revealed = L.applyReveal(host, 0, packet.reveal)
		if round.joining then return end -- held until the server's state (B4 join)
		syncPause(round)
		sendNow()
		return
	end
	local state = round
	if not state or packet.resetId ~= state.resetId or packet.run ~= state.run then return end
	if kind == "reveal" then
		state.revealed = L.applyReveal(state.host, state.revealed, packet)
		-- Architect review: a replay in progress needs the same slots.
		if state.replay then L.applyReveal(state.replay.host, 0, packet) end
	elseif kind == "ack" then
		state.stats.acks += 1
		state.hello = true
		local n = packet.n
		if type(n) == "number" then
			while state.unacked[1] and state.unacked[1].n <= n do table.remove(state.unacked, 1) end
		end
	elseif kind == "hash" then
		verify(state, packet)
	elseif kind == "state" then
		restore(state, packet)
	elseif kind == "stop" then
		state.stats.stopped = packet.reason
		round = nil
		if view and view.stop then view.stop(state, packet.reason) end
	end
end

-- ── Clock ─────────────────────────────────────────────────────────────────

-- B4: an open session (folder ClientSimRound = this board's ResetId) with no round here: ask to join.
local function checkJoin()
	local open = folder and folder:GetAttribute("ClientSimRound")
	if open == nil or open ~= folder:GetAttribute("ResetId") or (round and round.resetId == open) then
		join.waitSince = nil
		return
	end
	local now = os.clock()
	join.waitSince = join.waitSince or now
	if now - join.waitSince >= L.JoinWaitSeconds and now - join.sentAt >= L.JoinRetrySeconds then
		join.sentAt = now
		lastStats.joinsSent += 1
		local run = folder:GetAttribute("RunSequence")
		if type(run) == "number" then fire({ join = open, run = run }) end
	end
end

local function perturb(state, dx)
	local eggs = state.host.board.eggs
	local egg = eggs[#eggs]
	if not egg then return end
	egg.x += dx
	state.stats.perturbs += 1
	state.stats.perturbAt, state.stats.perturbTick = os.clock(), state.host.board.tick
end

local function onHeartbeat(dt)
	if test.freeze then return end
	checkJoin()
	local state = round
	if not state or state.joining then return end
	local host = state.host
	if test.perturb then perturb(state, test.perturb); test.perturb = nil end
	if test.perturbEvery and not host.over then perturb(state, test.perturbEvery) end
	syncPause(state)
	if not host.over then
		state.acc = math.min(state.acc + dt * Config.Pace * test.rate, FIXED * MAX_FRAME_STEPS * math.max(1, test.rate))
		while state.acc >= FIXED do
			-- B4 join: inputs the server had queued apply at their ticks.
			local future = state.future
			while future[1] and future[1].tick <= host.board.tick do
				RoundSim.apply(host, table.remove(future, 1))
			end
			if view then view.beforeStep(state) end
			local events = RoundSim.step(host, if view then impacts else nil)
			if not events then state.acc = 0; break end
			if view then
				view.afterStep(state, events, impacts)
				table.clear(impacts)
			end
			state.acc -= FIXED
			state.stats.steps += 1
			record(state, host)
			if host.over then
				state.final = L.hash(host)
				state.result = RoundSim.result(host)
				sendNow()
				break
			end
		end
	end
	if state.replay then advanceReplay(state) end
	if state.want and os.clock() - state.want.at > L.WantRetrySeconds then state.want = nil end
	local interval = if state.host.over then L.OverHeartbeatSeconds else L.HeartbeatSeconds
	if os.clock() - state.sentAt >= interval then sendNow() end
end

-- ── Studio test bindable (PlayerGui.EggDropClientSim) ─────────────────────

local function stats()
	local state = round
	local out = table.clone(lastStats)
	out.active = state ~= nil
	if view and view.stats then out.mirror = view.stats() end
	if state then
		local host = state.host
		out.resetId, out.run, out.tick, out.revealed, out.lastN = state.resetId, state.run, host.board.tick, state.revealed, host.lastN
		out.unacked, out.paused, out.over, out.drops = #state.unacked, host.paused, host.over, host.board.drops
		out.belt, out.armed, out.final, out.result = table.clone(host.belt), host.board.armed, state.final, state.result
		out.hello = state.hello
		out.hash = L.hash(host)
		out.wallSeconds = os.clock() - state.startedAt
		out.joining, out.replaying, out.wanting, out.verified = state.joining, state.replay ~= nil, state.want ~= nil, state.verified
		out.logSize, out.ringSize, out.nextN = #state.log, #state.ringTicks, state.nextN
	end
	return out
end

local function mountTest(player)
	local gui = player:WaitForChild("PlayerGui")
	local hook = Instance.new("BindableFunction")
	hook.Name = "EggDropClientSim"
	hook.OnInvoke = function(action, a, b)
		if action == "stats" then return stats()
		elseif action == "drop" then return Driver.drop(a)
		elseif action == "item" then return Driver.item(a)
		elseif action == "pause" then Driver.pause(a); return true
		elseif action == "mirrorReset" then
			if view and view.resetStats then view.resetStats() end
			return true
		elseif action == "rate" then test.rate = if type(a) == "number" then a else 1; return test.rate
		elseif action == "freeze" then test.freeze = a == true; return test.freeze
		elseif action == "perturb" then test.perturb = if type(a) == "number" then a else 1; return true
		elseif action == "perturbEvery" then test.perturbEvery = if type(a) == "number" then a else nil; return true
		elseif action == "forget" then
			-- As a reload would: the round is gone here, the server's session is still open.
			local state = round
			round = nil
			if state and view and view.stop then view.stop(state, "Forget") end
			return state ~= nil
		elseif action == "hold" then
			test.hold = a == true
			if not test.hold then
				local held = test.held
				test.held = {}
				for _, packet in ipairs(held) do remote:FireServer(packet) end
				return #held
			end
			return 0
		elseif action == "raw" then remote:FireServer(a); return true
		elseif action == "current" then
			-- A well-formed packet for this round (the exploit spec edits it before "raw").
			local state = round
			if not state then return nil end
			return { resetId = state.resetId, run = state.run, tick = state.host.board.tick, inputs = {} }
		end
		return nil
	end
	hook.Parent = gui
end

function Driver.start()
	if started then return Driver end
	started = true
	if not (Flags.DeckClientSim == true or Flags.DeckClientSimTesters == true or studio) then return Driver end
	task.spawn(function()
		local player = Players.LocalPlayer
		remote = ReplicatedStorage:WaitForChild("Remotes"):WaitForChild(L.RemoteName, 60)
		if not remote then return end
		folder = ReplicatedStorage:WaitForChild("EggDropBoards"):WaitForChild(tostring(player.UserId), 120)
		remote.OnClientEvent:Connect(onMessage)
		RunService.Heartbeat:Connect(onHeartbeat)
		if studio then mountTest(player) end
	end)
	return Driver
end

return Driver
