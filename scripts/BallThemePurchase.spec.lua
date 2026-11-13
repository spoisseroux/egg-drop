-- Ball theme Star purchases, equip and the hatching v11 save (BallThemeState +
-- LifetimeState; batch 2026-11-13 R1, BUILD-PLAN architect change 1, play-forever
-- fields): fixed prices (Kittens 120), debit and ownership in one write, idempotent by
-- operation id bound to theme + price, free themes always owned, equip any owned
-- theme, a v10 save upgrading to v11 (wallet, pets, quests, wearables kept; empty
-- ballThemes / stats / stamps / book), v11 validation, quest cleanup on a v11 record,
-- and lifetime counters written inside the existing fenced transactions.
-- Isolated adapters only; no DataStore or user writes.
-- Usage (Server): require(ServerScriptService.Server.ZZSpecs.BallThemePurchase)(ServerScriptService.Server)
return function(server)
	local H = require(server.HatchProgress)
	local B = require(server.BallThemeState)
	local L = require(server.LifetimeState)
	local Themes = require(game:GetService("ReplicatedStorage").Shared.BallThemes)
	local cases = {}
	local function copy(v) if type(v) ~= "table" then return v end; local r = {}; for k, x in pairs(v) do r[k] = copy(x) end; return r end
	local function test(name, run) run(); table.insert(cases, name) end
	local function fixture()
		local db, c = {}, { now = 1700000000, serial = 0, writes = 0, rolls = 0 }
		local adapter = {
			now = function() return c.now end,
			guid = function() c.serial += 1; return "op" .. c.serial end,
			random = function() c.rolls += 1; return .1 end,
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
	local function fund(h, stars) assert(H.grantPurchase(h, "fund-" .. stars .. "-" .. h.state.revision, stars, false)) end

	test("catalogue: six themes, Smileys default, fixed prices 0/0/20/40/40/120, no fruit", function()
		assert(Themes.Default == "smileys" and #Themes.Order == 6)
		local prices = {}
		for _, id in ipairs(Themes.Order) do prices[id] = Themes.ById[id].price end
		assert(prices.smileys == 0 and prices.marbles == 0 and prices.gumdrops == 20 and prices.gems == 40 and prices.planets == 40 and prices.kittens == 120)
		assert(Themes.price("smileys") == nil and Themes.price("kittens") == 120 and Themes.price("fruit") == nil)
		assert(Themes.ById.marbles.face == "none" and Themes.ById.marbles.texture == "motif", "Marbles is today's look")
	end)

	test("a fresh save is v11 with Smileys equipped, free themes owned, zeroed counters", function()
		local h = fixture()
		assert(h.state.version == 11 and H.valid(h.state))
		assert(B.equipped(h.state) == "smileys" and B.owns(h.state, "marbles") and not B.owns(h.state, "gems"))
		for _, key in ipairs(L.Counters) do assert(h.state.stats[key] == 0, key) end
		assert(h.state.stamps == 0 and #h.state.book.claimed == 0 and h.state.book.found == 0)
		local public = H.public(h)
		assert(public.ballThemes.equipped == "smileys" and table.find(public.ballThemes.owned, "smileys"))
	end)

	test("buying debits the fixed price once, records ownership, equips and counts Stars spent", function()
		local h, db, c = fixture()
		fund(h, 200)
		local before, rolls, spent = h.state.nectar, c.rolls, h.state.stats.starsSpent
		local ok, reason = H.buyBallTheme(h, "b-1", "kittens", 120, true)
		assert(ok and reason == "Saved", tostring(reason))
		assert(h.state.nectar == before - 120 and db.player_1.hatching.nectar == before - 120)
		assert(B.owns(h.state, "kittens") and B.equipped(h.state) == "kittens")
		assert(c.rolls == rolls, "a theme purchase drew a random number")
		assert(h.state.stats.starsSpent == spent + 120, "starsSpent not counted")
		assert(db.player_1.hatching.lastOperation.digest == "ball:kittens:120", "op id not bound to theme + price")
	end)

	test("the same operation id and an owned theme never charge twice; a free theme is never sold", function()
		local h, _, c = fixture()
		fund(h, 100)
		assert(H.buyBallTheme(h, "b-2", "gems", 40, true))
		local balance, writes = h.state.nectar, c.writes
		local ok, reason = H.buyBallTheme(h, "b-2", "gems", 40, true)
		assert(ok and reason == "AlreadyOwned" and h.state.nectar == balance and c.writes == writes)
		ok, reason = H.buyBallTheme(h, "b-3", "gems", 40, true)
		assert(ok and reason == "AlreadyOwned" and h.state.nectar == balance and c.writes == writes)
		ok, reason = H.buyBallTheme(h, "b-4", "marbles", 0, true)
		assert(ok and reason == "AlreadyOwned" and c.writes == writes, "a free theme wrote")
	end)

	test("a reused operation id with another theme or price is OperationConflict, never a false Saved", function()
		local h, db, c = fixture()
		fund(h, 200)
		assert(H.buyBallTheme(h, "b-r", "gumdrops", 20, true))
		local balance, writes = h.state.nectar, c.writes
		local ok, reason = H.buyBallTheme(h, "b-r", "planets", 40, true)
		assert(not ok and reason == "OperationConflict", tostring(reason))
		assert(not B.owns(h.state, "planets") and h.state.nectar == balance and c.writes == writes)
		-- Another server holding a stale snapshot is refused inside the callback too.
		local h2, db2 = fixture()
		fund(h2, 200)
		local stale = copy(h2.state)
		assert(H.buyBallTheme(h2, "b-s", "gumdrops", 20, true))
		local committed = copy(db2.player_1.hatching)
		h2.state = stale
		ok, reason = H.buyBallTheme(h2, "b-s", "gems", 40, true)
		assert(not ok and reason == "OperationConflict", "callback: " .. tostring(reason))
		assert(db2.player_1.hatching.nectar == committed.nectar and not B.owns(db2.player_1.hatching, "gems"))
		assert(db.player_1.hatching.lastOperation.digest == "ball:gumdrops:20")
	end)

	test("a replayed UpdateAsync callback and commit-then-error charge once", function()
		local h, db, c = fixture()
		fund(h, 60)
		local before = h.state.nectar
		c.replay = true
		assert(H.buyBallTheme(h, "b-5", "planets", 40, false))
		c.replay = false
		assert(db.player_1.hatching.nectar == before - 40 and B.equipped(h.state) == "smileys", "equip=false kept Smileys")
		local h2, db2, c2 = fixture()
		fund(h2, 60)
		before = h2.state.nectar
		c2.failAfter = true
		local ok, reason = H.buyBallTheme(h2, "b-6", "gumdrops", 20, true)
		assert(not ok and reason == "Retrying" and db2.player_1.hatching.nectar == before - 20)
		ok = H.buyBallTheme(h2, "b-6", "gumdrops", 20, true)
		assert(ok and h2.state.nectar == before - 20 and db2.player_1.hatching.nectar == before - 20)
		local count = 0; for _, id in ipairs(h2.state.ballThemes.owned) do if id == "gumdrops" then count += 1 end end
		assert(count == 1)
	end)

	test("refuses when short, at a wrong price or for an unknown theme, without writing", function()
		local h, _, c = fixture()
		local before, writes = h.state.nectar, c.writes
		assert(before < 120, "fixture starts below the Kittens price")
		local ok, reason = H.buyBallTheme(h, "b-7", "kittens", 120, true)
		assert(not ok and reason == "NeedStars" and h.state.nectar == before and c.writes == writes)
		fund(h, 200); writes = c.writes
		ok, reason = H.buyBallTheme(h, "b-8", "kittens", 80, true); assert(not ok and reason == "PriceChanged", tostring(reason))
		ok, reason = H.buyBallTheme(h, "b-9", "fruit", 20, true); assert(not ok and reason == "NotForSale")
		ok, reason = H.buyBallTheme(h, "b-10", "kittens", "120", true); assert(not ok and reason == "InvalidBallTheme")
		assert(c.writes == writes, "a refusal wrote")
	end)

	test("equip: owned and free themes only; an unchanged choice writes nothing", function()
		local h, _, c = fixture()
		local ok, reason = H.equipBallTheme(h, "e-1", "gems"); assert(not ok and reason == "Unowned", tostring(reason))
		assert(H.equipBallTheme(h, "e-2", "marbles")); assert(B.equipped(h.state) == "marbles")
		local writes = c.writes
		ok, reason = H.equipBallTheme(h, "e-3", "marbles"); assert(ok and reason == "NoChange" and c.writes == writes)
		ok, reason = H.equipBallTheme(h, "e-4", "nope"); assert(not ok and reason == "InvalidBallTheme")
		fund(h, 50); assert(H.buyBallTheme(h, "e-5", "gems", 40, false)); assert(B.equipped(h.state) == "marbles")
		assert(H.equipBallTheme(h, "e-6", "gems") and B.equipped(h.state) == "gems")
		ok, reason = H.equipBallTheme(h, "e-6", "smileys"); assert(not ok and reason == "OperationConflict", "equip id bound to theme")
	end)

	test("v11 validation: tolerant of later ids, strict on shape, equipped must be owned or free", function()
		assert(B.valid({ ballThemes = { owned = { "smileys", "future" }, equipped = "future" } }))
		assert(B.valid({ ballThemes = { owned = {}, equipped = "marbles" } }), "a free theme needs no row")
		assert(not B.valid({ ballThemes = { owned = {}, equipped = "gems" } }), "unowned paid theme equipped")
		assert(not B.valid({ ballThemes = { owned = { "a", "a" }, equipped = "smileys" } }))
		assert(not B.valid({ ballThemes = { owned = {}, equipped = "smileys", extra = 1 } }))
		assert(not B.valid({ ballThemes = { owned = { [2] = "x" }, equipped = "smileys" } }))
		assert(not B.valid({}))
		local stats = L.freshStats()
		assert(L.valid({ stats = stats, stamps = 0, book = L.freshBook() }))
		local future = copy(stats); future.newCounter = 5; assert(L.valid({ stats = future, stamps = 3, book = { claimed = { "balls25" }, found = 9 } }))
		local missing = copy(stats); missing.rounds = nil; assert(not L.valid({ stats = missing, stamps = 0, book = L.freshBook() }))
		local negative = copy(stats); negative.merges = -1; assert(not L.valid({ stats = negative, stamps = 0, book = L.freshBook() }))
		assert(not L.valid({ stats = stats, stamps = 1.5, book = L.freshBook() }))
		assert(not L.valid({ stats = stats, stamps = 0, book = { claimed = { "a", "a" }, found = 0 } }))
		assert(not L.valid({ stats = stats, stamps = 0, book = { claimed = {}, found = 0, junk = true } }))
	end)

	test("a v10 save upgrades to v11: wallet, pets, quests and wearables kept; never a failed load", function()
		local h, db, _, adapter = fixture()
		fund(h, 40)
		local balance = h.state.nectar
		assert(H.release(h))
		local old = copy(db.player_1.hatching)
		old.version = 10; old.ballThemes, old.stats, old.stamps, old.book = nil, nil, nil, nil; old.lease = { token = "", expiresAt = 0 }
		assert(H.validV10(old), "fixture is an authentic v10 record")
		db.player_1.hatching = old
		local again = H.load(1, { rank = 1 }, adapter)
		assert(again.status == "Ready" and again.state.version == 11, tostring(again.status))
		assert(again.state.nectar == balance and again.state.inventoryMask == old.inventoryMask and again.state.quests ~= nil)
		assert(type(again.state.petWearables) == "table" and B.equipped(again.state) == "smileys" and again.state.stats.rounds == 0)
		-- A v10 record carrying stray v11 fields is upgraded with fresh ones, never a failed load.
		assert(H.release(again))
		local stray = copy(old); stray.ballThemes = { owned = "junk" }; stray.stats = { rounds = -4 }; db.player_1.hatching = stray
		local cleaned = H.load(1, { rank = 1 }, adapter)
		assert(cleaned.status == "Ready" and cleaned.state.version == 11 and B.equipped(cleaned.state) == "smileys" and cleaned.state.stats.rounds == 0)
		-- Ownership and the equipped theme survive a fresh session on v11.
		fund(cleaned, 30); assert(H.buyBallTheme(cleaned, "v-1", "gumdrops", 20, true)); assert(H.release(cleaned))
		local carried = H.load(1, { rank = 1 }, adapter)
		assert(carried.status == "Ready" and B.owns(carried.state, "gumdrops") and B.equipped(carried.state) == "gumdrops")
	end)

	test("quest cleanup runs on v11 (version >= 10): an old-catalogue quest record is a fresh draw, not InvalidData", function()
		local h, db, _, adapter = fixture()
		assert(H.release(h))
		local record = copy(db.player_1.hatching)
		assert(record.version == 11)
		record.quests = { v = 1, catalog = -1 }; record.lease = { token = "", expiresAt = 0 }
		db.player_1.hatching = record
		local again = H.load(1, { rank = 1 }, adapter)
		assert(again.status == "Ready" and again.state.version == 11 and again.state.quests.v == 1, "v11 quest cleanup: " .. tostring(again.status))
	end)

	test("lifetime counters ride the fenced round award: rounds, wins by difficulty, tidy, best chain, tier V, Stars earned", function()
		local h = fixture()
		local family = "pip"
		local function run(seq, success, clean, heat, chain, maxTier)
			local amount = if success then(if clean then 8 else 6)else 0
			local summary = { family = family, day = tostring(require(game:GetService("ReplicatedStorage").Shared.DailyContracts).dayOf(1700000000)),
				success = success, clean = clean, score = 100, chain = chain, clears = 0, drops = if success then 24 else 10, heat = heat, maxTier = maxTier }
			local ok, reason = H.award(h, seq, amount, summary, {})
			assert(ok, "award " .. tostring(reason))
		end
		local earned = h.state.stats.starsEarned
		run(1, true, true, "hard", 4, 5)
		run(2, true, false, "easy", 2, 3)
		run(3, false, false, "medium", 6, 2)
		local s = h.state.stats
		assert(s.rounds == 3 and s.winsHard == 1 and s.winsEasy == 1 and s.winsMedium == 0 and s.tidyWins == 1, "rounds/wins")
		assert(s.bestChain == 6 and s.tierFive == 1, "bestChain/tierFive")
		assert(s.starsEarned > earned, "starsEarned")
		-- A Robux Star grant is not "earned".
		local before = s.starsEarned; fund(h, 50); assert(h.state.stats.starsEarned == before, "a purchase counted as earned")
	end)

	return cases
end
