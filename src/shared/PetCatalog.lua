local Trials = require(script.Parent.PocketTrials)

local Pets = {
	{ id = "pip", name = "Zivvi", charge = 6, cue = "pet", color = Color3.fromHex("#E5DBD0") },
	{ id = "puddle", name = "Ovelle", charge = 12, cue = "puddle", color = Color3.fromHex("#D3DBD9") },
	{ id = "wick", name = "Tikket", charge = 24, cue = "wick", color = Color3.fromHex("#DDD6CA") },
	{ id = "orbit", name = "Nuum", charge = 36, cue = "orbit", color = Color3.fromHex("#D9D9D4") },
}

Pets.rares = {
	{ id = "bloom_pip", name = "Vezzi", family = "pip", trial = Trials.HighRoller,
		cue = "pet", color = Color3.fromHex("#E4D9CD") },
	{ id = "foxfire_wick", name = "Kiprik", family = "wick", trial = Trials.Fivefold,
		cue = "wick", color = Color3.fromHex("#DEDAD7"), accent = Color3.fromHex("#AC9DC1") },
	{ id = "eclipse_orbit", name = "Nolli", family = "orbit", trial = Trials.DoubleSweep,
		cue = "orbit", color = Color3.fromHex("#D3D3CC"), accent = Color3.fromHex("#9795AC") },
}
Pets.collection = table.clone(Pets)
for _, pet in ipairs(Pets.rares) do
	table.insert(Pets.collection, pet)
end
Pets.byId = {}
for index, pet in ipairs(Pets.collection) do
	pet.index = index
	Pets.byId[pet.id] = pet
end

function Pets.isUnlocked(pet, rank, trials, inventoryMask)
	if inventoryMask ~= nil then
		return bit32.band(inventoryMask, bit32.lshift(1, pet.index - 1)) ~= 0
	end
	if pet.trial then
		return bit32.band(trials, pet.trial.bit) ~= 0
	end
	return pet.index <= rank
end

function Pets.ownedCount(rank, trials, inventoryMask)
	if inventoryMask ~= nil then
		local count = 0
		for _, pet in ipairs(Pets.collection) do
			if Pets.isUnlocked(pet, rank, trials, inventoryMask) then count += 1 end
		end
		return count
	end
	local count = math.min(rank, #Pets)
	for _, pet in ipairs(Pets.rares) do
		if Pets.isUnlocked(pet, rank, trials) then
			count += 1
		end
	end
	return count
end

return Pets
