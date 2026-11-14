-- Roblox Analytics for the Stars economy and core loop. Live servers only:
-- Roblox accepts analytics from published games, so Studio is a no-op.
-- Retention (D1/D7) comes from the Creator Dashboard automatically.
local AnalyticsService = game:GetService("AnalyticsService")
local Players = game:GetService("Players")
local RunService = game:GetService("RunService")

local Economy = { Currency = "Stars" }
local enabled = not RunService:IsStudio() and game.GameId ~= 0

local function call(method, player, ...)
	if not enabled then return end
	local args = table.pack(...)
	task.defer(function()
		if player.Parent ~= Players then return end
		local ok, problem = pcall(method, AnalyticsService, player, table.unpack(args, 1, args.n))
		if not ok then warn("Egg Drop analytics:", problem) end
	end)
end

local function transaction(kind)
	local ok, item = pcall(function() return Enum.AnalyticsEconomyTransactionType[kind] end)
	return if ok and item then item.Name else kind
end

-- kind: IAP, Shop, Gameplay, TimedReward, Onboarding, ContextualPurchase
function Economy.source(player, amount, balance, kind, sku)
	if not enabled or type(amount) ~= "number" or amount <= 0 then return end
	call(AnalyticsService.LogEconomyEvent, player, Enum.AnalyticsEconomyFlowType.Source, Economy.Currency,
		amount, balance, transaction(kind), sku)
end

-- Optional hook (init.server): called on every Stars sink (the funnel's "First Stars spend"
-- step). Live servers only in practice: Economy.command returns early in Studio. Never errors
-- into the caller.
Economy.onSink = nil

function Economy.sink(player, amount, balance, kind, sku)
	if type(amount) ~= "number" or amount <= 0 then return end
	if Economy.onSink then pcall(Economy.onSink, player, amount, sku) end
	if not enabled then return end
	call(AnalyticsService.LogEconomyEvent, player, Enum.AnalyticsEconomyFlowType.Sink, Economy.Currency,
		amount, balance, transaction(kind), sku)
end

-- A nursery command changed the wallet from `before` to `after`.
-- Hatch results carry their own refund so cost and refund log separately.
function Economy.command(player, action, before, after, state)
	if not enabled or type(before) ~= "number" or type(after) ~= "number" then return end
	if action == "hatch" and state and state.lastHatch then
		local refund = state.lastHatch.refund or 0
		local cost = before - after + refund
		Economy.sink(player, cost, after - refund, "Shop", "CompanionEgg_" .. tostring(state.lastHatch.recipe or "meadow"))
		Economy.source(player, refund, after, "Gameplay", "DuplicateRefund")
	elseif action == "daily" then
		Economy.source(player, after - before, after, "TimedReward", "DailyGift")
	elseif after < before then
		Economy.sink(player, before - after, after, "Shop", action)
	elseif after > before then
		Economy.source(player, after - before, after, "Gameplay", action)
	end
end

-- Custom-field slots Roblox accepts: up to three string values, keyed by enum.
local fieldKeys = {"CustomField01", "CustomField02", "CustomField03"}
local function customFields(fields)
	if type(fields) ~= "table" then return nil end
	local out, any = {}, false
	for i, key in ipairs(fieldKeys) do
		local value = fields[i]
		if value ~= nil then
			local ok, enumKey = pcall(function() return Enum.AnalyticsCustomFieldKeys[key].Name end)
			if ok and enumKey then out[enumKey] = string.sub(tostring(value), 1, 50); any = true end
		end
	end
	return if any then out else nil
end
Economy.customFields = customFields

-- fields: optional array of up to three values (CustomField01..03); keep names low-cardinality
-- and put ids in fields.
function Economy.event(player, name, value, fields)
	local packed = customFields(fields)
	if packed then
		call(AnalyticsService.LogCustomEvent, player, name, value or 1, packed)
	else
		call(AnalyticsService.LogCustomEvent, player, name, value or 1)
	end
end

-- An egg opened (Toy, Feature, Material, Hue). The family is in the name (4 values), the
-- result id in CustomField01. A refused receipt (stack limit) is not an open.
local resultKeys = {"featureId", "toyId", "finishId", "materialId", "itemId", "resultItem"}
function Economy.eggOpened(player, family, receipt)
	if type(receipt) == "table" and receipt.outcome == "Refused" then return end
	local result = "unknown"
	if type(receipt) == "table" then
		for _, key in ipairs(resultKeys) do
			if type(receipt[key]) == "string" then result = receipt[key]; break end
		end
	end
	Economy.event(player, "EggOpened_" .. tostring(family), 1, {result})
end

-- Synchronous variant for PlayerRemoving (the deferred path drops a leaving player).
function Economy.eventNow(player, name, value)
	if not enabled then return end
	local ok, problem = pcall(AnalyticsService.LogCustomEvent, AnalyticsService, player, name, value or 1)
	if not ok then warn("Egg Drop analytics:", problem) end
end

return Economy
