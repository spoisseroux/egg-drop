-- Island edges (WORLD-PASS-2026-11-22 item 5, slice 1), the Finds pattern. Shared and pure: FeatureFlags.IslandBounds is
-- the build ceiling, and it opens only on the beta place or in Studio, while the runtime switch is on (ConfigService key
-- `island_bounds`, server IslandBoundsConfig: off until the config has loaded once, then missing or malformed = on). Off
-- is the game before this build: no extra walls, no safe-spot return; the perimeter ring and FallCatch are untouched
-- either way (FallCatch stays the last resort). The server (IslandBoundsHost) reads it; no client code does (GardenLife
-- reads only the pure safeCell, for where a Dewdrop may land).
--
-- Walls: hand-written top-ups at the feet of the climbable slopes `scripts/sweep_island_edges.py` found walking
-- (artifacts/world-pass-2026-11-22/edge-sweep.md). Each is a thin invisible box from (x1, z1) to (x2, z2), standing
-- from `base` (a stud under the lowest ground beneath it) to `top` (at least 16 over the foot, and more than a jump
-- over the highest ground beneath it). CanTouch is off; CanQuery is ignored by Roblox while CanCollide is on, so rays do
-- hit them: the camera skips invisible parts, server rays are filtered to the room, prompts here skip line of sight,
-- and RoomView's greeting-shot rays exclude the folder (code review). Pets walk the planner's grid, not physics. None comes within 3 studs of the
-- Dash course, a park kerb, a find spot or a station, and none stands on a path tile (IslandBounds.spec and the sweep).
-- Rerun the sweep after any change here or to the walk map; it rewrites IslandGround (the safe ground).
local RunService=game:GetService("RunService")
local Flags=require(script.Parent.FeatureFlags)
local Ground=require(script.Parent.IslandGround)
local Bounds={}
Bounds.PlaceId=107705084891479 -- Pocket Pals Beta
Bounds.Attribute="Bounds_on"
Bounds.Key="island_bounds"
Bounds.Folder="IslandBounds"
Bounds.Thick=1
Bounds.FallY=-25        -- below this the root has fallen off (well above FallCatch at -166 to -158)
Bounds.Margin=3         -- outside the ring by more than this has left the island
Bounds.SafeTopY=16      -- a safe sample's root is at most this high (safe ground is at or below y 10)
Bounds.SampleEvery=1    -- seconds between safe-spot samples per player
Bounds.Quiet=2          -- no sample, and no return, this long after the server moved the character
Bounds.Cooldown=3       -- at most one return per player this often
Bounds.Leap=40          -- studs between two samples a walker cannot cover: treated as a server move
Bounds.Lift=.5          -- a return puts the root this far above the recorded spot

local function wall(id,x1,z1,x2,z2,base,top)
	return table.freeze({id=id,x1=x1,z1=z1,x2=x2,z2=z2,base=base,top=top})
end
Bounds.Walls=table.freeze({
	-- East mountain: the grass ramp at (100..105, 10..14) walks up to y 56 and over the buried ring boxes 57 and 58
	-- (115, 20). The ledge north of it and the shelf east of it are one full jump up; the three close the corner.
	wall("east_ledge",92,9.5,98.5,9.5,3.4,21),
	wall("east_ramp",98.5,9.5,99.5,22.5,3,21),
	wall("east_shelf",99.5,22.5,113.5,23,3,21),
	-- West mountain: the rock ramp at (-84..-77, -45..-37) climbs to the shelf at y 10 and on to the north band.
	-- From the ring box at (-83.9, -34.8) to the cliff at (-74, -47); the find spots (-77, -35) and (-71, -41) stay out.
	wall("west_ramp",-84,-34,-74.5,-47,-.8,21),
	-- Tumble Falls: the bowl north of the pool, (59..70, -86..-82), walks up the band. Starts at the cliff at x 57.
	wall("pool_bowl",57.5,-81.5,69.5,-81.5,3,30),
	-- The north spur (x 7..30, z -34..-100): a grass ridge from the garden up into the north band, walkable on every
	-- side. Round its foot from the band west of it to the band east of it. CreekNook (1, -33) is 9 studs out.
	wall("spur_neck_west",1,-101,9,-91,3.1,21),
	wall("spur_west_1",9,-91,11.5,-84,3.5,21),
	wall("spur_west_2",11.5,-84,11.5,-72,3.8,21),
	wall("spur_west_3",11.5,-72,8.5,-64,3.6,21),
	wall("spur_west_4",8.5,-64,6,-55,3.6,21),
	wall("spur_west_5",6,-55,6,-47,3.5,21),
	wall("spur_west_6",6,-47,9,-38,3.5,21),
	wall("spur_tip_west",9,-38,13.5,-33,3.6,21),
	wall("spur_tip",13.5,-33,21.5,-33,3.3,21),
	wall("spur_tip_east",21.5,-33,26.5,-38.5,3.3,21),
	wall("spur_east_1",26.5,-38.5,26.5,-58,3.3,21),
	wall("spur_east_2",26.5,-58,30,-66,3.5,21),
	wall("spur_east_3",30,-66,30.5,-86,3.4,21),
})

local injected=nil
-- Specs pass env = {flags, place, studio}; the game passes nothing.
function Bounds.ceiling(env)
	env=env or injected or {}
	if(env.flags or Flags).IslandBounds~=true then return false end
	local studio=env.studio
	if studio==nil then studio=RunService:IsStudio()end
	return(env.place or game.PlaceId)==Bounds.PlaceId or studio==true
end
-- Pure: a switch value. Anything but a boolean (missing, malformed) is the shipped default, on.
function Bounds.resolve(configValue,override,ceiling)
	if ceiling==nil then ceiling=Bounds.ceiling()end
	if not ceiling then return false end
	if type(override)=="boolean"then return override end
	if type(configValue)=="boolean"then return configValue end
	return true
end
-- Server only (IslandBoundsConfig): the resolved value every server check reads. Off until it is set.
local switch=false
function Bounds.setSwitch(value)
	if not RunService:IsServer()then return false end
	switch=value==true
	return true
end
function Bounds.on()
	if injected then return injected.on~=false and Bounds.ceiling(injected)end
	if not Bounds.ceiling()then return false end
	if RunService:IsServer()and not switch then return false end
	return workspace:GetAttribute(Bounds.Attribute)==true
end
function Bounds.changed()return workspace:GetAttributeChangedSignal(Bounds.Attribute)end
-- Spec seam, refused outside Studio.
function Bounds.inject(env)
	if not RunService:IsStudio()then return false end
	injected=if type(env)=="table"then table.clone(env)else nil
	return true
end

-- A wall as a box: CFrame (local X along the wall) and size.
function Bounds.box(w)
	local dx,dz=w.x2-w.x1,w.z2-w.z1
	local height=w.top-w.base
	return CFrame.new((w.x1+w.x2)/2,w.base+height/2,(w.z1+w.z2)/2)*CFrame.Angles(0,math.atan2(-dz,dx),0),
		Vector3.new(math.sqrt(dx*dx+dz*dz),height,Bounds.Thick)
end
-- Pure: the distance in plan from (x, z) to a wall's centre line.
function Bounds.distance(w,x,z)
	local dx,dz=w.x2-w.x1,w.z2-w.z1
	local t=math.clamp(((x-w.x1)*dx+(z-w.z1)*dz)/(dx*dx+dz*dz),0,1)
	local ex,ez=x-w.x1-t*dx,z-w.z1-t*dz
	return math.sqrt(ex*ex+ez*ez)
end

-- The perimeter ring (the wall centres, in order).
local ring={}
for k=1,#Ground.Ring,2 do table.insert(ring,Vector2.new(Ground.Ring[k]/10,Ground.Ring[k+1]/10))end
Bounds.Ring=table.freeze(ring)
function Bounds.inside(x,z)
	local hit=false
	local j=#ring
	for i=1,#ring do
		local a,b=ring[i],ring[j]
		if(a.Y>z)~=(b.Y>z)and x<a.X+(z-a.Y)*(b.X-a.X)/(b.Y-a.Y)then hit=not hit end
		j=i
	end
	return hit
end
function Bounds.ringDistance(x,z)
	local best=math.huge
	local j=#ring
	for i=1,#ring do
		local a,b=ring[j],ring[i]
		local dx,dz=b.X-a.X,b.Y-a.Y
		local t=math.clamp(((x-a.X)*dx+(z-a.Y)*dz)/(dx*dx+dz*dz),0,1)
		local ex,ez=x-a.X-t*dx,z-a.Y-t*dz
		best=math.min(best,ex*ex+ez*ez)
		j=i
	end
	return math.sqrt(best)
end
-- Pure: has a root at this position left the island (fallen below FallY, or outside the ring by more than Margin)?
function Bounds.gone(position)
	if position.Y<Bounds.FallY then return true end
	return not Bounds.inside(position.X,position.Z)and Bounds.ringDistance(position.X,position.Z)>Bounds.Margin
end
-- Pure: is the walk-map cell under (x, z) safe ground (IslandGround)?
function Bounds.safeCell(x,z)
	local i,j=math.floor(x-Ground.X0+.5),math.floor(z-Ground.Z0+.5)
	local row=Ground.Rows[j+1]
	if not row then return false end
	for k=1,#row,2 do
		if i<row[k]then return false end
		if i<=row[k+1]then return true end
	end
	return false
end
return table.freeze(Bounds)
