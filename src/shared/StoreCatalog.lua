-- Robux store for v1 (prices chosen 2026-11-11; see TODO.md "Launch prices").
-- Ids are the Creator Dashboard ids for universe 10774758591 (created 2026-11-11,
-- Managed Pricing off). An entry with id 0 is listed but cannot be prompted.
-- `price` must match the dashboard price.
local Store = {}

Store.Passes = table.freeze({
	table.freeze({ key = "doubleStars", id = 2078960411, price = 299, name = "2× Stars",
		blurb = "Double Stars from every round and quest. Forever." }),
	table.freeze({ key = "supporter", id = 2078804439, price = 99, name = "Supporter",
		blurb = "+1 Star for every finished round. Thank you!" }),
})

-- `once` products can be prompted a single time per player (server enforced).
Store.Products = table.freeze({
	table.freeze({ key = "starter", id = 3730431023, price = 49, stars = 40, once = true, name = "Starter pack",
		blurb = "40 Stars to get your garden going. One per player." }),
	table.freeze({ key = "handful", id = 3730431114, price = 39, stars = 20, name = "Handful of Stars" }),
	table.freeze({ key = "pouch", id = 3730431153, price = 99, stars = 60, name = "Pouch of Stars" }),
	table.freeze({ key = "jar", id = 3730431202, price = 199, stars = 140, name = "Jar of Stars" }),
	table.freeze({ key = "chest", id = 3730431229, price = 499, stars = 400, name = "Chest of Stars" }),
})

-- Pass effects on a saved round reward. Applied inside the fenced transaction.
Store.DoubleStarsMultiplier = 2
Store.SupporterRoundBonus = 1

Store.PassByKey, Store.PassById, Store.ProductByKey, Store.ProductById = {}, {}, {}, {}
for _, pass in ipairs(Store.Passes) do
	Store.PassByKey[pass.key] = pass
	if pass.id > 0 then Store.PassById[pass.id] = pass end
end
for _, product in ipairs(Store.Products) do
	Store.ProductByKey[product.key] = product
	if product.id > 0 then Store.ProductById[product.id] = product end
end

function Store.configured(entry)
	return type(entry) == "table" and type(entry.id) == "number" and entry.id > 0
end

-- The round boost a player's passes give. Pure; used by server and recap text.
function Store.boost(passes)
	passes = type(passes) == "table" and passes or {}
	return {
		multiplier = if passes.doubleStars == true then Store.DoubleStarsMultiplier else 1,
		bonus = if passes.supporter == true then Store.SupporterRoundBonus else 0,
	}
end

return table.freeze(Store)
