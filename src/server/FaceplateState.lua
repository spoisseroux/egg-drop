-- Faceplates bought with Stars (UI-SPEC-2026-11-12 section 5.5). Fixed prices
-- from DeckThemes (faceplates.json), never random. Ownership lives in the fenced
-- hatching record next to the wallet, so a debit and its plate commit together.
local Themes=require(game:GetService("ReplicatedStorage").Shared.DeckThemes)
local Faceplates={Limit=64}

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

-- Pure check shared by the server's early refusal and the UpdateAsync callback.
function Faceplates.check(state,plateId,price)
	local expected=Themes.price(plateId)
	if not expected then return false,"NotForSale"end
	if price~=nil and price~=expected then return false,"PriceChanged"end
	if Faceplates.owns(state,plateId)then return false,"AlreadyOwned"end
	if #(state.faceplates or {})>=Faceplates.Limit then return false,"OwnedLimit"end
	if state.nectar<expected then return false,"NeedStars"end
	return true,nil,expected
end

-- candidate = { plateId, price, operationId }
function Faceplates.apply(state,candidate)
	if type(candidate)~="table"or not validId(candidate.plateId)then return false,"InvalidFaceplate"end
	local ok,why,price=Faceplates.check(state,candidate.plateId,candidate.price)
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
