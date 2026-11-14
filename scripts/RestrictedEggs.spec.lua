-- Paid random items policy (play-forever F1; BUILD-PLAN architect change 6). PolicyService
-- is read once per player and fails CLOSED (unknown = restricted). For a restricted
-- player every Star-priced egg (toys, finishes, fruit, features, pet hatch) gives the
-- fixed next item from a published order and draws no random number, enforced in
-- HatchProgress; the snapshot publishes `restricted` and `nextFixed` so the client can
-- show "Next: <item>". Unrestricted players still roll. Isolated adapters only.
-- Usage (Server): require(ServerScriptService.Server.ZZSpecs.RestrictedEggs)(ServerScriptService.Server)
return function(server)
	local H = require(server.HatchProgress)
	local Policy = require(server.PaidRandomPolicy)
	local Shared = game:GetService("ReplicatedStorage").Shared
	local Toys = require(Shared.ToyCatalog)
	local Finishes = require(Shared.MaterialCatalog)
	local Hue = require(Shared.HueCatalog)
	local Features = require(Shared.FeatureCatalog)
	local Eggs = require(Shared.EggCatalog)
	local cases = {}
	local function copy(v) if type(v) ~= "table" then return v end; local r = {}; for k, x in pairs(v) do r[k] = copy(x) end; return r end
	local function test(name, run) run(); table.insert(cases, name) end
	local function fixture(restricted)
		local db, c = {}, { now = 1700000000, serial = 0, writes = 0, rolls = 0, unit = .99, quotes = 0 }
		local adapter = {
			now = function() return c.now end,
			guid = function() c.serial += 1; return "op" .. c.serial end,
			random = function() c.rolls += 1; return c.unit end,
			wait = function() end,
			update = function(key, transform)
				c.writes += 1
				local value = transform(copy(db[key]))
				if value then db[key] = copy(value) end
				return copy(value)
			end,
		}
		local h = H.load(1, { rank = 1 }, adapter)
		assert(h.status == "Ready", "fixture load " .. tostring(h.status))
		h.restricted = restricted
		assert(H.grantPurchase(h, "fund", 1000, false))
		return h, db, c
	end
	local function quote(h, c, kind, fields)
		c.quotes += 1
		local revision = h.state.revision
		local value = copy(fields or {})
		value.id = tostring(revision) .. ":" .. (if kind == "hue" then "" else kind .. "-") .. "fixed-" .. c.quotes
		value.catalogVersion = if kind == "hue" then Hue.CatalogVersion else 1
		return value, revision
	end
	local function command(h, c, kind, action, fields)
		local value, revision = quote(h, c, kind, fields)
		local ok, why = H[kind .. "Command"](h, action, value, revision)
		assert(ok, action .. " " .. tostring(why))
	end
	local function buyToy(h, c) command(h, c, "toy", "toyBuy", { poolVersion = Toys.PoolVersion, eligible = Toys.remaining(h.state.toyUnlocks) }); command(h, c, "toy", "toyAck", { resultId = h.state.pendingToyResult.id }) end
	local function buyFinish(h, c) command(h, c, "material", "materialBuy", { poolVersion = Finishes.PoolVersion, eligible = Finishes.remaining(h.state.materialUnlocks) }); command(h, c, "material", "materialAck", { resultId = h.state.pendingMaterialResult.id }) end
	local function buyFruit(h, c) command(h, c, "hue", "hueBuy", {}); command(h, c, "hue", "hueStore", { resultId = h.state.pendingHueResult.id }) end
	local function buyFeature(h, c) command(h, c, "feature", "featureBuy", { poolVersion = Features.PoolVersion }); command(h, c, "feature", "featureAck", { resultId = h.state.pendingFeatureResult.id }) end

	test("policy read fails closed: restricted unless the policy says false", function()
		local waits = 0
		local function wait() waits += 1 end
		assert(Policy.read({}, function() return { ArePaidRandomItemsRestricted = true } end, wait) == true)
		assert(Policy.read({}, function() return { ArePaidRandomItemsRestricted = false } end, wait) == false)
		assert(Policy.read({}, function() return {} end, wait) == true, "a missing field must read as restricted")
		assert(Policy.read({}, function() return "junk" end, wait) == true)
		waits = 0
		assert(Policy.read({}, function() error("PolicyService down") end, wait) == true and waits == Policy.Attempts - 1)
		local calls = 0
		assert(Policy.read({}, function() calls += 1; if calls == 1 then error("blip") end; return { ArePaidRandomItemsRestricted = false } end, wait) == false)
	end)

	test("policy cache: unknown is restricted; one read per player; forget clears", function()
		local player = { UserId = -9001 }
		Policy.forget(player)
		assert(Policy.cached(player) == true and Policy.cached(nil) == true)
		local reads = 0
		local function allowed() reads += 1; return { ArePaidRandomItemsRestricted = false } end
		assert(Policy.resolve(player, allowed, function() end) == false and Policy.cached(player) == false)
		assert(Policy.resolve(player, allowed, function() end) == false and reads == 1, "policy read twice")
		Policy.forget(player)
		assert(Policy.cached(player) == true)
		assert(Policy.resolve(player, function() error("down") end, function() end) == true and Policy.cached(player) == true)
		Policy.forget(player)
	end)

	test("restricted toys and finishes follow the published PaidOrder with no random draw", function()
		local h, _, c = fixture(true)
		assert(H.public(h).restricted == true and H.public(h).nextFixed.toy == Toys.PaidOrder[1])
		local rolls = c.rolls
		for _, id in ipairs(Toys.PaidOrder) do
			assert(H.public(h).nextFixed.toy == id)
			buyToy(h, c)
			assert(h.state.toyUnlocks[id] == true, "expected toy " .. id)
		end
		assert(H.public(h).nextFixed.toy == nil, "nothing left to show")
		for _, id in ipairs(Finishes.PaidOrder) do
			assert(H.public(h).nextFixed.material == id)
			buyFinish(h, c)
			assert(h.state.materialUnlocks[id] == true, "expected finish " .. id)
		end
		assert(c.rolls == rolls, "a restricted purchase drew a random number")
	end)

	test("restricted fruit and features give the item held fewest of, in published order", function()
		local h, _, c = fixture(true)
		local rolls = c.rolls
		for _, id in ipairs(Hue.RollOrder) do
			assert(H.public(h).nextFixed.hue == id)
			local before = h.state.hueInventory[id]
			buyFruit(h, c)
			assert(h.state.hueInventory[id] == before + 1, "expected fruit " .. id)
		end
		assert(H.public(h).nextFixed.hue == Hue.RollOrder[1], "the order starts over")
		for _, id in ipairs({ "horns", "claws", "wings", "horns" }) do
			assert(H.public(h).nextFixed.feature == id)
			local before = h.state.featureStock[id]
			buyFeature(h, c)
			assert(h.state.featureStock[id] == before + 1, "expected feature " .. id)
		end
		assert(c.rolls == rolls, "a restricted purchase drew a random number")
	end)

	test("unrestricted players still roll (snapshot says restricted = false)", function()
		local h, _, c = fixture(false)
		assert(H.public(h).restricted == false)
		local rolls = c.rolls
		c.unit = .99
		buyToy(h, c)
		assert(h.state.toyUnlocks[Toys.Pools[Toys.PoolVersion][#Toys.Pools[Toys.PoolVersion]]] == true, "a .99 roll takes the last eligible toy")
		buyFeature(h, c)
		assert(h.state.featureStock.wings == 1, "a .99 roll is wings")
		assert(c.rolls == rolls + 2)
	end)

	test("pet hatch: fixed next pet by recipe order; retired recipes stay refused with no draw", function()
		assert(Eggs.fixedNext("meadow", 0) == nil and Eggs.fixedNext("nope", 0) == nil, "retired recipes publish nothing")
		local h, _, c = fixture(true)
		assert(next(H.public(h).nextFixed.hatch) == nil, "v1 has no live pet egg")
		local rolls, writes = c.rolls, c.writes
		local ok, reason = H.command(h, "hatch", "meadow", h.state.revision)
		assert(not ok and reason == "RetiredEgg" and c.rolls == rolls and c.writes == writes)
	end)

	return cases
end
