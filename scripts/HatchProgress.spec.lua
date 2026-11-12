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

	-- v1 (one pet): formerly "active four outcomes normalize" over the Meadow odds.
	-- Meadow is retired, so it now offers no odds, no rare pool and cannot roll.
	test("v1 roster is Zivvi only and the retired Meadow egg offers no odds", function()
		local Pets=require(game.ReplicatedStorage.Shared.PetCatalog)
		assert(#Pets.active==1 and Pets.active[1].id=="pip" and Pets.isActive("pip"))
		for _,id in ipairs({"puddle","wick","orbit","bloom_pip","foxfire_wick","eclipse_orbit"})do assert(Pets.byId[id]and not Pets.isActive(id))end
		assert(Catalog.ById.meadow.retired and Catalog.ById.sprout.retired)
		assert(not Catalog.hasRarePool("meadow")and #Catalog.odds("sprout",7)==0)
		for misses=0,7 do
			assert(#Catalog.odds("meadow",misses)==0)
			assert(not pcall(Catalog.roll,"meadow",misses,.1))
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
		local nectar = h.state.nectar
		local ok, reason = Hatching.command(h, "hatch", "meadow", h.state.revision)
		assert(not ok and reason == "RetiredEgg" and h.state.nectar == nectar)
		-- The pending starter reveal still blocks another live award route.
		ok, reason = Hatching.awardPet(h, Hatching.petCandidate(h, "lease", "pip"))
		assert(not ok and reason == "RevealPending" and h.state.nectar == nectar)
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

	-- v1: formerly spent the full Meadow price and rejected a stale hatch. The
	-- retired egg is now refused before any write; stale/replayed commands are
	-- exercised through the still-live daily claim.
	test("retired egg never spends; stale commands and callback retries", function()
		local db, c, adapter = fixture()
		c.replay = true
		c.now = 18000 + 86400 * 20 + 86399
		local h = Hatching.load(1, { rank = 1 }, adapter("a"))
		local writes = c.updateCalls
		local ok, reason = Hatching.command(h, "hatch", "meadow", h.state.revision)
		assert(not ok and reason == "RetiredEgg" and c.randomCalls == 0 and c.updateCalls == writes)
		assert(Hatching.award(h, 1, 6) and Hatching.award(h, 2, 6))
		assert(h.state.nectar == 18)
		writes = c.updateCalls
		ok, reason = Hatching.command(h, "hatch", "meadow", h.state.revision)
		assert(not ok and reason == "RetiredEgg" and h.state.nectar == 18 and h.state.lastHatch == nil)
		assert(c.randomCalls == 0 and c.updateCalls == writes)
		c.now += 1
		local day = Hatching.public(h).dailyDay
		local revision = h.state.revision
		command(h, "daily", day)
		assert(h.state.nectar == 24 and db.player_1.hatching.nectar == 24)
		writes = c.updateCalls
		ok = Hatching.command(h, "daily", day, revision)
		assert(not ok and h.state.nectar == 24 and c.randomCalls == 0 and c.updateCalls == writes)
		assert(db.player_1.hatching.mastery.pip == 0)
	end)

	-- v1: formerly an ambiguous committed Meadow hatch; the same fenced
	-- resume guarantee is now checked with a daily claim.
	test("ambiguous committed daily claim cannot credit twice", function()
		local db, c, adapter = fixture()
		c.now = 18000 + 86400 * 20 + 86399
		local h = Hatching.load(1, { rank = 1 }, adapter("a"))
		assert(Hatching.award(h, 1, 6) and Hatching.award(h, 2, 6))
		c.now += 1
		local day = Hatching.public(h).dailyDay
		local revision = h.state.revision
		c.failAfterCommit = true
		local ok = Hatching.command(h, "daily", day, revision)
		assert(not ok and h.status == "Retrying")
		local committed = copy(db.player_1.hatching.lastOperation)
		assert(db.player_1.hatching.nectar == 24)
		ok = Hatching.command(h, "daily", day, revision)
		assert(ok and h.state.lastOperation.id == committed.id and h.state.nectar == 24)
		assert(h.state.dailyClaimDay == day and c.randomCalls == 0)
	end)

	-- v1: the pending reveal fixture is now the onboarding starter grant
	-- instead of a Meadow hatch.
	test("pre-commit starter, acknowledgement and daily failures resume unchanged", function()
		local db, c, adapter = fixture()
		local h = Hatching.load(1, {}, adapter("a"))
		local nectar = h.state.nectar
		c.failBeforeCommit = true
		assert(not Hatching.grantStarter(h))
		assert(h.status == "Retrying" and h.pending and not Catalog.isOwned(db.player_1.hatching.inventoryMask, "pip"))
		local pendingId = h.pending.id
		local hatchId = h.pending.candidate.id
		assert(Hatching.retry(h))
		assert(h.status == "Ready" and h.pending == nil and h.state.nectar == nectar)
		assert(h.state.lastOperation.id == pendingId and h.state.lastHatch.id == hatchId and h.state.lastHatch.starter)
		assert(h.state.lastHatch.petId == "pip" and h.state.mastery.pip == 0 and c.randomCalls == 0)
		local ok, reason = Hatching.retry(h)
		assert(not ok and reason == "NoPending" and h.state.nectar == nectar)
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
		assert(db.player_1.hatching.nectar == nectar and h.pending)
		pendingId = h.pending.id
		assert(Hatching.retry(h))
		assert(h.state.nectar == nectar + 6 and h.state.dailyClaimDay == day and h.state.lastOperation.id == pendingId)
		assert(not Hatching.command(h, "daily", day, h.state.revision))
		assert(h.state.nectar == nectar + 6 and c.randomCalls == 0)
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

	-- v1: formerly "every active outcome grants once" (Meadow outcome grants and
	-- frozen misses). The retired egg is refused with no debit, roll or grant,
	-- and earned misses survive reload untouched.
	test("retired Meadow egg is refused at any pity level with no state change", function()
		for misses=0,7 do
			local db,c,adapter=fixture();local h=Hatching.load(1,{rank=1},adapter("a"))
			db.player_1.hatching.misses=misses;assert(Hatching.renew(h))
			assert(Hatching.award(h,1,6)and Hatching.award(h,2,6));c.sample=.999
			local before,writes=copy(db.player_1.hatching),c.updateCalls
			local ok,reason=Hatching.command(h,"hatch","meadow",h.state.revision)
			assert(not ok and reason=="RetiredEgg"and c.randomCalls==0 and c.updateCalls==writes)
			assert(h.state.nectar==18 and h.state.lastHatch==nil and h.state.misses==misses and h.state.inventoryMask==before.inventoryMask)
			assert(db.player_1.hatching.revision==before.revision and db.player_1.hatching.nectar==18)
			assert(Hatching.release(h))
			local again=Hatching.load(1,{},adapter("b"));assert(again.state.misses==misses and again.state.nectar==18)
		end
	end)

	test("paid retired outcome receipts survive reload and acknowledge without reroll or regrant",function()
		for _,id in ipairs({"bloom_pip","foxfire_wick","eclipse_orbit"})do
			local db,c,adapter=fixture();local h=Hatching.load(1,{rank=1},adapter("a"));assert(Hatching.release(h))
			local saved=db.player_1.hatching
			saved.nectar=47;saved.misses=7;saved.inventoryMask=bit32.bor(saved.inventoryMask,Catalog.bit(id))
			saved.lastHatch={id="old-paid-"..id,petId=id,rare=true,duplicate=false,recipe="sprout",family=Catalog.family(id),mastery=0}
			local again=Hatching.load(1,{},adapter("b"));local receipt=again.state.lastHatch
			assert(again.status=="Ready"and receipt.id=="old-paid-"..id and receipt.petId==id and receipt.rare)
			local mask,random=again.state.inventoryMask,c.randomCalls
			command(again,"ack",receipt.id)
			assert(again.state.lastHatch==nil and again.state.nectar==47 and again.state.inventoryMask==mask and again.state.misses==7 and c.randomCalls==random)
			assert(not Hatching.command(again,"ack",receipt.id,again.state.revision))
		end
	end)

	local function runSummary(h, overrides)
		local summary = { family = "pip", day = Hatching.public(h).dailyDay, success = true,
			clean = true, score = 600, chain = 3, clears = 0, drops = 24 }
		for key, value in pairs(overrides or {}) do summary[key] = value end
		return summary
	end

	test("v2 mastery upgrade preserves marks, sparkles and all legacy fields", function()
		local db, _, adapter = fixture()
		local h = Hatching.load(1, { rank = 1 }, adapter("a"))
		assert(Hatching.release(h))
		local old = db.player_1.hatching
		old.version, old.mastery.pip, old.mastery.wick = 2, 3, 2
		for _,key in ipairs({"toyUnlocks","petToys","toyReceipts","toyReceiptOrder","toyReservation","pendingToyResult","lastToyResult","featureStock","petFeatures","featureReceipts","featureReceiptOrder","featureReservation","pendingFeatureResult","lastFeatureResult","materialUnlocks","petMaterials","materialReceipts","materialReceiptOrder","materialReservation","pendingMaterialResult","lastMaterialResult","hueInventory","petHues","hueItemReceipts","hueReceiptOrder","hueMigrationId","hueMigrationAcknowledged","legacyLastHueResult","legacyHueEgg","legacyHueRedemption","pendingHueResult","hueReservation"})do old[key]=nil end
		old.hueAssignments=nil;old.petDay,old.petCount,old.lastPetAward=nil,nil,nil -- Authentic pre-pet v2 input.
		old.masteryChallenges, old.masteryLegacyMask, old.contracts, old.totalWins = nil, nil, nil, nil
		db.player_1.keep, old.nectar = "untouched", 47
		h = Hatching.load(1, {}, adapter("b"))
		assert(h.status == "Ready" and h.state.version == 8 and h.state.nectar == 47)
		assert(h.state.petCount==0 and h.state.petDay==Hatching.public(h).dailyDay)
		local public = Hatching.public(h)
		assert(public.mastery.pip == 3 and public.mastery.wick == 2 and public.masteryLegacyMask == 1)
		assert(public.masteryRanks.pip == 1 and public.masteryRanks.wick == 0)
		assert(public.masteryChallenges.pip == 0 and public.totalWins == 0 and db.player_1.keep == "untouched")
		assert(Hatching.release(h))
		h = Hatching.load(1, {}, adapter("c"))
		assert(h.state.nectar == 47 and h.state.masteryLegacyMask == 1)
	end)

	test("saved wins preserve archived mastery points challenges and rank without promotions", function()
        local db, _, adapter = fixture()
        local h = Hatching.load(1, { rank = 1 }, adapter("a"))
        assert(Hatching.award(h, 1, 8, runSummary(h)))
        assert(h.state.mastery.pip == 0 and h.state.masteryChallenges.pip == 0 and h.state.totalWins == 1)
        db.player_1.hatching.mastery.pip, db.player_1.hatching.masteryChallenges.pip = 24, 6
        assert(Hatching.renew(h))
        assert(Hatching.public(h).masteryRanks.pip == 2)
        assert(Hatching.award(h, 2, 8, runSummary(h)))
        assert(h.state.mastery.pip == 24 and h.state.masteryChallenges.pip == 6 and Hatching.public(h).masteryRanks.pip == 2)
        assert(h.state.lastRunReward.promotedTo == 0 and h.state.lastRunReward.masteryPoints == 0)
    end)

	test("daily contracts and saved wins commit atomically once per run and day", function()
		local _, c, adapter = fixture()
		c.replay = true
		local h = Hatching.load(1, { rank = 1 }, adapter("a"))
		assert(Hatching.award(h, 1, 8, runSummary(h)))
		assert(h.state.nectar == 20 and h.state.lastRunReward.daily == 6 and h.state.lastRunReward.total == 14)
		assert(h.state.mastery.pip == 0 and h.state.totalWins == 1)
		assert(Hatching.award(h, 2, 8, runSummary(h)))
		assert(h.state.nectar == 32 and h.state.lastRunReward.daily == 4 and h.state.contracts.claimedMask == 7)
		assert(Hatching.award(h, 3, 8, runSummary(h)))
		assert(h.state.nectar == 40 and h.state.lastRunReward.daily == 0)
		assert(Hatching.award(h, 1, 8, runSummary(h)))
		assert(h.state.nectar == 40 and h.state.mastery.pip == 0 and h.state.totalWins == 3)
		local public = Hatching.public(h)
		assert(#public.contracts == 3 and public.contracts[1].claimed and public.contracts[1].progress == 2)
		public.contracts[1].progress, public.masteryDetails.pip.points = 0, 0
		assert(h.state.contracts.progress.runs == 2 and h.state.mastery.pip == 0)
	end)

	test("completed-budget failures can earn skill contracts but not mastery or free wins", function()
		local _, _, adapter = fixture()
		local h = Hatching.load(1, { rank = 1 }, adapter("a"))
		assert(Hatching.award(h, 1, 0, runSummary(h, { success = false, clean = false, drops = 3 })))
		assert(h.state.nectar == 6 and h.state.mastery.pip == 0 and h.state.contracts.claimedMask == 0)
		assert(Hatching.award(h, 2, 0, runSummary(h, { success = false, clean = false })))
		assert(h.state.nectar == 12 and h.state.mastery.pip == 0 and h.state.totalWins == 0)
		assert(h.state.contracts.progress.runs == 0 and h.state.contracts.claimedMask == 6)
	end)

	test("run start-day lock, daily rollover and rollback cannot reassign a contract", function()
		local _, c, adapter = fixture()
		c.now = 18000 + 86400 * 20 + 86390
		local h = Hatching.load(1, { rank = 1 }, adapter("a"))
		local oldRun = runSummary(h)
		c.now += 15
		assert(Hatching.award(h, 1, 8, oldRun))
		assert(h.state.nectar == 14 and h.state.contracts.claimedMask == 0)
		assert(Hatching.award(h, 2, 8, runSummary(h)))
		assert(h.state.nectar == 28 and h.state.contracts.day == "21")
		c.now -= 15
		assert(Hatching.award(h, 3, 8, runSummary(h)))
		assert(h.state.nectar == 36 and h.state.contracts.day == "21" and h.state.contracts.progress.runs == 1)
	end)

	test("compound award retries immutable stats and original day before or after commit", function()
		for _, failure in ipairs({ "failBeforeCommit", "failAfterCommit" }) do
			local db, c, adapter = fixture()
			c.now = 18000 + 86400 * 20 + 86390
			local h = Hatching.load(1, { rank = 1 }, adapter("a"))
			local summary = runSummary(h)
			c[failure] = true
			assert(not Hatching.award(h, 1, 8, summary))
			assert(db.player_1.hatching.nectar == (if failure == "failAfterCommit" then 20 else 6))
			summary.family, summary.score = "orbit", 0
			c.now += 15
			assert(Hatching.retry(h))
			assert(h.state.nectar == 20 and h.state.mastery.pip == 0 and h.state.mastery.orbit == 0)
			assert(h.state.contracts.day == "20" and h.state.contracts.claimedMask == 6 and h.state.totalWins == 1)
		end
	end)

	test("unowned family, malformed stats and mismatched payouts cannot alter a profile", function()
		local _, c, adapter = fixture()
		local h = Hatching.load(1, { rank = 1 }, adapter("a"))
		local writes = c.updateCalls
		assert(not Hatching.award(h, 1, 8, runSummary(h, { family = "orbit" })))
		assert(not Hatching.award(h, 1, 8, runSummary(h, { drops = 23 })))
		assert(not Hatching.award(h, 1, 8, runSummary(h, { score = 0 / 0 })))
		assert(not Hatching.award(h, 1, 6, runSummary(h)))
		assert(c.updateCalls == writes and h.state.nectar == 6 and h.state.mastery.pip == 0)
	end)

	-- v1: the duplicate half formerly hatched Meadow; the retired egg is now
	-- refused and the archived marks are checked unchanged.
	test("rare-only ownership earns saved wins and refused retired egg preserves archived marks", function()
		local db, c, adapter = fixture()
		local h = Hatching.load(1, { rank = 1 }, adapter("a"))
		db.player_1.hatching.inventoryMask = Catalog.bit("bloom_pip")
		assert(Hatching.renew(h))
		assert(Hatching.award(h, 1, 8, runSummary(h)))
		assert(h.state.mastery.pip == 0 and h.state.mastery.wick == 0)
		-- Restore Pip solely to test a duplicate result; no rank-based ownership is used.
		db.player_1.hatching.inventoryMask = bit32.bor(h.state.inventoryMask, Catalog.bit("pip"))
		db.player_1.hatching.mastery.pip = 3
		assert(Hatching.renew(h))
		c.sample = 0
		local nectar = h.state.nectar
		local ok, reason = Hatching.command(h, "hatch", "meadow", h.state.revision)
		assert(not ok and reason == "RetiredEgg" and h.state.lastHatch == nil and h.state.nectar == nectar)
		assert(h.state.mastery.pip == 3 and c.randomCalls == 0)
		assert(h.state.masteryLegacyMask == 0 and Hatching.public(h).masteryRanks.pip == 1)
	end)

	return { passed = #passed, cases = passed }
end
