local Players = game:GetService("Players")
local ReplicatedStorage = game:GetService("ReplicatedStorage")
local RunService = game:GetService("RunService")

local Config = require(ReplicatedStorage.Shared.BoardConfig)
local Themes = require(ReplicatedStorage.Shared.DeckThemes)
local Stickers = require(ReplicatedStorage.Shared.DeckStickers)
local Pets = require(ReplicatedStorage.Shared.PetCatalog)
local Settings = require(ReplicatedStorage.Shared.DeckSettings)
local Simulation = require(script.BoardSimulation)
local Round = require(script.BoardRound)
local Lounge = require(script.Lounge)
local Progress = require(script.PlayerProgress)

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
local trays = child("Folder", "EggDropBoards", ReplicatedStorage)
local boards = {}
local loading = {}
local nextSlot = 0
Lounge.create()

local function publishState(board)
	board.folder:SetAttribute("Preset", board.sim.preset)
	board.folder:SetAttribute("Drops", board.sim.drops)
	board.folder:SetAttribute("NextTier", Simulation.nextTier(board.sim))
	board.folder:SetAttribute("Merges", board.merges)
	board.folder:SetAttribute("Chain", board.chain)
	board.folder:SetAttribute("PeakChain", board.peakChain)
	board.folder:SetAttribute("MaxClears", board.round.maxClears)
	board.folder:SetAttribute("TrialMask", board.profile.trials)
	board.folder:SetAttribute("Score", board.round.score)
	board.folder:SetAttribute("BestScore", board.profile.bestScore)
	board.folder:SetAttribute("NewBest", board.round.score > board.startBest)
	board.folder:SetAttribute("HatchCharge", board.profile.charge)
	board.folder:SetAttribute("OwnedPets", math.min(board.profile.rank, #Pets))
	board.folder:SetAttribute("CompanionId", board.profile.companionId)
	board.folder:SetAttribute("RoundOver", board.round.over)
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
	board.sim = Simulation.new(preset, board.sim and board.sim.serial)
	board.round = Round.new()
	board.startBest = board.profile.bestScore
	board.folder:SetAttribute("ResetId", board.sim.serial)
	board.merges = 0
	board.chain = 0
	board.peakChain = 0
	board.lastMerge = -math.huge
	board.lastDrop = -math.huge
	board.playTime = 0
	publishState(board)
	syncVisuals(board)
end

local function addPlayer(player)
	if boards[player] or loading[player] then
		return
	end
	loading[player] = true
	local profile = Progress.load(player.UserId)
	loading[player] = nil
	if player.Parent ~= Players then
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
	}
	boards[player] = board
	reset(board, Config.DefaultPreset)
	folder:SetAttribute("Mode", board.mode)
	folder:SetAttribute("DeckThemeId", profile.theme)
	folder:SetAttribute("DeckStickerId", profile.sticker)
	folder:SetAttribute("SoundLevel", profile.sound)
	folder:SetAttribute("ReducedEffects", profile.reduced)
	folder:SetAttribute("ProfileLoadFailed", profile.loadFailed)
	folder.Parent = trays
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

Players.PlayerAdded:Connect(addPlayer)
Players.PlayerRemoving:Connect(function(player)
	local board = boards[player]
	if board then
		board.characterConnection:Disconnect()
		board.folder:Destroy()
		boards[player] = nil
		Progress.release(board.profile)
	end
end)
for _, player in ipairs(Players:GetPlayers()) do
	task.spawn(addPlayer, player)
end

request.OnServerEvent:Connect(function(player, action, value, sticker)
	local board = boards[player]
	if not board then
		return
	end
	local now = os.clock()
	if action == "appearance" then
		if typeof(value) == "string" and Themes.ById[value] and typeof(sticker) == "string"
			and Stickers.canEquip(sticker, board.profile.rank, board.profile.trials)
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
	if action == "companion" then
		local pet = if typeof(value) == "string" then Pets.byId[value] else nil
		if board.mode == "Room" and pet and Pets.isUnlocked(pet, board.profile.rank, board.profile.trials)
			and value ~= board.profile.companionId and now - board.lastCompanionChange >= 0.35 then
			board.lastCompanionChange = now
			Progress.equipCompanion(board.profile, pet)
			board.folder:SetAttribute("CompanionId", pet.id)
		end
		return
	end
	if action == "mode" then
		if now - board.lastModeChange < Config.ModeSwitchInterval or value == board.mode
			or (value ~= "Board" and (value ~= "Room" or board.profile.rank < 1)) then
			return
		end
		board.lastModeChange = now
		board.mode = value
		Lounge.setMode(player.Character, player.UserId, value, board.profile.theme, board.profile.sticker)
		board.folder:SetAttribute("Mode", value)
		return
	end
	if board.mode ~= "Board" then
		return
	end
	if action == "drop" then
		if board.round.over or typeof(value) ~= "number" or not (value >= 0 and value <= 1)
			or now - board.lastDrop < Config.DropInterval then
			return
		end
		board.lastDrop = now
		if Simulation.drop(board.sim, value) then
			publishState(board)
		end
	elseif action == "reset" or action == "preset" then
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
	end
end)

local accumulator = 0
local merged = {}
RunService.Heartbeat:Connect(function(dt)
	accumulator = math.min(accumulator + dt, Config.FixedStep * 8)
	while accumulator >= Config.FixedStep do
		accumulator -= Config.FixedStep
		for player, board in pairs(boards) do
			if board.mode ~= "Board" or board.round.over then
				continue
			end
			board.playTime += Config.FixedStep
			table.clear(merged)
			Simulation.step(board.sim, Config.FixedStep, merged, board.impacts)
			board.round:step(board.sim.eggs, Config.FixedStep)
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
				Progress.chargeHatch(board.profile, merge.tier)
				feedback:FireClient(player, merge.position, merge.tier, board.chain, merge.from, merge.other, merge.id, merge.cleared)
			end
			if #merged > 0 or board.round.over then
				publishState(board)
			end
		end
	end
	local now = os.clock()
	for player, board in pairs(boards) do
		syncVisuals(board)
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
