local Pets = require(script.Parent.PetCatalog)

local Catalog = {
	DailyBonus = 6, -- Legacy flat gift; the daily gift now pays StampCard.reward(stamps) (play-forever F1).
	DuplicateRefund = 0.5,
	DayOffsetSeconds = -5 * 3600,
	RareGuarantee = 7,
	Order = { "meadow" },
	ById = {
		-- Retired for v1 (one pet, Zivvi). The server refuses retired recipes.
		meadow = {
			retired = true,
			name = "Mixed Meadow", cost = 18, color = Color3.fromHex("#C2EC74"),
			weights = {
				-- Whole percentages that sum to 100, shown before purchase.
				{ id = "pip", weight = 40 }, { id = "puddle", weight = 28 },
				{ id = "wick", weight = 22 }, { id = "orbit", weight = 10 },
			},
		},
		sprout = {
			retired = true,
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
	if not recipe or recipe.retired then return {} end
	local guarantee = (misses or 0) >= Catalog.RareGuarantee and Catalog.hasRarePool(recipeId)
	local total = 0
	for _, entry in ipairs(recipe.weights) do
		if Pets.isActive(entry.id)and(not guarantee or Pets.byId[entry.id].trial)then total += entry.weight end
	end
	local odds = {}
	for _, entry in ipairs(recipe.weights) do
		if Pets.isActive(entry.id)and(not guarantee or Pets.byId[entry.id].trial)then
			table.insert(odds, { id = entry.id, weight = entry.weight / total * 100 })
		end
	end
	return odds
end

function Catalog.hasRarePool(recipeId)
 local recipe=Catalog.ById[recipeId]
 if not recipe or recipe.retired then return false end
 for _,entry in ipairs(recipe.weights)do if entry.weight>0 and Pets.isActive(entry.id)and Pets.byId[entry.id].trial then return true end end
 return false
end

-- Restricted players (ArePaidRandomItemsRestricted, BUILD-PLAN F1 architect change 6) never
-- get a random roll: the next active pet in the recipe's published order that they do not
-- own yet, else the first. Deterministic from the save, so it can be shown before buying.
function Catalog.fixedNext(recipeId, inventoryMask)
	local recipe = Catalog.ById[recipeId]
	if not recipe or recipe.retired then return nil end
	local first
	for _, entry in ipairs(recipe.weights) do
		if entry.weight > 0 and Pets.isActive(entry.id) then
			first = first or entry.id
			if not Catalog.isOwned(inventoryMask, entry.id) then return entry.id end
		end
	end
	return first
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
