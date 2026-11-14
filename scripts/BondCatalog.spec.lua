-- Bond levels (BondCatalog, slice F) and earned charm shapes (PetCharmCatalog, slice D):
-- thresholds 25 / 75 / 150 / 250, the level display capped at 5 while xp keeps accruing,
-- one unlock per shipped level, and the stateless charm rules.
-- Pure shared data; no DataStore, no instances.
-- Usage (Server): require(ServerScriptService.Server.ZZSpecs.BondCatalog)(ServerScriptService.Server)
-- The second argument (optional) is the Shared folder to read; it defaults to ReplicatedStorage.Shared.
return function(_, shared)
	local Shared = shared or game:GetService("ReplicatedStorage").Shared
	local Bond = require(Shared.BondCatalog)
	local Charms = require(Shared.PetCharmCatalog)
	local UICopy = require(Shared.UICopy)
	local cases = {}
	local function test(name, run) run(); table.insert(cases, name) end

	test("thresholds rise strictly: 0 / 25 / 75 / 150 / 250, with levels 6 to 10 reserved", function()
		assert(Bond.MaxLevelShipped == 5 and Bond.MaxXP == 100000)
		for level, xp in ipairs({ 0, 25, 75, 150, 250 }) do assert(Bond.Thresholds[level] == xp and Bond.threshold(level) == xp, level) end
		assert(#Bond.Thresholds == 10 and Bond.threshold(11) == nil and Bond.threshold(0) == nil)
		for level = 2, #Bond.Thresholds do assert(Bond.Thresholds[level] > Bond.Thresholds[level - 1], level) end
		assert(Bond.XP.pet == 1 and Bond.XP.round == 2 and Bond.XP.win == 3 and Bond.XP.playDate == 5)
	end)

	test("level(xp): every boundary, and the display caps at 5 however much xp accrues", function()
		for xp, level in pairs({ [0] = 1, [1] = 1, [24] = 1, [25] = 2, [74] = 2, [75] = 3, [149] = 3, [150] = 4, [249] = 4, [250] = 5, [251] = 5, [349] = 5, [350] = 5, [850] = 5, [100000] = 5 }) do
			assert(Bond.level(xp) == level, xp .. " -> " .. Bond.level(xp))
		end
		-- Missing and malformed xp read as level 1; nothing here can error.
		for _, junk in ipairs({ false, "40", {}, -3, 0 / 0, -math.huge }) do assert(Bond.level(junk) == 1 and Bond.clamp(junk) == 0) end
		assert(Bond.level(nil) == 1 and Bond.level(math.huge) == 5 and Bond.clamp(math.huge) == Bond.MaxXP and Bond.clamp(1e9) == Bond.MaxXP)
		assert(Bond.level(24.9) == 1 and Bond.clamp(24.9) == 24 and Bond.level(25.2) == 2)
		local previous = 1
		for xp = 0, 400 do local level = Bond.level(xp); assert(level >= previous and level - previous <= 1, xp); previous = level end
	end)

	test("progress(xp): the bar toward the next shipped level, full and capped at level 5", function()
		local p = Bond.progress(0); assert(p.level == 1 and p.floor == 0 and p.next == 25 and p.fraction == 0 and not p.capped)
		p = Bond.progress(50); assert(p.level == 2 and p.floor == 25 and p.next == 75 and math.abs(p.fraction - .5) < 1e-9)
		p = Bond.progress(249); assert(p.level == 4 and p.next == 250 and p.fraction < 1 and p.fraction > .98)
		p = Bond.progress(250); assert(p.level == 5 and p.next == nil and p.fraction == 1 and p.capped == true and p.xp == 250)
		p = Bond.progress(9999); assert(p.level == 5 and p.capped and p.xp == 9999, "xp is kept past the shipped cap")
		p = Bond.progress("x"); assert(p.level == 1 and p.xp == 0)
		assert(Bond.xpOf({ pip = 80 }, "pip") == 80 and Bond.xpOf({ pip = 80 }, "blip") == 0 and Bond.xpOf(nil, "pip") == 0 and Bond.xpOf({ pip = "x" }, "pip") == 0 and Bond.xpOf({ pip = 5 }, nil) == 0)
	end)

	test("one unlock per shipped level, named in UICopy and built from existing beats", function()
		assert(#Bond.Unlocks == Bond.MaxLevelShipped)
		local beats = { wave = true, sit = true, wiggle = true, stretch = true }
		local ids = {}
		for level, unlock in ipairs(Bond.Unlocks) do
			assert(unlock.level == level and Bond.unlock(level) == unlock and not ids[unlock.id], level); ids[unlock.id] = true
			assert(unlock.copy == "bond.trick.l" .. level and UICopy.has(unlock.copy), "no UICopy name for level " .. level)
			assert(#unlock.beats >= 1); for _, beat in ipairs(unlock.beats) do assert(beats[beat], unlock.id .. " uses " .. beat) end
		end
		assert(Bond.Unlocks[5].hearts == true and Bond.unlock(6) == nil)
		assert(#Bond.unlocked(0) == 1 and #Bond.unlocked(75) == 3 and #Bond.unlocked(100000) == 5 and Bond.unlocked(150)[4].id == "stretch")
	end)

	test("charm shapes: three free, Heart and Star earned by monotonic rules, Leaf reserved until its mesh ships", function()
		assert(table.concat(Charms.Order, ",") == "dot,ring,pebble,heart,star" and Charms.Default == "dot" and Charms.Version == 2)
		for _, id in ipairs(Charms.Order) do assert(Charms.known(id) and type(Charms.ById[id].name) == "string" and Charms.renderShape(id) == id, id) end
		for _, id in ipairs({ "dot", "ring", "pebble" }) do
			assert(Charms.rule(id) == nil and Charms.earned(id, nil) and Charms.earned(id, {}) and Charms.progress(id, nil).earned, id)
		end
		assert(not Charms.known("leaf") and Charms.Reserved.leaf.rule == "stamps14" and Charms.Rules.stamps14.need == 14 and not Charms.earned("leaf", { stamps = 99 }))
		assert(Charms.renderShape("leaf") == "dot" and Charms.validStored("leaf"), "a stored future shape survives and draws the default")
		assert(Charms.ById.heart.mesh == "Bear__CharmHeart" and Charms.ById.star.mesh == "Bear__CharmStar")
		-- Heart: the book's Wardrobe page claimed at 100%.
		assert(not Charms.earned("heart", nil) and not Charms.earned("heart", {}) and not Charms.earned("heart", { claimed = { "wardrobe.75", "balls.100" } }))
		assert(Charms.earned("heart", { claimed = { "balls.100", "wardrobe.100" } }))
		-- Star: four weekly bonuses; a save without the counter is simply not there yet.
		assert(not Charms.earned("star", { stats = {} }) and not Charms.earned("star", { stats = { weeklyBonuses = 3 } }))
		assert(Charms.earned("star", { stats = { weeklyBonuses = 4 } }) and Charms.earned("star", { stats = { weeklyBonuses = 40 } }))
		assert(not Charms.earned("star", { stats = { weeklyBonuses = "4" } }) and not Charms.earned("star", { stats = "x" }) and not Charms.earned("star", { claimed = { "wardrobe.100" } }))
		-- Unknown ids are never earned.
		assert(not Charms.earned("nope", { stamps = 99 }) and not Charms.earned(nil, {}) and not Charms.earned(4, {}))
		local p = Charms.progress("star", { stats = { weeklyBonuses = 3 } }); assert(p.have == 3 and p.need == 4 and not p.earned)
		p = Charms.progress("star", { stats = { weeklyBonuses = 9 } }); assert(p.have == 4 and p.need == 4 and p.earned)
		p = Charms.progress("heart", {}); assert(p.have == 0 and p.need == 1 and not p.earned)
		p = Charms.progress("nope", {}); assert(not p.earned)
	end)

	test("facts(state) reads a save or its snapshot: stamps, claimed, stats, bond", function()
		local facts = Charms.facts({ stamps = 9, book = { claimed = { "wardrobe.100" }, found = 0 }, stats = { weeklyBonuses = 4 }, bond = { pip = 30 } })
		assert(facts.stamps == 9 and facts.claimed[1] == "wardrobe.100" and facts.stats.weeklyBonuses == 4 and facts.bond.pip == 30)
		assert(Charms.earned("heart", facts) and Charms.earned("star", facts))
		for _, junk in ipairs({ false, 3, "x", {} }) do
			local empty = Charms.facts(junk)
			assert(empty.stamps == 0 and #empty.claimed == 0 and next(empty.stats) == nil and next(empty.bond) == nil)
			assert(not Charms.earned("heart", empty) and not Charms.earned("star", empty) and Charms.earned("dot", empty))
		end
		assert(Charms.facts(nil).stamps == 0 and Charms.facts({ stamps = "x", book = { claimed = 3 }, stats = 4, bond = 5 }).stamps == 0)
	end)

	return cases
end
