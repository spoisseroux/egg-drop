local Themes = require(game:GetService("ReplicatedStorage").Shared.DeckThemes)
local Stickers = require(game:GetService("ReplicatedStorage").Shared.DeckStickers)
local Pets = require(game:GetService("ReplicatedStorage").Shared.PetCatalog)
local Trials = require(game:GetService("ReplicatedStorage").Shared.PocketTrials)
local Settings = require(game:GetService("ReplicatedStorage").Shared.DeckSettings)
local Backgrounds = require(game:GetService("ReplicatedStorage").Shared.DeckBackgrounds)
local PetAppearance=require(script.Parent.PetAppearance)
local HatchGuard=require(script.Parent.HatchGuard)
local EggCatalog=require(game:GetService("ReplicatedStorage").Shared.EggCatalog)

local Progress = {}
local pending = {}
local flushRequested,flushQueued,flushAttempts={},{},{}
local flush,scheduleFlush
local store = require(script.Parent.ProgressStore)
local writer = game.JobId
local function appearanceStamp(value)
	return if type(value)=="number" and value==value and value>=0 and value<=9007199254740000 and value%1==0 then value else 0
end
local function storedBackground(record)
	return if record.background==nil then Backgrounds.Default else record.background
end
local function appearanceChange(theme,sticker,background,at,generation)
	return table.freeze({theme=theme,sticker=sticker,background=background,at=at,generation=generation,writer=writer})
end

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

local function decode(key, record, success)
	record = if type(record) == "table" then record else {}
	local rank = rankOf(record)
	local trials = trialsOf(record)
	local companion = Pets.byId[record.companionId]
	local petAppearance=PetAppearance.decode(record.petAppearance)
	local petAt=0;for _,entry in pairs(petAppearance)do petAt=math.max(petAt,entry.at)end
	local fallbacks={}
	for slot,collection in pairs({theme=Themes,sticker=Stickers,background=Backgrounds})do
		if record[slot]~=nil and not collection.ById[record[slot]]then fallbacks[slot]="Unknown"end
	end
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
		background = if type(storedBackground(record))=="string" and Backgrounds.ById[storedBackground(record)] then storedBackground(record) else Backgrounds.Default,
		petAppearance=petAppearance,petAppearanceSaved=if success then PetAppearance.decode(record.petAppearance)else {},
		petAppearanceChanges={},petAppearanceGeneration=0,lastPetAppearanceAt=petAt,
		lastCompanionAt=appearanceStamp(record.companionAt),companionGeneration=0,
		appearanceFallbacks = fallbacks,
		lastAppearanceAt = appearanceStamp(record.themeAt),
		appearanceGeneration = 0,
		appearanceSaved = if success then {
			theme = if record.theme==nil then Themes.Default else record.theme,
			sticker = if record.sticker==nil then Stickers.Default else record.sticker,
			background = storedBackground(record),
		} else nil,
		trials = trials,
		sound = if Settings.validSound(record.sound) then record.sound else Settings.DefaultSound,
		reduced = record.reduced == true,
		loadFailed = not success,
		saveFailed = false,
	}
end

function Progress.fromRecord(userId, record, success)
	return decode("player_" .. userId, record, success ~= false)
end

function Progress.load(userId)
	local key = "player_" .. userId
	local success, record
	for attempt = 1, 3 do
		success, record = pcall(store.GetAsync, store, key)
		if success then break end
		if attempt < 3 then task.wait(attempt * .6) end
	end
	if not success then warn("Egg Drop could not load the player profile:", record); record = nil end
	return decode(key, record, success)
end

-- Only an acquired authoritative snapshot may replace the provisional read.
function Progress.hydrate(profile, record)
	if profile.saving or pending[profile] then return false end
	local fresh = decode(profile.key, record, true)
	for key, value in pairs(fresh) do profile[key] = value end
	profile.companionId = fresh.companionId
	return true
end

local function finishFlush(profile,success)
 if not pending[profile]then flushRequested[profile]=nil;flushAttempts[profile]=nil;return end
 if not flushRequested[profile]then return end
 if success then flushAttempts[profile]=0;scheduleFlush(profile,0)
 else
  local attempt=(flushAttempts[profile]or 0)+1;flushAttempts[profile]=attempt
  if attempt<=3 then scheduleFlush(profile,({.5,1,2})[attempt])
  else flushRequested[profile]=nil;flushAttempts[profile]=nil end
 end
end
scheduleFlush=function(profile,delay)
 if flushQueued[profile]or profile.saving then return end
 local ticket={};flushQueued[profile]=ticket
 local function run()
  if flushQueued[profile]~=ticket then return end;flushQueued[profile]=nil
  if profile.saving then return end -- Its completion owns the latched follow-up.
  if not pending[profile]then finishFlush(profile,true);return end
  flush(profile)
 end
 if delay>0 then task.delay(delay,run)else task.defer(run)end
end

-- User-facing preferences must not wait for the twelve-second safety sweep.
-- One profile writer owns persistence; requests arriving during it only latch
-- another drain. Retried candidates retain their exact stamps and proof rules.
function Progress.requestFlush(profile)
 if profile.loadFailed then return false,"Temporary"end
 if not pending[profile]then return true end
 if not flushRequested[profile]then flushAttempts[profile]=0 end
 flushRequested[profile]=true;scheduleFlush(profile,0);return true
end

flush=function(profile)
	if not pending[profile] then return true end
	if profile.saving then return false, "Busy" end
	if profile.loadFailed then return false, "Temporary" end
	profile.saving = true
	local rank, charge, best = profile.earnedRank, profile.earnedCharge, profile.earnedBest
	local petChanges=table.clone(profile.petAppearanceChanges or {})
	local appearance = profile.appearanceChange
	local theme, sticker, themeAt = if appearance then appearance.theme else profile.theme,
		if appearance then appearance.sticker else profile.sticker, if appearance then appearance.at else nil
	local companionChange=profile.companionChange
	local companionId, companionAt = if companionChange then companionChange.petId else profile.companionId, if companionChange then companionChange.at else profile.companionAt
	local companionWriter=if companionChange then companionChange.writer else writer
	local companionFenced=true
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
		if next(petChanges)then record.petAppearance=PetAppearance.merge(record.petAppearance,petChanges)end
		local previousTime = appearanceStamp(record.themeAt)
		local previousWriter = if type(record.themeWriter) == "string" then record.themeWriter else ""
		if themeAt and (themeAt > previousTime or (themeAt == previousTime and writer >= previousWriter)) then
			record.theme, record.sticker, record.themeAt, record.themeWriter = theme, sticker, themeAt, appearance.writer
			record.background=appearance.background
		end
		local previousCompanionTime = if type(record.companionAt) == "number" then record.companionAt else 0
		local previousCompanionWriter = if type(record.companionWriter) == "string" then record.companionWriter else ""
		local exact=record.companionId==companionId and record.companionAt==companionAt and record.companionWriter==companionWriter
		if companionChange and not exact then
			local h=record.hatching;local f=companionChange.fence
			companionFenced=type(h)=="table"and not HatchGuard.other(h,"companion")and h.epoch==f.epoch and h.revision==f.revision and EggCatalog.isOwned(h.inventoryMask,companionId)and type(h.lease)=="table"and h.lease.token==f.token and h.lease.expiresAt>f.now()
		end
		if companionFenced and companionAt and (companionAt > previousCompanionTime
			or (companionAt == previousCompanionTime and companionWriter >= previousCompanionWriter)) then
			record.companionId, record.companionAt, record.companionWriter = companionId, companionAt, companionWriter
		end
		return record
	end

	local success, result = pcall(store.UpdateAsync, store, profile.key, merge)
	profile.saving = false
	if not success then
		setSaveFailed(profile, true)
		warn("Egg Drop could not save the player profile:", result)
		finishFlush(profile,false)
		return false, "Retrying"
	end
	setSaveFailed(profile, false)
	if rank == profile.earnedRank and charge == profile.earnedCharge then
		profile.earnedRank = nil
		profile.earnedCharge = nil
	end
	if best == profile.earnedBest then
		profile.earnedBest = nil
	end
	if appearance then
		local verified=type(result)=="table" and result.theme==appearance.theme and result.sticker==appearance.sticker
			and storedBackground(result)==appearance.background
			and result.themeAt==appearance.at and result.themeWriter==appearance.writer
		if verified then
			profile.appearanceSaved={theme=appearance.theme,sticker=appearance.sticker,background=appearance.background}
			for _,slot in ipairs({"theme","sticker","background"})do
				if profile.appearanceFallbacks and profile[slot]==appearance[slot]then profile.appearanceFallbacks[slot]=nil end
			end
			if profile.appearanceChange==appearance then profile.appearanceChange=nil;profile.themeAt=nil end
			if profile.onAppearanceSaved then profile.onAppearanceSaved(appearance) end
		else
			-- Honor a proven newer foreign winner unless a genuinely newer local
			-- intent arrived while saving. Never replay the captured older click.
			local current=profile.appearanceChange
			local foreignAt=appearanceStamp(type(result)=="table" and result.themeAt)
			local foreignWriter=if type(result)=="table" and type(result.themeWriter)=="string" then result.themeWriter else nil
			local validForeign=type(result)=="table" and type(result.theme)=="string" and Themes.ById[result.theme]
				and type(result.sticker)=="string" and Stickers.ById[result.sticker] and foreignWriter
				and type(storedBackground(result))=="string" and Backgrounds.ById[storedBackground(result)]
				and foreignAt==result.themeAt and (foreignAt>appearance.at or (foreignAt==appearance.at and foreignWriter>appearance.writer))
			if current and current.generation==appearance.generation and validForeign then
				profile.theme,profile.sticker,profile.background=result.theme,result.sticker,storedBackground(result)
				if profile.resolveAppearance then profile.theme,profile.sticker,profile.background=profile.resolveAppearance(profile.theme,profile.sticker,profile.background) end
				profile.lastAppearanceAt=math.max(profile.lastAppearanceAt or 0,foreignAt)
				profile.appearanceSaved={theme=result.theme,sticker=result.sticker,background=storedBackground(result)}
				profile.appearanceChange,profile.themeAt=nil,nil
				if profile.onAppearanceSuperseded then profile.onAppearanceSuperseded(appearance) end
			elseif current then
				local at=math.max(profile.lastAppearanceAt or 0,appearanceStamp(type(result)=="table" and result.themeAt))+1
				profile.lastAppearanceAt,profile.themeAt=at,at
				profile.appearanceChange=appearanceChange(current.theme,current.sticker,current.background,at,current.generation)
				setSaveFailed(profile,true)
			end
		end
	end
	for id,candidate in pairs(petChanges)do
		local stored=type(result)=="table"and type(result.petAppearance)=="table"and result.petAppearance[id]
		local current=profile.petAppearanceChanges[id]
		if PetAppearance.matches(stored,candidate)then
            profile.petAppearanceSaved[id]=table.clone(stored)
			if current==candidate then profile.petAppearanceChanges[id]=nil end
			if profile.onPetAppearanceSaved then profile.onPetAppearanceSaved(candidate)end
		else
			local foreign=PetAppearance.newer(stored,candidate)
			if current==candidate and foreign then
				profile.petAppearance[id],profile.petAppearanceSaved[id]=foreign,table.clone(foreign)
				profile.petAppearanceChanges[id]=nil;profile.lastPetAppearanceAt=math.max(profile.lastPetAppearanceAt or 0,foreign.at)
				if profile.onPetAppearanceSuperseded then profile.onPetAppearanceSuperseded(candidate)end
			elseif current then
				if foreign and current.at<=foreign.at then
					local at=math.max(profile.lastPetAppearanceAt or 0,foreign.at)+1
                    local rebased=table.freeze({petId=id,visible=current.visible,shape=current.shape or "dot",at=at,writer=current.writer,generation=current.generation})
					profile.petAppearanceChanges[id]=rebased;profile.lastPetAppearanceAt=at
                    profile.petAppearance[id]={charmVisible=rebased.visible,charmShape=rebased.shape,at=at,writer=rebased.writer}
				end
				setSaveFailed(profile,true)
			end
		end
	end
	local companionProof=type(result)=="table"and result.companionId==companionId and result.companionAt==companionAt and result.companionWriter==companionWriter
	if companionChange and profile.companionChange==companionChange then
		if companionProof then
			profile.companionId=companionId;profile.companionChange=nil;profile.lastCompanionAt=math.max(profile.lastCompanionAt or 0,companionAt)
			if profile.onCompanionSaved then profile.onCompanionSaved(companionChange)end
		elseif type(result)=="table"and Pets.byId[result.companionId]and type(result.hatching)=="table"and EggCatalog.isOwned(result.hatching.inventoryMask,result.companionId)and appearanceStamp(result.companionAt)==result.companionAt and type(result.companionWriter)=="string"and(result.companionAt>companionAt or(result.companionAt==companionAt and result.companionWriter>companionWriter))then
			profile.companionId=result.companionId;profile.companionChange=nil;profile.lastCompanionAt=result.companionAt
			if profile.onCompanionSuperseded then profile.onCompanionSuperseded(companionChange)end
		elseif not companionFenced then
			profile.companionChange=nil;if profile.onCompanionRejected then profile.onCompanionRejected(companionChange,"SessionLost")end
		else setSaveFailed(profile,true)end
	elseif not companionChange and companionAt~=nil and companionAt==profile.companionAt then
		if companionProof then profile.companionAt=nil
		elseif type(result)=="table"and Pets.byId[result.companionId]and type(result.companionAt)=="number"and type(result.companionWriter)=="string"
			and(result.companionAt>companionAt or(result.companionAt==companionAt and result.companionWriter>companionWriter))
			and(if type(result.hatching)=="table"then EggCatalog.isOwned(result.hatching.inventoryMask,result.companionId)else Pets.isUnlocked(Pets.byId[result.companionId],rankOf(result),trialsOf(result)))then
			profile.companionId=result.companionId;profile.lastCompanionAt=math.max(profile.lastCompanionAt or 0,result.companionAt);profile.companionAt=nil
		else setSaveFailed(profile,true)end
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
	if not (profile.earnedRank or profile.earnedBest or profile.themeAt or profile.companionAt or profile.companionChange
		or profile.earnedTrials or profile.soundChange or profile.motionChange or next(profile.petAppearanceChanges or {})) then
		pending[profile] = nil
	end
	finishFlush(profile,not profile.saveFailed)
	return pending[profile] == nil
end

Progress.flushOnce = flush

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

function Progress.setPetAppearance(profile,petId,visible,shape)
    local Charms=require(game:GetService("ReplicatedStorage").Shared.PetCharmCatalog)
    if not PetAppearance.supported[petId]or type(visible)~="boolean"or(shape~=nil and not Charms.known(shape))then return nil end
    shape=shape or PetAppearance.shape(profile,petId)
	profile.petAppearance=profile.petAppearance or {};profile.petAppearanceChanges=profile.petAppearanceChanges or {};profile.petAppearanceSaved=profile.petAppearanceSaved or {}
	profile.petAppearanceGeneration=(profile.petAppearanceGeneration or 0)+1
	local at=math.max(DateTime.now().UnixTimestampMillis,(profile.lastPetAppearanceAt or 0)+1)
    local candidate=table.freeze({petId=petId,visible=visible,shape=shape,at=at,writer=writer,generation=profile.petAppearanceGeneration})
    profile.lastPetAppearanceAt=at;profile.petAppearance[petId]={charmVisible=visible,charmShape=shape,at=at,writer=writer}
	profile.petAppearanceChanges[petId]=candidate;markDirty(profile);return candidate
end

function Progress.equipCompanion(profile, pet)
	if profile.companionChange then return false,"Busy"end
	profile.companionId = pet.id
	profile.companionAt = math.max(DateTime.now().UnixTimestampMillis,(profile.lastCompanionAt or 0)+1)
	profile.lastCompanionAt=profile.companionAt
	markDirty(profile)
end
function Progress.stageCompanion(profile,pet,operationId,fence)
 if profile.loadFailed or profile.companionChange or profile.companionAt or type(operationId)~="string"or type(fence)~="table"then return nil,"Busy"end
 profile.companionGeneration=(profile.companionGeneration or 0)+1
 local at=math.max(DateTime.now().UnixTimestampMillis,(profile.lastCompanionAt or 0)+1)
 local candidate=table.freeze({petId=pet.id,expectedOld=profile.companionId,id=operationId,at=at,writer=writer,generation=profile.companionGeneration,
  fence=table.freeze({epoch=fence.epoch,token=fence.token,revision=fence.revision,now=fence.now})})
 profile.lastCompanionAt=at;profile.companionChange=candidate;markDirty(profile);return candidate
end

function Progress.recordScore(profile, score)
	if score > profile.bestScore then
		profile.bestScore = score
		profile.earnedBest = score
		markDirty(profile)
	end
end

function Progress.equip(profile, theme, sticker, background)
	profile.theme = theme
	profile.sticker = sticker
	profile.background = background or profile.background or Backgrounds.Default
	profile.appearanceGeneration=(profile.appearanceGeneration or 0)+1
	local at=math.max(DateTime.now().UnixTimestampMillis,(profile.lastAppearanceAt or 0)+1)
	profile.lastAppearanceAt,profile.themeAt=at,at
	profile.appearanceChange=appearanceChange(theme,sticker,profile.background,at,profile.appearanceGeneration)
	markDirty(profile)
	return profile.appearanceChange
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

if store.persistent then
	game:BindToClose(function()
		local deadline = os.clock() + 24
		while next(pending) and os.clock() < deadline do
			flushPending()
			task.wait(1)
		end
	end)
end

return Progress
