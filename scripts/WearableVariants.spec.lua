-- Recolour variants and the slice B wardrobe tabs (WearableVariants, WearableCatalog):
-- row validation, listing after the base at the base price, the `from` week gate, pets
-- without the base, renderMap, the main-piece tint rule, hidden empty tabs and take-off.
-- Pure shared data; no DataStore, no instances.
-- Usage (Server): require(ServerScriptService.Server.ZZSpecs.WearableVariants)(ServerScriptService.Server)
-- The second argument (optional) is the Shared folder to read; it defaults to ReplicatedStorage.Shared.
return function(server, shared)
	local Shared = shared or game:GetService("ReplicatedStorage").Shared
	local Variants = require(Shared.WearableVariants)
	local Catalog = require(Shared.WearableCatalog)
	local Rules = require(Shared.PetAttachmentRules)
	local Defs = require(Shared.PetRigDefinitions)
	local cases = {}
	local function test(name, run) run(); table.insert(cases, name) end
	local bear = Defs.pip
	local function attachment(name) for _, a in ipairs(bear.attachments) do if a.name == name then return a end end; error("no attachment " .. name) end

	test("rows: ten valid recolours with the brief's exact colours; bad rows are refused", function()
		assert(#Variants.Rows == 10 and Variants.problem(Variants.Rows) == nil)
		local expected = {
			beanie_mint = { "beanie", "#7FE0CF", "Mint Pom Beanie" }, beanie_butter = { "beanie", "#FFD86B", "Butter Pom Beanie" },
			beanie_grape = { "beanie", "#9B7BE8", "Grape Pom Beanie" }, tee_berry = { "tee", "#D94A7A", "Berry Stripy Tee" },
			tee_forest = { "tee", "#3F8F6B", "Forest Stripy Tee" }, tee_tangerine = { "tee", "#F08A3C", "Tangerine Stripy Tee" },
			bellcollar_silver = { "bellcollar", "#DCE3EE", "Silver Bell Collar" }, bellcollar_rose = { "bellcollar", "#F2A0A8", "Rose Bell Collar" },
			sunhat_cocoa = { "sunhat", "#A9764F", "Cocoa Sun Hat" }, sunhat_peach = { "sunhat", "#FFB38A", "Peach Sun Hat" },
		}
		for _, row in ipairs(Variants.Rows) do
			local want = assert(expected[row.id], "unexpected variant " .. row.id)
			assert(row.base == want[1] and row.color == want[2] and row.name == want[3], row.id)
			assert(#row.id <= 32 and Variants.ById[row.id] == row and row.from == nil and row.price == nil)
			assert(table.isfrozen(row))
		end
		assert(Variants.ById.bellcollar_rose.piece == "Neck_BellCollar_Bell" and Variants.ById.beanie_mint.piece == nil)
		local function bad(row) return Variants.problem({ row }) ~= nil end
		assert(bad({ id = "Beanie", base = "beanie", name = "x", color = "#FFFFFF" }), "upper case id")
		assert(bad({ id = string.rep("a", 33), base = "beanie", name = "x", color = "#FFFFFF" }), "33 characters")
		assert(bad({ id = "a", base = "a", name = "x", color = "#FFFFFF" }), "its own base")
		assert(bad({ id = "a", base = "beanie", name = "", color = "#FFFFFF" }), "no name")
		assert(bad({ id = "a", base = "beanie", name = "x", color = "FFFFFF" }) and bad({ id = "a", base = "beanie", name = "x", color = "#FFF" }), "hex")
		assert(bad({ id = "a", base = "beanie", name = "x", color = "#FFFFFF", price = 0 }) and bad({ id = "a", base = "beanie", name = "x", color = "#FFFFFF", from = -1 }))
		assert(Variants.problem({ { id = "a", base = "beanie", name = "x", color = "#FFFFFF" }, { id = "a", base = "tee", name = "y", color = "#000000" } }) ~= nil, "duplicate id")
		assert(Variants.problem({ { id = "a", base = "beanie", name = "x", color = "#FFFFFF" }, { id = "b", base = "a", name = "y", color = "#000000" } }) ~= nil, "a variant of a variant")
		assert(Variants.problem({ { id = "a", base = "beanie", name = "x", color = "#12ab9F", price = 20, from = 3000, piece = "Hat_Beanie" } }) == nil)
	end)

	test("the Bear lists all ten at the base price, each right after its base, sharing the base's slot and keys", function()
		local list = Catalog.forPet("pip")
		local count = 0
		for index, item in ipairs(list.order) do
			if item.variant then
				count += 1
				local base = assert(list.byId[item.base], item.id)
				assert(not base.variant and item.price == base.price and item.tier == base.tier and item.slot == base.slot, item.id)
				assert(item.keys == base.keys and item.flags == base.flags and item.perSide == base.perSide and item.primary == base.primary and item.role == base.role, item.id)
				assert(item.color == Variants.ById[item.id].color and item.name == Variants.ById[item.id].name)
				-- Walk back over sibling variants to the base.
				local back = index - 1
				while list.order[back].variant do assert(list.order[back].base == item.base, "variants of two bases interleaved"); back -= 1 end
				assert(list.order[back].id == item.base, item.id .. " is not after its base")
				assert(Catalog.item("pip", item.id) == item and Catalog.price("pip", item.id) == base.price)
			else
				assert(item.variant == nil and item.base == nil and item.color == nil, item.id)
			end
		end
		assert(count == 10, count)
		local hats = Catalog.inTab("pip", "Hat")
		assert(hats[1].id == "beanie" and hats[2].id == "beanie_mint" and hats[3].id == "beanie_butter" and hats[4].id == "beanie_grape" and hats[5].id == "sunhat" and hats[6].id == "sunhat_cocoa")
		assert(Catalog.price("pip", "beanie_mint") == 15 and Catalog.price("pip", "sunhat_peach") == 30 and Catalog.price("pip", "bellcollar_rose") == 30 and Catalog.price("pip", "tee_berry") == 15)
		assert(Catalog.Variants == Variants.Rows, "the localization export reads the names from WearableCatalog.Variants")
	end)

	test("a `from` week hides a row until that week; a price override applies; a pet without the base lists none", function()
		local week = Variants.week(1700000000)
		assert(week == Catalog.week(1700000000) and week % 1 == 0)
		-- Monday 05:00 UTC rolls the week (1700456400 = Mon 2023-11-20 05:00:00 UTC).
		assert(Variants.week(1700456400) == Variants.week(1700456399) + 1 and Variants.week(1700456400 + 7 * 86400 - 1) == Variants.week(1700456400))
		local rows = {
			{ id = "beanie_now", base = "beanie", name = "Now", color = "#101010" },
			{ id = "beanie_later", base = "beanie", name = "Later", color = "#202020", from = week + 1, price = 20 },
			{ id = "cape_red", base = "cape_that_does_not_exist", name = "Cape", color = "#303030" },
		}
		assert(Variants.problem(rows) == nil)
		local now = Catalog.compose("pip", Variants.rows(week, rows))
		assert(now.byId.beanie_now and now.byId.beanie_later == nil and now.byId.cape_red == nil)
		local later = Catalog.compose("pip", Variants.rows(week + 1, rows))
		assert(later.byId.beanie_later and later.byId.beanie_later.price == 20 and later.byId.beanie_now.price == 15 and later.byId.cape_red == nil)
		assert(#Variants.rows(week - 5, rows) == 2 and #Variants.rows(math.huge, rows) == 3 and #Variants.rows(nil, rows) == 2)
		-- Pets with no authored wearables (every retired rig today) list nothing.
		assert(#Catalog.compose("puddle", Variants.Rows).order == 0 and #Catalog.forPet("puddle").order == 0 and not Catalog.hasItems("puddle"))
		assert(#Catalog.forPet("nobody").order == 0 and #Catalog.forPet(nil).order == 0 and Catalog.item("puddle", "beanie_mint") == nil)
		-- A variant id may never be a rig item id.
		assert(not pcall(Catalog.compose, "pip", { { id = "sunhat", base = "beanie", name = "Clash", color = "#404040" } }))
	end)

	test("renderMap maps variants to base ids with a tint; base and unknown ids pass through", function()
		local render = Catalog.renderMap("pip", { Hat = "beanie_mint", Neck = "bellcollar_rose", Shirt = "tee", Tail = "nope", EarPiercingL = "ring", EarPiercingR = "ring" })
		assert(render.mapped.Hat == "beanie" and render.mapped.Neck == "bellcollar" and render.mapped.Shirt == "tee" and render.mapped.Tail == "nope")
		assert(render.mapped.EarPiercingL == "ring" and render.mapped.EarPiercingR == "ring")
		local hat, neck = render.tints.Hat, render.tints.Neck
		assert(hat.to == "#7FE0CF" and hat.primary == "#E9574C" and hat.item == "beanie" and hat.id == "beanie_mint" and hat.piece == nil)
		assert(neck.to == "#F2A0A8" and neck.primary == "secondary" and neck.item == "bellcollar" and neck.piece == "Neck_BellCollar_Bell")
		assert(render.tints.Shirt == nil and render.tints.Tail == nil and render.tints.EarPiercingL == nil)
		-- The rig rules accept the mapped map and drop the unknown id.
		local wear = Rules.normalize(bear, render.mapped)
		assert(wear.Hat == "beanie" and wear.Neck == "bellcollar" and wear.Tail == nil)
		assert(Rules.normalize(bear, { Hat = "beanie_mint" }).Hat == nil, "the rig itself has no variant meshes")
		-- Junk in, empty out.
		for _, junk in ipairs({ false, 3, "x" }) do local r = Catalog.renderMap("pip", junk); assert(next(r.mapped) == nil and next(r.tints) == nil) end
		local odd = Catalog.renderMap("pip", { [1] = "beanie_mint", Hat = 4 }); assert(next(odd.mapped) == nil)
		local other = Catalog.renderMap("puddle", { Hat = "beanie_mint" }); assert(other.mapped.Hat == "beanie_mint" and other.tints.Hat == nil)
		assert(Catalog.tintSignature(render.tints) == "Hat=beanie_mint;Neck=bellcollar_rose" and Catalog.tintSignature({}) == "" and Catalog.tintSignature(nil) == "")
	end)

	test("the main-piece rule: own pieces in the base's main colour change, a named piece wins, secondary trim never changes", function()
		local tints = Catalog.renderMap("pip", { Hat = "beanie_mint", Neck = "bellcollar_silver", Shirt = "tee_berry" }).tints
		assert(Catalog.tintFor(tints.Hat, attachment("Hat_Beanie")) == "#7FE0CF")
		assert(Catalog.tintFor(tints.Hat, attachment("Hat_Beanie_Trim")) == nil, "beanie trim is secondary")
		assert(Catalog.tintFor(tints.Hat, attachment("Hat_SunHat")) == nil, "another item under the beanie tint")
		for _, name in ipairs({ "Shirt_Tee_Torso", "Shirt_Tee_SleeveL", "Shirt_Tee_SleeveR" }) do assert(Catalog.tintFor(tints.Shirt, attachment(name)) == "#D94A7A", name) end
		assert(Catalog.tintFor(tints.Shirt, attachment("Shirt_Tee_Stripes")) == nil)
		assert(Catalog.tintFor(tints.Neck, attachment("Neck_BellCollar_Bell")) == "#DCE3EE")
		assert(Catalog.tintFor(tints.Neck, attachment("Neck_BellCollar")) == nil, "the collar band stays secondary")
		assert(Catalog.tintFor(nil, attachment("Hat_Beanie")) == nil and Catalog.tintFor(tints.Hat, nil) == nil)
		-- Every shipped variant recolours at least one piece of its base and never a secondary or face piece.
		for _, row in ipairs(Variants.Rows) do
			local item = Catalog.item("pip", row.id)
			local tint = Catalog.renderMap("pip", { [item.keys[1]] = row.id }).tints[item.keys[1]]
			local changed = 0
			for _, a in ipairs(bear.attachments) do
				local to = Catalog.tintFor(tint, a)
				if to then changed += 1; assert(a.item == row.base and a.colorRole == "own" and to == row.color, row.id .. " " .. a.name) end
			end
			assert(changed >= 1, row.id .. " recolours nothing")
		end
		assert(Catalog.attachmentKey(bear, attachment("Hat_Beanie")) == "Hat")
		for _, a in ipairs(bear.attachments) do
			if a.item == "ring" then assert(Catalog.attachmentKey(bear, a) == "EarPiercing" .. a.side, a.name) end
		end
	end)

	test("tabs: eleven known slots, only tabs with an item are shown, and take-off still validates on a hidden slot", function()
		local ids = {}
		for _, tab in ipairs(Catalog.Tabs) do table.insert(ids, tab.id .. "=" .. tab.slot); assert(bear.slots[tab.slot], "the Bear rig has no slot " .. tab.slot) end
		assert(table.concat(ids, ",") == "hat=Hat,shirt=Shirt,neck=Neck,ears=EarPiercing,eyes=Eyes,mouth=Mouth,tail=Tail,eyewear=Eyewear,cheek=Cheek,wrist=Wrist,ankle=Ankle")
		local shown = Catalog.tabsFor("pip")
		local previous = 0
		for _, tab in ipairs(shown) do
			local at = table.find(Catalog.Tabs, tab)
			assert(at and at > previous and #Catalog.inTab("pip", tab.slot) > 0, tab.id); previous = at
		end
		for _, tab in ipairs(Catalog.Tabs) do
			assert((table.find(shown, tab) ~= nil) == (#Catalog.inTab("pip", tab.slot) > 0), tab.id)
		end
		assert(#shown >= 7 and #Catalog.tabsFor("puddle") == 0)
		-- No Anklets, no Ankle tab (VISUAL-BRIEF 6).
		assert((#Catalog.inTab("pip", "Ankle") > 0) == (table.find(shown, Catalog.Tabs[11]) ~= nil))
		if server then
			local W = require(server.WearableState)
			local state = { inventoryMask = 1, petWearables = {}, nectar = 0 }
			for _, tab in ipairs(Catalog.Tabs) do
				local row, why = W.equipResult(state, "pip", tab.slot, false)
				assert(row and next(row.equipped) == nil, tab.id .. " take-off refused: " .. tostring(why))
			end
			local row, why = W.equipResult(state, "pip", "Aura", false); assert(row == nil and why == "InvalidWearable")
		end
	end)

	return cases
end
