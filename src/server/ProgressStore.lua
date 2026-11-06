-- Both profile and hatch writers share the same root in Studio as in live play.
local RunService = game:GetService("RunService")
local backing = if RunService:IsStudio() then nil else game:GetService("DataStoreService"):GetDataStore("EggDropProgressV1")
local memory = {}
local Store = { persistent = backing ~= nil }
local function clone(value)
	if type(value) ~= "table" then return value end
	local result = {}
	for key, child in pairs(value) do result[key] = clone(child) end
	return result
end
function Store:GetAsync(key)
	return if backing then backing:GetAsync(key) else clone(memory[key])
end
function Store:UpdateAsync(key, transform)
	if backing then return backing:UpdateAsync(key, transform) end
	local result = transform(clone(memory[key]))
	if result ~= nil then memory[key] = clone(result) end
	return clone(result)
end
return Store
