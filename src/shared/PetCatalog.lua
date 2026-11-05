local Trials = require(script.Parent.PocketTrials)

local Pets = {
	{ id = "pip", name = "Pip", charge = 6, cue = "pet", color = Color3.fromHex("#FFE0AA") },
	{ id = "puddle", name = "Puddle", charge = 12, cue = "puddle", color = Color3.fromHex("#80D6F2") },
	{ id = "wick", name = "Wick", charge = 24, cue = "wick", color = Color3.fromHex("#F79860") },
	{ id = "orbit", name = "Orbit", charge = 36, cue = "orbit", color = Color3.fromHex("#C7AEF3") },
}

Pets.bloom = {
	id = "bloom_pip", name = "Bloom Pip", family = "pip", trial = Trials.HighRoller,
	cue = "pet", color = Color3.fromHex("#F6A786"),
}
Pets.collection = table.clone(Pets)
table.insert(Pets.collection, Pets.bloom)
Pets.byId = {}
for index, pet in ipairs(Pets.collection) do
	pet.index = index
	Pets.byId[pet.id] = pet
end

function Pets.isUnlocked(pet, rank, trials)
	if pet.trial then
		return bit32.band(trials, pet.trial.bit) ~= 0
	end
	return pet.index <= rank
end

function Pets.ownedCount(rank, trials)
	return math.min(rank, #Pets) + (if Pets.isUnlocked(Pets.bloom, rank, trials) then 1 else 0)
end

return Pets
