local Pets = require(script.Parent.PetCatalog)

local Catalog = {
	DailyBonus = 6,
	DayOffsetSeconds = -5 * 3600,
	RareGuarantee = 7,
	Order = { "meadow", "sprout" },
	ById = {
		meadow = {
			name = "Mixed Meadow", cost = 18, color = Color3.fromHex("#C2EC74"),
			weights = {
				{ id = "pip", weight = 35 }, { id = "puddle", weight = 25 },
				{ id = "wick", weight = 20 }, { id = "orbit", weight = 10 },
				{ id = "bloom_pip", weight = 5 }, { id = "foxfire_wick", weight = 3 },
				{ id = "eclipse_orbit", weight = 2 },
			},
		},
		sprout = {
			name = "Sprout Focused", cost = 24, color = Color3.fromHex("#FFB77A"),
			weights = { { id = "pip", weight = 80 }, { id = "bloom_pip", weight = 20 } },
		},
	},
	Families = { "pip", "puddle", "wick", "orbit" },
}

function Catalog.family(id)
	local pet = Pets.byId[id]
	return pet and (pet.family or pet.id) or nil
end

function Catalog.bit(id)
	local pet = Pets.byId[id]
	return if pet then bit32.lshift(1, pet.index - 1) else 0
end

function Catalog.isOwned(mask, id)
	local bit = Catalog.bit(id)
	return bit ~= 0 and bit32.band(mask or 0, bit) ~= 0
end

function Catalog.mask(ids)
	local mask = 0
	for _, id in ipairs(ids) do mask = bit32.bor(mask, Catalog.bit(id)) end
	return mask
end

function Catalog.odds(recipeId, misses)
	local recipe = Catalog.ById[recipeId]
	if not recipe then return {} end
	local guarantee = (misses or 0) >= Catalog.RareGuarantee
	local total = 0
	for _, entry in ipairs(recipe.weights) do
		if not guarantee or Pets.byId[entry.id].trial then total += entry.weight end
	end
	local odds = {}
	for _, entry in ipairs(recipe.weights) do
		if not guarantee or Pets.byId[entry.id].trial then
			table.insert(odds, { id = entry.id, weight = entry.weight / total * 100 })
		end
	end
	return odds
end

function Catalog.roll(recipeId, misses, unit)
	assert(type(unit) == "number" and unit >= 0 and unit < 1, "Random sample must be in [0, 1)")
	local odds = Catalog.odds(recipeId, misses)
	assert(#odds > 0, "Unknown egg recipe")
	local threshold = unit * 100
	local cumulative = 0
	for _, entry in ipairs(odds) do
		cumulative += entry.weight
		if threshold < cumulative then return entry.id end
	end
	return odds[#odds].id
end

return Catalog
