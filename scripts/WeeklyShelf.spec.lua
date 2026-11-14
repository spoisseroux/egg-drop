-- Weekly shelf (WeeklyShelf, slice C): the week clock, three deterministic slots, the 20%
-- price table, what never appears (deluxe, book-only, free), no repeat from last week, and
-- the rendezvous property (a new catalogue id rarely moves the live shelf).
-- Pure shared data; no DataStore, no instances.
-- Usage (Server): require(ServerScriptService.Server.ZZSpecs.WeeklyShelf)(ServerScriptService.Server)
-- The second argument (optional) is the Shared folder to read; it defaults to ReplicatedStorage.Shared.
return function(_, shared)
	local Shared = shared or game:GetService("ReplicatedStorage").Shared
	local Shelf = require(Shared.WeeklyShelf)
	local Flags = require(Shared.FeatureFlags)
	local Wear = require(Shared.WearableCatalog)
	local Plates = require(Shared.DeckThemes)
	local Balls = require(Shared.BallThemes)
	local Rotation = require(Shared.QuestRotation)
	local Daily = require(Shared.DailyContracts)
	local cases = {}
	local function test(name, run) run(); table.insert(cases, name) end
	local base = Shelf.week(1700000000)
	local function ids(slots) local out = {}; for _, slot in ipairs(slots) do table.insert(out, slot.kind .. ":" .. slot.id) end; return table.concat(out, ",") end

	test("the week is the weekly quests' week: Monday 05:00 UTC, from a time or a day number", function()
		assert(Flags.WeeklyShelf == true, "the shelf flag is on for this build")
		assert(base == Rotation.week(tonumber(Daily.dayOf(1700000000))) and base == Shelf.weekOfDay(Daily.dayOf(1700000000)))
		-- 1700456400 = Mon 2023-11-20 05:00:00 UTC.
		assert(Shelf.week(1700456400) == Shelf.week(1700456399) + 1)
		assert(Shelf.week(1700456400 + 7 * 86400 - 1) == Shelf.week(1700456400) and Shelf.week(1700456400 + 7 * 86400) == Shelf.week(1700456400) + 1)
		assert(Shelf.weekOfDay("19681") == Shelf.weekOfDay(19681) and Shelf.weekOfDay(19680) + 1 == Shelf.weekOfDay(19681))
	end)

	test("the price table: 20% off, rounded to the nearest Star", function()
		for full, price in pairs({ [15] = 12, [30] = 24, [60] = 48, [20] = 16, [40] = 32, [80] = 64, [120] = 96 }) do
			assert(Shelf.discounted(full) == price, full .. " -> " .. Shelf.discounted(full))
		end
	end)

	test("three slots: a variant, a non-variant wearable, then a faceplate (even weeks) or a ball theme (odd weeks)", function()
		for week = base, base + 59 do
			local slots = Shelf.slots(week)
			assert(#slots == 3, "week " .. week .. " has " .. #slots)
			assert(slots == Shelf.slots(week), "same week, same table")
			local first, second, third = slots[1], slots[2], slots[3]
			assert(first.kind == "wearable" and second.kind == "wearable")
			local variant, plain = Wear.item("pip", first.id), Wear.item("pip", second.id)
			assert(variant and variant.variant == true and first.full == variant.price, "slot 1 is not a variant: " .. first.id)
			assert(plain and plain.variant == nil and second.full == plain.price, "slot 2 is a variant: " .. second.id)
			if week % 2 == 0 then
				assert(third.kind == "faceplate" and third.full == Plates.price(third.id), third.id)
				assert(not Plates.isBookOnly(third.id) and Plates.ById[third.id].tier ~= "deluxe" and table.find(Plates.Order, third.id))
			else
				assert(third.kind == "ball" and third.full == Balls.price(third.id), third.id)
				assert(Balls.ById[third.id].tier ~= "deluxe" and not Balls.isFree(third.id))
			end
			for _, slot in ipairs(slots) do
				assert(slot.full > 0 and slot.price == Shelf.discounted(slot.full) and slot.price < slot.full, slot.id)
				assert(Shelf.price(slot.kind, slot.id, week) == slot.price and Shelf.has(slot.kind, slot.id, week))
				assert(table.isfrozen(slot))
			end
		end
	end)

	test("off the shelf, another kind, another week or junk: no shelf price", function()
		local slots = Shelf.slots(base)
		assert(Shelf.price("wearable", "no_such_item", base) == nil and Shelf.price("faceplate", slots[1].id, base) == nil)
		assert(Shelf.price("wearable", slots[1].id, nil) == nil and Shelf.price(nil, slots[1].id, base) == nil and Shelf.price("wearable", nil, base) == nil)
		assert(#Shelf.slots(nil) == 0 and #Shelf.slots(base + .5) == 0 and #Shelf.slots(0 / 0) == 0 and #Shelf.slots("x") == 0 and #Shelf.slots(math.huge) == 0)
		-- Book-only and free things are never priced, whatever the week.
		for week = base, base + 39 do
			assert(Shelf.price("faceplate", "bookworm", week) == nil and Shelf.price("faceplate", "stargazer", week) == nil)
			assert(Shelf.price("ball", "smileys", week) == nil and Shelf.price("ball", "marbles", week) == nil)
			assert(Shelf.price("faceplate", Plates.Default, week) == nil)
		end
	end)

	test("adjacent weeks differ and no slot repeats last week's pick; the shelf moves through the catalogue", function()
		local seen = { {}, {} }
		for week = base, base + 59 do
			local now, before = Shelf.slots(week), Shelf.slots(week - 1)
			assert(ids(now) ~= ids(before), "week " .. week .. " repeats the whole shelf")
			assert(now[1].id ~= before[1].id, "slot 1 repeats in week " .. week)
			assert(now[2].id ~= before[2].id, "slot 2 repeats in week " .. week)
			-- Slot 3 alternates kind, so its previous pick of the same kind is two weeks back.
			local same = Shelf.slots(week - 2)[3]
			assert(now[3].kind == same.kind and now[3].kind ~= before[3].kind and now[3].id ~= same.id, "slot 3 repeats in week " .. week)
			seen[1][now[1].id] = true; seen[2][now[2].id] = true
		end
		local variants, wearables = 0, 0
		for _ in pairs(seen[1]) do variants += 1 end
		for _ in pairs(seen[2]) do wearables += 1 end
		assert(variants >= 6 and wearables >= 8, "the shelf is stuck: " .. variants .. " variants, " .. wearables .. " wearables in 60 weeks")
	end)

	test("pools are sorted by id and hold only priced, sellable items", function()
		local pools = Shelf.pools(base)
		for name, pool in pairs(pools) do
			local previous = ""
			for _, row in ipairs(pool) do assert(row.id > previous and row.full > 0, name .. " " .. row.id); previous = row.id end
		end
		assert(#pools.variant == 10 and #pools.wearable >= 17 and #pools.faceplate >= 1 and #pools.ball >= 1)
		for _, row in ipairs(pools.variant) do assert(Wear.item("pip", row.id).variant) end
		for _, row in ipairs(pools.wearable) do assert(not Wear.item("pip", row.id).variant) end
		for _, row in ipairs(pools.faceplate) do assert(Plates.ById[row.id].tier ~= "deluxe" and not Plates.isBookOnly(row.id)) end
		for _, row in ipairs(pools.ball) do assert(Balls.ById[row.id].tier ~= "deluxe") end
	end)

	test("a fresh variant (from == week) takes slot 1 that week", function()
		local function poolsOf(week)
			local pools = Shelf.pools(base)
			local variants = table.clone(pools.variant)
			if week >= base + 3 then table.insert(variants, { id = "zz_new_variant", full = 15, fresh = week == base + 3 }) end
			return { variant = variants, wearable = pools.wearable, faceplate = pools.faceplate, ball = pools.ball }
		end
		assert(Shelf.compute(base + 3, poolsOf)[1].id == "zz_new_variant")
		assert(Shelf.compute(base + 4, poolsOf)[1].id ~= "zz_new_variant", "last week's pick is skipped")
		assert(Shelf.compute(base + 2, poolsOf)[1].id ~= "zz_new_variant")
	end)

	test("rendezvous: one new catalogue id changes at most one slot, and leaves the shelf alone in at least 90% of 200 weeks", function()
		local function added(extra)
			return function(week)
				local pools = Shelf.pools(base)
				local copy = { variant = table.clone(pools.variant), wearable = table.clone(pools.wearable), faceplate = table.clone(pools.faceplate), ball = table.clone(pools.ball) }
				table.insert(copy[extra.pool], { id = extra.id, full = extra.full })
				table.sort(copy[extra.pool], function(a, b) return a.id < b.id end)
				return copy
			end
		end
		local function plain() return Shelf.pools(base) end
		for _, extra in ipairs({ { pool = "wearable", id = "mmm_new_item", full = 30 }, { pool = "variant", id = "mmm_new_variant", full = 15 }, { pool = "faceplate", id = "mmm_new_plate", full = 40 }, { pool = "ball", id = "mmm_new_ball", full = 40 } }) do
			local unchanged, source = 0, added(extra)
			for week = base, base + 199 do
				local before, after = Shelf.compute(week, plain), Shelf.compute(week, source)
				local moved = 0
				for index = 1, 3 do if before[index].id ~= after[index].id then moved += 1 end end
				assert(moved <= 1, extra.id .. " moved " .. moved .. " slots in week " .. week)
				if moved == 0 then unchanged += 1 end
			end
			-- A new id wins a slot about 1 week in (pool size + 1). Measured 2026-11-14 with 23 wearables,
			-- 10 variants, 10 plates and 5 ball themes: 188 / 182 / 190 / 180 of 200 weeks untouched.
			-- The floors leave room for the catalogues to grow or shrink by a few items.
			assert(unchanged >= (if extra.pool == "wearable" then 176 elseif extra.pool == "variant" then 170 else 160), extra.id .. " left only " .. unchanged .. " of 200 weeks alone")
		end
	end)

	test("the hash is a stable 32-bit value (the shelf never depends on the platform)", function()
		assert(Shelf.hash(1, 1, "a") == Shelf.hash(1, 1, "a") and Shelf.hash(1, 1, "a") ~= Shelf.hash(2, 1, "a") and Shelf.hash(1, 1, "a") ~= Shelf.hash(1, 2, "a"))
		for _, id in ipairs({ "a", "beanie_mint", "liquid_chrome" }) do
			local h = Shelf.hash(2967, 1, id); assert(h >= 0 and h < 2 ^ 32 and h % 1 == 0, id)
		end
		-- FNV-1a 32 of "0:1:a" (offset 2166136261, prime 16777619), computed independently.
		local function reference(text)
			local h = 2166136261
			for i = 1, #text do
				h = bit32.bxor(h, string.byte(text, i))
				local result, factor, value = 0, 16777619, h
				-- Schoolbook multiply mod 2^32, one bit of the prime at a time.
				while factor > 0 do
					if factor % 2 == 1 then result = (result + value) % 4294967296 end
					value = (value * 2) % 4294967296; factor = factor // 2
				end
				h = result
			end
			return h
		end
		for _, text in ipairs({ { 0, 1, "a" }, { 2967, 1, "beanie_grape" }, { 3100, 7, "night_orb" } }) do
			assert(Shelf.hash(text[1], text[2], text[3]) == reference(text[1] .. ":" .. text[2] .. ":" .. text[3]), text[3])
		end
	end)

	return cases
end
