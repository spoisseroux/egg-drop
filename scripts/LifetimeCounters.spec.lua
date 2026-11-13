-- Lifetime counters and discoveries (play-forever F1; BUILD-PLAN architect changes 4, 5):
-- `merges` and `itemsUsed` ride the server-built run summary into the fenced award, the
-- award validator refuses NaN / fractional / negative / oversized values (so a bad value
-- can never fail valid() and lose a round's Stars), discoveries are OR-ed into
-- book.found as bits 0..30 only (bit 31 would fail valid()), counters stay capped, and
-- `pets` keeps meaning pets hatched. Isolated adapters only; no DataStore or user writes.
-- Usage (Server): require(ServerScriptService.Server.ZZSpecs.LifetimeCounters)(ServerScriptService.Server)
return function(server)
	local H = require(server.HatchProgress)
	local L = require(server.LifetimeState)
	local Shared = game:GetService("ReplicatedStorage").Shared
	local Book = require(Shared.BookCatalog)
	local Daily = require(Shared.DailyContracts)
	local cases = {}
	local function copy(v) if type(v) ~= "table" then return v end; local r = {}; for k, x in pairs(v) do r[k] = copy(x) end; return r end
	local function test(name, run) run(); table.insert(cases, name) end
	local function fixture(profile)
		local db, c = {}, { now = 1700000000, serial = 0, writes = 0 }
		local adapter = {
			now = function() return c.now end,
			guid = function() c.serial += 1; return "op" .. c.serial end,
			random = function() return .1 end,
			wait = function() end,
			update = function(key, transform)
				c.writes += 1
				local value = transform(copy(db[key]))
				if value then db[key] = copy(value) end
				return copy(value)
			end,
		}
		local h = H.load(1, profile or { rank = 1 }, adapter)
		assert(h.status == "Ready", "fixture load " .. tostring(h.status))
		return h, db, c
	end
	local seq = 0
	local function summary(fields)
		local s = { family = "pip", day = tostring(Daily.dayOf(1700000000)), success = false, clean = false, score = 100,
			chain = 1, clears = 0, drops = 10, heat = "medium", maxTier = 2, goalsMet = 0, templateId = "bank_pair", merges = 0, itemsUsed = 0 }
		for key, value in pairs(fields or {}) do s[key] = value end
		if s.success then s.drops = 24 end
		return s
	end
	local function award(h, fields)
		seq += 1
		local s = summary(fields)
		local amount = if s.success then (if s.clean then 8 else 6) else 0
		return H.award(h, seq, amount, s, {})
	end
	local function bit(n) return bit32.lshift(1, n) end

	test("merges and itemsUsed from the run summary are written inside the award and add up", function()
		seq = 0
		local h, db = fixture()
		assert(award(h, { merges = 7, itemsUsed = 2 }))
		assert(award(h, { merges = 5, itemsUsed = 0, success = true }))
		local s = h.state.stats
		assert(s.merges == 12 and s.itemsUsed == 2 and s.rounds == 2, string.format("merges %d items %d", s.merges, s.itemsUsed))
		assert(db.player_1.hatching.stats.merges == 12 and db.player_1.hatching.stats.itemsUsed == 2)
		assert(s.parkGames == 0, "parkGames has no source yet")
		assert(H.public(h).stats.merges == 12 and H.public(h).stats.parkGames == nil, "public stats hide parkGames")
		-- An older summary without the fields still saves (counters unchanged).
		local old = summary(); old.merges, old.itemsUsed = nil, nil; seq += 1
		assert(H.award(h, seq, 0, old, {}))
		assert(h.state.stats.merges == 12 and h.state.stats.rounds == 3)
	end)

	test("NaN, fractional, negative and oversized counters are refused before any write", function()
		seq = 0
		local h, _, c = fixture()
		local before, writes = copy(h.state.stats), c.writes
		for _, bad in ipairs({ { merges = 0 / 0 }, { merges = 1.5 }, { merges = -1 }, { merges = L.RunMerges + 1 }, { merges = math.huge },
			{ itemsUsed = 0 / 0 }, { itemsUsed = L.RunItems + 1 }, { itemsUsed = "2" }, { merges = "3" } }) do
			local ok, reason = award(h, bad)
			assert(not ok and reason == "InvalidSummary", "accepted " .. tostring(next(bad)) .. " " .. tostring(reason))
		end
		assert(c.writes == writes and h.state.stats.merges == before.merges and h.state.stats.itemsUsed == before.itemsUsed)
		assert(award(h, { merges = L.RunMerges, itemsUsed = L.RunItems }), "the bounds themselves are accepted")
		assert(H.valid(h.state))
	end)

	test("discoveries: tier V, chain 5, a win per field template and per difficulty set fixed bits", function()
		seq = 0
		local h = fixture()
		assert(award(h, { maxTier = 5, chain = 5, success = false, templateId = "lantern_chain", heat = "hard" }))
		local found = h.state.book.found
		assert(found == bit(0) + bit(1), "a lost round sets only tier V and chain 5: " .. found)
		assert(award(h, { success = true, templateId = "lantern_chain", heat = "hard" }))
		assert(h.state.book.found == bit(0) + bit(1) + bit(Book.DiscoveryById.win_lantern_chain.bit) + bit(Book.DiscoveryById.win_hard.bit))
		assert(award(h, { success = true, clean = true, templateId = "nope", heat = "easy" }), "an unknown template still saves")
		assert(bit32.band(h.state.book.found, bit(Book.DiscoveryById.win_easy.bit)) ~= 0)
		-- Every discovery is reachable from a round, and the Discoveries page reads the bits.
		for _, template in ipairs(require(Shared.FieldObjectives).Order) do assert(award(h, { success = true, templateId = template })) end
		assert(award(h, { success = true, heat = "medium" }))
		local page = Book.pageProgress(h.state, "discoveries")
		assert(page.owned == page.total and page.percent == 100, page.owned .. "/" .. page.total)
		for _, entry in ipairs(Book.Discoveries) do assert(entry.bit >= 0 and entry.bit <= 30, entry.id) end
	end)

	test("found stays within bits 0..30: bit 31 and junk are ignored, a full mask stays valid", function()
		local state = { book = L.freshBook() }
		L.setFound(state, 2 ^ 31); assert(state.book.found == 0, "bit 31 written")
		L.setFound(state, 0 / 0); L.setFound(state, -4); L.setFound(state, math.huge); assert(state.book.found == 0)
		L.setFound(state, 2 ^ 31 + 4); assert(state.book.found == 4)
		seq = 0
		local h, db = fixture()
		db.player_1.hatching.book.found = 2 ^ 31 - 1
		assert(H.renew(h))
		assert(award(h, { maxTier = 5, chain = 9, success = true, templateId = "bank_pair", heat = "hard" }))
		assert(h.state.book.found == 2 ^ 31 - 1 and H.valid(h.state))
	end)

	test("counters cap at LifetimeState.Cap; bestChain keeps the maximum", function()
		seq = 0
		local h, db = fixture()
		db.player_1.hatching.stats.merges = L.Cap - 3
		db.player_1.hatching.stats.itemsUsed = L.Cap
		assert(H.renew(h))
		assert(award(h, { merges = 50, itemsUsed = 3, chain = 4 }))
		assert(h.state.stats.merges == L.Cap and h.state.stats.itemsUsed == L.Cap and H.valid(h.state))
		assert(award(h, { chain = 2 }))
		assert(h.state.stats.bestChain == 4)
	end)

	test("pets stays pets hatched: the starter grant counts one, petting adds none", function()
		local h = fixture({})
		assert(h.state.stats.pets == 0)
		assert(H.grantStarter(h))
		assert(h.state.stats.pets == 1, "starter not counted")
		assert(H.command(h, "ack", h.state.lastHatch.id, h.state.revision))
		local ok = H.awardPet(h, H.petCandidate(h, "lease-1", "pip"))
		assert(ok and h.state.stats.pets == 1, "petting counted as a pet")
	end)

	return cases
end
