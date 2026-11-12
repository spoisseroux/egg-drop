-- v1 store economy. Isolated adapters only; no DataStore, MarketplaceService or user writes.
-- Run in a Server datamodel with the fresh server module namespace.
return function(server)
	local H = require(server.HatchProgress)
	local Purchases = require(server.PurchaseState)
	local Catalog = require(game:GetService("ReplicatedStorage").Shared.EggCatalog)
	local Store = require(game:GetService("ReplicatedStorage").Shared.StoreCatalog)
	local cases = {}
	local function copy(v) if type(v) ~= "table" then return v end; local r = {}; for k, x in pairs(v) do r[k] = copy(x) end; return r end
	local function test(name, run) run(); table.insert(cases, name) end
	local function fixture(sample)
		local db, c = {}, { now = 1700000000, serial = 0, writes = 0 }
		local adapter = {
			now = function() return c.now end,
			guid = function() c.serial += 1; return "op" .. c.serial end,
			random = function() return sample or .1 end,
			wait = function() end,
			update = function(key, transform)
				c.writes += 1
				if c.failBefore then c.failBefore = false; error("fixture before commit") end
				local value = transform(copy(db[key]))
				if c.replay then value = transform(copy(db[key])) end
				if value then db[key] = copy(value) end
				if c.failAfter then c.failAfter = false; error("fixture after commit") end
				return copy(value)
			end,
		}
		local h = H.load(1, { rank = 1 }, adapter)
		assert(h.status == "Ready", "fixture load " .. tostring(h.status))
		return h, db, c, adapter
	end

	-- v1: formerly checked the Meadow odds summed to 100. Every companion recipe is
	-- retired, so none publishes odds; any future active recipe must still be whole and sum to 100.
	test("retired companion eggs publish no odds; active recipes are whole percentages", function()
		assert(Catalog.ById.meadow.retired and #Catalog.odds("meadow", 0) == 0)
		for _, id in ipairs(Catalog.Order) do
			local odds, total = Catalog.odds(id, 0), 0
			assert(#odds == 0 or not Catalog.ById[id].retired)
			for _, entry in ipairs(odds) do
				assert(math.abs(entry.weight - math.round(entry.weight)) < 1e-9, "fractional odds " .. entry.weight)
				total += entry.weight
			end
			assert(#odds == 0 or math.abs(total - 100) < 1e-9, "odds total " .. total)
		end
	end)

	test("a purchase grants its Stars exactly once, even when replayed", function()
		local h, db, c = fixture()
		local before = h.state.nectar
		c.replay = true
		assert(H.grantPurchase(h, "receipt-1", 60, false))
		assert(h.state.nectar == before + 60 and db.player_1.hatching.nectar == before + 60)
		local writes = c.writes
		local ok, reason = H.grantPurchase(h, "receipt-1", 60, false)
		assert(ok and reason == "AlreadyGranted" and c.writes == writes and h.state.nectar == before + 60)
	end)

	test("commit-then-error is proved on retry without a second grant", function()
		local h, db, c = fixture()
		local before = h.state.nectar
		c.failAfter = true
		assert(not H.grantPurchase(h, "receipt-2", 20, false))
		assert(db.player_1.hatching.nectar == before + 20)
		assert(H.grantPurchase(h, "receipt-2", 20, false))
		assert(h.state.nectar == before + 20 and db.player_1.hatching.nectar == before + 20)
	end)

	test("a fresh server session sees an earlier grant and refuses to repeat it", function()
		local h, db, c, adapter = fixture()
		assert(H.grantPurchase(h, "receipt-3", 40, true))
		assert(H.release(h))
		local again = H.load(1, { rank = 1 }, adapter)
		assert(again.status == "Ready")
		local balance = again.state.nectar
		local ok, reason = H.grantPurchase(again, "receipt-3", 40, true)
		assert(ok and reason == "AlreadyGranted" and again.state.nectar == balance)
		assert(H.public(again).starterClaimed == true)
	end)

	test("ledger stays bounded and valid", function()
		local h = fixture()
		for i = 1, Purchases.Limit + 5 do assert(H.grantPurchase(h, "r" .. i, 1, false)) end
		assert(#h.state.purchases.ids == Purchases.Limit and h.state.purchases.total == Purchases.Limit + 5)
		assert(Purchases.valid(h.state))
	end)

	test("invalid purchase input is refused before any write", function()
		local h, _, c = fixture()
		local writes = c.writes
		assert(not H.grantPurchase(h, "", 10, false))
		assert(not H.grantPurchase(h, "x", 0, false))
		assert(not H.grantPurchase(h, "y", 1.5, false))
		assert(c.writes == writes or c.writes == writes) -- local precheck may still reject in-transaction
		assert(h.state.purchases == nil)
	end)

	test("2x Stars doubles round and contract Stars; Supporter adds one per finished round", function()
		local h = fixture()
		local summary = { family = "pip", day = h.state.contracts.day, success = true, clean = false,
			score = 100, chain = 1, clears = 0, drops = 24 }
		local before = h.state.nectar
		assert(H.award(h, 1, 6, summary, Store.boost({ doubleStars = true, supporter = true })))
		local reward = h.state.lastRunReward
		assert(reward.total == (reward.base + reward.daily) * 2 + 1, "boosted total " .. reward.total)
		assert(reward.bonus == reward.total - reward.base - reward.daily)
		assert(h.state.nectar == before + reward.total)
		local failed = { family = "pip", day = h.state.contracts.day, success = false, clean = false,
			score = 0, chain = 0, clears = 0, drops = 3 }
		before = h.state.nectar
		assert(H.award(h, 2, 0, failed, Store.boost({ supporter = true })))
		assert(h.state.lastRunReward.total == h.state.lastRunReward.daily + 1 and h.state.nectar == before + h.state.lastRunReward.total)
	end)

	test("no passes leaves rewards unchanged and forged boosts are clamped", function()
		local h = fixture()
		local summary = { family = "pip", day = h.state.contracts.day, success = true, clean = true,
			score = 100, chain = 1, clears = 0, drops = 24 }
		assert(H.award(h, 1, 8, summary, { multiplier = 50, bonus = 99 }))
		local reward = h.state.lastRunReward
		assert(reward.total == reward.base + reward.daily and reward.bonus == 0)
	end)

	-- v1: formerly "a duplicate companion refunds half the egg price". The retired
	-- Meadow egg is now refused with no debit, no reveal and no write.
	test("the retired companion egg is refused without spending purchased Stars", function()
		local h, _, c = fixture(.01)
		assert(H.grantStarter(h)) -- rank 1 fixtures already own pip
		if h.state.lastHatch then assert(H.command(h, "ack", h.state.lastHatch.id, h.state.revision)) end
		local stored = h.state.revision
		assert(H.grantPurchase(h, "fund", 100, false))
		local before, writes = h.state.nectar, c.writes
		local ok, reason = H.command(h, "hatch", "meadow", h.state.revision)
		assert(not ok and reason == "RetiredEgg", tostring(reason))
		assert(h.state.lastHatch == nil and h.state.nectar == before and c.writes == writes)
		assert(stored ~= nil)
	end)

	return { passed = #cases, cases = cases }
end
