local HttpService = game:GetService("HttpService")
local ReplicatedStorage = game:GetService("ReplicatedStorage")
local Catalog = require(ReplicatedStorage.Shared.EggCatalog)
local Pets = require(ReplicatedStorage.Shared.PetCatalog)
local Mastery = require(ReplicatedStorage.Shared.FamilyMastery)
local Daily = require(ReplicatedStorage.Shared.DailyContracts)
local QuestState = require(script.Parent.QuestState)
local QuestRotation = require(ReplicatedStorage.Shared.QuestRotation)
-- Retired daily contracts (hatching v3 to v8). Kept only to validate and
-- upgrade old saves; v9 replaces them with `quests`.
local LegacyContracts = { { id = "runs", target = 2 }, { id = "chain", target = 3 }, { id = "score", target = 500 } }
local function legacyContracts(day) return { day = day, progress = { runs = 0, chain = 0, score = 0 }, claimedMask = 0 } end
local HueState=require(script.Parent.HueState)
local MaterialState=require(script.Parent.MaterialState)
local MaterialCatalog=require(ReplicatedStorage.Shared.MaterialCatalog)

local ToyState=require(script.Parent.ToyState)
local FeatureState=require(script.Parent.FeatureState)
local ToyCatalog=require(ReplicatedStorage.Shared.ToyCatalog)
local FeatureCatalog=require(ReplicatedStorage.Shared.FeatureCatalog)
local Guard=require(script.Parent.HatchGuard)
local Purchases=require(script.Parent.PurchaseState)
local Faceplates=require(script.Parent.FaceplateState)
local Wearables=require(script.Parent.WearableState)
local BallThemes=require(script.Parent.BallThemeState)
local Lifetime=require(script.Parent.LifetimeState)
local PlayDate=require(script.Parent.PlayDateState)
local Coach=require(ReplicatedStorage.Shared.CoachMarks)
local BoardConfig=require(ReplicatedStorage.Shared.BoardConfig)
local HeatPayout=require(ReplicatedStorage.Shared.HeatPayout)
local StampCard=require(ReplicatedStorage.Shared.StampCard)
local BookCatalog=require(ReplicatedStorage.Shared.BookCatalog)
local HueCatalog=require(ReplicatedStorage.Shared.HueCatalog)

local Hatching = { LeaseSeconds = 90, RenewSeconds = 20 }
local store = require(script.Parent.ProgressStore)
local random = Random.new()

local function clone(value)
	if type(value) ~= "table" then return value end
	local result = {}
	for key, child in pairs(value) do result[key] = clone(child) end
	return result
end

local function integer(value, maximum)
	return type(value) == "number" and value == math.floor(value)
		and value >= 0 and value <= (maximum or 1000000000)
end

local function defaultAdapter()
	return {
		now = function() return DateTime.now().UnixTimestampMillis / 1000 end,
		guid = function() return HttpService:GenerateGUID(false) end,
		random = function() return random:NextNumber() end,
		wait = task.wait,
		update = function(key, transform)
			return store:UpdateAsync(key, transform)
		end,
	}
end

local function legacyRecord(profile)
	profile = profile or {}
	local trials = if integer(profile.trials, 31) then profile.trials else 0
	return {
		rank = profile.rank or 0, hatchCharge = profile.charge or 0,
		trials = bit32.band(trials, 7), rareTrials = bit32.band(trials, 24),
		companionId = profile.companionId,
	}
end

local function dayOf(now)
	return Daily.dayOf(now)
end

local function migrate(record, now)
	local mask = 0
	local rank = if integer(record.rank) then math.min(record.rank, #Pets) else 0
	local trials = bit32.bor(if integer(record.trials, 31) then record.trials else 0,
		if integer(record.rareTrials, 31) then record.rareTrials else 0)
	for index = 1, rank do mask = bit32.bor(mask, Catalog.bit(Pets[index].id)) end
	for _, pet in ipairs(Pets.rares) do
		if bit32.band(trials, pet.trial.bit) ~= 0 then mask = bit32.bor(mask, Catalog.bit(pet.id)) end
	end
	local nextPet = Pets[rank + 1]
	local charge = if nextPet and integer(record.hatchCharge, 1000000)
		then math.min(record.hatchCharge, nextPet.charge - 1) else 0
	local mastery, challenges = {}, {}
	for _, family in ipairs(Catalog.Families) do mastery[family], challenges[family] = 0, 0 end
	local state = {
		version = 5, hueAssignments = {}, migrated = true, welcomeCredited = true,
		nectar = charge + 6, inventoryMask = mask, mastery = mastery, misses = 0,
		masteryChallenges = challenges, masteryLegacyMask = 0, totalWins = 0,
		contracts = legacyContracts(dayOf(now)),
		revision = 0, epoch = 0, operationSeq = 0, lastAwardSeq = 0,
		dailyClaimDay = dayOf(now),
		petDay = dayOf(now), petCount = 0,
		lease = { token = "", expiresAt = 0 },
	}
	return FeatureState.upgrade(ToyState.upgrade(MaterialState.upgrade(HueState.upgrade(state))))
end

local function validBase(state,version)
	if type(state) ~= "table" or state.version ~= version or state.migrated ~= true
		or state.welcomeCredited ~= true or not integer(state.nectar)
		or not integer(state.inventoryMask, 127) or not integer(state.misses, 7)
		or not integer(state.revision) or not integer(state.epoch)
		or not integer(state.operationSeq) or not integer(state.lastAwardSeq)
		or type(state.dailyClaimDay) ~= "string"
		or type(state.mastery) ~= "table" or type(state.masteryChallenges) ~= "table"
		or not integer(state.masteryLegacyMask, 15) or not integer(state.totalWins)
		or (version < 9 and (type(state.contracts) ~= "table" or type(state.contracts.progress) ~= "table"
			or type(state.contracts.day) ~= "string" or not integer(state.contracts.claimedMask, 7)))
		or (version >= 9 and state.contracts ~= nil)
		or type(state.lease) ~= "table"
		or type(state.lease.token) ~= "string" or type(state.lease.expiresAt) ~= "number" then
		return false
	end
	local claimDay = tonumber(state.dailyClaimDay)
	if state.lease.expiresAt~=state.lease.expiresAt or math.abs(state.lease.expiresAt)==math.huge then return false end
	if state.lastOperation~=nil and(type(state.lastOperation)~="table"or type(state.lastOperation.id)~="string"
		or not integer(state.lastOperation.sequence)or state.lastOperation.sequence<1 or state.lastOperation.sequence~=state.operationSeq
		or(state.lastOperation.digest~=nil and(type(state.lastOperation.digest)~="string"or #state.lastOperation.digest>120)))then return false end
	if not claimDay or claimDay ~= math.floor(claimDay) or math.abs(claimDay) > 1000000000 then return false end
	for _, family in ipairs(Catalog.Families) do
		if not integer(state.mastery[family], Mastery.MaxPoints)
			or not integer(state.masteryChallenges[family], 7) then return false end
	end
	if version < 9 then
		local contractDay = tonumber(state.contracts.day)
		if not contractDay or contractDay ~= math.floor(contractDay) or math.abs(contractDay) > 1000000000 then return false end
		for _, item in ipairs(LegacyContracts) do
			if not integer(state.contracts.progress[item.id], item.target) then return false end
		end
	end
	if state.lastHatch ~= nil then
		if type(state.lastHatch) ~= "table" or type(state.lastHatch.id) ~= "string"
			or not Pets.byId[state.lastHatch.petId] then return false end
	end
	return true
end

local function canonicalDay(value)
	local number=if type(value)=="string"then tonumber(value)else nil
	return number~=nil and number==math.floor(number)and math.abs(number)<=1000000000 and tostring(number)==value
end
local function validVersion(state,version,legacy)
	if not validBase(state,version)or not canonicalDay(state.petDay)or not integer(state.petCount,5)or not(if legacy then HueState.validLegacy(state)else HueState.valid(state))then return false end
	local receipt=state.lastPetAward
	if state.petCount==0 then return receipt==nil end
	return type(receipt)=="table"and type(receipt.id)=="string"and #receipt.id>0 and #receipt.id<=100
		and integer(receipt.sequence)and receipt.sequence>=state.petCount and receipt.sequence<=state.operationSeq
		and receipt.day==state.petDay and Pets.byId[receipt.petId]~=nil
		and (receipt.sequence~=state.operationSeq or (state.lastOperation and state.lastOperation.id==receipt.id))
end

local function validV6(state)return validVersion(state,6,false)end
local function validV7(state)
 -- Version-specific historical validation never interprets new working fields.
 return validVersion(state,7,false)and HueState.validHistorical(state)and MaterialState.valid(state)
end
local function validV8(state)return validVersion(state,8,false)and MaterialState.valid(state)and ToyState.valid(state)and FeatureState.valid(state)and Guard.valid(state)and Purchases.valid(state)and Faceplates.valid(state)end
-- v9: daily contracts retired, quests added (QUESTS-DIFFICULTY-PLAN section 3).
local function validV9(state)return validVersion(state,9,false)and QuestState.valid(state.quests)and MaterialState.valid(state)and ToyState.valid(state)and FeatureState.valid(state)and Guard.valid(state)and Purchases.valid(state)and Faceplates.valid(state)end
-- v10: pet wearables (owned + equipped per pet) beside the wallet.
local function validV10(state)return validVersion(state,10,false)and Wearables.valid(state)and QuestState.valid(state.quests)and MaterialState.valid(state)and ToyState.valid(state)and FeatureState.valid(state)and Guard.valid(state)and Purchases.valid(state)and Faceplates.valid(state)end
-- v11 (batch 2026-11-13): ball themes (owned + equipped) and the play-forever
-- lifetime fields (`stats` counters, `stamps`, collection `book` claims).
-- Pet Park (K1): optional additive `playDate` on v11, valid when missing (no version bump).
-- Onboarding (v1 track A): optional additive `coachMask` on v11, valid when missing (no version bump).
local function valid(state)return validVersion(state,11,false)and BallThemes.valid(state)and Lifetime.valid(state)and PlayDate.valid(state)and Coach.valid(state)and Wearables.valid(state)and QuestState.valid(state.quests)and MaterialState.valid(state)and ToyState.valid(state)and FeatureState.valid(state)and Guard.valid(state)and Purchases.valid(state)and Faceplates.valid(state)end
Hatching.validV10,Hatching.valid=validV10,valid

-- Upgrade only inside the lease-acquisition UpdateAsync callback. Legacy
-- duplicate marks and already-earned sparkle finishes survive without new credits.
local function upgrade(state, now, userId)
	if type(state)~="table"then return state end
	local nextState=state
	if state.version==2 then
		nextState=clone(state)
		if type(nextState.mastery)~="table"then return state end
		local challenges,legacy={},0
		for index,family in ipairs(Catalog.Families)do
			if not integer(nextState.mastery[family],3)then return state end
			challenges[family]=0
			if nextState.mastery[family]==3 then legacy=bit32.bor(legacy,bit32.lshift(1,index-1))end
		end
		nextState.version,nextState.masteryChallenges,nextState.masteryLegacyMask=3,challenges,legacy
		nextState.totalWins,nextState.contracts=0,legacyContracts(dayOf(now))
	end
	if nextState.version==3 then
		if not validBase(nextState,3)or nextState.petDay~=nil or nextState.petCount~=nil or nextState.lastPetAward~=nil then return state end
		nextState=clone(nextState);nextState.version=4;nextState.petDay=dayOf(now);nextState.petCount=0
	end
	if nextState.version==4 then
        -- Validate the complete historical record before adding any v5 namespace.
        if not validVersion(nextState,4,true)or nextState.hueAssignments~=nil or nextState.heldHueEgg~=nil or nextState.hueLastPurchase~=nil then return state end
        nextState=clone(nextState);nextState.version=5;nextState.hueAssignments={}
    end
	if nextState.version==5 then
		if not validBase(nextState,5)or not canonicalDay(nextState.petDay)or not integer(nextState.petCount,5)or not HueState.validV5(nextState)
			or nextState.hueInventory~=nil or nextState.petHues~=nil or nextState.hueItemReceipts~=nil or nextState.hueReceiptOrder~=nil
			or nextState.hueReservation~=nil or nextState.pendingHueResult~=nil or nextState.hueMigrationId~=nil or nextState.hueMigrationAcknowledged~=nil or nextState.legacyHueEgg~=nil or nextState.legacyHueRedemption~=nil or nextState.legacyLastHueResult~=nil then return state end
		-- Validate the full old award namespace as well, before freezing its proofs.
		if not validVersion(nextState,5,false)then return state end
		nextState=HueState.upgrade(nextState)
	end
	if nextState.version==6 then
		if not validV6(nextState)then return state end
		for _,key in ipairs({"materialUnlocks","petMaterials","materialReceipts","materialReceiptOrder","materialReservation","pendingMaterialResult","lastMaterialResult"})do if nextState[key]~=nil then return state end end
		nextState=MaterialState.upgrade(nextState)
	end
	if nextState.version==7 then
		if not validV7(nextState)then return state end
		for _,key in ipairs({"toyUnlocks","petToys","toyReceipts","toyReceiptOrder","toyReservation","pendingToyResult","lastToyResult","featureStock","petFeatures","featureReceipts","featureReceiptOrder","featureReservation","pendingFeatureResult","lastFeatureResult"})do if nextState[key]~=nil then return state end end
		nextState=FeatureState.upgrade(ToyState.upgrade(nextState))
	end
	if nextState.version==8 then
		-- Validate the whole v8 record, then retire contracts and draw quests.
		if not validV8(nextState)or nextState.quests~=nil then return state end
		nextState=clone(nextState);nextState.contracts=nil;nextState.version=9
		nextState.quests=QuestRotation.fresh(userId,tonumber(dayOf(now)))
	end
	if nextState.version==9 then
		-- Validate the whole v9 record (quests sanitised first, as at load), then
		-- add an empty wearables namespace. Wallet, pets and everything else carry over.
		-- v9 never wrote petWearables: a stray one is sanitised (kept only if it is a
		-- valid v10 namespace for this record), never a reason to fail the load.
		local stray=nextState.petWearables
		local candidate=clone(nextState);candidate.petWearables=nil
		candidate.quests=QuestState.sanitize(candidate.quests,dayOf(now),userId)
		if not validV9(candidate)then return state end
		nextState=Wearables.upgrade(candidate)
		if stray~=nil then
			local probe=clone(nextState);probe.petWearables=clone(stray)
			if Wearables.valid(probe)then nextState=probe end
		end
	end
	if nextState.version==10 then
		-- Validate the whole v10 record (quests sanitised first, as at load), then add
		-- the v11 namespaces with empty defaults. v10 never wrote them: a stray field is
		-- dropped, never a reason to fail the load. Wallet, pets and everything else carry over.
		local candidate=clone(nextState)
		candidate.ballThemes,candidate.stats,candidate.stamps,candidate.book=nil,nil,nil,nil
		candidate.quests=QuestState.sanitize(candidate.quests,dayOf(now),userId)
		if not validV10(candidate)then return state end
		candidate.version=11
		candidate.ballThemes=BallThemes.fresh()
		candidate.stats=Lifetime.freshStats();candidate.stamps=0;candidate.book=Lifetime.freshBook()
		nextState=candidate
	end
	return nextState
end

local function accept(handle, record, acquiring)
	if acquiring then
		handle.profileRecord = {}
		for key, value in pairs(record) do
			if key ~= "hatching" then handle.profileRecord[key] = clone(value) end
		end
	end
	handle.state = clone(record.hatching)
	handle.companionId = if Catalog.isOwned(handle.state.inventoryMask, record.companionId)
		then record.companionId else nil
	handle.nextRunSeq = math.max(handle.nextRunSeq or 1, handle.state.lastAwardSeq + 1)
end

function Hatching.load(userId, profile, adapter)
	adapter = adapter or defaultAdapter()
	local handle = {
		key = "player_" .. userId, userId = userId, adapter = adapter, token = adapter.guid(),
		status = "Loading", busy = false, nextRunSeq = 1,
	}
	if profile and profile.loadFailed then
		handle.state = upgrade(migrate(legacyRecord(profile), adapter.now()), adapter.now(), userId)
		handle.state.nectar = 0
		handle.status = "Temporary"
		return handle
	end
	local reason = "Unavailable"
	local function acquire(previous)
		local root = if type(previous) == "table" then clone(previous) else legacyRecord(profile)
		local state = root.hatching
		state = upgrade(if state == nil then migrate(root, adapter.now()) else state, adapter.now(), userId)
		-- Malformed or old-catalogue quests become a fresh draw; never a failed load.
		if type(state) == "table" and type(state.version) == "number" and state.version >= 10 then state.quests = QuestState.sanitize(state.quests, dayOf(adapter.now()), userId) end
		-- A malformed Play date field is dropped, never a failed load.
		if type(state) == "table" and state.playDate ~= nil then state.playDate = PlayDate.sanitize(state.playDate) end
		-- A malformed coach mask is dropped (reads 0), never a failed load.
		if type(state) == "table" and state.coachMask ~= nil then state.coachMask = Coach.sanitize(state.coachMask) end
		if not valid(state) then reason = "InvalidData"; return nil end
		state = clone(state)
		local now = adapter.now()
		-- A timed-out acquire may already have committed. Retry the same token
		-- without taking another epoch or locking this connection out of itself.
		if state.lease.token == handle.token and state.lease.expiresAt > now then
			root.hatching = state
			return root
		end
		if state.lease.token ~= "" and state.lease.expiresAt > now then reason = "Locked"; return nil end
		state.epoch += 1
		state.revision += 1
		state.lease = { token = handle.token, expiresAt = now + Hatching.LeaseSeconds }
		root.hatching = state
		return root
	end
	local ok, record
	for attempt = 1, 3 do
		ok, record = pcall(adapter.update, handle.key, acquire)
		if ok then break end
		if attempt < 3 and adapter.wait then adapter.wait(attempt * 0.5) end
	end
	if ok and record and record.hatching and record.hatching.lease.token == handle.token then
		accept(handle, record, true)
		handle.epoch = handle.state.epoch
		handle.status = "Ready"
		if handle.state.hueReservation then Hatching.resumeHueReservation(handle) end
		if handle.state.materialReservation then Hatching.resumeMaterialReservation(handle)end
		if handle.state.toyReservation then Hatching.resumeItemReservation(handle,"toy")end
		if handle.state.featureReservation then Hatching.resumeItemReservation(handle,"feature")end
	else
		handle.state = upgrade(migrate(legacyRecord(profile), adapter.now()), adapter.now(), userId)
		handle.state.nectar = 0
		handle.status = if ok then reason else "Unavailable"
		if not ok then warn("Egg Drop hatching load failed:", record) end
	end
	return handle
end

-- Paid-random-items policy (BUILD-PLAN F1 architect change 6). The host sets
-- `handle.restricted` (true until PolicyService says otherwise: fail closed). A
-- restricted player's Star-priced egg gives this fixed next item instead of a roll;
-- the same values are published so the client can show "Next: <item>" before buying.
function Hatching.nextFixed(state)
	local hatch = {}
	for id, recipe in pairs(Catalog.ById) do
		if not recipe.retired then hatch[id] = Catalog.fixedNext(id, state.inventoryMask) end
	end
	return {
		hatch = hatch,
		toy = ToyCatalog.fixedNext(ToyCatalog.remaining(state.toyUnlocks)),
		material = MaterialCatalog.fixedNext(MaterialCatalog.remaining(state.materialUnlocks)),
		hue = HueCatalog.fixedNext(state.hueInventory),
		feature = FeatureCatalog.fixedNext(state.featureStock),
	}
end
local function isRestricted(handle) return handle.restricted == true end

function Hatching.public(handle)
	local state = handle.state
	if not state then return { status = handle.status, revision = 0 } end
	local ranks, details = {}, {}
	for _, family in ipairs(Catalog.Families) do
		ranks[family] = Mastery.rank(state.mastery[family], state.masteryChallenges[family])
		details[family] = Mastery.describe(state.mastery[family], state.masteryChallenges[family])
	end
	local public = {
		status = handle.status, revision = state.revision, nectar = state.nectar,
		masteryRanks = ranks, masteryDetails = details, masteryChallenges = clone(state.masteryChallenges),
		masteryLegacyMask = state.masteryLegacyMask, totalWins = state.totalWins,
		quests = QuestState.public(state.quests, dayOf(handle.adapter.now()), handle.userId, handle.passMultiplier or 1, handle.adapter.now()),
		lastRunReward = clone(state.lastRunReward), lastQuestClaim = clone(state.lastQuestClaim),
		misses = state.misses, inventoryMask = state.inventoryMask, mastery = clone(state.mastery),
		lastHatch = clone(state.lastHatch),
		hues=clone(state.hues or {}),lastHueResult=HueState.publicReceipt(state.lastHueResult),
        heldHueEgg=clone(state.heldHueEgg),hueLastPurchase=HueState.publicReceipt(state.hueLastPurchase),
		petDay = state.petDay, petCount = state.petCount, lastPetAward = clone(state.lastPetAward),
		-- dailyBonus: the reward of the stamp the next daily claim adds (stamps % 7).
		dailyDay = dayOf(handle.adapter.now()), dailyBonus = StampCard.reward(state.stamps),
		dailyAvailable = handle.status == "Ready" and tonumber(state.dailyClaimDay) < tonumber(dayOf(handle.adapter.now())),
	}
	-- Play-forever v1 (additive): stamp card, collection book, lifetime records, and the
	-- paid-random-items policy view (restricted players see the fixed next item).
	public.stamps = state.stamps or 0
	public.stampReward = StampCard.reward(state.stamps)
	public.stampDay = state.dailyClaimDay
	public.stampCard = { rewards = table.clone(StampCard.Rewards), onCard = StampCard.onCard(state.stamps), next = StampCard.position(state.stamps) }
	public.book = BookCatalog.public(state)
	local stats = {}
	for key, value in pairs(state.stats or {}) do if key ~= "parkGames" then stats[key] = value end end
	public.stats = stats
	-- Pet Park Play date progress for today: {day, count, target, reward, done}.
	public.playDate = PlayDate.public(state, dayOf(handle.adapter.now()))
	-- Onboarding: one-time coach cards already shown (0 when the field is missing).
	public.coachMask = Coach.mask(state.coachMask)
	-- QA Q5: Stars from rounds saved today in this session (not saved; no daily cap).
	public.todayEarned = Hatching.roundStarsToday(handle, dayOf(handle.adapter.now()))
	public.restricted = handle.restricted == true
	public.nextFixed = Hatching.nextFixed(state)
	for key,value in pairs(HueState.public(state))do public[key]=value end
	for key,value in pairs(MaterialState.public(state))do public[key]=value end
	for key,value in pairs(ToyState.public(state))do public[key]=value end
	for key,value in pairs(FeatureState.public(state))do public[key]=value end
	for key,value in pairs(Purchases.public(state))do public[key]=value end
	for key,value in pairs(Faceplates.public(state))do public[key]=value end
	for key,value in pairs(Wearables.public(state))do public[key]=value end
	for key,value in pairs(BallThemes.public(state))do public[key]=value end
	public.materialAvailable=MaterialCatalog.available(ReplicatedStorage:FindFirstChild("PetMaterials"))
	public.catalogVersion=require(ReplicatedStorage.Shared.HueCatalog).CatalogVersion
	return public
end

local function fenced(handle, state, now)
	return valid(state) and state.epoch == handle.epoch and state.lease.token == handle.token
		and state.lease.expiresAt > now
end

-- Pending operations retain their identity and RNG candidate after an ambiguous
-- write failure. A callback retry can never charge twice or choose another pet.
local function petProof(pending,state)
	local receipt=state.lastPetAward
	return pending.kind=="pet"and receipt and receipt.id==pending.id and receipt.sequence==pending.sequence
		and receipt.sequence==pending.candidate.sequence
		and receipt.day==pending.candidate.day and receipt.petId==pending.candidate.petId
end
local function committed(pending,state)
	if pending.kind=="pet"then return petProof(pending,state)end
	if pending.kind=="hue"then return HueState.proof(state,pending.candidate)end
	if pending.kind=="material"then return MaterialState.proof(state,pending.candidate)end
	if pending.kind=="toy"then return ToyState.proof(state,pending.candidate)end
	if pending.kind=="feature"then return FeatureState.proof(state,pending.candidate)end
	-- The digest binds an operation id to its arguments: a reused id with other
	-- arguments is not proof that this request committed.
	return state.lastOperation and state.lastOperation.id==pending.id and state.lastOperation.digest==pending.digest
end
local function reusedId(pending,state)
	return state.lastOperation and state.lastOperation.id==pending.id and state.lastOperation.digest~=pending.digest
end
-- QA 2026-11-13 Q5 results strip ("Today: ★ N earned"): Stars this session's saved
-- rounds paid today. Session memory on the handle only, never saved and never a
-- required field: a rejoin starts the count again, and a new day resets it.
local function noteRoundStars(handle, pending)
	if type(pending) ~= "table" or string.sub(pending.signature or "", 1, 6) ~= "award:" then return end
	local reward = handle.state and handle.state.lastRunReward
	local day = pending.candidate and pending.candidate.day
	if type(reward) ~= "table" or type(reward.total) ~= "number" or reward.total ~= reward.total or day == nil then return end
	local today = handle.roundStarsToday
	if type(today) ~= "table" or today.day ~= tostring(day) then
		today = { day = tostring(day), stars = 0 }
		handle.roundStarsToday = today
	end
	today.stars = math.min(1000000000, today.stars + math.max(0, math.floor(reward.total)))
end
function Hatching.roundStarsToday(handle, day)
	local today = handle and handle.roundStarsToday
	if type(today) ~= "table" or today.day ~= tostring(day) then return 0 end
	return today.stars
end

local function transact(handle, signature, expectedRevision, apply, candidate, operationId, kind, digest)
	if handle.busy then return false, "Busy" end
	if handle.status ~= "Ready" and handle.status ~= "Retrying" then return false, handle.status end
	local pending = handle.pending
	if pending and pending.signature ~= signature then return false, "Pending" end
	if not pending then
		if expectedRevision ~= handle.state.revision then return false, "RevisionChanged" end
		-- Reject impossible stage/ownership/balance requests locally. The same
		-- checks run again inside UpdateAsync against its authoritative snapshot.
		local allowed, failure = apply(clone(handle.state), candidate)
		if not allowed then return false, failure end
		pending = {
			signature = signature, id = operationId or handle.adapter.guid(), revision = expectedRevision, kind=kind,
			sequence = handle.state.operationSeq + 1, apply = apply, candidate = candidate, digest = digest,
		}
		if reusedId(pending, handle.state) then return false, "OperationConflict" end
		handle.pending = pending
	end
	handle.busy = true
	local reason = "Unavailable"
	local ok, record = pcall(handle.adapter.update, handle.key, function(previous)
		if type(previous) ~= "table" or not fenced(handle, previous.hatching, handle.adapter.now()) then
			reason = "SessionLost"; return nil
		end
		local root = clone(previous)
		local state = root.hatching
		if committed(pending,state)then return root end -- Proof precedes calendar expiry.
		if reusedId(pending,state)then reason = "OperationConflict"; return nil end
		if state.revision ~= pending.revision or state.operationSeq + 1 ~= pending.sequence then
			 reason = "RevisionChanged"; return if pending.kind=="pet"or pending.kind=="hue"or pending.kind=="material"or pending.kind=="toy"or pending.kind=="feature"then root else nil
		end
		local before = { nectar = state.nectar, inventoryMask = state.inventoryMask }
		local allowed, failure = pending.apply(state, pending.candidate)
		if not allowed then reason = failure; return if pending.kind=="pet"or pending.kind=="hue"or pending.kind=="material"or pending.kind=="toy"or pending.kind=="feature"then root else nil end
		Lifetime.record(before, state, pending.signature)
		state.revision += 1
		state.operationSeq = pending.sequence
		state.lastOperation = { id = pending.id, sequence = pending.sequence, digest = pending.digest }
		state.lease.expiresAt = handle.adapter.now() + Hatching.LeaseSeconds
		if not valid(state)then reason="InvalidData";return previous end
		return root
	end)
	handle.busy = false
	if ok and record and record.hatching and committed(pending,record.hatching)then
		accept(handle, record)
		handle.pending = nil
		handle.status = "Ready"
		noteRoundStars(handle, pending)
		return true, "Saved"
	end
	if ok and(pending.kind=="pet"or pending.kind=="hue"or pending.kind=="material"or pending.kind=="toy"or pending.kind=="feature")and record and fenced(handle,record.hatching,handle.adapter.now())then
		-- A fenced unchanged return proves that this operation did not commit.
		-- Expired-day/revision refusals must not strand Retrying with no pending.
		accept(handle,record);handle.pending=nil;handle.status="Ready"
		return false,reason
	end
	if not ok then
		handle.status = "Retrying"
		warn("Egg Drop hatching save failed:", record)
		return false, "Retrying"
	end
	handle.pending = nil
	if reason == "SessionLost" then handle.status = "SessionLost" end
	return false, reason
end

-- Resume the saved operation without rebuilding a command, drawing another
-- candidate, or changing its revision/identity after a transient store error.
function Hatching.retry(handle)
	local pending = handle.pending
	if not pending then return false, "NoPending" end
	if pending.phase=="reserve"then return Hatching.reserveHue(handle,pending.candidate)end
	if pending.phase=="materialReserve"then return Hatching.reserveMaterial(handle,pending.candidate)end
	if pending.phase=="toyReserve"or pending.phase=="featureReserve"then return Hatching.reserveItem(handle,pending.kind,pending.candidate)end
	return transact(handle, pending.signature, pending.revision, pending.apply, pending.candidate)
end

-- A durable private candidate closes the retry/reconnect RNG gap. Reservation
-- changes neither revision nor wallet; settlement alone is a visible operation.
function Hatching.resumeHueReservation(handle)
	local candidate=handle.state.hueReservation
	if not candidate then return false,"NoPending"end
	handle.pending={kind="hue",signature="hue:"..candidate.quote.id,id=candidate.operationId,sequence=candidate.sequence,
		revision=handle.state.revision,apply=HueState.apply,candidate=clone(candidate)}
	handle.status="Retrying"
	return Hatching.retry(handle)
end
function Hatching.reserveHue(handle,candidate)
	if handle.busy then return false,"Busy"end
	handle.busy=true
	local reason="Unavailable"
	local ok,record=pcall(handle.adapter.update,handle.key,function(previous)
		if type(previous)~="table"or not fenced(handle,previous.hatching,handle.adapter.now())then reason="SessionLost";return nil end
		local root=clone(previous);local state=root.hatching
		local receipt,same=HueState.find(state,candidate.quote)
		if receipt then reason=if same then "AlreadySaved"else "OperationConflict";return root end
		if state.hueReservation then
			if not HueState.same(state.hueReservation,candidate)then reason="PurchasePending"end
			return root
		end
		if state.revision~=candidate.quote.revision or state.operationSeq+1~=candidate.sequence then reason="RevisionChanged";return root end
		local allowed,why=HueState.purchaseEligibility(state);if not allowed then reason=why;return root end
		state.hueReservation=clone(candidate);return root
	end)
	handle.busy=false
	if not ok then handle.status="Retrying";warn("Egg Drop Hue reservation failed:",record);return false,"Retrying"end
	if not record or not record.hatching or not fenced(handle,record.hatching,handle.adapter.now())then
		handle.pending=nil;handle.status="SessionLost";return false,"SessionLost"
	end
	accept(handle,record)
	if HueState.proof(handle.state,candidate)then handle.pending=nil;handle.status="Ready";return true,"AlreadySaved"end
	if not HueState.same(handle.state.hueReservation,candidate)then handle.pending=nil;handle.status="Ready";return false,reason end
	handle.pending.phase=nil;handle.pending.revision=handle.state.revision
	return Hatching.retry(handle)
end

function Hatching.hueCommand(handle,action,value,revision)
	local quote=HueState.quote(action,value,revision)
	if not quote then return false,"InvalidHue"end
	if handle.status~="Ready"and handle.status~="Retrying"then return false,handle.status end
	if handle.pending and handle.pending.kind=="hue"and handle.pending.candidate.quote.id==quote.id
		and not HueState.same(handle.pending.candidate.quote,quote)then return false,"OperationConflict"end
	if handle.busy then return false,"Busy"end
	local receipt,same=HueState.find(handle.state,quote)
	if receipt then
		if not same then return false,"OperationConflict"end
		return true,"AlreadySaved",HueState.publicReceipt(receipt)
	end
	local signature="hue:"..quote.id
	local candidate=handle.pending and handle.pending.candidate
	if not handle.pending then
		if revision~=handle.state.revision then return false,"RevisionChanged"end
		if quote.catalogVersion==nil then return false,"LegacyPurchaseClosed"end
		candidate={quote=clone(quote),operationId=handle.adapter.guid(),sequence=handle.state.operationSeq+1}
		if action=="hueBuy"then
			local allowed,why=HueState.purchaseEligibility(handle.state);if not allowed then return false,why end
			candidate.itemId=if isRestricted(handle)then HueCatalog.fixedNext(handle.state.hueInventory)else HueCatalog.roll(handle.adapter.random());if not candidate.itemId then return false,"InvalidRoll"end
			handle.pending={kind="hue",signature=signature,id=candidate.operationId,sequence=candidate.sequence,revision=revision,apply=HueState.apply,candidate=candidate,phase="reserve"}
			local ok,why=Hatching.reserveHue(handle,candidate)
			local saved=if ok then HueState.find(handle.state,quote)else nil
			return ok,why,if saved then HueState.publicReceipt(saved)else nil
		end
	elseif handle.pending.signature~=signature then return false,"Pending"
	elseif handle.pending.phase=="reserve"then
		local ok,why=Hatching.reserveHue(handle,candidate);local saved=if ok then HueState.find(handle.state,quote)else nil
		return ok,why,if saved then HueState.publicReceipt(saved)else nil
	end
	local ok,reason=transact(handle,signature,revision,HueState.apply,candidate,if not handle.pending then candidate.operationId else nil,"hue")
	local result=if ok then HueState.find(handle.state,quote)else nil
	return ok,reason,if result then HueState.publicReceipt(result)else nil
end

function Hatching.resumeMaterialReservation(handle)
 local candidate=handle.state.materialReservation;if not candidate then return false,"NoPending"end
 handle.pending={kind="material",signature="material:"..candidate.quote.id,id=candidate.operationId,sequence=candidate.sequence,
  revision=handle.state.revision,apply=MaterialState.apply,candidate=clone(candidate)}
 handle.status="Retrying";return Hatching.retry(handle)
end
function Hatching.reserveMaterial(handle,candidate)
 if handle.busy then return false,"Busy"end;handle.busy=true
 local reason="Unavailable"
 local ok,record=pcall(handle.adapter.update,handle.key,function(previous)
  if type(previous)~="table"or not fenced(handle,previous.hatching,handle.adapter.now())then reason="SessionLost";return nil end
  local root=clone(previous);local state=root.hatching
  local receipt,same=MaterialState.find(state,candidate.quote)
  if receipt then reason=if same then "AlreadySaved"else "OperationConflict";return root end
  if state.materialReservation then
   if not MaterialState.same(state.materialReservation,candidate)then reason="PurchasePending"end;return root
  end
  if state.revision~=candidate.quote.revision or state.operationSeq+1~=candidate.sequence then reason="RevisionChanged";return root end
  local allowed,why=MaterialState.purchaseEligibility(state,candidate.quote);if not allowed then reason=why;return root end
  state.materialReservation=clone(candidate)
  if not valid(state)then reason="InvalidData";return previous end
  return root
 end)
 handle.busy=false
 if not ok then handle.status="Retrying";warn("Egg Drop Material reservation failed:",record);return false,"Retrying"end
 if not record or not record.hatching or not fenced(handle,record.hatching,handle.adapter.now())then handle.pending=nil;handle.status="SessionLost";return false,"SessionLost"end
 accept(handle,record)
 if MaterialState.proof(handle.state,candidate)then handle.pending=nil;handle.status="Ready";return true,"AlreadySaved"end
 if not MaterialState.same(handle.state.materialReservation,candidate)then handle.pending=nil;handle.status="Ready";return false,reason end
 handle.pending.phase=nil;handle.pending.revision=handle.state.revision;return Hatching.retry(handle)
end
function Hatching.materialCommand(handle,action,value,revision)
 local quote=MaterialState.quote(action,value,revision);if not quote then return false,"InvalidMaterial"end
 if handle.status~="Ready"and handle.status~="Retrying"then return false,handle.status end
 if handle.pending and handle.pending.kind=="material"and handle.pending.candidate.quote.id==quote.id and not MaterialState.same(handle.pending.candidate.quote,quote)then return false,"OperationConflict"end
 if handle.busy then return false,"Busy"end
 local receipt,same=MaterialState.find(handle.state,quote)
 if receipt then return if same then true else false,if same then "AlreadySaved"else "OperationConflict",if same then MaterialState.publicReceipt(receipt)else nil end
 local signature="material:"..quote.id;local candidate=handle.pending and handle.pending.candidate
 if not handle.pending then
  if revision~=handle.state.revision then return false,"RevisionChanged"end
  candidate={quote=clone(quote),operationId=handle.adapter.guid(),sequence=handle.state.operationSeq+1}
  if action=="materialBuy"then
   if quote.poolVersion~=MaterialCatalog.PoolVersion then return false,"LegacyPurchaseClosed"end
   local allowed,why=MaterialState.purchaseEligibility(handle.state,quote);if not allowed then return false,why end
   candidate.finishId=if isRestricted(handle)then MaterialCatalog.fixedNext(quote.eligible)else MaterialCatalog.roll(quote.eligible,handle.adapter.random());if not candidate.finishId then return false,"InvalidRoll"end
   handle.pending={kind="material",signature=signature,id=candidate.operationId,sequence=candidate.sequence,revision=revision,apply=MaterialState.apply,candidate=candidate,phase="materialReserve"}
   local ok,why=Hatching.reserveMaterial(handle,candidate);local saved=if ok then MaterialState.find(handle.state,quote)else nil
   return ok,why,if saved then MaterialState.publicReceipt(saved)else nil
  end
 elseif handle.pending.signature~=signature then return false,"Pending"
 elseif handle.pending.phase=="materialReserve"then
  local ok,why=Hatching.reserveMaterial(handle,candidate);local saved=if ok then MaterialState.find(handle.state,quote)else nil
  return ok,why,if saved then MaterialState.publicReceipt(saved)else nil
 end
 local ok,reason=transact(handle,signature,revision,MaterialState.apply,candidate,if not handle.pending then candidate.operationId else nil,"material")
 local saved=if ok then MaterialState.find(handle.state,quote)else nil
 return ok,reason,if saved then MaterialState.publicReceipt(saved)else nil
end


-- These two bounded item families share the existing root writer and fence.
local itemStates={toy=ToyState,feature=FeatureState}
local itemCatalogs={toy=ToyCatalog,feature=FeatureCatalog}
function Hatching.resumeItemReservation(handle,kind)
 local api=itemStates[kind];local candidate=handle.state[kind.."Reservation"]
 if not api or not candidate then return false,"NoPending"end
 handle.pending={kind=kind,signature=kind..":"..candidate.quote.id,id=candidate.operationId,sequence=candidate.sequence,
  revision=handle.state.revision,apply=api.apply,candidate=clone(candidate)}
 handle.status="Retrying";return Hatching.retry(handle)
end
function Hatching.reserveItem(handle,kind,candidate)
 local api=itemStates[kind];local key=kind.."Reservation"
 if handle.busy then return false,"Busy"end;handle.busy=true
 local reason="Unavailable"
 local ok,record=pcall(handle.adapter.update,handle.key,function(previous)
  if type(previous)~="table"or not fenced(handle,previous.hatching,handle.adapter.now())then reason="SessionLost";return nil end
  local root=clone(previous);local state=root.hatching
  local receipt,same=api.find(state,candidate.quote)
  if receipt then reason=if same then "AlreadySaved"else "OperationConflict";return root end
  if state[key]then if not api.same(state[key],candidate)then reason="PurchasePending"end;return root end
  if state.revision~=candidate.quote.revision or state.operationSeq+1~=candidate.sequence then reason="RevisionChanged";return root end
  local allowed,why=api.purchaseEligibility(state,candidate.quote);if not allowed then reason=why;return root end
  state[key]=clone(candidate)
  if not valid(state)then reason="InvalidData";return previous end
  return root
 end)
 handle.busy=false
 if not ok then handle.status="Retrying";warn("Egg Drop item reservation failed:",record);return false,"Retrying"end
 if not record or not record.hatching or not fenced(handle,record.hatching,handle.adapter.now())then handle.pending=nil;handle.status="SessionLost";return false,"SessionLost"end
 accept(handle,record)
 if api.proof(handle.state,candidate)then handle.pending=nil;handle.status="Ready";return true,"AlreadySaved"end
 if not api.same(handle.state[key],candidate)then handle.pending=nil;handle.status="Ready";return false,reason end
 handle.pending.phase=nil;handle.pending.revision=handle.state.revision;return Hatching.retry(handle)
end
local function itemCommand(handle,kind,action,value,revision)
 local api,catalog=itemStates[kind],itemCatalogs[kind]
 local quote=api.quote(action,value,revision);if not quote then return false,if kind=="toy"then "InvalidToy"else "InvalidFeature"end
 if handle.status~="Ready"and handle.status~="Retrying"then return false,handle.status end
 if handle.pending and handle.pending.kind==kind and handle.pending.candidate.quote.id==quote.id and not api.same(handle.pending.candidate.quote,quote)then return false,"OperationConflict"end
 if handle.busy then return false,"Busy"end
 local receipt,same=api.find(handle.state,quote)
 if receipt then return same,if same then "AlreadySaved"else "OperationConflict",if same then api.publicReceipt(receipt)else nil end
 local signature=kind..":"..quote.id;local candidate=handle.pending and handle.pending.candidate
 if not handle.pending then
  if revision~=handle.state.revision then return false,"RevisionChanged"end
  candidate={quote=clone(quote),operationId=handle.adapter.guid(),sequence=handle.state.operationSeq+1}
  if action==kind.."Buy"then
   local allowed,why=api.purchaseEligibility(handle.state,quote);if not allowed then return false,why end
   local awarded
   if isRestricted(handle)and kind=="toy"then awarded=catalog.fixedNext(quote.eligible)
   elseif isRestricted(handle)then awarded=catalog.fixedNext(handle.state.featureStock)
   elseif kind=="toy"then awarded=catalog.roll(quote.eligible,handle.adapter.random())
   else awarded=catalog.roll(handle.adapter.random())end
   if not awarded then return false,"InvalidRoll"end
   candidate[if kind=="toy"then "toyId"else "featureId"]=awarded
   handle.pending={kind=kind,signature=signature,id=candidate.operationId,sequence=candidate.sequence,revision=revision,apply=api.apply,candidate=candidate,phase=kind.."Reserve"}
   local ok,why=Hatching.reserveItem(handle,kind,candidate);local saved=if ok then api.find(handle.state,quote)else nil
   return ok,why,if saved then api.publicReceipt(saved)else nil
  end
 elseif handle.pending.signature~=signature then return false,"Pending"
 elseif handle.pending.phase==kind.."Reserve"then
  local ok,why=Hatching.reserveItem(handle,kind,candidate);local saved=if ok then api.find(handle.state,quote)else nil
  return ok,why,if saved then api.publicReceipt(saved)else nil
 end
 local ok,reason=transact(handle,signature,revision,api.apply,candidate,if not handle.pending then candidate.operationId else nil,kind)
 local saved=if ok then api.find(handle.state,quote)else nil
 return ok,reason,if saved then api.publicReceipt(saved)else nil
end
function Hatching.toyCommand(handle,action,value,revision)return itemCommand(handle,"toy",action,value,revision)end
function Hatching.featureCommand(handle,action,value,revision)return itemCommand(handle,"feature",action,value,revision)end

function Hatching.petCandidate(handle,leaseId,petId)
	return table.freeze({id=handle.adapter.guid(),day=dayOf(handle.adapter.now()),petId=petId,leaseId=leaseId,sequence=handle.state.operationSeq+1})
end
function Hatching.awardPet(handle,candidate)
	if type(candidate)~="table"then return false,"InvalidPetAward"end
	for key in pairs(candidate)do if key~="id"and key~="day"and key~="petId"and key~="leaseId"and key~="sequence"then return false,"InvalidPetAward"end end
	if type(candidate.id)~="string"or #candidate.id<1 or #candidate.id>100 or not canonicalDay(candidate.day)
		or not integer(candidate.sequence)or candidate.sequence<1
		or not Pets.byId[candidate.petId]or type(candidate.leaseId)~="string"or #candidate.leaseId<1 or #candidate.leaseId>100 then return false,"InvalidPetAward"end
	local receipt=handle.state.lastPetAward
	if receipt and receipt.id==candidate.id and receipt.sequence==candidate.sequence and receipt.day==candidate.day and receipt.petId==candidate.petId then return true,"AlreadySaved"end
	if candidate.sequence~=handle.state.operationSeq+1 then return false,"StalePetAward"end
	local fixed=table.freeze(clone(candidate))
	return transact(handle,"pet:"..fixed.id,handle.state.revision,function(state,captured)
		local current=dayOf(handle.adapter.now())
		if captured.day~=current then return false,"ExpiredDay"end
		if tonumber(current)<tonumber(state.petDay)then return false,"ClockRollback"end
		if state.lastHatch then return false,"RevealPending"end
		if not Catalog.isOwned(state.inventoryMask,captured.petId)then return false,"PetChanged"end
		local count=if tonumber(current)>tonumber(state.petDay)then 0 else state.petCount
		if count>=5 then return false,"PetCap"end
		if state.nectar>=1000000000 then return false,"BalanceLimit"end
		state.nectar+=1;state.petDay=current;state.petCount=count+1
		state.lastPetAward={id=captured.id,sequence=state.operationSeq+1,day=current,petId=captured.petId}
		return true
	end,fixed,fixed.id,"pet")
end

function Hatching.command(handle, action, value, expectedRevision)
	if type(action) ~= "string" or type(value) ~= "string" or #value > 100
		or not integer(expectedRevision) then return false, "InvalidCommand" end
	local signature = action .. ":" .. value .. ":" .. expectedRevision
	local candidate = handle.pending and handle.pending.candidate
	if action == "hatch" and not handle.pending then
		local recipe = Catalog.ById[value]
		if not recipe then return false, "UnknownEgg" end
		if recipe.retired then return false,"RetiredEgg"end
		if handle.busy then return false, "Busy" end
		if handle.status ~= "Ready" then return false, handle.status end
		if expectedRevision ~= handle.state.revision then return false, "RevisionChanged" end
		if handle.state.lastHatch or Guard.other(handle.state,"companion") then return false, "RevealPending" end
		if not Catalog.isOwned(handle.state.inventoryMask, "pip") then return false, "MeetPipFirst" end
		if handle.state.nectar < recipe.cost then return false, "NeedNectar" end
		-- Restricted players draw no random number: the pet is the recipe's fixed next one.
		if isRestricted(handle) then
			candidate = { id = handle.adapter.guid(), unit = 0, fixed = true }
		else
			candidate = { id = handle.adapter.guid(), unit = handle.adapter.random() }
		end
	end
	return transact(handle, signature, expectedRevision, function(state, choice)
		if action == "ack" then
			if Guard.other(state,"companion")then return false,"RevealPending"end
			if not state.lastHatch or state.lastHatch.id ~= value then return false, "HatchChanged" end
			state.lastHatch = nil
			return true
		elseif action == "daily" then
			local day = dayOf(handle.adapter.now())
			if value ~= day then return false, "DayChanged" end
			if tonumber(state.dailyClaimDay) >= tonumber(day) then return false, "DailyClaimed" end
			-- The daily gift is the stamp card: one stamp a day, paying the reward of the
			-- stamp being added (4,4,5,5,6,6,12 by stamps % 7). The count never resets.
			local stamps = state.stamps or 0
			local reward = StampCard.reward(stamps)
			if state.nectar + reward > 1000000000 then return false, "BalanceLimit" end
			if stamps >= Lifetime.Cap then return false, "StampLimit" end
			state.nectar += reward
			state.stamps = stamps + 1
			state.dailyClaimDay = day
			return true
		elseif action == "hatch" then
			local recipe = Catalog.ById[value]
			if not recipe then return false, "UnknownEgg" end
			if recipe.retired then return false,"RetiredEgg"end
			if state.lastHatch or Guard.other(state,"companion") then return false, "RevealPending" end
			if not Catalog.isOwned(state.inventoryMask, "pip") then return false, "MeetPipFirst" end
			if state.nectar < recipe.cost then return false, "NeedNectar" end
			local petId = if choice.fixed then Catalog.fixedNext(value, state.inventoryMask) else Catalog.roll(value, state.misses, choice.unit)
			if not petId then return false, "UnknownEgg" end
			local pet = Pets.byId[petId]
			local family = Catalog.family(petId)
			local duplicate = Catalog.isOwned(state.inventoryMask, petId)
			local previousRank = Mastery.rank(state.mastery[family], state.masteryChallenges[family])
			-- A duplicate refunds half its price so every paid outcome gives something
			-- (Roblox paid-random-items policy). Frozen legacy marks remain intact.
			local refund = if duplicate then math.floor(recipe.cost * Catalog.DuplicateRefund) else 0
			state.nectar += refund - recipe.cost
			state.inventoryMask = bit32.bor(state.inventoryMask, Catalog.bit(petId))
			-- Preserve earned protection while the active pool has no rare outcomes.
			if Catalog.hasRarePool(value)then state.misses = if pet.trial then 0 else math.min(7, state.misses + 1)end
			state.lastHatch = { id = choice.id, petId = petId, duplicate = duplicate, refund = refund,
				family = family, mastery = state.mastery[family], rare = pet.trial ~= nil, recipe = value,
				masteryRank = Mastery.rank(state.mastery[family], state.masteryChallenges[family]),
				promotedTo = if Mastery.rank(state.mastery[family], state.masteryChallenges[family]) > previousRank
					then Mastery.rank(state.mastery[family], state.masteryChallenges[family]) else 0 }
			return true
		end
		return false, "UnknownAction"
	end, candidate)
end

function Hatching.grantStarter(handle)
	if Catalog.isOwned(handle.state.inventoryMask, "pip") then return true, "AlreadyOwned" end
	return transact(handle, "starter", handle.state.revision, function(state, candidate)
		if Catalog.isOwned(state.inventoryMask, "pip") then return true end
		if state.lastHatch or Guard.other(state,"companion")then return false, "RevealPending" end
		-- The Welcome round is the first Stars round (onboarding v1): its Stars arrive with
		-- the Bear, in this same transaction, so they cannot be missed or paid twice.
		local stars = Coach.WelcomeStars
		if state.nectar + stars > 1000000000 then stars = 0 end
		state.nectar += stars
		state.inventoryMask = bit32.bor(state.inventoryMask, Catalog.bit("pip"))
		state.lastHatch = { id = candidate.id, petId = "pip", duplicate = false,
			family = "pip", mastery = state.mastery.pip, rare = false, starter = true, stars = stars }
		return true
	end, { id = handle.adapter.guid() })
end

-- One-time coach cards (onboarding v1): OR `bits` into the optional `coachMask`. Already saved
-- is a success with no write. OR-only, so an ambiguous write retried later is harmless.
function Hatching.coachMark(handle, bits)
	if not Coach.integer(bits) or bits < 1 then return false, "InvalidCoach" end
	if handle.status ~= "Ready" and handle.status ~= "Retrying" then return false, handle.status end
	if Coach.covers(handle.state.coachMask, bits) then return true, "AlreadySaved" end
	local signature = "coach:" .. bits
	local pending = handle.pending
	if pending and pending.signature ~= signature then return false, "Pending" end
	local candidate = if pending then pending.candidate else table.freeze({ bits = bits })
	return transact(handle, signature, handle.state.revision, function(state, captured)
		state.coachMask = Coach.merge(state.coachMask, captured.bits)
		return true
	end, candidate, nil, nil, "coach:" .. bits)
end

-- Robux purchase grant. The purchase id is the durable idempotency key, so a
-- repeated ProcessReceipt on any server can never grant twice.
function Hatching.grantPurchase(handle, purchaseId, stars, once)
	if type(purchaseId) ~= "string" or #purchaseId < 1 or #purchaseId > 100 then return false, "InvalidPurchase" end
	if handle.status ~= "Ready" and handle.status ~= "Retrying" then return false, handle.status end
	if Purchases.granted(handle.state, purchaseId) then return true, "AlreadyGranted" end
	local candidate = table.freeze({ purchaseId = purchaseId, stars = stars, once = once == true })
	local ok, reason = transact(handle, "purchase:" .. purchaseId, handle.state.revision, Purchases.apply, candidate, "purchase:" .. purchaseId)
	if not ok and reason == "AlreadyGranted" then return true, reason end
	return ok, reason
end

-- Faceplate Star purchase. `operationId` (client-made, per press) is the
-- idempotency key: a retry of the same id resumes the same pending operation,
-- and owning the plate already is a success that never charges again.
function Hatching.buyFaceplate(handle, operationId, plateId, price)
	if type(operationId) ~= "string" or #operationId < 1 or #operationId > 80 or type(plateId) ~= "string" or #plateId > 64 then return false, "InvalidFaceplate" end
	if handle.status ~= "Ready" and handle.status ~= "Retrying" then return false, handle.status end
	local signature = "faceplate:" .. operationId
	if Faceplates.owns(handle.state, plateId) and not (handle.pending and handle.pending.signature == signature) then return true, "AlreadyOwned" end
	local candidate = handle.pending and handle.pending.signature == signature and handle.pending.candidate
		or table.freeze({ plateId = plateId, price = price, operationId = operationId })
	if candidate.plateId ~= plateId then return false, "OperationConflict" end
	-- The digest binds the id to its plate, so a reused id for another plate is
	-- refused as OperationConflict instead of matching lastOperation as "Saved".
	local ok, reason = transact(handle, signature, handle.state.revision, Faceplates.apply, candidate, signature, nil, "plate:" .. candidate.plateId)
	if not ok and reason == "AlreadyOwned" then return true, reason end
	return ok, reason
end

-- Wearable Star purchase: fixed server price, debit and ownership in one fenced
-- transact, idempotent by the client's operation id; an owned item never charges again.
-- `equip` wears it at once in the same write.
function Hatching.buyWearable(handle, operationId, petId, itemId, price, equip)
	if type(operationId) ~= "string" or #operationId < 1 or #operationId > 80 or type(petId) ~= "string" or #petId > 32
		or type(itemId) ~= "string" or #itemId > 32 then return false, "InvalidWearable" end
	if handle.status ~= "Ready" and handle.status ~= "Retrying" then return false, handle.status end
	local signature = "wearable:" .. operationId
	local resuming = handle.pending and handle.pending.signature == signature
	if Wearables.owns(handle.state, petId, itemId) and not resuming then return true, "AlreadyOwned" end
	local candidate = resuming and handle.pending.candidate
		or table.freeze({ petId = petId, itemId = itemId, price = price, operationId = operationId, equip = equip == true })
	if candidate.petId ~= petId or candidate.itemId ~= itemId then return false, "OperationConflict" end
	local digest = "buy:" .. candidate.petId .. ":" .. candidate.itemId
	local ok, reason = transact(handle, signature, handle.state.revision, Wearables.applyBuy, candidate, signature, nil, digest)
	if not ok and reason == "AlreadyOwned" then return true, reason end
	return ok, reason
end

-- Equip (itemId) or take off (itemId == false) one slot. Ownership is checked
-- against the saved record; an unchanged slot is a success with no write.
function Hatching.equipWearable(handle, operationId, petId, slot, itemId)
	if type(operationId) ~= "string" or #operationId < 1 or #operationId > 80 or type(petId) ~= "string" or #petId > 32
		or type(slot) ~= "string" or #slot > 32 or (itemId ~= false and (type(itemId) ~= "string" or #itemId > 32)) then return false, "InvalidWearable" end
	if handle.status ~= "Ready" and handle.status ~= "Retrying" then return false, handle.status end
	local signature = "wear:" .. operationId
	local resuming = handle.pending and handle.pending.signature == signature
	if not resuming then
		local row, why = Wearables.equipResult(handle.state, petId, slot, itemId)
		if not row then return false, why end
		if Wearables.same(row.equipped, Wearables.equipped(handle.state, petId)) then return true, "NoChange" end
	end
	local candidate = resuming and handle.pending.candidate
		or table.freeze({ petId = petId, slot = slot, itemId = itemId, operationId = operationId })
	local digest = "wear:" .. candidate.petId .. ":" .. candidate.slot .. ":" .. tostring(candidate.itemId)
	local ok, reason = transact(handle, signature, handle.state.revision, Wearables.applyEquip, candidate, signature, nil, digest)
	if not ok and reason == "NoChange" then return true, reason end
	return ok, reason
end

-- Ball theme Star purchase (hatching v11). Same pattern as buyFaceplate: the client's
-- operation id is the idempotency key and the digest binds it to theme + price, so
-- a reused id for another theme or price is OperationConflict, never a false Saved.
function Hatching.buyBallTheme(handle, operationId, themeId, price, equip)
	if type(operationId) ~= "string" or #operationId < 1 or #operationId > 80 or type(themeId) ~= "string" or #themeId > 32
		or type(price) ~= "number" then return false, "InvalidBallTheme" end
	if handle.status ~= "Ready" and handle.status ~= "Retrying" then return false, handle.status end
	local signature = "balltheme:" .. operationId
	local resuming = handle.pending and handle.pending.signature == signature
	if BallThemes.owns(handle.state, themeId) and not resuming then return true, "AlreadyOwned" end
	local candidate = resuming and handle.pending.candidate
		or table.freeze({ themeId = themeId, price = price, operationId = operationId, equip = equip == true })
	if candidate.themeId ~= themeId or candidate.price ~= price then return false, "OperationConflict" end
	local digest = "ball:" .. candidate.themeId .. ":" .. tostring(candidate.price)
	local ok, reason = transact(handle, signature, handle.state.revision, BallThemes.applyBuy, candidate, signature, nil, digest)
	if not ok and reason == "AlreadyOwned" then return true, reason end
	return ok, reason
end

-- Equip an owned (or free) ball theme. An unchanged choice is a success with no write.
function Hatching.equipBallTheme(handle, operationId, themeId)
	if type(operationId) ~= "string" or #operationId < 1 or #operationId > 80 or type(themeId) ~= "string" or #themeId > 32 then return false, "InvalidBallTheme" end
	if handle.status ~= "Ready" and handle.status ~= "Retrying" then return false, handle.status end
	local signature = "balluse:" .. operationId
	local resuming = handle.pending and handle.pending.signature == signature
	if not resuming and BallThemes.equipped(handle.state) == themeId then return true, "NoChange" end
	local candidate = resuming and handle.pending.candidate or table.freeze({ themeId = themeId, operationId = operationId })
	if candidate.themeId ~= themeId then return false, "OperationConflict" end
	local ok, reason = transact(handle, signature, handle.state.revision, BallThemes.applyEquip, candidate, signature, nil, "balluse:" .. candidate.themeId)
	if not ok and reason == "NoChange" then return true, reason end
	return ok, reason
end

-- Collection book (play-forever F1; BUILD-PLAN architect changes 1 and 3). The page
-- percent is recomputed inside the transaction from the UpdateAsync snapshot (current
-- catalogue ids only, capped 100); `book.claimed` is the double-pay guard; the
-- book-only faceplate is granted here (never through Faceplates.apply, which charges
-- and refuses unpriced plates) and re-checked on every claim so a missed grant repairs.
local function bookFaceplateOwed(state)
	local book = state.book
	return type(book) == "table" and BookCatalog.faceplateEarned(book.claimed)
		and not Faceplates.owns(state, BookCatalog.BookOnlyFaceplate)
end
local function grantBookFaceplate(state)
	if not bookFaceplateOwed(state) or #(state.faceplates or {}) >= Faceplates.Limit then return false end
	local owned = table.clone(state.faceplates or {})
	table.insert(owned, BookCatalog.BookOnlyFaceplate)
	state.faceplates = owned
	return true
end
-- candidate = { milestoneId, reward, operationId }
local function applyBookClaim(state, candidate)
	local milestone = BookCatalog.milestone(candidate.milestoneId)
	if not milestone then return false, "InvalidMilestone" end
	if milestone.reward ~= candidate.reward then return false, "RewardChanged" end
	local book = state.book
	if type(book) ~= "table" or type(book.claimed) ~= "table" then return false, "InvalidData" end
	if table.find(book.claimed, milestone.id) then
		-- A repeat never pays; it only repairs a missed book-only faceplate.
		if grantBookFaceplate(state) then return true end
		return false, "AlreadyClaimed"
	end
	if BookCatalog.pagePercent(state, milestone.page) < milestone.percent then return false, "NotReached" end
	if state.nectar + milestone.reward > 1000000000 then return false, "BalanceLimit" end
	if not Lifetime.claim(state, milestone.id) then return false, "BookFull" end
	state.nectar += milestone.reward
	grantBookFaceplate(state)
	return true
end
-- The client's operation id is the idempotency key; the digest binds it to milestone +
-- reward, so a reused id for another milestone is OperationConflict, never a false Saved.
function Hatching.bookClaim(handle, operationId, milestoneId, reward)
	if type(operationId) ~= "string" or #operationId < 1 or #operationId > 80
		or type(milestoneId) ~= "string" or #milestoneId > 40 then return false, "InvalidMilestone" end
	local milestone = BookCatalog.milestone(milestoneId)
	if not milestone then return false, "InvalidMilestone" end
	if reward ~= nil and reward ~= milestone.reward then return false, "RewardChanged" end
	if handle.status ~= "Ready" and handle.status ~= "Retrying" then return false, handle.status end
	local signature = "book:" .. milestone.id
	local resuming = handle.pending and handle.pending.signature == signature
	if not resuming and table.find(handle.state.book.claimed, milestone.id) and not bookFaceplateOwed(handle.state) then
		return true, "AlreadyClaimed"
	end
	local candidate = if resuming then handle.pending.candidate
		else table.freeze({ milestoneId = milestone.id, reward = milestone.reward, operationId = operationId })
	local digest = "book:" .. candidate.milestoneId .. ":" .. tostring(candidate.reward)
	local ok, why = transact(handle, signature, handle.state.revision, applyBookClaim, candidate, "bookop:" .. operationId, nil, digest)
	if not ok and why == "AlreadyClaimed" then return true, why end
	return ok, why
end
Hatching.bookFaceplateOwed = bookFaceplateOwed

-- boost = { multiplier = 1|2, bonus = 0|1 } from the player's game passes.
function Hatching.award(handle, runSequence, amount, summary, boost)
	if not integer(runSequence) or runSequence < 1 or (amount ~= 0 and amount ~= 6 and amount ~= 8) then
		return false, "InvalidReward"
	end
	boost = if type(boost) == "table" then boost else {}
	local multiplier = if boost.multiplier == 2 then 2 else 1
	local bonus = if boost.bonus == 1 then 1 else 0
	if runSequence <= handle.state.lastAwardSeq then return true, "AlreadyAwarded" end
	if summary ~= nil then
		if type(summary) ~= "table" or type(summary.family) ~= "string"
			or not Mastery.ownsFamily(handle.state.inventoryMask, summary.family)
			or type(summary.day) ~= "string" or not tonumber(summary.day)
			or tonumber(summary.day) ~= math.floor(tonumber(summary.day))
			or math.abs(tonumber(summary.day)) > 1000000000
			or type(summary.success) ~= "boolean" or type(summary.clean) ~= "boolean"
			or not integer(summary.score) or not integer(summary.chain, 10000)
			or not integer(summary.clears, 10000) or not integer(summary.drops, 24)
			or (summary.success and summary.drops ~= 24)
			or (summary.clean and not summary.success)
			or (summary.heat ~= nil and not BoardConfig.validHeat(summary.heat))
			or (summary.maxTier ~= nil and not integer(summary.maxTier, 5))
			or (summary.goalsMet ~= nil and not integer(summary.goalsMet, 3))
			or (summary.templateId ~= nil and (type(summary.templateId) ~= "string" or #summary.templateId > 40))
			-- Lifetime counters (play-forever F1): bounded integers; a NaN or a huge
			-- value is refused here rather than failing valid() inside every award.
			or (summary.merges ~= nil and not integer(summary.merges, Lifetime.RunMerges))
			or (summary.itemsUsed ~= nil and not integer(summary.itemsUsed, Lifetime.RunItems))
			or amount ~= (if summary.success then (if summary.clean then 8 else 6) else 0) then
			return false, "InvalidSummary"
		end
	end
	-- The run's heat is set by the server at its first drop; no summary is Medium.
	local heat = if summary and summary.heat then summary.heat else BoardConfig.DefaultHeat
	-- Copy once: the host's mutable board and day clock must never alter a
	-- pending transaction when DataStore invokes its callback again later.
	local candidate = { summary = clone(summary), day = dayOf(handle.adapter.now()), multiplier = multiplier, bonus = bonus, userId = handle.userId }
	local signature = "award:" .. runSequence .. ":" .. amount .. ":" .. heat
	return transact(handle, signature, handle.state.revision, function(state, captured)
		if runSequence <= state.lastAwardSeq then return false, "AwardChanged" end
		local run = captured.summary
		local marks, promoted = 0, 0
		if run then
			if not Mastery.ownsFamily(state.inventoryMask, run.family) then return false, "FamilyChanged" end
			if run.success then
				-- Saved wins still unlock independent cosmetics; family facts are archived.
				state.totalWins += 1
			end
			Lifetime.recordRun(state, run, heat)
		end
		-- Quests: roll the calendar (auto-credit) and count this run, atomically
		-- with the payout. Quest Stars are claimed by hand, never added here.
		local quests, credited, moved = QuestState.onRun(state.quests, run, captured.day, captured.userId, captured.multiplier or 1)
		state.quests = quests
		-- Heat multiplier on the round amount (base and tidy), before the pass. A missed
		-- round with a goal met adds the flat finish pay (onboarding v1, no heat multiplier).
		local missPay = if run then HeatPayout.missStars(run.success, run.goalsMet) else 0
		local roundStars = HeatPayout.roundStars(amount, heat) + missPay
		local total = roundStars * (captured.multiplier or 1) + (if run then captured.bonus or 0 else 0)
		if state.nectar + total + credited > 1000000000 then return false, "BalanceLimit" end
		state.nectar += total + credited
		state.lastAwardSeq = runSequence
		state.lastRunReward = { sequence = runSequence, base = amount, heat = heat, roundStars = roundStars, total = total, bonus = total - roundStars, missPay = missPay,
			questAuto = credited, quests = moved, masteryPoints = marks, family = if run then run.family else nil, promotedTo = promoted }
		return true
	end, candidate)
end

-- Quest claim (plan section 5): signature quest:<scope>:<period>:<slot>. A repeat
-- returns true, "AlreadyClaimed"; an ambiguous write resumes the same pending
-- operation, so a claim pays exactly once. boost.multiplier doubles it (2x pass).
function Hatching.questClaim(handle, scope, slot, period, boost)
	if (scope ~= "daily" and scope ~= "weekly") or not integer(slot, 3) or type(period) ~= "string" or #period > 12 then return false, "InvalidQuest" end
	if handle.status ~= "Ready" and handle.status ~= "Retrying" then return false, handle.status end
	local signature = "quest:" .. scope .. ":" .. period .. ":" .. slot
	local candidate = if handle.pending and handle.pending.signature == signature then handle.pending.candidate
		else table.freeze({ scope = scope, slot = slot, period = period, day = dayOf(handle.adapter.now()), userId = handle.userId,
			multiplier = if type(boost) == "table" and boost.multiplier == 2 then 2 else 1 })
	local ok, reason = transact(handle, signature, handle.state.revision, QuestState.claim, candidate)
	if not ok and reason == "AlreadyClaimed" then return true, reason end
	return ok, reason
end

-- Pet Park Play date (K1): `count` finished park activities in one write. Adds stats.parkGames,
-- moves today's playDate count (capped at 3) and pays +4 Stars once when it reaches 3. The
-- signature is keyed by day (park:<day>); the caller's operation id is the idempotency key and
-- playDate.op the proof the host reads to subtract exactly what committed.
function Hatching.parkPlay(handle, operationId, count)
	if type(operationId) ~= "string" or #operationId < 1 or #operationId > 100 or not integer(count, PlayDate.MaxBatch) or count < 1 then return false, "InvalidParkPlay" end
	if handle.status ~= "Ready" and handle.status ~= "Retrying" then return false, handle.status end
	if PlayDate.committed(handle.state, operationId) then return true, "AlreadySaved" end
	local day = dayOf(handle.adapter.now())
	local signature = "park:" .. day
	local pending = handle.pending
	if pending and (pending.signature ~= signature or pending.id ~= operationId) then return false, "Pending" end
	local candidate = if pending then pending.candidate else table.freeze({ id = operationId, day = day, count = count })
	return transact(handle, signature, handle.state.revision, function(state, captured)
		return PlayDate.apply(state, captured, dayOf(handle.adapter.now()))
	end, candidate, operationId, nil, "park:" .. candidate.day .. ":" .. candidate.count)
end
function Hatching.parkCommitted(handle, operationId) return PlayDate.committed(handle.state, operationId) end
function Hatching.playDateDone(handle) return PlayDate.done(handle.state, dayOf(handle.adapter.now())) end

-- The free daily reroll: signature reroll:<day>:<slot>; saved as `rerolled`.
function Hatching.questReroll(handle, slot, day, boost)
	if not integer(slot, 3) or slot < 1 or type(day) ~= "string" or #day > 12 then return false, "InvalidQuest" end
	if handle.status ~= "Ready" and handle.status ~= "Retrying" then return false, handle.status end
	local signature = "reroll:" .. day .. ":" .. slot
	local candidate = if handle.pending and handle.pending.signature == signature then handle.pending.candidate
		else table.freeze({ slot = slot, period = day, day = dayOf(handle.adapter.now()), userId = handle.userId,
			multiplier = if type(boost) == "table" and boost.multiplier == 2 then 2 else 1 })
	return transact(handle, signature, handle.state.revision, QuestState.reroll, candidate)
end

local function maintain(handle, releasing)
	if handle.busy then return false, "Busy" end
	if handle.status ~= "Ready" and handle.status ~= "Retrying" then return false, handle.status end
	handle.busy = true
	local reason = "SessionLost"
	local ok, record = pcall(handle.adapter.update, handle.key, function(previous)
		if type(previous) ~= "table" or not fenced(handle, previous.hatching, handle.adapter.now()) then return nil end
		local root = clone(previous)
		root.hatching.lease.expiresAt = if releasing then 0 else handle.adapter.now() + Hatching.LeaseSeconds
		return root
	end)
	handle.busy = false
	if ok and record and record.hatching and record.hatching.lease.token == handle.token then
		accept(handle, record)
		if handle.pending and committed(handle.pending,handle.state)then
			handle.pending = nil
		end
		handle.status = if releasing then "Released" elseif handle.pending then "Retrying" else "Ready"
		return true, handle.status
	end
	if not ok then reason = "Retrying"; warn("Egg Drop hatching lease write failed:", record) end
	handle.status = reason
	return false, reason
end

function Hatching.renew(handle) return maintain(handle, false) end
function Hatching.release(handle) return maintain(handle, true) end

return Hatching
