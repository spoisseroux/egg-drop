local DataStoreService = game:GetService("DataStoreService")
local RunService = game:GetService("RunService")
local Themes = require(game:GetService("ReplicatedStorage").Shared.DeckThemes)
local Stickers = require(game:GetService("ReplicatedStorage").Shared.DeckStickers)

local Progress = {}
local pending = {}
local memory = {}
local store = if RunService:IsStudio() then nil else DataStoreService:GetDataStore("EggDropProgressV1")
local writer = game.JobId

local function rankOf(record)
	local rank = record.rank
	return if type(rank) == "number" and rank >= 0 and rank < math.huge then math.floor(rank) else 0
end

function Progress.load(userId)
	local key = "player_" .. userId
	local record = memory[key]
	local success = true
	if store then
		success, record = pcall(store.GetAsync, store, key)
		if not success then
			warn("Egg Drop could not load the player profile:", record)
		end
	end
	record = if type(record) == "table" then record else {}
	return {
		key = key,
		rank = rankOf(record),
		theme = if type(record.theme) == "string" and Themes.ById[record.theme] then record.theme else Themes.Default,
		sticker = if type(record.sticker) == "string" and Stickers.ById[record.sticker] then record.sticker else Stickers.Default,
		loadFailed = not success,
	}
end

local function flush(profile)
	if profile.saving or not pending[profile] then
		return
	end
	profile.saving = true
	local rank, theme, sticker, themeAt = profile.earnedRank, profile.theme, profile.sticker, profile.themeAt
	local function merge(previous)
		local record = if type(previous) == "table" then table.clone(previous) else {}
		if rank then
			record.rank = math.max(rank, rankOf(record))
		end
		local previousTime = if type(record.themeAt) == "number" then record.themeAt else 0
		local previousWriter = if type(record.themeWriter) == "string" then record.themeWriter else ""
		if themeAt and (themeAt > previousTime or (themeAt == previousTime and writer >= previousWriter)) then
			record.theme, record.sticker, record.themeAt, record.themeWriter = theme, sticker, themeAt, writer
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
		warn("Egg Drop could not save the player profile:", result)
		return
	end
	if rank == profile.earnedRank then
		profile.earnedRank = nil
	end
	if themeAt == profile.themeAt then
		profile.themeAt = nil
	end
	if not profile.earnedRank and not profile.themeAt then
		pending[profile] = nil
	end
end

function Progress.equip(profile, theme, sticker)
	profile.theme = theme
	profile.sticker = sticker
	profile.themeAt = DateTime.now().UnixTimestampMillis
	pending[profile] = true
end

function Progress.earn(profile)
	profile.rank += 1
	profile.earnedRank = profile.rank
	pending[profile] = true
	task.defer(flush, profile)
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
