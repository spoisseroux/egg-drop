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
-- Studio test knobs (exploit specs): rate multiplies the clock; freeze stops stepping and sending;
-- hold buffers outgoing messages (a send blackout) until released.
local test = { rate = 1, freeze = false, hold = false, held = {} }

local function newStats()
	return { sent = 0, messages = 0, accepted = 0, latched = 0, localRefused = {}, acks = 0, hashes = {}, steps = 0 }
end
local lastStats = newStats()

local function fire(packet)
	if test.hold then table.insert(test.held, packet); return end
	remote:FireServer(packet)
end

local function sendNow()
	local state = round
	if not state then return end
	local host = state.host
	local inputs, tick = {}, host.board.tick
	for index, input in ipairs(state.unacked) do
		if index > L.MaxBatchInputs then
			-- Truncated: report only up to the first input left out, so the server never passes it.
			tick = input.tick
			break
		end
		inputs[index] = input
	end
	fire({ resetId = state.resetId, run = state.run, tick = tick, inputs = inputs })
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
	if #state.unacked >= L.MaxUnacked then return refuseLocal(state, "Backlog") end
	input.n, input.tick = host.lastN + 1, host.board.tick
	local saved = { host.lastN, host.inputCount, host.tickInputsAt, host.tickInputs }
	local ok, result = RoundSim.apply(host, input)
	if not ok and result ~= "Full" and result ~= "Spawn" then
		host.lastN, host.inputCount, host.tickInputsAt, host.tickInputs = saved[1], saved[2], saved[3], saved[4]
		return refuseLocal(state, result)
	end
	if ok then state.stats.accepted += 1 else state.stats.latched += 1 end
	state.stats.sent += 1
	table.insert(state.unacked, input)
	sendNow()
	if view and view.input then view.input(state, input, ok, result) end
	return ok, result
end

local function active()
	return round ~= nil and not round.host.over
end

-- B3: a round exists but cannot take this tap (over, or no hello yet): refused here, never sent on
-- today's path. Nil when no lockstep round runs.
local function closedTap(state)
	if not state then return nil end
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
-- stop(state, reason). One view; attach(nil) detaches.
function Driver.attach(hooks) view = hooks end
function Driver.round() return round end
-- The fraction of a fixed step the clock has run past the last step (render interpolation);
-- 1 while paused or over (the last step is the drawn state).
function Driver.alpha()
	local state = round
	if not state or state.host.paused or state.host.over or test.freeze then return 1 end
	return math.clamp(state.acc / FIXED, 0, 1)
end
function Driver.sentCount() return lastStats.sent end

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
		round = {
			host = host, resetId = packet.resetId, run = packet.run, revealed = 0,
			unacked = {}, acc = 0, sentAt = -math.huge, startedAt = os.clock(), stats = newStats(),
		}
		lastStats = round.stats
		round.revealed = L.applyReveal(host, 0, packet.reveal)
		syncPause(round)
		sendNow()
		return
	end
	local state = round
	if not state or packet.resetId ~= state.resetId or packet.run ~= state.run then return end
	if kind == "reveal" then
		state.revealed = L.applyReveal(state.host, state.revealed, packet)
	elseif kind == "ack" then
		state.stats.acks += 1
		state.hello = true
		local n = packet.n
		if type(n) == "number" then
			while state.unacked[1] and state.unacked[1].n <= n do table.remove(state.unacked, 1) end
		end
	elseif kind == "stop" then
		state.stats.stopped = packet.reason
		round = nil
		if view and view.stop then view.stop(state, packet.reason) end
	end
end

-- ── Clock ─────────────────────────────────────────────────────────────────

local function onHeartbeat(dt)
	local state = round
	if not state or test.freeze then return end
	local host = state.host
	syncPause(state)
	if not host.over then
		state.acc = math.min(state.acc + dt * Config.Pace * test.rate, FIXED * MAX_FRAME_STEPS * math.max(1, test.rate))
		while state.acc >= FIXED do
			if view then view.beforeStep(state) end
			local events = RoundSim.step(host, if view then impacts else nil)
			if not events then state.acc = 0; break end
			if view then
				view.afterStep(state, events, impacts)
				table.clear(impacts)
			end
			state.acc -= FIXED
			state.stats.steps += 1
			if host.board.tick % 60 == 0 and studio then state.stats.hashes[tostring(host.board.tick)] = L.hash(host) end
			if host.over then
				state.final = L.hash(host)
				state.result = RoundSim.result(host)
				sendNow()
				break
			end
		end
	end
	local interval = if host.over then L.OverHeartbeatSeconds else L.HeartbeatSeconds
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
