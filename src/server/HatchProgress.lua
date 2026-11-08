local HttpService = game:GetService("HttpService")
local ReplicatedStorage = game:GetService("ReplicatedStorage")
local Catalog = require(ReplicatedStorage.Shared.EggCatalog)
local Pets = require(ReplicatedStorage.Shared.PetCatalog)
local Mastery = require(ReplicatedStorage.Shared.FamilyMastery)
local Daily = require(ReplicatedStorage.Shared.DailyContracts)

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
	return {
		version = 4, migrated = true, welcomeCredited = true,
		nectar = charge + 6, inventoryMask = mask, mastery = mastery, misses = 0,
		masteryChallenges = challenges, masteryLegacyMask = 0, totalWins = 0,
		contracts = Daily.empty(dayOf(now)),
		revision = 0, epoch = 0, operationSeq = 0, lastAwardSeq = 0,
		dailyClaimDay = dayOf(now),
		petDay = dayOf(now), petCount = 0,
		lease = { token = "", expiresAt = 0 },
	}
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
local function valid(state)
	if not validBase(state,4)or not canonicalDay(state.petDay)or not integer(state.petCount,5)then return false end
	local receipt=state.lastPetAward
	if state.petCount==0 then return receipt==nil end
	return type(receipt)=="table"and type(receipt.id)=="string"and #receipt.id>0 and #receipt.id<=100
		and integer(receipt.sequence)and receipt.sequence>=state.petCount and receipt.sequence<=state.operationSeq
		and receipt.day==state.petDay and Pets.byId[receipt.petId]~=nil
		and (receipt.sequence~=state.operationSeq or (state.lastOperation and state.lastOperation.id==receipt.id))
end

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
	return {
		status = handle.status, revision = state.revision, nectar = state.nectar,
		masteryRanks = ranks, masteryDetails = details, masteryChallenges = clone(state.masteryChallenges),
		masteryLegacyMask = state.masteryLegacyMask, totalWins = state.totalWins,
		contracts = Daily.public(state.contracts, dayOf(handle.adapter.now())), lastRunReward = clone(state.lastRunReward),
		misses = state.misses, inventoryMask = state.inventoryMask, mastery = clone(state.mastery),
		lastHatch = clone(state.lastHatch),
		petDay = state.petDay, petCount = state.petCount, lastPetAward = clone(state.lastPetAward),
		dailyDay = dayOf(handle.adapter.now()), dailyBonus = Catalog.DailyBonus,
		dailyAvailable = handle.status == "Ready" and tonumber(state.dailyClaimDay) < tonumber(dayOf(handle.adapter.now())),
	}
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
			reason = "RevisionChanged"; return if pending.kind=="pet"then root else nil
		end
		local allowed, failure = pending.apply(state, pending.candidate)
		if not allowed then reason = failure; return if pending.kind=="pet"then root else nil end
		state.revision += 1
		state.operationSeq = pending.sequence
		state.lastOperation = { id = pending.id, sequence = pending.sequence }
		state.lease.expiresAt = handle.adapter.now() + Hatching.LeaseSeconds
		return root
	end)
	handle.busy = false
	if ok and record and record.hatching and committed(pending,record.hatching)then
		accept(handle, record)
		handle.pending = nil
		handle.status = "Ready"
		return true, "Saved"
	end
	if ok and pending.kind=="pet"and record and fenced(handle,record.hatching,handle.adapter.now())then
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
	return transact(handle, pending.signature, pending.revision, pending.apply, pending.candidate)
end

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
		if handle.busy then return false, "Busy" end
		if handle.status ~= "Ready" then return false, handle.status end
		if expectedRevision ~= handle.state.revision then return false, "RevisionChanged" end
		if handle.state.lastHatch then return false, "RevealPending" end
		if not Catalog.isOwned(handle.state.inventoryMask, "pip") then return false, "MeetPipFirst" end
		if handle.state.nectar < recipe.cost then return false, "NeedNectar" end
		candidate = { id = handle.adapter.guid(), unit = handle.adapter.random() }
	end
	return transact(handle, signature, expectedRevision, function(state, choice)
		if action == "ack" then
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
			if state.lastHatch then return false, "RevealPending" end
			if not Catalog.isOwned(state.inventoryMask, "pip") then return false, "MeetPipFirst" end
			if state.nectar < recipe.cost then return false, "NeedNectar" end
			local petId = Catalog.roll(value, state.misses, choice.unit)
			local pet = Pets.byId[petId]
			local family = Catalog.family(petId)
			local duplicate = Catalog.isOwned(state.inventoryMask, petId)
			local previousRank = Mastery.rank(state.mastery[family], state.masteryChallenges[family])
			state.nectar -= recipe.cost
			if duplicate then state.mastery[family] = math.min(Mastery.MaxPoints, state.mastery[family] + 1) end
			state.inventoryMask = bit32.bor(state.inventoryMask, Catalog.bit(petId))
			state.misses = if pet.trial then 0 else math.min(7, state.misses + 1)
			state.lastHatch = { id = choice.id, petId = petId, duplicate = duplicate,
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
		if state.lastHatch then return false, "RevealPending" end
		state.inventoryMask = bit32.bor(state.inventoryMask, Catalog.bit("pip"))
		state.lastHatch = { id = candidate.id, petId = "pip", duplicate = false,
			family = "pip", mastery = state.mastery.pip, rare = false, starter = true }
		return true
	end, { id = handle.adapter.guid() })
end

function Hatching.award(handle, runSequence, amount, summary)
	if not integer(runSequence) or runSequence < 1 or (amount ~= 0 and amount ~= 6 and amount ~= 8) then
		return false, "InvalidReward"
	end
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
			or amount ~= (if summary.success then (if summary.clean then 8 else 6) else 0) then
			return false, "InvalidSummary"
		end
	end
	-- Copy once: the host's mutable board and day clock must never alter a
	-- pending transaction when DataStore invokes its callback again later.
	local candidate = { summary = clone(summary), day = dayOf(handle.adapter.now()) }
	local signature = "award:" .. runSequence .. ":" .. amount
	return transact(handle, signature, handle.state.revision, function(state, captured)
		if runSequence <= state.lastAwardSeq then return false, "AwardChanged" end
		local run = captured.summary
		local extra, completed, marks, promoted = 0, {}, 0, 0
		if run then
			if not Mastery.ownsFamily(state.inventoryMask, run.family) then return false, "FamilyChanged" end
			if run.success then
				local before = Mastery.rank(state.mastery[run.family], state.masteryChallenges[run.family])
				marks = if run.clean then 2 else 1
				state.mastery[run.family] = math.min(Mastery.MaxPoints, state.mastery[run.family] + marks)
				state.masteryChallenges[run.family] = bit32.bor(state.masteryChallenges[run.family], Mastery.challengeMask(run))
				local after = Mastery.rank(state.mastery[run.family], state.masteryChallenges[run.family])
				promoted = if after > before then after else 0
				state.totalWins += 1
			end
			state.contracts, extra, completed = Daily.apply(state.contracts, run, captured.day)
		end
		if state.nectar + amount + extra > 1000000000 then return false, "BalanceLimit" end
		state.nectar += amount + extra
		state.lastAwardSeq = runSequence
		state.lastRunReward = { sequence = runSequence, base = amount, daily = extra, total = amount + extra,
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
