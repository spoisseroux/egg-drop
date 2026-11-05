-- Execute this returned function with the actual NurseryProgress and
-- NurseryCatalog modules. No Roblox DataStore or live user profile is changed.
return function(Nursery, Catalog)
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
		local ok, reason = Nursery.command(handle, action, value, handle.state.revision)
		assert(ok, action .. " failed: " .. tostring(reason))
	end
	local function readyEgg(handle, recipe)
		command(handle, "start", recipe)
		local id = handle.state.project.id
		while not handle.state.project.ready do
			if handle.state.project.needsCare then command(handle, "care", id)
			else command(handle, "fund", id) end
		end
		return id
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
		local handle = Nursery.load(1, {}, adapter("a"))
		assert(handle.status == "Ready" and handle.state.inventoryMask == 127 and handle.state.nectar == 6)
		assert(db.player_1.keep == "preserved" and db.player_1.bestScore == 900)
		assert(Nursery.release(handle))
		local again = Nursery.load(1, {}, adapter("b"))
		assert(again.state.nectar == 6 and again.state.inventoryMask == 127)
		local partial = Nursery.load(2, { rank = 0, charge = 5 }, adapter("c"))
		assert(partial.state.nectar == 11)
	end)

	test("starter grant, persistent reveal, exact acknowledgement", function()
		local _, _, adapter = fixture()
		local h = Nursery.load(1, {}, adapter("a"))
		assert(Nursery.grantStarter(h))
		assert(h.state.inventoryMask == Catalog.bit("pip") and h.state.lastHatch.starter)
		local id = h.state.lastHatch.id
		assert(Nursery.grantStarter(h))
		assert(h.state.lastHatch.id == id)
		local ok = Nursery.command(h, "start", "meadow", h.state.revision)
		assert(not ok)
		ok = Nursery.command(h, "ack", "wrong-id", h.state.revision)
		assert(not ok and h.state.lastHatch.id == id)
		command(h, "ack", id)
		assert(h.state.lastHatch == nil)
	end)

	test("ambiguous session acquire resumes the same lease", function()
		local db, c, adapter = fixture()
		c.failAfterCommit = true
		local h = Nursery.load(1, { rank = 1 }, adapter("a"))
		assert(h.status == "Ready" and h.state.epoch == 1 and h.state.nectar == 6)
		assert(db.player_1.nursery.lease.token == h.token)
	end)

	test("stage spending, stale commands and callback retries", function()
		local db, c, adapter = fixture()
		c.replay = true
		local h = Nursery.load(1, { rank = 1 }, adapter("a"))
		assert(Nursery.award(h, 1, 6) and Nursery.award(h, 2, 6))
		assert(h.state.nectar == 18)
		local revision = h.state.revision
		command(h, "start", "meadow")
		local id = h.state.project.id
		local writes = c.updateCalls
		local ok = Nursery.command(h, "start", "meadow", revision)
		assert(not ok and h.state.nectar == 12)
		ok = Nursery.command(h, "fund", id, h.state.revision)
		assert(not ok and h.state.nectar == 12 and c.updateCalls == writes)
		command(h, "care", id); command(h, "fund", id)
		command(h, "care", id); command(h, "fund", id); command(h, "care", id)
		assert(h.state.nectar == 0 and h.state.project.ready)
		command(h, "hatch", id)
		assert(h.state.lastHatch.petId == "pip" and h.state.lastHatch.duplicate)
		assert(h.state.mastery.pip == 1 and c.randomCalls == 1)
		assert(db.player_1.nursery.mastery.pip == 1)
	end)

	test("ambiguous committed hatch cannot reroll or duplicate", function()
		local db, c, adapter = fixture()
		local h = Nursery.load(1, { rank = 1 }, adapter("a"))
		assert(Nursery.award(h, 1, 6) and Nursery.award(h, 2, 6))
		local id = readyEgg(h, "meadow")
		local revision = h.state.revision
		c.failAfterCommit = true
		local ok = Nursery.command(h, "hatch", id, revision)
		assert(not ok and h.status == "Retrying")
		local committed = copy(db.player_1.nursery.lastHatch)
		c.sample = 0.999
		ok = Nursery.command(h, "hatch", id, revision)
		assert(ok and h.state.lastHatch.id == committed.id and h.state.lastHatch.petId == "pip")
		assert(h.state.mastery.pip == 1 and c.randomCalls == 1)
	end)

	test("monotonic payouts reject replay beyond receipt history", function()
		local _, _, adapter = fixture()
		local h = Nursery.load(1, { rank = 1 }, adapter("a"))
		for sequence = 1, 300 do assert(Nursery.award(h, sequence, 6)) end
		local nectar = h.state.nectar
		assert(Nursery.award(h, 1, 8))
		assert(h.state.nectar == nectar and h.state.lastAwardSeq == 300)
	end)

	test("lease takeover fences stale commands and renewals", function()
		local db, c, adapter = fixture()
		local old = Nursery.load(1, { rank = 1 }, adapter("a"))
		local blocked = Nursery.load(1, {}, adapter("b"))
		assert(blocked.status == "Locked")
		c.now += Nursery.LeaseSeconds + 1
		local current = Nursery.load(1, {}, adapter("c"))
		assert(current.status == "Ready" and current.state.epoch > old.state.epoch)
		assert(not Nursery.renew(old))
		assert(not Nursery.award(old, 1, 8))
		assert(db.player_1.nursery.lease.token == current.token and db.player_1.nursery.nectar == 6)
	end)

	test("local overlap, sparse inventory and public isolation", function()
		local db, c, adapter = fixture()
		local h = Nursery.load(1, { rank = 1 }, adapter("a"))
		c.beforeUpdate = function() assert(not Nursery.award(h, 2, 6)) end
		assert(Nursery.award(h, 1, 6))
		assert(h.state.nectar == 12)
		db.player_1.nursery.inventoryMask = Catalog.bit("orbit")
		assert(Nursery.renew(h))
		local public = Nursery.public(h)
		assert(Catalog.isOwned(public.inventoryMask, "orbit") and not Catalog.isOwned(public.inventoryMask, "wick"))
		assert(public.lease == nil and public.token == nil)
		public.mastery.pip = 3
		assert(h.state.mastery.pip == 0)
	end)

	test("failed legacy load cannot spend or overwrite", function()
		local db, _, adapter = fixture()
		local h = Nursery.load(1, { loadFailed = true }, adapter("a"))
		assert(h.status == "Temporary")
		assert(not Nursery.grantStarter(h))
		assert(not Nursery.award(h, 1, 8))
		assert(db.player_1 == nil)
	end)
	return { passed = #passed, cases = passed }
end
