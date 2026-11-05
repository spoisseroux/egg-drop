-- Execute this returned function with the actual HatchProgress and
-- EggCatalog modules. No Roblox DataStore or live user profile is changed.
return function(Hatching, Catalog)
	local passed = {}
	local function copy(value)
		if type(value) ~= "table" then return value end
		local result = {}
		for key, item in pairs(value) do result[key] = copy(item) end
		return result
	end
	local function fixture(initial)
		local db = initial or {}
		local control = { now = 1000, serial = 0, randomCalls = 0, updateCalls = 0, sample = 0.1, replay = false, failAfterCommit = false }
		local function adapter(label)
			return {
				now = function() return control.now end,
				guid = function() control.serial += 1; return label .. "-" .. control.serial end,
				random = function() control.randomCalls += 1; return control.sample end,
				update = function(key, transform)
					control.updateCalls += 1
					if control.failBeforeCommit then
						control.failBeforeCommit = false
						error("Expected fixture: connection lost before commit")
					end
					if control.beforeUpdate then
						local callback = control.beforeUpdate
						control.beforeUpdate = nil
						callback()
					end
					local output = transform(copy(db[key]))
					if control.replay then output = transform(copy(db[key])) end
					if output ~= nil then db[key] = copy(output) end
					if control.failAfterCommit then
						control.failAfterCommit = false
						error("Expected fixture: connection lost after commit")
					end
					return copy(output)
				end,
			}
		end
		return db, control, adapter
	end
	local function command(handle, action, value)
		local ok, reason = Hatching.command(handle, action, value, handle.state.revision)
		assert(ok, action .. " failed: " .. tostring(reason))
	end
	local function test(name, callback)
		callback()
		table.insert(passed, name)
	end

	test("all catalog outcomes and rare protection", function()
		for index, unit in ipairs({ 0, 0.35, 0.60, 0.80, 0.90, 0.95, 0.98 }) do
			assert(Catalog.roll("meadow", 0, unit) == Catalog.ById.meadow.weights[index].id)
		end
		assert(Catalog.roll("meadow", 7, 0) == "bloom_pip")
		assert(Catalog.roll("meadow", 7, 0.50) == "foxfire_wick")
		assert(Catalog.roll("meadow", 7, 0.80) == "eclipse_orbit")
		assert(Catalog.roll("sprout", 7, 0.999) == "bloom_pip")
		for _, recipe in ipairs(Catalog.Order) do
			for _, misses in ipairs({ 0, 7 }) do
				local sum = 0
				for _, entry in ipairs(Catalog.odds(recipe, misses)) do sum += entry.weight end
				assert(math.abs(sum - 100) < 0.000001)
			end
		end
	end)

	test("legacy seven-pet migration and one-time credits", function()
		local db, _, adapter = fixture({ player_1 = { rank = 4, trials = 7, rareTrials = 24, bestScore = 900, keep = "preserved" } })
		local handle = Hatching.load(1, {}, adapter("a"))
		assert(handle.status == "Ready" and handle.state.inventoryMask == 127 and handle.state.nectar == 6)
		assert(db.player_1.keep == "preserved" and db.player_1.bestScore == 900)
		assert(Hatching.release(handle))
		local again = Hatching.load(1, {}, adapter("b"))
		assert(again.state.nectar == 6 and again.state.inventoryMask == 127)
		local partial = Hatching.load(2, { rank = 0, charge = 5 }, adapter("c"))
		assert(partial.state.nectar == 11)
	end)

	test("starter grant, persistent reveal, exact acknowledgement", function()
		local _, _, adapter = fixture()
		local h = Hatching.load(1, {}, adapter("a"))
		assert(Hatching.grantStarter(h))
		assert(h.state.inventoryMask == Catalog.bit("pip") and h.state.lastHatch.starter)
		local id = h.state.lastHatch.id
		assert(Hatching.grantStarter(h))
		assert(h.state.lastHatch.id == id)
		local ok = Hatching.command(h, "hatch", "meadow", h.state.revision)
		assert(not ok)
		ok = Hatching.command(h, "ack", "wrong-id", h.state.revision)
		assert(not ok and h.state.lastHatch.id == id)
		command(h, "ack", id)
		assert(h.state.lastHatch == nil)
	end)

	test("ambiguous session acquire resumes the same lease", function()
		local db, c, adapter = fixture()
		c.failAfterCommit = true
		local h = Hatching.load(1, { rank = 1 }, adapter("a"))
		assert(h.status == "Ready" and h.state.epoch == 1 and h.state.nectar == 6)
		assert(db.player_1.hatching.lease.token == h.token)
	end)

	test("direct full-cost spending, stale commands and callback retries", function()
		local db, c, adapter = fixture()
		c.replay = true
		local h = Hatching.load(1, { rank = 1 }, adapter("a"))
		local writes = c.updateCalls
		local ok, reason = Hatching.command(h, "hatch", "meadow", h.state.revision)
		assert(not ok and reason == "NeedNectar" and c.randomCalls == 0 and c.updateCalls == writes)
		assert(Hatching.award(h, 1, 6) and Hatching.award(h, 2, 6))
		assert(h.state.nectar == 18)
		local revision = h.state.revision
		command(h, "hatch", "meadow")
		assert(h.state.nectar == 0 and h.state.lastHatch.petId == "pip" and h.state.lastHatch.duplicate)
		assert(h.state.mastery.pip == 1 and c.randomCalls == 1)
		writes = c.updateCalls
		ok = Hatching.command(h, "hatch", "meadow", revision)
		assert(not ok and h.state.nectar == 0 and c.randomCalls == 1 and c.updateCalls == writes)
		assert(db.player_1.hatching.mastery.pip == 1)
	end)

	test("ambiguous committed hatch cannot reroll or duplicate", function()
		local db, c, adapter = fixture()
		local h = Hatching.load(1, { rank = 1 }, adapter("a"))
		assert(Hatching.award(h, 1, 6) and Hatching.award(h, 2, 6))
		local id = "meadow"
		local revision = h.state.revision
		c.failAfterCommit = true
		local ok = Hatching.command(h, "hatch", id, revision)
		assert(not ok and h.status == "Retrying")
		local committed = copy(db.player_1.hatching.lastHatch)
		c.sample = 0.999
		ok = Hatching.command(h, "hatch", id, revision)
		assert(ok and h.state.lastHatch.id == committed.id and h.state.lastHatch.petId == "pip")
		assert(h.state.mastery.pip == 1 and c.randomCalls == 1)
	end)

	test("pre-commit hatch, acknowledgement and daily failures resume unchanged", function()
		local db, c, adapter = fixture()
		local h = Hatching.load(1, { rank = 1 }, adapter("a"))
		assert(Hatching.award(h, 1, 6) and Hatching.award(h, 2, 6))
		c.failBeforeCommit = true
		assert(not Hatching.command(h, "hatch", "meadow", h.state.revision))
		assert(h.status == "Retrying" and h.pending and db.player_1.hatching.nectar == 18)
		local pendingId = h.pending.id
		local hatchId = h.pending.candidate.id
		c.sample = 0.999
		assert(Hatching.retry(h))
		assert(h.status == "Ready" and h.pending == nil and h.state.nectar == 0)
		assert(h.state.lastOperation.id == pendingId and h.state.lastHatch.id == hatchId)
		assert(h.state.lastHatch.petId == "pip" and h.state.mastery.pip == 1 and c.randomCalls == 1)
		local ok, reason = Hatching.retry(h)
		assert(not ok and reason == "NoPending" and h.state.nectar == 0)
		c.failBeforeCommit = true
		assert(not Hatching.command(h, "ack", hatchId, h.state.revision))
		assert(db.player_1.hatching.lastHatch.id == hatchId)
		pendingId = h.pending.id
		assert(Hatching.retry(h))
		assert(h.state.lastHatch == nil and h.state.lastOperation.id == pendingId)
		assert(Hatching.release(h))
		c.now += 86400
		h = Hatching.load(1, {}, adapter("b"))
		local day = Hatching.public(h).dailyDay
		c.failBeforeCommit = true
		assert(not Hatching.command(h, "daily", day, h.state.revision))
		assert(db.player_1.hatching.nectar == 0 and h.pending)
		pendingId = h.pending.id
		assert(Hatching.retry(h))
		assert(h.state.nectar == 6 and h.state.dailyClaimDay == day and h.state.lastOperation.id == pendingId)
		assert(not Hatching.command(h, "daily", day, h.state.revision))
		assert(h.state.nectar == 6 and c.randomCalls == 1)
	end)

	test("monotonic payouts reject replay beyond receipt history", function()
		local _, _, adapter = fixture()
		local h = Hatching.load(1, { rank = 1 }, adapter("a"))
		for sequence = 1, 300 do assert(Hatching.award(h, sequence, 6)) end
		local nectar = h.state.nectar
		assert(Hatching.award(h, 1, 8))
		assert(h.state.nectar == nectar and h.state.lastAwardSeq == 300)
	end)

	test("lease takeover fences stale commands and renewals", function()
		local db, c, adapter = fixture()
		local old = Hatching.load(1, { rank = 1 }, adapter("a"))
		local blocked = Hatching.load(1, {}, adapter("b"))
		assert(blocked.status == "Locked")
		c.now += Hatching.LeaseSeconds + 1
		local current = Hatching.load(1, {}, adapter("c"))
		assert(current.status == "Ready" and current.state.epoch > old.state.epoch)
		assert(not Hatching.renew(old))
		assert(not Hatching.award(old, 1, 8))
		assert(db.player_1.hatching.lease.token == current.token and db.player_1.hatching.nectar == 6)
	end)

	test("local overlap, sparse inventory and public isolation", function()
		local db, c, adapter = fixture()
		local h = Hatching.load(1, { rank = 1 }, adapter("a"))
		c.beforeUpdate = function() assert(not Hatching.award(h, 2, 6)) end
		assert(Hatching.award(h, 1, 6))
		assert(h.state.nectar == 12)
		db.player_1.hatching.inventoryMask = Catalog.bit("orbit")
		assert(Hatching.renew(h))
		local public = Hatching.public(h)
		assert(Catalog.isOwned(public.inventoryMask, "orbit") and not Catalog.isOwned(public.inventoryMask, "wick"))
		assert(public.lease == nil and public.token == nil)
		public.mastery.pip = 3
		assert(h.state.mastery.pip == 0)
	end)

	test("failed legacy load cannot spend or overwrite", function()
		local db, _, adapter = fixture()
		local h = Hatching.load(1, { loadFailed = true }, adapter("a"))
		assert(h.status == "Temporary")
		assert(not Hatching.grantStarter(h))
		assert(not Hatching.award(h, 1, 8))
		assert(db.player_1 == nil)
	end)
	test("daily reward is once per Hollow day and survives callback retry", function()
		local db, c, adapter = fixture()
		c.now = 18000 + 86400 * 20 + 86399
		c.replay = true
		local h = Hatching.load(1, { rank = 1 }, adapter("a"))
		local p = Hatching.public(h)
		assert(not p.dailyAvailable and p.dailyDay == "20" and p.dailyBonus == 6)
		assert(not Hatching.command(h, "daily", p.dailyDay, h.state.revision))
		c.now += 1
		p = Hatching.public(h)
		assert(p.dailyAvailable and p.dailyDay == "21")
		local revision = h.state.revision
		command(h, "daily", p.dailyDay)
		assert(h.state.nectar == 12 and db.player_1.hatching.nectar == 12)
		assert(not Hatching.command(h, "daily", p.dailyDay, revision))
		assert(not Hatching.command(h, "daily", p.dailyDay, h.state.revision))
		assert(not Hatching.public(h).dailyAvailable)
		c.now += 86400
		assert(not Hatching.command(h, "daily", "21", h.state.revision))
		assert(not Hatching.renew(h))
		local nextVisit = Hatching.load(1, {}, adapter("b"))
		command(nextVisit, "daily", "22")
		assert(nextVisit.state.nectar == 18)
		c.now -= 86400
		assert(not Hatching.public(nextVisit).dailyAvailable)
		assert(not Hatching.command(nextVisit, "daily", "21", nextVisit.state.revision))
		assert(nextVisit.state.nectar == 18)
	end)

	test("every advertised result grants once and rare protection resets", function()
		for index, sample in ipairs({ 0, 0.35, 0.60, 0.80, 0.90, 0.95, 0.98 }) do
			local _, c, adapter = fixture()
			c.sample = sample
			local h = Hatching.load(1, { rank = 1 }, adapter("a"))
			assert(Hatching.award(h, 1, 6) and Hatching.award(h, 2, 6))
			command(h, "hatch", "meadow")
			local expected = Catalog.ById.meadow.weights[index].id
			assert(h.state.lastHatch.petId == expected and Catalog.isOwned(h.state.inventoryMask, expected))
			assert(h.state.nectar == 0)
		end
		local db, c, adapter = fixture()
		local h = Hatching.load(1, { rank = 1 }, adapter("a"))
		db.player_1.hatching.misses = 7
		assert(Hatching.renew(h))
		assert(Hatching.award(h, 1, 6) and Hatching.award(h, 2, 6) and Hatching.award(h, 3, 6))
		c.sample = 0.01
		command(h, "hatch", "sprout")
		assert(h.state.lastHatch.petId == "bloom_pip" and h.state.lastHatch.rare and h.state.misses == 0)
	end)

	return { passed = #passed, cases = passed }
end
