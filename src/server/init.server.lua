local Players = game:GetService("Players")
local ReplicatedStorage = game:GetService("ReplicatedStorage")
local RunService = game:GetService("RunService")
local HttpService = game:GetService("HttpService")

local Config = require(ReplicatedStorage.Shared.BoardConfig)
local Themes = require(ReplicatedStorage.Shared.DeckThemes)
local Stickers = require(ReplicatedStorage.Shared.DeckStickers)
local Pets = require(ReplicatedStorage.Shared.PetCatalog)
local Settings = require(ReplicatedStorage.Shared.DeckSettings)
local Simulation = require(script.BoardSimulation)
local Round = require(script.BoardRound)
local Lounge = require(script.Lounge)
local Progress = require(script.PlayerProgress)
local FirstSession = require(script.FirstSession)
local FieldRun = require(script.FieldRun)
local Nursery = require(script.HatchProgress)
local NurseryCatalog = require(ReplicatedStorage.Shared.EggCatalog)
local FamilyMastery = require(ReplicatedStorage.Shared.FamilyMastery)
local CloseProgress = require(script.CloseProgress)

local function child(className, name, parent)
	local instance = Instance.new(className)
	instance.Name = name
	instance.Parent = parent
	return instance
end

local remotes = ReplicatedStorage:WaitForChild("Remotes")
local request = child("RemoteEvent", "BoardRequest", remotes)
local feedback = child("RemoteEvent", "BoardMerge", remotes)
local impactsRemote = child("RemoteEvent", "BoardImpact", remotes)
local nurseryRequest = child("RemoteEvent", "HatchRequest", remotes)
local nurseryFeedback = child("RemoteEvent", "HatchFeedback", remotes)
local trays = child("Folder", "EggDropBoards", ReplicatedStorage)
local boards = {}
local loading = {}
local closing = {}
local nextSlot = 0
Lounge.create()

local function inventory(board)
	return board.nursery.state.inventoryMask
end

local function hasPip(board)
	return NurseryCatalog.isOwned(inventory(board), "pip")
end

local function publishNursery(board)
	local state = Nursery.public(board.nursery)
	if NurseryCatalog.isOwned(state.inventoryMask, "pip") then
		if not NurseryCatalog.isOwned(state.inventoryMask, board.profile.companionId) then
			Progress.equipCompanion(board.profile, Pets.byId.pip)
			board.folder:SetAttribute("CompanionId", "pip")
		end
		if board.firstSession then board.firstSession:advance(4) end
	end
	if board.nurseryBusy then state.status = "Busy" end
	board.folder:SetAttribute("HatchState", HttpService:JSONEncode(state))
	board.folder:SetAttribute("InventoryMask", state.inventoryMask)
	board.folder:SetAttribute("HatchActive", true)
	local masteryMask = state.masteryLegacyMask or 0
	board.folder:SetAttribute("MasteryRanks", HttpService:JSONEncode(state.masteryRanks or {}))

	board.folder:SetAttribute("MasteryMask", masteryMask)
end

local function publishState(board)
	board.folder:SetAttribute("Preset", board.sim.preset)
	board.folder:SetAttribute("Drops", board.sim.drops)
	board.folder:SetAttribute("NextTier", Simulation.nextTier(board.sim))
	board.folder:SetAttribute("PreviewTier1", Simulation.nextTier(board.sim, 1))
	board.folder:SetAttribute("PreviewTier2", Simulation.nextTier(board.sim, 2))
	board.folder:SetAttribute("Merges", board.merges)
	board.folder:SetAttribute("Chain", board.chain)
	board.folder:SetAttribute("PeakChain", board.peakChain)
	board.folder:SetAttribute("MaxClears", board.round.maxClears)
	board.folder:SetAttribute("TrialMask", board.profile.trials)
	board.folder:SetAttribute("Score", board.round.score)
	board.folder:SetAttribute("BestScore", board.profile.bestScore)
	board.folder:SetAttribute("NewBest", board.round.score > board.startBest)
	board.folder:SetAttribute("HatchCharge", board.profile.charge)
	-- Compatibility for the welcome guide only. Sparse inventory uses its own mask.
	local prefix = 0
	for i, pet in ipairs(Pets) do
		if not NurseryCatalog.isOwned(inventory(board), pet.id) then break end
		prefix = i
	end
	board.folder:SetAttribute("OwnedPets", prefix)
	board.folder:SetAttribute("InventoryMask", inventory(board))
	board.folder:SetAttribute("CompanionId", board.profile.companionId)
	board.folder:SetAttribute("RoundOver", board.round.over)
	board.folder:SetAttribute("RunFamily", board.runFamily or "pip")
	board.folder:SetAttribute("SelectedFamily", board.selectedFamily or "pip")
	board.folder:SetAttribute("DangerY", board.round.overflowY or Config.OverflowY)
	board.folder:SetAttribute("OverflowPressure", board.round.danger or 0)
	board.folder:SetAttribute("FieldPhase", board.field and board.field.phase or "Welcome")
	board.folder:SetAttribute("FieldStage", board.field and board.field.rootStage or 0)
	board.folder:SetAttribute("FieldBudget", board.field and board.field.budget or nil)
	board.folder:SetAttribute("FieldZoneBound", FieldRun.ZoneBound)
	board.folder:SetAttribute("FieldReady", (not hasPip(board) or board.nursery.status == "Ready")
		and (not board.field or (board.field:canDrop(board.sim.drops) and Simulation.canDrop(board.sim))))
end

local function syncVisuals(board)
	local live = {}
	for _, egg in ipairs(board.sim.eggs) do
		live[egg.id] = true
		local part = board.parts[egg.id]
		if not part then
			part = Instance.new("Part")
			part.Name = "Egg_" .. egg.id
			part.Shape = Enum.PartType.Ball
			part.Size = Vector3.one * egg.radius * 2
			part.Color = Config.Tiers[egg.tier].color
			part.Material = Enum.Material.SmoothPlastic
			part.Anchored = true
			part.CanCollide = false
			part.CanTouch = false
			part.CanQuery = false
			part.CastShadow = false
			part:SetAttribute("Tier", egg.tier)
			part:SetAttribute("EggId", egg.id)
			board.parts[egg.id] = part
		end
		local position = Vector3.new(egg.position.X, egg.position.Y, 0)
		if part.Position ~= position then
			part.Position = position
		end
		if not part.Parent then
			part.Parent = board.folder
		end
	end
	for id, part in pairs(board.parts) do
		if not live[id] then
			part:Destroy()
			board.parts[id] = nil
		end
	end
end

local function reset(board, preset)
	board.folder:ClearAllChildren()
	table.clear(board.parts)
	local field = hasPip(board) and board.nursery.status == "Ready"
	board.field = if field then FieldRun.new() else nil
	local selected = board.selectedFamily or NurseryCatalog.family(board.profile.companionId) or "pip"
	board.runFamily = if FamilyMastery.ownsFamily(inventory(board), selected) then selected else "pip"
	board.selectedFamily = board.runFamily
	board.runDay = Nursery.public(board.nursery).dailyDay
	board.runSequence = board.nursery.nextRunSeq
	board.nursery.nextRunSeq += 1
	board.sim = Simulation.new(preset, board.sim and board.sim.serial,
		if field then FieldRun.simulationOptions(Random.new():NextInteger(1, 2147483646)) else nil)
	board.round = Round.new(if field then FieldRun.roundOptions() else nil)
	board.startBest = board.profile.bestScore
	board.folder:SetAttribute("ResetId", board.sim.serial)
	board.merges = 0
	board.chain = 0
	board.peakChain = 0
	board.lastMerge = -math.huge
	board.lastDrop = -math.huge
	board.playTime = 0
	board.payoutPending = false
	board.earnedPayout = nil
	board.folder:SetAttribute("FieldSuccess", false)
	board.folder:SetAttribute("NectarAward", 0)
	board.folder:SetAttribute("DailyAward", 0)
	board.folder:SetAttribute("MasteryAward", 0)
	board.folder:SetAttribute("RewardStatus", "")
	publishState(board)
	syncVisuals(board)
end

local function addPlayer(player)
	if boards[player] or loading[player] then
		return
	end
	loading[player] = true
	local profile = Progress.load(player.UserId)
	local nursery = Nursery.load(player.UserId, profile)
	loading[player] = nil
	if player.Parent ~= Players then
		Nursery.release(nursery)
		return
	end
	local folder = Instance.new("Folder")
	folder.Name = tostring(player.UserId)
	nextSlot += 1
	local slot = nextSlot
	local board = {
		folder = folder,
		parts = {},
		impacts = {},
		lastDrop = -math.huge,
		lastReset = -math.huge,
		lastModeChange = -math.huge,
		lastAppearanceChange = -math.huge,
		lastCompanionChange = -math.huge,
		mode = "Board",
		profile = profile,
		nursery = nursery,
		firstSession = FirstSession.new(player, profile),
	}
	if nursery.companionId then profile.companionId = nursery.companionId end
	if not NurseryCatalog.isOwned(nursery.state.inventoryMask, profile.companionId) then
		profile.companionId = if NurseryCatalog.isOwned(nursery.state.inventoryMask, "pip") then "pip" else nil
	end
	if not Stickers.canEquip(profile.sticker, profile.rank, profile.trials, nursery.state.inventoryMask) then profile.sticker = Stickers.Default end
	board.mode = if NurseryCatalog.isOwned(nursery.state.inventoryMask, "pip") then "Room" else "Board"
	boards[player] = board
	reset(board, Config.DefaultPreset)
	publishNursery(board)
	folder:SetAttribute("Mode", board.mode)
	folder:SetAttribute("DeckThemeId", profile.theme)
	folder:SetAttribute("DeckStickerId", profile.sticker)
	folder:SetAttribute("SoundLevel", profile.sound)
	folder:SetAttribute("ReducedEffects", profile.reduced)
	folder:SetAttribute("SaveStatus", if profile.loadFailed then "Temporary" else nil)
	profile.onSaveFailed = function(failed)
		if boards[player] == board and folder.Parent then
			folder:SetAttribute("SaveStatus", if failed then "Retrying" else nil)
		end
	end
	folder.Parent = trays
	if board.firstSession then
		board.firstSession:advance(1)
	end
	local function spawn(character)
		Lounge.spawn(character, slot, player, function()
			return board.mode, profile.theme, profile.sticker
		end)
	end
	board.characterConnection = player.CharacterAdded:Connect(spawn)
	if player.Character then
		task.spawn(spawn, player.Character)
	end
end

local function closeBoard(board)
	if closing[board] then return end
	closing[board] = true
	board.closing = true
	task.spawn(function()
		local ok, reason = CloseProgress.drain(Nursery, board.nursery, board.earnedPayout)
		if not ok then warn("Egg Drop close save did not finish:", reason) end
		closing[board] = nil
	end)
end
Players.PlayerAdded:Connect(addPlayer)
Players.PlayerRemoving:Connect(function(player)
	local board = boards[player]
	if board then
		board.profile.onSaveFailed = nil
		board.characterConnection:Disconnect()
		board.folder:Destroy()
		boards[player] = nil
		Progress.release(board.profile)
		closeBoard(board)
	end
end)

for _, player in ipairs(Players:GetPlayers()) do
	task.spawn(addPlayer, player)
end

request.OnServerEvent:Connect(function(player, action, value, sticker)
	local board = boards[player]
	if not board or board.closing then
		return
	end
	local now = os.clock()
	if action == "appearance" then
		if typeof(value) == "string" and Themes.ById[value] and typeof(sticker) == "string"
			and Stickers.canEquip(sticker, board.profile.rank, board.profile.trials, inventory(board))
			and (value ~= board.profile.theme or sticker ~= board.profile.sticker) and now - board.lastAppearanceChange >= 0.25 then
			board.lastAppearanceChange = now
			Progress.equip(board.profile, value, sticker)
			board.folder:SetAttribute("DeckThemeId", value)
			board.folder:SetAttribute("DeckStickerId", sticker)
			Lounge.setAppearance(player.Character, value, sticker)
		end
		return
	end
	if action == "sound" or action == "motion" then
		if value ~= nil then
			return
		end
		if action == "sound" then
			local nextSound = Settings.NextSound[board.profile.sound]
			Progress.setSetting(board.profile, "sound", nextSound)
			board.folder:SetAttribute("SoundLevel", nextSound)
		else
			local reduced = not board.profile.reduced
			Progress.setSetting(board.profile, "reduced", reduced)
			board.folder:SetAttribute("ReducedEffects", reduced)
		end
		return
	end
	if action == "pause" then
		if typeof(value) == "boolean" then board.menuPaused = value end
		return
	end
	if action == "family" then
		if typeof(value) == "string" and FamilyMastery.ownsFamily(inventory(board), value) then
			board.selectedFamily = value
			board.folder:SetAttribute("SelectedFamily", value)
		end
		return
	end
	if action == "companion" then
		local pet = if typeof(value) == "string" then Pets.byId[value] else nil
		if board.mode == "Room" and pet and NurseryCatalog.isOwned(inventory(board), pet.id)
			and value ~= board.profile.companionId and now - board.lastCompanionChange >= 0.35 then
			board.lastCompanionChange = now
			Progress.equipCompanion(board.profile, pet)
			board.folder:SetAttribute("CompanionId", pet.id)
		end
		return
	end
	if action == "mode" then
		if now - board.lastModeChange < Config.ModeSwitchInterval or value == board.mode
			or (value ~= "Board" and (value ~= "Room" or not hasPip(board))) then
			return
		end
		board.lastModeChange = now
		if value == "Board" and hasPip(board) and not board.field then reset(board, board.sim.preset) end
		board.mode = value
		board.menuPaused = false
		Lounge.setMode(player.Character, player.UserId, value, board.profile.theme, board.profile.sticker)
		board.folder:SetAttribute("Mode", value)
		if value == "Room" and board.firstSession then
			board.firstSession:record("FirstSessionLoungeVisit")
		end
		return
	end
	if board.mode ~= "Board" then
		return
	end
	if action == "drop" then
		if board.menuPaused or board.round.over or (hasPip(board) and board.nursery.status ~= "Ready")
			or (board.field and (not board.field:canDrop(board.sim.drops) or not Simulation.canDrop(board.sim)))
			or typeof(value) ~= "number" or not (value >= 0 and value <= 1)
			or now - board.lastDrop < Config.DropInterval then
			return
		end
		board.lastDrop = now
		if Simulation.drop(board.sim, value) then
			publishState(board)
			if board.firstSession then
				board.firstSession:advance(2)
			end
		end
	elseif action == "reset" or action == "preset" then
		if board.payoutPending then return end
		if now - board.lastReset < Config.ResetInterval then
			return
		end
		if (action == "reset" and not board.round.over) or (action == "preset" and not RunService:IsStudio()) then
			return
		end
		local preset = board.sim.preset
		if action == "preset" then
			if typeof(value) ~= "string" or not Config.Presets[value] then
				return
			end
			preset = value
		end
		board.lastReset = now
		reset(board, preset)
		if action == "reset" and board.firstSession then
			board.firstSession:record("FirstSessionRoundRetry")
		end
	end
end)

local messages = {
	NeedNectar = "Earn more nectar in a field run.", RevisionChanged = "Your hatch progress updated. Try again.",
	Busy = "Finishing your last hatch action…", Pending = "Retry the previous action while it saves.",
	Retrying = "Saving is delayed. Your result will stay the same when retried.",
	SessionLost = "This hatch session moved to another server. Rejoin to continue.",
	Locked = "Your previous session is closing. Please wait a moment.",
	Temporary = "Hatch saving is unavailable. Rejoin before spending nectar.",
}

nurseryRequest.OnServerEvent:Connect(function(player, action, value, revision)
	local board = boards[player]
	if not board or board.closing or typeof(action) ~= "string" then return end
	if action ~= "hatch" and action ~= "ack" and action ~= "daily" then return end
	if os.clock() - (board.lastHatchRequest or -math.huge) < .3 then
		nurseryFeedback:FireClient(player, "error", "One moment…")
		return
	end
	board.lastHatchRequest = os.clock()
	if board.nurseryBusy or board.payoutPending then
		nurseryFeedback:FireClient(player, "error", "Finishing your last save…")
		return
	end
	board.nurseryBusy = true
	publishNursery(board)
	local ok, reason = Nursery.command(board.nursery, action, value, revision)
	board.nurseryBusy = false
	if boards[player] ~= board then return end
	publishNursery(board)
	publishState(board)
	if not ok then nurseryFeedback:FireClient(player, "error", messages[reason] or reason) end
end)

local function settleReward(player, board)
	if board.payoutRunning then return end
	local amount = board.field.outcome.reward
	board.folder:SetAttribute("FieldSuccess", board.field.outcome.success)
	local summary = { family = board.runFamily, day = board.runDay, success = board.field.outcome.success,
		clean = board.field.outcome.success and amount == 8, score = board.round.score, chain = board.peakChain,
		clears = board.round.maxClears, drops = board.sim.drops }
	board.earnedPayout = { sequence = board.runSequence, amount = amount, summary = summary, saved = false }
	board.payoutPending, board.payoutRunning = true, true
	board.folder:SetAttribute("RewardStatus", "Saving")
	task.spawn(function()
		while boards[player] == board and not board.closing and board.payoutPending do
			if not board.closing and not board.nurseryBusy and not board.nursery.busy then
				local ok, reason = Nursery.award(board.nursery, board.runSequence, amount, summary)
				if boards[player] ~= board then break end
				publishNursery(board)
				if ok then
					board.payoutPending = false
					board.earnedPayout.saved = true
					local saved = Nursery.public(board.nursery).lastRunReward
					board.folder:SetAttribute("NectarAward", saved and saved.sequence == board.runSequence and saved.total or amount)
					board.folder:SetAttribute("MasteryAward", saved and saved.sequence == board.runSequence and saved.masteryPoints or 0)
					board.folder:SetAttribute("DailyAward", saved and saved.sequence == board.runSequence and saved.daily or 0)
					board.folder:SetAttribute("RewardStatus", "Saved")
					break
				end
				board.folder:SetAttribute("RewardStatus", messages[reason] or reason)
			end
			task.wait(2)
		end
		board.payoutRunning = false
	end)
end

local function grantWelcome(player, board)
	if board.starterRunning or hasPip(board) then return end
	board.starterRunning = true
	task.spawn(function()
		while boards[player] == board and not board.closing and not hasPip(board) do
			if not board.closing and not board.nurseryBusy and not board.nursery.busy then
				local ok = Nursery.grantStarter(board.nursery)
				if boards[player] ~= board then break end
				publishNursery(board)
				publishState(board)
				if ok then
					board.profile.companionId = "pip"
					board.folder:SetAttribute("CompanionId", "pip")
					if board.firstSession then board.firstSession:advance(4) end
					break
				end
			end
			task.wait(2)
		end
		board.starterRunning = false
	end)
end

local accumulator = 0
local merged = {}
RunService.Heartbeat:Connect(function(dt)
	accumulator = math.min(accumulator + dt, Config.FixedStep * 8)
	while accumulator >= Config.FixedStep do
		accumulator -= Config.FixedStep
		for player, board in pairs(boards) do
			if board.closing or board.mode ~= "Board" or board.round.over or board.menuPaused then
				continue
			end
			board.playTime += Config.FixedStep
			local wasReady = Simulation.canDrop(board.sim)
			table.clear(merged)
			Simulation.step(board.sim, Config.FixedStep, merged, board.impacts)
			board.round:step(board.sim.eggs, Config.FixedStep, board.sim.drops)
			for _, merge in ipairs(merged) do
				board.chain = if board.playTime - board.lastMerge <= 1.25 then board.chain + 1 else 1
				board.peakChain = math.max(board.peakChain, board.chain)
				board.lastMerge = board.playTime
				board.merges += 1
				if merge.cleared then
					board.round.maxClears += 1
				end
				board.round.score += 10 * (merge.tier + math.min(board.chain - 1, 9)) + (if merge.cleared then 100 else 0)
				Progress.recordScore(board.profile, board.round.score)
				Progress.recordTrials(board.profile, board.chain, board.round.score, board.round.maxClears)
				if board.field then board.field:observe(merge) end
				if not hasPip(board) and board.profile.rank < 1 then
					Progress.chargeHatch(board.profile, merge.tier)
				end
				if board.firstSession then
					board.firstSession:advance(3)
				end
				feedback:FireClient(player, merge.position, merge.tier, board.chain, merge.from, merge.other, merge.id, merge.cleared)
			end
			if board.profile.rank >= 1 and not hasPip(board) then grantWelcome(player, board) end
			if board.field then
				local oldPhase, oldStage = board.field.phase, board.field.rootStage
				local result = board.field:step(board.sim.eggs, Config.FixedStep, board.sim.drops, board.round.over)
				if result then
					board.round.over = true
					settleReward(player, board)
				end
				if oldPhase ~= board.field.phase or oldStage ~= board.field.rootStage then publishState(board) end
			end
			if #merged > 0 or board.round.over then
				publishState(board)
			elseif wasReady ~= Simulation.canDrop(board.sim) then
				publishState(board)
			end
		end
	end
	local now = os.clock()
	for player, board in pairs(boards) do
		syncVisuals(board)
		if now - (board.lastPressurePublish or 0) >= .1 then
			board.lastPressurePublish = now
			board.folder:SetAttribute("DangerY", board.round.overflowY or Config.OverflowY)
			board.folder:SetAttribute("OverflowPressure", board.round.danger or 0)
		end
		local batch = {}
		for id, impact in pairs(board.impacts) do
			if board.parts[id] and now - (impact.egg.lastImpact or -math.huge) >= 0.12 then
				impact.egg.lastImpact = now
				table.insert(batch, { id, impact.normal, impact.speed })
			end
		end
		if #batch > 0 then
			impactsRemote:FireClient(player, batch)
		end
		table.clear(board.impacts)
	end
end)

task.spawn(function()
	while true do
		task.wait(2)
		for player, board in pairs(boards) do
			if not board.closing and board.nursery.status == "Retrying" and board.nursery.pending
				and not board.nurseryBusy and not board.nursery.busy then
				task.spawn(function()
					Nursery.retry(board.nursery)
					if boards[player] == board then publishNursery(board); publishState(board) end
				end)
			end
		end
	end
end)

task.spawn(function()
	while true do
		task.wait(Nursery.RenewSeconds)
		for player, board in pairs(boards) do
			if not board.closing and not board.nurseryBusy and not board.nursery.busy then
				task.spawn(function()
					if board.nursery.status == "Locked" or board.nursery.status == "Unavailable" then
						board.nurseryBusy = true
						local replacement = Nursery.load(player.UserId, board.profile)
						if boards[player] ~= board or board.closing then Nursery.release(replacement); return end
						board.nursery = replacement
						board.nurseryBusy = false
						if replacement.status == "Ready" and hasPip(board) then reset(board, board.sim.preset) end
					else
						Nursery.renew(board.nursery)
					end
					if boards[player] == board then publishNursery(board); publishState(board) end
				end)
			end
		end
	end
end)

game:BindToClose(function()
	for _, board in pairs(boards) do closeBoard(board) end
	local deadline = os.clock() + 25
	while next(closing) and os.clock() < deadline do task.wait(.1) end
end)
