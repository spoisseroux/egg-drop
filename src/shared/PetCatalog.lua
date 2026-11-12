local Trials = require(script.Parent.PocketTrials)
local BaseColors = require(script.Parent.PetBaseColors)

local Pets = {
	{ id = "pip", name = "Bear", charge = 6, cue = "pet", color = Color3.fromHex("#E5DBD0") },
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
	pet.color, pet.accent = BaseColors.body, BaseColors.secondary
	Pets.byId[pet.id] = pet
end
-- Permanent collection/order/ownership bits above retain all seven saved identities.
-- Availability is a separate set; retiring an outcome never deletes an owned pet.
-- v1 (2026-11-11): one pet, Zivvi, met through onboarding. Ovelle, Nuum and
-- Tikket stay in the catalog for a later, more deliberate roster design.
Pets.active = table.freeze({Pets.byId.pip})
Pets.activeById = table.freeze({pip=true})
function Pets.isActive(pet)
 return Pets.activeById[if type(pet)=="table"then pet.id else pet]==true
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

function Pets.activeOwnedCount(rank, trials, inventoryMask)
 local count=0
 for _,pet in ipairs(Pets.active)do if Pets.isUnlocked(pet,rank,trials,inventoryMask)then count+=1 end end
 return count
end
function Pets.collectionSummary(rank,trials,inventoryMask)
 local active=Pets.activeOwnedCount(rank,trials,inventoryMask)
 local retained=Pets.ownedCount(rank,trials,inventoryMask)-active
 return string.format("%02d/%02d",active,#Pets.active)..(if retained>0 then " · "..retained.." retained"else "")
end

return Pets
