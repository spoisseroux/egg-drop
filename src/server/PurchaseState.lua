-- Durable Robux receipt ledger inside the fenced hatching record. A purchase id
-- is granted exactly once, even if ProcessReceipt runs again on another server.
local Purchases = { Limit = 64 }

local function validId(id) return type(id) == "string" and #id > 0 and #id <= 100 end

function Purchases.valid(state)
	local p = state.purchases
	if p == nil then return true end
	if type(p) ~= "table" or type(p.ids) ~= "table" or #p.ids > Purchases.Limit then return false end
	if p.starter ~= nil and type(p.starter) ~= "boolean" then return false end
	if type(p.total) ~= "number" or p.total < 0 or p.total % 1 ~= 0 then return false end
	for key in pairs(p) do if key ~= "ids" and key ~= "starter" and key ~= "total" then return false end end
	for index, id in ipairs(p.ids) do if not validId(id) then return false end; if index > Purchases.Limit then return false end end
	local last = state.lastPurchase
	if last ~= nil and (type(last) ~= "table" or not validId(last.id) or type(last.stars) ~= "number" or last.stars < 1 or last.stars % 1 ~= 0) then return false end
	return true
end

function Purchases.granted(state, purchaseId)
	local p = state.purchases
	return p ~= nil and table.find(p.ids, purchaseId) ~= nil
end

-- candidate = { purchaseId, stars, once }
function Purchases.apply(state, candidate)
	if not validId(candidate.purchaseId) or type(candidate.stars) ~= "number" or candidate.stars < 1
		or candidate.stars % 1 ~= 0 or candidate.stars > 100000 then return false, "InvalidPurchase" end
	if Purchases.granted(state, candidate.purchaseId) then return false, "AlreadyGranted" end
	if state.nectar + candidate.stars > 1000000000 then return false, "BalanceLimit" end
	local p = state.purchases or { ids = {}, total = 0 }
	p = { ids = table.clone(p.ids), starter = p.starter, total = p.total }
	table.insert(p.ids, candidate.purchaseId)
	while #p.ids > Purchases.Limit do table.remove(p.ids, 1) end
	if candidate.once then p.starter = true end
	p.total += 1
	state.purchases = p
	state.nectar += candidate.stars
	state.lastPurchase = { id = candidate.purchaseId, stars = candidate.stars }
	return true
end

function Purchases.public(state)
	local p = state.purchases
	return { starterClaimed = p ~= nil and p.starter == true, lastPurchase = state.lastPurchase }
end

return Purchases
