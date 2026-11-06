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
	local done = 0
	for _, bit in pairs(Mastery.ChallengeBits) do
		if bit32.band(challenges, bit) ~= 0 then done += 1 end
	end
	return { rank = rank, name = Mastery.Names[rank] or "Unranked", points = points,
		nextPoints = Mastery.Thresholds[math.min(rank + 1, 3)], challenges = done, challengeGoal = 3,
		hint = if rank < 2 then "Win rounds or hatch duplicates"
			elseif rank < 3 then "25 marks + clean win, chain 3 and score 500" else "Family mastered" }
end

function Mastery.challengeMask(summary)
	if not summary.success then return 0 end
	return bit32.bor(if summary.clean then 1 else 0,
		if summary.chain >= 3 then 2 else 0, if summary.score >= 500 then 4 else 0)
end

return Mastery
