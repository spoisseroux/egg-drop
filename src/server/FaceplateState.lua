-- Faceplates bought with Stars (UI-SPEC-2026-11-12 section 5.5). Fixed prices
-- from DeckThemes (faceplates.json), never random. Ownership lives in the fenced
-- hatching record next to the wallet, so a debit and its plate commit together.
local Shared=game:GetService("ReplicatedStorage").Shared
local Themes=require(Shared.DeckThemes)
local Faceplates={Limit=64}
-- Weekly shelf (slice C): a purchase made in shelf week `week` pays the shelf price when the
-- item is on that week's shelf, otherwise the catalogue price. The module is Lane K's; a
-- build without it (or with FeatureFlags.WeeklyShelf off) simply always pays full price.
local shelfModule=Shared:FindFirstChild("WeeklyShelf")
local Shelf=if shelfModule then require(shelfModule)else nil
local function expectedPrice(kind,id,base,week)
	if Shelf==nil or week==nil or type(base)~="number"then return base end
	local price=Shelf.price(kind,id,week)
	-- A shelf price is only ever a discount: a whole number of Stars from 1 up to the base.
	if type(price)=="number"and price==price and price%1==0 and price>=1 and price<=base then return price end
	return base
end

local function validId(id)return type(id)=="string"and #id>0 and #id<=64 end

-- Tolerant: unknown ids from a later catalogue still validate (they are simply
-- never equippable here), so a save never fails over a plate list.
function Faceplates.valid(state)
	local owned=state.faceplates
	if owned==nil then return true end
	if type(owned)~="table"or #owned>Faceplates.Limit then return false end
	local count=0
	for key in pairs(owned)do count+=1;if type(key)~="number"then return false end end
	if count~=#owned then return false end
	for _,id in ipairs(owned)do if not validId(id)then return false end end
	return true
end

function Faceplates.owns(state,id)
	return type(state.faceplates)=="table"and table.find(state.faceplates,id)~=nil
end

-- Pure check shared by the server's early refusal and the UpdateAsync callback. `week` is
-- the shelf week frozen in the purchase (nil = no shelf: the catalogue price).
function Faceplates.check(state,plateId,price,week)
	local expected=Themes.price(plateId)
	if not expected then return false,"NotForSale"end
	expected=expectedPrice("faceplate",plateId,expected,week)
	if price~=nil and price~=expected then return false,"PriceChanged"end
	if Faceplates.owns(state,plateId)then return false,"AlreadyOwned"end
	if #(state.faceplates or {})>=Faceplates.Limit then return false,"OwnedLimit"end
	if state.nectar<expected then return false,"NeedStars"end
	return true,nil,expected
end

-- candidate = { plateId, price, operationId, week }
function Faceplates.apply(state,candidate)
	if type(candidate)~="table"or not validId(candidate.plateId)then return false,"InvalidFaceplate"end
	local ok,why,price=Faceplates.check(state,candidate.plateId,candidate.price,candidate.week)
	if not ok then return false,why end
	local owned=table.clone(state.faceplates or {})
	table.insert(owned,candidate.plateId)
	state.faceplates=owned
	state.nectar-=price
	return true
end

function Faceplates.public(state)
	return {faceplates=table.clone(state.faceplates or {})}
end

return Faceplates
