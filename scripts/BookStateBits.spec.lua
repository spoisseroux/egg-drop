-- Slice C / D book data (BookCatalog): the six state Discoveries (bits 11..16) and
-- Book.stateBits, the garden hour, book-only plates and Book.platesOwed, and the Wardrobe
-- page counting base items only. Catalogue level only: the transactions that call these
-- are covered by LifetimeCounters / BookClaim (lane S).
-- Pure shared data; no DataStore, no instances.
-- Usage (Server): require(ServerScriptService.Server.ZZSpecs.BookStateBits)(ServerScriptService.Server)
-- The second argument (optional) is the Shared folder to read; it defaults to ReplicatedStorage.Shared.
return function(_, shared)
	local Shared = shared or game:GetService("ReplicatedStorage").Shared
	local Book = require(Shared.BookCatalog)
	local Wear = require(Shared.WearableCatalog)
	local Plates = require(Shared.DeckThemes)
	local Toys = require(Shared.ToyCatalog)
	local Finishes = require(Shared.MaterialCatalog)
	local Park = require(Shared.ParkActivities)
	local Daily = require(Shared.DailyContracts)
	local cases = {}
	local function test(name, run) run(); table.insert(cases, name) end
	local function bit(n) return bit32.lshift(1, n) end
	local function has(mask, id) return bit32.band(mask, bit(Book.DiscoveryById[id].bit)) ~= 0 end
	-- 2023-11-15 03:00:00 UTC = 22:00 the evening before in the garden (UTC-5): night.
	local night = 1700017200
	-- 2023-11-15 17:00:00 UTC = 12:00 in the garden: day.
	local noon = 1700067600

	test("seventeen Discoveries: the old eleven keep bits 0..10, the six state ones take 11..16", function()
		assert(#Book.Discoveries == 17)
		local want = { pet_night = 11, play_date = 12, full_outfit = 13, win_each_item = 14, tidy_25 = 15, rounds_100 = 16 }
		local state, used = 0, {}
		for _, entry in ipairs(Book.Discoveries) do
			assert(entry.bit >= 0 and entry.bit <= Book.MaxBit and not used[entry.bit], entry.id); used[entry.bit] = true
			assert(type(entry.name) == "string" and #entry.name > 0 and #entry.name <= 40, entry.id)
			if entry.state then state += 1; assert(want[entry.id] == entry.bit, entry.id) else assert(entry.bit <= 10, entry.id) end
		end
		assert(state == 6 and Book.DiscoveryById.tier_five.bit == 0 and Book.DiscoveryById.chain_five.bit == 1 and Book.DiscoveryById.win_hard.bit == 10)
		for id, n in pairs(want) do assert(Book.DiscoveryById[id].bit == n, id) end
		assert(#Book.Pages.discoveries.items == 17)
		-- A round never sets a state bit.
		assert(Book.runBits({ maxTier = 5, chain = 9, success = true, templateId = "lantern_chain", clean = true, itemsUsed = 9 }, "hard") < bit(11))
	end)

	test("the garden hour is the real UTC-5 clock; night is 20:00 to 06:00", function()
		assert(math.abs(Book.hour(night) - 22) < 1e-6 and math.abs(Book.hour(noon) - 12) < 1e-6)
		assert(Book.isNight(night) and not Book.isNight(noon))
		local midnight = night + 2 * 3600 -- 00:00 garden time
		assert(math.abs(Book.hour(midnight)) < 1e-6 and Book.isNight(midnight))
		assert(Book.isNight(midnight + 6 * 3600 - 1) and not Book.isNight(midnight + 6 * 3600), "06:00 ends the night")
		assert(not Book.isNight(midnight + 20 * 3600 - 1) and Book.isNight(midnight + 20 * 3600), "20:00 starts it")
		-- The garden's calendar day is the game day (both roll at 05:00 UTC).
		assert(Daily.dayOf(midnight) == tostring(tonumber(Daily.dayOf(midnight - 1)) + 1))
		assert(Book.hour(nil) == Book.hour(0) and Book.hour(0 / 0) == Book.hour(0))
	end)

	test("pet_night: only the pet write itself, only that day, only at night", function()
		local function petted(at, seq) return { operationSeq = seq or 7, lastPetAward = { id = "p", sequence = 8, day = Daily.dayOf(at), petId = "pip" } } end
		assert(has(Book.stateBits(petted(night), night, "pet:p"), "pet_night"))
		assert(not has(Book.stateBits(petted(noon), noon, "pet:p"), "pet_night"), "petting at noon")
		-- Another write later that night (a purchase) does not count a daytime pet.
		assert(not has(Book.stateBits(petted(noon), noon + 9 * 3600, "buy:pip:beanie"), "pet_night"), "a purchase at night")
		assert(not has(Book.stateBits(petted(night), night, "quest:daily:1"), "pet_night"))
		-- Yesterday's pet receipt at night today does not count.
		assert(not has(Book.stateBits(petted(night - 86400), night, "pet:p"), "pet_night"))
		-- Without a signature the receipt must belong to this write (sequence = operationSeq or +1).
		assert(has(Book.stateBits(petted(night, 7), night), "pet_night") and has(Book.stateBits(petted(night, 8), night), "pet_night"))
		assert(not has(Book.stateBits(petted(night, 12), night), "pet_night"), "an old receipt")
		assert(not has(Book.stateBits({ operationSeq = 7 }, night, "pet:p"), "pet_night") and not has(Book.stateBits(petted(night), nil, "pet:p"), "pet_night"))
	end)

	test("play_date, tidy_25, rounds_100 and win_each_item read the save", function()
		local target = Park.PlayDate.Target
		assert(has(Book.stateBits({ playDate = { day = "1", count = target } }, noon), "play_date"))
		assert(not has(Book.stateBits({ playDate = { day = "1", count = target - 1 } }, noon), "play_date"))
		assert(Book.stateBits({ stats = { tidyWins = 24, rounds = 99, itemWinKinds = 14 } }, noon) == 0)
		local mask = Book.stateBits({ stats = { tidyWins = 25, rounds = 100, itemWinKinds = 15 } }, noon)
		assert(mask == bit(14) + bit(15) + bit(16), mask)
		-- A save with 30 tidy wins earns tidy_25 on any commit; extra item bits do not hurt.
		assert(has(Book.stateBits({ stats = { tidyWins = 30 } }, noon, "buy:pip:beanie"), "tidy_25"))
		assert(has(Book.stateBits({ stats = { itemWinKinds = 31 } }, noon), "win_each_item"))
		for _, kinds in ipairs({ 0, 1, 7, 8, 11, 13, 14 }) do assert(not has(Book.stateBits({ stats = { itemWinKinds = kinds } }, noon), "win_each_item"), kinds) end
		-- Old saves have neither optional key.
		assert(Book.stateBits({ stats = { tidyWins = 3, rounds = 4 } }, noon) == 0)
		-- Junk never errors and never sets a bit.
		for _, junk in ipairs({ false, 3, "x" }) do assert(Book.stateBits(junk, noon) == 0) end
		assert(Book.stateBits(nil, noon) == 0)
		assert(Book.stateBits({ stats = "x", playDate = 4, petWearables = "y", lastPetAward = 2, operationSeq = "z" }, night) == 0)
		assert(Book.stateBits({ stats = { tidyWins = 0 / 0, rounds = -5, itemWinKinds = "15" }, playDate = { count = "3" } }, noon) == 0)
	end)

	test("full_outfit: five distinct slots on one pet, a pair counts once, variants count, unknown ids do not", function()
		local function worn(equipped) return { petWearables = { pip = { owned = {}, equipped = equipped } } } end
		local five = { Hat = "beanie_mint", Shirt = "tee", Neck = "beads", Eyes = "happy", Mouth = "w" }
		assert(Book.outfitSlots("pip", five) == 5 and has(Book.stateBits(worn(five), noon), "full_outfit"))
		local pair = { Hat = "beanie", Shirt = "tee", Neck = "beads", EarPiercingL = "ring", EarPiercingR = "ring" }
		assert(Book.outfitSlots("pip", pair) == 4 and not has(Book.stateBits(worn(pair), noon), "full_outfit"), "a pair counted twice")
		pair.Tail = "heart"; assert(Book.outfitSlots("pip", pair) == 5 and has(Book.stateBits(worn(pair), noon), "full_outfit"))
		local junk = { Hat = "beanie", Shirt = "tee", Neck = "beads", Eyes = "nope", Mouth = 4 }
		assert(Book.outfitSlots("pip", junk) == 3 and not has(Book.stateBits(worn(junk), noon), "full_outfit"))
		-- Slots are not pooled across pets, and a pet without wearables wears none.
		assert(Book.outfitSlots("puddle", five) == 0 and Book.outfitSlots(nil, five) == 0 and Book.outfitSlots("pip", nil) == 0)
		assert(not has(Book.stateBits({ petWearables = { pip = { equipped = { Hat = "beanie", Shirt = "tee" } }, puddle = { equipped = { Neck = "beads", Eyes = "happy", Mouth = "w" } } } }, noon), "full_outfit"))
		assert(Book.FullOutfitSlots == 5)
	end)

	test("the Wardrobe page counts base items only; the Toys page follows the live pools", function()
		local base = 0
		for _, item in ipairs(Wear.forPet("pip").order) do if not item.variant then base += 1 end end
		assert(#Book.Pages.wardrobe.items == base and base >= 17, #Book.Pages.wardrobe.items .. " vs " .. base)
		for _, item in ipairs(Book.Pages.wardrobe.items) do assert(not Wear.item(item.petId, item.itemId).variant, item.id) end
		-- Owning only variants moves nothing; owning a base does.
		local state = { petWearables = { pip = { owned = { "beanie_mint", "tee_berry", "sunhat_peach" }, equipped = {} } } }
		assert(Book.pageProgress(state, "wardrobe").owned == 0)
		table.insert(state.petWearables.pip.owned, "beanie"); assert(Book.pageProgress(state, "wardrobe").owned == 1)
		local toys, finishes = 0, 0
		for _, item in ipairs(Book.Pages.toys.items) do if item.kind == "toy" then toys += 1 else finishes += 1 end end
		assert(toys == #Toys.Pools[Toys.PoolVersion] and toys == 5 and finishes == #Finishes.Pools[Finishes.PoolVersion] and finishes == 2)
		assert(Book.pageProgress({ toyUnlocks = { wobble_top = true, squeaky_carrot = true }, materialUnlocks = { pearl_edge = true } }, "toys").owned == 2, "pool 3 finishes are not sold yet")
	end)

	test("book-only plates: Bookworm for three finished pages, Stargazer for Discoveries 100%, owed until held", function()
		assert(Book.BookOnlyFaceplate == "bookworm" and Book.StargazerPlate == "stargazer" and Book.StargazerMilestone == "discoveries.100")
		assert(Book.milestone(Book.StargazerMilestone), "the Discoveries page pays a 100% milestone")
		local listed = {}
		for index, plate in ipairs(Book.BookOnlyPlates) do
			listed[plate.id] = index
			assert(Plates.isBookOnly(plate.id) and Plates.price(plate.id) == nil and type(plate.earned) == "function" and type(plate.rule) == "string", plate.id)
			assert(Book.Pages.faceplates.bookOnly[index] == plate.id)
		end
		assert(listed.bookworm == 1 and #Book.Pages.faceplates.bookOnly == #Book.BookOnlyPlates)
		for _, item in ipairs(Book.Pages.faceplates.items) do assert(not listed[item.id], "a book-only plate counts on the page: " .. item.id) end
		-- Stargazer is listed exactly when this build's DeckThemes has it as a book-only plate.
		local stargazer = Plates.ById.stargazer ~= nil and Plates.isBookOnly("stargazer")
		assert((listed.stargazer ~= nil) == stargazer)
		local function state(claimed, plates) return { book = { claimed = claimed, found = 0 }, faceplates = plates or {} } end
		local three = { "balls.100", "toys.100", "wardrobe.100" }
		assert(#Book.platesOwed(state({})) == 0 and #Book.platesOwed(state({ "balls.100", "toys.100", "balls.75" })) == 0)
		assert(table.concat(Book.platesOwed(state(three)), ",") == "bookworm")
		assert(#Book.platesOwed(state(three, { "bookworm" })) == 0, "a held plate is not owed")
		local onlyDiscoveries = Book.platesOwed(state({ "discoveries.100" }))
		assert(table.concat(onlyDiscoveries, ",") == (if stargazer then "stargazer" else ""), "Stargazer does not need Bookworm")
		local all = Book.platesOwed(state({ "balls.100", "toys.100", "discoveries.100" }))
		assert(table.concat(all, ",") == (if stargazer then "bookworm,stargazer" else "bookworm"))
		-- A repair: Bookworm held, Stargazer missed.
		assert(table.concat(Book.platesOwed(state({ "balls.100", "toys.100", "discoveries.100" }, { "bookworm" })), ",") == (if stargazer then "stargazer" else ""))
		for _, junk in ipairs({ false, 3, "x" }) do assert(#Book.platesOwed(junk) == 0) end
		assert(#Book.platesOwed({ book = "x" }) == 0 and #Book.platesOwed({}) == 0)
		-- The snapshot lists every plate with its state, and keeps the old two fields.
		local public = Book.public(state(three))
		assert(public.faceplate == "bookworm" and public.faceplateEarned == true and #public.plates == #Book.BookOnlyPlates)
		assert(public.plates[1].id == "bookworm" and public.plates[1].earned == true and public.plates[1].owned == false and public.plates[1].rule == "pages3")
		assert(Book.public(state(three, { "bookworm" })).plates[1].owned == true and Book.public(nil).plates[1].earned == false)
	end)

	return cases
end
