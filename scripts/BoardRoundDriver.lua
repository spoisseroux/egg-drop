-- Studio Client (B1 parity, artifacts/qa-2026-11-17-v887/B1-plan.md): plays real field rounds
-- over the live BoardRequest remote so src/server/RoundRecorder.lua records them. Grid aims
-- (k/400, so the host's aim quantization is a no-op), a mix of mashing (a drop every frame until
-- one lands: interval and gate edges) and slow taps, items whenever the belt has one, and a
-- pause/resume with an item inside it. Heat cycles medium, hard, easy (applied at reset).
-- Copy to src/client/ZZSpecs/BoardRoundDriver.lua. Usage (Client execute_luau, task.spawn it):
--   _G.B1Drive = require(PlayerScripts.Client.ZZSpecs.BoardRoundDriver)({ rounds = 6, seed = 5 })
-- Progress in _G.B1DriveStatus.
return function(options)
	options = options or {}
	local Players = game:GetService("Players")
	local RS = game:GetService("RunService")
	local player = Players.LocalPlayer
	local board = game.ReplicatedStorage:WaitForChild("EggDropBoards"):WaitForChild(tostring(player.UserId))
	local req = game.ReplicatedStorage:FindFirstChild("BoardRequest", true)
	local random = Random.new(options.seed or 5)
	local heats = options.heats or { "medium", "hard", "easy" }
	local log = {}
	local function status(text) _G.B1DriveStatus = text; table.insert(log, text) end
	local function waitFor(check, seconds)
		local t = os.clock()
		while not check() and os.clock() - t < seconds do RS.Heartbeat:Wait() end
		return check()
	end
	local function freshRound(heat)
		for _ = 1, 4 do
			if not board:GetAttribute("RoundOver") and (board:GetAttribute("Drops") or 0) == 0 then break end
			waitFor(function() return board:GetAttribute("RewardStatus") ~= "Saving" end, 8)
			local seq = board:GetAttribute("RunSequence")
			req:FireServer(if board:GetAttribute("RoundOver") then "reset" else "restart", seq)
			waitFor(function() return board:GetAttribute("RunSequence") ~= seq end, 5)
			task.wait(0.6)
		end
		if heat then req:FireServer("heat", heat); task.wait(0.8) end
	end
	local function useItem()
		local belt = board:GetAttribute("ItemBelt") or ""
		local id = belt:match("^[^,]+")
		if not id or (board:GetAttribute("ItemArmed") or "") ~= "" then return false end
		req:FireServer("item", { resetId = board:GetAttribute("ResetId"), seq = board:GetAttribute("ItemSeq") or 0, id = id })
		task.wait(0.15)
		return true
	end
	local played = {}
	for round = 1, options.rounds or 6 do
		freshRound(heats[(round - 1) % #heats + 1])
		local mash = round % 2 == 1
		local pausedOnce = false
		local deadline = os.clock() + 90
		while not board:GetAttribute("RoundOver") and (board:GetAttribute("Drops") or 0) < 24 and os.clock() < deadline do
			local before = board:GetAttribute("Drops") or 0
			local aim = random:NextInteger(0, 400) / 400
			if mash then
				waitFor(function()
					if board:GetAttribute("RoundOver") or (board:GetAttribute("Drops") or 0) > before then return true end
					req:FireServer("drop", aim)
					return false
				end, 4)
			else
				waitFor(function() return board:GetAttribute("FieldReady") == true or board:GetAttribute("RoundOver") end, 4)
				task.wait(random:NextNumber(0.05, 0.9))
				req:FireServer("drop", aim)
				waitFor(function() return (board:GetAttribute("Drops") or 0) > before or board:GetAttribute("RoundOver") end, 1.5)
			end
			if random:NextNumber() < 0.5 then useItem() end
			if not pausedOnce and (board:GetAttribute("Drops") or 0) >= 12 then
				pausedOnce = true
				req:FireServer("pause", true); task.wait(0.4)
				useItem(); task.wait(0.3)
				req:FireServer("pause", false)
			end
		end
		waitFor(function() return board:GetAttribute("RoundOver") == true end, 30)
		local summary = string.format("round %d heat=%s mash=%s drops=%s merges=%s score=%s over=%s reason=%s",
			round, tostring(board:GetAttribute("RunHeat") or heats[(round - 1) % #heats + 1]), tostring(mash),
			tostring(board:GetAttribute("Drops")), tostring(board:GetAttribute("Merges")), tostring(board:GetAttribute("Score")),
			tostring(board:GetAttribute("RoundOver")), tostring(board:GetAttribute("FieldReason")))
		table.insert(played, summary)
		status(summary)
		task.wait(1)
	end
	status("done")
	return played
end
