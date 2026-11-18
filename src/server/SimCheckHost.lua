-- Owner-only board sim determinism check, server side (B0-plan.md; FeatureFlags.SimCheck).
-- The experience creator's client (or anyone in Studio) replays SimCheck's three logs after
-- join and sends its hash lists; this replays the same logs once per server (cached, spread
-- over frames) and answers match or the first mismatch. One report per player per server;
-- everyone else is ignored. Nothing here touches a board or a save.
local Players = game:GetService("Players")
local ReplicatedStorage = game:GetService("ReplicatedStorage")
local FeatureFlags = require(ReplicatedStorage.Shared.FeatureFlags)
local Check = require(ReplicatedStorage.Shared.SimCheck)

local Host = {}
local expected, computing = nil, false
local waiting = {}
local reported = {}

local function serverHashes()
	if expected then return expected end
	if computing then
		table.insert(waiting, coroutine.running())
		return coroutine.yield()
	end
	computing = true
	-- 30 fixed steps a frame (about 320 frames): small beside the live boards' own steps.
	local ok, run = pcall(Check.run, function() task.wait() end, 30)
	computing = false
	expected = if ok then run else nil
	if not ok then warn("[SimCheck] server replay failed: " .. tostring(run)) end
	local list = waiting
	waiting = {}
	for _, thread in ipairs(list) do task.spawn(thread, expected) end
	return expected
end

function Host.mount(remotes)
	if FeatureFlags.SimCheck ~= true then return nil end
	local remote = remotes:FindFirstChild("SimCheck") or Instance.new("RemoteEvent")
	remote.Name = "SimCheck"
	remote.Parent = remotes
	Players.PlayerRemoving:Connect(function(player) reported[player] = nil end)
	remote.OnServerEvent:Connect(function(player, report)
		if reported[player] then return end
		reported[player] = true
		if not Check.isOwner(player) or not Check.validReport(report) then return end
		local run = serverHashes()
		if not run or not player.Parent then return end
		local miss = Check.compare(run.hashes, report.hashes)
		local total = 0
		for _, list in ipairs(run.hashes) do total += #list end
		print(string.format("[SimCheck] %s: %s (%d hashes, server %s, client %s, client %.2f s)", player.Name,
			if miss then string.format("MISMATCH at log %d hash %d", miss.log, miss.index) else "match",
			total, Check.digest(run.hashes), Check.digest(report.hashes), tonumber(report.seconds) or -1))
		remote:FireClient(player, { version = Check.Version, match = miss == nil, log = miss and miss.log,
			index = miss and miss.index, total = total })
	end)
	return remote
end

return Host
