-- Stamp card (play-forever F1; BUILD-PLAN architect change 2): the `daily` action stays
-- `daily` (same gate, dailyClaimDay), pays StampCard.reward(stamps) and adds one stamp.
-- Rewards cycle 4,4,5,5,6,6,12 (42 a week, as the old 6 x 7), one stamp per Hollow day,
-- the count never resets (a missed day costs nothing), a stale day is DayChanged, and an
-- ambiguous write pays once. Isolated adapters only; no DataStore or user writes.
-- Usage (Server): require(ServerScriptService.Server.ZZSpecs.StampCard)(ServerScriptService.Server)
return function(server)
	local H = require(server.HatchProgress)
	local Stamp = require(game:GetService("ReplicatedStorage").Shared.StampCard)
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
	-- A day later the lease has long expired, so a new day is a new session (release, reload).
	local function nextDay(h, c, adapter, days)
		assert(H.release(h))
		c.now += 86400 * (days or 1)
		local again = H.load(1, { rank = 1 }, adapter)
		assert(again.status == "Ready", "reload " .. tostring(again.status))
		return again
	end
	local function claim(h)
		local day = H.public(h).dailyDay
		return H.command(h, "daily", day, h.state.revision)
	end

	test("catalogue: rewards 4,4,5,5,6,6,12 = 42 a week; reward(stamps) is the stamp being added", function()
		assert(table.concat(Stamp.Rewards, ",") == "4,4,5,5,6,6,12" and Stamp.Length == 7)
		local week = 0; for _, n in ipairs(Stamp.Rewards) do week += n end; assert(week == 42)
		for stamps = 0, 20 do assert(Stamp.reward(stamps) == Stamp.Rewards[stamps % 7 + 1], stamps) end
		assert(Stamp.reward(-3) == 4 and Stamp.reward(0 / 0) == 4 and Stamp.reward(1.5) == 4, "junk counts read as 0")
		assert(Stamp.onCard(9) == 2 and Stamp.position(6) == 7)
	end)

	test("one stamp per day; the snapshot shows today's reward, stamps and the card", function()
		local h, db, c, adapter = fixture()
		local p = H.public(h)
		assert(not p.dailyAvailable and p.dailyBonus == 4 and p.stamps == 0 and p.stampReward == 4, "load day already counts as claimed")
		assert(table.concat(p.stampCard.rewards, ",") == "4,4,5,5,6,6,12" and p.stampCard.onCard == 0 and p.stampCard.next == 1)
		h = nextDay(h, c, adapter)
		local before = h.state.nectar
		assert(H.public(h).dailyAvailable)
		assert(claim(h))
		assert(h.state.nectar == before + 4 and h.state.stamps == 1 and db.player_1.hatching.stamps == 1)
		local writes = c.writes
		local ok, reason = claim(h)
		assert(not ok and reason == "DailyClaimed" and h.state.stamps == 1 and c.writes == writes, tostring(reason))
		p = H.public(h)
		assert(not p.dailyAvailable and p.dailyBonus == 4 and p.stamps == 1 and p.stampDay == h.state.dailyClaimDay)
		assert(c.rolls == 0, "a stamp drew a random number")
	end)

	test("rewards cycle 4,4,5,5,6,6,12 then start over; Stars earned counted", function()
		local h, _, c, adapter = fixture()
		local paid = {}
		local earned = h.state.stats.starsEarned
		for _ = 1, 9 do
			h = nextDay(h, c, adapter)
			local before = h.state.nectar
			assert(H.public(h).dailyBonus == Stamp.reward(h.state.stamps))
			assert(claim(h))
			table.insert(paid, h.state.nectar - before)
		end
		assert(table.concat(paid, ",") == "4,4,5,5,6,6,12,4,4", table.concat(paid, ","))
		assert(h.state.stamps == 9 and h.state.stats.starsEarned == earned + 50)
	end)

	test("missed days never reset the count; a reload keeps it", function()
		local h, db, c, adapter = fixture()
		for _ = 1, 3 do h = nextDay(h, c, adapter); assert(claim(h)) end
		assert(h.state.stamps == 3)
		h = nextDay(h, c, adapter, 5) -- five days away
		local before = h.state.nectar
		assert(claim(h))
		assert(h.state.stamps == 4 and h.state.nectar == before + 5, "the 4th stamp pays 5 after a gap")
		local again = nextDay(h, c, adapter)
		assert(again.state.stamps == 4 and db.player_1.hatching.stamps == 4)
		before = again.state.nectar
		assert(claim(again) and again.state.stamps == 5 and again.state.nectar == before + 6)
	end)

	test("a stale day is DayChanged with no write; the client refreshes and claims", function()
		local h, _, c, adapter = fixture()
		local stale = H.public(h).dailyDay
		h = nextDay(h, c, adapter)
		local writes, before = c.writes, h.state.nectar
		local ok, reason = H.command(h, "daily", stale, h.state.revision)
		assert(not ok and reason == "DayChanged" and c.writes == writes and h.state.nectar == before and h.state.stamps == 0, tostring(reason))
		assert(claim(h) and h.state.stamps == 1)
	end)

	test("an ambiguous write or a replayed callback adds one stamp and pays once", function()
		local h, db, c, adapter = fixture()
		h = nextDay(h, c, adapter)
		local before = h.state.nectar
		local day, revision = H.public(h).dailyDay, h.state.revision
		c.failAfter = true
		local ok, reason = H.command(h, "daily", day, revision)
		assert(not ok and reason == "Retrying" and db.player_1.hatching.stamps == 1)
		ok = H.command(h, "daily", day, revision)
		assert(ok and h.state.stamps == 1 and h.state.nectar == before + 4 and db.player_1.hatching.nectar == before + 4)
		h = nextDay(h, c, adapter)
		c.replay = true
		assert(claim(h))
		c.replay = false
		assert(h.state.stamps == 2 and db.player_1.hatching.stamps == 2 and h.state.nectar == before + 8)
	end)

	return cases
end
