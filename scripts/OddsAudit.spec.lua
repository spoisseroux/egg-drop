-- v859 listing audit (launch blocker): every egg's odds panel adds up to 100% and equal shares
-- read the same. The Toy Egg showed six equal toys as 17/17/17/17/16/16%. Pure: builds every
-- displayed odds table (Hatch eggs list, Customization Egg, Material disclosure, restricted
-- panels, and the per-item lists in the Toy / Feature / Hue panels) from the shipped catalogs.
return function(client)
	local Shared = game.ReplicatedStorage.Shared
	local Shop = require(client.EggHatchView)
	local OddsText = require(Shared.OddsText)
	local Toys = require(Shared.ToyCatalog)
	local Materials = require(Shared.MaterialCatalog)
	local Features = require(Shared.FeatureCatalog)
	local Hues = require(Shared.HueCatalog)
	local LookEgg = require(Shared.LookEggCatalog)
	local cases = {}
	local function test(name, run) run(); table.insert(cases, name) end

	-- A displayed value as a percentage: "25%", "12.5%", "1 in 6" (100/6), "<1%" (small).
	local function percent(text)
		local n = text:match("^1 in (%d+)$")
		if n then return 100 / tonumber(n), false end
		if text == "<1%" then return 0.5, true end
		local p = text:match("^([%d%.]+)%%$")
		assert(p, "unreadable odds value '" .. text .. "'")
		return tonumber(p), false
	end
	-- rows: {{label, value, probability}}. Sums the shown values and groups equal shares.
	local function audit(label, rows)
		if #rows == 0 then return end
		local total, fuzzy = 0, false
		local byShare = {}
		for _, row in ipairs(rows) do
			local p, small = percent(row.value)
			total += p; fuzzy = fuzzy or small
			local key = string.format("%.9f", row.probability)
			byShare[key] = byShare[key] or {}
			table.insert(byShare[key], row)
		end
		local slack = if fuzzy then 1 else 0.05
		assert(math.abs(total - 100) <= slack, string.format("%s: shown odds add up to %.2f%%", label, total))
		for _, group in pairs(byShare) do
			for _, row in ipairs(group) do
				assert(row.value == group[1].value, string.format("%s: equal shares read %s and %s (%s, %s)", label, group[1].value, row.value, group[1].label, row.label))
			end
		end
	end
	-- Every subset of a list (the toy and material pools are small).
	local function subsets(list, visit)
		for mask = 0, 2 ^ #list - 1 do
			local owned = {}
			for i, id in ipairs(list) do if bit32.band(mask, 2 ^ (i - 1)) ~= 0 then owned[id] = true end end
			visit(owned, mask)
		end
	end

	test("equal shares: whole, one decimal or 1 in N, the same on every row", function()
		for n = 2, 12 do
			local list = {}
			for i = 1, n do list[i] = 1 end
			local shown = OddsText.list(list)
			for i = 2, n do assert(shown[i] == shown[1], n .. " equal shares read unequal") end
			assert(shown[1] == OddsText.equalShare(n) and OddsText.format(1 / n) == shown[1], n .. " shares: list and format differ")
			assert(shown[1]:match("^[%d%.]+%%$"), n .. " shares are not a percentage: " .. shown[1])
			local p = percent(shown[1]); assert(math.abs(p * n - 100) < 0.05, n .. " shares do not add up")
			-- Paid random items: rounded values keep four significant digits.
			local digits = shown[1]:gsub("%%", ""):gsub("%.", ""):gsub("^0+", "")
			local _, rounded = OddsText.list(list)
			assert(not rounded or #digits >= 4, n .. " shares rounded to fewer than four digits: " .. shown[1])
		end
		assert(OddsText.equalShare(6) == "16.67%" and OddsText.equalShare(3) == "33.33%" and OddsText.equalShare(4) == "25%" and OddsText.equalShare(8) == "12.5%")
		local precise = OddsText.preciseList({ 1, 1, 1 }, 4); assert(precise[1] == precise[3], "preciseList equal thirds unequal")
	end)

	test("Toy Egg: every owned subset of the pool, in the Hatch list and the Toy panel", function()
		subsets(Toys.Pools[Toys.PoolVersion], function(owned, mask)
			local odds = Shop.oddsRows("toy", { toyUnlocks = owned })
			local rows = {}
			for i, entry in ipairs(Toys.odds(owned)) do
				assert(odds.rows[i].id == entry.id, "toy rows out of order")
				table.insert(rows, { label = entry.id, value = odds.rows[i].value, probability = entry.probability })
			end
			audit("Toy Egg list (owned mask " .. mask .. ")", rows)
			local panel = {}
			for _, entry in ipairs(Toys.odds(owned)) do table.insert(panel, { label = entry.id, value = OddsText.format(entry.probability), probability = entry.probability }) end
			audit("Toy panel (owned mask " .. mask .. ")", panel)
		end)
		-- The reported case: a fresh save, six toys, each 16.67% with the rounding note.
		local fresh = Shop.oddsRows("toy", {})
		for i = 1, 6 do assert(fresh.rows[i].value == "16.67%", "fresh Toy Egg reads " .. fresh.rows[i].value) end
		assert(fresh.rounded and fresh.rows[7].id == "rounded", "rounded odds carry the note")
	end)

	test("Material Egg: every pool and owned subset (whole and precise disclosure)", function()
		for version, pool in pairs(Materials.Pools) do
			subsets(pool, function(owned, mask)
				local entries = Materials.odds(owned, version)
				local probabilities = {}
				for _, entry in ipairs(entries) do table.insert(probabilities, entry.probability) end
				local shown = if version == 4 then OddsText.preciseList(probabilities, 4) else OddsText.list(probabilities)
				local rows = {}
				for i, entry in ipairs(entries) do table.insert(rows, { label = entry.id, value = shown[i], probability = entry.probability }) end
				audit("Material pool " .. version .. " (owned mask " .. mask .. ")", rows)
			end)
		end
		local disclosed = Shop.oddsRows("material", { materialPoolVersion = 4, restricted = false, materialSelectionMode = "random", materialAvailable = true })
		local rows = {}
		for i, entry in ipairs(Materials.odds(nil, 4)) do table.insert(rows, { label = entry.id, value = disclosed.rows[i].value, probability = entry.probability }) end
		audit("Material Egg panel", rows)
	end)

	test("Customization Egg: every missing-charm table, jar rows and the charm row", function()
		subsets(LookEgg.EggShapes, function(owned, mask)
			local odds = Shop.lookOdds({ charmUnlocks = owned })
			local missing = LookEgg.missing(owned)
			local table_ = LookEgg.Tables[#missing]
			local rows = {}
			for _, row in ipairs(odds.rows) do
				if row.value ~= "" then
					local probability = if row.id == "charm" then table_.charm * #missing / 100 else table_[row.id] / 100
					table.insert(rows, { label = row.id, value = row.value, probability = probability })
				end
			end
			audit("Customization Egg (charms owned mask " .. mask .. ")", rows)
			-- The pity egg: every missing-charm count, this egg is a charm (jars 0%, charms split evenly).
			if #missing > 0 then
				local pity = Shop.lookOdds({ charmUnlocks = owned, lookCharmMisses = LookEgg.PityAt - 1 })
				local pityRows = {}
				for _, row in ipairs(pity.rows) do
					if row.value ~= "" then
						table.insert(pityRows, { label = row.id, value = row.value, probability = if row.id == "charm" then 1 else 0 })
					end
				end
				audit("Customization Egg pity egg (charms owned mask " .. mask .. ")", pityRows)
				local charm
				for _, row in ipairs(pity.rows) do if row.id == "charm" then charm = row end end
				assert(charm and charm.value == "100%" and charm.label:find(OddsText.equalShare(#missing), 1, true), "pity egg charm split: " .. tostring(charm and charm.label))
			end
		end)
	end)

	test("Feature and Hue panels: per-item lists add up and equal shares read the same", function()
		local features = {}
		for _, r in ipairs(Features.odds()) do table.insert(features, { label = r.id, value = OddsText.format(r.probability), probability = r.probability }) end
		local listed = {}
		for _, r in ipairs(Features.odds()) do table.insert(listed, r.probability) end
		local shown = OddsText.list(listed)
		local rows = {}
		for i, r in ipairs(Features.odds()) do table.insert(rows, { label = r.id, value = shown[i], probability = r.probability }) end
		audit("Feature Egg list", rows)
		-- The Feature panel formats each line alone: equal shares must still match.
		local seen = {}
		for _, row in ipairs(features) do
			local key = string.format("%.9f", row.probability)
			assert(seen[key] == nil or seen[key] == row.value, "Feature panel equal shares read unequal")
			seen[key] = row.value
		end
		local hue = Shop.oddsRows("hue", {})
		local hueRows = {}
		for i, id in ipairs(Hues.RollOrder) do table.insert(hueRows, { label = id, value = hue.rows[i].value, probability = Hues.Items[id].weight }) end
		audit("Hue Egg list", hueRows)
		local panel = {}
		for _, id in ipairs(Hues.RollOrder) do table.insert(panel, { label = id, value = OddsText.format(1 / #Hues.RollOrder), probability = 1 / #Hues.RollOrder }) end
		audit("Hue panel", panel)
	end)

	test("restricted panels name the next item and show no percentages", function()
		for _, id in ipairs({ "toy", "hue", "feature", "look" }) do
			local odds = if id == "look" then Shop.lookOdds({ restricted = true }) else Shop.oddsRows(id, { restricted = true })
			assert(odds.restricted == true and #odds.rows >= 1, id .. " restricted panel")
			for _, row in ipairs(odds.rows) do assert(row.value == "", id .. " restricted row shows odds " .. row.value) end
		end
		local material = Shop.oddsRows("material", { materialPoolVersion = 4, restricted = true })
		assert(material.restricted, "material restricted panel")
		for _, row in ipairs(material.rows) do assert(row.value == "", "material restricted row shows odds") end
	end)

	return { passed = #cases, cases = cases }
end
