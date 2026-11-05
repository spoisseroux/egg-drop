local DataStoreService = game:GetService("DataStoreService")
local RunService = game:GetService("RunService")
local Themes = require(game:GetService("ReplicatedStorage").Shared.DeckThemes)
local Stickers = require(game:GetService("ReplicatedStorage").Shared.DeckStickers)
local Pets = require(game:GetService("ReplicatedStorage").Shared.PetCatalog)
local Trials = require(game:GetService("ReplicatedStorage").Shared.PocketTrials)
local Settings = require(game:GetService("ReplicatedStorage").Shared.DeckSettings)

local Progress = {}
local pending = {}
local memory = {}
local store = if RunService:IsStudio() then nil else DataStoreService:GetDataStore("EggDropProgressV1")
local writer = game.JobId

local function markDirty(profile)
	if not profile.loadFailed then
		pending[profile] = true
	end
end

local function setSaveFailed(profile, failed)
	if profile.saveFailed ~= failed then
		profile.saveFailed = failed
		if profile.onSaveFailed then
			profile.onSaveFailed(failed)
		end
	end
end

local function rankOf(record)
	local rank = record.rank
	return if type(rank) == "number" and rank >= 0 and rank < math.huge then math.floor(rank) else 0
end

local function bestOf(record)
	local best = record.bestScore
	return if type(best) == "number" and best >= 0 and best < math.huge then math.floor(best) else 0
end

local function chargeOf(record, rank)
	local nextPet = Pets[rank + 1]
	local charge = record.hatchCharge
	return if nextPet and type(charge) == "number" and charge >= 0
		then math.floor(math.min(charge, nextPet.charge - 1)) else 0
end

local function trialsOf(record)
	return bit32.bor(bit32.band(Trials.mask(record.trials), Trials.ClubMask),
		bit32.band(Trials.mask(record.rareTrials), Trials.RareMask))
end

function Progress.load(userId)
	local key = "player_" .. userId
	local record = memory[key]
	local success = true
	if store then
		for attempt = 1, 3 do
			success, record = pcall(store.GetAsync, store, key)
			if success then
				break
			end
			if attempt < 3 then
				task.wait(attempt * 0.6)
			end
		end
		if not success then
			warn("Egg Drop could not load the player profile:", record)
			record = nil
		end
	end
	record = if type(record) == "table" then record else {}
	local rank = rankOf(record)
	local trials = trialsOf(record)
	local companion = Pets.byId[record.companionId]
	return {
		key = key,
		rank = rank,
		charge = chargeOf(record, rank),
		bestScore = bestOf(record),
		-- The caller validates against the migrated nursery inventory after loading it.
		companionId = if companion then companion.id
			elseif rank > 0 then Pets[1].id else nil,
		theme = if type(record.theme) == "string" and Themes.ById[record.theme] then record.theme else Themes.Default,
		sticker = if type(record.sticker) == "string" and Stickers.ById[record.sticker] then record.sticker else Stickers.Default,
		trials = trials,
		sound = if Settings.validSound(record.sound) then record.sound else Settings.DefaultSound,
		reduced = record.reduced == true,
		loadFailed = not success,
		saveFailed = false,
	}
end

local function flush(profile)
	if profile.loadFailed or profile.saving or not pending[profile] then
		return
	end
	profile.saving = true
	local rank, charge, best = profile.earnedRank, profile.earnedCharge, profile.earnedBest
	local theme, sticker, themeAt = profile.theme, profile.sticker, profile.themeAt
	local companionId, companionAt = profile.companionId, profile.companionAt
	local earnedTrials = profile.earnedTrials
	local soundChange, motionChange = profile.soundChange, profile.motionChange
	local function merge(previous)
		local record = if type(previous) == "table" then table.clone(previous) else {}
		local previousRank = rankOf(record)
		if rank and (rank > previousRank or (rank == previousRank and charge > chargeOf(record, previousRank))) then
			record.rank, record.hatchCharge = rank, charge
		end
		if best then
			record.bestScore = math.max(best, bestOf(record))
		end
		if earnedTrials then
			local completed = bit32.bor(trialsOf(record), earnedTrials)
			record.trials = bit32.band(completed, Trials.ClubMask)
			record.rareTrials = bit32.band(completed, Trials.RareMask)
		end
		local function mergeSetting(key, change)
			if not change then
				return
			end
			local at, source = key .. "At", key .. "Writer"
			local previousAt = if type(record[at]) == "number" then record[at] else 0
			local previousWriter = if type(record[source]) == "string" then record[source] else ""
			if change.at > previousAt or (change.at == previousAt and writer >= previousWriter) then
				record[key], record[at], record[source] = change.value, change.at, writer
			end
		end
		mergeSetting("sound", soundChange)
		mergeSetting("reduced", motionChange)
		local previousTime = if type(record.themeAt) == "number" then record.themeAt else 0
		local previousWriter = if type(record.themeWriter) == "string" then record.themeWriter else ""
		if themeAt and (themeAt > previousTime or (themeAt == previousTime and writer >= previousWriter)) then
			record.theme, record.sticker, record.themeAt, record.themeWriter = theme, sticker, themeAt, writer
		end
		local previousCompanionTime = if type(record.companionAt) == "number" then record.companionAt else 0
		local previousCompanionWriter = if type(record.companionWriter) == "string" then record.companionWriter else ""
		if companionAt and (companionAt > previousCompanionTime
			or (companionAt == previousCompanionTime and writer >= previousCompanionWriter)) then
			record.companionId, record.companionAt, record.companionWriter = companionId, companionAt, writer
		end
		return record
	end

	local success, result
	if store then
		success, result = pcall(store.UpdateAsync, store, profile.key, merge)
	else
		success = true
		memory[profile.key] = merge(memory[profile.key])
	end
	profile.saving = false
	if not success then
		setSaveFailed(profile, true)
		warn("Egg Drop could not save the player profile:", result)
		return
	end
	setSaveFailed(profile, false)
	if rank == profile.earnedRank and charge == profile.earnedCharge then
		profile.earnedRank = nil
		profile.earnedCharge = nil
	end
	if best == profile.earnedBest then
		profile.earnedBest = nil
	end
	if themeAt == profile.themeAt then
		profile.themeAt = nil
	end
	if companionAt == profile.companionAt then
		profile.companionAt = nil
	end
	if earnedTrials == profile.earnedTrials then
		profile.earnedTrials = nil
	end
	if soundChange == profile.soundChange then
		profile.soundChange = nil
	end
	if motionChange == profile.motionChange then
		profile.motionChange = nil
	end
	if not (profile.earnedRank or profile.earnedBest or profile.themeAt or profile.companionAt
		or profile.earnedTrials or profile.soundChange or profile.motionChange) then
		pending[profile] = nil
	end
end

function Progress.recordTrials(profile, chain, score, clears)
	local earned = Trials.earned(profile.trials, chain, score, clears)
	if earned == profile.trials then
		return
	end
	profile.trials = earned
	profile.earnedTrials = earned
	markDirty(profile)
end

function Progress.setSetting(profile, key, value)
	local changeKey = if key == "sound" then "soundChange" else "motionChange"
	profile[key] = value
	profile[changeKey] = { value = value, at = DateTime.now().UnixTimestampMillis }
	markDirty(profile)
end

function Progress.equipCompanion(profile, pet)
	profile.companionId = pet.id
	profile.companionAt = DateTime.now().UnixTimestampMillis
	markDirty(profile)
end

function Progress.recordScore(profile, score)
	if score > profile.bestScore then
		profile.bestScore = score
		profile.earnedBest = score
		markDirty(profile)
	end
end

function Progress.equip(profile, theme, sticker)
	profile.theme = theme
	profile.sticker = sticker
	profile.themeAt = DateTime.now().UnixTimestampMillis
	markDirty(profile)
end

function Progress.chargeHatch(profile, amount)
	local pet = Pets[profile.rank + 1]
	if not pet then
		return nil
	end
	profile.charge += amount
	local hatched = profile.charge >= pet.charge
	if hatched then
		profile.rank += 1
		profile.charge = if Pets[profile.rank + 1] then profile.charge - pet.charge else 0
		if not profile.companionId then
			profile.companionId = pet.id
		end
	end
	profile.earnedRank = profile.rank
	profile.earnedCharge = profile.charge
	markDirty(profile)
	if hatched then
		task.defer(flush, profile)
	end
end

function Progress.release(profile)
	task.defer(flush, profile)
end

local function flushPending()
	for profile in pairs(pending) do
		task.defer(flush, profile)
	end
end

task.spawn(function()
	while true do
		task.wait(12)
		flushPending()
	end
end)

if store then
	game:BindToClose(function()
		local deadline = os.clock() + 24
		while next(pending) and os.clock() < deadline do
			flushPending()
			task.wait(1)
		end
	end)
end

return Progress
