-- Client-run board B2, server side (artifacts/qa-2026-11-17-v887/B2-plan.md). Behind
-- FeatureFlags.DeckClientSim (false); in Studio the ServerStorage attribute DeckClientSim = true
-- turns it on for the next field round reset. A lockstep round is run by BoardRoundSim as the
-- authority, stepped only up to the tick the owner's client has reported (the input horizon),
-- under clock guards; the client steps its own copy from the same spec and sends its inputs.
--
-- init.server.lua keeps reading `board.sim`, `board.round`, `board.field` and the round counters:
-- `begin` returns a mirror shaped like BoardSimulation's board, and after every advance the host's
-- state is copied onto the mirror and onto the real Round / FieldRun objects, so publishState,
-- syncVisuals (the shared Parts other players see), BoardItems.publish, BoardNet.publish, RunReturn
-- and settleReward run unchanged. Events go to the hooks init.server.lua passes (its old merge loop's
-- consumers). Flag and override off: begin returns nil and nothing here runs.
--
-- B4 (B4-plan.md): a checkpoint hash every L.HashTicks and at the round end; the full state on the
-- client's `want` (rate-limited); a join for a driver that lost its round; after L.MaxResyncs the
-- session closes and the server runs the round itself (`serverRun`, today's requests as inputs).
local ReplicatedStorage = game:GetService("ReplicatedStorage")
local ServerStorage = game:GetService("ServerStorage")
local RunService = game:GetService("RunService")
local HttpService = game:GetService("HttpService")
local Shared = ReplicatedStorage.Shared
local Flags = require(Shared.FeatureFlags)
local Config = require(Shared.BoardConfig)
local Sim = require(Shared.BoardSim)
local RoundSim = require(Shared.BoardRoundSim)
local L = require(Shared.BoardLockstep)
local Net = require(script.Parent.BoardNet)

local Host = {}
-- Deck net audit: the start carries the server's clock, so the client can tell how long its hello can take
-- (its early taps stop before the no-hello fallback could take them). The offline harness swaps it.
Host.serverNow = function() return workspace:GetServerTimeNow() end
local FIXED = Config.FixedStep
local TPS = L.TicksPerSecond
local remote = nil
local studio = RunService:IsStudio()

-- player (optional): with FeatureFlags.DeckClientSimTesters, Spencer's test accounts
-- (SimCheck.isOwner) play lockstep rounds in a published build before the flag goes on for all.
function Host.enabled(player)
	if Flags.DeckClientSim == true then return true end
	-- B4: in Studio every player is a tester (SimCheck.isOwner); ServerStorage.DeckClientSim = false
	-- (explicitly) turns lockstep off there, so today's-path regressions can run.
	if studio and ServerStorage:GetAttribute("DeckClientSim") == false then return false end
	if Flags.DeckClientSimTesters == true and player and require(Shared.SimCheck).isOwner(player) then return true end
	return studio and ServerStorage:GetAttribute("DeckClientSim") == true
end

local function send(board, kind, packet)
	if remote and board.player and board.player.Parent then remote:FireClient(board.player, kind, packet) end
end

local function count(map, key)
	map[key] = (map[key] or 0) + 1
end

-- B4: the folder says which lockstep session is open (a driver without that round asks to join).
local function publishOpen(board, state)
	local folder = board.folder
	if not folder then return end
	local value = if state and not state.closed then state.resetId else nil
	if folder:GetAttribute("ClientSimRound") ~= value then folder:SetAttribute("ClientSimRound", value) end
end

local function close(board, state)
	state.closed = true
	publishOpen(board, nil)
end

-- B4: the host's full state (end of an advance: every queued input at its tick applied), masked past
-- the reveals. extra: join, pending. Returns true when sent.
local function sendState(board, state, now, extra)
	local host = state.host
	local data, bytes = L.encodeState(host, state.revealed)
	if not data then
		count(state.stats.stateFail, bytes or "Encode")
		return false
	end
	local packet = { resetId = state.resetId, run = state.run, tick = host.board.tick, hash = L.hash(host), n = host.lastN,
		revealed = state.revealed, data = data }
	for key, value in pairs(extra or {}) do packet[key] = value end
	send(board, "state", packet)
	state.lastStateAt = now
	state.stats.statesSent += 1
	if bytes > state.stats.stateBytes then state.stats.stateBytes = bytes end
	return true
end

-- B4: repeated desync (or a state that cannot be sent): the session closes and the server runs the
-- rest of the round itself in wall time. The client releases its round and plays on today's path
-- (ghosts, snapshot stream); its drop / item requests become host inputs (Host.serverInput). Inputs
-- already queued stay and apply at their ticks (architect review: the player saw them).
local function desyncFallback(board, state, reason)
	if state.closed then return end
	close(board, state)
	state.serverRun = true
	state.fallbackAt = os.clock()
	state.runTick = state.host.board.tick
	state.clientN = state.lastN
	state.wantState = false
	state.stats.takeover = reason
	send(board, "stop", { resetId = state.resetId, run = state.run, reason = "Desync" })
end

-- ── Round start ───────────────────────────────────────────────────────────

local function revealTo(board, state, want)
	local n = #state.host.board.queue
	want = math.min(want, n)
	if want <= state.revealed then return nil end
	local slice = L.revealSlice(state.host, state.revealed, want)
	state.revealed = want
	return slice
end

-- Called from reset() in place of Simulation.new. `descriptor` is nil for a round that is not a
-- field (Welcome, no save): today's path. Returns the mirror board, or nil for today's path.
-- `fallback(serial)` (B3) puts today's board in place (board.sim) when the client never answers.
function Host.begin(board, preset, serial, descriptor, itemsOn, fallback)
	local old = board.lockstep
	if old then
		serial = old.host.board.serial
		if not old.closed then send(board, "stop", { resetId = old.resetId, run = old.run, reason = "Reset" }) end
	end
	board.lockstep = nil
	publishOpen(board, nil)
	if not descriptor or not Host.enabled(board.player) then return nil end
	local spec = RoundSim.fieldSpec(preset, serial, descriptor, board.runHeat, itemsOn)
	local host, why = RoundSim.new(spec)
	if not host or spec.budget > #spec.queue then
		warn("[ClientSim] round host refused its spec:", why or "Budget")
		return nil
	end
	local now = os.clock()
	local view = {
		eggs = {}, preset = preset, serial = spec.serial, drops = 0, queue = host.board.queue, stars = {},
		contactGate = false, dropAge = 0, fallingId = nil, armed = nil, clientSim = true,
	}
	local state = {
		host = host, spec = spec, view = view, views = {}, live = {},
		resetId = spec.serial, run = board.runSequence, closed = false, serverDriven = false,
		hello = false, fallback = fallback,
		pending = {}, head = 1, tail = 0, lastN = 0, lastTick = 0, reported = 0, queuedDrops = 0,
		allow = 0, wall = 0, revealed = 0, tokens = L.MessageBurst, tokensAt = now,
		lastProgressAt = now, lastReportAt = now, stalledAt = nil, ackedN = 0, overHandled = false,
		-- B4: verify / rollback / rejoin / desync fallback.
		checkpoint = nil, overHashSent = false, wantState = false, resyncs = 0, lastStateAt = -math.huge,
		clientOverTick = nil, clientOverHandled = nil, joins = 0, joinAt = -math.huge,
		serverRun = false, runTick = 0, clientN = 0, dropTokens = {}, fallbackAt = -math.huge, serverInputSeen = false,
		stats = { batches = 0, inputs = 0, resent = 0, applied = 0, refused = {}, rule = {}, throttled = 0,
			stalls = 0, maxBehind = 0, maxSteps = 0, aheadMax = 0, hashes = {}, startedAt = now,
			hashesSent = 0, wants = 0, statesSent = 0, stateBytes = 0, stateFail = {}, deferred = 0, overMismatch = 0,
			joins = 0, serverInputs = 0, lateClientInputs = 0 },
	}
	board.lockstep = state
	local public = RoundSim.publicSpec(spec)
	public.descriptor.seed = nil -- the queue is made from it: never sent
	state.public = public
	send(board, "start", { version = L.Version, resetId = state.resetId, run = state.run, spec = public,
		queueLength = #spec.queue, reveal = revealTo(board, state, L.Reveal) or L.revealSlice(host, 0, 0), sentAt = Host.serverNow() })
	publishOpen(board, state)
	return view
end

-- ── Client messages ───────────────────────────────────────────────────────

local function refuse(state, reason)
	count(state.stats.refused, reason)
	return false, reason
end

-- One client message. Every refusal leaves the round untouched (the client resends unacked inputs).
function Host.receive(board, packet, now)
	local state = board.lockstep
	if not state then return false, "NoRound" end
	state.tokens = math.min(L.MessageBurst, state.tokens + (now - state.tokensAt) * L.MessageRate)
	state.tokensAt = now
	if state.tokens < 1 then return refuse(state, "Rate") end
	state.tokens -= 1
	local joinId, joinRun = L.readJoin(packet)
	if joinId then return Host.join(board, state, joinId, joinRun, now) end
	local batch, reason = L.readBatch(packet)
	if not batch then return refuse(state, reason) end
	if batch.resetId ~= state.resetId or batch.run ~= state.run then return refuse(state, "Stale") end
	local host = state.host
	if state.closed then
		-- B4: after a desync fallback, inputs the client made before it saw the stop still count
		-- (architect review): renumbered behind the server's own, at the server's tick or later.
		-- Code review: only for a short window after the stop and before any server-run request, and
		-- never past the server's tick + 1 s (a far-future tick would hold every later input back).
		if state.serverRun and not host.over and not state.serverInputSeen and now - state.fallbackAt <= L.LateInputSeconds then
			local hb = host.board
			for _, input in ipairs(batch.inputs) do
				if input.n > state.clientN and state.tail - state.head + 1 < L.MaxPending then
					state.clientN = input.n
					state.lastN += 1
					state.lastTick = math.min(math.max(input.tick, hb.tick, state.lastTick), hb.tick + L.LeadTicks)
					state.tail += 1
					state.pending[state.tail] = { n = state.lastN, tick = state.lastTick, kind = input.kind, aim = input.aim, item = input.item }
					if input.kind == "drop" then state.queuedDrops += 1 end
					state.stats.lateClientInputs += 1
				end
			end
			return true
		end
		return refuse(state, "Stale")
	end
	-- B4: the client's checkpoint hash did not match: its state is sent at the end of the next
	-- advance (rate-limited there). `over`: the client's host ended at batch.tick.
	if batch.want then
		state.stats.wants += 1
		state.wantState = true
	end
	if host.over then
		state.stats.afterEnd = (state.stats.afterEnd or 0) + 1
		return false, "Over"
	end
	if batch.tick < state.reported then return refuse(state, "Order") end
	if batch.tick > state.allow + L.LeadTicks + L.AheadTicks then return refuse(state, "Ahead") end
	-- Inputs this server already queued are resends: skipped. The rest must follow on.
	local fresh, resent = {}, 0
	for _, input in ipairs(batch.inputs) do
		if input.n <= state.lastN then resent += 1 else table.insert(fresh, input) end
	end
	local serverTick = host.board.tick
	if #fresh > 0 then
		if fresh[1].n ~= state.lastN + 1 then return refuse(state, "Gap") end
		if fresh[1].tick < serverTick then return refuse(state, "Late") end
		if fresh[1].tick < state.lastTick then return refuse(state, "Order") end
		if state.tail - state.head + 1 + #fresh > L.MaxPending then return refuse(state, "Busy") end
	end
	for _, input in ipairs(fresh) do
		state.tail += 1
		state.pending[state.tail] = input
		if input.kind == "drop" then state.queuedDrops += 1 end
	end
	if #fresh > 0 then
		state.lastN, state.lastTick = fresh[#fresh].n, fresh[#fresh].tick
	end
	if batch.tick > state.reported then state.lastProgressAt, state.lastReportAt = now, now end
	state.reported = batch.tick
	state.clientOverTick = if batch.over then batch.tick else nil
	state.stats.batches += 1
	state.stats.inputs += #fresh
	state.stats.resent += resent
	-- B3: the first accepted message is the client's hello (its host and deck run this round); the
	-- ack answers it even with no inputs, and the client drops only after it.
	local hello = not state.hello
	state.hello = true
	if hello or #fresh > 0 or (resent > 0 and state.ackedN < state.lastN) then
		state.ackedN = state.lastN
		send(board, "ack", { resetId = state.resetId, run = state.run, n = state.lastN, tick = serverTick })
	end
	return true
end

-- B4: a driver without a round for the open session (rejoin, late start, a lost round) asks for it.
-- The session goes on from the server's host: `start` (join), the full state with the inputs still
-- queued (the new client logs and applies them at their ticks, architect review) and an ack. The
-- clock guards restart at the server's tick (the new client reports from there).
function Host.join(board, state, resetId, run, now)
	local host = state.host
	if resetId ~= state.resetId or run ~= state.run or state.closed or host.over then return refuse(state, "JoinStale") end
	if state.joins >= L.MaxJoins or now - state.joinAt < L.JoinSeconds then return refuse(state, "JoinRate") end
	state.joins += 1
	state.joinAt = now
	state.stats.joins += 1
	local hb = host.board
	state.reported, state.wall, state.allow = hb.tick, hb.tick, hb.tick
	-- (lastProgressAt stays: joins never push the idle timeout back, code review.)
	state.lastReportAt, state.stalledAt = now, nil
	state.clientOverTick, state.wantState, state.hello = nil, false, true
	local pending = {}
	for index = state.head, state.tail do
		local input = state.pending[index]
		if input then table.insert(pending, { n = input.n, tick = input.tick, kind = input.kind, aim = input.aim, item = input.item }) end
	end
	send(board, "start", { version = L.Version, resetId = state.resetId, run = state.run, spec = state.public,
		queueLength = #hb.queue, reveal = L.revealSlice(host, 0, state.revealed), join = true })
	if not sendState(board, state, now, { join = true, pending = pending }) then
		desyncFallback(board, state, "JoinState")
		return false, "JoinState"
	end
	state.ackedN = state.lastN
	send(board, "ack", { resetId = state.resetId, run = state.run, n = state.lastN, tick = hb.tick })
	return true
end

-- B4: today's drop / item request on a round the server runs after a desync fallback. Queued behind
-- every input already queued, at the server's tick or later. kind: "drop" (aim 0..1) or an item id.
-- A drop's token is acked when it applies (today's ghost handoff). Returns false when not server-run.
function Host.serverInput(board, kind, value, token)
	local state = board.lockstep
	if not state or not state.serverRun or state.host.over then return false end
	local input
	if kind == "drop" then
		local aim = Sim.aimIndex(value)
		if not aim then
			if token then Net.ack(board, board.player, token, false, "Aim") end
			return true
		end
		input = { kind = "drop", aim = aim, token = token }
	elseif value == "swap" or value == "pop" then input = { kind = value }
	elseif value == "bomb" or value == "magnet" then input = { kind = "arm", item = value }
	else return true end
	if state.tail - state.head + 1 >= L.MaxPending then
		if token then Net.ack(board, board.player, token, false, "Busy") end
		return true
	end
	state.serverInputSeen = true
	state.lastN += 1
	state.lastTick = math.max(state.host.board.tick, state.lastTick)
	input.n, input.tick = state.lastN, state.lastTick
	state.tail += 1
	state.pending[state.tail] = input
	if input.kind == "drop" then state.queuedDrops += 1 end
	state.stats.serverInputs += 1
	return true
end

-- ── Advance ───────────────────────────────────────────────────────────────

local function applyInput(board, state, input, hooks)
	local host = state.host
	if input.kind == "drop" then state.queuedDrops = math.max(0, state.queuedDrops - 1) end
	local ok, result = RoundSim.apply(host, input)
	if input.token then
		-- B4 server-run drop: today's ack (the ghost hands over to the ball carrying this token).
		if ok then
			state.view.fallingId = host.board.fallingId
			state.dropTokens[result.id] = input.token
		end
		Net.ack(board, board.player, input.token, ok, if ok then nil else result)
	end
	if not ok then
		-- Full / Spawn take the interval latch, so the client sends them too (B2-plan.md); any
		-- other rule refusal here means the two hosts disagree.
		count(state.stats.rule, result)
		return false
	end
	state.stats.applied += 1
	local kind = input.kind
	if kind == "drop" then
		if hooks.drop then hooks.drop(board.player, board, host.board.drops) end
	elseif kind == "swap" or kind == "pop" or kind == "arm" then
		if hooks.item then hooks.item(board.player, board, result) end
	end
	return true
end

-- The server ends the client's session and finishes the round itself (stall in Settling, idle).
local function takeOver(board, state, reason)
	if state.closed then return end
	close(board, state)
	state.serverDriven = true
	state.stats.takeover = reason
	table.clear(state.pending)
	state.head, state.tail = 1, 0
	send(board, "stop", { resetId = state.resetId, run = state.run, reason = reason })
end

local function sync(board, state)
	local host, view = state.host, state.view
	local hb = host.board
	view.serial, view.drops, view.fallingId, view.armed, view.queue = hb.serial, hb.drops, hb.fallingId, hb.armed, hb.queue
	-- BoardSimulation.canDrop on the mirror: contactGate false = open; true with a falling ball that
	-- has no contact = closed (the host's 72-tick gate already decided).
	view.contactGate, view.dropAge = not Sim.canDrop(hb), 0
	local stars = view.stars
	table.clear(stars)
	for slot, star in ipairs(hb.stars or {}) do
		if star then stars[slot] = star end
	end
	local eggs, views, live = view.eggs, state.views, state.live
	table.clear(eggs)
	table.clear(live)
	for _, egg in ipairs(hb.eggs) do
		local mirror = views[egg.id]
		if not mirror then
			mirror = { id = egg.id, tier = egg.tier, radius = egg.radius, dropToken = state.dropTokens[egg.id] }
			views[egg.id] = mirror
		end
		mirror.position = Vector2.new(egg.x, egg.y)
		mirror.velocity = Vector2.new(egg.vx, egg.vy)
		mirror.powerUp, mirror.mark, mirror.hasContact = egg.powerUp, egg.mark, egg.hasContact
		mirror.magnetLeft = egg.magnetTicks * FIXED
		table.insert(eggs, mirror)
		live[egg.id] = true
	end
	for id in pairs(views) do
		if not live[id] then views[id] = nil end
	end
	local round = board.round
	if round then
		round.score, round.maxClears, round.over = host.score, host.clears, host.over
		round.danger, round.settledHeight, round.overflowY = host.danger, host.settledHeight, host.overflowY
		round.overflowTime = host.overflowTicks * FIXED
		round.graceLeft = if host.overflowTicks > 0 and not host.over then math.max(0, (host.graceTicks - host.overflowTicks) * FIXED) else 0
	end
	local field = board.field
	if field then
		field.phase, field.rootStage, field.goalProgress = host.phase, host.stage, host.progress
		field.chainIdentity, field.lastOrdinal, field.settleTime = host.chainIdentity, host.merges, host.settleTicks * FIXED
		if host.outcome then field.outcome = host.outcome end
	end
	board.merges, board.chain, board.peakChain, board.maxTier = host.merges, host.chain, host.peakChain, host.maxTier
	board.itemSeq, board.itemKinds, board.itemsOn = host.itemSeq, host.itemKinds, host.itemsOn
	if #board.belt ~= #host.belt or table.concat(board.belt, ",") ~= table.concat(host.belt, ",") then board.belt = table.clone(host.belt) end
	board.playTime, board.lastMerge = host.playTime, host.lastMergeTime or -math.huge
end

local function events(board, state, stepped, hooks)
	local host = state.host
	if #stepped.merges > 0 and hooks.merge then
		-- The running score / clears at each merge, as the old loop saw them.
		local score, clears = host.score, host.clears
		for _, merge in ipairs(stepped.merges) do
			score -= merge.points
			if merge.cleared then clears -= 1 end
		end
		for _, merge in ipairs(stepped.merges) do
			score += merge.points
			if merge.cleared then clears += 1 end
			hooks.merge(board.player, board, merge, score, merge.chain, clears)
		end
	end
	if stepped.bursts and hooks.bursts then hooks.bursts(board.player, board, stepped.bursts) end
end

-- B3: the client never answered the start (no driver, no host, still loading): the round has not
-- moved (tick 0, nothing queued), so today's board takes its place and the round plays on today's
-- path. The client's late messages are then refused (NoRound).
local function fallBack(board, state, now)
	close(board, state)
	state.stats.takeover = "NoHello"
	if studio then Host.publishStats(board, now, true) end
	send(board, "stop", { resetId = state.resetId, run = state.run, reason = "Fallback" })
	board.lockstep = nil
	state.fallback(state.spec.serial)
	return true
end

-- Once per server Heartbeat. Steps the host toward the client's reported tick (or to the end when
-- the server drives), applying queued inputs at their ticks. Returns true when published state
-- changed (init.server.lua then calls publishState).
function Host.advance(board, now, dt, hooks)
	local state = board.lockstep
	if not state or board.closing then return false end
	local host = state.host
	local hb = host.board
	if not state.hello and not state.closed and state.fallback and hb.tick == 0 and state.head > state.tail
		and now - state.stats.startedAt >= L.HelloSeconds then
		return fallBack(board, state, now)
	end
	-- What publishState shows (fixed length: hb.armed may be nil).
	local before = { hb.drops, host.merges, host.phase, host.stage, host.progress, Sim.canDrop(hb), host.itemSeq, #host.belt, hb.armed or "", host.paused, host.over }
	-- Clock guards. `wall`: the wall-clock estimate of the client's tick (running time x 156, only
	-- while the host runs). `allow`: what the server may step to, minus the 1 s lead; it follows
	-- `wall`, never banks more than 3 s past the reports (a stall), and regrows after a stall at
	-- most 5% faster than wall time. So steps never pass wall + 1 s (the speed-up spec checks it).
	if not host.paused and not host.over then
		state.wall += dt * TPS
		state.allow += dt * TPS * L.RateSlack
		-- B4 server-run: the server's own clock (never banks more than the 1 s lead past its tick).
		if state.serverRun then state.runTick = math.min(state.runTick + dt * TPS, hb.tick + L.LeadTicks) end
	end
	state.allow = math.min(state.allow, state.wall, math.max(state.reported, hb.tick) + L.StallTicks)
	-- Stalled: running (not paused, not over) and no new reported tick for StallSeconds (code review:
	-- decided on wall time since the last report, never from the allowance).
	if host.paused or host.over or state.serverDriven or state.serverRun then state.lastReportAt = now end
	if now - state.lastReportAt >= L.StallSeconds then
		if not state.stalledAt then
			state.stalledAt = now
			state.stats.stalls += 1
		end
	else
		state.stalledAt = nil
	end
	local behind = state.allow - state.reported
	if behind > state.stats.maxBehind then state.stats.maxBehind = behind end
	local changed = false
	if not host.over then
		local target = if state.serverDriven then math.huge
			elseif state.serverRun then math.floor(state.runTick)
			else math.min(state.reported, state.allow + L.LeadTicks)
		if not state.serverRun and state.reported > target then state.stats.throttled += 1 end
		local steps = 0
		while true do
			local input = state.pending[state.head]
			while input and input.tick <= hb.tick do
				state.pending[state.head] = nil
				state.head += 1
				applyInput(board, state, input, hooks)
				state.lastProgressAt = now
				input = state.pending[state.head]
			end
			if state.serverDriven and host.paused and not host.over then
				-- The session is closed: the server resumes with its own input.
				RoundSim.apply(host, { n = host.lastN + 1, tick = hb.tick, kind = "resume" })
			elseif state.serverRun and not host.over and state.head > state.tail then
				-- B4 server-run: pauses follow the board (Room, menus), as today's path froze it
				-- (architect review: a round paused at the fallback must resume).
				local want = board.mode ~= "Board" or board.menuPaused == true
				if host.paused ~= want then
					state.lastN = math.max(state.lastN, host.lastN) + 1
					state.lastTick = math.max(state.lastTick, hb.tick)
					RoundSim.apply(host, { n = state.lastN, tick = hb.tick, kind = if want then "pause" else "resume" })
				end
			end
			if host.over or host.paused or hb.tick >= target or steps >= L.MaxStepsPerFrame then break end
			local stepped = RoundSim.step(host)
			if not stepped then break end
			steps += 1
			Net.stepped(board)
			if not state.serverDriven and hb.tick > state.wall + L.LeadTicks + 1 then state.stats.overLead = (state.stats.overLead or 0) + 1 end
			events(board, state, stepped, hooks)
			if hb.tick % 60 == 0 and studio then state.stats.hashes[tostring(hb.tick)] = L.hash(host) end
			-- B4: the checkpoint right after the step that reached the tick (before inputs at it).
			if hb.tick % L.HashTicks == 0 and not state.closed then state.checkpoint = { tick = hb.tick, hash = L.hash(host) } end
		end
		if steps > state.stats.maxSteps then state.stats.maxSteps = steps end
		-- Server-run drops still queued when the round ends: today's refusal ack (the ghost fades).
		if state.serverRun and host.over then
			for index = state.head, state.tail do
				local input = state.pending[index]
				if input and input.token then Net.ack(board, board.player, input.token, false, "RoundOver") end
				state.pending[index] = nil
			end
			state.head, state.tail = 1, 0
		end
		if steps > 0 then state.lastProgressAt = now end
		-- An explicit head/tail queue (consumed slots are nil, so `#` is not usable).
		if state.head > state.tail then state.head, state.tail = 1, 0 end
	end
	-- Timeouts (B2-plan.md): never on a paused-in-Room board, as today a field waits there.
	if not host.over and not state.serverDriven and not state.serverRun and board.mode == "Board" then
		if host.phase == "Settling" and state.stalledAt and now - state.stalledAt >= L.SettleTakeoverSeconds then
			takeOver(board, state, "Stalled")
		elseif now - state.lastProgressAt >= (if host.paused then L.PausedIdleSeconds else L.IdleSeconds) then
			if host.phase == "Settling" then takeOver(board, state, "Idle")
			else
				takeOver(board, state, "Idle")
				if L.idleFinishes(hb.drops) then RoundSim.finish(host) end
			end
		end
	elseif board.mode ~= "Board" then
		state.lastProgressAt = now
	end
	-- Reveal: the next slots past the server's drops plus up to 2 drops already queued.
	local slice = revealTo(board, state, hb.drops + math.min(state.queuedDrops, L.RevealQueued) + L.Reveal)
	if slice and not state.closed then
		slice.resetId, slice.run = state.resetId, state.run
		send(board, "reveal", slice)
	end
	-- B4 verify: the latest checkpoint hash, and once the round's end hash (architect review: a
	-- divergence in the last ticks is caught either way). A client whose host ended at a tick the
	-- server reached without ending gets the server's state.
	if not state.closed then
		local checkpoint = state.checkpoint
		if checkpoint then
			state.checkpoint = nil
			state.stats.hashesSent += 1
			send(board, "hash", { resetId = state.resetId, run = state.run, tick = checkpoint.tick, hash = checkpoint.hash })
		end
		if host.over and not state.overHashSent then
			state.overHashSent = true
			send(board, "hash", { resetId = state.resetId, run = state.run, tick = hb.tick, hash = L.hash(host), over = true })
		end
		local overTick = state.clientOverTick
		if overTick and not host.over and hb.tick >= overTick and state.clientOverHandled ~= overTick then
			state.clientOverHandled = overTick
			state.stats.overMismatch += 1
			state.wantState = true
		end
		-- Rollback: the full state, at most one per ResyncSeconds and MaxResyncs per round; past
		-- that (or a state that cannot be encoded) the round falls back to the server-run path.
		if state.wantState then
			if state.resyncs >= L.MaxResyncs and host.over then
				-- Code review: a finished round never falls back (its result stands); no more states.
				state.wantState = false
			elseif state.resyncs >= L.MaxResyncs then
				desyncFallback(board, state, "Desync")
				changed = true
			elseif now - state.lastStateAt >= L.ResyncSeconds then
				state.wantState = false
				if sendState(board, state, now) then
					state.resyncs += 1
				else
					desyncFallback(board, state, "StateFail")
					changed = true
				end
			elseif not state.deferredAt then
				state.deferredAt = now
				state.stats.deferred += 1
			end
			if not state.wantState then state.deferredAt = nil end
		end
	end
	-- After the end, one last copy is enough (code review: no per-Heartbeat garbage on a finished board).
	if not state.syncedOver then sync(board, state) end
	if host.over and state.overHandled then state.syncedOver = true end
	local after = { hb.drops, host.merges, host.phase, host.stage, host.progress, Sim.canDrop(hb), host.itemSeq, #host.belt, hb.armed or "", host.paused, host.over }
	for index = 1, 11 do
		if before[index] ~= after[index] then changed = true; break end
	end
	if host.over and not state.overHandled then
		state.overHandled = true
		state.final = L.hash(host)
		state.result = RoundSim.result(host)
		if hooks.over then hooks.over(board.player, board, state.result) end
		changed = true
	end
	if studio then Host.publishStats(board, now) end
	return changed
end

-- B3: the owner's snapshot stream (BoardNet.publish) is off while its client draws its own host
-- (an open session that has said hello); on today's path, before the hello and after a takeover it runs.
function Host.streaming(board)
	local state = board.lockstep
	return not (state and state.hello and not state.closed)
end

-- B4: the owner's BoardMerge events. On a live session its mirror already played every merge, so
-- they only feed the Studio merge counter; before the hello and after a takeover / fallback (the
-- released round draws the server again) they are needed.
function Host.mergeEvents(board)
	return studio or Host.streaming(board)
end

-- ── Studio stats (specs read the board folder attribute ClientSimStats) ──

function Host.stats(board)
	local state = board.lockstep
	if not state then return nil end
	local host = state.host
	local out = table.clone(state.stats)
	out.resetId, out.run, out.tick, out.reported, out.allow = state.resetId, state.run, host.board.tick, state.reported, state.allow
	out.wall = state.wall
	out.revealed, out.lastN, out.pending = state.revealed, state.lastN, state.tail - state.head + 1
	out.paused, out.hello = host.paused, state.hello
	out.resyncs, out.serverRun, out.joinCount = state.resyncs, state.serverRun, state.joins
	local nextInput = state.pending[state.head]
	out.nextInput = nextInput and (nextInput.kind .. "@" .. nextInput.tick .. "#" .. nextInput.n) or nil
	out.over, out.final, out.result, out.closed = host.over, state.final, state.result, state.closed
	out.hash = L.hash(host)
	out.stalled = state.stalledAt ~= nil
	out.wallSeconds = os.clock() - state.stats.startedAt
	local payout = board.earnedPayout
	if payout and state.result and payout.sequence == state.run then
		local r, s = state.result, payout.summary
		out.payout = { amount = payout.amount, success = s.success, score = s.score, chain = s.chain, clears = s.clears,
			drops = s.drops, merges = s.merges, maxTier = s.maxTier, itemsUsed = s.itemsUsed, itemKinds = s.itemKinds, goalsMet = s.goalsMet }
		out.payoutMatch = payout.amount == r.reward and s.success == r.success and s.score == r.score and s.chain == r.peakChain
			and s.clears == r.clears and s.drops == r.drops and s.merges == r.merges and s.maxTier == r.maxTier
			and s.itemsUsed == r.itemsUsed and s.itemKinds == r.itemKinds and s.goalsMet == r.goalsMet and s.heat == r.heat
			and s.templateId == r.templateId
	end
	out.rewardStatus = board.folder:GetAttribute("RewardStatus")
	return out
end

function Host.publishStats(board, now, force)
	local state = board.lockstep
	if not state or not studio then return end
	if not force and state.statsAt and now - state.statsAt < 0.25 and not (state.host.over and not state.statsFinal) then return end
	state.statsAt = now
	if state.host.over then state.statsFinal = true end
	local ok, encoded = pcall(HttpService.JSONEncode, HttpService, Host.stats(board))
	if ok then board.folder:SetAttribute("ClientSimStats", encoded) end
end

-- ── Mount ─────────────────────────────────────────────────────────────────

-- The remote exists only in Studio or with the flag on. boardOf(player) -> the player's board.
function Host.mount(remotes, boardOf)
	if not (studio or Flags.DeckClientSim == true or Flags.DeckClientSimTesters == true) then return nil end
	remote = remotes:FindFirstChild(L.RemoteName) or Instance.new("RemoteEvent")
	remote.Name = L.RemoteName
	remote.Parent = remotes
	remote.OnServerEvent:Connect(function(player, packet)
		local board = boardOf(player)
		if not board or board.closing then return end
		local ok, problem = pcall(Host.receive, board, packet, os.clock())
		if not ok then
			warn("[ClientSim] message handler failed:", problem)
			if board.lockstep then count(board.lockstep.stats.refused, "Error") end
		end
	end)
	return remote
end

return Host
