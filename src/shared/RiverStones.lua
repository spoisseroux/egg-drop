-- The river stepping stones (beta 17 QA, shot 012655; artifacts/qa-2026-11-25-beta17/WORLD-ALIVE-LOOK.md section 4).
-- Shared and pure: the numbers the server's stone builder (StoneBuilder, DashMount) and the client's flow rings and
-- drifting leaves (LifeScene) both read. No instances, no services, no Random: every roll is a hash of the stone's seed,
-- so the same stone is carved the same on every server.
--   Rows       the three walkable stones (centres within .3 of DashCourse.Stones, where the hop is judged)
--   Company    three small stones off the row (not walkable), Landings: two flat stones set into the kerb line
--   Collider   one invisible cylinder per stone, players only (pets ignore the Dash model: PetFollow.ground)
--   cuts(row)  the 5 to 7 cutting planes of the stone builder's GeometryService intersect
--   Piers      the bridge piers the flow rings sit round [check] in Studio against W7_Bridge__marble
local Stones={}
Stones.Water=3.2   -- the stream's surface (WorldV7Data.wet)
Stones.Kerb=4.3    -- the marble kerb's top
Stones.Material="Slate"
local hex=Color3.fromHex

-- ball: the carve's Ball multiplier (nil: Stones.Ball); base: the height the cut planes pass through the footprint (nil:
-- the water).
local function row(name,x,z,length,width,turn,top,colour,seed,ball,base)
	return table.freeze({name=name,x=x,z=z,length=length,width=width,turn=turn,top=top,colour=hex(colour),seed=seed,ball=ball,base=base})
end
-- East to west, in DashCourse.Stones order. Footprint length x width (studs), turn (degrees about up), top (studs).
-- Code review: every top is DashCourse's STONE_TOP (4.00), where the racing pets stand, so no pet sinks into a stone;
-- the dome falls away below the walking top, and the three differ in outline, turn and colour.
Stones.Rows=table.freeze({
	row("East",7.5,9.0,2.6,2.1,20,4.00,"#8A8580",11),
	row("Middle",4.5,9.4,2.8,2.4,-35,4.00,"#7F847F",23),
	row("West",1.55,10.0,2.5,2.0,70,4.00,"#948E84",37),
})
-- The builder's carve (section 4, "Shape, tonight"): a Ball Ball x the stone's length, sunk so its top is the stone's
-- top, cut by Cuts big Blocks whose near faces stand at Reach of the footprint radius, each leaning out Lean degrees.
Stones.Ball=1.5
Stones.Cuts=table.freeze({5,7})
Stones.Reach=table.freeze({.85,1})
Stones.Lean=table.freeze({8,20})
Stones.Block=10 -- a cutting block's side (studs): much bigger than any stone
-- The fallback when the carve throws (or offline): two stacked Cylinders, the footprint's width then Upper of it.
Stones.Fallback=table.freeze({lower=.45,upper=.3,upperShare=.8})
-- Wet band: a second stone under each, Scale x as wide, Darker darker, its top just over the water. Its Ball is big (a
-- near-flat top), or only a sliver of it would clear the water.
Stones.Band=table.freeze({scale=1.12,darker=.35,top=3.25,ball=16})
-- Moss: one plate on top at Share of the footprint, lawn-patch-a tinted, decal transparency.
Stones.Moss=table.freeze({share=.7,colour=hex("#5F7F4A"),transparency=.45,lift=.02,texture="lawnPatchA"})
-- Company: small stones just off the row, tops 3.4 to 3.6; one upstream (+Z: the stream runs north to south) of the
-- middle stone, two downstream of the east one. Visual only.
Stones.Company=table.freeze({
	row("UpMiddle",4.2,11.9,.8,.7,15,3.5,"#878580",51),
	row("DownEastA",7.9,6.7,1.1,.9,-40,3.6,"#8F8A82",53),
	row("DownEastB",6.5,6.1,.7,.6,60,3.4,"#7C807B",57),
})
-- Landings: one flat stone where the row meets each bank, set into the kerb line (its long side along the kerb), so the
-- kerb is broken where the crossing lands. Raised .03 over the kerb so the seam is the landing's edge [check] z-fight.
-- A gently domed slab: Ball 12 x (its edge about .05 under its middle), the cuts through the footprint just under the
-- kerb's top.
Stones.LandingLift=.03
Stones.LandingBall=12
Stones.Landings=table.freeze({
	row("LandingEast",9.2,8.71,2.4,1.6,90,4.3+.03,"#9A958C",61,12,4.2),
	row("LandingWest",-.2,10.29,2.4,1.6,90,4.3+.03,"#968F86",67,12,4.2),
})
-- The colliders (section 4, "Colliders"): 2.9 across, top .03 under the stone's top, 1.2 deep. Players only.
Stones.Collider=table.freeze({diameter=2.9,below=.03,depth=1.2})
-- Bridge piers for the flow rings (W7_Bridge__marble at (4, 21), 25.2 long in X): where its feet meet the water.
-- [check] in Studio: move these onto the real piers, or drop them if the arch has none in the water.
Stones.Piers=table.freeze({
	table.freeze({x=-1.2,z=21,size=1.6}),
	table.freeze({x=9.2,z=21,size=1.6}),
})

-- A hash in [0, 1) of (seed, k): the same on every machine.
function Stones.roll(seed,k)
	local h=(seed*374761393+k*668265263)%4294967296
	h=bit32.bxor(h,bit32.rshift(h,13))
	h=(h*1274126177)%4294967296
	h=bit32.bxor(h,bit32.rshift(h,16))
	return h/4294967296
end
local function lerp(range,t)return range[1]+(range[2]-range[1])*t end

-- The footprint's radius (studs) in the stone's own direction `theta` (radians, 0 = along its length).
function Stones.radius(stone,theta)
	local a,b=stone.length/2,stone.width/2
	local c,s=math.cos(theta)/a,math.sin(theta)/b
	return 1/math.sqrt(c*c+s*s)
end
-- The cutting planes: {yaw (world radians), lean (degrees), reach (0..1), distance (studs from the centre at the
-- waterline)}. Evenly spread round the stone, each nudged by up to a third of a step.
function Stones.cuts(stone)
	local seed=stone.seed or 1
	local count=math.floor(lerp({Stones.Cuts[1],Stones.Cuts[2]+.999},Stones.roll(seed,1)))
	local out={}
	local turn=math.rad(stone.turn or 0)
	for k=1,count do
		local theta=(k-1)/count*math.pi*2+(Stones.roll(seed,10+k)-.5)*(2/3)*(math.pi*2/count)
		local reach=lerp(Stones.Reach,Stones.roll(seed,30+k))
		local lean=lerp(Stones.Lean,Stones.roll(seed,50+k))
		table.insert(out,{yaw=theta+turn,theta=theta,lean=lean,reach=reach,distance=reach*Stones.radius(stone,theta)})
	end
	return out
end
-- The colour of a stone's wet band.
function Stones.bandColour(colour)
	local k=1-Stones.Band.darker
	return Color3.new(colour.R*k,colour.G*k,colour.B*k)
end
-- A stone's wet band: the same stone Scale x as wide, its top at the band's top, darker.
function Stones.band(stone)
	local B=Stones.Band
	return table.freeze({name=stone.name.."Band",x=stone.x,z=stone.z,length=stone.length*B.scale,width=stone.width*B.scale,
		turn=stone.turn,top=B.top,colour=Stones.bandColour(stone.colour),seed=stone.seed+1000,ball=B.ball})
end
-- Collider k: its centre (Vector3), its size along the cylinder's axis and across, and its top.
function Stones.collider(stone)
	local C=Stones.Collider
	local top=stone.top-C.below
	return Vector3.new(stone.x,top-C.depth/2,stone.z),C.depth,C.diameter,top
end
-- Every point the flow rings and the leaves treat as an obstacle: the three stones and the piers, {x, z, size}.
function Stones.obstacles()
	local out={}
	for _,stone in ipairs(Stones.Rows)do table.insert(out,{x=stone.x,z=stone.z,size=math.max(stone.length,stone.width),stone=true})end
	for _,pier in ipairs(Stones.Piers)do table.insert(out,{x=pier.x,z=pier.z,size=pier.size})end
	return out
end

return table.freeze(Stones)
