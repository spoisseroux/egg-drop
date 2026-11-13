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
		assert(h.state.nectar == 22 and db.player_1.hatching.nectar == 22)
		writes = c.updateCalls
		ok = Hatching.command(h, "daily", day, revision)
		assert(not ok and h.state.nectar == 22 and c.randomCalls == 0 and c.updateCalls == writes)
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
		assert(db.player_1.hatching.nectar == 22)
		ok = Hatching.command(h, "daily", day, revision)
		assert(ok and h.state.lastOperation.id == committed.id and h.state.nectar == 22)
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
		assert(h.state.nectar == nectar + 4 and h.state.dailyClaimDay == day and h.state.lastOperation.id == pendingId)
		assert(not Hatching.command(h, "daily", day, h.state.revision))
		assert(h.state.nectar == nectar + 4 and c.randomCalls == 0)
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
		assert(not p.dailyAvailable and p.dailyDay == "20" and p.dailyBonus == 4 and p.stamps == 0)
		assert(not Hatching.command(h, "daily", p.dailyDay, h.state.revision))
		c.now += 1
		p = Hatching.public(h)
		assert(p.dailyAvailable and p.dailyDay == "21")
		local revision = h.state.revision
		command(h, "daily", p.dailyDay)
		assert(h.state.nectar == 10 and db.player_1.hatching.nectar == 10)
		assert(not Hatching.command(h, "daily", p.dailyDay, revision))
		assert(not Hatching.command(h, "daily", p.dailyDay, h.state.revision))
		assert(not Hatching.public(h).dailyAvailable)
		c.now += 86400
		assert(not Hatching.command(h, "daily", "21", h.state.revision))
		assert(not Hatching.renew(h))
		local nextVisit = Hatching.load(1, {}, adapter("b"))
		command(nextVisit, "daily", "22")
		assert(nextVisit.state.nectar == 14)
		c.now -= 86400
		assert(not Hatching.public(nextVisit).dailyAvailable)
		assert(not Hatching.command(nextVisit, "daily", "21", nextVisit.state.revision))
		assert(nextVisit.state.nectar == 14)
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
		old.quests, old.petWearables = nil, nil; old.ballThemes, old.stats, old.stamps, old.book = nil, nil, nil, nil -- authentic v2 input (v2 upgrade adds contracts)
		for _,key in ipairs({"toyUnlocks","petToys","toyReceipts","toyReceiptOrder","toyReservation","pendingToyResult","lastToyResult","featureStock","petFeatures","featureReceipts","featureReceiptOrder","featureReservation","pendingFeatureResult","lastFeatureResult","materialUnlocks","petMaterials","materialReceipts","materialReceiptOrder","materialReservation","pendingMaterialResult","lastMaterialResult","hueInventory","petHues","hueItemReceipts","hueReceiptOrder","hueMigrationId","hueMigrationAcknowledged","legacyLastHueResult","legacyHueEgg","legacyHueRedemption","pendingHueResult","hueReservation"})do old[key]=nil end
		old.hueAssignments=nil;old.petDay,old.petCount,old.lastPetAward=nil,nil,nil -- Authentic pre-pet v2 input.
		old.masteryChallenges, old.masteryLegacyMask, old.contracts, old.totalWins = nil, nil, nil, nil
		db.player_1.keep, old.nectar = "untouched", 47
		h = Hatching.load(1, {}, adapter("b"))
		assert(h.status == "Ready" and h.state.version == 11 and h.state.nectar == 47)
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

	-- Quests replace the daily contracts (hatching v9, QUESTS-DIFFICULTY-PLAN 3-5).
	local QuestCatalog=require(game.ReplicatedStorage.Shared.QuestCatalog)
	local QuestRules=require(game.ReplicatedStorage.Shared.QuestRules)
	local function slotFor(h,metric,scope)
		for slot,id in ipairs(h.state.quests[scope or "daily"].ids)do if QuestCatalog.ById[id].metric==metric then return slot,QuestCatalog.ById[id] end end
	end
	local function finish(db,h,scope,slot)
		local def=QuestCatalog.ById[db.player_1.hatching.quests[scope].ids[slot]]
		db.player_1.hatching.quests[scope].prog[slot]=QuestRules.maxStored(def);assert(Hatching.renew(h))
		return def
	end
	test("saved wins and quest progress commit atomically once per run; quests never pay inside award", function()
		local _, c, adapter = fixture()
		c.replay = true
		local h = Hatching.load(1, { rank = 1 }, adapter("a"))
		assert(h.state.version==11 and h.state.contracts==nil and h.state.quests.v==1)
		assert(Hatching.award(h, 1, 8, runSummary(h)))
		assert(h.state.nectar == 14 and h.state.lastRunReward.total == 8 and h.state.lastRunReward.questAuto == 0)
		assert(h.state.totalWins == 1 and type(h.state.lastRunReward.quests)=="table")
		local before=table.clone(h.state.quests.daily.prog)
		assert(Hatching.award(h, 1, 8, runSummary(h)))
		assert(h.state.nectar == 14 and table.concat(h.state.quests.daily.prog,",")==table.concat(before,","),"a replayed award moves nothing")
		local public = Hatching.public(h)
		assert(public.contracts==nil and #public.quests.daily==3 and #public.quests.weekly==3 and public.quests.rerollLeft==1)
		public.quests.daily[1].progress=99
		assert(h.state.quests.daily.prog[1]~=99)
	end)

	test("progress only comes from the server summary; overflowed rounds and other days do not count", function()
		local _, c, adapter = fixture()
		c.now = 18000 + 86400 * 20 + 86390
		local h = Hatching.load(1, { rank = 1 }, adapter("a"))
		local zero=table.concat(h.state.quests.daily.prog,",")
		assert(Hatching.award(h, 1, 0, runSummary(h, { success = false, clean = false, drops = 3 })))
		assert(table.concat(h.state.quests.daily.prog,",")==zero)
		local oldRun = runSummary(h)
		c.now += 15 -- the run started yesterday
		assert(Hatching.award(h, 2, 8, oldRun))
		assert(table.concat(h.state.quests.daily.prog,",")=="0,0,0" and h.state.quests.day=="21")
		c.now -= 15 -- clock rollback: the stored day stays, the run does not count
		assert(Hatching.award(h, 3, 8, runSummary(h)))
		assert(h.state.quests.day=="21" and table.concat(h.state.quests.daily.prog,",")=="0,0,0")
		-- There is no client progress path: only award, questClaim and questReroll exist.
		assert(Hatching.questProgress==nil and Hatching.setQuest==nil)
	end)

	test("claims pay once, doubled by the pass, including after an ambiguous retry", function()
		local db, c, adapter = fixture()
		local h = Hatching.load(1, { rank = 1 }, adapter("a"))
		local day=h.state.quests.day
		local ok,reason=Hatching.questClaim(h,"daily",1,day)
		assert(not ok and reason=="NotComplete")
		finish(db,h,"daily",1)
		local wallet=h.state.nectar
		c.failAfterCommit=true
		ok=Hatching.questClaim(h,"daily",1,day,{multiplier=2})
		assert(not ok and h.status=="Retrying" and db.player_1.hatching.nectar==wallet+8)
		ok,reason=Hatching.questClaim(h,"daily",1,day,{multiplier=2})
		assert(ok and reason=="Saved" and h.state.nectar==wallet+8)
		ok,reason=Hatching.questClaim(h,"daily",1,day,{multiplier=2})
		assert(ok and reason=="AlreadyClaimed" and h.state.nectar==wallet+8)
		local entry=h.state.quests.history[#h.state.quests.history]
		assert(entry.s==8 and entry.a==false and entry.d==day)
		assert(not Hatching.questClaim(h,"daily",1,"999") and not Hatching.questClaim(h,"daily",4,day) and not Hatching.questClaim(h,"monthly",1,day))
		assert(h.state.nectar==wallet+8)
	end)

	test("weekly claims and the all-three bonus", function()
		local db, _, adapter = fixture()
		local h = Hatching.load(1, { rank = 1 }, adapter("a"))
		local week=h.state.quests.week
		local wallet=h.state.nectar
		assert(not Hatching.questClaim(h,"weekly",0,week))
		for slot=1,3 do finish(db,h,"weekly",slot);assert(Hatching.questClaim(h,"weekly",slot,week))end
		assert(h.state.nectar==wallet+30 and Hatching.public(h).quests.bonusReady)
		assert(Hatching.questClaim(h,"weekly",0,week))
		assert(h.state.nectar==wallet+35 and h.state.quests.weekly.bonus)
		local ok,reason=Hatching.questClaim(h,"weekly",0,week)
		assert(ok and reason=="AlreadyClaimed" and h.state.nectar==wallet+35)
	end)

	test("one free reroll a day, saved across sessions and refused once used", function()
		local db, c, adapter = fixture()
		local h = Hatching.load(1, { rank = 1 }, adapter("a"))
		local day=h.state.quests.day
		local old=h.state.quests.daily.ids[2]
		assert(Hatching.questReroll(h,2,day))
		local new=h.state.quests.daily.ids[2]
		assert(new~=old and QuestCatalog.ById[new].pool=="craft" and h.state.quests.daily.rerolled and db.player_1.hatching.quests.daily.rerolled)
		local ok,reason=Hatching.questReroll(h,3,day)
		assert(not ok and reason=="NoReroll")
		assert(Hatching.release(h))
		local again=Hatching.load(1,{},adapter("b"))
		ok,reason=Hatching.questReroll(again,1,day)
		assert(not ok and reason=="NoReroll" and again.state.quests.daily.ids[2]==new and Hatching.public(again).quests.rerollLeft==0)
		-- A started or claimed slot cannot be rerolled; a new day brings a new reroll.
		assert(Hatching.release(again))
		c.now+=86400
		again=Hatching.load(1,{},adapter("b2"))
		local tomorrow=Hatching.public(again).quests
		assert(tomorrow.rerollLeft==1 and tomorrow.day~=day)
		assert(Hatching.release(again))
		db.player_1.hatching.quests=nil -- forces a sanitize-at-load path below
		local fresh=Hatching.load(1,{},adapter("c"))
		assert(fresh.status=="Ready" and fresh.state.quests.day==tomorrow.day)
		fresh.state.quests.daily.prog[1]=1;db.player_1.hatching.quests.daily.prog[1]=1
		ok,reason=Hatching.questReroll(fresh,1,tomorrow.day);assert(not ok and reason=="Started")
		assert(not Hatching.questReroll(fresh,1,day),"yesterday's reroll is refused")
	end)

	test("day and week rollover auto-credit unclaimed finished quests inside the next transaction", function()
		local db, c, adapter = fixture()
		c.now = 18000 + 86400 * 20 + 86390
		local h = Hatching.load(1, { rank = 1 }, adapter("a"))
		finish(db,h,"daily",1)
		local wallet=h.state.nectar
		c.now += 15
		assert(Hatching.award(h, 1, 8, runSummary(h), { multiplier = 2, bonus = 0 }))
		local reward=h.state.lastRunReward
		assert(reward.questAuto==8 and reward.total==16 and h.state.nectar==wallet+24)
		local entry=h.state.quests.history[#h.state.quests.history]
		assert(entry.a==true and entry.s==8 and entry.d=="20")
		-- Weekly: finish all three, jump to next Monday, then any claim credits 30 + 5.
		db.player_1.hatching.quests.daily.prog={0,0,0}
		for slot=1,3 do finish(db,h,"weekly",slot)end
		wallet=h.state.nectar
		assert(Hatching.release(h))
		c.now += 86400*7
		h=Hatching.load(1,{},adapter("b"))
		assert(h.state.nectar==wallet,"loading never credits by itself")
		local day=Hatching.public(h).quests.day
		assert(Hatching.questReroll(h,1,day))
		assert(h.state.nectar==wallet+35,h.state.nectar-wallet)
		assert(h.state.quests.history[#h.state.quests.history].id=="weekly_bonus")
	end)

	test("old saves never crash: v8 with contracts, malformed quests and an old catalogue", function()
		local db, _, adapter = fixture()
		local h = Hatching.load(1, { rank = 1 }, adapter("a"))
		assert(Hatching.release(h))
		local v8=copy(db.player_1.hatching);v8.version=8;v8.quests=nil;v8.petWearables=nil;v8.ballThemes,v8.stats,v8.stamps,v8.book=nil,nil,nil,nil
		v8.contracts={day="20",progress={runs=1,chain=3,score=500},claimedMask=6}
		db.player_1.hatching=v8
		h=Hatching.load(1,{},adapter("b"))
		assert(h.status=="Ready"and h.state.version==11 and h.state.contracts==nil and h.state.quests.v==1)
		for _,broken in ipairs({"junk",{v=1},{v=1,catalog=0},"catalog"})do
			assert(Hatching.release(h))
			if broken=="catalog"then db.player_1.hatching.quests.catalog=QuestCatalog.CatalogVersion+1
			else db.player_1.hatching.quests=broken end
			h=Hatching.load(1,{},adapter("x"..tostring(broken)))
			assert(h.status=="Ready"and h.state.quests.catalog==QuestCatalog.CatalogVersion,tostring(broken))
		end
		assert(Hatching.release(h))
		db.player_1.hatching.quests.daily.ids[1]="d_retired_quest"
		h=Hatching.load(1,{},adapter("y"))
		assert(h.status=="Ready"and QuestCatalog.ById[h.state.quests.daily.ids[1]])
		local size=#game:GetService("HttpService"):JSONEncode(h.state.quests)
		for i=1,30 do table.insert(h.state.quests.history,{d="20404",id="w_goals_hard12",s=20,a=true})end
		assert(#game:GetService("HttpService"):JSONEncode(h.state.quests)<2200 and size<1500)
	end)

	test("compound award retries immutable stats and original day before or after commit", function()
		for _, failure in ipairs({ "failBeforeCommit", "failAfterCommit" }) do
			local db, c, adapter = fixture()
			c.now = 18000 + 86400 * 20 + 86390
			local h = Hatching.load(1, { rank = 1 }, adapter("a"))
			local summary = runSummary(h)
			c[failure] = true
			assert(not Hatching.award(h, 1, 8, summary))
			assert(db.player_1.hatching.nectar == (if failure == "failAfterCommit" then 14 else 6))
			summary.family, summary.score = "orbit", 0
			c.now += 15
			assert(Hatching.retry(h))
			assert(h.state.nectar == 14 and h.state.mastery.pip == 0 and h.state.mastery.orbit == 0)
			assert(h.state.quests.day == "20" and h.state.totalWins == 1 and h.state.lastRunReward.total == 8)
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

	test("heat multiplier sits inside award before the pass and Supporter", function()
		local expect = { easy = { 5, 6 }, medium = { 6, 8 }, hard = { 9, 12 } }
		for heat, pair in pairs(expect) do
			for index, amount in ipairs({ 6, 8 }) do
				for _, boost in ipairs({ { multiplier = 1, bonus = 0 }, { multiplier = 2, bonus = 1 } }) do
					local _, _, adapter = fixture()
					local h = Hatching.load(1, { rank = 1 }, adapter("a"))
					local before = h.state.nectar
					local summary = runSummary(h, { heat = heat, clean = amount == 8, chain = 1, score = 0 })
					assert(Hatching.award(h, 1, amount, summary, boost))
					local reward = h.state.lastRunReward
					local want = pair[index] * boost.multiplier + boost.bonus
					assert(reward.heat == heat and reward.roundStars == pair[index] and reward.total == want, heat .. amount)
					assert(h.state.nectar - before == want)
				end
			end
		end
		local _, _, adapter = fixture()
		local h = Hatching.load(1, { rank = 1 }, adapter("a"))
		assert(Hatching.award(h, 1, 8, runSummary(h, { heat = "hard", chain = 1, score = 0 }), { multiplier = 2, bonus = 1 }))
		assert(h.state.lastRunReward.total == 25)
		-- No summary pays Medium; an unknown heat is refused before any write.
		assert(not Hatching.award(h, 2, 8, runSummary(h, { heat = "insane" })))
		assert(Hatching.award(h, 2, 6) and h.state.lastRunReward.total == 6 and h.state.lastRunReward.heat == "medium")
	end)

	-- QA 2026-11-13 Q5: the results strip's "Today: ★ N earned" reads public.todayEarned.
	test("todayEarned counts saved rounds this session today, never saved, a new day reads 0", function()
		local db, c, adapter = fixture()
		c.now = 18000 + 86400 * 30 + 100
		local h = Hatching.load(1, { rank = 1 }, adapter("a"))
		assert(Hatching.public(h).todayEarned == 0)
		assert(Hatching.award(h, 1, 6) and Hatching.award(h, 2, 8))
		assert(Hatching.public(h).todayEarned == 14, "two saved rounds: " .. tostring(Hatching.public(h).todayEarned))
		local ok, why = Hatching.award(h, 2, 8)
		assert(ok and why == "AlreadyAwarded" and Hatching.public(h).todayEarned == 14, "a repeated round adds nothing")
		assert(Hatching.award(h, 3, 0) and Hatching.public(h).todayEarned == 14, "a missed round adds nothing")
		assert(db.player_1.hatching.todayEarned == nil and db.player_1.hatching.roundStarsToday == nil, "never written to the save")
		assert(h.state.todayEarned == nil and h.state.roundStarsToday == nil, "not part of the saved state")
		c.now += 86400
		assert(Hatching.public(h).todayEarned == 0, "a new day starts again at 0")
	end)

	return { passed = #passed, cases = passed }
end
