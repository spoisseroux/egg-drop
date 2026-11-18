-- Owner-only board sim determinism check, client side (B0-plan.md; FeatureFlags.SimCheck).
-- For the experience creator only (anyone in Studio): after the loading screen, at low
-- priority (a few fixed steps per frame), replay SimCheck's three logs through BoardSim and
-- send the hash lists; the server answers match or the first mismatch, shown once on the
-- notification rail. This proves a real phone steps the shared sim to the server's bits.
-- Owner diagnostics: the line is not player copy, so it is not in UICopy.
local Players = game:GetService("Players")
local ReplicatedStorage = game:GetService("ReplicatedStorage")
local FeatureFlags = require(ReplicatedStorage.Shared.FeatureFlags)

local Client = {}
Client.StartDelay = 8 -- seconds after the loading screen
Client.TicksPerFrame = 40
local started = false

local function run()
	local Check = require(ReplicatedStorage.Shared.SimCheck)
	local player = Players.LocalPlayer
	if not Check.isOwner(player) then return end
	local playerGui = player:WaitForChild("PlayerGui", 60)
	if not playerGui then return end
	local deadline = os.clock() + 90
	while playerGui:GetAttribute("LoadingSeconds") == nil and os.clock() < deadline do task.wait(0.5) end
	task.wait(Client.StartDelay)
	local remote = ReplicatedStorage:WaitForChild("Remotes"):WaitForChild("SimCheck", 30)
	if not remote then return end
	local connection
	connection = remote.OnClientEvent:Connect(function(answer)
		if type(answer) ~= "table" then return end
		connection:Disconnect()
		local text = if answer.match then string.format("Sim check: match (%d hashes)", tonumber(answer.total) or 0)
			else string.format("Sim check: MISMATCH (log %s, hash %s)", tostring(answer.log), tostring(answer.index))
		print("[SimCheck] " .. text)
		local ok, Rail = pcall(require, script.Parent.NotificationRail)
		if ok then Rail.enqueue(playerGui, "simCheck", { text = text, icon = if answer.match then "✓" else "!" }) end
	end)
	local result = Check.run(function() task.wait() end, Client.TicksPerFrame)
	print(string.format("[SimCheck] client replay %.2f s busy, digest %s", result.seconds, Check.digest(result.hashes)))
	remote:FireServer({ version = Check.Version, hashes = result.hashes, seconds = result.seconds })
	task.delay(30, function()
		if not connection.Connected then return end
		connection:Disconnect()
		print("[SimCheck] Sim check: no answer from the server")
		local ok, Rail = pcall(require, script.Parent.NotificationRail)
		if ok then Rail.enqueue(playerGui, "simCheck", { text = "Sim check: no answer", icon = "!" }) end
	end)
end

function Client.start()
	if started or FeatureFlags.SimCheck ~= true then return end
	started = true
	task.spawn(function()
		local ok, problem = pcall(run)
		if not ok then warn("[SimCheck] client check failed: " .. tostring(problem)) end
	end)
end

return Client
