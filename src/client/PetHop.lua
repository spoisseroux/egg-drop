-- Beta (42) note 16, D16: the torso moves with the feet. Pure rules shared by GardenPetVisual (the pose),
-- PetPoseSampler (planting) and PetFollow (the walk's bob).
--   air     the hops that take the whole pet off the ground (the hello wave, a reaction, the petting screen's hop and
--           burst, the gift chain's jump): the body AND the feet rise, and planted feet let go while it lasts.
--   ground  what the body does over feet that stay put (the walk's bob, the boop squash, an idle beat's rise).
-- The walk's bob dips at each footfall (where a foot plants) and is back at rest by mid-step: never above the rest
-- height, so a running torso no longer floats over its planted feet.
local Hop={}
Hop.Greet,Hop.React=.11,.11 -- x the pet's scale: the hello and reaction hop heights (as before)
Hop.Boop=.05                -- x scale: the boop's squash dip (as before)
Hop.Release=.004            -- studs: above this the pet is airborne and its feet are not planted
-- The pet's lift, split (studs). greet/react are 0..1 weights; cuddleHop, bob, rise are in scale units; giftHop is
-- already in studs (GiftPaintWipe's); boop 0..1.
function Hop.split(scale,greet,react,cuddleHop,giftHop,bob,boop,rise)
	scale=tonumber(scale)or 1
	local air=((greet or 0)*Hop.Greet+(react or 0)*Hop.React+(cuddleHop or 0))*scale+(giftHop or 0)
	local ground=(-(boop or 0)*Hop.Boop+(bob or 0)+(rise or 0))*scale
	return air,ground
end
-- How far the feet rise with an air lift: only upward (a crouch stays in the body; the feet never sink).
function Hop.feet(air)
	air=tonumber(air)or 0
	return if air>0 then air else 0
end
-- Whether planted feet should let go this frame (GardenPetVisual leaves the last air lift on visual.airLift).
function Hop.airborne(visual)
	return type(visual)=="table"and(tonumber(visual.airLift)or 0)>Hop.Release
end
-- The walk's bob (scale units, <= 0): `amount` deep at each footfall (gait phase 0 and pi, where the feet plant),
-- easing back to 0 by mid-step. weight is the gait's (0..1), scamper its multiplier over ScamperSpeed.
function Hop.walkBob(phase,amount,scamper,weight)
	local c=1-math.abs(math.sin(tonumber(phase)or 0))
	return -(amount or 0)*(scamper or 1)*(weight or 0)*c*c
end
return Hop
