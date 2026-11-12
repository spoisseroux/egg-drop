-- require(ZZSpecs.HeatPayout)() in any datamodel (shared modules only).
return function()
	local Shared = game:GetService("ReplicatedStorage").Shared
	local Config = require(Shared.BoardConfig)
	local Payout = require(Shared.HeatPayout)
	local passed = {}
	local function test(name, fn) fn(); table.insert(passed, name) end

	test("medium is today's round", function()
		local m = Config.Heat.medium
		assert(m.tenths == 10 and m.overflowY == 8.6 and m.grace == 2.4 and m.armAfter == 12 and m.bonusHeight == 7.5)
		assert(table.concat(m.bag, ",") == "1,1,1,1,2,2" and m.goals == 2)
		assert(Config.DefaultHeat == "medium" and Config.validHeat("hard") and not Config.validHeat("insane") and not Config.validHeat(nil))
	end)
	test("the tidy line moves with the overflow line", function()
		for _, key in ipairs(Config.HeatOrder) do
			local h = Config.Heat[key]
			assert(math.abs((h.overflowY - h.bonusHeight) - 1.1) < 1e-9, key)
		end
		assert(Config.Heat.hard.goals == 3 and Config.Heat.easy.goals == 2)
	end)
	test("win and tidy win per heat", function()
		local expect = { easy = { 5, 6 }, medium = { 6, 8 }, hard = { 9, 12 } }
		for key, pair in pairs(expect) do
			assert(Payout.roundStars(6, key) == pair[1] and Payout.roundStars(8, key) == pair[2], key)
			assert(Payout.roundStars(0, key) == 0)
			local low, high = Payout.range(key)
			assert(low == pair[1] and high == pair[2])
		end
	end)
	test("every heat x tidy x pass x supporter", function()
		local order = { easy = 1, medium = 2, hard = 3 }
		local seen = {}
		for _, key in ipairs(Config.HeatOrder) do
			for _, amount in ipairs({ 0, 6, 8 }) do
				for _, mult in ipairs({ 1, 2 }) do
					for _, bonus in ipairs({ 0, 1 }) do
						local total = Payout.total(amount, key, { multiplier = mult, bonus = bonus })
						assert(total == Payout.roundStars(amount, key) * mult + bonus)
						seen[key .. amount .. mult .. bonus] = total
					end
				end
			end
		end
		-- Harder always pays more for the same win.
		for _, amount in ipairs({ 6, 8 }) do
			for _, mult in ipairs({ 1, 2 }) do
				for _, bonus in ipairs({ 0, 1 }) do
					local e, m, h = seen["easy" .. amount .. mult .. bonus], seen["medium" .. amount .. mult .. bonus], seen["hard" .. amount .. mult .. bonus]
					assert(h > m and m > e)
				end
			end
		end
		assert(Payout.total(8, "hard", { multiplier = 2, bonus = 1 }) == 25)
		assert(Payout.total(6, "easy", { multiplier = 2, bonus = 1 }) == 11)
		-- Malformed boosts never inflate.
		assert(Payout.total(8, "hard", { multiplier = 9, bonus = 7 }) == 12)
		local _ = order
	end)
	test("labels", function()
		assert(Payout.label("easy") == "×0.8" and Payout.label("medium") == "×1" and Payout.label("hard") == "×1.5")
		assert(Payout.rangeText("hard") == "9–12" and Payout.rangeText("easy", { multiplier = 2 }) == "10–12")
		assert(not pcall(Payout.roundStars, 6, "nope"))
	end)
	return { passed = #passed, cases = passed }
end
