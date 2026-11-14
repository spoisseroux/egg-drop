-- Both profile and hatch writers share the same root in Studio as in live play.
local RunService = game:GetService("RunService")
local DataStoreService = if RunService:IsStudio() then nil else game:GetService("DataStoreService")

-- v1 launch store. Private-test saves in "EggDropProgressV1" are intentionally
-- left behind: the public launch starts every player fresh (decided 2026-11-11).
local Store = { Name = "EggDropLaunchV1" }
-- TEST ONLY (Spencer 2026-11-13): FeatureFlags.TestFreshSaves gives every published version its own
-- store ("EggDropTest_v<PlaceVersion>"), so each private publish starts every player fresh. Old
-- saves are not deleted, just not read. MUST be false before the public launch (TODO launch list).
if not RunService:IsStudio() and require(game:GetService("ReplicatedStorage").Shared.FeatureFlags).TestFreshSaves == true then
	Store.Name = "EggDropTest_v" .. tostring(game.PlaceVersion)
	warn("[Egg Drop] TestFreshSaves is ON: progress store " .. Store.Name .. " (fresh saves this publish). Turn it off before launch.")
end
local backing = if DataStoreService then DataStoreService:GetDataStore(Store.Name) else nil
local memory = {}
Store.persistent = backing ~= nil

local function clone(value)
	if type(value) ~= "table" then return value end
	local result = {}
	for key, child in pairs(value) do result[key] = clone(child) end
	return result
end

-- Wait briefly for request budget instead of letting a burst (server shutdown,
-- many joins) fail and fall into slower retry paths. Never waits forever: the
-- callers already retry and fence failed writes.
local function awaitBudget(requestType, maxWait)
	if not DataStoreService then return end
	local deadline = os.clock() + maxWait
	while os.clock() < deadline do
		local ok, budget = pcall(DataStoreService.GetRequestBudgetForRequestType, DataStoreService, requestType)
		if not ok or budget > 0 then return end
		task.wait(0.25)
	end
end
Store.awaitBudget = awaitBudget

function Store:GetAsync(key)
	if not backing then return clone(memory[key]) end
	awaitBudget(Enum.DataStoreRequestType.GetAsync, 3)
	return backing:GetAsync(key)
end

function Store:UpdateAsync(key, transform)
	if not backing then
		local result = transform(clone(memory[key]))
		if result ~= nil then memory[key] = clone(result) end
		return clone(result)
	end
	awaitBudget(Enum.DataStoreRequestType.UpdateAsync, 3)
	return backing:UpdateAsync(key, transform)
end

return Store
