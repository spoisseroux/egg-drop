-- The upper tier greybox rows (UPPER-TIER-BUILD-PLAN.md section 2, as built; the T0 zigzag retired for the island's cliff
-- path, CLIFF-DEN-BUILD.md): the terrace, its walls with the gap where the cliff path arrives, two clumps, three toy pads
-- and the tree pole. Greybox.gates(gates) are the path's two invisible closers while the terrace is closed. Names "W7T_" so the
-- camera clamp (CameraClamp.isWorld: "W7") stops on them. Pure. TierGreybox.rows(closers) adds the two end closers that
-- Tier.closers works out from the ring data (TierHost calls it when it mounts; nothing reads world data here).
local Tier=require(script.Parent.Tier)
local GreyboxRows=require(script.Parent.GreyboxRows)
local Greybox={}
-- Home's palette (Fable R8 FIX 1: from the plaza the tier must read as a higher piece of the island, not a grey
-- building). Sampled medians of the shipped textures (assets/world/textures/grounded, scripts/build_world_v7_grounded_
-- textures.py), grass and cliff through the Aero tints (WorldAero.Surfaces): lawn #17702C, cliff rock #6B7465, plaza
-- marble #B2B1B3, dirt path #815C3F. Matte Roblox materials. Pads stay dark, the tree pole pale.
local LAWN,CLIFF,MARBLE,DIRT,CLUMP,PAD,POLE="#17702C","#6B7465","#B2B1B3","#815C3F","#5A6256","#3E4A3C","#E8E4D8"
local FACE,LIP="#869080",1.4 -- Fable cliff-den review fix 8
Greybox.Look=table.freeze({lawn=LAWN,cliff=CLIFF,marble=MARBLE,dirt=DIRT,clump=CLUMP,face=FACE})
Greybox.Lip=LIP
local GRASS,ROCK,STONE,EARTH={material="Grass"},{material="Slate"},{material="Marble"},{material="Ground"}
local function with(a,b)local t=table.clone(a);for k,v in pairs(b or {})do t[k]=v end;return t end
local Y,BOTTOM,TOP=Tier.FloorY,Tier.SkirtY,Tier.WallTop

function Greybox.rows(closers)
	local b=GreyboxRows.new("W7T_")
	local T=Tier.TierFrame
	-- The terrace: slab, garden-side retaining face, outer skirt and end skirts down to SkirtY.
	b.block("Floor",T,-38,-22,Y-2,38,22,Y,LAWN,GRASS)
	-- Fable cliff-den review fix 8: the face up to the floor's top (no dark grass band), a lighter rock.
	b.block("FaceGarden",T,-38,21,14,38,22,Y,FACE,with(ROCK,{shadow=true}))
	b.block("SkirtOuter",T,-38,-22,BOTTOM,38,-21,Y-2,CLIFF,ROCK)
	b.block("SkirtNorthEast",T,-38,-21,BOTTOM,-37,21,Y-2,CLIFF,ROCK)
	b.block("SkirtSouthWest",T,37,-21,BOTTOM,38,21,Y-2,CLIFF,ROCK)
	-- The balustrade (garden edge) with the gap where the cliff path arrives (Tier.Gap), and the outer rim and end rims, each a
	-- visible lip with an invisible wall above it up to WallTop.
	local g1,g2=Tier.Gap.a1,Tier.Gap.a2
	-- Fable fix 8: a low stone lip like the path's, not a white wall.
	b.block("BalustradeNorth",T,-38,21,Y,g1,22,Y+LIP,CLIFF,ROCK)
	b.block("BalustradeSouth",T,g2,21,Y,38,22,Y+LIP,CLIFF,ROCK)
	b.wall("BalustradeNorthStop",T,-38,21,Y+LIP,g1,22,TOP)
	b.wall("BalustradeSouthStop",T,g2,21,Y+LIP,38,22,TOP)
	b.block("RimOuter",T,-38,-22,Y,38,-21,Y+4,CLIFF,ROCK)
	b.wall("RimOuterStop",T,-38,-22,Y+4,38,-21,TOP)
	b.block("RimNorthEast",T,-38,-21,Y,-37,21,Y+4,CLIFF,ROCK)
	b.wall("RimNorthEastStop",T,-38,-21,Y+4,-37,21,TOP)
	b.block("RimSouthWest",T,37,-21,Y,38,21,Y+4,CLIFF,ROCK)
	b.wall("RimSouthWestStop",T,37,-21,Y+4,38,21,TOP)
	-- On the terrace: two clumps (rooms), three toy pads, the tree pole.
	-- Fable fix 8: lower, smaller, stepped, in the cliff's grey; nothing over Y+5 within 14 studs of the gap.
	-- WORLD-FINISH-LOOK slice B: the Top Lawn's circle (K (0, 5) r 13) must be clear, so the first clump moved from s 8..20,
	-- t -8..6 to the outer side behind the bench, 17+ from K and clear of the tree spot (20, -12). Lane E sculpts it.
	b.block("ClumpOne",T,4,-20,Y,14,-12,Y+5,CLIFF,with(ROCK,{shadow=true}))
	b.block("ClumpOneTop",T,6,-18,Y+5,10,-14,Y+8,CLIFF,with(ROCK,{shadow=true}))
	b.block("ClumpTwo",T,-36,-20,Y,-22,-6,Y+6,CLIFF,with(ROCK,{shadow=true}))
	b.block("PadCrunch",T,26,4,Y,34,12,Y+.1,PAD,{collide=false})
	b.block("PadPop",T,26,-12,Y,32,-6,Y+.1,PAD,{collide=false})
	b.block("PadMoss",T,-18,-16,Y,-12,-10,Y+.1,PAD,{collide=false})
	b.block("TreePole",T,-7,-15,Y,-5,-13,Y+14,POLE,{shadow=true})
	-- The end closers (invisible, SkirtY..WallTop), from Tier.closers.
	for k,closer in ipairs(closers or {})do b.segment("EndCloser"..k,closer.from,closer.to,BOTTOM,TOP)end
	return table.freeze(b.rows)
end
-- The path's closers while the terrace is closed (Tier.gates): invisible walls, players only.
function Greybox.gates(gates)
	local b=GreyboxRows.new("W7T_")
	for _,g in ipairs(gates or {})do b.segment(g.name,g.from,g.to,g.y1,g.y2)end
	return table.freeze(b.rows)
end
return table.freeze(Greybox)
