-- B4 verify / rollback / rejoin spec (artifacts/qa-2026-11-17-v887/B4-plan.md). Studio Client.
-- Setup as ClientSimLockstep.spec.lua (DeckNetHarness H.setup(), a tidy win for items, Server
-- execute_luau `game.ServerStorage:SetAttribute("DeckClientSim", true)`). Copy this and
-- ClientSimLockstep.spec.lua to src/client/ZZSpecs/ (ClientSimRollback.lua, ClientSimLockstep.lua),
-- restart Play, then from a Client execute_luau (poll _G.B4SpecStatus / _G.B4SpecLines):
--   local S = require(PlayerScripts.Client.ZZSpecs.ClientSimRollback)
--   task.spawn(function() _G.B4Spec = S.run({ "desync0", "desync06", "repeated", "rejoin", "soak0_1", "soak0_5",
--     "soak06_1", "soak06_5", "soakJ_1", "soakJ_5" }) end)
-- desync: a forced desync (the client host's newest ball moved 1.5 studs) is found by the server's
-- checkpoint hash, restored and replayed: recovery time (perturb -> swap), the largest drawn ease per
-- frame (<= 0.5 studs), pops, then the round's verdict (client = server hashes and final, payout).
-- repeated: a desync every Heartbeat: 3 resyncs, then the fallback (stop Desync) and the rest of the
-- round on today's path (BoardRequest drops), payout = the host's result. rejoin: the driver forgets its
-- round mid-play (a reload), joins, continues; the verdict as above. soak: full rounds under lag with
-- loss-like spikes (each 0.1 s, chance p: +0.5 s incoming lag for 0.2 s): 0 mismatches.
local Players = game:GetService("Players")
local RS = game:GetService("RunService")
local Http = game:GetService("HttpService")
local ReplicatedStorage = game:GetService("ReplicatedStorage")

local S = {}
local player = Players.LocalPlayer
local gui = player:WaitForChild("PlayerGui")
local board = ReplicatedStorage:WaitForChild("EggDropBoards"):WaitForChild(tostring(player.UserId))
local req = ReplicatedStorage:FindFirstChild("BoardRequest", true)
local net = settings().Network
local LS = require(script.Parent.ClientSimLockstep)

local function status(text) _G.B4SpecStatus = text end
local function hook() return gui:WaitForChild("EggDropClientSim", 10) end
local function cs() return hook():Invoke("stats") end
local function ss()
	local raw = board:GetAttribute("ClientSimStats")
	if not raw then return nil end
	local ok, value = pcall(Http.JSONDecode, Http, raw)
	return if ok then value else nil
end
local function waitFor(check, seconds)
	local t = os.clock()
	while not check() and os.clock() - t < seconds do RS.Heartbeat:Wait() end
	return check()
end
local function fmt(map)
	local parts = {}
	for k, v in pairs(map or {}) do table.insert(parts, k .. "=" .. tostring(v)) end
	table.sort(parts)
	return "{" .. table.concat(parts, ",") .. "}"
end

-- Lag with loss-like spikes. base: number or {lo, hi} (jitter); spike: chance per 0.1 s.
local lagOn = false
local function lag(base, spike)
	lagOn = false
	task.wait(0.2)
	net.IncomingReplicationLag = 0
	if base == nil then return end
	lagOn = true
	task.spawn(function()
		local r = Random.new(5)
		local current = if type(base) == "table" then base[1] else base
		local nextJitter, spikeUntil = 0, 0
		while lagOn do
			local now = os.clock()
			if type(base) == "table" and now >= nextJitter then
				current = r:NextNumber(base[1], base[2])
				nextJitter = now + r:NextNumber(0.05, 0.15)
			end
			if spike and spike > 0 and now >= spikeUntil and r:NextNumber() < spike then spikeUntil = now + 0.2 end
			net.IncomingReplicationLag = current + (if now < spikeUntil then 0.5 else 0)
			task.wait(0.1)
		end
		net.IncomingReplicationLag = 0
	end)
end

local function rollbackLine(c, s)
	local m = c.mirror or {}
	return string.format("verify checks=%d matched=%d mismatches=%d skipped=%d missing=%d wants=%d states=%d restoreBad=%s"
		.. " replays=%d rollbacks=%d abandoned=%d replaySteps=%d stepsFrameMax=%d framesMax=%d recoverMs=%s"
		.. " | mirror corrections=%s offsetMax=%.2f corrMaxFrame=%.3f easing=%s pops +%s -%s far=%s"
		.. " | server hashesSent=%s wants=%s statesSent=%s stateBytes=%s resyncs=%s deferred=%s overMismatch=%s joins=%s serverRun=%s takeover=%s",
		c.checks or 0, c.matched or 0, c.mismatches or 0, c.skipped or 0, c.missing or 0, c.wants or 0, c.states or 0, fmt(c.restoreBad),
		c.replays or 0, c.rollbacks or 0, c.abandoned or 0, c.replaySteps or 0, c.replayStepsFrameMax or 0, c.replayFramesMax or 0,
		table.concat((function() local t = {} for _, v in ipairs(c.recoverMs or {}) do table.insert(t, string.format("%.0f", v)) end return t end)(), "/"),
		tostring(m.corrections), m.offsetMax or 0, m.corrMaxFrame or 0, tostring(m.easing), tostring(m.popAdded), tostring(m.popRemoved), tostring(m.popFar),
		tostring(s.hashesSent), tostring(s.wants), tostring(s.statesSent), tostring(s.stateBytes), tostring(s.resyncs), tostring(s.deferred),
		tostring(s.overMismatch), tostring(s.joinCount), tostring(s.serverRun), tostring(s.takeover))
end

local scenarios = {}

-- A forced desync at the 6th drop. Recovery = perturb -> corrected host swapped in.
local function desync(base)
	return function(random)
		lag(base)
		task.wait(1)
		local note, ok = "", true
		LS.play(random, { at = function(drops)
			if drops ~= 6 then return end
			waitFor(function() local c = cs(); return not c.wanting and not c.replaying end, 3)
			hook():Invoke("mirrorReset")
			local before = cs().rollbacks or 0
			hook():Invoke("perturb", 1.5)
			waitFor(function() return (cs().rollbacks or 0) > before end, 8)
			local c = cs()
			local recover = if c.lastRollbackAt and c.perturbAt then (c.lastRollbackAt - c.perturbAt) * 1000 else -1
			-- Lag: the server's hash and the client's request are two round trips (lag each way).
			local limit = 500 + base * 4000
			ok = (c.rollbacks or 0) > before and recover >= 0 and recover <= limit
			note = string.format("perturb at tick %s, recovered in %.0f ms (limit %.0f), replay %s",
				tostring(c.perturbTick), recover, limit, if c.lastReplay then string.format("%d->%d %d steps %d frames", c.lastReplay.from, c.lastReplay.to, c.lastReplay.steps, c.lastReplay.frames) else "-")
		end })
		lag(nil)
		local pass, line = LS.verdict("desync " .. tostring(base), { note = note })
		local c, s = cs(), ss() or {}
		local m = c.mirror or {}
		pass = pass and ok and (m.corrMaxFrame or 1) <= 0.5 + 1e-9 and (c.mismatches or 0) >= 1 and not s.serverRun
		return pass, (pass and "PASS" or "FAIL") .. " " .. line:gsub("^%a+ ", "", 1) .. " | " .. rollbackLine(c, s)
	end
end
scenarios.desync0 = desync(0)
scenarios.desync06 = desync(0.6)

-- A desync every Heartbeat from the 5th drop: three full states, then the fallback; the rest of
-- the round through today's BoardRequest drops on the server-run host.
scenarios.repeated = function(random)
	local note, fellBack = "", false
	LS.play(random, { at = function(drops)
		if drops ~= 5 then return end
		hook():Invoke("perturbEvery", 0.4)
		fellBack = waitFor(function() return not cs().active end, 20)
		hook():Invoke("perturbEvery", nil)
	end })
	hook():Invoke("perturbEvery", nil)
	local c0 = cs()
	local today = 0
	local deadline = os.clock() + 120
	while os.clock() < deadline and not board:GetAttribute("RoundOver") and (board:GetAttribute("Drops") or 0) < 24 do
		if board:GetAttribute("FieldReady") then
			req:FireServer("drop", random:NextInteger(0, 400) / 400)
			today += 1
		end
		task.wait(random:NextNumber(0.25, 0.5))
	end
	waitFor(function() local s = ss(); return s and s.over and (s.payout ~= nil or s.rewardStatus == "Refused") end, 40)
	local s = ss() or {}
	local sr = s.result or {}
	local pass = fellBack and c0.stopped == "Desync" and s.serverRun == true and s.takeover == "Desync" and s.resyncs == 3
		and s.over == true and s.payoutMatch == true
	note = string.format("fellBack=%s stopped=%s today drops sent=%d serverInputs=%s lateClientInputs=%s result reward=%s score=%s drops=%s reason=%s payoutMatch=%s",
		tostring(fellBack), tostring(c0.stopped), today, tostring(s.serverInputs), tostring(s.lateClientInputs), tostring(sr.reward), tostring(sr.score),
		tostring(sr.drops), tostring(sr.reason), tostring(s.payoutMatch))
	return pass, string.format("%s repeated desync | %s | %s", pass and "PASS" or "FAIL", note, rollbackLine(c0, s))
end

-- The driver forgets its round at the 7th drop (a reload) and joins the open session.
scenarios.rejoin = function(random)
	local note, ok = "", true
	LS.play(random, { at = function(drops)
		if drops ~= 7 then return end
		task.wait(0.3)
		local t0 = os.clock()
		hook():Invoke("forget")
		local joined = waitFor(function() local c = cs(); return c.active and not c.joining and (c.joins or 0) >= 1 end, 10)
		local c = cs()
		ok = joined
		note = string.format("forgot, joined=%s in %.0f ms (joinsSent=%s joins=%s), tick %s", tostring(joined), (os.clock() - t0) * 1000,
			tostring(c.joinsSent), tostring(c.joins), tostring(c.tick))
	end })
	local pass, line = LS.verdict("rejoin", { note = note, expected = { "Stale" } })
	local c, s = cs(), ss() or {}
	pass = pass and ok and s.joinCount == 1 and (c.mismatches or 0) == 0
	return pass, (pass and "PASS" or "FAIL") .. " " .. line:gsub("^%a+ ", "", 1) .. " | " .. rollbackLine(c, s)
end

local function soak(base, spike)
	return function(random)
		lag(base, spike)
		task.wait(1)
		LS.play(random)
		lag(nil)
		local label = (if type(base) == "table" then "jitter " .. base[1] .. "-" .. base[2] else "lag " .. tostring(base)) .. " spikes " .. tostring(spike * 100) .. "%"
		local pass, line = LS.verdict("soak " .. label)
		local c, s = cs(), ss() or {}
		pass = pass and (c.mismatches or 0) == 0 and (c.rollbacks or 0) == 0 and (c.matched or 0) > 0
		return pass, (pass and "PASS" or "FAIL") .. " " .. line:gsub("^%a+ ", "", 1) .. " | " .. rollbackLine(c, s)
	end
end
scenarios.soak0_1 = soak(0, 0.01)
scenarios.soak0_5 = soak(0, 0.05)
scenarios.soak06_1 = soak(0.6, 0.01)
scenarios.soak06_5 = soak(0.6, 0.05)
scenarios.soakJ_1 = soak({ 0.1, 0.8 }, 0.01)
scenarios.soakJ_5 = soak({ 0.1, 0.8 }, 0.05)

function S.run(list, seed)
	local random = Random.new(seed or 31)
	local lines, allPass = {}, true
	for index, name in ipairs(list) do
		status(string.format("%d/%d %s: fresh round", index, #list, name))
		if not LS.fresh() then
			table.insert(lines, "FAIL " .. name .. ": no fresh lockstep round (is ServerStorage.DeckClientSim on?)")
			allPass = false
			_G.B4SpecLines = lines
			continue
		end
		status(string.format("%d/%d %s: playing", index, #list, name))
		local ok, pass, line = pcall(scenarios[name], random)
		if not ok then pass, line = false, "FAIL " .. name .. " errored: " .. tostring(pass) end
		hook():Invoke("perturbEvery", nil)
		allPass = allPass and pass
		table.insert(lines, line)
		_G.B4SpecLines = lines
	end
	lag(nil)
	status("done")
	return (allPass and "ALL PASS" or "SOME FAILED") .. "\n" .. table.concat(lines, "\n")
end

return S
