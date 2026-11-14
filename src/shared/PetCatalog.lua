local Trials = require(script.Parent.PocketTrials)
local BaseColors = require(script.Parent.PetBaseColors)

-- All pets share one voice ("pet" cue) until each new pet gets its own set (Spencer, 2026-11-12).
local Pets = {
	{ id = "pip", name = "Bear", charge = 6, cue = "pet", color = Color3.fromHex("#E5DBD0") },
	{ id = "puddle", name = "Ovelle", charge = 12, cue = "pet", color = Color3.fromHex("#D3DBD9") },
	{ id = "wick", name = "Tikket", charge = 24, cue = "pet", color = Color3.fromHex("#DDD6CA") },
	{ id = "orbit", name = "Nuum", charge = 36, cue = "pet", color = Color3.fromHex("#D9D9D4") },
}

Pets.rares = {
	{ id = "bloom_pip", name = "Vezzi", family = "pip", trial = Trials.HighRoller,
		cue = "pet", color = Color3.fromHex("#E4D9CD") },
	{ id = "foxfire_wick", name = "Kiprik", family = "wick", trial = Trials.Fivefold,
		cue = "pet", color = Color3.fromHex("#DEDAD7"), accent = Color3.fromHex("#AC9DC1") },
	{ id = "eclipse_orbit", name = "Nolli", family = "orbit", trial = Trials.DoubleSweep,
		cue = "pet", color = Color3.fromHex("#D3D3CC"), accent = Color3.fromHex("#9795AC") },
}
Pets.collection = table.clone(Pets)
for _, pet in ipairs(Pets.rares) do
	table.insert(Pets.collection, pet)
end
-- Earned pets (overnight 2026-11-14, slice E): appended after the rares, never into the `Pets`
-- array, so the legacy rank migration (HatchProgress.migrate walks Pets[1..rank]) and every
-- saved bit above are unchanged. Blip is collection index 8 (bit 0x80), granted on the 7th
-- stamp once EarnedPets.enabled("blip"). `ownPalette` keeps his showcase green as the undyed
-- base (SYSTEMS-SCOPE 8 #3) instead of the neutral white pass below.
Pets.earned = {
	{ id = "blip", name = "Blip", cue = "pet", earned = true, ownPalette = true,
		color = Color3.fromHex("#7BD88F"), accent = Color3.fromHex("#D6F5E3") },
}
for _, pet in ipairs(Pets.earned) do
	table.insert(Pets.collection, pet)
end
-- One line under the reveal name plate (UI-SPEC-REDESIGN-CELEBRATIONS 1.4),
-- 60 characters at most, in the garden's warm and quirky voice.
local descriptions = {
	pip = "Soft as a nap. Hugs first, asks questions never.",
	puddle = "Hums to puddles. The puddles have started humming back.",
	wick = "Ticks like a tiny clock. Always early for snacks.",
	orbit = "Floats in slow circles, collecting quiet thoughts.",
	bloom_pip = "A bear in bloom. Smells faintly of tomorrow's picnic.",
	foxfire_wick = "Glows when happy. Glows a lot, honestly.",
	eclipse_orbit = "Borrows the night sky and always gives it back.",
	blip = "Fell off a toy shelf on a faraway moon. Likes it here.",
}
Pets.byId = {}
for index, pet in ipairs(Pets.collection) do
	pet.description = descriptions[pet.id] or "A brand new friend for your garden."
	pet.index = index
	if not pet.ownPalette then pet.color, pet.accent = BaseColors.body, BaseColors.secondary end
	Pets.byId[pet.id] = pet
end
-- Permanent collection/order/ownership bits above retain all seven saved identities.
-- Availability is a separate set; retiring an outcome never deletes an owned pet.
-- v1 (2026-11-11): one pet, Zivvi, met through onboarding. Ovelle, Nuum and
-- Tikket stay in the catalog for a later, more deliberate roster design.
-- Slice E: an earned pet joins the active set only when EarnedPets.enabled() says so (the
-- SecondPet flag and a rig definition), the same gate the server grants with.
do
	local EarnedPets = require(script.Parent.EarnedPets)
	local active, activeById = { Pets.byId.pip }, { pip = true }
	for _, pet in ipairs(Pets.earned) do
		if EarnedPets.enabled(pet.id) then table.insert(active, pet); activeById[pet.id] = true end
	end
	Pets.active = table.freeze(active)
	Pets.activeById = table.freeze(activeById)
end
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
