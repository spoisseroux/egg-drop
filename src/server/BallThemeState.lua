-- Ball themes bought with Stars (hatching v11, batch 2026-11-13 R1). Fixed prices
-- from Shared.BallThemes, never random. Ownership and the equipped id live in the
-- fenced hatching record next to the wallet, so a debit and its theme commit together.
--
-- state.ballThemes = { owned = {themeId, ...}, equipped = themeId }
-- Free themes (Smileys, Marbles) are always owned; `owned` also lists them from the
-- upgrade so a later catalogue that prices one cannot take it away.
local Shared=game:GetService("ReplicatedStorage").Shared
local Themes=require(Shared.BallThemes)
local State={Limit=Themes.Limit}
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

local function validId(id)return type(id)=="string"and #id>0 and #id<=32 end
local function copy(v)if type(v)~="table"then return v end;local r={};for k,x in pairs(v)do r[k]=copy(x)end;return r end

function State.fresh()return{owned={"smileys","marbles"},equipped=Themes.Default}end

-- Tolerant of ids from a later catalogue (kept, never equippable here); strict on
-- shape: an array of distinct ids, at most Limit, and an equipped id that is owned.
function State.valid(state)
	local row=state.ballThemes
	if type(row)~="table"or type(row.owned)~="table"or not validId(row.equipped)then return false end
	for key in pairs(row)do if key~="owned"and key~="equipped"then return false end end
	local count,seen=0,{}
	for key in pairs(row.owned)do count+=1;if type(key)~="number"then return false end end
	if count~=#row.owned or count>State.Limit then return false end
	for _,id in ipairs(row.owned)do if not validId(id)or seen[id]then return false end;seen[id]=true end
	return seen[row.equipped]==true or Themes.isFree(row.equipped)
end

function State.owns(state,id)
	local row=state.ballThemes
	return Themes.owns(row and row.owned,id)
end
function State.equipped(state)
	local row=state.ballThemes
	return if row and Themes.ById[row.equipped]then row.equipped else Themes.Default
end

-- Pure check shared by the server's early refusal and the UpdateAsync callback. `week` is
-- the shelf week frozen in the purchase (nil = no shelf: the catalogue price).
function State.check(state,themeId,price,week)
	local expected=Themes.price(themeId)
	if not expected then return false,"NotForSale"end
	expected=expectedPrice("ball",themeId,expected,week)
	if price~=nil and price~=expected then return false,"PriceChanged"end
	if State.owns(state,themeId)then return false,"AlreadyOwned"end
	if #((state.ballThemes or {}).owned or {})>=State.Limit then return false,"OwnedLimit"end
	if state.nectar<expected then return false,"NeedStars"end
	return true,nil,expected
end

-- candidate = { themeId, price, operationId, equip, week }
function State.applyBuy(state,candidate)
	if type(candidate)~="table"or not validId(candidate.themeId)then return false,"InvalidBallTheme"end
	local ok,why,price=State.check(state,candidate.themeId,candidate.price,candidate.week)
	if not ok then return false,why end
	local row=copy(state.ballThemes or State.fresh())
	table.insert(row.owned,candidate.themeId)
	if candidate.equip then row.equipped=candidate.themeId end
	state.ballThemes=row
	state.nectar-=price
	return true
end

-- candidate = { themeId, operationId }
function State.applyEquip(state,candidate)
	if type(candidate)~="table"or not validId(candidate.themeId)or not Themes.ById[candidate.themeId]then return false,"InvalidBallTheme"end
	if not State.owns(state,candidate.themeId)then return false,"Unowned"end
	local row=copy(state.ballThemes or State.fresh())
	if row.equipped==candidate.themeId then return false,"NoChange"end
	row.equipped=candidate.themeId
	state.ballThemes=row
	return true
end

function State.public(state)
	local row=state.ballThemes or State.fresh()
	return{ballThemes={owned=table.clone(row.owned),equipped=State.equipped(state)}}
end

return State
