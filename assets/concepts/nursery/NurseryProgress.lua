local DataStoreService = game:GetService("DataStoreService")
local HttpService = game:GetService("HttpService")
local ReplicatedStorage = game:GetService("ReplicatedStorage")
local RunService = game:GetService("RunService")
local Catalog = require(ReplicatedStorage.Shared.NurseryCatalog)
local Pets = require(ReplicatedStorage.Shared.PetCatalog)

local Nursery = { LeaseSeconds = 90, RenewSeconds = 20 }
local store = if RunService:IsStudio() then nil else DataStoreService:GetDataStore("EggDropProgressV1")
local memory = {}
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
			if store then return store:UpdateAsync(key, transform) end
			local nextRecord = transform(clone(memory[key]))
			if nextRecord ~= nil then memory[key] = clone(nextRecord) end
			return clone(nextRecord)
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

local function migrate(record)
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
	local mastery = {}
	for _, family in ipairs(Catalog.Families) do mastery[family] = 0 end
	return {
		version = 2, migrated = true, welcomeCredited = true,
		nectar = charge + 6, inventoryMask = mask, mastery = mastery, misses = 0,
		revision = 0, epoch = 0, operationSeq = 0, lastAwardSeq = 0,
		lease = { token = "", expiresAt = 0 },
	}
end

local function valid(state)
	if type(state) ~= "table" or state.version ~= 2 or state.migrated ~= true
		or state.welcomeCredited ~= true or not integer(state.nectar)
		or not integer(state.inventoryMask, 127) or not integer(state.misses, 7)
		or not integer(state.revision) or not integer(state.epoch)
		or not integer(state.operationSeq) or not integer(state.lastAwardSeq)
		or type(state.mastery) ~= "table" or type(state.lease) ~= "table"
		or type(state.lease.token) ~= "string" or type(state.lease.expiresAt) ~= "number" then
		return false
	end
	for _, family in ipairs(Catalog.Families) do
		if not integer(state.mastery[family], 3) then return false end
	end
	local project = state.project
	if project ~= nil then
		if type(project) ~= "table" or type(project.id) ~= "string"
			or not Catalog.ById[project.recipe] or not integer(project.funded)
			or project.funded < 6 or project.funded > Catalog.ById[project.recipe].cost
			or project.funded % 6 ~= 0 or type(project.needsCare) ~= "boolean"
			or type(project.ready) ~= "boolean" or type(project.guaranteed) ~= "boolean"
			or project.ready ~= (project.funded == Catalog.ById[project.recipe].cost and not project.needsCare) then return false end
	end
	if state.lastHatch ~= nil then
		if type(state.lastHatch) ~= "table" or type(state.lastHatch.id) ~= "string"
			or not Pets.byId[state.lastHatch.petId] then return false end
	end
	return true
end

local function accept(handle, record)
	handle.state = clone(record.nursery)
	handle.companionId = if Catalog.isOwned(handle.state.inventoryMask, record.companionId)
		then record.companionId else nil
	handle.nextRunSeq = math.max(handle.nextRunSeq or 1, handle.state.lastAwardSeq + 1)
end

function Nursery.load(userId, profile, adapter)
	adapter = adapter or defaultAdapter()
	local handle = {
		key = "player_" .. userId, adapter = adapter, token = adapter.guid(),
		status = "Loading", busy = false, nextRunSeq = 1,
	}
	if profile and profile.loadFailed then
		handle.state = migrate(legacyRecord(profile))
		handle.state.nectar = 0
		handle.status = "Temporary"
		return handle
	end
	local reason = "Unavailable"
	local function acquire(previous)
		local root = if type(previous) == "table" then clone(previous) else legacyRecord(profile)
		local state = root.nursery
		if state == nil then state = migrate(root) end
		if not valid(state) then reason = "InvalidData"; return nil end
		state = clone(state)
		local now = adapter.now()
		-- A timed-out acquire may already have committed. Retry the same token
		-- without taking another epoch or locking this connection out of itself.
		if state.lease.token == handle.token and state.lease.expiresAt > now then
			root.nursery = state
			return root
		end
		if state.lease.token ~= "" and state.lease.expiresAt > now then reason = "Locked"; return nil end
		state.epoch += 1
		state.revision += 1
		state.lease = { token = handle.token, expiresAt = now + Nursery.LeaseSeconds }
		root.nursery = state
		return root
	end
	local ok, record
	for attempt = 1, 3 do
		ok, record = pcall(adapter.update, handle.key, acquire)
		if ok then break end
		if attempt < 3 and adapter.wait then adapter.wait(attempt * 0.5) end
	end
	if ok and record and record.nursery and record.nursery.lease.token == handle.token then
		accept(handle, record)
		handle.epoch = handle.state.epoch
		handle.status = "Ready"
	else
		handle.state = migrate(legacyRecord(profile))
		handle.state.nectar = 0
		handle.status = if ok then reason else "Unavailable"
		if not ok then warn("Egg Drop nursery load failed:", record) end
	end
	return handle
end

function Nursery.public(handle)
	local state = handle.state
	if not state then return { status = handle.status, revision = 0 } end
	return {
		status = handle.status, revision = state.revision, nectar = state.nectar,
		misses = state.misses, inventoryMask = state.inventoryMask, mastery = clone(state.mastery),
		project = clone(state.project), lastHatch = clone(state.lastHatch),
	}
end

local function fenced(handle, state, now)
	return valid(state) and state.epoch == handle.epoch and state.lease.token == handle.token
		and state.lease.expiresAt > now
end

-- Pending operations retain their identity and RNG candidate after an ambiguous
-- write failure. A callback retry can never charge twice or choose another pet.
local function transact(handle, signature, expectedRevision, apply, candidate)
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
			signature = signature, id = handle.adapter.guid(), revision = expectedRevision,
			sequence = handle.state.operationSeq + 1, apply = apply, candidate = candidate,
		}
		handle.pending = pending
	end
	handle.busy = true
	local reason = "Unavailable"
	local ok, record = pcall(handle.adapter.update, handle.key, function(previous)
		if type(previous) ~= "table" or not fenced(handle, previous.nursery, handle.adapter.now()) then
			reason = "SessionLost"; return nil
		end
		local root = clone(previous)
		local state = root.nursery
		if state.lastOperation and state.lastOperation.id == pending.id then return root end
		if state.revision ~= pending.revision or state.operationSeq + 1 ~= pending.sequence then
			reason = "RevisionChanged"; return nil
		end
		local allowed, failure = pending.apply(state, pending.candidate)
		if not allowed then reason = failure; return nil end
		state.revision += 1
		state.operationSeq = pending.sequence
		state.lastOperation = { id = pending.id, sequence = pending.sequence }
		state.lease.expiresAt = handle.adapter.now() + Nursery.LeaseSeconds
		return root
	end)
	handle.busy = false
	if ok and record and record.nursery and record.nursery.lastOperation
		and record.nursery.lastOperation.id == pending.id then
		accept(handle, record)
		handle.pending = nil
		handle.status = "Ready"
		return true, "Saved"
	end
	if not ok then
		handle.status = "Retrying"
		warn("Egg Drop nursery save failed:", record)
		return false, "Retrying"
	end
	handle.pending = nil
	if reason == "SessionLost" then handle.status = "SessionLost" end
	return false, reason
end

function Nursery.command(handle, action, value, expectedRevision)
	if type(action) ~= "string" or type(value) ~= "string" or #value > 100
		or not integer(expectedRevision) then return false, "InvalidCommand" end
	local signature = action .. ":" .. value .. ":" .. expectedRevision
	local candidate = handle.pending and handle.pending.candidate
	if not handle.pending then
		if action == "start" then candidate = { id = handle.adapter.guid() }
		elseif action == "hatch" then candidate = { id = handle.adapter.guid(), unit = handle.adapter.random() } end
	end
	return transact(handle, signature, expectedRevision, function(state, choice)
		if action == "ack" then
			if not state.lastHatch or state.lastHatch.id ~= value then return false, "HatchChanged" end
			state.lastHatch = nil
			return true
		elseif action == "start" then
			if not Catalog.ById[value] then return false, "UnknownEgg" end
			if state.project then return false, "EggAlreadyActive" end
			if state.lastHatch then return false, "RevealPending" end
			if not Catalog.isOwned(state.inventoryMask, "pip") then return false, "MeetPipFirst" end
			if state.nectar < Catalog.StageCost then return false, "NeedNectar" end
			state.nectar -= Catalog.StageCost
			state.project = { id = choice.id, recipe = value, funded = Catalog.StageCost,
				needsCare = true, ready = false, guaranteed = state.misses >= Catalog.RareGuarantee }
			return true
		end
		local project = state.project
		if not project or project.id ~= value then return false, "EggChanged" end
		local recipe = Catalog.ById[project.recipe]
		if action == "fund" then
			if project.needsCare then return false, "CareFirst" end
			if project.ready then return false, "ReadyToHatch" end
			if state.nectar < Catalog.StageCost then return false, "NeedNectar" end
			state.nectar -= Catalog.StageCost
			project.funded += Catalog.StageCost
			project.needsCare = true
			return true
		elseif action == "care" then
			if not project.needsCare then return false, "AlreadyCared" end
			project.needsCare = false
			project.ready = project.funded >= recipe.cost
			return true
		elseif action == "hatch" then
			if not project.ready or project.needsCare then return false, "NotReady" end
			local petId = Catalog.roll(project.recipe, if project.guaranteed then 7 else 0, choice.unit)
			local pet = Pets.byId[petId]
			local family = Catalog.family(petId)
			local duplicate = Catalog.isOwned(state.inventoryMask, petId)
			if duplicate then state.mastery[family] = math.min(3, state.mastery[family] + 1) end
			state.inventoryMask = bit32.bor(state.inventoryMask, Catalog.bit(petId))
			state.misses = if pet.trial then 0 else math.min(7, state.misses + 1)
			state.lastHatch = { id = choice.id, petId = petId, duplicate = duplicate,
				family = family, mastery = state.mastery[family], rare = pet.trial ~= nil }
			state.project = nil
			return true
		end
		return false, "UnknownAction"
	end, candidate)
end

function Nursery.grantStarter(handle)
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

function Nursery.award(handle, runSequence, amount)
	if not integer(runSequence) or runSequence < 1 or (amount ~= 0 and amount ~= 6 and amount ~= 8) then
		return false, "InvalidReward"
	end
	if runSequence <= handle.state.lastAwardSeq then return true, "AlreadyAwarded" end
	return transact(handle, "award:" .. runSequence .. ":" .. amount, handle.state.revision, function(state)
		if runSequence <= state.lastAwardSeq then return false, "AwardChanged" end
		if state.nectar + amount > 1000000000 then return false, "BalanceLimit" end
		state.nectar += amount
		state.lastAwardSeq = runSequence
		return true
	end)
end

local function maintain(handle, releasing)
	if handle.busy then return false, "Busy" end
	if handle.status ~= "Ready" and handle.status ~= "Retrying" then return false, handle.status end
	handle.busy = true
	local reason = "SessionLost"
	local ok, record = pcall(handle.adapter.update, handle.key, function(previous)
		if type(previous) ~= "table" or not fenced(handle, previous.nursery, handle.adapter.now()) then return nil end
		local root = clone(previous)
		root.nursery.lease.expiresAt = if releasing then 0 else handle.adapter.now() + Nursery.LeaseSeconds
		return root
	end)
	handle.busy = false
	if ok and record and record.nursery and record.nursery.lease.token == handle.token then
		accept(handle, record)
		if handle.pending and handle.state.lastOperation and handle.state.lastOperation.id == handle.pending.id then
			handle.pending = nil
		end
		handle.status = if releasing then "Released" elseif handle.pending then "Retrying" else "Ready"
		return true, handle.status
	end
	if not ok then reason = "Retrying"; warn("Egg Drop nursery lease write failed:", record) end
	handle.status = reason
	return false, reason
end

function Nursery.renew(handle) return maintain(handle, false) end
function Nursery.release(handle) return maintain(handle, true) end

return Nursery
