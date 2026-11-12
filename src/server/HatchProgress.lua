local HttpService = game:GetService("HttpService")
local ReplicatedStorage = game:GetService("ReplicatedStorage")
local Catalog = require(ReplicatedStorage.Shared.EggCatalog)
local Pets = require(ReplicatedStorage.Shared.PetCatalog)
local Mastery = require(ReplicatedStorage.Shared.FamilyMastery)
local Daily = require(ReplicatedStorage.Shared.DailyContracts)
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
local BoardConfig=require(ReplicatedStorage.Shared.BoardConfig)
local HeatPayout=require(ReplicatedStorage.Shared.HeatPayout)

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
		contracts = Daily.empty(dayOf(now)),
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
		or type(state.contracts) ~= "table" or type(state.contracts.progress) ~= "table"
		or type(state.contracts.day) ~= "string" or not integer(state.contracts.claimedMask, 7)
		or type(state.lease) ~= "table"
		or type(state.lease.token) ~= "string" or type(state.lease.expiresAt) ~= "number" then
		return false
	end
	local claimDay = tonumber(state.dailyClaimDay)
	if state.lease.expiresAt~=state.lease.expiresAt or math.abs(state.lease.expiresAt)==math.huge then return false end
	if state.lastOperation~=nil and(type(state.lastOperation)~="table"or type(state.lastOperation.id)~="string"
		or not integer(state.lastOperation.sequence)or state.lastOperation.sequence<1 or state.lastOperation.sequence~=state.operationSeq)then return false end
	if not claimDay or claimDay ~= math.floor(claimDay) or math.abs(claimDay) > 1000000000 then return false end
	for _, family in ipairs(Catalog.Families) do
		if not integer(state.mastery[family], Mastery.MaxPoints)
			or not integer(state.masteryChallenges[family], 7) then return false end
	end
	local contractDay = tonumber(state.contracts.day)
	if not contractDay or contractDay ~= math.floor(contractDay) or math.abs(contractDay) > 1000000000 then return false end
	for _, item in ipairs(Daily.Definitions) do
		if not integer(state.contracts.progress[item.id], item.target) then return false end
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
local function valid(state)return validVersion(state,8,false)and MaterialState.valid(state)and ToyState.valid(state)and FeatureState.valid(state)and Guard.valid(state)and Purchases.valid(state)and Faceplates.valid(state)end

-- Upgrade only inside the lease-acquisition UpdateAsync callback. Legacy
-- duplicate marks and already-earned sparkle finishes survive without new credits.
local function upgrade(state, now)
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
		nextState.totalWins,nextState.contracts=0,Daily.empty(dayOf(now))
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
		key = "player_" .. userId, adapter = adapter, token = adapter.guid(),
		status = "Loading", busy = false, nextRunSeq = 1,
	}
	if profile and profile.loadFailed then
		handle.state = migrate(legacyRecord(profile), adapter.now())
		handle.state.nectar = 0
		handle.status = "Temporary"
		return handle
	end
	local reason = "Unavailable"
	local function acquire(previous)
		local root = if type(previous) == "table" then clone(previous) else legacyRecord(profile)
		local state = root.hatching
		if state == nil then state = migrate(root, adapter.now()) else state = upgrade(state, adapter.now()) end
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
		handle.state = migrate(legacyRecord(profile), adapter.now())
		handle.state.nectar = 0
		handle.status = if ok then reason else "Unavailable"
		if not ok then warn("Egg Drop hatching load failed:", record) end
	end
	return handle
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
		contracts = Daily.public(state.contracts, dayOf(handle.adapter.now())), lastRunReward = clone(state.lastRunReward),
		misses = state.misses, inventoryMask = state.inventoryMask, mastery = clone(state.mastery),
		lastHatch = clone(state.lastHatch),
		hues=clone(state.hues or {}),lastHueResult=HueState.publicReceipt(state.lastHueResult),
        heldHueEgg=clone(state.heldHueEgg),hueLastPurchase=HueState.publicReceipt(state.hueLastPurchase),
		petDay = state.petDay, petCount = state.petCount, lastPetAward = clone(state.lastPetAward),
		dailyDay = dayOf(handle.adapter.now()), dailyBonus = Catalog.DailyBonus,
		dailyAvailable = handle.status == "Ready" and tonumber(state.dailyClaimDay) < tonumber(dayOf(handle.adapter.now())),
	}
	for key,value in pairs(HueState.public(state))do public[key]=value end
	for key,value in pairs(MaterialState.public(state))do public[key]=value end
	for key,value in pairs(ToyState.public(state))do public[key]=value end
	for key,value in pairs(FeatureState.public(state))do public[key]=value end
	for key,value in pairs(Purchases.public(state))do public[key]=value end
	for key,value in pairs(Faceplates.public(state))do public[key]=value end
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
	return state.lastOperation and state.lastOperation.id==pending.id
end
local function transact(handle, signature, expectedRevision, apply, candidate, operationId, kind)
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
			sequence = handle.state.operationSeq + 1, apply = apply, candidate = candidate,
		}
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
		if state.revision ~= pending.revision or state.operationSeq + 1 ~= pending.sequence then
			 reason = "RevisionChanged"; return if pending.kind=="pet"or pending.kind=="hue"or pending.kind=="material"or pending.kind=="toy"or pending.kind=="feature"then root else nil
		end
		local allowed, failure = pending.apply(state, pending.candidate)
		if not allowed then reason = failure; return if pending.kind=="pet"or pending.kind=="hue"or pending.kind=="material"or pending.kind=="toy"or pending.kind=="feature"then root else nil end
		state.revision += 1
		state.operationSeq = pending.sequence
		state.lastOperation = { id = pending.id, sequence = pending.sequence }
		state.lease.expiresAt = handle.adapter.now() + Hatching.LeaseSeconds
		if not valid(state)then reason="InvalidData";return previous end
		return root
	end)
	handle.busy = false
	if ok and record and record.hatching and committed(pending,record.hatching)then
		accept(handle, record)
		handle.pending = nil
		handle.status = "Ready"
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
			candidate.itemId=require(ReplicatedStorage.Shared.HueCatalog).roll(handle.adapter.random());if not candidate.itemId then return false,"InvalidRoll"end
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
   candidate.finishId=MaterialCatalog.roll(quote.eligible,handle.adapter.random());if not candidate.finishId then return false,"InvalidRoll"end
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
   local awarded=if kind=="toy"then catalog.roll(quote.eligible,handle.adapter.random())else catalog.roll(handle.adapter.random())
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
		candidate = { id = handle.adapter.guid(), unit = handle.adapter.random() }
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
			if state.nectar + Catalog.DailyBonus > 1000000000 then return false, "BalanceLimit" end
			state.nectar += Catalog.DailyBonus
			state.dailyClaimDay = day
			return true
		elseif action == "hatch" then
			local recipe = Catalog.ById[value]
			if not recipe then return false, "UnknownEgg" end
			if recipe.retired then return false,"RetiredEgg"end
			if state.lastHatch or Guard.other(state,"companion") then return false, "RevealPending" end
			if not Catalog.isOwned(state.inventoryMask, "pip") then return false, "MeetPipFirst" end
			if state.nectar < recipe.cost then return false, "NeedNectar" end
			local petId = Catalog.roll(value, state.misses, choice.unit)
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
		state.inventoryMask = bit32.bor(state.inventoryMask, Catalog.bit("pip"))
		state.lastHatch = { id = candidate.id, petId = "pip", duplicate = false,
			family = "pip", mastery = state.mastery.pip, rare = false, starter = true }
		return true
	end, { id = handle.adapter.guid() })
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
	local ok, reason = transact(handle, signature, handle.state.revision, Faceplates.apply, candidate, signature)
	if not ok and reason == "AlreadyOwned" then return true, reason end
	return ok, reason
end

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
			or amount ~= (if summary.success then (if summary.clean then 8 else 6) else 0) then
			return false, "InvalidSummary"
		end
	end
	-- The run's heat is set by the server at its first drop; no summary is Medium.
	local heat = if summary and summary.heat then summary.heat else BoardConfig.DefaultHeat
	-- Copy once: the host's mutable board and day clock must never alter a
	-- pending transaction when DataStore invokes its callback again later.
	local candidate = { summary = clone(summary), day = dayOf(handle.adapter.now()), multiplier = multiplier, bonus = bonus }
	local signature = "award:" .. runSequence .. ":" .. amount .. ":" .. heat
	return transact(handle, signature, handle.state.revision, function(state, captured)
		if runSequence <= state.lastAwardSeq then return false, "AwardChanged" end
		local run = captured.summary
		local extra, completed, marks, promoted = 0, {}, 0, 0
		if run then
			if not Mastery.ownsFamily(state.inventoryMask, run.family) then return false, "FamilyChanged" end
			if run.success then
				-- Saved wins still unlock independent cosmetics; family facts are archived.
				state.totalWins += 1
			end
			state.contracts, extra, completed = Daily.apply(state.contracts, run, captured.day)
		end
		-- Heat multiplier on the round amount (base and tidy), before the pass.
		local roundStars = HeatPayout.roundStars(amount, heat)
		local earned = roundStars + extra
		local total = earned * (captured.multiplier or 1) + (if run then captured.bonus or 0 else 0)
		if state.nectar + total > 1000000000 then return false, "BalanceLimit" end
		state.nectar += total
		state.lastAwardSeq = runSequence
		state.lastRunReward = { sequence = runSequence, base = amount, heat = heat, roundStars = roundStars, daily = extra, total = total, bonus = total - earned,
			masteryPoints = marks, family = if run then run.family else nil, promotedTo = promoted, contracts = completed }
		return true
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
