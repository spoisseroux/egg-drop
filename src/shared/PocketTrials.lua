local Trials = {
	Goals = {
		{ bit = 1, name = "Triple Pop", hint = "Chain 3 merges", target = 3 },
		{ bit = 2, name = "High Roller", hint = "Score 250 in one round", target = 250 },
		{ bit = 4, name = "Clean Sweep", hint = "Merge two tier V jellies", target = 1 },
	},
	All = 7,
}

function Trials.mask(value)
	return if type(value) == "number" and value >= 0 and value <= Trials.All and value == math.floor(value)
		then value else 0
end

function Trials.earned(mask, chain, score, cleared)
	return bit32.bor(mask, if chain >= Trials.Goals[1].target then 1 else 0,
		if score >= Trials.Goals[2].target then 2 else 0, if cleared then 4 else 0)
end

return Trials
