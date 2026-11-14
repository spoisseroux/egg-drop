-- Bond XP per pet (overnight 2026-11-14, slice F; SYSTEMS-SCOPE 5). An optional, additive
-- field on the hatching save (v11, no version bump):
--   bond = { [petId] = xp }
-- Missing is valid (every save before this build). A malformed field is repaired at load
-- (State.sanitize), never a failed load. XP is written only inside transactions that already
-- exist (pet award, round award, Play date) and only for an owned pet, so an entry needs no
-- ownership check of its own. XP keeps counting past the shipped level cap (BondCatalog), up
-- to MaxXP, so later levels need no migration.
--
-- Rule: bond XP never makes an award, a pet or a park write fail. State.add has no failure
-- return: it is a no-op for an unknown or unowned pet or a bad amount.
local Shared=game:GetService("ReplicatedStorage").Shared
local Pets=require(Shared.PetCatalog)
local Eggs=require(Shared.EggCatalog)
-- Lane K's catalogue (levels, thresholds). Optional here: the server stores XP, never levels.
local catalogModule=Shared:FindFirstChild("BondCatalog")
local Catalog=if catalogModule then require(catalogModule)else {}

local State={}
State.MaxXP=if type(Catalog.MaxXP)=="number"then Catalog.MaxXP else 100000
State.Limit=16
-- XP per source [PLACEHOLDER numbers, SYSTEMS-SCOPE 8 #13]. BondCatalog.XP may override them.
local xp=if type(Catalog.XP)=="table"then Catalog.XP else {}
local function amount(value,default)
	return if type(value)=="number"and value==value and value%1==0 and value>=0 and value<=1000 then value else default
end
State.XP=table.freeze({
	pet=amount(xp.pet,1),           -- one paid pet (HatchProgress.awardPet; capped by PetDailyCap)
	round=amount(xp.round,2),       -- a saved round finished with the pet as companion
	win=amount(xp.win,3),           -- ... and won
	playDate=amount(xp.playDate,5), -- today's Play date completed (once a day)
})

local function integer(value,maximum)
	return type(value)=="number"and value==value and value%1==0 and value>=0 and value<=maximum
end

-- Tolerant: nil is valid. Otherwise a table of at most Limit entries, each a known pet id
-- and an integer 0..MaxXP.
function State.valid(state)
	local bond=state.bond
	if bond==nil then return true end
	if type(bond)~="table"then return false end
	local count=0
	for petId,value in pairs(bond)do
		count+=1
		if type(petId)~="string"or Pets.byId[petId]==nil or not integer(value,State.MaxXP)then return false end
	end
	return count<=State.Limit
end

-- Load-time repair: keep the well-formed entries (XP above the cap is clamped), drop the
-- rest; a non-table becomes nil. Walks the catalogue, so the result is deterministic.
function State.sanitize(value)
	if type(value)~="table"then return nil end
	local result,count={},0
	for _,pet in ipairs(Pets.collection)do
		local entry=value[pet.id]
		if count<State.Limit and type(entry)=="number"and entry==entry and entry>=0 and entry%1==0 then
			result[pet.id]=math.min(entry,State.MaxXP);count+=1
		end
	end
	return result
end

function State.xp(state,petId)
	local bond=type(state)=="table"and state.bond
	local value=type(bond)=="table"and bond[petId]
	return if integer(value,State.MaxXP)then value else 0
end

-- Adds XP for an owned pet (copy-on-write, clamped at MaxXP). Never fails, returns nothing.
function State.add(state,petId,gain)
	if type(state)~="table"or type(petId)~="string"or Pets.byId[petId]==nil then return end
	if type(gain)~="number"or gain~=gain or gain<=0 or gain==math.huge then return end
	if not Eggs.isOwned(state.inventoryMask or 0,petId)then return end
	local bond=State.sanitize(state.bond)or {}
	bond[petId]=math.min(State.MaxXP,(bond[petId]or 0)+math.floor(gain))
	state.bond=bond
end

function State.public(state)
	return {bond=State.sanitize(type(state)=="table"and state.bond)or {}}
end

return State
