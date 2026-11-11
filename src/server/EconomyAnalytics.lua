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

function Economy.sink(player, amount, balance, kind, sku)
	if not enabled or type(amount) ~= "number" or amount <= 0 then return end
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

function Economy.event(player, name, value)
	call(AnalyticsService.LogCustomEvent, player, name, value or 1)
end

return Economy
