-- The upper tier greybox rows (UPPER-TIER-BUILD-PLAN.md section 2, as built): the terrace, its walls, the top platform,
-- the four-leg zigzag path and its landings, two clumps, three toy pads and the tree pole. Names "W7T_" so the
-- camera clamp (CameraClamp.isWorld: "W7") stops on them. Pure. TierGreybox.rows(closers) adds the two end closers that
-- Tier.closers works out from the ring data (TierHost calls it when it mounts; nothing reads world data here).
local Tier=require(script.Parent.Tier)
local GreyboxRows=require(script.Parent.GreyboxRows)
local Greybox={}
local FLOOR,WALL,PATH,CLUMP,PAD,POLE="#7C8C6E","#5A5E62","#7A746A","#59665A","#3E4A3C","#E8E4D8"
local Y,BOTTOM,TOP=Tier.FloorY,Tier.SkirtY,Tier.WallTop
local KERB=1.5
local SEGMENTS=4

function Greybox.rows(closers)
	local b=GreyboxRows.new("W7T_")
	local T,P=Tier.TierFrame,Tier.PathFrame
	-- The terrace: slab, garden-side retaining face, outer skirt and end skirts down to SkirtY.
	b.block("Floor",T,-38,-22,Y-2,38,22,Y,FLOOR)
	b.block("FaceGarden",T,-38,21,14,38,22,Y-2,WALL,{shadow=true})
	b.block("SkirtOuter",T,-38,-22,BOTTOM,38,-21,Y-2,WALL)
	b.block("SkirtNorthEast",T,-38,-21,BOTTOM,-37,21,Y-2,WALL)
	b.block("SkirtSouthWest",T,37,-21,BOTTOM,38,21,Y-2,WALL)
	-- The balustrade (garden edge) with the gap onto the top platform (Tier.Gap), and the outer rim and end rims, each a
	-- visible lip with an invisible wall above it up to WallTop.
	local g1,g2=Tier.Gap.a1,Tier.Gap.a2
	b.block("BalustradeNorth",T,-38,21,Y,g1,22,Y+3,PATH)
	b.block("BalustradeSouth",T,g2,21,Y,38,22,Y+3,PATH)
	b.wall("BalustradeNorthStop",T,-38,21,Y+3,g1,22,TOP)
	b.wall("BalustradeSouthStop",T,g2,21,Y+3,38,22,TOP)
	b.block("RimOuter",T,-38,-22,Y,38,-21,Y+4,WALL)
	b.wall("RimOuterStop",T,-38,-22,Y+4,38,-21,TOP)
	b.block("RimNorthEast",T,-38,-21,Y,-37,21,Y+4,WALL)
	b.wall("RimNorthEastStop",T,-38,-21,Y+4,-37,21,TOP)
	b.block("RimSouthWest",T,37,-21,Y,38,21,Y+4,WALL)
	b.wall("RimSouthWestStop",T,37,-21,Y+4,38,21,TOP)
	-- The path: four legs side by side running out from the cliff and back (Tier.Legs), landings at both ends, the top
	-- platform from leg 4 back over the cliff onto the terrace. Kerbs between legs follow the higher leg; the foot of leg 1
	-- is open on its cave side for its first 3 studs.
	local top,near,far,run=Tier.Top,Tier.Near,Tier.Far,Tier.Run
	b.block("TopPlatform",P,top.u1,top.o1,0,top.u2,top.o2,Y,PATH)
	b.block("TopKerbPark",P,top.u1,top.o1,Y,top.u2,top.o1+.5,Y+KERB,PATH)
	b.wall("TopStopPark",P,top.u1,top.o1,Y+KERB,top.u2,top.o1+.5,TOP)
	b.block("TopKerbLanding",P,top.u1,top.o2-.5,Y,top.u2,top.o2,Y+KERB,PATH)
	b.wall("TopStopLanding",P,top.u1,top.o2-.5,Y+KERB,top.u2,top.o2,TOP)
	local legs=Tier.Legs
	for k,leg in ipairs(legs)do
		b.slab(leg.name,P,near,far,leg.o1,leg.o2,leg.near,leg.far,1,PATH)
		-- Supports: stepped boxes from the lawn to a stud under the slab's lowest point in each step.
		for j=1,SEGMENTS do
			local u1,u2=near+run*(j-1)/SEGMENTS,near+run*j/SEGMENTS
			local low=math.min(Tier.legY(leg,u1),Tier.legY(leg,u2))-1.2
			b.block(leg.name.."Support"..j,P,u1,leg.o1,0,u2,leg.o2,low,WALL)
		end
	end
	-- Kerbs: the park side of leg 4, between the legs (following the higher one), the cave side of leg 1 (from u Near + 3).
	local function kerb(name,o1,o2,leg,u1)
		u1=u1 or near
		-- Half a stud wide: the slot under it between two supports is too narrow for anyone, so no base.
		b.slab(name,P,u1,far,o1,o2,Tier.legY(leg,u1)+KERB,leg.far+KERB,1+KERB,WALL)
	end
	kerb("KerbPark",0,.5,legs[4])
	kerb("Kerb34",6.5,7,legs[4])
	kerb("Kerb23",13,13.5,legs[3])
	kerb("Kerb12",19.5,20,legs[2])
	kerb("KerbCave",26,26.5,legs[1],near+3)
	-- Landings: solid blocks from the lawn, kerbs on their open sides.
	for _,l in ipairs(Tier.Landings)do b.block(l.name,P,l.u1,l.o1,0,l.u2,l.o2,l.y,PATH)end
	local nearL,farA,farB=Tier.Landings[1],Tier.Landings[2],Tier.Landings[3]
	b.block("NearLandingKerbCave",P,nearL.u1,nearL.o2-.5,nearL.y,nearL.u2,nearL.o2,nearL.y+KERB,WALL)
	b.block("NearLandingBank",P,nearL.u1,nearL.o1,nearL.y,nearL.u1+.5,nearL.o2,nearL.y+KERB,WALL)
	b.block("FarKerbA",P,farA.u2-.5,farA.o1,farA.y,farA.u2,farA.o2,farA.y+KERB,WALL)
	b.block("FarKerbB",P,farB.u2-.5,farB.o1,farB.y,farB.u2,farB.o2,farB.y+KERB,WALL)
	b.block("FarKerbBetween",P,far,farB.o2,farA.y,farA.u2,farB.o2+.5,farB.y+KERB,WALL)
	b.block("FarKerbPark",P,far,farB.o1,farB.y,farB.u2,farB.o1+.5,farB.y+KERB,WALL)
	b.block("FarKerbCave",P,far,farA.o2-.5,farA.y,farA.u2,farA.o2,farA.y+KERB,WALL)
	b.block("LandingStone",P,nearL.u1+1,nearL.o1+4,nearL.y,nearL.u1+3,nearL.o1+7,nearL.y+1.2,CLUMP)
	-- On the terrace: two clumps (rooms), three toy pads, the tree pole.
	b.block("ClumpOne",T,6,-8,Y,24,14,Y+10,CLUMP,{shadow=true})
	b.block("ClumpTwo",T,-36,-20,Y,-22,-6,Y+8,CLUMP,{shadow=true})
	b.block("PadCrunch",T,26,4,Y,34,12,Y+.1,PAD,{collide=false})
	b.block("PadPop",T,26,-12,Y,32,-6,Y+.1,PAD,{collide=false})
	b.block("PadMoss",T,-18,-16,Y,-12,-10,Y+.1,PAD,{collide=false})
	b.block("TreePole",T,-7,-15,Y,-5,-13,Y+14,POLE,{shadow=true})
	-- The end closers (invisible, SkirtY..WallTop), from Tier.closers.
	for k,closer in ipairs(closers or {})do b.segment("EndCloser"..k,closer.from,closer.to,BOTTOM,TOP)end
	return table.freeze(b.rows)
end
return table.freeze(Greybox)
