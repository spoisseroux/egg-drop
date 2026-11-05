local highRoller = { bit = 2, name = "High Roller", hint = "Score 250 in one round", target = 250, readout = "Points" }
local fivefold = { bit = 8, name = "Fivefold", hint = "Chain 5 merges", target = 5, readout = "Chain" }
local doubleSweep = {
	bit = 16, name = "Double Sweep", hint = "Clear 2 tier V pairs in one round", target = 2, readout = "Tier V pairs",
}
local Trials = {
	Goals = {
		{ bit = 1, name = "Triple Pop", hint = "Chain 3 merges", target = 3 },
		highRoller,
		{ bit = 4, name = "Clean Sweep", hint = "Merge two tier V jellies", target = 1 },
	},
	ClubMask = 7,
	RareMask = 24,
	All = 31,
	HighRoller = highRoller,
	Fivefold = fivefold,
	DoubleSweep = doubleSweep,
}

function Trials.mask(value)
	return if type(value) == "number" and value >= 0 and value <= Trials.All and value == math.floor(value)
		then value else 0
end

function Trials.clubComplete(mask)
	return bit32.band(mask, Trials.ClubMask) == Trials.ClubMask
end

function Trials.earned(mask, chain, score, clears)
	return bit32.bor(mask, if chain >= Trials.Goals[1].target then 1 else 0,
		if score >= highRoller.target then highRoller.bit else 0, if clears >= 1 then 4 else 0,
		if chain >= fivefold.target then fivefold.bit else 0, if clears >= doubleSweep.target then doubleSweep.bit else 0)
end

return Trials
