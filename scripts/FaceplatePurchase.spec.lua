-- Faceplate Star purchases (UI-SPEC-2026-11-12 5.5, SCOPE Decisions): fixed prices,
-- server debit, ownership, idempotent by operation id, never random.
-- Isolated adapters only; no DataStore or user writes.
-- Usage (Server): require(ServerScriptService.Server.ZZSpecs.FaceplatePurchase)(ServerScriptService.Server)
return function(server)
	local H = require(server.HatchProgress)
	local Faceplates = require(server.FaceplateState)
	local Shared = game:GetService("ReplicatedStorage").Shared
	local Themes = require(Shared.DeckThemes)
	local Catalog = require(Shared.AppearanceCatalog)
	local Stickers = require(Shared.DeckStickers)
	local cases = {}
	local function copy(v) if type(v) ~= "table" then return v end; local r = {}; for k, x in pairs(v) do r[k] = copy(x) end; return r end
	local function test(name, run) run(); table.insert(cases, name) end
	local function fixture()
		local db, c = {}, { now = 1700000000, serial = 0, writes = 0 }
		local adapter = {
			now = function() return c.now end,
			guid = function() c.serial += 1; return "op" .. c.serial end,
			random = function() return .1 end,
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
	local function fund(h, stars)
		assert(H.grantPurchase(h, "fund-" .. stars .. "-" .. h.state.revision, stars, false))
	end

	test("the catalogue: 16 plates, 8 free starters with the saved ids, 8 at 20/40/80", function()
		assert(#Themes.Order == 16)
		local prices = {}
		for index, id in ipairs(Themes.Order) do
			local theme = Themes.ById[id]
			assert(theme and theme.texture and theme.accent and theme.ui and theme.lcd, id)
			if index <= 8 then
				assert(theme.tier == "starter" and theme.priceStars == 0 and Themes.price(id) == nil, id)
			else
				prices[id] = Themes.price(id)
			end
		end
		for _, id in ipairs({ "sherbet", "stone", "ice", "brick", "moss", "honey", "gloaming", "copperleaf" }) do assert(Themes.ById[id].tier == "starter") end
		assert(prices.aqua_pop == 20 and prices.lime_gel == 20 and prices.sorbet_sky == 20)
		assert(prices.liquid_chrome == 40 and prices.tidepool == 40 and prices.aurora_glass == 40)
		assert(prices.prism_flare == 80 and prices.night_orb == 80)
	end)

	test("buying debits the fixed price once and records ownership", function()
		local h, db = fixture()
		fund(h, 100)
		local before = h.state.nectar
		local ok, reason = H.buyFaceplate(h, "buy-1", "aurora_glass", 40)
		assert(ok and reason == "Saved", tostring(reason))
		assert(h.state.nectar == before - 40 and db.player_1.hatching.nectar == before - 40)
		assert(Faceplates.owns(h.state, "aurora_glass"))
		assert(table.find(H.public(h).faceplates, "aurora_glass"))
	end)

	test("the same operation id and an owned plate never charge twice", function()
		local h, _, c = fixture()
		fund(h, 100)
		assert(H.buyFaceplate(h, "buy-2", "night_orb", 80))
		local balance, writes = h.state.nectar, c.writes
		local ok, reason = H.buyFaceplate(h, "buy-2", "night_orb", 80)
		assert(ok and reason == "AlreadyOwned" and h.state.nectar == balance and c.writes == writes)
		ok, reason = H.buyFaceplate(h, "buy-3", "night_orb", 80)
		assert(ok and reason == "AlreadyOwned" and h.state.nectar == balance and c.writes == writes)
	end)

	test("a replayed UpdateAsync callback and commit-then-error charge once", function()
		local h, db, c = fixture()
		fund(h, 60)
		local before = h.state.nectar
		c.replay = true
		assert(H.buyFaceplate(h, "buy-4", "tidepool", 40))
		c.replay = false
		assert(db.player_1.hatching.nectar == before - 40)
		local h2, db2, c2 = fixture()
		fund(h2, 60)
		before = h2.state.nectar
		c2.failAfter = true
		local ok, reason = H.buyFaceplate(h2, "buy-5", "lime_gel", 20)
		assert(not ok and reason == "Retrying" and db2.player_1.hatching.nectar == before - 20)
		ok = H.buyFaceplate(h2, "buy-5", "lime_gel", 20)
		assert(ok and h2.state.nectar == before - 20 and db2.player_1.hatching.nectar == before - 20)
		assert(#h2.state.faceplates == 1)
	end)

	test("refuses when the wallet is short, without writing", function()
		local h, _, c = fixture()
		local before, writes = h.state.nectar, c.writes
		assert(before < 80, "fixture starts below the showcase price")
		local ok, reason = H.buyFaceplate(h, "buy-6", "prism_flare", 80)
		assert(not ok and reason == "NeedStars" and h.state.nectar == before and c.writes == writes)
		assert(not Faceplates.owns(h.state, "prism_flare"))
	end)

	test("starters are free and not sold; prices are server-side", function()
		local h = fixture()
		fund(h, 100)
		local ok, reason = H.buyFaceplate(h, "buy-7", "sherbet", 0)
		assert(not ok and reason == "NotForSale")
		ok, reason = H.buyFaceplate(h, "buy-8", "unknown_plate", 1)
		assert(not ok and reason == "NotForSale")
		ok, reason = H.buyFaceplate(h, "buy-9", "aqua_pop", 1)
		assert(not ok and reason == "PriceChanged")
		local facts = Catalog.facts({}, h.state)
		for _, id in ipairs({ "sherbet", "stone", "ice", "brick", "moss" }) do assert(Catalog.canEquip("theme", id, facts), id) end
		assert(not Catalog.canEquip("theme", "aqua_pop", facts))
		assert(H.buyFaceplate(h, "buy-10", "aqua_pop", 20))
		assert(Catalog.canEquip("theme", "aqua_pop", Catalog.facts({}, h.state)))
	end)

	test("ownership survives a fresh session", function()
		local h, _, _, adapter = fixture()
		fund(h, 50)
		assert(H.buyFaceplate(h, "buy-11", "sorbet_sky", 20))
		assert(H.release(h))
		local again = H.load(1, { rank = 1 }, adapter)
		assert(again.status == "Ready" and Faceplates.owns(again.state, "sorbet_sky"))
	end)

	test("stickers are retired: only the blank id remains, old ids resolve to none", function()
		assert(#Stickers.Order == 1 and Stickers.Default == "none")
		for _, old in ipairs({ "star", "glitch", "seed", "wick", "club", "lantern" }) do
			assert(Stickers.ById[old] == nil and not Stickers.canEquip(old))
		end
	end)

	test("faceplate state validation tolerates later plate ids but rejects junk", function()
		assert(Faceplates.valid({ faceplates = { "future_plate" } }))
		assert(not Faceplates.valid({ faceplates = { 5 } }))
		assert(not Faceplates.valid({ faceplates = { a = "x" } }))
	end)

	return cases
end
