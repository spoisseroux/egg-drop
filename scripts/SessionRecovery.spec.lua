-- Native Server fixture. All reads/writes below use a test-only cloned root store.
-- profileSource is the current PlayerProgress source supplied by the host.
return function(server, profileSource, sessionSource)
	local Hatching, Close = require(server.HatchProgress), require(server.CloseProgress)
	local Shared = game:GetService("ReplicatedStorage").Shared
	local Catalog, Pets = require(Shared.EggCatalog), require(Shared.PetCatalog)
	assert(type(profileSource) == "string", "pass current PlayerProgress source as argument two")
	assert(type(sessionSource) == "string", "pass current SessionProfile source as argument three")
	local function sandbox(source, environment, label)
		environment.game = environment.game or game
		environment.task = environment.task or task
		environment.DateTime = environment.DateTime or DateTime
		environment.require = environment.require or require
		local module = Instance.new("ModuleScript")
		module.Name = "_SessionRecoverySandbox_" .. label
		module.Source = "return function(__env)\nlocal game, script, task, DateTime, require = __env.game, __env.script, __env.task, __env.DateTime, __env.require\n"
			.. source .. "\nend"
		module.Parent = server
		local ok, factory = pcall(require, module)
		module:Destroy()
		assert(ok, factory)
		return factory(environment)
	end
	local function sessionModule(progress)
		local actualRequire = require
		return sandbox(sessionSource, { script = server.SessionProfile, require = function(module)
			if module == server.PlayerProgress then return progress end
			return actualRequire(module)
		end }, "SessionProfile")
	end
	local function copy(value)
		if type(value) ~= "table" then return value end
		local result = {}
		for key, item in pairs(value) do result[key] = copy(item) end
		return result
	end
	local passed = {}
	local function test(name, run) run(); table.insert(passed, name) end
	local function harness(initial)
		local db = copy(initial or {})
		local c = { now = 1700000000, milliseconds = 1700000000000, serial = 0, randomCalls = 0,
			profileWrites = 0, hatchWrites = 0, callbacks = {}, queues = {}, sample = 0.96, writes = {} }
		local fakeStore = { persistent = true }
		function fakeStore:GetAsync(key)
			if c.getFailed then error("Expected fixture: initial profile read unavailable") end
			return copy(if c.staleRead ~= nil then c.staleRead else db[key])
		end
		function fakeStore:UpdateAsync(key, transform)
			c.profileWrites += 1
			if c.failProfile then error("Expected fixture: profile save unavailable") end
			if c.beforeProfileTransform then local callback = c.beforeProfileTransform; c.beforeProfileTransform = nil; callback() end
			local value = transform(copy(db[key]))
			if value ~= nil then db[key] = copy(value) end
			table.insert(c.writes, { kind = "profile", root = copy(db[key]) })
			return copy(value)
		end
		local actualRequire = require
		local function profileModule(writer)
			local queue = {}; table.insert(c.queues, queue)
			local fakeGame = { JobId = "fixture-" .. writer }
			function fakeGame:GetService(service)
				if service == "ReplicatedStorage" then return game:GetService(service) end
				if service == "RunService" then return { IsStudio = function() return false end } end
				if service == "DataStoreService" then return { GetDataStore = function(_, name)
					assert(name == "EggDropLaunchV1"); return fakeStore
				end } end
				error("Unexpected sandbox service: " .. service)
			end
			function fakeGame:BindToClose(callback) table.insert(c.callbacks, callback) end
			local taskShim = {
				spawn = function() end, -- Never start the production background loop in a fixture.
				defer = function(callback, ...) table.insert(queue, { callback, table.pack(...) }) end,
				wait = function(dt) c.now += dt or 0; return dt or 0 end,
			}
			local environment = { game = fakeGame, script = server.PlayerProgress, task = taskShim,
				DateTime = { now = function() c.milliseconds += 1; return { UnixTimestampMillis = c.milliseconds } end },
				require = function(module)
					if module == server.ProgressStore then return fakeStore end
					return actualRequire(module)
				end,
			}
			local api = sandbox(profileSource, environment, "PlayerProgress_" .. writer)
			assert(type(api.fromRecord) == "function" and type(api.hydrate) == "function" and type(api.flushOnce) == "function", "recovery API not installed")
			return api, function()
				while #queue > 0 do local item = table.remove(queue, 1); item[1](table.unpack(item[2], 1, item[2].n)) end
			end
		end
		local function adapter(writer)
			return {
				now = function() return c.now end,
				guid = function() c.serial += 1; return "fixture-" .. writer .. "-" .. c.serial end,
				random = function() c.randomCalls += 1; return c.sample end,
				wait = function(dt) c.now += dt end,
				update = function(key, transform)
					c.hatchWrites += 1
					local value = transform(copy(db[key]))
					if value ~= nil then
						if c.beforeHatchCommit then c.beforeHatchCommit(value, db[key]) end
						db[key] = copy(value)
						table.insert(c.writes, { kind = "hatch", root = copy(value) })
					end
					return copy(value)
				end,
			}
		end
		local function options(flush, timeout)
			return { now = function() return c.now end, wait = function(dt) c.now += dt end,
				timeout = timeout or 2, profileFlush = flush }
		end
		return db, c, profileModule, adapter, options
	end
	local function command(handle, action, value)
		local ok, reason = Hatching.command(handle, action, value, handle.state.revision)
		assert(ok, action .. ": " .. tostring(reason))
	end
	local function summary(handle, family)
		return { family = family or "pip", day = Hatching.public(handle).dailyDay, success = true, clean = true,
			score = 600, chain = 3, clears = 0, drops = 24 }
	end
	local function initial()
		return { rank = 0, hatchCharge = 0, bestScore = 0, theme = "sherbet", sticker = "none", sound = "Full",
			reduced = false, outerSentinel = { intact = true } }
	end

	test("dirty outgoing profile drains before release and a stale reader hydrates the acquired root", function()
		local id, key = 71001, "player_71001"
		local original = initial()
		-- A genuine prior-edition owner remains equipped while the v1 Meadow egg is retired.
		original.rareTrials = Pets.byId.foxfire_wick.trial.bit
		local db, c, module, adapter, options = harness({ [key] = original })
		local A, deferredA = module("A")
		local B = module("B")
		local profileA = A.load(id)
		local a = Hatching.load(id, profileA, adapter("A"))
		assert(a.status == "Ready")
		assert(Hatching.grantStarter(a)); command(a, "ack", a.state.lastHatch.id)
		assert(Hatching.award(a, 1, 8, summary(a)))
		assert(a.state.nectar == 14, "first clean win: welcome6 +8 (contracts retired for quests, 4dae3d0)")
		db[key].hatching.innerSentinel = { intact = true }
		-- v1: Meadow is retired (no debit, no roll); a saved reveal receipt replaces the
		-- old orbit hatch so the pending reveal still crosses the lease handoff.
		local refused, why = Hatching.command(a, "hatch", "meadow", a.state.revision)
		assert(not refused and why == "RetiredEgg" and a.state.nectar == 14 and c.randomCalls == 0)
		db[key].hatching.lastHatch = { id = "recovery-saved-reveal", petId = "pip", duplicate = false, family = "pip", mastery = 0, rare = false, starter = true }
		assert(Hatching.renew(a) and a.state.lastHatch.id == "recovery-saved-reveal")
		assert(Catalog.isOwned(a.state.inventoryMask,"foxfire_wick"),"migration lost the retained owner")
		local revealId = a.state.lastHatch.id
		A.setSetting(profileA, "sound", "Quiet"); A.setSetting(profileA, "reduced", true)
		A.equip(profileA, "ice", "none"); A.equipCompanion(profileA, Pets.byId.foxfire_wick); A.recordScore(profileA, 999)
		A.release(profileA) -- Deliberately delay this outgoing autosave callback.
		c.staleRead = original
		local profileB = B.load(id)
		c.staleRead = nil
		assert(profileB.sound == "Full" and profileB.theme == "sherbet")
		local blocked = Hatching.load(id, profileB, adapter("B-early"))
		assert(blocked.status == "Locked", "stale GetAsync must not bypass an active lease")
		local payout = { sequence = 2, amount = 8, summary = summary(a, "wick") }
		c.beforeHatchCommit = function(nextRoot, previous)
			if previous.hatching.lease.expiresAt > c.now and nextRoot.hatching.lease.expiresAt == 0 then
				assert(nextRoot.hatching.lease.token == previous.hatching.lease.token, "release preserves the old fencing token")
				assert(nextRoot.sound == "Quiet" and nextRoot.theme == "ice" and nextRoot.sticker == "none"
					and nextRoot.reduced and nextRoot.companionId == "foxfire_wick", "lease released before profile drain")
			end
		end
		assert(Close.drain(Hatching, a, payout, options(function() return A.flushOnce(profileA) end)))
		assert(payout.saved and db[key].hatching.nectar == 22, "second win8 (quest Stars are claimed by hand)")
		local savedRevision, writes = db[key].hatching.revision, c.profileWrites
		deferredA()
		assert(c.profileWrites == writes and db[key].hatching.revision == savedRevision, "delayed old flush must already be drained")
		local b = Hatching.load(id, profileB, adapter("B"))
		assert(b.status == "Ready" and b.profileRecord and b.profileRecord.hatching == nil)
		local callback = function() end
		profileB.onSaveFailed = callback
		assert(sessionModule(B).hydrate(profileB, b) and profileB.onSaveFailed == callback)
		assert(profileB.sound == "Quiet" and profileB.reduced and profileB.theme == "ice" and profileB.sticker == "none"
			and profileB.companionId == "foxfire_wick" and profileB.bestScore == 999)
		assert(b.state.inventoryMask == Catalog.mask({ "pip", "foxfire_wick" }) and b.state.lastHatch.id == revealId and b.state.lastHatch.petId == "pip" and b.state.nectar == 22)
		assert(db[key].outerSentinel.intact and db[key].hatching.innerSentinel.intact)
		command(b, "ack", revealId)
		local balance, marks = b.state.nectar, b.state.mastery.wick
		assert(Hatching.award(b, 2, 8, summary(b, "wick")))
		assert(b.state.nectar == balance and b.state.mastery.wick == marks and c.randomCalls == 0, "reward replay must not credit twice or reroll")
		assert(Close.drain(Hatching, b, nil, options(function() return B.flushOnce(profileB) end)))
		local again = Hatching.load(id, profileB, adapter("C"))
		assert(again.status == "Ready" and again.state.lastHatch == nil and again.state.nectar == 22 and c.randomCalls == 0)
		assert(db[key].outerSentinel.intact and db[key].hatching.innerSentinel.intact)
	end)

	test("profile save failure times out without releasing the lease and later recovers", function()
		local id, key = 71002, "player_71002"
		local db, c, module, adapter, options = harness({ [key] = initial() })
		local A, deferred = module("failure-A")
		local profile = A.load(id)
		local a = Hatching.load(id, profile, adapter("failure-A"))
		A.setSetting(profile, "sound", "Off")
		c.failProfile = true
		local ok, reason = Close.drain(Hatching, a, nil, options(function() return A.flushOnce(profile) end, 0.6))
		assert(not ok and reason == "CloseTimeout" and db[key].hatching.lease.token == a.token)
		local blocked = Hatching.load(id, {}, adapter("failure-B"))
		assert(blocked.status == "Locked")
		c.failProfile = false
		assert(Close.drain(Hatching, a, nil, options(function() return A.flushOnce(profile) end)))
		assert(db[key].sound == "Off" and db[key].hatching.lease.expiresAt == 0 and db[key].hatching.lease.token == a.token)
		deferred()
		local nextSession = Hatching.load(id, {}, adapter("recovered-B"))
		assert(nextSession.status == "Ready" and nextSession.profileRecord.sound == "Off")
	end)

	test("failed initial load cannot write defaults or acquire a persistent hatch session", function()
		local db, c, module, adapter = harness({ player_71003 = initial() })
		local A = module("load-failed")
		c.getFailed = true
		local profile = A.load(71003)
		assert(profile.loadFailed)
		A.setSetting(profile, "sound", "Off")
		A.flushOnce(profile)
		local before = c.hatchWrites
		local handle = Hatching.load(71003, profile, adapter("temporary"))
		assert(handle.status == "Temporary" and c.profileWrites == 0 and c.hatchWrites == before)
		assert(db.player_71003.sound == "Full" and db.player_71003.hatching == nil)
	end)

	test("hydrate rejects dirty and in-flight profiles but fromRecord decodes authoritative defaults safely", function()
		local _, _, module = harness()
		local A = module("hydrate")
		local profile = A.fromRecord(71004, initial(), true)
		A.setSetting(profile, "sound", "Quiet")
		assert(not A.hydrate(profile, { sound = "Off", theme = "ice" }) and profile.sound == "Quiet")
		local clean = A.fromRecord(71005, initial(), true)
		clean.saving = true
		assert(not A.hydrate(clean, { sound = "Off" }) and clean.sound == "Full")
		clean.saving = false
		assert(A.hydrate(clean, { sound = "Off", theme = "ice", sticker = "seed", reduced = true, companionId = "foxfire_wick" }))
		assert(clean.key == "player_71005" and clean.sound == "Off" and clean.theme == "ice" and clean.companionId == "foxfire_wick")
		local failed = A.fromRecord(71006, initial(), false)
		assert(failed.loadFailed)
		A.flushOnce(failed)
	end)

	-- Stickers are retired: a stored old sticker id loads as "none".
	test("locked and unavailable sessions preserve provisional rare and sticker choices", function()
		local _, _, module = harness()
		local A = module("provisional")
		local Session = sessionModule(A)
		local raw = initial()
		raw.companionId, raw.sticker, raw.theme, raw.sound = "foxfire_wick", "wick", "moss", "Off"
		local profile = A.fromRecord(71007, raw, true)
		for _, status in ipairs({ "Loading", "Locked", "Unavailable", "Temporary", "Retrying" }) do
			local handle = { status = status, state = { inventoryMask = 0 }, profileRecord = {} }
			assert(not Session.ready(handle) and not Session.hydrate(profile, handle))
			assert(profile.companionId == "foxfire_wick" and profile.sticker == "none" and profile.theme == "moss" and profile.sound == "Off")
		end
		assert(Session.ready({ status = "Ready" }) and not Session.ready({ status = "Ready" }, true))
	end)

	test("a setting changed during an in-flight autosave drains before lease release", function()
		local id, key = 71008, "player_71008"
		local db, c, module, adapter, options = harness({ [key] = initial() })
		local A = module("inflight")
		local profile = A.load(id)
		local handle = Hatching.load(id, profile, adapter("inflight"))
		A.setSetting(profile, "sound", "Quiet")
		c.beforeProfileTransform = function()
			assert(profile.saving and not A.flushOnce(profile), "another caller must not treat an in-flight dirty profile as drained")
			assert(not A.hydrate(profile, initial()))
			assert(Hatching.load(id, {}, adapter("inflight-other")).status == "Locked")
			A.setSetting(profile, "sound", "Off")
		end
		assert(Close.drain(Hatching, handle, nil, options(function() return A.flushOnce(profile) end)))
		assert(c.profileWrites == 2 and db[key].sound == "Off" and db[key].hatching.lease.expiresAt == 0
			and db[key].hatching.lease.token == handle.token)
	end)

	test("a temporary profile recovers through a fresh read and authoritative acquisition", function()
		local id, key = 71009, "player_71009"
		local saved = initial()
		saved.rank, saved.companionId, saved.sound, saved.reduced, saved.theme, saved.sticker = 1, "pip", "Quiet", true, "ice", "seed"
		local _, c, module, adapter = harness({ [key] = saved })
		local A = module("temporary-recovery")
		c.getFailed = true
		local provisional = A.load(id)
		local unavailable = Hatching.load(id, provisional, adapter("temporary-before"))
		assert(provisional.loadFailed and unavailable.status == "Temporary" and c.profileWrites == 0 and c.hatchWrites == 0)
		c.getFailed = false
		local fresh = A.load(id)
		local acquired = Hatching.load(id, fresh, adapter("temporary-after"))
		assert(not fresh.loadFailed and acquired.status == "Ready")
		assert(sessionModule(A).hydrate(provisional, acquired))
		assert(not provisional.loadFailed and provisional.sound == "Quiet" and provisional.reduced and provisional.theme == "ice"
			and provisional.sticker == "none" and provisional.companionId == "pip")
		assert(c.profileWrites == 0, "recovery hydration must not save provisional defaults")
	end)

	test("the actual Studio store keeps both writers in one isolated cloned root", function()
		local studioGame = {}
		function studioGame:GetService(name)
			assert(name == "RunService", "Studio store must not request a persistent DataStore")
			return { IsStudio = function() return true end }
		end
		local store = sandbox(server.ProgressStore.Source, { game = studioGame, script = server.ProgressStore }, "StudioStore")
		assert(store.persistent == false and store:GetAsync("fixture-player") == nil)
		local initialRoot = { theme = "ice", hatching = { nectar = 14, inventoryMask = Catalog.mask({ "pip", "foxfire_wick" }) } }
		store:UpdateAsync("fixture-player", function() return initialRoot end)
		initialRoot.hatching.nectar = 999
		local read = store:GetAsync("fixture-player")
		assert(read.hatching.nectar == 14)
		read.theme, read.hatching.nectar = "brick", 888
		assert(store:GetAsync("fixture-player").theme == "ice" and store:GetAsync("fixture-player").hatching.nectar == 14)
		store:UpdateAsync("fixture-player", function(previous) previous.sound = "Quiet"; return previous end)
		store:UpdateAsync("fixture-player", function(previous) previous.hatching.nectar += 8; return previous end)
		local merged = store:GetAsync("fixture-player")
		assert(merged.theme == "ice" and merged.sound == "Quiet" and merged.hatching.nectar == 22
			and merged.hatching.inventoryMask == Catalog.mask({ "pip", "foxfire_wick" }))
	end)
	return { passed = #passed, cases = passed, persistentWrites = false }
end
