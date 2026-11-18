-- B3 client render spec (artifacts/qa-2026-11-17-v887/B3-plan.md). Studio Client.
-- Setup as ClientSimLockstep.spec.lua (DeckNetHarness H.setup(), a tidy win for items, Server
-- execute_luau `game.ServerStorage:SetAttribute("DeckClientSim", true)`). Copy this, DeckNetHarness and
-- ClientSimLockstep to src/client/ZZSpecs/, restart Play, then from a Client execute_luau:
--   local S = require(PlayerScripts.Client.ZZSpecs.ClientBoardMirror)
--   task.spawn(function() _G.B3Spec = S.run({ 0, 0.6, { 0.1, 0.8 } }) end)   -- poll _G.B3SpecStatus
--   task.spawn(function() _G.B3Today = S.today({ 0, 0.6, { 0.1, 0.8 } }) end) -- override OFF: today's path
-- Each lockstep round is played through the deck's own dropEgg (Studio tap hook DeckNetTestTap) on a
-- phone-size deck (812x354). Measured: tap -> ball view (ms and frames), merge step -> merge juice
-- (ms and frames), RenderStepped frame time and the mirror's own per-frame cost, client = server final
-- hash, result and payout, settle / merge diffs (mirror vs server values), server refusals.
local Players = game:GetService("Players")
local RS = game:GetService("RunService")
local Http = game:GetService("HttpService")
local ReplicatedStorage = game:GetService("ReplicatedStorage")

local S = {}
local player = Players.LocalPlayer
local gui = player:WaitForChild("PlayerGui")
local board = ReplicatedStorage:WaitForChild("EggDropBoards"):WaitForChild(tostring(player.UserId))
local net = settings().Network
local specs = script.Parent
local H = require(specs.DeckNetHarness)
local LS = require(specs.ClientSimLockstep)

local function status(text) _G.B3SpecStatus = text end
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
local function lagLabel(lag) return if type(lag) == "table" then ("jitter " .. lag[1] .. "-" .. lag[2]) else ("lag " .. tostring(lag)) end

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

-- RenderStepped frame times while `fn` runs.
local function frames(fn)
	local list, last = {}, os.clock()
	local conn = RS.RenderStepped:Connect(function()
		local now = os.clock(); table.insert(list, (now - last) * 1000); last = now
	end)
	local a, b = fn()
	conn:Disconnect()
	local sorted = {}
	for i = 6, #list do table.insert(sorted, list[i]) end
	table.sort(sorted)
	local n, sum = #sorted, 0
	for _, v in ipairs(sorted) do sum += v end
	local summary = if n == 0 then "frames=0" else string.format("frames=%d mean=%.2f p50=%.2f p99=%.2f worst=%.1f ms",
		n, sum / n, sorted[math.ceil(n * .5)], sorted[math.ceil(n * .99)], sorted[n])
	return summary, a, b
end

local function deckTap(aim)
	gui:SetAttribute("DeckNetTestAim", aim)
	gui:SetAttribute("DeckNetTestTap", (gui:GetAttribute("DeckNetTestTap") or 0) + 1)
end

-- One lockstep round, every drop through the deck's dropEgg.
local function playRound(random)
	local deadline = os.clock() + 150
	local toBall, toBallFrames = {}, {}
	local seen = -1
	while os.clock() < deadline do
		local c = cs()
		if c.over or not c.active or (c.drops or 0) >= 24 then break end
		if c.drops ~= seen then seen = c.drops end
		local before = c.drops
		task.wait(random:NextNumber(0.05, 0.45))
		local aim = random:NextInteger(0, 400) / 400
		local frame0 = 0
		local counter = RS.RenderStepped:Connect(function() frame0 += 1 end)
		local tapAt
		local firstTry = os.clock()
		waitFor(function()
			local now = cs()
			if now.over or not now.active or now.drops > before then return true end
			-- A fresh round opens the difficulty picker, which takes the deck's A until the first
			-- drop: that one goes straight to the driver.
			if now.drops == 0 and os.clock() - firstTry > 0.8 then hook():Invoke("drop", aim); return false end
			local sent = gui:GetAttribute("DeckNetTapSent") or 0
			frame0 = 0
			deckTap(aim)
			if (gui:GetAttribute("DeckNetTapSent") or 0) > sent then tapAt = gui:GetAttribute("DeckNetTapAt") end
			return false
		end, 4)
		if tapAt then
			waitFor(function() local shown = gui:GetAttribute("DeckNetBallShownAt"); return shown and shown >= tapAt end, 1.5)
			local shown = gui:GetAttribute("DeckNetBallShownAt")
			if shown and shown >= tapAt then table.insert(toBall, (shown - tapAt) * 1000); table.insert(toBallFrames, frame0) end
		end
		counter:Disconnect()
		if random:NextNumber() < 0.4 then
			local now = cs()
			local id = now.belt and now.belt[1]
			if id and not now.armed then hook():Invoke("item", id) end
		end
	end
	waitFor(function() return cs().over == true or not cs().active end, 30)
	return toBall, toBallFrames
end

local function med(list)
	if #list == 0 then return -1, -1 end
	local c = table.clone(list); table.sort(c)
	return c[math.ceil(#c / 2)], c[#c]
end

function S.round(lag, random)
	if not LS.fresh() then return false, "FAIL " .. lagLabel(lag) .. ": no fresh lockstep round (override on?)" end
	hook():Invoke("mirrorReset")
	setLag(lag)
	task.wait(1)
	local frameLine, toBall, toBallFrames = frames(function() return playRound(random) end)
	setLag(0)
	waitFor(function() local s = ss(); return s and s.over and (s.payout ~= nil or s.rewardStatus == "Refused") end, 40)
	waitFor(function() return (cs().unacked or 0) == 0 end, 5)
	task.wait(1.5) -- the server's RoundOver reaches the mirror (settle)
	local c, s = cs(), ss() or {}
	local m = c.mirror or {}
	local diffs = {}
	local cr, sr = c.result or {}, s.result or {}
	for _, key in ipairs({ "success", "reward", "score", "merges", "peakChain", "clears", "drops", "maxTier", "itemsUsed", "itemKinds", "goalsMet", "overTick" }) do
		if cr[key] ~= sr[key] then table.insert(diffs, key) end
	end
	local refused = table.clone(s.refused or {})
	-- The last heartbeat of the previous round can reach the new session before its stop reaches
	-- the client (lag): an honest Stale, never an input.
	if (refused.Stale or 0) <= 2 then refused.Stale = nil end
	local legit = count(refused) == 0 and count(s.rule) == (c.latched or 0)
	local tb, tbx = med(toBall)
	local tf, tfx = med(toBallFrames)
	local mt, md = m.mergeDelayFrames or {}, m.mergeDelayMs or {}
	local settleDiffs = count(m.settle and m.settle.diffs)
	local pass = c.final ~= nil and c.final == s.final and #diffs == 0 and s.payoutMatch == true and legit
		and settleDiffs == 0 and (m.mergeDiffs or 0) == 0 and (m.mergeMissing or 0) == 0 and (m.settle and m.settle.checked or 0) >= 1
		and (mt.max or 0) <= 1 and (m.lateMerges or 0) == 0
	local line = string.format("%s B3 %s | tapToBall(deck hook) median=%.1f max=%.1f ms frames median=%s max=%s n=%d | mirror tapToBall ms=%s frames=%s"
		.. " | mergeDelay frames median=%s max=%s ms median=%.1f max=%.1f merges=%d late=%d | %s | mirror sync mean=%.0fus max=%.0fus"
		.. " | final c=%s s=%s result=%s payoutMatch=%s reward=%s score=%s merges=%s | settle checked=%s diffs=%s%s merge checked=%s diffs=%s missing=%s"
		.. " | impacts=%s grants=%s drops=%s retries=%s refused=%s rule=%s latched=%s localRefused=%s",
		pass and "PASS" or "FAIL", lagLabel(lag), tb, tbx, tostring(tf), tostring(tfx), #toBall,
		m.tapToBallMs and string.format("%.1f/%.1f", m.tapToBallMs.median, m.tapToBallMs.max) or "-",
		m.tapToBallFrames and string.format("%d/%d", m.tapToBallFrames.median, m.tapToBallFrames.max) or "-",
		tostring(mt.median), tostring(mt.max), md.median or -1, md.max or -1, m.merges or 0, m.lateMerges or 0,
		frameLine, m.syncMeanUs or 0, m.syncMaxUs or 0, tostring(c.final), tostring(s.final), #diffs == 0 and "same" or table.concat(diffs, ","),
		tostring(s.payoutMatch), tostring(sr.reward), tostring(sr.score), tostring(sr.merges),
		tostring(m.settle and m.settle.checked), fmt(m.settle and m.settle.diffs), m.settle and m.settle.last and (" (" .. m.settle.last .. ")") or "", tostring(m.mergeChecked), tostring(m.mergeDiffs), tostring(m.mergeMissing),
		tostring(m.impacts), tostring(m.grants), tostring(m.drops), tostring(m.viewRetries), fmt(s.refused), fmt(s.rule), tostring(c.latched), fmt(c.localRefused))
	return pass, line
end

function S.run(lags, seed)
	local random = Random.new(seed or 23)
	H.phone(true)
	local lines, all = {}, true
	for index, lag in ipairs(lags) do
		status(string.format("%d/%d %s", index, #lags, lagLabel(lag)))
		local ok, pass, line = pcall(S.round, lag, random)
		if not ok then pass, line = false, "FAIL " .. lagLabel(lag) .. " errored: " .. tostring(pass) end
		all = all and pass
		table.insert(lines, line)
		_G.B3SpecLines = lines
	end
	setLag(0)
	H.phone(false)
	status("done")
	return (all and "ALL PASS" or "SOME FAILED") .. "\n" .. table.concat(lines, "\n")
end

-- Today's path (override OFF): the same phone deck and taps through dropEgg (the ghost ball),
-- frame times. The ghost stats count v890's predicted merges (the today's-path mitigation).
local req = ReplicatedStorage:FindFirstChild("BoardRequest", true)
local function freshToday()
	for _ = 1, 4 do
		local run = board:GetAttribute("RunSequence")
		if not board:GetAttribute("RoundOver") and (board:GetAttribute("Drops") or 0) == 0 then return true end
		waitFor(function() return board:GetAttribute("RewardStatus") ~= "Saving" end, 15)
		req:FireServer(if board:GetAttribute("RoundOver") then "reset" else "restart", run)
		waitFor(function() return board:GetAttribute("RunSequence") ~= run end, 5)
		task.wait(3.2)
	end
	return false
end
function S.todayRound(lag, random)
	if not freshToday() then return "FAIL today " .. lagLabel(lag) .. ": no fresh round" end
	setLag(lag)
	task.wait(1)
	-- The difficulty picker takes the deck's A until the first drop: that one goes to the server.
	req:FireServer("drop", 0.5)
	waitFor(function() return (board:GetAttribute("Drops") or 0) > 0 end, 5)
	local toBall = {}
	local frameLine = frames(function()
		local deadline = os.clock() + 120
		while os.clock() < deadline and not board:GetAttribute("RoundOver") and (board:GetAttribute("Drops") or 0) < 24 do
			task.wait(random:NextNumber(0.05, 0.45))
			local aim = random:NextInteger(0, 400) / 400
			local tapAt
			waitFor(function()
				if board:GetAttribute("RoundOver") or (board:GetAttribute("Drops") or 0) >= 24 then return true end
				local sent = gui:GetAttribute("DeckNetTapSent") or 0
				deckTap(aim)
				if (gui:GetAttribute("DeckNetTapSent") or 0) > sent then tapAt = gui:GetAttribute("DeckNetTapAt"); return true end
				return false
			end, 4)
			if tapAt then
				waitFor(function() local shown = gui:GetAttribute("DeckNetBallShownAt"); return shown and shown >= tapAt end, 1.5)
				local shown = gui:GetAttribute("DeckNetBallShownAt")
				if shown and shown >= tapAt then table.insert(toBall, (shown - tapAt) * 1000) end
			end
		end
		waitFor(function() return board:GetAttribute("RoundOver") == true end, 30)
	end)
	setLag(0)
	gui:SetAttribute("DeckNetQuery", os.clock()); task.wait(0.1)
	local report = Http:JSONDecode(gui:GetAttribute("DeckNetReport") or "{}")
	local g = report.ghost or {}
	local tb, tbx = med(toBall)
	return string.format("today %s | tapToBall(ghost) median=%.1f max=%.1f ms n=%d | %s | ghost handoffs=%s timeouts=%s predicted=%s confirmed=%s undone=%s | stream %s",
		lagLabel(lag), tb, tbx, #toBall, frameLine, tostring(g.handoffs), tostring(g.timeouts), tostring(g.predicted), tostring(g.confirmed),
		tostring(g.undone), tostring(gui:GetAttribute("DeckNetStats")))
end
function S.today(lags, seed)
	local random = Random.new(seed or 23)
	H.phone(true)
	local lines = {}
	for index, lag in ipairs(lags) do
		status(string.format("today %d/%d %s", index, #lags, lagLabel(lag)))
		local ok, line = pcall(S.todayRound, lag, random)
		table.insert(lines, if ok then line else ("FAIL today errored: " .. tostring(line)))
		_G.B3TodayLines = lines
	end
	setLag(0)
	H.phone(false)
	status("today done")
	return table.concat(lines, "\n")
end

return S
