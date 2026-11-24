-- The upper tier, greybox T0 (artifacts/qa-2026-11-24-beta15/UPPER-TIER-BUILD-PLAN.md; look: UPPER-TIER-LOOK.md): a terrace
-- on the north-west ridge, 76 x 44 at y 29, and an open zigzag path up to it west of the cave mouth. Players only:
-- pets wait at the foot (by design in T0). Shared and pure, the IslandBounds pattern: FeatureFlags.Tier is the build
-- ceiling and opens only on the beta place or in Studio; the server's switch (TierConfig, ConfigService `garden_tier`:
-- off until the config has loaded once, then missing or malformed = on) reaches clients as `Tier_on`. Off is the game
-- before this build. Nothing here reads world data at require time: TierHost works out the ring boxes when it mounts.
--
-- Two frames, both in plan (x, z) with world heights:
--   the tier: centre C, s along the ridge (NE end -38, SW end +38), t toward the garden (garden edge +22, outer -22);
--   the path: from F0 (on the cliff foot, park side) out from the cliff by u (A), along the cliff toward the cave by o
--     (Out). Four legs side by side, each running out and back (see Tier.Legs).
local RunService=game:GetService("RunService")
local Flags=require(script.Parent.FeatureFlags)
local Tier={}
Tier.PlaceId=107705084891479 -- Pocket Pals Beta
Tier.Attribute="Tier_on"
Tier.Key="garden_tier"
Tier.Model="Tier"            -- EggDropLounge.Tier, the built greybox
Tier.Blocked="TierPetBlock"  -- EggDropLounge.PetRegions.TierPetBlock*, the pet-blocked footprints
Tier.Ring="PerimeterWall"    -- EggDropLounge.PerimeterWall.Wall<i> (LoungeWorldV7Art)
Tier.MaxErrors=3
Tier.Tick=.1

-- Heights and sizes.
Tier.FloorY=29        -- the terrace top (architect: 29, so no crest bump pokes through)
Tier.FootY=4.6        -- the lawn at the path's foot
Tier.Length,Tier.Width=76,44
Tier.SkirtY=-8        -- outer skirt and end closers reach down to here (the outer corners' ground is -4..+3)
Tier.WallTop=40       -- invisible walls (players only) up to here
Tier.RegionY=20       -- the bounds region starts here, over the lawn
Tier.Grow=1.5         -- the pet-blocked footprints are the solids grown by this much

local function unit(x,z)local m=math.sqrt(x*x+z*z);return x/m,z/m end
Tier.C=Vector3.new(-60,Tier.FloorY,-96)
Tier.D=Vector2.new(unit(-64,46))                 -- along the ridge, NE -> SW
Tier.N=Vector2.new(-Tier.D.Y,Tier.D.X)           -- toward the garden
if Tier.N.X*(-30-Tier.C.X)+Tier.N.Y*(4-Tier.C.Z)<0 then Tier.N=Vector2.new(Tier.D.Y,-Tier.D.X)end

-- The path (build: the Pet Park "grove" at (-38, -46) fills the cliff foot south-west of here, so Fable's two 44-stud legs
-- along the foot cannot fit; the lawn between the cave mouth, the park, Tree_05 and lamp 4 is about 26 along the cliff
-- by 38 out). A compact zigzag of four legs running out from the cliff and back, 6 wide, about 13.5 degrees. Frame: F0
-- on the cliff foot at the park side; u out from the cliff into the lawn (A), o along the cliff toward the cave (Out).
Tier.F0=Vector3.new(-41.82,Tier.FootY,-74.07)
Tier.A=Vector2.new(unit(34,32))
Tier.Out=Vector2.new(unit(32,-34))
Tier.Near,Tier.Run=6,25.5                    -- legs run from u Near to u Near + Run
Tier.Far=Tier.Near+Tier.Run                  -- far landings u Far..Far+6, a kerb to Far+6.5
Tier.Rise=(Tier.FloorY-Tier.FootY)/4
local function h(k)return Tier.FootY+Tier.Rise*k end
-- Each leg: o1..o2, its height at the near end and at the far end. Leg 1 is the foot (cave side), leg 4 the top.
Tier.Legs=table.freeze({
	table.freeze({name="Leg1",o1=20,o2=26,near=h(0),far=h(1)}),
	table.freeze({name="Leg2",o1=13.5,o2=19.5,near=h(2),far=h(1)}),
	table.freeze({name="Leg3",o1=7,o2=13,near=h(2),far=h(3)}),
	table.freeze({name="Leg4",o1=.5,o2=6.5,near=h(4),far=h(3)}),
})
function Tier.legY(leg,u)return leg.near+(leg.far-leg.near)*(u-Tier.Near)/Tier.Run end
Tier.Landings=table.freeze({
	table.freeze({name="NearLanding",u1=-1,u2=Tier.Near,o1=7,o2=20,y=h(2)}),
	table.freeze({name="FarLandingA",u1=Tier.Far,u2=Tier.Far+6.5,o1=13,o2=26.5,y=h(1)}),
	table.freeze({name="FarLandingB",u1=Tier.Far,u2=Tier.Far+6.5,o1=0,o2=13,y=h(3)}),
})
Tier.Top=table.freeze({u1=-7,u2=Tier.Near,o1=0,o2=7}) -- the top platform, from leg 4 back over the cliff to the terrace

-- Plan points.
function Tier.T(s,t,y)return Vector3.new(Tier.C.X+Tier.D.X*s+Tier.N.X*t,y or Tier.FloorY,Tier.C.Z+Tier.D.Y*s+Tier.N.Y*t)end
function Tier.P(u,o,y)return Vector3.new(Tier.F0.X+Tier.A.X*u+Tier.Out.X*o,y or Tier.FootY,Tier.F0.Z+Tier.A.Y*u+Tier.Out.Y*o)end
-- A frame whose local X is `along` and local -Z is `side` (a plan unit vector each), at `at` (right-handed: side must be
-- along rotated a quarter turn clockwise seen from above).
local function frame(at,along,side)
	return CFrame.new(at.X,at.Y,at.Z, along.X,0,-side.X, 0,1,0, along.Y,0,-side.Y)
end
Tier.frame=frame
Tier.TierFrame=frame(Tier.C,Tier.D,Tier.N)
Tier.PathFrame=frame(Tier.F0,Tier.A,Tier.Out)

-- Footprints in plan: {name, frame = "tier" | "path", a1, b1, a2, b2} with (a, b) = (s, t) or (u, o). The solids a
-- player can stand on (covers) and the pet-blocked footprints (pieces 2 on, grown by Grow) both come from these.
-- minY: a root above this over a path piece is "up there" (switch-off evacuation). Lawn level plus 4, so a player standing
-- on the lawn beside the path (root about 3 over the ground) is never moved.
Tier.PathMinY=Tier.FootY+4
Tier.Pieces=table.freeze({
	table.freeze({name="Terrace",frame="tier",a1=-38,b1=-22,a2=38,b2=22,minY=Tier.RegionY}),
	table.freeze({name="TopPlatform",frame="path",a1=Tier.Top.u1,b1=Tier.Top.o1,a2=Tier.Top.u2,b2=Tier.Top.o2,minY=Tier.PathMinY}),
	table.freeze({name="Legs",frame="path",a1=Tier.Near,b1=0,a2=Tier.Far,b2=26.5,minY=Tier.PathMinY}),
	table.freeze({name="NearLanding",frame="path",a1=-1,b1=7,a2=Tier.Near,b2=20,minY=Tier.PathMinY}),
	table.freeze({name="FarLandings",frame="path",a1=Tier.Far,b1=0,a2=Tier.Far+6.5,b2=26.5,minY=Tier.PathMinY}),
})
local function local2(piece,x,z)
	if piece.frame=="tier"then
		local dx,dz=x-Tier.C.X,z-Tier.C.Z
		return dx*Tier.D.X+dz*Tier.D.Y,dx*Tier.N.X+dz*Tier.N.Y
	end
	local dx,dz=x-Tier.F0.X,z-Tier.F0.Z
	return dx*Tier.A.X+dz*Tier.A.Y,dx*Tier.Out.X+dz*Tier.Out.Y
end
Tier.local2=local2
-- Pure: is (x, z) inside the piece's footprint, grown by `grow`?
function Tier.inPiece(piece,x,z,grow)
	grow=grow or 0
	local a,b=local2(piece,x,z)
	return a>=piece.a1-grow and a<=piece.a2+grow and b>=piece.b1-grow and b<=piece.b2+grow
end
-- The balustrade gap (s range) is the top platform's terrace end, half a stud wider each side.
do
	local s1=local2(Tier.Pieces[1],Tier.P(Tier.Top.u1,Tier.Top.o1).X,Tier.P(Tier.Top.u1,Tier.Top.o1).Z)
	local s2=local2(Tier.Pieces[1],Tier.P(Tier.Top.u1,Tier.Top.o2).X,Tier.P(Tier.Top.u1,Tier.Top.o2).Z)
	Tier.Gap=table.freeze({a1=math.min(s1,s2)-.5,a2=math.max(s1,s2)+.5})
end
-- Pure: the pet floor chain. `open` is TierHost's own flag; only `true` covers anything, so closed (false, nil) the
-- caller's line is exactly what it was. Covered = on the terrace, the top platform, a leg or the landing, in plan.
function Tier.covers(position,open)
	if open~=true or typeof(position)~="Vector3"then return false end
	local x,z=position.X,position.Z
	if x~=x or z~=z then return false end
	for _,piece in ipairs(Tier.Pieces)do if Tier.inPiece(piece,x,z,0)then return true end end
	return false
end
-- Pure: is a root at this position standing up there (for the switch-off evacuation)? Over a piece and above its minY.
function Tier.onIt(position)
	if typeof(position)~="Vector3"or position.X~=position.X then return false end
	for _,piece in ipairs(Tier.Pieces)do
		if position.Y>piece.minY and Tier.inPiece(piece,position.X,position.Z,.5)then return true end
	end
	return false
end

-- Island bounds: one region round the terrace, the top platform and leg B's top, from RegionY up. Inside it a root has
-- left only below fallY (= RegionY). No safe function: no safe samples up there (a fall returns you to the lawn).
do
	local xs,zs={}, {}
	local t=Tier.Top
	for _,p in ipairs({Tier.T(-38,-22),Tier.T(-38,22),Tier.T(38,-22),Tier.T(38,22),Tier.P(t.u1,t.o1),Tier.P(t.u1,t.o2),Tier.P(t.u2,t.o1),
		Tier.P(t.u2,t.o2),Tier.P(t.u2+4,t.o1),Tier.P(t.u2+4,t.o2)})do
		table.insert(xs,p.X);table.insert(zs,p.Z)
	end
	local lo=Vector3.new(math.min(table.unpack(xs))-2,Tier.RegionY,math.min(table.unpack(zs))-2)
	local hi=Vector3.new(math.max(table.unpack(xs))+2,80,math.max(table.unpack(zs))+2)
	Tier.Region=table.freeze({min=lo,max=hi})
	Tier.BoundsRegions=table.freeze({table.freeze({name="tier",min=lo,max=hi,fallY=Tier.RegionY})})
end

-- Switch off: everyone up there goes to the lawn by the foot (inside the home Floor, facing the plaza).
Tier.Evacuation=table.freeze({at=Tier.P(16,32,Tier.FootY),facing=Vector3.new(-30,Tier.FootY,4)})
Tier.EvacuationOffsets=table.freeze({Vector3.zero,Vector3.new(-1.6,0,0),Vector3.new(1.6,0,0),Vector3.new(-.8,0,-2.2),Vector3.new(.8,0,-2.2)})

-- The ring boxes that stand aside while open: every perimeter box (WorldV7Data.perimeter entries {center, size, yaw})
-- that meets the terrace grown by 1 stud, sampled along its centre line. Called by TierHost.mount,
-- inside its pcall, never at require. Returns the sorted indices and the two neighbours left standing.
function Tier.ringAside(perimeter)
	local aside={}
	for i,entry in ipairs(perimeter)do
		local c,size,yaw=entry.center,entry.size,entry.yaw or 0
		local ux,uz=math.cos(yaw),-math.sin(yaw)
		for k=-4,4 do
			local x,z=c[1]+ux*size[1]/2*k/4,c[3]+uz*size[1]/2*k/4
			if Tier.inPiece(Tier.Pieces[1],x,z,1)then table.insert(aside,i);break end
		end
	end
	if #aside==0 then return aside,nil,nil end
	local n=#perimeter
	local first,last=aside[1],aside[#aside]
	return aside,(first-2)%n+1,last%n+1
end

-- The end closers: from each standing neighbour box's end nearest the tier to the tier's end wall at the same t, so the
-- crest beyond the tier's ends has no gap where the ring stood aside. Pure; TierHost.mount calls it with the ring data.
-- Returns {from = Vector3, to = Vector3} in plan (y 0).
function Tier.closers(perimeter,before,after)
	local out={}
	for _,i in ipairs({before,after})do
		local entry=perimeter[i]
		if entry then
			local c,size,yaw=entry.center,entry.size,entry.yaw or 0
			local ux,uz=math.cos(yaw),-math.sin(yaw)
			local best,bestS
			for _,k in ipairs({-1,1})do
				local x,z=c[1]+ux*size[1]/2*k,c[3]+uz*size[1]/2*k
				local s=math.abs((local2(Tier.Pieces[1],x,z)))
				if not best or s<bestS then best,bestS=Vector3.new(x,0,z),s end
			end
			local s,t=local2(Tier.Pieces[1],best.X,best.Z)
			local wall=Tier.T(if s<0 then -37.5 else 37.5,math.clamp(t,-21.5,21.5),0)
			table.insert(out,table.freeze({from=best,to=wall,ring=i}))
		end
	end
	return out
end

-- Pure: are the stood-aside indices one contiguous run that does not wrap past 1 / n? (TierHost refuses anything else.)
function Tier.ringRunOk(aside,n)
	if type(aside)~="table"or #aside==0 or type(n)~="number"then return false end
	if aside[1]<=1 or aside[#aside]>=n then return false end
	for k=2,#aside do if aside[k]~=aside[k-1]+1 then return false end end
	return true
end

local injected=nil
-- Specs pass env = {flags, place, studio, on}; the game passes nothing.
function Tier.ceiling(env)
	env=env or injected or {}
	if(env.flags or Flags).Tier~=true then return false end
	local studio=env.studio
	if studio==nil then studio=RunService:IsStudio()end
	return(env.place or game.PlaceId)==Tier.PlaceId or studio==true
end
-- Pure: a switch value. Anything but a boolean (missing, malformed) is the shipped default, on.
function Tier.resolve(configValue,override,ceiling)
	if ceiling==nil then ceiling=Tier.ceiling()end
	if not ceiling then return false end
	if type(override)=="boolean"then return override end
	if type(configValue)=="boolean"then return configValue end
	return true
end
-- Server only (TierConfig): the resolved value TierHost reads. Off until it is set.
local switch=false
function Tier.setSwitch(value)
	if not RunService:IsServer()then return false end
	switch=value==true
	return true
end
function Tier.on()
	if injected then return injected.on~=false and Tier.ceiling(injected)end
	if not Tier.ceiling()then return false end
	if RunService:IsServer()and not switch then return false end
	return workspace:GetAttribute(Tier.Attribute)==true
end
-- Spec seam, refused outside Studio.
function Tier.inject(env)
	if not RunService:IsStudio()then return false end
	injected=if type(env)=="table"then table.clone(env)else nil
	return true
end
return table.freeze(Tier)
