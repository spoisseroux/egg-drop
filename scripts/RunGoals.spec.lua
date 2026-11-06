-- Native fixtures for authoritative progress descriptions and receipt fencing.
return function(client)
	local Mastery = require(game.ReplicatedStorage.Shared.FamilyMastery)
	local Catalog = require(game.ReplicatedStorage.Shared.EggCatalog)
	local Receipt = require(client.RunReceipt)
	local cases = {}
	local function test(name, body) body(); table.insert(cases, name) end
	test("all four families retain their rank thresholds and completion flags", function()
		for _, family in ipairs(Catalog.Families) do
			assert(Mastery.ownsFamily(Catalog.mask({family}), family))
			for mask = 0, 7 do
				for _, points in ipairs({0, 2, 3, 9, 10, 24, 25, 35}) do
					local d = Mastery.describe(points, mask)
					assert(d.rank == Mastery.rank(points, mask))
					assert(#d.missingChallenges + d.challenges == 3 and d.challengeGoal == 3)
					assert(d.marksRemaining >= 0 and d.nextPoints == ({3,10,25})[math.min(d.rank+1,3)])
					assert(d.nextGoal and d.rewardHint)
				end
			end
		end
	end)
	test("early goals name the exact remaining marks and next rank", function()
		assert(Mastery.describe(2,0).nextGoal == "1 mark to rank I")
		assert(Mastery.describe(3,0).nextGoal == "7 marks to rank II")
		assert(Mastery.describe(10,0).nextGoal == "15 marks to rank III")
	end)
	test("25 marks missing only chain names the win requirement", function()
		local d = Mastery.describe(25,5)
		assert(d.rank == 2 and d.marksRemaining == 0 and d.nextGoal == "Win with a chain of 3")
		assert(#d.missingChallenges == 1 and d.missingChallenges[1] == d.nextGoal)
	end)
	test("mastered families never predict another rank or negative marks", function()
		local d = Mastery.describe(35,7)
		assert(d.rank == 3 and d.nextRank == nil and d.marksRemaining == 0 and #d.missingChallenges == 0)
		assert(d.nextGoal == "Family mastered")
	end)
	test("failed skill contracts cannot record mastery win challenges", function()
		assert(Mastery.challengeMask({success=false,clean=false,chain=5,score=900}) == 0)
		assert(Mastery.challengeMask({success=true,clean=true,chain=3,score=500}) == 7)
	end)
	test("prior equal-value receipt and promotion cannot enter a new recap", function()
		local s = {lastRunReward={sequence=8,total=8,promotedTo=1,family="pip"}}
		assert(Receipt.select(s,9,"Saved",true) == nil)
		assert(Receipt.select(s,8,"Saved",true) == s.lastRunReward)
	end)
	test("late snapshot and non-saved states remain unconfirmed", function()
		local s = {lastRunReward={sequence=9,total=6}}
		assert(Receipt.select({},9,"Saved",true) == nil)
		for _,status in ipairs({"", "Saving", "Retrying", "Busy"}) do assert(Receipt.select(s,9,status,true) == nil) end
		assert(Receipt.select(s,9,"Saved",false) == nil)
	end)
	test("receipt stays attached to the played family", function()
		local s = {selectedFamily="wick",lastRunReward={sequence=9,family="pip",masteryPoints=1}}
		assert(Receipt.select(s,9,"Saved",true).family == "pip")
	end)
	return {passed=#cases,cases=cases}
end
