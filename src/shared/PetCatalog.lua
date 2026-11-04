local Pets = {
	{ id = "pip", name = "Pip", charge = 6, cue = "pet", color = Color3.fromHex("#FFE0AA") },
	{ id = "puddle", name = "Puddle", charge = 12, cue = "puddle", color = Color3.fromHex("#80D6F2") },
	{ id = "wick", name = "Wick", charge = 24, cue = "wick", color = Color3.fromHex("#F79860") },
	{ id = "orbit", name = "Orbit", charge = 36, cue = "orbit", color = Color3.fromHex("#C7AEF3") },
}

Pets.byId = {}
for index, pet in ipairs(Pets) do
	pet.index = index
	Pets.byId[pet.id] = pet
end

return Pets
