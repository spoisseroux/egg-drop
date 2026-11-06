local Catalog = require(script.Parent.EggCatalog)

local Mastery = {
	Thresholds = { 3, 10, 25 },
	Names = { "Sprout", "Grove", "Bloom" },
	ChallengeBits = { clean = 1, chain = 2, score = 4 },
	ChallengeGoal = 7,
	MaxPoints = 1000000,
}

function Mastery.ownsFamily(inventoryMask, family)
	if not table.find(Catalog.Families, family) then return false end
	if Catalog.isOwned(inventoryMask, family) then return true end
	for _, id in ipairs({ "bloom_pip", "foxfire_wick", "eclipse_orbit" }) do
		if Catalog.family(id) == family and Catalog.isOwned(inventoryMask, id) then return true end
	end
	return false
end

function Mastery.rank(points, challenges)
	if points >= Mastery.Thresholds[3] and challenges == Mastery.ChallengeGoal then return 3 end
	if points >= Mastery.Thresholds[2] then return 2 end
	if points >= Mastery.Thresholds[1] then return 1 end
	return 0
end

function Mastery.describe(points, challenges)
	local rank = Mastery.rank(points, challenges)
	local missing, done = {}, 0
	for _, condition in ipairs({
		{ bit = Mastery.ChallengeBits.clean, title = "Clean win" },
		{ bit = Mastery.ChallengeBits.chain, title = "Win with a chain of 3" },
		{ bit = Mastery.ChallengeBits.score, title = "Win with 500 points" },
	}) do
		if bit32.band(challenges, condition.bit) ~= 0 then done += 1
		else table.insert(missing, condition.title) end
	end
	local nextRank = if rank < 3 then rank + 1 else nil
	local nextPoints = Mastery.Thresholds[math.min(rank + 1, 3)]
	local marksRemaining = if nextRank then math.max(0, nextPoints - points) else 0
	local nextGoal = if not nextRank then "Family mastered"
		elseif marksRemaining > 0 then string.format("%d %s to rank %s", marksRemaining,
			if marksRemaining == 1 then "mark" else "marks", ({ "I", "II", "III" })[nextRank])
		else missing[1] or "Family mastered"
	return { rank = rank, name = Mastery.Names[rank] or "Unranked", points = points,
		nextPoints = nextPoints, challenges = done, challengeGoal = 3,
		hint = if rank < 2 then "Win rounds or hatch duplicates"
			elseif rank < 3 then "25 marks + clean win, chain 3 and score 500" else "Family mastered",
		nextRank = nextRank, marksRemaining = marksRemaining, missingChallenges = missing, nextGoal = nextGoal,
		rewardHint = if rank == 0 then "Next: family badge" elseif rank == 1 then "Next: outlined family crest"
			elseif rank == 2 then "Next: blooming family effect" else "Bloom family effect unlocked" }
end

function Mastery.challengeMask(summary)
	if not summary.success then return 0 end
	return bit32.bor(if summary.clean then 1 else 0,
		if summary.chain >= 3 then 2 else 0, if summary.score >= 500 then 4 else 0)
end

return Mastery
