-- B2 lockstep end-to-end + exploit spec (artifacts/qa-2026-11-17-v887/B2-plan.md). Studio Client.
-- Setup: Server execute_luau `game.ServerStorage:SetAttribute("DeckClientSim", true)`; a save that
-- owns a pet and is on a field (DeckNetHarness H.setup()). Copy to src/client/ZZSpecs/ClientSimLockstep.lua,
-- restart Play, then from a Client execute_luau (task.spawn it; poll _G.B2Spec / _G.B2SpecStatus):
--   local S = require(PlayerScripts.Client.ZZSpecs.ClientSimLockstep)
--   task.spawn(function() _G.B2Spec = S.run({ "lag0", "lag06", "jitter", "speed", "stall", "blackout", "raw" }) end)
-- Each scenario plays one real field round through the game's ClientRoundDriver (PlayerGui
-- bindable EggDropClientSim; every 4th tap through the deck's own dropEgg via DeckNetTestTap) and
-- compares the server's lockstep stats (board attribute ClientSimStats, Studio only) with the client's.
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
local TPS = 156

local function status(text) _G.B2SpecStatus = text end
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
local function count(map)
	local n = 0
	for _, v in pairs(map or {}) do n += v end
	return n
end
local function fmt(map)
	local parts = {}
	for k, v in pairs(map or {}) do table.insert(parts, k .. "=" .. tostring(v)) end
	table.sort(parts)
	return "{" .. table.concat(parts, ",") .. "}"
end

-- Lag: nil/number, or {lo, hi} re-drawn every 50-150 ms (jitter).
local lagRunning = false
local function setLag(lag)
	lagRunning = false
	task.wait()
	if type(lag) == "table" then
		lagRunning = true
		task.spawn(function()
			local r = Random.new(7)
			while lagRunning do net.IncomingReplicationLag = r:NextNumber(lag[1], lag[2]); task.wait(r:NextNumber(0.05, 0.15)) end
		end)
	else
		net.IncomingReplicationLag = lag or 0
	end
end

-- A fresh lockstep round: reset (over) / restart (dropped) / heat rebuild (fresh but old path).
function S.fresh(heat)
	for attempt = 1, 6 do
		local c, s = cs(), ss()
		local run = board:GetAttribute("RunSequence")
		if c.active and not c.over and c.run == run and (c.drops or 0) == 0 and s and s.run == run then
			if not heat or board:GetAttribute("RunHeat") == heat or attempt > 4 then return true end
		end
		waitFor(function() return board:GetAttribute("RewardStatus") ~= "Saving" end, 15)
		if board:GetAttribute("RoundOver") then
			req:FireServer("reset", run)
		elseif (board:GetAttribute("Drops") or 0) > 0 then
			req:FireServer("restart", run)
		else
			-- Heat change before the first drop rebuilds the field (HeatRequest "Rebuild").
			local now = board:GetAttribute("RunHeat")
			req:FireServer("heat", heat or (if now == "medium" then "easy" else "medium"))
		end
		waitFor(function() return board:GetAttribute("RunSequence") ~= run end, 5)
		task.wait(3.2) -- Config.ResetInterval between rebuilds
	end
	local c = cs()
	return c.active and not c.over and c.run == board:GetAttribute("RunSequence")
end

local tapCount = 0
local function tap(aim)
	tapCount += 1
	if tapCount % 4 == 0 then
		-- The deck's own dropEgg (init.client.lua Studio hook), gated by the deck UI as a finger is.
		local before = cs().sent
		gui:SetAttribute("DeckNetTestAim", aim)
		gui:SetAttribute("DeckNetTestTap", (gui:GetAttribute("DeckNetTestTap") or 0) + 1)
		return cs().sent > before
	end
	return hook():Invoke("drop", aim) == true
end

local function useItem()
	local c = cs()
	local id = c.belt and c.belt[1]
	if not id or c.armed then return false end
	return hook():Invoke("item", id) == true
end

-- Plays the live round to its end. hooks.at(drops) runs once per new drop count (exploits).
local function play(random, hooks)
	hooks = hooks or {}
	local deadline = os.clock() + 150
	local mash = random:NextNumber() < 0.5
	local paused, seen = false, -1
	while os.clock() < deadline do
		local c = cs()
		if c.over or not c.active or (c.drops or 0) >= 24 then break end
		if c.drops ~= seen then
			seen = c.drops
			if hooks.at then hooks.at(c.drops) end
			c = cs()
			if c.over or not c.active then break end
		end
		local aim = random:NextInteger(0, 400) / 400
		local before = c.drops
		if not mash then task.wait(random:NextNumber(0.05, 0.7)) end
		waitFor(function()
			local now = cs()
			if now.over or not now.active or now.drops > before then return true end
			tap(aim)
			return false
		end, 4)
		if random:NextNumber() < 0.5 then useItem() end
		if not paused and (cs().drops or 0) >= 12 then
			paused = true
			hook():Invoke("pause", true); task.wait(0.4)
			useItem(); task.wait(0.3)
			hook():Invoke("pause", false)
		end
	end
	waitFor(function() return cs().over == true or not cs().active end, 30)
end

-- Compares the finished round on both sides.
local function verdict(label, extra)
	extra = extra or {}
	local c = cs()
	waitFor(function() local s = ss(); return s and s.over and (s.payout ~= nil or s.rewardStatus == "Refused") end, 40)
	waitFor(function() local now = cs(); return (now.unacked or 0) == 0 end, 5)
	local s = ss() or {}
	c = cs()
	local hashOk, compared, firstBad = true, 0, nil
	for tick, hash in pairs(c.hashes or {}) do
		local other = s.hashes and s.hashes[tick]
		if other then
			compared += 1
			if other ~= hash then hashOk = false; firstBad = firstBad or tick end
		end
	end
	local resultOk, diffs = true, {}
	local cr, sr = c.result or {}, s.result or {}
	for _, key in ipairs({ "success", "reward", "score", "merges", "peakChain", "clears", "drops", "maxTier", "itemsUsed", "itemKinds", "goalsMet", "overTick", "reason" }) do
		if cr[key] ~= sr[key] then resultOk = false; table.insert(diffs, key .. ":" .. tostring(cr[key]) .. "/" .. tostring(sr[key])) end
	end
	local refused = table.clone(s.refused or {})
	for _, reason in ipairs(extra.expected or {}) do refused[reason] = nil end
	local rule = count(s.rule)
	local legit = count(refused) == 0 and rule == (c.latched or 0)
	local finalOk = c.final ~= nil and c.final == s.final
	local pass = finalOk and hashOk and resultOk and s.payoutMatch == true and legit and (extra.ok == nil or extra.ok)
	local line = string.format("%s %s final c=%s s=%s hashes=%d/%s result=%s payoutMatch=%s reward=%s score=%s merges=%s drops=%s goals=%s tidy/reason=%s"
		.. " | sent=%d accepted=%d latched=%d localRefused=%s | server applied=%d batches=%d resent=%d refused=%s rule=%s throttled=%d stalls=%d maxBehind=%.0f maxSteps=%d%s",
		pass and "PASS" or "FAIL", label, tostring(c.final), tostring(s.final), compared, hashOk and "ok" or ("BAD@" .. tostring(firstBad)),
		resultOk and "same" or table.concat(diffs, ","), tostring(s.payoutMatch), tostring(sr.reward), tostring(sr.score), tostring(sr.merges),
		tostring(sr.drops), tostring(sr.goalsMet), tostring(sr.reason), c.sent or 0, c.accepted or 0, c.latched or 0, fmt(c.localRefused),
		s.applied or 0, s.batches or 0, s.resent or 0, fmt(s.refused), fmt(s.rule), s.throttled or 0, s.stalls or 0, s.maxBehind or 0, s.maxSteps or 0,
		extra.note and (" | " .. extra.note) or "")
	return pass, line
end

local scenarios = {}

local function plain(lag)
	return function(random)
		setLag(lag)
		task.wait(1)
		play(random)
		setLag(0)
		return verdict(type(lag) == "table" and ("jitter " .. lag[1] .. "-" .. lag[2]) or ("lag " .. tostring(lag)))
	end
end
scenarios.lag0 = plain(0)
scenarios.lag06 = plain(0.6)
scenarios.jitter = plain({ 0.1, 0.8 })

-- 2x clock for 2.5 s: the server must step at <= 1.05x wall + 1 s lead and the round must survive.
scenarios.speed = function(random)
	local note, ok = "", true
	play(random, { at = function(drops)
		if drops ~= 4 then return end
		local s0, t0 = ss(), os.clock()
		hook():Invoke("rate", 2)
		local worst = 0
		while os.clock() - t0 < 2.5 do
			task.wait(0.25)
			local s = ss()
			local rate = (s.tick - s0.tick) / (os.clock() - t0)
			if rate > worst then worst = rate end
		end
		hook():Invoke("rate", 1)
		local s1 = ss()
		-- The server may step to its allowance + 1 s lead, never past the wall estimate + 1 s.
		local bound = (s0.allow + TPS - s0.tick) + (os.clock() - t0) * TPS * 1.05 + 20
		ok = (s1.tick - s0.tick) <= bound and (s1.throttled or 0) > (s0.throttled or 0) and s1.tick <= s1.wall + TPS + 1
			and (s1.overLead or 0) == 0
		note = string.format("speed: server +%d ticks in %.2f s (bound %.0f), client +%d, lead over wall %.0f ticks, throttled %d -> %d, overLead %d",
			s1.tick - s0.tick, os.clock() - t0, bound, cs().tick - s0.reported, s1.tick - s1.wall, s0.throttled or 0, s1.throttled or 0, s1.overLead or 0)
	end })
	return verdict("speed-up 2x", { ok = ok, note = note, expected = { "Ahead" } })
end

-- Freeze 5 s (no steps, no messages): stalled like a disconnect, then the round resumes.
scenarios.stall = function(random)
	local note, ok = "", true
	play(random, { at = function(drops)
		if drops ~= 5 then return end
		local s0 = ss()
		hook():Invoke("freeze", true)
		task.wait(5)
		local s1 = ss()
		hook():Invoke("freeze", false)
		ok = s1.stalled == true and (s1.stalls or 0) > (s0.stalls or 0) and not s1.over
		note = string.format("stall: stalled=%s stalls %d -> %d, server tick %d -> %d (allow %.0f, reported %d)",
			tostring(s1.stalled), s0.stalls or 0, s1.stalls or 0, s0.tick, s1.tick, s1.allow or -1, s1.reported or -1)
	end })
	return verdict("stall 5 s", { ok = ok, note = note })
end

-- Send blackouts of 2 s and 5 s (the client keeps playing) and a Room round trip.
scenarios.blackout = function(random)
	local notes = {}
	play(random, { at = function(drops)
		if drops == 3 or drops == 8 then
			local seconds = if drops == 3 then 2 else 5
			hook():Invoke("hold", true)
			local t = os.clock()
			while os.clock() - t < seconds do
				tap(random:NextInteger(0, 400) / 400)
				task.wait(0.3)
			end
			local released = hook():Invoke("hold", false)
			table.insert(notes, string.format("blackout %ds released %d messages", seconds, released))
		elseif drops == 14 then
			req:FireServer("mode", "Room")
			task.wait(2.5)
			local paused = cs().paused
			req:FireServer("mode", "Board")
			waitFor(function() return board:GetAttribute("Mode") == "Board" end, 4)
			task.wait(1)
			table.insert(notes, "room trip paused=" .. tostring(paused) .. " back=" .. tostring(board:GetAttribute("Mode")))
		end
	end })
	return verdict("blackout+room", { note = table.concat(notes, "; "), expected = { "Rate" } })
end

-- Raw malformed / hostile batches; every one refused by reason, the round unharmed.
scenarios.raw = function(random)
	local results, ok = {}, true
	play(random, { at = function(drops)
		if drops ~= 6 then return end
		waitFor(function() return (cs().unacked or 0) == 0 end, 3)
		local s0 = ss()
		local function try(name, mutate, want)
			local packet = hook():Invoke("current")
			mutate(packet)
			local before = ss().refused or {}
			hook():Invoke("raw", packet)
			task.wait(0.35)
			local after = ss()
			local got = (after.refused and after.refused[want] or 0) - (before[want] or 0)
			table.insert(results, string.format("%s->%s:%d", name, want, got))
			if got < 1 then ok = false end
		end
		local c = cs()
		try("outOfOrder", function(p) p.tick = math.max(0, ss().reported - 30) end, "Order")
		try("future", function(p) p.inputs = { { n = c.lastN + 1, tick = p.tick + 40, kind = "drop", aim = 200 } } end, "Future")
		try("ahead", function(p) p.tick += TPS * 10 end, "Ahead")
		try("oversized", function(p)
			p.inputs = {}
			for i = 1, 40 do p.inputs[i] = { n = c.lastN + i, tick = p.tick, kind = "pop" } end
		end, "Size")
		try("gap", function(p) p.inputs = { { n = cs().lastN + 5, tick = p.tick, kind = "pop" } } end, "Gap")
		try("late", function(p) p.inputs = { { n = cs().lastN + 1, tick = 0, kind = "pop" } } end, "Late")
		try("wrongReset", function(p) p.resetId += 1 end, "Stale")
		try("wrongRun", function(p) p.run += 1 end, "Stale")
		try("garbage", function(p) p.extra = string.rep("x", 100) end, "Malformed")
		try("badKind", function(p) p.inputs = { { n = cs().lastN + 1, tick = p.tick, kind = "win" } } end, "Malformed")
		-- A duplicate n (already queued) with other content is skipped, never applied.
		local applied0 = ss().applied
		local dup = hook():Invoke("current")
		if cs().lastN > 0 then
			dup.inputs = { { n = cs().lastN, tick = dup.tick, kind = "pop" } }
			hook():Invoke("raw", dup)
			task.wait(0.35)
		end
		local s1 = ss()
		table.insert(results, string.format("duplicate->resent:%d applied+%d", (s1.resent or 0) - (s0.resent or 0), s1.applied - applied0))
		-- A flood of 90 heartbeats in one frame.
		local flood = hook():Invoke("current")
		for _ = 1, 90 do hook():Invoke("raw", flood) end
		task.wait(0.5)
		local s2 = ss()
		table.insert(results, string.format("flood->Rate:%d", (s2.refused.Rate or 0) - (s1.refused.Rate or 0)))
		if (s2.refused.Rate or 0) - (s1.refused.Rate or 0) < 20 then ok = false end
	end })
	return verdict("raw exploits", { ok = ok, note = table.concat(results, " "),
		expected = { "Order", "Future", "Ahead", "Size", "Gap", "Late", "Stale", "Malformed", "Rate" } })
end

function S.run(list, seed)
	local random = Random.new(seed or 11)
	local lines, allPass = {}, true
	for index, name in ipairs(list) do
		status(string.format("%d/%d %s: fresh round", index, #list, name))
		if not S.fresh() then
			table.insert(lines, "FAIL " .. name .. ": no fresh lockstep round (is ServerStorage.DeckClientSim on?)")
			allPass = false
			continue
		end
		status(string.format("%d/%d %s: playing", index, #list, name))
		local ok, pass, line = pcall(scenarios[name], random)
		if not ok then pass, line = false, "FAIL " .. name .. " errored: " .. tostring(pass) end
		allPass = allPass and pass
		table.insert(lines, line)
		_G.B2SpecLines = lines
	end
	setLag(0)
	status("done")
	return (allPass and "ALL PASS" or "SOME FAILED") .. "\n" .. table.concat(lines, "\n")
end

-- B4 (ClientSimRollback.spec.lua) reuses the round player and the verdict.
S.play, S.verdict, S.setLag, S.tap = play, verdict, setLag, tap

return S
