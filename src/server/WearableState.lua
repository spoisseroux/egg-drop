-- Pet wearables bought with Stars (hatching v10). Fixed prices from WearableCatalog
-- (the rig definition's `wearableItems`), never random. Ownership and the equipped
-- map live in the fenced hatching record next to the wallet, so a debit, its item
-- and an equip commit together.
--
-- state.petWearables = { [petId] = { owned = {itemId, ...}, equipped = {slotKey = itemId} } }
-- Slot keys match PetAttachmentRules ("Hat", "EarPiercingL", ...). Exclusions hide,
-- never unequip, so equipping only ever writes the item's own slot keys.
local Shared=game:GetService("ReplicatedStorage").Shared
local Catalog=require(Shared.WearableCatalog)
local Eggs=require(Shared.EggCatalog)
local State={Limit=Catalog.OwnedLimit,KeyLimit=24}
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

local function id(v)return type(v)=="string"and #v>0 and #v<=32 end
local function copy(v)if type(v)~="table"then return v end;local r={};for k,x in pairs(v)do r[k]=copy(x)end;return r end

function State.upgrade(state)
	local s=copy(state);s.version=10;s.petWearables={};return s
end

-- Tolerant of item ids from a later catalogue (they are simply never shown here),
-- strict on shape, ownership of the pet, and equipped items being owned.
function State.valid(state)
	local rows=state.petWearables
	if type(rows)~="table"then return false end
	for pet,row in pairs(rows)do
		if type(pet)~="string"or not Eggs.isOwned(state.inventoryMask,pet)then return false end
		if type(row)~="table"or type(row.owned)~="table"or type(row.equipped)~="table"then return false end
		for key in pairs(row)do if key~="owned"and key~="equipped"then return false end end
		local count,seen=0,{}
		for key in pairs(row.owned)do count+=1;if type(key)~="number"then return false end end
		if count~=#row.owned or count>State.Limit then return false end
		for _,item in ipairs(row.owned)do if not id(item)or seen[item]then return false end;seen[item]=true end
		local keys=0
		for key,item in pairs(row.equipped)do
			keys+=1
			if not id(key)or not id(item)or not seen[item]then return false end
		end
		if keys>State.KeyLimit then return false end
	end
	return true
end

function State.row(state,petId)
	local row=(state.petWearables or {})[petId]
	return {owned=table.clone(row and row.owned or {}),equipped=table.clone(row and row.equipped or {})}
end
function State.owns(state,petId,itemId)
	local row=(state.petWearables or {})[petId]
	return row~=nil and table.find(row.owned,itemId)~=nil
end

local function put(state,petId,row)
	local rows=table.clone(state.petWearables or {});rows[petId]=row;state.petWearables=rows
end
local function wear(row,petId,item)
	local equipped=table.clone(row.equipped)
	-- One item per slot: both sides of a pair, or the single key.
	for _,key in ipairs(Catalog.slotKeys(petId,item.slot))do equipped[key]=nil end
	for _,key in ipairs(item.keys)do equipped[key]=item.id end
	row.equipped=equipped
end

-- Pure check shared by the server's early refusal and the UpdateAsync callback. `week` is
-- the shelf week frozen in the purchase (nil = no shelf: the catalogue price). Returns
-- true, nil, item, expectedPrice.
function State.price(petId,itemId,week)
	local item=Catalog.item(petId,itemId)
	return if item then expectedPrice("wearable",itemId,item.price,week)else nil
end
function State.check(state,petId,itemId,price,week)
	if not Eggs.isOwned(state.inventoryMask,petId)then return false,"Unowned"end
	local item=Catalog.item(petId,itemId)
	if not item then return false,"NotForSale"end
	local expected=expectedPrice("wearable",itemId,item.price,week)
	if price~=nil and price~=expected then return false,"PriceChanged"end
	if State.owns(state,petId,itemId)then return false,"AlreadyOwned"end
	if #State.row(state,petId).owned>=State.Limit then return false,"OwnedLimit"end
	if state.nectar<expected then return false,"NeedStars"end
	return true,nil,item,expected
end

-- candidate = { petId, itemId, price, operationId, equip, week }
function State.applyBuy(state,candidate)
	if type(candidate)~="table"or not id(candidate.petId)or not id(candidate.itemId)then return false,"InvalidWearable"end
	local ok,why,item,expected=State.check(state,candidate.petId,candidate.itemId,candidate.price,candidate.week)
	if not ok then return false,why end
	local row=State.row(state,candidate.petId)
	table.insert(row.owned,item.id)
	if candidate.equip then wear(row,candidate.petId,item)end
	put(state,candidate.petId,row)
	state.nectar-=expected
	return true
end

-- What an equip would change to, or nil plus a reason. itemId=false takes the slot off.
function State.equipResult(state,petId,slot,itemId)
	if not Eggs.isOwned(state.inventoryMask,petId)then return nil,"Unowned"end
	local row=State.row(state,petId)
	if itemId then
		local item=Catalog.item(petId,itemId)
		if not item or item.slot~=slot then return nil,"InvalidWearable"end
		if not table.find(row.owned,itemId)then return nil,"NotOwned"end
		wear(row,petId,item)
	else
		local known=false
		for _,tab in ipairs(Catalog.Tabs)do if tab.slot==slot then known=true end end
		if not known then return nil,"InvalidWearable"end
		local equipped=table.clone(row.equipped)
		for _,key in ipairs(Catalog.slotKeys(petId,slot))do equipped[key]=nil end
		row.equipped=equipped
	end
	return row
end
function State.same(a,b)
	for k,v in pairs(a)do if b[k]~=v then return false end end
	for k,v in pairs(b)do if a[k]~=v then return false end end
	return true
end
-- candidate = { petId, slot, itemId (string or false), operationId }
function State.applyEquip(state,candidate)
	if type(candidate)~="table"or not id(candidate.petId)or not id(candidate.slot)then return false,"InvalidWearable"end
	local row,why=State.equipResult(state,candidate.petId,candidate.slot,candidate.itemId)
	if not row then return false,why end
	if State.same(row.equipped,State.row(state,candidate.petId).equipped)then return false,"NoChange"end
	put(state,candidate.petId,row)
	return true
end

function State.public(state)
	return {petWearables=copy(state.petWearables or {})}
end
function State.equipped(state,petId)
	local row=(state.petWearables or {})[petId]
	return if row then table.clone(row.equipped)else {}
end
return State
