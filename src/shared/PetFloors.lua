-- The server's one pet floor test (PLAY-DEN-BUILD-PLAN.md, architect: three plain booleans, validWander is hot). The home
-- Floor less a stud, or the Hush's floors while it is open, or the Play Den's (the room and the apron) while it is open;
-- never a tier footprint while the tier is open. With all three false or nil it is today's line exactly:
--   Hush.onPetFloor(floor, p, false) and not Tier.covers(p, false)
-- `den` is the den's layout (DenLayout) while DenHost is open, else nil.
local Shared=script.Parent
local Hush=require(Shared.Hush)
local Tier=require(Shared.Tier)
local DenLayout=require(Shared.DenLayout)
local Floors={}
function Floors.ok(floor,position,hushOpen,tierOpen,den)
	if not(Hush.onPetFloor(floor,position,hushOpen)or(den~=nil and DenLayout.petFloor(den,position,true)))then return false end
	return not Tier.covers(position,tierOpen)
end
return table.freeze(Floors)
