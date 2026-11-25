-- The upper tier (artifacts/qa-2026-11-24-beta15/UPPER-TIER-BUILD-PLAN.md; look: UPPER-TIER-LOOK.md; the way up:
-- artifacts/qa-2026-11-25-beta17/CLIFF-DEN-BUILD.md): a terrace on the north-west ridge, 76 x 44 at y 29, reached by the
-- island's cliff path (the beta's sculpt, CliffDenData.path: cut into the rock west of the cave, from the lawn by the
-- den up to the terrace's garden edge). The T0 zigzag is retired. Players only: pets wait at the path's foot. Shared and
-- pure, the IslandBounds pattern: FeatureFlags.Tier is the build ceiling and opens only on the beta place or in Studio;
-- the server's switch (TierConfig, ConfigService `garden_tier`: off until the config has loaded once, then missing or
-- malformed = on) reaches clients as `Tier_on`. The terrace also needs the cliff path: without the sculpt (no WorldBeta
-- pack, the workspace attribute `CliffDen` unset) there is no way up and it stays closed. Off is the game before this
-- build. Nothing here reads world data at require time: TierHost works out the ring boxes when it mounts, and the path
-- is read from CliffDenData only when first asked (never on live: the ceiling is closed there).
--
-- The tier's frame, in plan (x, z) with world heights: centre C, s along the ridge (NE end -38, SW end +38), t toward the
-- garden (garden edge +22, outer -22).
local RunService=game:GetService("RunService")
local Flags=require(script.Parent.FeatureFlags)
local Tier={}
Tier.PlaceId=107705084891479 -- Pocket Pals Beta
Tier.Attribute="Tier_on"
Tier.Key="garden_tier"
Tier.CliffAttribute="CliffDen" -- set on workspace at server start when the island's sculpt is swapped in (CliffDenSwap)
Tier.Model="Tier"            -- EggDropLounge.Tier, the built greybox
Tier.Gates="TierGates"       -- EggDropLounge.TierGates, the path's foot and the notch closed while the terrace is
Tier.Blocked="TierPetBlock"  -- EggDropLounge.PetRegions.TierPetBlock*, the pet-blocked footprints
Tier.Ring="PerimeterWall"    -- EggDropLounge.PerimeterWall.Wall<i> (LoungeWorldV7Art)
Tier.MaxErrors=3
Tier.Tick=.1

-- Heights and sizes.
Tier.FloorY=29        -- the terrace top (architect: 29, so no crest bump pokes through; the sculpt regrades under 27)
Tier.FootY=4.6        -- the lawn at the path's foot
Tier.Length,Tier.Width=76,44
Tier.SkirtY=-8        -- outer skirt and end closers reach down to here (the outer corners' ground is -4..+3)
Tier.WallTop=54       -- invisible walls (players only) up to here (Studio R8: at 40 one player cleared it from the 3-4 high lips; at 48 a player on another's head on a lip still did, root 51.3)
Tier.RegionY=20       -- the bounds region starts here, over the lawn
Tier.Grow=1.5         -- the pet-blocked footprints are the path grown by this much
Tier.PathLift=2       -- the path counts as "up there" for pets where its tread is this far over the foot
Tier.PathBlock=3      -- footprints: one box per this many centre-line segments

local function unit(x,z)local m=math.sqrt(x*x+z*z);return x/m,z/m end
Tier.C=Vector3.new(-60,Tier.FloorY,-96)
Tier.D=Vector2.new(unit(-64,46))                 -- along the ridge, NE -> SW
Tier.N=Vector2.new(-Tier.D.Y,Tier.D.X)           -- toward the garden
if Tier.N.X*(-30-Tier.C.X)+Tier.N.Y*(4-Tier.C.Z)<0 then Tier.N=Vector2.new(Tier.D.Y,-Tier.D.X)end

-- Plan points.
function Tier.T(s,t,y)return Vector3.new(Tier.C.X+Tier.D.X*s+Tier.N.X*t,y or Tier.FloorY,Tier.C.Z+Tier.D.Y*s+Tier.N.Y*t)end
-- A frame whose local X is `along` and local -Z is `side` (a plan unit vector each), at `at` (right-handed: side must be
-- along rotated a quarter turn clockwise seen from above).
local function frame(at,along,side)
	return CFrame.new(at.X,at.Y,at.Z, along.X,0,-side.X, 0,1,0, along.Y,0,-side.Y)
end
Tier.frame=frame
Tier.TierFrame=frame(Tier.C,Tier.D,Tier.N)

-- The terrace's footprint in plan: {name, frame = "tier", a1, b1, a2, b2} with (a, b) = (s, t). minY: a root above this
-- over it is "up there" (switch-off evacuation).
Tier.Pieces=table.freeze({
	table.freeze({name="Terrace",frame="tier",a1=-38,b1=-22,a2=38,b2=22,minY=Tier.RegionY}),
})
local function local2(_,x,z)
	local dx,dz=x-Tier.C.X,z-Tier.C.Z
	return dx*Tier.D.X+dz*Tier.D.Y,dx*Tier.N.X+dz*Tier.N.Y
end
Tier.local2=local2
-- Pure: is (x, z) inside the piece's footprint, grown by `grow`?
function Tier.inPiece(piece,x,z,grow)
	grow=grow or 0
	local a,b=local2(piece,x,z)
	return a>=piece.a1-grow and a<=piece.a2+grow and b>=piece.b1-grow and b<=piece.b2+grow
end
-- The balustrade gap (s range) where the cliff path arrives on the garden edge (CliffDenData.terrace.gap; the path's
-- last centre-line point is at s 30, t 22). CliffDen.spec checks the two agree.
Tier.Gap=table.freeze({a1=26,a2=34})

-- The cliff path, from CliffDenData (lazy, once): {points = {Vector3}, widths = {number}, box = {min, max} in plan}, or
-- false when the data is missing or malformed (then nothing is covered and the terrace never opens).
local path=nil
function Tier.path(data)
	if data==nil and path~=nil then return path end
	local d=data
	if d==nil then
		local ok,module=pcall(function()return require(script.Parent:FindFirstChild("CliffDenData"))end)
		d=if ok then module else nil
	end
	local line=type(d)=="table"and type(d.path)=="table"and d.path.centreLine
	local out=false
	if type(line)=="table"and #line>=2 then
		local points,widths={}, {}
		local x0,z0,x1,z1=math.huge,math.huge,-math.huge,-math.huge
		local good=true
		for _,p in ipairs(line)do
			if type(p)~="table"or type(p.x)~="number"or type(p.y)~="number"or type(p.z)~="number"or type(p.width)~="number"then good=false;break end
			table.insert(points,Vector3.new(p.x,p.y,p.z));table.insert(widths,p.width)
			x0,z0,x1,z1=math.min(x0,p.x),math.min(z0,p.z),math.max(x1,p.x),math.max(z1,p.z)
		end
		if good then
			out=table.freeze({points=table.freeze(points),widths=table.freeze(widths),
				box=table.freeze({min=Vector2.new(x0,z0),max=Vector2.new(x1,z1)})})
		end
	end
	if data==nil then path=out end
	return out
end
-- Pure: the path's tread under (x, z) when (x, z) is within half its width plus `grow` of the centre line in plan: the
-- tread height there (the nearest segment's), else nil.
function Tier.onPath(x,z,grow,p)
	p=p or Tier.path()
	if not p or x~=x or z~=z then return nil end
	grow=grow or 0
	local reach=4+grow
	if x<p.box.min.X-reach or x>p.box.max.X+reach or z<p.box.min.Y-reach or z>p.box.max.Y+reach then return nil end
	local best,bestY=math.huge,nil
	local pts=p.points
	for i=1,#pts-1 do
		local a,b=pts[i],pts[i+1]
		local dx,dz=b.X-a.X,b.Z-a.Z
		local len2=dx*dx+dz*dz
		local t=if len2>0 then math.clamp(((x-a.X)*dx+(z-a.Z)*dz)/len2,0,1)else 0
		local ex,ez=x-a.X-dx*t,z-a.Z-dz*t
		local dist=math.sqrt(ex*ex+ez*ez)
		local half=(p.widths[i]+(p.widths[i+1]-p.widths[i])*t)/2
		if dist<=half+grow and dist<best then best,bestY=dist,a.Y+(b.Y-a.Y)*t end
	end
	return bestY
end
-- Pure: the pet floor chain. `open` is TierHost's own flag; only `true` covers anything, so closed (false, nil) the
-- caller's line is exactly what it was. Covered = on the terrace, or over the cliff path where it has left the lawn.
function Tier.covers(position,open,p)
	if open~=true or typeof(position)~="Vector3"then return false end
	local x,z=position.X,position.Z
	if x~=x or z~=z then return false end
	if Tier.inPiece(Tier.Pieces[1],x,z,0)then return true end
	local y=Tier.onPath(x,z,0,p)
	return y~=nil and y>=Tier.FootY+Tier.PathLift
end
-- Pure: is a root at this position standing up there (for the switch-off evacuation)? On the terrace above its minY.
-- (The path stays: whoever is on it when the terrace closes walks down; the gate at the notch stops them at the top.)
function Tier.onIt(position)
	if typeof(position)~="Vector3"or position.X~=position.X then return false end
	for _,piece in ipairs(Tier.Pieces)do
		if position.Y>piece.minY and Tier.inPiece(piece,position.X,position.Z,.5)then return true end
	end
	return false
end

-- Island bounds: one region round the terrace, from RegionY up. Inside it a root has left only below fallY (= RegionY).
-- No safe function: no safe samples up there (a fall returns you to the lawn). The path itself is inside the ring.
do
	local xs,zs={}, {}
	for _,p in ipairs({Tier.T(-38,-22),Tier.T(-38,22),Tier.T(38,-22),Tier.T(38,22)})do
		table.insert(xs,p.X);table.insert(zs,p.Z)
	end
	local lo=Vector3.new(math.min(table.unpack(xs))-2,Tier.RegionY,math.min(table.unpack(zs))-2)
	local hi=Vector3.new(math.max(table.unpack(xs))+2,80,math.max(table.unpack(zs))+2)
	Tier.Region=table.freeze({min=lo,max=hi})
	Tier.BoundsRegions=table.freeze({table.freeze({name="tier",min=lo,max=hi,fallY=Tier.RegionY})})
end

-- Switch off: everyone up there goes to the lawn south-east of the path's foot (inside the home Floor, clear of the den's
-- apron and doorstep, facing the plaza). The T0 spot is now the den's doorstep (Fable).
Tier.Evacuation=table.freeze({at=Vector3.new(-14,Tier.FootY,-79),facing=Vector3.new(-30,Tier.FootY,4)})
Tier.EvacuationOffsets=table.freeze({Vector3.zero,Vector3.new(-1.6,0,0),Vector3.new(1.6,0,0),Vector3.new(-.8,0,-2.2),Vector3.new(.8,0,-2.2)})

-- The path's gates (closed while the terrace is closed): across the path a little way up from its foot, and across the
-- arrival at the notch. {name, from, to, y1, y2} in plan (y ignored on from/to). Pure; nil without a path.
Tier.GateFoot,Tier.GateTop=4,2 -- centre-line points from the foot / from the arrival
function Tier.gates(p)
	p=p or Tier.path()
	if not p then return nil end
	local function across(i,j)
		local a,b=p.points[i],p.points[j]
		local dir=Vector3.new(b.X-a.X,0,b.Z-a.Z).Unit
		local side=Vector3.new(-dir.Z,0,dir.X)*(p.widths[i]/2+1.5)
		return a-side,a+side,a.Y
	end
	local n=#p.points
	local f1,f2,fy=across(Tier.GateFoot,Tier.GateFoot+1)
	local t1,t2,ty=across(n-Tier.GateTop,n-Tier.GateTop+1)
	return{
		{name="GateFoot",from=f1,to=f2,y1=fy-2,y2=fy+16},
		{name="GateNotch",from=t1,to=t2,y1=ty-2,y2=Tier.WallTop},
	}
end

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
-- Specs pass env = {flags, place, studio, on, cliffDen}; the game passes nothing.
function Tier.ceiling(env)
	env=env or injected or {}
	if(env.flags or Flags).Tier~=true then return false end
	local studio=env.studio
	if studio==nil then studio=RunService:IsStudio()end
	return(env.place or game.PlaceId)==Tier.PlaceId or studio==true
end
-- Pure: a switch value. Anything but a boolean (missing, malformed) is the shipped default, on (Spencer 2026-11-25: the
-- cliff path is the way up, so the terrace is open again; `/tier off` closes it on a server).
function Tier.resolve(configValue,override,ceiling)
	if ceiling==nil then ceiling=Tier.ceiling()end
	if not ceiling then return false end
	if type(override)=="boolean"then return override end
	if type(configValue)=="boolean"then return configValue end
	return true
end
-- Is the island's cliff path in on this server (the sculpt swapped in at start)?
function Tier.cliff()
	if injected then return injected.cliffDen~=false end
	return workspace:GetAttribute(Tier.CliffAttribute)==true
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
