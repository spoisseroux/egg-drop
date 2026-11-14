-- Earned pets (overnight 2026-11-14, slice E; SYSTEMS-SCOPE 1.1 / 1.3). Pure and shared: the
-- server grants with it, the client reads the same gate, so the two can never disagree about
-- whether an earned pet exists in this build.
--
--   Rules[petId] = { stamps = N }   the pet is owed once the save holds N lifetime stamps
--   enabled(petId)                  FeatureFlags.SecondPet and a rig definition for the pet
--   owed(state)                     enabled pets whose rule is met and that are not owned yet
--
-- `state` is the hatching save or its public snapshot (both carry `stamps` and
-- `inventoryMask`). Every rule is monotonic (stamps never go down, a pet is never un-owned),
-- so the ownership bit is the only receipt a grant needs.
--
-- The table is deliberately not frozen: server specs swap `enabled` to exercise the grant with
-- the flag off. Nothing at runtime writes to it.
local Flags=require(script.Parent.FeatureFlags)
local Earned={}
Earned.Order=table.freeze({"blip"})
Earned.Rules=table.freeze({blip=table.freeze({stamps=7})})

function Earned.enabled(petId)
	if Flags.SecondPet~=true or type(petId)~="string"or Earned.Rules[petId]==nil then return false end
	-- Required lazily: with the flag off no caller pays for the rig tables.
	return require(script.Parent.PetRigDefinitions)[petId]~=nil
end

local function count(value)
	return if type(value)=="number"and value==value and value>=0 and value%1==0 then value else 0
end

function Earned.owed(state)
	local result={}
	if type(state)~="table"then return result end
	local Eggs=require(script.Parent.EggCatalog) -- lazy: EggCatalog -> PetCatalog -> this module
	local stamps,mask=count(state.stamps),count(state.inventoryMask)
	for _,petId in ipairs(Earned.Order)do
		if Earned.enabled(petId)and Eggs.bit(petId)~=0 and stamps>=Earned.Rules[petId].stamps
			and not Eggs.isOwned(mask,petId)then table.insert(result,petId)end
	end
	return result
end

return Earned
