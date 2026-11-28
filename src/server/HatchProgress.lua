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
-- Customization Egg (plan 2026-11-16): optional v11 fields and the lookBuy rules.
local LookState=require(script.Parent.LookState)
local LookEgg=require(ReplicatedStorage.Shared.LookEggCatalog)
local MaterialState=require(script.Parent.MaterialState)
local MaterialCatalog=require(ReplicatedStorage.Shared.MaterialCatalog)

local ToyState=require(script.Parent.ToyState)
local FeatureState=require(script.Parent.FeatureState)
local ToyCatalog=require(ReplicatedStorage.Shared.ToyCatalog)
local FeatureCatalog=require(ReplicatedStorage.Shared.FeatureCatalog)
local Guard=require(script.Parent.HatchGuard)
-- Beta (12) QA T1: the save key (player_<id>, or the owner's fresh-save key on the beta), resolved by Progress.load.
local ProgressKey=require(script.Parent.ProgressKey)
local Purchases=require(script.Parent.PurchaseState)
local Faceplates=require(script.Parent.FaceplateState)
local Wearables=require(script.Parent.WearableState)
local BallThemes=require(script.Parent.BallThemeState)
local Lifetime=require(script.Parent.LifetimeState)
local PlayDate=require(script.Parent.PlayDateState)
local Coach=require(ReplicatedStorage.Shared.CoachMarks)
-- The lessons remembered (TEACH-MORE-BRIEF 3, ARCH-REVIEW-TEACH): optional `teachMask` and `teachParked` beside coachMask.
local TeachMarks=require(ReplicatedStorage.Shared.TeachMarks)
-- Growth cuts (2026-11-25): the Welcome bonus on a new save's first three field rounds (optional `starterRounds`).
local StarterBonus=require(ReplicatedStorage.Shared.StarterBonus)
-- G2 (2026-11-25): the first hello, +2 Stars on a new save's first paid pet (optional `firstHello`).
local FirstHello=require(ReplicatedStorage.Shared.FirstHello)
-- Onboarding v3 section 3 (2026-11-27): the one-time +5 welcome gift on "You're all set!" (optional `welcomeGift`).
local WelcomeGift=require(ReplicatedStorage.Shared.WelcomeGift)
-- The gift chain (ONBOARDING-FUN-PASS section 2, Onboard "gifts"): the optional `gifts` field and its free eggs.
local GiftEggs=require(ReplicatedStorage.Shared.GiftEggs)
-- The daily rack (ROTATION-BRIEF, ARCH-REVIEW-ROTATION): the Outfit Egg (optional `rack` field), the Outfit gift and the
-- Paint Egg's daily splash / no-pity switches. Off (DailyRack.on false): nothing read, written or published.
local DailyRack=require(ReplicatedStorage.Shared.DailyRack)
local RackState=require(script.Parent.RackState)
local BoardConfig=require(ReplicatedStorage.Shared.BoardConfig)
local HeatPayout=require(ReplicatedStorage.Shared.HeatPayout)
local StampCard=require(ReplicatedStorage.Shared.StampCard)
local BookCatalog=require(ReplicatedStorage.Shared.BookCatalog)
local HueCatalog=require(ReplicatedStorage.Shared.HueCatalog)
-- Overnight 2026-11-14 (slices E, C, F): earned pets, the weekly shelf and bond XP.
local EarnedPets=require(ReplicatedStorage.Shared.EarnedPets)
local FeatureFlags=require(ReplicatedStorage.Shared.FeatureFlags)
local Bond=require(script.Parent.BondState)
-- v2 pet stats (S1): optional petStats / statBonus / statsSeed fields, the BondState pattern.
local Stats=require(script.Parent.StatState)
local StatXP=require(game:GetService("ReplicatedStorage").Shared.StatCatalog).XP
local StatCaps=require(game:GetService("ReplicatedStorage").Shared.StatCatalog).Caps
-- v2 Stat Eggs: optional snackPouch / statEgg fields (StatEggState) and petBoosts (StatState).
local StatEggs=require(script.Parent.StatEggState)
local StatEggCatalog=require(ReplicatedStorage.Shared.StatEggCatalog)
-- Levels matter (2026-11-22): medal eggs are derived from the saved XP (MedalEggs); off = not read.
local MedalEggs=require(script.Parent.MedalEggs)
local Levels=require(ReplicatedStorage.Shared.Levels)
-- Garden Dash (2026-11-22): the optional dash field (DashState); off = not read, not written, no snapshot key.
local DashState=require(script.Parent.DashState)
local Dash=require(ReplicatedStorage.Shared.Dash)
-- Garden finds (S9): the optional finds field (FindsState); off = not read, not written, no snapshot key.
local FindsState=require(script.Parent.FindsState)
-- Garden fruit (GARDEN-PLAY-BRIEF-2 section 5): the optional fruit field (FruitState), Heart XP a fruit, a daily cap.
local FruitState=require(script.Parent.FruitState)
local Finds=require(ReplicatedStorage.Shared.Finds)
-- Onboarding v3 slice C: the optional Sleepy Nest field (NestState); off = not read, not written, no snapshot key.
local NestState=require(script.Parent.NestState)
local Onboard=require(ReplicatedStorage.Shared.Onboard)
-- v2 pet names: optional names / petNames fields (NameState); earned pieces granted by catchUp.
local Names=require(script.Parent.NameState)
-- Paint pots (PAINT-SHINE-DRESS-PLAN): the optional paintPots field and the potBuy rules.
local PaintPots=require(script.Parent.PaintPotState)
local PaintPotCatalog=require(ReplicatedStorage.Shared.PaintPotCatalog)
local NameCatalog=require(ReplicatedStorage.Shared.NameCatalog)
-- v2 S2: the pet that earns XP for actions with no pet of their own (quests, the daily stamp,
-- book milestones). The host sets handle.statPetOf; read once per call, so retries are stable.
local function statPet(handle)
	local ok,petId=pcall(function()return handle.statPetOf and handle.statPetOf()end)
	return if ok and type(petId)=="string"and Pets.byId[petId]then petId else nil
end
-- Lane K's WeeklyShelf: a build without it (or with the flag off) has no shelf week, so
-- every purchase pays the catalogue price and no boundary check runs.
local shelfModule=ReplicatedStorage.Shared:FindFirstChild("WeeklyShelf")
local Shelf=if shelfModule then require(shelfModule)else nil
local function shelfWeek(now)
	if Shelf==nil or FeatureFlags.WeeklyShelf~=true then return nil end
	return Shelf.week(now)
end
-- "This week" (ThisWeek): the week a weekly wardrobe pick is sold in, frozen in its purchase (nil for every other item).
local ThisWeek=require(ReplicatedStorage.Shared.ThisWeek)
local function listWeek(itemId, now)
	if not ThisWeek.isWeekly(itemId) then return nil end
	return ThisWeek.week(now)
end

local Hatching = { LeaseSeconds = 90, RenewSeconds = 20 }
-- Petting pays +1 Star up to this many times a day (QA v2 R5.5: 5 -> 10, alongside the faster
-- PetContact window). Saves written with the old cap (0..5) stay valid.
Hatching.PetDailyCap = 10
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
		-- Growth cuts: the live adapter pays the Welcome bonus (with FeatureFlags.StarterBonus). Specs build their
		-- own adapters and keep their exact payouts unless they opt in (scripts/StarterBonus.spec.lua).
		starterBonus = true,
		-- G2: the live adapter pays the first hello (with FeatureFlags.FirstHelloBonus); spec adapters opt in.
		firstHello = true,
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
		or not integer(state.inventoryMask, 255) or not integer(state.misses, 7)
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
	if not validBase(state,version)or not canonicalDay(state.petDay)or not integer(state.petCount,Hatching.PetDailyCap)or not(if legacy then HueState.validLegacy(state)else HueState.valid(state))then return false end
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
-- Bond levels (overnight 2026-11-14, slice F): optional additive `bond` on v11, valid when missing (no version bump).
-- Customization Egg (2026-11-16): optional additive finishInventory, petFinish, charmUnlocks,
-- lookCharmMisses and lookFound on v11 (LookState.valid, run inside HueState.valid).
-- Welcome bonus (growth cuts 2026-11-25): optional additive `starterRounds` on v11, valid when missing (no version bump).
-- First hello (G2 2026-11-25): optional additive `firstHello` on v11, valid when missing (no version bump).
local function valid(state)return validVersion(state,11,false)and PaintPots.valid(state)and BallThemes.valid(state)and Lifetime.valid(state)and PlayDate.valid(state)and Coach.valid(state)and TeachMarks.valid(state)and StarterBonus.valid(state)and FirstHello.valid(state)and WelcomeGift.valid(state)and Bond.valid(state)and Stats.valid(state)and Stats.validBoosts(state)and StatEggs.valid(state)and Names.valid(state)and Wearables.valid(state)and QuestState.valid(state.quests)and MaterialState.valid(state)and ToyState.valid(state)and FeatureState.valid(state)and Guard.valid(state)and Purchases.valid(state)and Faceplates.valid(state)end
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
		if not validBase(nextState,5)or not canonicalDay(nextState.petDay)or not integer(nextState.petCount,Hatching.PetDailyCap)or not HueState.validV5(nextState)
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
		key = if profile and type(profile.key) == "string" then profile.key else ProgressKey.of(userId), userId = userId, adapter = adapter, token = adapter.guid(),
		status = "Loading", busy = false, nextRunSeq = 1, restricted = true,
	}
	if profile and profile.loadFailed then
		handle.state = upgrade(migrate(legacyRecord(profile), adapter.now()), adapter.now(), userId)
		handle.state.nectar = 0
		handle.state.charmUnlocks = {}
		handle.status = "Temporary"
		return handle
	end
	local reason = "Unavailable"
	local function acquire(previous)
		local root = if type(previous) == "table" then clone(previous) else legacyRecord(profile)
		local state = root.hatching
		-- Customization Egg (plan §2.2, R3): this acquire creates the save when it has no hatching
		-- yet. A record with no hatching but signs of play under the old charm rules (a saved charm
		-- choice or a best score) counts as legacy (code review 2026-11-16): those players owned the
		-- three shapes. The public launch starts on a fresh DataStore, so this only reaches testers.
		local priorPlay = type(previous) == "table" and ((type(previous.petAppearance) == "table" and next(previous.petAppearance) ~= nil)
			or (type(previous.bestScore) == "number" and previous.bestScore > 0))
		local fresh = state == nil and not priorPlay
		state = upgrade(if state == nil then migrate(root, adapter.now()) else state, adapter.now(), userId)
		-- Malformed or old-catalogue quests become a fresh draw; never a failed load.
		if type(state) == "table" and type(state.version) == "number" and state.version >= 10 then state.quests = QuestState.sanitize(state.quests, dayOf(adapter.now()), userId) end
		-- A malformed Play date field is dropped, never a failed load.
		if type(state) == "table" and state.playDate ~= nil then state.playDate = PlayDate.sanitize(state.playDate) end
		-- A malformed coach mask is dropped (reads 0), never a failed load.
		if type(state) == "table" and state.coachMask ~= nil then state.coachMask = Coach.sanitize(state.coachMask) end
		-- The lessons remembered (ARCH-REVIEW-TEACH 2): malformed teach fields are dropped, then, with Onboard `teach` on,
		-- the load-time rules OR their bits in (veteran, moved on, the facts already true). In this callback, so no write of
		-- their own; never a failed load (an error drops both fields: at worst a repeat lesson). Off: the save is untouched.
		if type(state) == "table" then
			if state.teachMask ~= nil then state.teachMask = TeachMarks.sanitize(state.teachMask) end
			if state.teachParked ~= nil then state.teachParked = TeachMarks.sanitize(state.teachParked) end
			if TeachMarks.allows() then
				local backfilled, problem = pcall(TeachMarks.backfill, state)
				if not backfilled then warn("Egg Drop: dropped teach marks at load:", problem); state.teachMask = nil; state.teachParked = nil end
			end
		end
		-- A malformed Welcome bonus counter is dropped (then read as a save that has played: no bonus), never a failed load.
		if type(state) == "table" and state.starterRounds ~= nil then state.starterRounds = StarterBonus.sanitize(state.starterRounds) end
		-- G2: a malformed first-hello field is dropped (then read by its rule: a save with a paid pet is done), never a failed load.
		if type(state) == "table" and state.firstHello ~= nil then state.firstHello = FirstHello.sanitize(state.firstHello) end
		-- The welcome gift: a malformed field is dropped (then not owed: it never pays), never a failed load.
		if type(state) == "table" and state.welcomeGift ~= nil then state.welcomeGift = WelcomeGift.sanitize(state.welcomeGift) end
		-- Malformed bond XP is repaired (bad entries dropped), never a failed load.
		if type(state) == "table" and state.bond ~= nil then state.bond = Bond.sanitize(state.bond) end
		-- v2 stats (S1): malformed stat fields are repaired, never a failed load.
		if type(state) == "table" then Stats.sanitize(state) end
		-- v2 Stat Eggs: the pouch, egg counters and receipts are repaired one subfield at a time.
		if type(state) == "table" then StatEggs.sanitize(state) end
		-- Never a failed load (architect review): a field that still does not validate is dropped on its
		-- own, never with petStats beside it. Unreachable while sanitize is complete; logged if hit.
		if type(state) == "table" and not Stats.validBoosts(state) then warn("Egg Drop: dropped petBoosts at load"); state.petBoosts = nil end
		if type(state) == "table" and not StatEggs.valid(state) then warn("Egg Drop: dropped statEgg/snackPouch at load"); state.statEgg = nil; state.snackPouch = nil end
		-- v2 names: repaired one subfield at a time; still invalid drops receipts, petNames, owned in turn.
		-- Code review: guarded like catchUp, so a repair error drops the names fields, never the load.
		if type(state) == "table" then
			local repaired, problem = pcall(function() Names.sanitize(state); Names.dropInvalid(state) end)
			if not repaired then warn("Egg Drop: dropped names at load:", problem); state.names = nil; state.petNames = nil end
		end
		-- Paint pots (architect review item 4): newer or malformed receipts are repaired before validation, never a
		-- failed load; still invalid drops the receipts alone (the jars and Stars live in validated fields).
		if type(state) == "table" then
			local repaired = pcall(PaintPots.sanitize, state)
			if not repaired or not PaintPots.valid(state) then warn("Egg Drop: dropped paintPots at load"); state.paintPots = nil end
		end
		-- "No default charm" (plan §2.2): a save written before this build has no charmUnlocks and
		-- keeps Snowflake, Ring and Pebble (everyone owned them under the old rules); a save this
		-- acquire creates starts with none. Written once here, so every later reader sees one form.
		if type(state) == "table" and state.charmUnlocks == nil then
			state.charmUnlocks = if fresh then {} else Hatching.legacyCharms()
		end
		if not valid(state) then reason = "InvalidData"; return nil end
		-- v2 stats (S1, architect review): credit play from before stats once, after the save is
		-- known valid. Reads only the snapshot, so a retried callback seeds identically.
		Stats.seed(state)
		-- Code review: a seed problem must never lock a player out; drop the stats instead.
		if not Stats.valid(state) then state.petStats = nil end
		-- Levels matter: a malformed medal egg count fails closed (all used). After the seed, which may
		-- itself earn medals. Never a failed load.
		local counted, problem = pcall(MedalEggs.sanitize, state)
		if not counted then warn("Egg Drop: medal egg repair failed:", problem) end
		-- v2 names (architect review): starters and every earned piece the save already qualifies for.
		-- Protected: an error or an invalid result restores the old value, never a failed load.
		Hatching.catchUpNames(state)
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
		handle.state.charmUnlocks = {}
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
		look = LookState.fixedNext(state),
	}
end
local function isRestricted(handle) return handle.restricted ~= false end
-- Every egg shape: what a save written before the Customization Egg build keeps.
function Hatching.legacyCharms()
	local unlocks = {}
	for _, shape in ipairs(LookEgg.EggShapes) do unlocks[shape] = true end
	return unlocks
end
-- Customization Egg sale gate (switch plus verified finish templates). `handle.lookAvailable`
-- is a spec seam only; the host never sets it.
function Hatching.lookAvailable(handle)
	if handle and handle.lookAvailable ~= nil then return handle.lookAvailable == true end
	return LookEgg.available(ReplicatedStorage:FindFirstChild("PetMaterials"), ReplicatedStorage:FindFirstChild("PetMaterialsTwoTone"))
end
local function lookContext(handle)
	return { available = Hatching.lookAvailable(handle), selectionMode = LookEgg.selectionMode(handle.restricted) }
end

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
	-- Garden Dash: today's paid races, ribbons, cups, best time and title. Never the seed.
	if Dash.on() then public.dash = DashState.public(state, dayOf(handle.adapter.now())) end
	-- Garden finds: today's paid finds and the daily limit, only while the switch is on.
	if Finds.on() then public.finds = FindsState.public(state, dayOf(handle.adapter.now())) end
	-- The Sleepy Nest: the egg growing in the nest, only while the switch is on (no key until the first egg lands).
	if Onboard.on("nest") and not NestState.halted then public.nest = NestState.public(state, handle.adapter.now()) end
	-- Onboarding: one-time coach cards already shown (0 when the field is missing).
	public.coachMask = Coach.mask(state.coachMask)
	-- The lessons remembered: latched lessons, tips and `done`. No key while nothing is latched (the client reads that as
	-- 0), so a save that never met the lessons publishes the snapshot it did before.
	public.teachMask = if TeachMarks.mask(state.teachMask) > 0 then TeachMarks.mask(state.teachMask) else nil
	-- Bond XP per pet (slice F): {} when the field is missing. Levels come from BondCatalog.
	public.bond = Bond.public(state).bond
	-- v2 stats (S1): per owned pet XP, levels and total; Bonus XP left today per stat.
	public.petStats = Stats.public(state, dayOf(handle.adapter.now()))
	-- v2 Stat Eggs: pouch, eggs left today, free eggs, the Feast promise and per pet quote keys.
	public.statEgg = StatEggs.public(state, dayOf(handle.adapter.now()), StatEggCatalog.selectionMode(handle.restricted), Levels.on("medals"))
	-- v2 names: owned pieces, per-pet names and the Names Egg card (odds or the fixed next piece).
	public.names = Names.public(state, NameCatalog.selectionMode(handle.restricted))
	-- Weekly shelf (slice C): the week the server prices with (nil while the shelf is off).
	-- The client may also derive it from dailyDay; this is the authoritative copy.
	public.shelfWeek = shelfWeek(handle.adapter.now())
	-- "This week": the week the server sells the weekly pick in (nil while its switch is off).
	public.thisWeek = if ThisWeek.on() then ThisWeek.week(handle.adapter.now()) else nil
	-- QA Q5: Stars from rounds saved today in this session (not saved; no daily cap).
	public.todayEarned = Hatching.roundStarsToday(handle, dayOf(handle.adapter.now()))
	public.restricted = isRestricted(handle)
	public.nextFixed = Hatching.nextFixed(state)
	for key,value in pairs(HueState.public(state))do public[key]=value end
	for key,value in pairs(MaterialState.public(state))do public[key]=value end
	for key,value in pairs(ToyState.public(state))do public[key]=value end
	for key,value in pairs(FeatureState.public(state))do public[key]=value end
	for key,value in pairs(Purchases.public(state))do public[key]=value end
	for key,value in pairs(Faceplates.public(state))do public[key]=value end
	for key,value in pairs(Wearables.public(state))do public[key]=value end
	for key,value in pairs(BallThemes.public(state))do public[key]=value end
	public.materialAvailable=MaterialCatalog.available(ReplicatedStorage:FindFirstChild("PetMaterials"),ReplicatedStorage:FindFirstChild("PetMaterialsTwoTone"))
 public.materialSelectionMode=MaterialCatalog.selectionMode(handle.restricted)
	-- Customization Egg (slice 1, nothing on sale): owned finish jars, finish looks, egg charm
	-- shapes, pity counter, found items, the sale gate and the selection mode.
	for key,value in pairs(LookState.public(state))do public[key]=value end
	public.lookAvailable=Hatching.lookAvailable(handle)
	public.lookSelectionMode=LookEgg.selectionMode(handle.restricted)
	public.catalogVersion=require(ReplicatedStorage.Shared.HueCatalog).CatalogVersion
	-- Paint pots: the last receipt, only once a pot was bought (an untouched snapshot is unchanged).
	for key,value in pairs(PaintPots.public(state))do public[key]=value end
	-- The gift chain (Onboard "gifts"): only while the switch is on (off: no key, the snapshot as before).
	if Onboard.on("gifts") then public.gifts = Hatching.giftsPublic(handle, { nest = Onboard.on("nest") }) end
	-- The daily rack (DailyRack "rack"): today's Outfit Egg per owned pet (off: no key, the snapshot as before).
	if DailyRack.on("rack") then public.rack = Hatching.rackPublic(handle) end
	-- The Paint Egg's daily splash and no pity (their switches; off: no keys). The client shows LookEggCatalog.odds with
	-- `lookDay` and sends it back beside the lookBuy quote; `lookNoPity` hides the "charm in N" line.
	if DailyRack.on("lookdaily") then public.lookDay = DailyRack.today(handle.adapter.now()) end
	if DailyRack.on("looknopity") then public.lookNoPity = true end
	-- The welcome gift's state (Onboard "allset2"), so the client can ask again while the save is still owed.
	if Onboard.on("allset2") then public.welcomeGift = WelcomeGift.sanitize(state.welcomeGift) end
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
	if pending.kind=="pot"then return PaintPots.proof(state,pending.candidate)end
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
			 reason = "RevisionChanged"; return if pending.kind=="pet"or pending.kind=="hue"or pending.kind=="material"or pending.kind=="toy"or pending.kind=="feature"or pending.kind=="pot"then root else nil
		end
		local before = { nectar = state.nectar, inventoryMask = state.inventoryMask }
		local allowed, failure = pending.apply(state, pending.candidate)
		if not allowed then reason = failure; return if pending.kind=="pet"or pending.kind=="hue"or pending.kind=="material"or pending.kind=="toy"or pending.kind=="feature"or pending.kind=="pot"then root else nil end
		-- ARCH-REVIEW-TEACH 1: a lesson whose fact this write made true (a pot used, a snack fed, a ribbon won, the
		-- twelfth round) is latched in the same write, before a later one can make the fact false again.
		if TeachMarks.allows() then
			local latched = pcall(TeachMarks.latch, state)
			if not latched then warn("Egg Drop: teach latch skipped") end
		end
		-- `now` is read here, inside the callback, so the state-derived Discoveries
		-- (BookCatalog.stateBits) see the clock of this attempt.
		Lifetime.record(before, state, pending.signature, handle.adapter.now())
		-- v2 names: a level-up, a book claim or a first pet and its name pieces commit in one write.
		Hatching.catchUpNames(state)
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
	if ok and(pending.kind=="pet"or pending.kind=="hue"or pending.kind=="material"or pending.kind=="toy"or pending.kind=="feature"or pending.kind=="pot")and record and fenced(handle,record.hatching,handle.adapter.now())then
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
	-- Live lookBuy checks (switch, policy, pool) run here, at reserve time only (plan R4).
	local context=if candidate.quote.action=="lookBuy"then lookContext(handle)else nil
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
		local allowed,why=HueState.purchaseEligibility(state,candidate.quote,context);if not allowed then reason=why;return root end
		state.hueReservation=clone(candidate)
		-- Never write a reservation this build could not load again.
		if not valid(state)then reason="InvalidData";return previous end
		return root
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
		-- v1 launch: the Hue Egg is retired (the Customization Egg sells hue jars). A new hueBuy
		-- is closed; a saved hueBuy receipt still replays above (HueState.find) and a reservation
		-- already in flight still settles (the pending branches below), so old saves keep working.
		-- `handle.hueBuyFixture` is spec-only (never set from a request), like `lookAvailable`: the
		-- old-receipt specs make a real hueBuy receipt through it.
		if action=="hueBuy"and handle.hueBuyFixture~=true then return false,"LegacyPurchaseClosed"end
		candidate={quote=clone(quote),operationId=handle.adapter.guid(),sequence=handle.state.operationSeq+1}
		if action=="hueBuy"or action=="lookBuy"then
			if action=="lookBuy"then
				-- Customization Egg: a stale pool version is closed; the switch, policy, price and
				-- bound pool are checked against this handle (NotReady, PolicyChanged, PoolChanged).
				if quote.poolVersion~=LookEgg.PoolVersion then return false,"LegacyPurchaseClosed"end
				-- The daily splash (DailyRack "lookdaily", ARCH-REVIEW-ROTATION 7): the day the client showed rides beside the
				-- quote (`lookDay`) and must be today, else PoolChanged with no charge; the roll uses that day's table. No pity
				-- ("looknopity"): never a guaranteed charm (misses still count, capped at MissesLimit). PoolVersion stays 1.
				local options={}
				if DailyRack.on("lookdaily")then
					local day=DailyRack.dayArg(type(value)=="table"and value.lookDay or nil)
					if day==nil or day~=DailyRack.today(handle.adapter.now())then return false,"PoolChanged"end
					options.day=day
				end
				options.noPity=DailyRack.on("looknopity")
				local allowed,why=HueState.purchaseEligibility(handle.state,quote,lookContext(handle));if not allowed then return false,why end
				candidate.itemId=if quote.selectionMode=="fixed"then quote.fixedItemId else LookEgg.roll(handle.adapter.random(),quote.missingCharms,quote.charmMisses,options)
			else
				local allowed,why=HueState.purchaseEligibility(handle.state);if not allowed then return false,why end
				candidate.itemId=if isRestricted(handle)then HueCatalog.fixedNext(handle.state.hueInventory)else HueCatalog.roll(handle.adapter.random())
			end
			if not candidate.itemId then return false,"InvalidRoll"end
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
  if candidate.quote.poolVersion==4 and candidate.quote.selectionMode~=MaterialCatalog.selectionMode(handle.restricted)then reason="PolicyChanged";return root end
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
   if quote.poolVersion==4 and quote.selectionMode~=MaterialCatalog.selectionMode(handle.restricted)then return false,"PolicyChanged"end
   candidate.finishId=if isRestricted(handle)then MaterialCatalog.fixedNext(quote.eligible,quote.poolVersion)else MaterialCatalog.roll(quote.eligible,handle.adapter.random(),quote.poolVersion);if not candidate.finishId then return false,"InvalidRoll"end
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

-- Paint pots (PAINT-SHINE-DRESS-PLAN): one fixed-price pot, one transact. No roll, so no reservation: the quote id,
-- the digest and the sequence prove it (PaintPotState.proof). A saved receipt replays first; a new operation checks
-- the revision and the live price; the Stars and every refusal are checked again inside UpdateAsync (apply). The
-- switch, the rate limits and Busy are the host's (PaintPotHost), after the receipt lookup.
-- Beta (38), gacha only: no request reaches this now (PaintPotHost refuses every new buy as NotSold). It stays for the
-- beta (38) receipts' proof (`committed`, kind "pot") and for the save-path and cross-version specs.
function Hatching.potCommand(handle,action,value,revision)
	local quote=PaintPots.quote(action,value,revision)
	if not quote then return false,"InvalidPot"end
	if handle.status~="Ready"and handle.status~="Retrying"then return false,handle.status end
	local receipt,same=PaintPots.find(handle.state,quote)
	if receipt then
		if same then return true,"AlreadySaved",PaintPots.publicReceipt(receipt)end
		return false,"OperationConflict"
	end
	if handle.busy then return false,"Busy"end
	local signature="pot:"..quote.id
	local pending=handle.pending
	local candidate
	if pending and pending.signature==signature then
		if pending.digest~=PaintPots.digest(quote)then return false,"OperationConflict"end
		candidate=pending.candidate
	elseif pending then return false,"Pending"
	else
		if revision~=handle.state.revision then return false,"RevisionChanged"end
		if quote.price~=PaintPotCatalog.Price then return false,"PriceChanged"end
		candidate={quote=clone(quote),operationId=handle.adapter.guid(),sequence=handle.state.operationSeq+1,digest=PaintPots.digest(quote)}
	end
	local ok,reason=transact(handle,signature,revision,PaintPots.apply,candidate,if pending then nil else candidate.operationId,"pot",candidate.digest)
	local saved=if ok then PaintPots.find(handle.state,quote)else nil
	return ok,reason,if saved then PaintPots.publicReceipt(saved)else nil
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
   -- Slice D: a new Toy Egg purchase must quote the current pool (a stale client still on an
   -- older pool is refused, like materialBuy). A reservation made before the pool bump
   -- resumes above and settles on the pool it was quoted from.
   if kind=="toy"and quote.poolVersion~=catalog.PoolVersion then return false,"LegacyPurchaseClosed"end
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
	-- G2: the first-hello switch is read once here, after the key check, and frozen with the candidate (a retry
	-- resumes the pending candidate, so it pays the same way).
	local fixed=clone(candidate)
	fixed.hello=FeatureFlags.FirstHelloBonus==true and handle.adapter.firstHello==true
	fixed=table.freeze(fixed)
	return transact(handle,"pet:"..fixed.id,handle.state.revision,function(state,captured)
		local current=dayOf(handle.adapter.now())
		if captured.day~=current then return false,"ExpiredDay"end
		if tonumber(current)<tonumber(state.petDay)then return false,"ClockRollback"end
		if state.lastHatch then return false,"RevealPending"end
		if not Catalog.isOwned(state.inventoryMask,captured.petId)then return false,"PetChanged"end
		local count=if tonumber(current)>tonumber(state.petDay)then 0 else state.petCount
		if count>=Hatching.PetDailyCap then return false,"PetCap"end
		-- G2: the first hello is read from this snapshot BEFORE lastPetAward (its "never petted" marker) is written.
		local hello=if captured.hello and FirstHello.due(state)then FirstHello.Bonus else 0
		if state.nectar+1+hello>1000000000 then hello=0 end -- never refuse the pet itself for the hello
		if state.nectar+1>1000000000 then return false,"BalanceLimit"end
		if hello>0 then FirstHello.apply(state)end
		state.nectar+=1+hello;state.petDay=current;state.petCount=count+1
		state.lastPetAward={id=captured.id,sequence=state.operationSeq+1,day=current,petId=captured.petId,hello=if hello>0 then hello else nil}
		-- Bond (slice F): +1 XP per paid pet, so at most PetDailyCap a day. Never fails.
		Bond.add(state,captured.petId,Bond.XP.pet)
		-- v2 S2: Heart for an accepted petting pulse (already capped by PetDailyCap).
		Stats.grant(state,captured.petId,"heart",StatXP.pet,current)
		return true
	end,fixed,fixed.id,"pet")
end

function Hatching.command(handle, action, value, expectedRevision)
	local dailyPet = if action == "daily" then statPet(handle) else nil
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
			-- v2 S2: Smarts for the stamp, to the pet that is out.
			if dailyPet then Stats.grant(state, dailyPet, "smarts", StatXP.stamp, day) end
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

-- `owed` (Onboard "allset2" on, read by the caller): this brand-new save is owed the welcome gift (`welcomeGift` = 0,
-- in this same write). Saves whose Bear came earlier, or with the switch off, are never owed it.
-- `giftsOwed` (Onboard "gifts" on, read by the caller): this brand-new save is owed the gift chain (`gifts.v`, in this
-- same write; GiftEggs.mark). The same rule: never an older save, never one whose Bear came with the switch off.
function Hatching.grantStarter(handle, owed, giftsOwed)
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
		if candidate.welcome then WelcomeGift.mark(state) end
		if candidate.gifts then GiftEggs.mark(state) end
		return true
	end, { id = handle.adapter.guid(), welcome = owed == true, gifts = giftsOwed == true })
end

-- The welcome gift (ONBOARDING-V3-BRIEF section 3; Spencer 2026-11-27): +WelcomeGift.Bonus Stars once per save, ever,
-- when "You're all set!" is truly done in the save. ctx = {nest (false: the nest is off in this world), mask (coach
-- bits the board holds but has not saved yet)}, frozen into the candidate so a retry pays the same way.
-- Exactly once: the field is the receipt. It is read and set to the Stars paid inside the same UpdateAsync, so a
-- replayed request, a retry after a store error (the pending operation resumes, and committed() proves an ambiguous
-- write), a rejoin or a second server all meet `welcomeGift` > 0 and answer AlreadyGranted with nothing paid.
function Hatching.welcomeGift(handle, ctx)
	ctx = if type(ctx) == "table" then ctx else {}
	if handle.status ~= "Ready" and handle.status ~= "Retrying" then return false, handle.status end
	local signature = "welcomeGift"
	local resuming = handle.pending and handle.pending.signature == signature
	if not resuming and WelcomeGift.paid(handle.state) then return true, "AlreadyGranted" end
	local candidate = if resuming then handle.pending.candidate
		else table.freeze({ nest = ctx.nest ~= false, mask = Coach.mask(ctx.mask), teach = Coach.mask(ctx.teach) })
	local ok, reason = transact(handle, signature, handle.state.revision, function(state, captured)
		-- Code review: never under another open reservation or reveal (the write would not validate, InvalidData, and
		-- operationSeq must not move under a saved toy or look reservation): RevealPending, which the host waits on.
		if Guard.other(state, nil) then return false, "RevealPending" end
		-- beta 44 (ARCH-REVIEW-SIMPLIFY 6): ctx.teach, the board's queued teach latches (the deck tour stands in for a round)
		local due, why = WelcomeGift.due(state, captured.nest, captured.mask, captured.teach)
		if not due then return false, why end
		if state.nectar + WelcomeGift.Bonus > 1000000000 then return false, "BalanceLimit" end
		WelcomeGift.apply(state)
		return true
	end, candidate, nil, nil, "welcome:" .. WelcomeGift.Bonus)
	if not ok and reason == "AlreadyGranted" then return true, reason end
	return ok, reason
end

-- The gift chain's Paint and Toy Eggs (GiftEggs; ONBOARDING-FUN-PASS section 2, Onboard "gifts"). One free crank each,
-- once per save, only when its trigger is true in the save. ctx = {nest (false: the nest is off in this world), mask}.
-- -> ok, reason, record (GiftEggs.publicRecord; for AlreadyGranted, the record already saved, so an unseen reveal can
-- still show). Exactly once: the kind's record is the proof, read and written in the same UpdateAsync as the pot or
-- the toy. The candidate (its op, the roll or the fixed pick, the day) is frozen, so a retry after a store error
-- resumes it and draws the same item; an ambiguous write is proved by lastOperation (id + digest); a replay, a rejoin
-- or a second server meets the record and is AlreadyGranted with nothing written. Nothing is written under another
-- open reservation or reveal (HatchGuard: RevealPending, which the host waits on), so operationSeq never moves
-- under a saved toy or look reservation.
function Hatching.giftEgg(handle, kind, ctx)
	if type(kind) ~= "string" or not GiftEggs.Crankable[kind] then return false, "InvalidGift" end
	ctx = if type(ctx) == "table" then ctx else {}
	if handle.status ~= "Ready" and handle.status ~= "Retrying" then return false, handle.status end
	local signature = "gift:" .. kind
	local resuming = handle.pending and handle.pending.signature == signature
	if not resuming then
		if GiftEggs.granted(handle.state, kind) then
			return true, "AlreadyGranted", GiftEggs.publicRecord(kind, GiftEggs.record(handle.state, kind))
		end
		if handle.pending then return false, "Pending" end
	end
	local candidate
	if resuming then candidate = handle.pending.candidate
	else
		-- The Outfit gift (DailyRack "rack"): only while the rack is on; the order (Outfit first) is frozen with it.
		local rack = DailyRack.on("rack")
		if kind == "outfit" and not rack then return false, "NotReady" end
		local fixed = isRestricted(handle)
		candidate = table.freeze({ kind = kind, op = handle.adapter.guid(), day = dayOf(handle.adapter.now()), nest = ctx.nest ~= false,
			mask = Coach.mask(ctx.mask), fixed = fixed, unit = if fixed then nil else handle.adapter.random(),
			rack = rack, pet = if rack then (ctx.petId or statPet(handle) or "pip") else nil })
	end
	local found -- the record the authoritative snapshot already holds (a stale copy here, another server's grant)
	local ok, reason = transact(handle, signature, handle.state.revision, function(state, c)
		if Guard.other(state, nil) then return false, "RevealPending" end
		local due, why = GiftEggs.due(state, c.kind, dayOf(handle.adapter.now()), { nest = c.nest, mask = c.mask, rack = c.rack, petId = c.pet })
		if not due then
			if why == "AlreadyGranted" then found = GiftEggs.record(state, c.kind) end
			return false, why
		end
		local item = GiftEggs.draw(state, c)
		if not item then return false, if c.kind == "outfit" then "AllOwned" else "InvalidRoll" end
		if c.kind == "outfit" then
			-- The hat goes on the pet that is out, worn in the same write; ownership and the 128 cap are checked again.
			local granted, refusal = Wearables.grant(state, c.pet, item, true)
			if not granted then return false, refusal end
			GiftEggs.with(state, c.kind, { op = c.op, item = item, day = c.day, rev = state.revision + 1, seq = state.operationSeq + 1,
				pet = c.pet, rounds = GiftEggs.facts(state).rounds })
			return true
		end
		if c.kind == "paint" then
			if type(state.hueInventory) ~= "table" then return false, "InvalidData" end
			local before = state.hueInventory[item] or 0
			if not integer(before, HueCatalog.StackLimit) or before >= HueCatalog.StackLimit then return false, "StackLimit" end
			local stock = table.clone(state.hueInventory); stock[item] = before + 1; state.hueInventory = stock
			local bit = LookEgg.bit(item)
			local mask = if integer(state.lookFound, LookEgg.FoundLimit) then state.lookFound else 0
			if bit then state.lookFound = bit32.bor(mask, bit) end
		else
			if type(state.toyUnlocks) ~= "table" then return false, "InvalidData" end
			local unlocks = table.clone(state.toyUnlocks); unlocks[item] = true; state.toyUnlocks = unlocks
		end
		-- With the rack on, the Paint and Toy records keep the rounds they were given at (the next gift counts from them).
		GiftEggs.with(state, c.kind, { op = c.op, item = item, day = c.day, rev = state.revision + 1, seq = state.operationSeq + 1,
			rounds = if c.rack then GiftEggs.facts(state).rounds else nil })
		return true
	end, candidate, candidate.op, nil, "gift:" .. kind .. ":" .. candidate.op)
	if ok then return true, reason, GiftEggs.publicRecord(kind, GiftEggs.record(handle.state, kind)) end
	if reason == "AlreadyGranted" then
		return true, reason, GiftEggs.publicRecord(kind, found or GiftEggs.record(handle.state, kind))
	end
	return false, reason
end
-- The gift's reveal was seen ("Paint {pet}!", "Play!" or Later): `seen` goes true, never back. Idempotent: already seen
-- answers at once with no write; no record (or a broken field) is NoGift. Never under another open reveal.
function Hatching.giftSeen(handle, kind)
	if type(kind) ~= "string" or not GiftEggs.Crankable[kind] then return false, "InvalidGift" end
	if handle.status ~= "Ready" and handle.status ~= "Retrying" then return false, handle.status end
	local signature = "giftSeen:" .. kind
	local resuming = handle.pending and handle.pending.signature == signature
	local r = GiftEggs.record(handle.state, kind)
	if not resuming then
		if not r then return false, "NoGift" end
		if r.seen == true then return true, "AlreadySaved" end
		if handle.pending then return false, "Pending" end
	end
	local candidate = if resuming then handle.pending.candidate else table.freeze({ kind = kind, op = r.op })
	local ok, reason = transact(handle, signature, handle.state.revision, function(state, c)
		if Guard.other(state, nil) then return false, "RevealPending" end
		local saved = GiftEggs.record(state, c.kind)
		if not saved or saved.op ~= c.op then return false, "NoGift" end
		if saved.seen == true then return false, "AlreadySaved" end
		local copy = clone(saved); copy.seen = true
		GiftEggs.with(state, c.kind, copy)
		return true
	end, candidate, nil, nil, "giftSeen:" .. kind .. ":" .. candidate.op)
	if not ok and reason == "AlreadySaved" then return true, reason end
	return ok, reason
end
-- The gift ready now (the first of paint, toy, snack whose trigger holds and that can be delivered), or nil. The
-- Snack also needs the Stat Egg on sale, room in the pouch and a stat left to grow for the pet that is out (never
-- advertise a gift that cannot be given: architect review 5). ctx = {nest, mask, petId}.
function Hatching.giftReady(handle, ctx)
	ctx = if type(ctx) == "table" then ctx else {}
	local state = handle.state
	if type(state) ~= "table" then return nil end
	local today = dayOf(handle.adapter.now())
	local rack = DailyRack.on("rack")
	local outPet = ctx.petId or statPet(handle) or "pip"
	for _, kind in ipairs(GiftEggs.kinds(rack)) do
		local due = GiftEggs.due(state, kind, today, { nest = ctx.nest, mask = ctx.mask, rack = rack, petId = outPet })
		if due and kind == "snack" then
			local petId = ctx.petId or statPet(handle) or "pip"
			due = StatEggCatalog.Enabled == true and #StatEggs.pouch(state) < StatEggCatalog.PouchSize
				and Catalog.isOwned(state.inventoryMask, petId) and #StatEggs.eligible(state, petId) > 0
		end
		if due then return kind end
	end
	return nil
end
-- What the owner's client sees (only while Onboard "gifts" is on): owed, which kinds are granted, the one ready now,
-- an unseen Paint or Toy record (its reveal replays) and the Snack record.
function Hatching.giftsPublic(handle, ctx)
	local state = handle.state
	local view = GiftEggs.read(state)
	local granted = {}
	local rack = DailyRack.on("rack")
	for _, kind in ipairs(GiftEggs.kinds(rack)) do granted[kind] = GiftEggs.granted(state, kind) end
	local unseenKind, unseen = GiftEggs.unseen(state, rack)
	local public = { owed = view.owed, granted = granted, fetch = view.fetch, ready = if view.owed then Hatching.giftReady(handle, ctx) else nil,
		unseen = if unseenKind then GiftEggs.publicRecord(unseenKind, unseen) else nil,
		snack = GiftEggs.publicRecord("snack", GiftEggs.record(state, "snack")) }
	-- The rack on: the Outfit gift's hat for the pet that is out ("A gift: Pom Beanie, 100%"), nil once given or none left.
	if rack and not granted.outfit then
		public.outfit = GiftEggs.outfitItem(state, ctx.petId or statPet(handle) or "pip")
	end
	return public
end

-- The Outfit Egg (DailyRack "rack"; ROTATION-BRIEF 5, ARCH-REVIEW-ROTATION 1-3). Paid (DailyRack.Price Stars) and
-- repeatable, so idempotent by the client's request id: signature `rack:<id>`, the id saved in `rack.ops` with the
-- write. request = {requestId, petId, day, price, mode, poolKey, equip?}: what the player saw. Before the first attempt
-- the day is compared with the server's (DayChanged), the price (PriceChanged), the policy (PolicyChanged: restricted
-- players see `fixed`) and, through the clone check, the pool (PoolChanged): each answers with no charge and the host
-- publishes a fresh snapshot. A retry after a store error resumes the frozen candidate (its day and unit), so it can
-- never roll again or charge twice. Inside UpdateAsync: RackState.apply's rules (Guard.other, a broken field, the op
-- already saved, ownership, the bound pool, RackDone, ClosetFull at 128, Stars). -> ok, reason, record (RackState.publicLast).
-- AlreadySaved (a replay) answers true with the saved record when it was the last one.
function Hatching.rackEgg(handle, egg, request)
	if egg ~= "outfit" or type(request) ~= "table" then return false, "InvalidRack" end
	local op, petId, price, mode, poolKey = request.requestId, request.petId, request.price, request.mode, request.poolKey
	local day = DailyRack.dayArg(request.day)
	if not RackState.opaque(op) or type(petId) ~= "string" or #petId < 1 or #petId > 32 or day == nil
		or type(price) ~= "number" or (mode ~= "random" and mode ~= "fixed") or type(poolKey) ~= "string" or #poolKey > 32 then
		return false, "InvalidRack"
	end
	if handle.status ~= "Ready" and handle.status ~= "Retrying" then return false, handle.status end
	local signature = "rack:" .. op
	local resuming = handle.pending and handle.pending.signature == signature
	local candidate
	if resuming then candidate = handle.pending.candidate
	else
		local saved = RackState.find(handle.state, op)
		if saved then return true, "AlreadySaved", RackState.publicLast(if type(saved) == "table" then saved else nil) end
		if handle.pending then return false, "Pending" end
		if not DailyRack.on("rack") then return false, "NotReady" end
		if day ~= DailyRack.today(handle.adapter.now()) then return false, "DayChanged" end
		if price ~= DailyRack.Price then return false, "PriceChanged" end
		local current = RackState.selectionMode(handle.restricted)
		if mode ~= current then return false, "PolicyChanged" end
		candidate = table.freeze({ op = op, egg = egg, petId = petId, day = day, price = price, mode = mode, poolKey = poolKey,
			equip = request.equip == true, unit = if mode == "random" then handle.adapter.random() else nil })
	end
	local digest = "rack:" .. egg .. ":" .. candidate.petId .. ":" .. candidate.day .. ":" .. candidate.price .. ":" .. candidate.mode .. ":" .. candidate.poolKey
	local ok, reason = transact(handle, signature, handle.state.revision, RackState.apply, candidate, candidate.op, nil, digest)
	if ok then return true, reason, RackState.publicLast(RackState.read(handle.state).last) end
	if reason == "AlreadySaved" then
		local saved = RackState.find(handle.state, candidate.op)
		return true, reason, RackState.publicLast(if type(saved) == "table" then saved else nil)
	end
	return false, reason
end
-- What the owner's client sees (only while DailyRack "rack" is on): RackState.public for every owned pet, `outfit`
-- the pet that is out.
function Hatching.rackPublic(handle)
	local state = handle.state
	if type(state) ~= "table" then return nil end
	local pets = {}
	for _, pet in ipairs(Pets.active) do table.insert(pets, pet.id) end
	return RackState.public(state, DailyRack.today(handle.adapter.now()), isRestricted(handle), statPet(handle) or "pip", pets)
end

-- Earned pets (overnight 2026-11-14, slice E; SYSTEMS-SCOPE 1.3). Grants `petId` once its
-- rule is met (Blip: 7 lifetime stamps). Flag, rule and ownership are re-checked inside
-- UpdateAsync. The ownership bit is the idempotency receipt: a replayed callback, a retried
-- write or a second server all converge, and "already owned" is a success with no write.
-- Deliberately no `lastHatch`: a reveal receipt would block petting, awards and items behind
-- RevealPending until an ack. The client shows the arrival card from coach bit `petArrived`.
function Hatching.grantEarnedPet(handle, petId)
	local rule = if type(petId) == "string" then EarnedPets.Rules[petId] else nil
	if not rule or not Pets.byId[petId] then return false, "UnknownPet" end
	if handle.status ~= "Ready" and handle.status ~= "Retrying" then return false, handle.status end
	local signature = "earnedpet:" .. petId
	local resuming = handle.pending and handle.pending.signature == signature
	if not resuming and Catalog.isOwned(handle.state.inventoryMask, petId) then return true, "AlreadyOwned" end
	local candidate = if resuming then handle.pending.candidate else table.freeze({ petId = petId })
	local ok, reason = transact(handle, signature, handle.state.revision, function(state, captured)
		local need = EarnedPets.Rules[captured.petId]
		if not need or not EarnedPets.enabled(captured.petId) then return false, "Disabled" end
		if Catalog.isOwned(state.inventoryMask, captured.petId) then return false, "AlreadyOwned" end
		if (if integer(state.stamps) then state.stamps else 0) < need.stamps then return false, "NotEarned" end
		state.inventoryMask = bit32.bor(state.inventoryMask, Catalog.bit(captured.petId))
		return true
	end, candidate, nil, nil, signature)
	if not ok and reason == "AlreadyOwned" then return true, reason end
	return ok, reason
end

-- Star adoption of an earned pet (v2 Bunny, V2-PET-AND-SNACKS-SCOPE 1.7): a fixed price from
-- EarnedPets.Rules[petId].stars, never random, never Robux. Shaped like buyFaceplate: the client's
-- operation id is the idempotency key, the digest binds it to the pet and price (a reused id for
-- another pet or price is OperationConflict), and the debit and the ownership bit commit in one
-- UpdateAsync. Owning the pet already (the 7th-stamp grant won the race, or another server) is a
-- success with no charge ("AlreadyOwned"); the apply re-checks the gate, the price and the wallet.
-- A save that has earned the pet (stamps at the rule) is never charged: the adopt becomes the free
-- grant (code review 2026-11-19: the grant loop waits for a quiet window, so a paid adopt could
-- otherwise land first).
local function earnedFree(state, rule)
	return (if integer(state.stamps) then state.stamps else 0) >= rule.stamps
end
local function adoptApply(state, candidate)
	local rule = EarnedPets.Rules[candidate.petId]
	if not rule or type(rule.stars) ~= "number" or not EarnedPets.enabled(candidate.petId) then return false, "Disabled" end
	if Catalog.isOwned(state.inventoryMask, candidate.petId) then return false, "AlreadyOwned" end
	if earnedFree(state, rule) then return false, "EarnedFree" end
	if candidate.price ~= rule.stars then return false, "PriceChanged" end
	if not integer(state.nectar) or state.nectar < candidate.price then return false, "NotEnoughStars" end
	state.nectar -= candidate.price
	state.inventoryMask = bit32.bor(state.inventoryMask, Catalog.bit(candidate.petId))
	return true
end
function Hatching.adoptPet(handle, operationId, petId, price)
	if type(operationId) ~= "string" or #operationId < 1 or #operationId > 80 or type(petId) ~= "string" or #petId > 32
		or EarnedPets.Rules[petId] == nil or not Pets.byId[petId] then return false, "InvalidAdopt" end
	if handle.status ~= "Ready" and handle.status ~= "Retrying" then return false, handle.status end
	local signature = "adopt:" .. operationId
	local resuming = handle.pending and handle.pending.signature == signature
	if not resuming and Catalog.isOwned(handle.state.inventoryMask, petId) then return true, "AlreadyOwned" end
	-- Earned already: hand it over through the free grant ("EarnedFree" on success, no Stars).
	local function free()
		local ok, reason = Hatching.grantEarnedPet(handle, petId)
		if ok then return true, (if reason == "AlreadyOwned" then reason else "EarnedFree") end
		return false, reason
	end
	if not resuming and earnedFree(handle.state, EarnedPets.Rules[petId]) then return free() end
	local candidate = if resuming then handle.pending.candidate else table.freeze({ petId = petId, price = price, operationId = operationId })
	if candidate.petId ~= petId or candidate.price ~= price then return false, "OperationConflict" end
	local digest = "adopt:" .. candidate.petId .. ":" .. tostring(candidate.price)
	local ok, reason = transact(handle, signature, handle.state.revision, adoptApply, candidate, signature, nil, digest)
	if not ok and reason == "AlreadyOwned" then return true, reason end
	if not ok and reason == "EarnedFree" then return free() end
	return ok, reason
end

-- One-time coach cards (onboarding v1): OR `bits` into the optional `coachMask`. Already saved
-- is a success with no write. OR-only, so an ambiguous write retried later is harmless.
-- The lessons remembered (ARCH-REVIEW-TEACH): `teach` (teachMask bits) and `parked` (teachParked bits) ride the same
-- write, so the coach and teach queues cost one revision bump per quiet window. Either may be 0 or nil; all three 0 is
-- refused.
function Hatching.coachMark(handle, bits, teach, parked)
	bits = if bits == nil then 0 else bits
	teach = if teach == nil then 0 else teach
	parked = if parked == nil then 0 else parked
	if not Coach.integer(bits) or not TeachMarks.integer(teach) or not TeachMarks.integer(parked) or bits + teach + parked < 1 then return false, "InvalidCoach" end
	if handle.status ~= "Ready" and handle.status ~= "Retrying" then return false, handle.status end
	if Coach.covers(handle.state.coachMask, bits) and TeachMarks.covers(handle.state.teachMask, teach)
		and TeachMarks.covers(handle.state.teachParked, parked) then return true, "AlreadySaved" end
	local signature = if teach == 0 and parked == 0 then "coach:" .. bits else "coach:" .. bits .. ":" .. teach .. ":" .. parked
	local pending = handle.pending
	if pending and pending.signature ~= signature then return false, "Pending" end
	local candidate = if pending then pending.candidate else table.freeze({ bits = bits, teach = teach, parked = parked })
	return transact(handle, signature, handle.state.revision, function(state, captured)
		if (captured.bits or 0) > 0 then state.coachMask = Coach.merge(state.coachMask, captured.bits) end
		if (captured.teach or 0) > 0 then state.teachMask = TeachMarks.merge(state.teachMask, captured.teach) end
		if (captured.parked or 0) > 0 then state.teachParked = TeachMarks.merge(state.teachParked, captured.parked) end
		return true
	end, candidate, nil, nil, signature)
end

-- Private beta only (Spencer 2026-11-20: "give me stars to buy the bunny"): a one-time Star
-- top-up for the owner's test save. `grantId` goes in the purchase id ledger so it lands once on
-- any server, but it is not a purchase: no starter flag, no purchase count, no lastPurchase.
-- The caller gates it to the beta place and the owner; this refuses any other place too.
Hatching.BetaPlaceId = 107705084891479
function Hatching.betaGrantStars(handle, grantId, stars)
	if game.PlaceId ~= Hatching.BetaPlaceId then return false, "BetaOnly" end
	if type(grantId) ~= "string" or #grantId < 1 or #grantId > 100 then return false, "InvalidGrant" end
	if type(stars) ~= "number" or stars < 1 or stars > 100000 or stars % 1 ~= 0 then return false, "InvalidGrant" end
	if handle.status ~= "Ready" and handle.status ~= "Retrying" then return false, handle.status end
	if Purchases.granted(handle.state, grantId) then return true, "AlreadyGranted" end
	local candidate = table.freeze({ id = grantId, stars = stars })
	return transact(handle, "beta:" .. grantId, handle.state.revision, function(state, c)
		if Purchases.granted(state, c.id) then return false, "AlreadyGranted" end
		if state.nectar + c.stars > 1000000000 then return false, "BalanceLimit" end
		local p = state.purchases or { ids = {}, total = 0 }
		p = { ids = table.clone(p.ids), starter = p.starter, total = p.total }
		table.insert(p.ids, c.id)
		while #p.ids > Purchases.Limit do table.remove(p.ids, 1) end
		state.purchases = p
		state.nectar += c.stars
		return true
	end, candidate)
end

-- Private beta and Studio only (Spencer 2026-11-21: "i have too many stars now to test need more
-- stars?"): the owner's `/stars N` chat command sets the test save's balance to N (0..100000).
-- Never on the live place: this refuses unless the place is the beta or the session is Studio.
-- Not a purchase and not a grant: no ledger entry, no Economy event.
function Hatching.betaSetStars(handle, stars)
	if game.PlaceId ~= Hatching.BetaPlaceId and not game:GetService("RunService"):IsStudio() then return false, "BetaOnly" end
	if type(stars) ~= "number" or stars < 0 or stars > 100000 or stars % 1 ~= 0 then return false, "InvalidStars" end
	if handle.status ~= "Ready" and handle.status ~= "Retrying" then return false, handle.status end
	return transact(handle, "betaSetStars:" .. tostring(stars) .. ":" .. tostring(handle.state.revision), handle.state.revision, function(state, c)
		state.nectar = c.stars
		return true
	end, table.freeze({ stars = stars }))
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

-- Weekly shelf (slice C; SYSTEMS-SCOPE 3.2). A Star purchase freezes the shelf week in its
-- candidate; the price check inside the write uses that week. If the week rolled over
-- between the request and this apply, the write is refused as ShelfChanged with no charge
-- (the client re-reads the snapshot). transact checks committed() before apply, so a write
-- that already landed still proves "Saved" after the boundary.
-- Levels matter: whether gated items are sold is frozen here too, so a purchase already in flight
-- finishes when the runtime switch goes off (a pending operation keeps this closure).
local function shelfApply(handle, apply)
	local gates = Levels.on("gates")
	return function(state, captured)
		if captured.week ~= nil and shelfWeek(handle.adapter.now()) ~= captured.week then return false, "ShelfChanged" end
		-- The same for a "This week" pick: sold in the week it was asked for, by the server's clock, or not at all.
		if captured.listWeek ~= nil and ThisWeek.week(handle.adapter.now()) ~= captured.listWeek then return false, "ShelfChanged" end
		return apply(state, captured, gates)
	end
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
		or table.freeze({ plateId = plateId, price = price, operationId = operationId, week = shelfWeek(handle.adapter.now()) })
	if candidate.plateId ~= plateId or candidate.price ~= price then return false, "OperationConflict" end
	-- The digest binds the id to its plate and price, so a reused id for another plate (or
	-- at another price) is refused as OperationConflict instead of matching lastOperation as "Saved".
	local digest = "plate:" .. candidate.plateId .. ":" .. tostring(candidate.price)
	local ok, reason = transact(handle, signature, handle.state.revision, shelfApply(handle, Faceplates.apply), candidate, signature, nil, digest)
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
		or table.freeze({ petId = petId, itemId = itemId, price = price, operationId = operationId, equip = equip == true,
			week = shelfWeek(handle.adapter.now()), listWeek = listWeek(itemId, handle.adapter.now()),
			-- Closet mode (DailyRack "rack"): frozen when asked, so a retry decides the same way (WearableState.check).
			closet = if DailyRack.on("rack") then true else nil })
	if candidate.petId ~= petId or candidate.itemId ~= itemId or candidate.price ~= price then return false, "OperationConflict" end
	local digest = "buy:" .. candidate.petId .. ":" .. candidate.itemId .. ":" .. tostring(candidate.price)
	local ok, reason = transact(handle, signature, handle.state.revision, shelfApply(handle, Wearables.applyBuy), candidate, signature, nil, digest)
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
		or table.freeze({ themeId = themeId, price = price, operationId = operationId, equip = equip == true,
			week = shelfWeek(handle.adapter.now()) })
	if candidate.themeId ~= themeId or candidate.price ~= price then return false, "OperationConflict" end
	local digest = "ball:" .. candidate.themeId .. ":" .. tostring(candidate.price)
	local ok, reason = transact(handle, signature, handle.state.revision, shelfApply(handle, BallThemes.applyBuy), candidate, signature, nil, digest)
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
-- Slice C (overnight 2026-11-14): more than one book-only plate (Bookworm for any three
-- pages, Stargazer for Discoveries 100%). The list and its rules are BookCatalog's
-- (BookOnlyPlates / platesOwed, Lane K); a catalogue without them is the single Bookworm rule.
local function bookPlateIds()
	local ids = {}
	if type(BookCatalog.BookOnlyPlates) == "table" then
		for _, row in ipairs(BookCatalog.BookOnlyPlates) do
			local id = if type(row) == "table" then row.id else row
			if type(id) == "string" and #id >= 1 and #id <= 64 and not table.find(ids, id) then table.insert(ids, id) end
		end
	end
	if #ids == 0 then table.insert(ids, BookCatalog.BookOnlyFaceplate) end
	return ids
end
-- Book-only plates the save has earned and does not hold, in catalogue order. Only ids in
-- bookPlateIds() can ever be returned, so this path never hands out a priced plate.
local function bookPlatesOwed(state)
	local owed = {}
	local book = state.book
	if type(book) ~= "table" then return owed end
	local wanted = {}
	if type(BookCatalog.platesOwed) == "function" then
		local list = BookCatalog.platesOwed(state)
		for _, id in ipairs(if type(list) == "table" then list else {}) do
			if type(id) == "string" then wanted[id] = true end
		end
	elseif BookCatalog.faceplateEarned(book.claimed) then
		wanted[BookCatalog.BookOnlyFaceplate] = true
	end
	for _, id in ipairs(bookPlateIds()) do
		if wanted[id] and not Faceplates.owns(state, id) then table.insert(owed, id) end
	end
	return owed
end
local function bookFaceplateOwed(state)
	return #bookPlatesOwed(state) > 0
end
-- Grants every owed plate that fits under the faceplate limit. True when one was added.
local function grantBookFaceplate(state)
	local owed = bookPlatesOwed(state)
	if #owed == 0 then return false end
	local owned = table.clone(state.faceplates or {})
	local granted = false
	for _, id in ipairs(owed) do
		if #owned < Faceplates.Limit then table.insert(owned, id); granted = true end
	end
	if granted then state.faceplates = owned end
	return granted
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
		else table.freeze({ milestoneId = milestone.id, reward = milestone.reward, operationId = operationId,
			-- v2 S2 (code review): the pet and day are frozen with the operation, stable on resume.
			statPet = statPet(handle), day = dayOf(handle.adapter.now()) })
	local digest = "book:" .. candidate.milestoneId .. ":" .. tostring(candidate.reward)
	-- v2 S2: Smarts for a book milestone, to the pet that is out.
	local ok, why = transact(handle, signature, handle.state.revision, function(state, c)
		local wasClaimed = table.find(state.book.claimed, c.milestoneId) ~= nil
		local applied, reason = applyBookClaim(state, c)
		if applied and c.statPet and c.day and not wasClaimed then Stats.grant(state, c.statPet, "smarts", StatXP.milestone, c.day) end
		return applied, reason
	end, candidate, "bookop:" .. operationId, nil, digest)
	if not ok and why == "AlreadyClaimed" then return true, why end
	return ok, why
end
Hatching.bookFaceplateOwed = bookFaceplateOwed
Hatching.bookPlatesOwed = bookPlatesOwed
Hatching.bookPlateIds = bookPlateIds
-- Set of the book-only plates a state holds (the host diffs it around a claim).
function Hatching.bookPlatesOwned(state)
	local owned = {}
	for _, id in ipairs(bookPlateIds()) do
		if Faceplates.owns(state, id) then owned[id] = true end
	end
	return owned
end
-- Round-item kind bits for the award summary's `itemKinds` (slice D, win_each_item).
Hatching.itemKindBit = Lifetime.itemKindBit

-- boost = { multiplier = 1|2, bonus = 0|1 } from the player's game passes.
-- petId (slice F, optional): the companion that played the round; it earns bond XP in this
-- same write (+2, or +3 on a win). Also read from boost.petId, so the close-drain path
-- (CloseProgress passes payout.boost) carries it. Frozen in the candidate, never in the
-- signature; an unknown or unowned pet simply earns nothing and the award is unaffected.
function Hatching.award(handle, runSequence, amount, summary, boost, petId)
	if not integer(runSequence) or runSequence < 1 or (amount ~= 0 and amount ~= 6 and amount ~= 8) then
		return false, "InvalidReward"
	end
	boost = if type(boost) == "table" then boost else {}
	if petId == nil then petId = boost.petId end
	petId = if type(petId) == "string" and Pets.byId[petId] then petId else nil
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
			-- Slice D: item kinds used this round, a 4-bit mask (swap, pop, bomb, magnet).
			or (summary.itemKinds ~= nil and not integer(summary.itemKinds, Lifetime.ItemKindsMask))
			or amount ~= (if summary.success then (if summary.clean then 8 else 6) else 0) then
			return false, "InvalidSummary"
		end
	end
	-- The run's heat is set by the server at its first drop; no summary is Medium.
	local heat = if summary and summary.heat then summary.heat else BoardConfig.DefaultHeat
	-- Copy once: the host's mutable board and day clock must never alter a
	-- pending transaction when DataStore invokes its callback again later.
	-- Growth cuts: the Welcome bonus switch is read once here and frozen in the candidate (a retry pays the same way).
	local starter = FeatureFlags.StarterBonus == true and handle.adapter.starterBonus == true
	local candidate = { summary = clone(summary), day = dayOf(handle.adapter.now()), multiplier = multiplier, bonus = bonus, userId = handle.userId, petId = petId, starter = starter }
	local signature = "award:" .. runSequence .. ":" .. amount .. ":" .. heat
	return transact(handle, signature, handle.state.revision, function(state, captured)
		if runSequence <= state.lastAwardSeq then return false, "AwardChanged" end
		local run = captured.summary
		local marks, promoted = 0, 0
		-- Welcome bonus (growth cuts): read from this snapshot before the round is counted, flat (no heat, pass or
		-- Supporter), saved in this same write. StarterBonus.apply writes `starterRounds` only when it pays.
		local starter = 0
		if run then
			if not Mastery.ownsFamily(state.inventoryMask, run.family) then return false, "FamilyChanged" end
			if captured.starter then starter = StarterBonus.apply(state) end
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
		local missPay = if run then HeatPayout.missStars(run.success, run.goalsMet, run) else 0
		local roundStars = HeatPayout.roundStars(amount, heat) + missPay
		local paid = roundStars * (captured.multiplier or 1) + (if run then captured.bonus or 0 else 0)
		-- `total` includes the Welcome bonus; `bonus` keeps its meaning (the pass and Supporter share of the round).
		local total = paid + starter
		if state.nectar + total + credited > 1000000000 then return false, "BalanceLimit" end
		state.nectar += total + credited
		state.lastAwardSeq = runSequence
		state.lastRunReward = { sequence = runSequence, base = amount, heat = heat, roundStars = roundStars, total = total, bonus = paid - roundStars, missPay = missPay, starter = starter,
			questAuto = credited, quests = moved, masteryPoints = marks, family = if run then run.family else nil, promotedTo = promoted }
		-- Bond (slice F): a saved round finished with this companion. Ownership is checked
		-- inside Bond.add against this snapshot; it can never fail the award.
		if run then Bond.add(state, captured.petId, if run.success then Bond.XP.win else Bond.XP.round) end
		-- v2 S2: pet stats from this round (never fails the award). Power from merges, chains and
		-- top tiers (capped per round); Energy from finishing, winning, tidy and goals; Heart +1.
		if run and captured.petId then
			local pid, day, gains = captured.petId, captured.day, {}
			local power = (run.merges or 0) * StatXP.merge + math.max(0, (run.chain or 0) - 1) * StatXP.chainLink
				+ (if run.maxTier == 5 then StatXP.topTier else 0) + (run.clears or 0) * StatXP.topClear
			power = math.min(power, StatCaps.powerPerRound)
			local energy = StatXP.round + (run.goalsMet or 0) * StatXP.goal
			if run.success then
				energy += if heat == "easy" then StatXP.winEasy elseif heat == "hard" then StatXP.winHard else StatXP.winMedium
				if run.clean then energy += StatXP.tidy end
			end
			gains.power = Stats.grant(state, pid, "power", power, day)
			gains.energy = Stats.grant(state, pid, "energy", energy, day)
			gains.heart = Stats.grant(state, pid, "heart", StatXP.roundWithPet, day)
			state.lastRunReward.stats = gains
		end
		-- v2 Stat Eggs: the first finished round each day brings a free Stat Egg (never fails the award).
		if run and StatEggs.grantDaily(state, captured.day) then state.lastRunReward.freeStatEgg = true end
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
	-- v2 S2: Smarts for the claim, to the pet that is out (read once here, stable on retries).
	local pid = statPet(handle)
	local ok, reason = transact(handle, signature, handle.state.revision, function(state, c)
		local claimed, why = QuestState.claim(state, c)
		if claimed and pid then
			local xp = if c.scope == "daily" then StatXP.questDaily else StatXP.questWeekly + (if c.slot == 0 then StatXP.questAllWeekly else 0)
			Stats.grant(state, pid, "smarts", xp, c.day)
		end
		return claimed, why
	end, candidate)
	if not ok and reason == "AlreadyClaimed" then return true, reason end
	return ok, reason
end

-- Pet Park Play date (K1): `count` finished park activities in one write. Adds stats.parkGames,
-- moves today's playDate count (capped at 3) and pays +4 Stars once when it reaches 3. The
-- signature is keyed by day (park:<day>); the caller's operation id is the idempotency key and
-- playDate.op the proof the host reads to subtract exactly what committed.
-- petId (slice F, optional): the companion; it earns bond XP once, in the write whose count
-- completes today's Play date. Not in the digest (playDate.op stays the proof).
-- fetches (v2 S0, optional): how many of `count` are park fetches (0..count), saved to stats.fetches.
function Hatching.parkPlay(handle, operationId, count, petId, fetches)
	if type(operationId) ~= "string" or #operationId < 1 or #operationId > 100 or not integer(count, PlayDate.MaxBatch) or count < 1 then return false, "InvalidParkPlay" end
	if handle.status ~= "Ready" and handle.status ~= "Retrying" then return false, handle.status end
	if PlayDate.committed(handle.state, operationId) then return true, "AlreadySaved" end
	local day = dayOf(handle.adapter.now())
	local signature = "park:" .. day
	local pending = handle.pending
	if pending and (pending.signature ~= signature or pending.id ~= operationId) then return false, "Pending" end
	local candidate = if pending then pending.candidate else table.freeze({ id = operationId, day = day, count = count,
		petId = if type(petId) == "string" and Pets.byId[petId] then petId else nil,
		fetches = if integer(fetches, count) and fetches > 0 then fetches else nil })
	return transact(handle, signature, handle.state.revision, function(state, captured)
		local today = dayOf(handle.adapter.now())
		local doneBefore = PlayDate.done(state, today)
		local ok, why = PlayDate.apply(state, captured, today)
		-- Bond (slice F): only the write that crosses the Play date target pays XP.
		if ok and not doneBefore and PlayDate.done(state, today) then Bond.add(state, captured.petId, Bond.XP.playDate) end
		-- v2 S2: Jump for park activities (and today's Play date), Speed for fetches.
		if ok and captured.petId then
			local fetches = captured.fetches or 0
			Stats.grant(state, captured.petId, "jump", math.max(0, captured.count - fetches) * StatXP.park, captured.day)
			if fetches > 0 then Stats.grant(state, captured.petId, "speed", fetches * StatXP.fetch, captured.day) end
			if not doneBefore and PlayDate.done(state, today) then Stats.grant(state, captured.petId, "jump", StatXP.playDate, captured.day) end
		end
		return ok, why
	end, candidate, operationId, nil, "park:" .. candidate.day .. ":" .. candidate.count .. ":" .. (candidate.fetches or 0))
end
function Hatching.parkCommitted(handle, operationId) return PlayDate.committed(handle.state, operationId) end
function Hatching.parkCompletion(handle, operationId) return PlayDate.completion(handle.state, operationId) end
function Hatching.playDateDone(handle) return PlayDate.done(handle.state, dayOf(handle.adapter.now())) end

-- Garden Dash (DashState): up to 8 finished races and Time Trials in one write. `operationId` is the host's
-- flight id, kept across retries; dash.op is the proof, so a retry, a replay or a second session pays once.
-- The day is read inside the write. No 2x pass and no XP. `results` is copied and frozen here.
function Hatching.dashResults(handle, operationId, results)
	if type(operationId) ~= "string" or #operationId < 1 or #operationId > 80 or not DashState.validResults(results) then return false, "InvalidDash" end
	if handle.status ~= "Ready" and handle.status ~= "Retrying" then return false, handle.status end
	if DashState.committed(handle.state, operationId) then return true, "AlreadySaved" end
	local signature = "dash:" .. operationId
	local pending = handle.pending
	if pending and pending.signature ~= signature then return false, "Pending" end
	local candidate = if pending then pending.candidate else table.freeze({ id = operationId, results = table.freeze(clone(results)) })
	return transact(handle, signature, handle.state.revision, function(state, captured)
		return DashState.apply(state, captured, dayOf(handle.adapter.now()))
	end, candidate, operationId, nil, DashState.digest(candidate.results))
end
function Hatching.dashCommitted(handle, operationId) return DashState.committed(handle.state, operationId) end
function Hatching.dashReceipt(handle, operationId) return DashState.receipt(handle.state, operationId) end

-- Garden finds (FindsState): one find for the pet the host captured when it accepted the claim. `operationId` is the
-- host's id, kept across retries; finds.op is the proof, so a retry, a replay or a second session pays once. A pending
-- write resumes its own frozen candidate. The count's day is read inside the write; the XP day is the candidate's.
-- A refusal (DailyLimit, NoPet) writes nothing.
function Hatching.findClaim(handle, operationId, petId)
	if type(operationId) ~= "string" or #operationId < 1 or #operationId > 80 or type(petId) ~= "string" or #petId < 1 or #petId > 40 then return false, "InvalidFind" end
	if handle.status ~= "Ready" and handle.status ~= "Retrying" then return false, handle.status end
	if FindsState.committed(handle.state, operationId) then return true, "AlreadySaved" end
	local signature = "find:" .. operationId
	local pending = handle.pending
	if pending and pending.signature ~= signature then return false, "Pending" end
	local candidate = if pending then pending.candidate else table.freeze({ id = operationId, petId = petId, n = 1, day = dayOf(handle.adapter.now()) })
	return transact(handle, signature, handle.state.revision, function(state, captured)
		return FindsState.apply(state, captured, dayOf(handle.adapter.now()))
	end, candidate, operationId, nil, "find:" .. candidate.day .. ":" .. candidate.petId)
end
function Hatching.findCommitted(handle, operationId) return FindsState.committed(handle.state, operationId) end
function Hatching.findReceipt(handle, operationId) return FindsState.receipt(handle.state, operationId) end

-- Garden fruit (FruitState): one fruit eaten by the pet the host captured when it accepted the claim, the findClaim way.
-- `operationId` is the host's id, kept across retries; fruit.op is the proof (paid once under retry, replay and a
-- second session). The count's day is read inside the write; the XP day is the candidate's. DailyLimit and NoPet
-- write nothing.
function Hatching.fruitClaim(handle, operationId, petId)
	if type(operationId) ~= "string" or #operationId < 1 or #operationId > 80 or type(petId) ~= "string" or #petId < 1 or #petId > 40 then return false, "InvalidFruit" end
	if handle.status ~= "Ready" and handle.status ~= "Retrying" then return false, handle.status end
	if FruitState.committed(handle.state, operationId) then return true, "AlreadySaved" end
	local signature = "fruit:" .. operationId
	local pending = handle.pending
	if pending and pending.signature ~= signature then return false, "Pending" end
	local candidate = if pending then pending.candidate else table.freeze({ id = operationId, petId = petId, day = dayOf(handle.adapter.now()) })
	return transact(handle, signature, handle.state.revision, function(state, captured)
		return FruitState.apply(state, captured, dayOf(handle.adapter.now()))
	end, candidate, operationId, nil, "fruit:" .. candidate.day .. ":" .. candidate.petId)
end
function Hatching.fruitCommitted(handle, operationId) return FruitState.committed(handle.state, operationId) end
function Hatching.fruitReceipt(handle, operationId) return FruitState.receipt(handle.state, operationId) end
function Hatching.fruitLeft(handle) return FruitState.left(handle.state, dayOf(handle.adapter.now())) end

-- The Sleepy Nest (NestState, Onboarding v3 slice C). Each is one write through transact; `operationId` is the host's id,
-- kept across retries, and a pending write resumes its own frozen candidate. The clock is read inside the write.
-- nestLand: an egg lands for `petId` when there is none (or the saved one is malformed), keeping the count; "Growing"
-- otherwise, writing nothing.
local function nestId(value) return type(value) == "string" and #value >= 1 and #value <= 80 end
local function nestPet(value) return type(value) == "string" and #value >= 1 and #value <= 40 end
function Hatching.nestLand(handle, operationId, petId)
	if not nestId(operationId) or not nestPet(petId) then return false, "InvalidNest" end
	if handle.status ~= "Ready" and handle.status ~= "Retrying" then return false, handle.status end
	local signature = "nestLand:" .. operationId
	local pending = handle.pending
	if pending and pending.signature ~= signature then return false, "Pending" end
	local candidate = if pending then pending.candidate else table.freeze({ id = operationId, petId = petId })
	return transact(handle, signature, handle.state.revision, function(state, captured)
		return NestState.land(state, captured, handle.adapter.now())
	end, candidate, operationId, nil, "nestLand:" .. candidate.petId)
end
-- nestClaim: hatch the egg the host saw. `n` (optional) is the count the host captured when it accepted the claim;
-- without it the count is captured here, once, and frozen with the candidate. nest.op is the proof, so a retry, a
-- replay or a second session pays once; the claim checks n == captured n and ready inside the write.
function Hatching.nestClaim(handle, operationId, petId, n)
	if not nestId(operationId) or not nestPet(petId) then return false, "InvalidNest" end
	if handle.status ~= "Ready" and handle.status ~= "Retrying" then return false, handle.status end
	if NestState.committed(handle.state, operationId) then return true, "AlreadySaved" end
	local signature = "nestClaim:" .. operationId
	local pending = handle.pending
	if pending and pending.signature ~= signature then return false, "Pending" end
	if n ~= nil and not integer(n) then return false, "InvalidNest" end
	local candidate = if pending then pending.candidate
		else table.freeze({ id = operationId, petId = petId, n = if n ~= nil then n else NestState.read(handle.state, handle.adapter.now()).n })
	return transact(handle, signature, handle.state.revision, function(state, captured)
		return NestState.claim(state, captured, handle.adapter.now())
	end, candidate, operationId, nil, "nestClaim:" .. candidate.n .. ":" .. candidate.petId)
end
-- nestTuck: Tuck in for the egg with count `n`; refused (nothing written) when it is gone or tucked already.
function Hatching.nestTuck(handle, operationId, n)
	if not nestId(operationId) or not integer(n) then return false, "InvalidNest" end
	if handle.status ~= "Ready" and handle.status ~= "Retrying" then return false, handle.status end
	local signature = "nestTuck:" .. operationId
	local pending = handle.pending
	if pending and pending.signature ~= signature then return false, "Pending" end
	local candidate = if pending then pending.candidate else table.freeze({ id = operationId, n = n })
	return transact(handle, signature, handle.state.revision, function(state, captured)
		return NestState.tuck(state, captured, handle.adapter.now())
	end, candidate, operationId, nil, "nestTuck:" .. candidate.n)
end
function Hatching.nestCommitted(handle, operationId) return NestState.committed(handle.state, operationId) end
function Hatching.nestReceipt(handle, operationId) return NestState.receipt(handle.state, operationId) end

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

-- v2 Stat Eggs (StatEggState). Both are idempotent by the client's operation id: the pending
-- candidate is resumed on a retry (same frozen roll), a saved receipt with the same digest is
-- "AlreadySaved" with that receipt, and the id reused for anything else is "OperationConflict".
-- No reservation is needed (architect review 2026-11-19): no result reaches the client before the
-- write is proven, and a roll that never committed was never shown or charged.
local function snackOperation(handle, signature, operationId, digest, makeCandidate, apply)
	if handle.status ~= "Ready" and handle.status ~= "Retrying" then return false, handle.status end
	local resuming = handle.pending and handle.pending.signature == signature
	if not resuming then
		local saved = StatEggs.receipt(handle.state, operationId)
		if saved then
			if saved.digest == digest then return true, "AlreadySaved", StatEggs.publicReceipt(saved) end
			return false, "OperationConflict"
		end
	end
	local candidate = if resuming then handle.pending.candidate else makeCandidate()
	if candidate.digest ~= digest then return false, "OperationConflict" end
	local ok, reason = transact(handle, signature, handle.state.revision, apply, candidate, signature, nil, digest)
	local saved = StatEggs.receipt(handle.state, operationId)
	if saved and saved.digest == digest and (ok or reason == "AlreadySaved") then return true, if ok then reason else "AlreadySaved", StatEggs.publicReceipt(saved) end
	return ok, reason
end

-- Buy and hatch one Stat Egg for `petId` (the pet that is out; the host checks that), paid with
-- Stars or, when `free`, one banked free egg (then one medal egg, while medals are on). `quoteKey` is the key the player's card showed
-- (StatEggCatalog.quoteKey): any change to the pool, price, mode, promise or position is
-- "PoolChanged" with no charge. A restricted (or unknown) policy draws no random number.
-- `gift` (the gift chain's Snack Egg, GiftEggs; needs `free`): an explicit request, in the digest, that opens only the
-- gift (StatEggState.buy re-checks GiftEggs.due and never falls back to the bank or a medal egg). Without it the gift is
-- never touched. A replay of the gift's own op answers from `gifts.snack` (the Stat Egg receipt ring keeps 32).
function Hatching.statEggBuy(handle, operationId, petId, free, quoteKey, gift)
	if type(operationId) ~= "string" or #operationId < 1 or #operationId > 80 or type(petId) ~= "string" or #petId > 32
		or not Pets.byId[petId] or type(free) ~= "boolean" or type(quoteKey) ~= "string" or #quoteKey > 64
		or (gift ~= nil and type(gift) ~= "boolean") or (gift == true and not free) then return false, "InvalidStatEgg" end
	gift = gift == true
	local signature = "statEgg:" .. operationId
	local digest = "egg:" .. petId .. ":" .. (if free then "1" else "0") .. ":" .. quoteKey .. (if gift then ":gift" else "")
	if gift and not(handle.pending and handle.pending.signature == signature) then
		local record = GiftEggs.record(handle.state, "snack")
		if record and record.op == operationId and not StatEggs.receipt(handle.state, operationId) then
			return true, "AlreadySaved", Hatching.giftSnackReceipt(record)
		end
	end
	return snackOperation(handle, signature, operationId, digest, function()
		local mode = StatEggCatalog.selectionMode(handle.restricted)
		local random = mode == "random"
		return table.freeze({ op = operationId, digest = digest, petId = petId, free = free, quoteKey = quoteKey, mode = mode,
			day = dayOf(handle.adapter.now()), medals = Levels.on("medals"), gift = gift,
			unitStat = if random then handle.adapter.random() else nil, unitSize = if random then handle.adapter.random() else nil })
	end, function(state, c)
		return StatEggs.buy(state, c, dayOf(handle.adapter.now()))
	end)
end

-- The Snack gift's receipt as the client reads a Stat Egg one, from `gifts.snack` (the replay of its own op once the
-- Stat Egg receipt has left the ring).
function Hatching.giftSnackReceipt(record)
	if type(record) ~= "table" then return nil end
	return { op = record.op, kind = "buy", snackId = record.snackId, stat = record.stat, size = record.size, petId = record.petId,
		free = true, cost = 0, source = "gift", day = record.day }
end

-- Feed one snack from the pouch to `petId`. The host checks the live conditions first (the pet is
-- out, no round, park, care or carry, the feed cooldown); this checks the save (StatEggState.feed).
function Hatching.snackFeed(handle, operationId, snackId, petId)
	if type(operationId) ~= "string" or #operationId < 1 or #operationId > 80 or type(petId) ~= "string" or #petId > 32
		or not Pets.byId[petId] or not integer(snackId, StatEggCatalog.SerialLimit) or snackId < 1 then return false, "InvalidSnack" end
	local signature = "snack:" .. operationId
	local digest = "feed:" .. snackId .. ":" .. petId
	return snackOperation(handle, signature, operationId, digest, function()
		return table.freeze({ op = operationId, digest = digest, snackId = snackId, petId = petId })
	end, StatEggs.feed)
end

-- v2 names. catchUp never fails its caller: an error restores the old value (architect review).
function Hatching.catchUpNames(state)
	if type(state) ~= "table" then return {} end
	local before = state.names
	local ok, added = pcall(Names.catchUp, state)
	if not ok then state.names = before; warn("Egg Drop: name catch-up failed:", added); return {} end
	return added
end

local function nameOperation(handle, signature, operationId, digest, makeCandidate, apply)
	if handle.status ~= "Ready" and handle.status ~= "Retrying" then return false, handle.status end
	local resuming = handle.pending and handle.pending.signature == signature
	if not resuming then
		local saved = Names.receipt(handle.state, operationId)
		if saved then
			if saved.digest == digest then return true, "AlreadySaved", Names.publicReceipt(saved) end
			return false, "OperationConflict"
		end
	end
	local candidate = if resuming then handle.pending.candidate else makeCandidate()
	if candidate.digest ~= digest then return false, "OperationConflict" end
	local ok, reason = transact(handle, signature, handle.state.revision, apply, candidate, signature, nil, digest)
	local saved = Names.receipt(handle.state, operationId)
	if saved and saved.digest == digest and (ok or reason == "AlreadySaved") then return true, if ok then reason else "AlreadySaved", Names.publicReceipt(saved) end
	return ok, reason
end

-- One Names Egg (8 Stars): one new piece, never a duplicate. `quoteKey` is the key the card
-- showed (NameCatalog.quoteKey); any change is "PoolChanged" with no charge. A restricted (or
-- unknown) policy draws no random number: the fixed next piece in NameCatalog.EggOrder.
function Hatching.nameEggBuy(handle, operationId, quoteKey)
	if type(operationId) ~= "string" or #operationId < 1 or #operationId > 80
		or type(quoteKey) ~= "string" or #quoteKey < 1 or #quoteKey > 64 then return false, "InvalidNameEgg" end
	local signature = "nameEgg:" .. operationId
	local digest = "name:" .. quoteKey
	return nameOperation(handle, signature, operationId, digest, function()
		local mode = NameCatalog.selectionMode(handle.restricted)
		return table.freeze({ op = operationId, digest = digest, quoteKey = quoteKey, mode = mode,
			unit = if mode == "random" then handle.adapter.random() else nil })
	end, Names.buy)
end

-- Rename a pet (free): 0..2 owned, distinct piece ids. Same name as saved = "Unchanged", no write.
function Hatching.setPetName(handle, petId, ids)
	if type(petId) ~= "string" or #petId > 32 or not Pets.byId[petId] or type(ids) ~= "table" or #ids > NameCatalog.MaxPieces then return false, "InvalidName" end
	local clean = {}
	for index = 1, #ids do
		local v = ids[index]
		if type(v) ~= "string" or #v < 1 or #v > 40 then return false, "InvalidName" end
		clean[index] = v
	end
	local n = 0; for _ in pairs(ids) do n += 1 end
	if n ~= #ids then return false, "InvalidName" end
	if handle.status ~= "Ready" and handle.status ~= "Retrying" then return false, handle.status end
	if not handle.pending and Names.sameName(handle.state, petId, clean) then return true, "Unchanged" end
	local signature = "petName:" .. petId .. ":" .. table.concat(clean, "+")
	local candidate = if handle.pending and handle.pending.signature == signature then handle.pending.candidate
		else table.freeze({ petId = petId, ids = table.freeze(clean) })
	return transact(handle, signature, handle.state.revision, Names.setName, candidate)
end

-- Studio only (the EggDropStatTestGrant hook): stat XP through a real transaction, so a level-up and
-- its name piece commit the way live play does. Refused outside Studio.
function Hatching.studioGrantStat(handle, petId, statId, xp)
	if not game:GetService("RunService"):IsStudio() then return false, "StudioOnly" end
	local candidate = table.freeze({ petId = petId, stat = statId, xp = xp })
	return transact(handle, "studioStat:" .. handle.adapter.guid(), handle.state.revision, function(state, c)
		return Stats.grant(state, c.petId, c.stat, c.xp, nil, true) > 0, "NoChange"
	end, candidate)
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
