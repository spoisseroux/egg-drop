-- Pet wearable Star purchases, equip and the hatching v10 save (WearableState):
-- fixed prices, debit and ownership in one write, idempotent by operation id, no
-- randomness, equip / unequip per slot (exclusions hide, never unequip), a v9 save
-- migrating safely, and public appearance replication.
-- Isolated adapters only; no DataStore or user writes.
-- Usage (Server): require(ServerScriptService.Server.ZZSpecs.WearablePurchase)(ServerScriptService.Server)
return function(server)
	local H = require(server.HatchProgress)
	local W = require(server.WearableState)
	local Appearance = require(server.PetAppearance)
	local Shared = game:GetService("ReplicatedStorage").Shared
	local Catalog = require(Shared.WearableCatalog)
	local Rules = require(Shared.PetAttachmentRules)
	local Defs = require(Shared.PetRigDefinitions)
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
	local function equipped(h) return W.equipped(h.state, "pip") end

	test("the catalogue: 13 Bear items at fixed 15/30/60 prices across the seven shop slots", function()
		local items = Catalog.forPet("pip").order
		assert(#items == 13, #items)
		local slots = {}
		for _, item in ipairs(items) do
			assert(item.price == Catalog.TierPrice[item.tier], item.id)
			slots[item.slot] = (slots[item.slot] or 0) + 1
		end
		assert(slots.Hat == 3 and slots.Shirt == 2 and slots.Neck == 2 and slots.EarPiercing == 2 and slots.Eyes == 2 and slots.Mouth == 1 and slots.Tail == 1)
		assert(Catalog.price("pip", "flowercrown") == 60 and Catalog.price("pip", "beanie") == 15 and Catalog.price("pip", "sparkle") == 30)
		local ring = Catalog.item("pip", "ring"); assert(ring.keys[1] == "EarPiercingL" and ring.keys[2] == "EarPiercingR")
		for _, tab in ipairs(Catalog.Tabs) do assert(#Catalog.inTab("pip", tab.slot) > 0, tab.id) end
		-- Every sold item renders on the Bear rig.
		local known = {}; for _, row in ipairs(Rules.items(Defs.pip)) do known[row.item] = true end
		for _, item in ipairs(items) do assert(known[item.id], "no meshes for " .. item.id) end
	end)

	test("buying debits the fixed price once, records ownership and equips", function()
		local h, db, c = fixture()
		fund(h, 100)
		local before, rolls = h.state.nectar, c.rolls
		local ok, reason = H.buyWearable(h, "w-1", "pip", "flowercrown", 60, true)
		assert(ok and reason == "Saved", tostring(reason))
		assert(h.state.nectar == before - 60 and db.player_1.hatching.nectar == before - 60)
		assert(W.owns(h.state, "pip", "flowercrown") and equipped(h).Hat == "flowercrown")
		assert(c.rolls == rolls, "a wearable purchase drew a random number")
		local public = H.public(h)
		assert(public.petWearables.pip.owned[1] == "flowercrown" and public.petWearables.pip.equipped.Hat == "flowercrown")
	end)

	test("the same operation id and an owned item never charge twice", function()
		local h, _, c = fixture()
		fund(h, 100)
		assert(H.buyWearable(h, "w-2", "pip", "sunhat", 30, true))
		local balance, writes = h.state.nectar, c.writes
		local ok, reason = H.buyWearable(h, "w-2", "pip", "sunhat", 30, true)
		assert(ok and reason == "AlreadyOwned" and h.state.nectar == balance and c.writes == writes)
		ok, reason = H.buyWearable(h, "w-3", "pip", "sunhat", 30, true)
		assert(ok and reason == "AlreadyOwned" and h.state.nectar == balance and c.writes == writes)
	end)

	test("a reused operation id with different arguments is refused, never a false Saved", function()
		local h, db, c = fixture()
		fund(h, 100)
		assert(H.buyWearable(h, "w-r", "pip", "beanie", 15, true))
		local balance, writes = h.state.nectar, c.writes
		-- Same id, another item: no charge, no item, and not "Saved".
		local ok, reason = H.buyWearable(h, "w-r", "pip", "sunhat", 30, true)
		assert(not ok and reason == "OperationConflict", tostring(ok) .. " " .. tostring(reason))
		assert(not W.owns(h.state, "pip", "sunhat") and h.state.nectar == balance and c.writes == writes)
		-- The saved record's op signature carries the arguments, so another server holding a
		-- stale snapshot is refused inside the callback too.
		assert(db.player_1.hatching.lastOperation.digest == "buy:pip:beanie")
		local h2, db2 = fixture()
		fund(h2, 100)
		local stale = copy(h2.state)
		assert(H.buyWearable(h2, "w-s", "pip", "beanie", 15, true))
		local committedState = copy(db2.player_1.hatching)
		h2.state = stale -- this session never saw the commit (as another server would)
		ok, reason = H.buyWearable(h2, "w-s", "pip", "sunhat", 30, true)
		assert(not ok and reason == "OperationConflict", "callback: " .. tostring(ok) .. " " .. tostring(reason))
		assert(db2.player_1.hatching.nectar == committedState.nectar and not W.owns(db2.player_1.hatching, "pip", "sunhat"))
		-- Equip ids are bound to their slot and item the same way.
		assert(H.buyWearable(h, "w-t", "pip", "sunhat", 30, false))
		assert(H.equipWearable(h, "e-r", "pip", "Hat", "sunhat"))
		ok, reason = H.equipWearable(h, "e-r", "pip", "Hat", "beanie")
		assert(not ok and reason == "OperationConflict" and equipped(h).Hat == "sunhat", tostring(reason))
		-- The same id with the same arguments is still a quiet success.
		ok, reason = H.buyWearable(h, "w-t", "pip", "sunhat", 30, false)
		assert(ok and reason == "AlreadyOwned")
	end)

	test("a replayed UpdateAsync callback and commit-then-error charge once", function()
		local h, db, c = fixture()
		fund(h, 60)
		local before = h.state.nectar
		c.replay = true
		assert(H.buyWearable(h, "w-4", "pip", "hoodie", 60, false))
		c.replay = false
		assert(db.player_1.hatching.nectar == before - 60)
		local h2, db2, c2 = fixture()
		fund(h2, 60)
		before = h2.state.nectar
		c2.failAfter = true
		local ok, reason = H.buyWearable(h2, "w-5", "pip", "beads", 15, true)
		assert(not ok and reason == "Retrying" and db2.player_1.hatching.nectar == before - 15)
		ok = H.buyWearable(h2, "w-5", "pip", "beads", 15, true)
		assert(ok and h2.state.nectar == before - 15 and db2.player_1.hatching.nectar == before - 15)
		assert(#W.row(h2.state, "pip").owned == 1)
	end)

	test("refuses when the wallet is short, a wrong price, an unknown item or an unowned pet, without writing", function()
		local h, _, c = fixture()
		local before, writes = h.state.nectar, c.writes
		assert(before < 60, "fixture starts below the showcase price")
		local ok, reason = H.buyWearable(h, "w-6", "pip", "flowercrown", 60, true)
		assert(not ok and reason == "NeedStars" and h.state.nectar == before and c.writes == writes)
		assert(not W.owns(h.state, "pip", "flowercrown"))
		fund(h, 100); writes = c.writes
		ok, reason = H.buyWearable(h, "w-7", "pip", "beanie", 1, true); assert(not ok and reason == "PriceChanged")
		ok, reason = H.buyWearable(h, "w-8", "pip", "crown", 15, true); assert(not ok and reason == "NotForSale")
		ok, reason = H.buyWearable(h, "w-9", "puddle", "beanie", 15, true); assert(not ok and (reason == "Unowned" or reason == "NotForSale"), tostring(reason))
		assert(c.writes == writes, "a refusal wrote")
	end)

	test("equip and unequip per slot; a pair fills both ears; only owned items equip", function()
		local h, _, c = fixture()
		fund(h, 200)
		local ok, reason = H.equipWearable(h, "e-0", "pip", "Hat", "beanie"); assert(not ok and reason == "NotOwned")
		assert(H.buyWearable(h, "b-1", "pip", "beanie", 15, false)); assert(equipped(h).Hat == nil)
		assert(H.buyWearable(h, "b-2", "pip", "sunhat", 30, false))
		assert(H.buyWearable(h, "b-3", "pip", "ring", 15, true))
		assert(equipped(h).EarPiercingL == "ring" and equipped(h).EarPiercingR == "ring")
		assert(H.equipWearable(h, "e-1", "pip", "Hat", "beanie")); assert(equipped(h).Hat == "beanie")
		-- One item per slot: the sun hat replaces the beanie.
		assert(H.equipWearable(h, "e-2", "pip", "Hat", "sunhat")); assert(equipped(h).Hat == "sunhat")
		local writes = c.writes
		ok, reason = H.equipWearable(h, "e-3", "pip", "Hat", "sunhat"); assert(ok and reason == "NoChange" and c.writes == writes)
		ok, reason = H.equipWearable(h, "e-4", "pip", "Shirt", "sunhat"); assert(not ok and reason == "InvalidWearable")
		assert(H.equipWearable(h, "e-5", "pip", "EarPiercing", false))
		assert(equipped(h).EarPiercingL == nil and equipped(h).EarPiercingR == nil and equipped(h).Hat == "sunhat")
		assert(H.equipWearable(h, "e-6", "pip", "Hat", false)); assert(next(equipped(h)) == nil)
		-- Taking off never sells or forgets the item.
		assert(W.owns(h.state, "pip", "sunhat") and W.owns(h.state, "pip", "ring"))
	end)

	test("exclusions hide, never unequip: a full hat hides horns, the Flower Crown keeps them", function()
		local h = fixture()
		fund(h, 200)
		assert(H.buyWearable(h, "x-1", "pip", "beanie", 15, true))
		assert(H.buyWearable(h, "x-2", "pip", "flowercrown", 60, false))
		assert(H.buyWearable(h, "x-3", "pip", "hoodie", 60, true))
		local r = Rules.resolve(Defs.pip, { horns = 4, wings = 2 }, equipped(h))
		assert(r.stages.horns == 0 and r.charmCenterHidden and r.stages.wings == 2, "beanie must hide horns and keep wings")
		assert(equipped(h).Hat == "beanie" and equipped(h).Shirt == "hoodie", "an exclusion unequipped something")
		assert(H.equipWearable(h, "x-4", "pip", "Hat", "flowercrown"))
		r = Rules.resolve(Defs.pip, { horns = 4 }, equipped(h))
		assert(r.stages.horns == 4 and not r.charmCenterHidden and r.blocked.Forehead and r.blocked.Chest)
		local sleeves = 0; for _, a in ipairs(r.show) do if a.item == "hoodie" and (a.channel == "HandL" or a.channel == "HandR") then sleeves += 1 end end
		assert(sleeves == 2, "hoodie sleeves ride the arm channels")
	end)

	test("a v9 save migrates to v10: wallet, pets and quests kept, empty wearables, never a failed load", function()
		local h, db, _, adapter = fixture()
		fund(h, 40)
		local balance = h.state.nectar
		assert(H.release(h))
		local old = copy(db.player_1.hatching)
		old.version = 9; old.petWearables = nil; old.lease = { token = "", expiresAt = 0 }
		db.player_1.hatching = old
		local again = H.load(1, { rank = 1 }, adapter)
		assert(again.status == "Ready" and again.state.version == 10, tostring(again.status))
		assert(again.state.nectar == balance and type(again.state.petWearables) == "table" and next(again.state.petWearables) == nil)
		assert(again.state.inventoryMask == old.inventoryMask and again.state.quests ~= nil)
		-- A v9 record that somehow already carries petWearables is sanitised, never a failed load:
		-- a malformed namespace is dropped to empty, a valid one is kept.
		assert(H.release(again))
		local bad = copy(old); bad.petWearables = { pip = "junk" }; db.player_1.hatching = bad
		local cleaned = H.load(1, { rank = 1 }, adapter)
		assert(cleaned.status == "Ready" and cleaned.state.version == 10, "a stray v9 wearables field failed the load: " .. tostring(cleaned.status))
		assert(next(cleaned.state.petWearables) == nil and cleaned.state.nectar == balance)
		assert(H.release(cleaned))
		local kept = copy(old); kept.petWearables = { pip = { owned = { "beanie" }, equipped = { Hat = "beanie" } } }; db.player_1.hatching = kept
		local carried = H.load(1, { rank = 1 }, adapter)
		assert(carried.status == "Ready" and W.owns(carried.state, "pip", "beanie") and W.equipped(carried.state, "pip").Hat == "beanie")
		assert(H.release(carried))
		local unowned = copy(old); unowned.petWearables = { puddle = { owned = { "beanie" }, equipped = {} } }; db.player_1.hatching = unowned
		local dropped = H.load(1, { rank = 1 }, adapter)
		assert(dropped.status == "Ready" and next(dropped.state.petWearables) == nil, "kept wearables for an unowned pet")
		-- v10 validation: equipped items must be owned; later catalogue ids are tolerated.
		assert(W.valid({ inventoryMask = again.state.inventoryMask, petWearables = { pip = { owned = { "future_hat" }, equipped = { Hat = "future_hat" } } } }))
		assert(not W.valid({ inventoryMask = again.state.inventoryMask, petWearables = { pip = { owned = {}, equipped = { Hat = "beanie" } } } }))
		assert(not W.valid({ inventoryMask = again.state.inventoryMask, petWearables = { pip = { owned = { "a", "a" }, equipped = {} } } }))
	end)

	test("ownership and the equipped set survive a fresh session", function()
		local h, _, _, adapter = fixture()
		fund(h, 60)
		assert(H.buyWearable(h, "s-1", "pip", "sparkle", 30, true))
		assert(H.buyWearable(h, "s-2", "pip", "heart", 30, true))
		assert(H.release(h))
		local again = H.load(1, { rank = 1 }, adapter)
		assert(again.status == "Ready" and W.owns(again.state, "pip", "sparkle") and W.equipped(again.state, "pip").Eyes == "sparkle" and W.equipped(again.state, "pip").Tail == "heart")
	end)

	test("replication: the public appearance carries the active pet's equipped wearables", function()
		local h = fixture()
		fund(h, 100)
		assert(H.buyWearable(h, "r-1", "pip", "tee", 15, true))
		assert(H.buyWearable(h, "r-2", "pip", "starstud", 30, true))
		local s = h.state
		local profile = { companionId = "pip", petAppearance = {}, petAppearanceSaved = {} }
		local public = Appearance.public(profile, s.hues, s.petHues, s.petMaterials, s.petToys, s.petFeatures, "pip", s.petWearables)
		assert(public.pip.wearables.Shirt == "tee" and public.pip.wearables.EarPiercingL == "starstud" and public.pip.wearables.EarPiercingR == "starstud")
		-- It survives the JSON round trip other clients decode.
		local Http = game:GetService("HttpService")
		local decoded = Http:JSONDecode(Http:JSONEncode(public))
		assert(decoded.pip.wearables.Shirt == "tee")
		-- Not the active pet: nothing leaks.
		assert(public.puddle == nil or public.puddle.wearables == nil)
	end)

	return cases
end
