-- Collection book claims (play-forever F1; BUILD-PLAN architect changes 1 and 3): page
-- percent computed by the server from the save (current catalogue ids only, capped 100),
-- unknown / retired / free ids ignored, a milestone pays once (`book.claimed`), the op id
-- is bound to milestone + reward (retry pays once, a reused id is OperationConflict),
-- claims survive a page dropping below them, and the book-only faceplate `bookworm` is
-- granted at three `<page>.100` claims, never sold, equippable once owned, and repaired
-- by any later claim. Isolated adapters only; no DataStore or user writes.
-- Usage (Server): require(ServerScriptService.Server.ZZSpecs.BookClaim)(ServerScriptService.Server)
return function(server)
	local H = require(server.HatchProgress)
	local Faceplates = require(server.FaceplateState)
	local Shared = game:GetService("ReplicatedStorage").Shared
	local Book = require(Shared.BookCatalog)
	local Plates = require(Shared.DeckThemes)
	local Balls = require(Shared.BallThemes)
	local Appearance = require(Shared.AppearanceCatalog)
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
	-- Change the saved record directly (as another build or an old save would), then let
	-- the session pick it up through a lease renewal.
	local function edit(h, db, change) change(db.player_1.hatching); assert(H.renew(h), "renew after edit") end
	local function fund(h, stars) assert(H.grantPurchase(h, "fund-" .. stars .. "-" .. h.state.revision, stars, false)) end
	local function claimedCount(h, id) local n = 0; for _, x in ipairs(h.state.book.claimed) do if x == id then n += 1 end end; return n end
	local function allPaidBalls() local owned = { "smileys", "marbles" }; for _, id in ipairs(Balls.Order) do if Balls.price(id) then table.insert(owned, id) end end; return owned end
	local function allFound() local mask = 0; for _, entry in ipairs(Book.Discoveries) do mask = bit32.bor(mask, bit32.lshift(1, entry.bit)) end; return mask end

	test("catalogue: five pages while the Bear is the only pet, 20 milestones paying 5/5/10/15 (175), fixed discovery bits", function()
		-- The Pets page opens with a second pet (Book.PetsPageMin); its ids stay reserved.
		assert(table.concat(Book.PageOrder, ",") == "balls,faceplates,wardrobe,toys,discoveries")
		assert(#Book.Milestones == 20 and Book.totalReward() == 175 and Book.milestone("pets.25") == nil)
		for _, page in ipairs(Book.PageOrder) do
			assert(Book.milestone(page .. ".25").reward == 5 and Book.milestone(page .. ".50").reward == 5
				and Book.milestone(page .. ".75").reward == 10 and Book.milestone(page .. ".100").reward == 15, page)
		end
		assert(Book.milestone("balls.30") == nil and Book.milestone("nope.25") == nil and Book.milestone(nil) == nil)
		local bits = {}
		for _, entry in ipairs(Book.Discoveries) do assert(entry.bit >= 0 and entry.bit <= 30 and not bits[entry.bit], entry.id); bits[entry.bit] = true end
		assert(Book.DiscoveryById.tier_five.bit == 0 and Book.DiscoveryById.chain_five.bit == 1)
		for _, template in ipairs(require(Shared.FieldObjectives).Order) do assert(Book.DiscoveryById["win_" .. template], template) end
		for _, heat in ipairs({ "easy", "medium", "hard" }) do assert(Book.DiscoveryById["win_" .. heat], heat) end
		-- Free and starter items are not pages items; every page item is a current catalogue id.
		for _, item in ipairs(Book.Pages.balls.items) do assert(Balls.price(item.id), item.id) end
		for _, item in ipairs(Book.Pages.faceplates.items) do assert(Plates.price(item.id) and item.id ~= "bookworm", item.id) end
		assert(Book.Pages.faceplates.bookOnly[1] == "bookworm")
	end)

	test("bookworm: book-only, never sold, not in the shop grid, equippable once owned", function()
		local theme = Plates.ById.bookworm
		assert(theme and theme.bookOnly and theme.rule == "book" and Plates.price("bookworm") == nil and Plates.isBookOnly("bookworm"))
		assert(table.find(Plates.Order, "bookworm") == nil and table.find(Plates.BookOnly, "bookworm"))
		assert(typeof(theme.ui.panel) == "Color3" and typeof(theme.accent) == "Color3" and type(theme.texture) == "string")
		local h, _, c = fixture()
		fund(h, 500)
		local writes, balance = c.writes, h.state.nectar
		local ok, reason = H.buyFaceplate(h, "bw-1", "bookworm", 0)
		assert(not ok and reason == "NotForSale" and c.writes == writes and h.state.nectar == balance, tostring(reason))
		assert(not Appearance.canEquip("theme", "bookworm", { faceplates = {} }))
		assert(Appearance.canEquip("theme", "bookworm", { faceplates = { "bookworm" } }))
		assert(Appearance.describeRequirement("theme", "bookworm", {}).text == "Fill any three collection book pages")
	end)

	test("percent comes from the save; old saves see every reached milestone at once", function()
		local h = fixture()
		local book = H.public(h).book
		local pages = {}; for _, row in ipairs(book.pages) do pages[row.id] = row end
		assert(pages.balls.percent == 0 and pages.balls.owned == 0 and pages.balls.total == #Book.Pages.balls.items)
		assert(pages.pets == nil and #book.claimable == 0, "no free Pets page with one pet: " .. table.concat(book.claimable, ","))
		fund(h, 100)
		assert(H.buyBallTheme(h, "g-1", "gumdrops", 20, false))
		local expected = math.floor(100 / #Book.Pages.balls.items)
		assert(Book.pagePercent(h.state, "balls") == expected)
		local before = h.state.nectar
		local ok, reason = H.bookClaim(h, "c-1", "balls.25", 5)
		assert(ok and reason == "Saved" and h.state.nectar == before + 5 and claimedCount(h, "balls.25") == 1, tostring(reason))
		ok, reason = H.bookClaim(h, "c-2", "balls.50", 5)
		assert(not ok and reason == "NotReached" and h.state.nectar == before + 5, tostring(reason))
		assert(h.state.stats.starsEarned >= 5)
	end)

	test("unknown, retired and free ids never count toward a page", function()
		assert(Book.pageProgress({ ballThemes = { owned = { "smileys", "marbles", "future" } } }, "balls").owned == 0)
		assert(Book.pageProgress({ materialUnlocks = { metal = true } }, "toys").owned == 0, "retired Metal counted")
		assert(Book.pageProgress({ faceplates = { "sherbet", "bookworm", "future_plate" } }, "faceplates").owned == 0)
		assert(Book.pageProgress({}, "nope").total == 0 and Book.pageProgress(nil, "balls").percent == 0)
		local h, db, c = fixture()
		edit(h, db, function(s) s.ballThemes.owned = { "smileys", "marbles", "future_a", "future_b" }; s.materialUnlocks = { metal = true } end)
		local writes = c.writes
		local ok, reason = H.bookClaim(h, "u-1", "balls.25", 5)
		assert(not ok and reason == "NotReached" and c.writes == writes, tostring(reason))
		ok, reason = H.bookClaim(h, "u-2", "toys.25", 5)
		assert(not ok and reason == "NotReached", tostring(reason))
	end)

	test("a milestone pays once: same op, another op, wrong reward and bad ids", function()
		local h, db, c = fixture()
		edit(h, db, function(st) st.book.found = allFound() end)
		local before = h.state.nectar
		assert(H.bookClaim(h, "p-1", "discoveries.25", 5))
		assert(h.state.nectar == before + 5)
		local writes = c.writes
		local ok, reason = H.bookClaim(h, "p-1", "discoveries.25", 5)
		assert(ok and reason == "AlreadyClaimed" and c.writes == writes and h.state.nectar == before + 5)
		ok, reason = H.bookClaim(h, "p-2", "discoveries.25")
		assert(ok and reason == "AlreadyClaimed" and c.writes == writes and h.state.nectar == before + 5)
		ok, reason = H.bookClaim(h, "p-3", "discoveries.50", 15); assert(not ok and reason == "RewardChanged", tostring(reason))
		ok, reason = H.bookClaim(h, "p-4", "discoveries.30", 5); assert(not ok and reason == "InvalidMilestone")
		ok, reason = H.bookClaim(h, "p-5", 25, 5); assert(not ok and reason == "InvalidMilestone")
		ok, reason = H.bookClaim(h, "", "discoveries.50", 5); assert(not ok and reason == "InvalidMilestone")
		assert(c.writes == writes and claimedCount(h, "discoveries.25") == 1 and H.valid(h.state))
	end)

	test("op-id retry after an ambiguous write and a replayed callback pay once; a reused id conflicts", function()
		local h, db, c = fixture()
		edit(h, db, function(st) st.book.found = allFound() end)
		local before = h.state.nectar
		c.failAfter = true
		local ok, reason = H.bookClaim(h, "r-1", "discoveries.50", 5)
		assert(not ok and reason == "Retrying" and db.player_1.hatching.nectar == before + 5)
		ok, reason = H.bookClaim(h, "r-1", "discoveries.50", 5)
		assert(ok and h.state.nectar == before + 5 and claimedCount(h, "discoveries.50") == 1, tostring(reason))
		c.replay = true
		assert(H.bookClaim(h, "r-2", "discoveries.75", 10))
		c.replay = false
		assert(h.state.nectar == before + 15 and db.player_1.hatching.nectar == before + 15 and claimedCount(h, "discoveries.75") == 1)
		assert(db.player_1.hatching.lastOperation.digest == "book:discoveries.75:10", "op id not bound to milestone + reward")
		local writes = c.writes
		ok, reason = H.bookClaim(h, "r-2", "discoveries.100", 15)
		assert(not ok and reason == "OperationConflict" and h.state.nectar == before + 15 and c.writes == writes, tostring(reason))
		assert(H.bookClaim(h, "r-3", "discoveries.100", 15) and h.state.nectar == before + 30)
	end)

	test("claims survive a page dropping below them (catalogue growth); nothing is clawed back", function()
		local h, db, _, adapter = fixture()
		fund(h, 100)
		assert(H.buyBallTheme(h, "g-2", "gumdrops", 20, false))
		assert(H.bookClaim(h, "s-1", "balls.25", 5))
		local balance = h.state.nectar
		-- Same effect as a larger catalogue: the page now reads below the claimed 25%.
		edit(h, db, function(s) s.ballThemes.owned = { "smileys", "marbles" }; table.insert(s.book.claimed, "stickers.25") end)
		assert(Book.pagePercent(h.state, "balls") == 0 and h.state.nectar == balance)
		local ok, reason = H.bookClaim(h, "s-2", "balls.25", 5)
		assert(ok and reason == "AlreadyClaimed" and h.state.nectar == balance)
		local row; for _, page in ipairs(H.public(h).book.pages) do if page.id == "balls" then row = page end end
		assert(row.milestones[1].claimed and not row.milestones[1].reached)
		assert(H.release(h))
		local again = H.load(1, { rank = 1 }, adapter)
		assert(again.status == "Ready" and table.find(again.state.book.claimed, "balls.25") and table.find(again.state.book.claimed, "stickers.25"),
			"an unknown later claim id must survive a load")
		assert(not table.find(H.public(again).book.claimable, "balls.25"))
	end)

	test("bookworm at three pages at 100%, once, equippable; Faceplates.apply never involved", function()
		local h, db = fixture()
		edit(h, db, function(s)
			s.ballThemes.owned = allPaidBalls()
			s.toyUnlocks = { ball = true, bone = true, sparkler = true }; s.materialUnlocks = { gloss = true, matte = true }
			s.book.found = allFound()
		end)
		local before = h.state.nectar
		assert(H.bookClaim(h, "w-1", "discoveries.100", 15)); assert(not Faceplates.owns(h.state, "bookworm"))
		assert(H.bookClaim(h, "w-2", "balls.100", 15)); assert(not Faceplates.owns(h.state, "bookworm"))
		assert(not H.public(h).book.faceplateEarned)
		assert(H.bookClaim(h, "w-3", "toys.100", 15))
		assert(Faceplates.owns(h.state, "bookworm") and H.public(h).book.faceplateEarned, "bookworm not granted at three pages")
		assert(h.state.nectar == before + 45, "the plate must cost nothing")
		assert(H.bookClaim(h, "w-4", "discoveries.75", 10))
		local count = 0; for _, id in ipairs(h.state.faceplates) do if id == "bookworm" then count += 1 end end
		assert(count == 1 and H.valid(h.state))
		assert(Appearance.canEquip("theme", "bookworm", Appearance.facts({}, H.public(h))))
	end)

	test("a missed grant repairs itself on any later claim, even of a claimed milestone", function()
		local h, db, c = fixture()
		edit(h, db, function(s) s.book.claimed = { "balls.100", "toys.100", "faceplates.100" }; s.faceplates = {} end)
		local balance = h.state.nectar
		-- Re-claiming a claimed milestone pays nothing but grants the owed plate.
		local ok, reason = H.bookClaim(h, "m-1", "toys.100", 15)
		assert(ok and reason == "Saved" and Faceplates.owns(h.state, "bookworm") and h.state.nectar == balance, tostring(reason))
		local writes = c.writes
		ok, reason = H.bookClaim(h, "m-2", "toys.100", 15)
		assert(ok and reason == "AlreadyClaimed" and c.writes == writes)
		-- A new claim repairs it as well (and pays).
		edit(h, db, function(s) s.faceplates = {}; s.book.found = allFound() end)
		assert(H.bookClaim(h, "m-3", "discoveries.25", 5))
		assert(Faceplates.owns(h.state, "bookworm") and h.state.nectar == balance + 5)
		-- Unknown ".100" ids never count toward the plate.
		assert(not Book.faceplateEarned({ "stickers.100", "hats.100", "balls.100" }))
	end)

	return cases
end
