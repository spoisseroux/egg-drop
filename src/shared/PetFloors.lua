-- The server's one pet floor test (PLAY-DEN-BUILD-PLAN.md, architect: three plain booleans, validWander is hot). The home
-- Floor less a stud, or the Hush's floors while it is open, or the Play Den's (the room and the apron) while it is open;
-- never a tier footprint while the tier is open. With all three false or nil it is today's line exactly:
--   Hush.onPetFloor(floor, p, false) and not Tier.covers(p, false)
-- `den` is the den's layout (DenLayout) while DenHost is open, else nil.
-- `petsUp` (WORLD-FINISH-LOOK slice A, the server's TierPets gate, only ever true with the tier open): the terrace less
-- TierPets.Keep and the cliff path's tread are pet floor too (the path is transit: its callers refuse wander and focus
-- there). It is checked first, before the home Floor (architect). false or nil: the line above, unchanged.
local Shared=script.Parent
local Hush=require(Shared.Hush)
local Tier=require(Shared.Tier)
local DenLayout=require(Shared.DenLayout)
local TierPets=require(Shared.TierPets)
local Floors={}
function Floors.ok(floor,position,hushOpen,tierOpen,den,petsUp)
	if petsUp==true and tierOpen==true then
		local zone=TierPets.zone(position)
		if zone=="terrace"then return TierPets.terraceSafe(position.X,position.Z)end
		if zone=="path"then return true end
	end
	if not(Hush.onPetFloor(floor,position,hushOpen)or(den~=nil and DenLayout.petFloor(den,position,true)))then return false end
	return not Tier.covers(position,tierOpen)
end
return table.freeze(Floors)
