-- Garden life, the maths (ALIVE-LIFE-BUILD-PLAN-2026-11-22; look numbers artifacts/alive-life-2026-11-22/LOOK-R2.md, then LOOK.md;
-- round 3, beta 12 QA L1-L3: artifacts/qa-2026-11-23-beta12/GARDEN-LIFE-NEST-LOOK.md and GARDEN-LIFE-NEST-BUILD-PLAN.md).
-- Pure: no instances, no clock, no services. GardenLife owns the parts and the one stepper and asks this what to show.
-- Everything random comes from a Random seeded by the caller, so the same seed and the same calls give the same
-- garden. Positions are Vector3, poses are CFrame; forward is -Z, up is +Y.
--   leaves       Leaves:step(now, dt, gust, cap, level, place) -> {kind, at} to Emit now; Sim.leafSpot (never under a
--                roof: Sim.LeafCover), Sim.leafWind (the emitters' Acceleration), Sim.leafDrift (how far one drifts)
--   bubbles      Bubbles:due(now, cap, allowed), Sim.bubbleSpot(camera, random, world), Bubbles:emit(now) -> "small" | "large"
--   butterflies  Butterflies:step(now, dt, world, patches, cap, still, daylight) -> the live ones; butterflyRoot / Flap /
--                Look / Parts (round 3: one continuous wing angle, glides, the firefly hand-off at dusk)
--   birds        Birds:chirp(now, perch, landing, cap, world, reduced, day), Birds:step(now, world, reduced, cap, level),
--                Sim.birdParts (round 3: eight parts, the head on its own, the tail, bounding flight)
--   day          Sim.day(daylight): the garden hour's gate for bubbles and birds (GARDEN-HOUR-LOOK 5); butterflies have
--                their own (.30 / .34)
--   dewdrops     Grove:refresh / :hanging / :active (what falls: a pure function of the server time), Loose:step
--                (what this client draws of it), Sim.fruitPose(loose, now) (world pass item 3; look numbers
--                artifacts/world-pass-2026-11-22/FRUIT-LOOK.md). Wind, Wind.hash and the gust number only, never a
--                Random, a camera or a cap, so every client sees the same fruit fall.
-- `world` is {camera = Vector3?, player = Vector3?, stations = {Vector3}, pad = {x, z, r}?, course = {x, z, ...}?
-- (only while a race is live; the grove passes it always), groundY = fn?, finds = {Vector3}?, kerbs = {{x, z, rx, rz}}?,
-- safe = fn(x, z)?}.
local Wind=require(script.Parent.Wind)
local Sim={}

-- Caps by AliveBudget level 0, 1, 2 (level 1 halves every cap; level 2 shows nothing). fruit: hanging Dewdrops shown,
-- loose: Dewdrops off the tree at once (FRUIT-LOOK 4). leaves: falling leaves alive (round 3; `petals` is the same
-- table under its old name for one build).
local leaves=table.freeze({28,14,0})
Sim.Caps=table.freeze({
	leaves=leaves,petals=leaves,bubbles=table.freeze({8,4,0}),butterflies=table.freeze({4,2,0}),
	birds=table.freeze({3,2,0}),emitters=table.freeze({3,3,0}),fruit=table.freeze({16,8,0}),loose=table.freeze({3,2,0}),
	-- Beta 14 QA B2: the night fireflies (a population of their own, GARDEN-LIFE-BUILD-PLAN section 3).
	fireflies=table.freeze({8,4,0}),
})
Sim.Hz=table.freeze({30,15}) -- steps a second at level 0 and 1
-- Never in the way: studs from the camera, a station (on the ground), the course line, past the waiting pad's edge.
Sim.Keep=table.freeze({camera=6,station=8,course=4,pad=2})
Sim.Drop=120 -- anything farther than this from the camera is dropped (a respawn, a camera jump, a teleport)

function Sim.level(level)
	level=if type(level)=="number"and level==level then math.floor(level)else 0
	return math.clamp(level,0,2)
end
function Sim.cap(kind,level)return Sim.Caps[kind][Sim.level(level)+1]end
-- The garden hour (GARDEN-HOUR-BUILD-PLAN-2026-11-23 slice D): bubbles and birds start only while its daylight is
-- above DayLife; the ones already out finish (bubbles pop on time, birds sit out their stay). `daylight` is nil with
-- the hour off: always day, as before. Leaves and Dewdrops never ask; butterflies have their own gate (round 3: they
-- fly over .30 and turn into fireflies under it, Sim.Butterfly). The daylight comes from the server clock
-- (GardenHour.phase), so every client gates on the same number.
Sim.DayLife=.7
function Sim.day(daylight)
	if type(daylight)~="number"or daylight~=daylight then return true end
	return daylight>Sim.DayLife
end
-- Seconds between steps, or nil when nothing runs (level 2).
function Sim.rate(level)
	local hz=Sim.Hz[Sim.level(level)+1]
	return if hz then 1/hz else nil
end

local function flat(a,b)
	local dx,dz=a.X-b.X,a.Z-b.Z
	return math.sqrt(dx*dx+dz*dz)
end
Sim.flat=flat
-- Studs on the ground plane from (x, z) to a flat x, z, x, z ... polyline.
function Sim.lineDistance(x,z,line)
	local best=math.huge
	if type(line)~="table"then return best end
	local n=#line//2
	if n==1 then return math.sqrt((x-line[1])^2+(z-line[2])^2)end
	for i=1,n-1 do
		local ax,az,bx,bz=line[i*2-1],line[i*2],line[i*2+1],line[i*2+2]
		local dx,dz=bx-ax,bz-az
		local length=dx*dx+dz*dz
		local t=if length>0 then math.clamp(((x-ax)*dx+(z-az)*dz)/length,0,1)else 0
		local d=math.sqrt((x-ax-dx*t)^2+(z-az-dz*t)^2)
		if d<best then best=d end
	end
	return best
end
-- A course line (x, z studs) from DashCourse's flat d, x, y, z lists in hundredths.
function Sim.courseLine(...)
	local out={}
	for _,list in ipairs({...})do
		for i=1,#list//4 do
			table.insert(out,list[i*4-2]/100);table.insert(out,list[i*4]/100)
		end
	end
	return out
end

-- Is this spot clear of the camera, the stations, the waiting pad and (while a race is live) the course?
-- false and the reason when not.
function Sim.clear(position,world,keep)
	keep=keep or Sim.Keep
	if typeof(position)~="Vector3"then return false,"spot"end
	world=world or {}
	if world.camera and(position-world.camera).Magnitude<keep.camera then return false,"camera"end
	for _,station in ipairs(world.stations or {})do
		if flat(position,station)<keep.station then return false,"station"end
	end
	local pad=world.pad
	if pad and math.sqrt((position.X-pad.x)^2+(position.Z-pad.z)^2)<pad.r+keep.pad then return false,"pad"end
	if world.course and Sim.lineDistance(position.X,position.Z,world.course)<keep.course then return false,"course"end
	return true
end

-- Falling leaves (beta 12 QA L2; GARDEN-LIFE-NEST-LOOK 2, replacing the petal bursts) --------------------------
-- A few leaves always coming down round the player: three emitters (leaf A, leaf B, a pale petal) that GardenLife
-- moves to a fresh spawn point for each emit. Sim.leafSpot draws that point uniform in the 72-stud square round the
-- player, 11 +- 1 studs over the ground there, and refuses a point off the island or whose drift path crosses a
-- covered place (Sim.LeafCover), so no leaf ever comes down under a roof; a refused emit is skipped, not redrawn.
-- The wind term is the gust number (Wind.gust, no breeze): the look's .7 studs a second when calm, 3.3 in a full gust.
Sim.Leaf=table.freeze({
	share=table.freeze({.55,.30,.15}),                                       -- leaf A, leaf B, petal
	life=table.freeze({table.freeze({9,12}),table.freeze({9,12}),table.freeze({8,10})}),
	rate=table.freeze({2.4,1.2}),boost=.5,                                    -- emits a second at level 0 / 1, x (1 + boost g)
	half=36,height=11,band=1,                                                 -- the square round the player; studs over the ground
	lean=.25,gust=.9,sway=.3,swayPeriod=7,fall=.45,drag=.5,                   -- Acceleration (GardenLife writes it at accelHz)
	speed=table.freeze({.3,.6}),spread=20,accelHz=4,
	-- How far a leaf can drift over its longest life: along the wind (reach) and to either side (side). Derived by
	-- LifeSim.spec from real wind sequences: Sim.leafDrift through a 12 s life from 4,000 start times over 3,000 s of
	-- gusts, with the wind dial at 1 and at 1.5 (two gusts in one life included): at most 14.5 along and 1.3 across
	-- (2026-11-23), rounded up with under 2 studs to spare. The gusts are short (.8 s up, 2.7 s down), so a leaf
	-- spends most of its life in the calm lean. [check] in Studio that a leaf's real drift matches (Drag's half-life).
	reach=16,side=2,
})
-- The covered places (roofs) no leaf may come down under: a flat circle each, x, z and radius in studs. From the
-- read-only Studio probe (scripts/probe_leaf_cover.luau, Play on the beta build after the island re-export, 2026-11-23;
-- artifacts/qa-2026-11-23-beta12/STUDIO-PROBES.md): every roof players stand under. Left out: the north aqueduct and
-- the cave and rock overhangs (behind the cave blocker and the rocks: nobody stands there) and the 1-2 cell rails and
-- ledges. Kept although IslandBounds.safeCell is false at their middles (pets do not walk there, players do): the
-- rotunda (on the knoll), the arch over the bridge, the station roof and the east colonnade.
Sim.LeafCover={
	{name="Rotunda",x=-60,z=50,r=8.2},           -- W7_Rotunda__palette, 45 cells
	{name="BridgeArch",x=5,z=20.6,r=14.8},       -- W7_Architecture__palette, 29 cells
	{name="BridgeArchSide",x=-6,z=24.7,r=3.4},   -- W7_Architecture__palette, 3 cells
	{name="WestColonnade",x=-36.4,z=-25.1,r=11.8}, -- W7_Architecture__trim, 9 cells
	{name="StationRoof",x=-46,z=-8.7,r=3.4},     -- W7_Stations__wood_plank, 3 cells
	{name="EastColonnade",x=85,z=57.4,r=8.4},    -- W7_Architecture__trim, 10 cells
}
-- The probe has run: leaves show on the beta (beta 13).
Sim.LeafCoverChecked=true

-- The Acceleration for gust g (0 to 1) at time t: downwind lean, a slow sideways sway, a gentle fall.
function Sim.leafWind(g,t)
	local L=Sim.Leaf
	g=if type(g)=="number"and g==g then math.clamp(g,0,1)else 0
	t=if type(t)=="number"and t==t then t else 0
	local dir=Wind.Direction
	local cross=Vector3.new(-dir.Z,0,dir.X)
	return dir*(L.lean+L.gust*g)+cross*(L.sway*math.sin(2*math.pi*t/L.swayPeriod))+Vector3.new(0,-L.fall,0)
end
-- How far a leaf let go at t0 drifts on the ground plane over `life` seconds under the real wind at `position`:
-- (along the wind, across it). Exponential drag as ParticleEmitter.Drag (half the speed every 1 / drag seconds), the
-- launch at its fastest straight downwind (the worst case).
function Sim.leafDrift(t0,life,position,dt)
	local L=Sim.Leaf
	dt=dt or 1/30
	local dir=Wind.Direction
	local cross=Vector3.new(-dir.Z,0,dir.X)
	local k=L.drag*math.log(2)
	local v=dir*(L.speed[2]*math.sin(math.rad(L.spread)))
	local x=Vector3.zero
	local t=t0
	while t<t0+life do
		local a=Sim.leafWind(Wind.gust(position,t),t)
		a=Vector3.new(a.X,0,a.Z)
		v+=(a-v*k)*dt
		x+=v*dt
		t+=dt
	end
	return x:Dot(dir),x:Dot(cross)
end
-- The covered place a leaf starting over (x, z) would drift under, or nil: its path is the segment from (x, z) to
-- reach studs downwind; refused when that passes within r + side of a cover's middle.
function Sim.leafCovered(x,z,cover)
	local L=Sim.Leaf
	local dir=Wind.Direction
	local line={x,z,x+dir.X*L.reach,z+dir.Z*L.reach}
	for _,place in ipairs(cover or Sim.LeafCover)do
		if Sim.lineDistance(place.x,place.z,line)<place.r+L.side then return place.name or "cover"end
	end
	return nil
end
-- A spawn point for one leaf round `centre` (the player), or nil and why: "ground" off the island (world.ground answers
-- nil), or the covered place's name.
function Sim.leafSpot(random,centre,world)
	local L=Sim.Leaf
	if typeof(centre)~="Vector3"then return nil,"centre"end
	local x=centre.X+random:NextNumber(-L.half,L.half)
	local z=centre.Z+random:NextNumber(-L.half,L.half)
	local y=random:NextNumber(-L.band,L.band)
	local ground=world and world.ground and world.ground(x,z)
	if type(ground)~="number"or ground~=ground or math.abs(ground)==math.huge then return nil,"ground"end
	local covered=Sim.leafCovered(x,z,world.cover)
	if covered then return nil,covered end
	return Vector3.new(x,ground+L.height+y,z)
end

local Leaves={};Leaves.__index=Leaves
Sim.Leaves=Leaves
function Leaves.new(seed)return setmetatable({random=Random.new(seed or 4),live={},carry=0},Leaves)end
function Leaves:count(now)
	local live=self.live
	for i=#live,1,-1 do if live[i]<=now then table.remove(live,i)end end
	return #live
end
function Leaves:clear()table.clear(self.live);self.carry=0 end
-- One step: {{kind = 1 | 2 | 3, at = Vector3}, ...}, at most one emit per kind a step (the rest carries). g: the gust
-- 0 to 1. place(kind, random) -> Vector3? is Sim.leafSpot round the player; nil skips that emit (the carry is spent).
-- The live count holds each kind's longest life, so the cap is never passed; at the cap nothing piles up.
function Leaves:step(now,dt,g,cap,level,place)
	local L=Sim.Leaf
	local out={}
	local rate=L.rate[Sim.level(level)+1]
	cap=cap or 0
	if not rate or cap<=0 then self.carry=0;return out end
	dt=if type(dt)=="number"and dt==dt then math.clamp(dt,0,.25)else 0
	g=if type(g)=="number"and g==g then math.clamp(g,0,1)else 0
	self.carry+=rate*(1+L.boost*g)*dt
	local room=cap-self:count(now)
	local used={}
	while self.carry>=1 do
		if room<=0 then self.carry=math.min(self.carry,1);break end
		local roll,kind=self.random:NextNumber(),3
		if roll<L.share[1]then kind=1 elseif roll<L.share[1]+L.share[2]then kind=2 end
		if used[kind]then break end
		used[kind]=true
		self.carry-=1
		local at=place and place(kind,self.random)
		if typeof(at)=="Vector3"then
			table.insert(self.live,now+L.life[kind][2])
			room-=1
			table.insert(out,{kind=kind,at=at})
		end
	end
	return out
end

-- Bubbles (brief B7; plan revision 3) --------------------------------------------------------------------------
Sim.BubbleEvery=3
Sim.BubbleLife=9
Sim.BubbleAhead=table.freeze({10,16}) -- studs in front of the camera
Sim.BubbleSide=4
Sim.BubbleRise=.4
Sim.BubbleDrift=table.freeze({1.5,3})
-- LOOK-R2 4: two emitters of one fixed diameter each (Size is never written after creation), 60% small.
Sim.BubbleSizes=table.freeze({small=.62,large=.95})
Sim.BubbleSmall=.6
local Bubbles={};Bubbles.__index=Bubbles
Sim.Bubbles=Bubbles
function Bubbles.new(seed)return setmetatable({random=Random.new(seed or 1),live={},nextAt=nil},Bubbles)end
function Bubbles:count(now)
	local live=self.live
	for i=#live,1,-1 do if live[i]<=now then table.remove(live,i)end end
	return #live
end
-- True when one is due now: one every BubbleEvery seconds, under the cap and allowed (no menu, day). A slot that
-- is not used (refused, full, a menu) is skipped, never saved up.
function Bubbles:due(now,cap,allowed)
	if not self.nextAt then self.nextAt=now+Sim.BubbleEvery;return false end
	if now<self.nextAt then return false end
	self.nextAt=now+Sim.BubbleEvery
	return allowed==true and self:count(now)<(cap or 0)
end
-- Counts one in and returns which emitter it comes from: "small" (60%) or "large".
function Bubbles:emit(now)
	table.insert(self.live,now+Sim.BubbleLife)
	return if self.random:NextNumber()<Sim.BubbleSmall then "small"else "large"
end
function Bubbles:clear()table.clear(self.live);self.nextAt=nil end
-- Where the next bubble starts: 10 to 16 studs ahead of the camera on the ground plane, up to 4 to a side, about
-- eye height less a little. nil and the reason when that spot is in the way.
function Sim.bubbleSpot(camera,random,world)
	if typeof(camera)~="CFrame"then return nil,"camera"end
	local look=camera.LookVector
	local ahead=Vector3.new(look.X,0,look.Z)
	ahead=if ahead.Magnitude>1e-3 then ahead.Unit else Vector3.new(0,0,-1)
	local side=Vector3.new(-ahead.Z,0,ahead.X)
	local eye=camera.Position
	local at=eye+ahead*random:NextNumber(Sim.BubbleAhead[1],Sim.BubbleAhead[2])+side*random:NextNumber(-Sim.BubbleSide,Sim.BubbleSide)
	local y=eye.Y-2+random:NextNumber()*2
	local ground=world and world.groundY and world.groundY(at.X,at.Z)
	if type(ground)=="number"and ground==ground then y=math.max(y,ground+1)end
	at=Vector3.new(at.X,y,at.Z)
	local ok,why=Sim.clear(at,world)
	if not ok then return nil,why end
	return at
end

-- Butterflies (brief C3; round 3: GARDEN-LIFE-NEST-LOOK 1) --------------------------------------------------------
-- One continuous wing angle (a flap with glides, a slow fan at rest, every change blended), each butterfly with its
-- own Random (drawn from the spawner's at birth), so its flight is a function of time, whatever the step rate.
-- Night: they fly while the garden hour's daylight is over .30 and spawn over .34; under .30 each one hands off to a
-- firefly, 1.5 s apart, colour slot 1 first (a glow at the body, wings fading), and is gone 6 s after its hand-off
-- starts; under .24 (a jump past dusk) the wings just fade in .5 s. Every spawn fades its wings in over 1.2 s.
local function smooth(t)t=math.clamp(t,0,1);return t*t*(3-2*t)end
Sim.Butterfly=table.freeze({reach=60,wander=3,speed=.65,restMin=2,restMax=4,low=1.2,high=2.4,perch=.35,restChance=.35,
	spawnGap=.5,pitch=10,
	flapHz=table.freeze({3.0,2.2}),flapMid=22,flapAmp=38,glideAngle=28, -- QA-R2-LOOK 4: small things beat faster
	glideEvery=table.freeze({1.6,3.2}),glideFor=table.freeze({.6,1.1}),envelope=.25,glideSink=.25,climb=.6,
	bob=.04,drift=.15,driftHz=.4,wobble=12,wobbleHz=.5,
	restMid=62,restAmp=14,restHz=.25,blend=.5,fadeIn=1.2,
	fly=.30,spawn=.34,handFloor=.24,handGap=1.5,handFade=1.5,handEnd=5,handGone=6,fadeOut=.5,
	glowFrom=.2,glowTo=.9,glowLit=.1,glowDim=.55,glowPulse=1.8,glowSpeed=.25,glowRise=table.freeze({1.5,2}),glowClimb=1.2})
local Butterflies={};Butterflies.__index=Butterflies
Sim.Butterflies=Butterflies
function Butterflies.new(seed)return setmetatable({random=Random.new(seed or 2),list={},spawnAt=0,handed={}},Butterflies)end
function Butterflies:clear()table.clear(self.list);table.clear(self.handed);self.spawnAt=0 end
local function wanderPoint(r,patch,radius,low,high)
	local a,d=r:NextNumber()*math.pi*2,math.sqrt(r:NextNumber())*radius
	return Vector3.new(patch.X+math.cos(a)*d,patch.Y+r:NextNumber(low,high),patch.Z+math.sin(a)*d)
end
-- The glide timetable runs on its own clock: catch it up to `now` (any number of glides at once).
local function glides(b,now)
	local B=Sim.Butterfly
	while now>=b.glideEnd do
		b.lastGlide=b.glideEnd
		b.glideAt=b.glideEnd+b.clock:NextNumber(B.glideEvery[1],B.glideEvery[2])
		b.glideEnd=b.glideAt+b.clock:NextNumber(B.glideFor[1],B.glideFor[2])
	end
end
local function dark(daylight)return type(daylight)=="number"and daylight==daylight and daylight<=Sim.Butterfly.fly end
-- patches: {Vector3} (flower patch middles on the ground). Spawns at most one every spawnGap seconds, on a patch
-- within reach of the camera that is clear (Sim.clear), one of each wing slot (1 to 4). Drops the far ones and any
-- over the cap at once. still = Reduced Motion: none. daylight: the garden hour's (nil with the hour off: day).
-- world.ground(x, z) -> y? is where a firefly rises from (else the patch).
function Butterflies:step(now,dt,world,patches,cap,still,daylight)
	local B,list=Sim.Butterfly,self.list
	local camera=world and world.camera
	if still or not camera then table.clear(list);return list end
	for i=#list,1,-1 do
		local b=list[i]
		local gone=b.hand~=nil and now-b.hand>=B.handGone
		local far=(b.position-camera).Magnitude>Sim.Drop
		if i>cap or far or gone or(b.fade and now-b.fade>=B.fadeOut)then
			table.remove(list,i)
			-- Beta 14 B2: a glow that finished its hand-off is passed on to the night population (GardenLife adopts it).
			if gone and i<=cap and not far then table.insert(self.handed,b.position)end
		end
	end
	if dark(daylight)then
		local fresh,last={},-math.huge
		for _,b in ipairs(list)do
			if b.hand then last=math.max(last,b.hand)elseif not b.fade then table.insert(fresh,b)end
		end
		if #fresh>0 then
			table.sort(fresh,function(a,c)return a.colour<c.colour end)
			if daylight>=B.handFloor then
				local start=math.max(now,last+B.handGap)
				for i,b in ipairs(fresh)do b.hand=start+(i-1)*B.handGap end
			else
				for _,b in ipairs(fresh)do b.fade=now end
			end
		end
	end
	local spawn=not(type(daylight)=="number"and daylight==daylight and daylight<=B.spawn)
	if spawn and #list<cap and now>=self.spawnAt and patches then
		self.spawnAt=now+B.spawnGap
		local near={}
		for _,patch in ipairs(patches)do
			if(patch-camera).Magnitude<=B.reach and Sim.clear(patch,world)then
				local used=false
				for _,b in ipairs(list)do if b.patch==patch then used=true;break end end
				if not used then table.insert(near,patch)end
			end
		end
		if #near>0 then
			local patch=near[self.random:NextInteger(1,#near)]
			local r=Random.new(self.random:NextInteger(1,1073741823))
			local start=wanderPoint(r,patch,B.wander,B.low,B.high)
			if Sim.clear(start,world)then
				local taken={}
				for _,b in ipairs(list)do taken[b.colour]=true end
				local colour=1
				while taken[colour]do colour+=1 end
				-- Its own clock for the glides (a Random of its own, drawn only by the timetable), so the glides are the
				-- same whatever the step rate.
				local clock=Random.new(r:NextInteger(1,1073741823))
				local b={patch=patch,position=start,target=wanderPoint(r,patch,B.wander,B.low,B.high),mode="fly",random=r,
					clock=clock,colour=colour,phase=r:NextNumber()*10,heading=Vector3.new(0,0,-1),born=now,lastGlide=-math.huge}
				b.glideAt=now+clock:NextNumber(B.glideEvery[1],B.glideEvery[2])
				b.glideEnd=b.glideAt+clock:NextNumber(B.glideFor[1],B.glideFor[2])
				table.insert(list,b)
			end
		end
	end
	local ground=world and world.ground
	for _,b in ipairs(list)do
		glides(b,now)
		local r=b.random
		local h=b.hand and now-b.hand
		if h and h>=B.handFade then
			-- A firefly: no wings, slowing to .25, rising to 1.5 to 2 studs over the ground.
			if b.mode~="glow"then
				b.mode="glow"
				local g=ground and ground(b.position.X,b.position.Z)
				b.glowY=(if type(g)=="number"and g==g then g else b.patch.Y)+r:NextNumber(B.glowRise[1],B.glowRise[2])
				b.target=wanderPoint(r,b.patch,B.wander,0,0)
			end
			local speed=B.speed+(B.glowSpeed-B.speed)*smooth((h-B.handFade)/(B.handEnd-B.handFade))
			local to=Vector3.new(b.target.X-b.position.X,0,b.target.Z-b.position.Z)
			local step=speed*dt
			local flatAt
			if to.Magnitude<=math.max(step,.05)then
				flatAt=Vector3.new(b.target.X,0,b.target.Z)
				b.target=wanderPoint(r,b.patch,B.wander,0,0)
			else
				flatAt=Vector3.new(b.position.X,0,b.position.Z)+to.Unit*step
				b.heading=to.Unit
			end
			local y=b.position.Y+(b.glowY-b.position.Y)*math.min(1,dt*B.glowClimb)
			b.position=Vector3.new(flatAt.X,y,flatAt.Z)
		elseif b.mode=="rest"then
			if now>=b.restUntil then
				b.mode,b.switchAt="fly",now
				b.target=wanderPoint(r,b.patch,B.wander,B.low,B.high)
			end
		else
			local to=b.target-b.position
			local step=B.speed*dt
			if to.Magnitude<=math.max(step,.05)then
				b.position=b.target
				if b.mode=="land"then
					b.mode,b.switchAt="rest",now
					b.restUntil=now+r:NextNumber(B.restMin,B.restMax)
				elseif r:NextNumber()<B.restChance then
					b.mode="land";b.target=wanderPoint(r,b.patch,B.wander*.5,B.perch,B.perch)
				else
					b.target=wanderPoint(r,b.patch,B.wander,B.low,B.high)
				end
			else
				local unit=to.Unit
				b.position+=unit*step
				local level=Vector3.new(unit.X,0,unit.Z)
				if level.Magnitude>1e-3 then b.heading=level.Unit end
			end
		end
	end
	return list
end
-- 1 while flapping, 0 in a glide, smoothstepped over `envelope` each way.
function Sim.butterflyEnvelope(b,now)
	local B=Sim.Butterfly
	if now<b.glideAt then return smooth(math.min(now-b.lastGlide,b.glideAt-now)/B.envelope)end
	if now<b.glideEnd then return 0 end
	return smooth((now-b.glideEnd)/B.envelope)
end
local function flightAngle(b,now,level)
	local B=Sim.Butterfly
	local f=B.flapHz[math.min(Sim.level(level),1)+1]
	local flap=B.flapMid+B.flapAmp*math.sin(2*math.pi*f*(now+b.phase))
	return B.glideAngle+(flap-B.glideAngle)*Sim.butterflyEnvelope(b,now)
end
local function restAngle(b,now)
	local B=Sim.Butterfly
	return B.restMid+B.restAmp*math.sin(2*math.pi*B.restHz*(now+b.phase))
end
-- How much of the flight's bob, wobble and pitch shows: 0 at rest, easing out on the way down to a flower and back in
-- over `blend` after leaving one.
local function airborne(b,now)
	local B=Sim.Butterfly
	if b.mode=="rest"then return 0 end
	if b.mode=="land"then return math.clamp((b.target-b.position).Magnitude/.8,0,1)end
	if b.switchAt and now-b.switchAt<B.blend then return smooth((now-b.switchAt)/B.blend)end
	return 1
end
-- Wing angle (radians): the flight's flap and glides, the slow fan at rest; a change between the two blends over .5 s.
function Sim.butterflyFlap(b,now,level)
	local B=Sim.Butterfly
	local resting=b.mode=="rest"
	local current=if resting then restAngle(b,now)else flightAngle(b,now,level)
	if b.switchAt and now-b.switchAt<B.blend then
		local before=if resting then flightAngle(b,now,level)else restAngle(b,now)
		current=before+(current-before)*smooth((now-b.switchAt)/B.blend)
	end
	return math.rad(current)
end
-- The root pose: travel heading with a slow yaw wobble, nose up, the bob in step with the flap (up on the down
-- stroke) plus a slow drift, and the glide's sink.
function Sim.butterflyRoot(b,now,level)
	local B=Sim.Butterfly
	local yaw=math.atan2(-b.heading.X,-b.heading.Z)
	if b.mode=="glow"then return CFrame.new(b.position)*CFrame.Angles(0,yaw,0)end
	local k=airborne(b,now)
	if k<=0 then return CFrame.new(b.position)*CFrame.Angles(0,yaw,0)end
	local t=now+b.phase
	local f=B.flapHz[math.min(Sim.level(level),1)+1]
	local e=Sim.butterflyEnvelope(b,now)
	local sink=0
	if now>=b.glideAt and now<b.glideEnd then sink=B.glideSink*smooth((now-b.glideAt)/(b.glideEnd-b.glideAt))
	elseif now-b.lastGlide<B.climb then sink=B.glideSink*(1-smooth((now-b.lastGlide)/B.climb))end
	local bob=-B.bob*math.cos(2*math.pi*f*t)*e+B.drift*math.sin(2*math.pi*B.driftHz*t)-sink
	yaw+=math.rad(B.wobble)*math.sin(2*math.pi*B.wobbleHz*t)*k
	return CFrame.new(b.position+Vector3.new(0,bob*k,0))*CFrame.Angles(0,yaw,0)*CFrame.Angles(math.rad(B.pitch)*k,0,0)
end
-- What to paint: {wing, body} transparencies (0 shown) and glow = nil or {size, transparency} (the hand-off).
function Sim.butterflyLook(b,now)
	local B=Sim.Butterfly
	local wing=1-smooth((now-b.born)/B.fadeIn)
	local body=0
	local glow=nil
	if b.fade then
		local k=smooth((now-b.fade)/B.fadeOut)
		wing,body=math.max(wing,k),k
	end
	local h=b.hand and now-b.hand
	if h and h>=0 then
		if h<B.handFade then
			local k=smooth(h/B.handFade)
			wing,body=math.max(wing,k),k
			glow={size=B.glowFrom+(B.glowTo-B.glowFrom)*k,transparency=1-(1-B.glowLit)*k}
		else
			wing,body=1,1
			local pulse=B.glowLit+(B.glowDim-B.glowLit)*(.5-.5*math.cos(2*math.pi*(h-B.handFade)/B.glowPulse))
			if h>=B.handEnd then pulse+=(1-pulse)*smooth((h-B.handEnd)/(B.handGone-B.handEnd))end
			glow={size=B.glowTo,transparency=math.min(1,pulse)}
		end
	end
	return{wing=wing,body=body,glow=glow}
end
-- Body, wing L, wing R (QA-R2-LOOK 4: span .52, a tenth of the avatar). Each wing is a plate built standing (its
-- Front/Back decals upright) and laid flat by the last -90 about X: image top forward, the Back face up. The wings
-- leave from the body's mid-line, and the body sits a little forward so a little head shows past the fore wings.
local flat90=CFrame.Angles(math.rad(-90),0,0)
Sim.ButterflyWing=table.freeze({hinge=.013,half=.12,forward=.013})
function Sim.butterflyParts(root,phi)
	local W=Sim.ButterflyWing
	return{root*CFrame.new(0,0,-W.forward),
		root*CFrame.new(-W.hinge,0,0)*CFrame.Angles(0,0,-phi)*CFrame.new(-W.half,0,0)*flat90,
		root*CFrame.new(W.hinge,0,0)*CFrame.Angles(0,0,phi)*CFrame.new(W.half,0,0)*flat90}
end

-- Fireflies at night (beta 14 QA B2; GARDEN-LIFE-BUILD-PLAN section 3) ----------------------------------------------
-- A population of their own while the garden hour is dark: the count follows the shared daylight (none over .34, the
-- full cap by .20), so they come out through dusk and leave at dawn, staggered. Each one hovers over a flower patch or a
-- point on a water bank within reach of the camera, else on a ring round the player; 1.5 to 3 studs up, wandering
-- slowly, with a soft pulse. A butterfly whose hand-off finished is adopted where it is (GardenLife passes it on). The
-- hour off (daylight nil): none. Reduced Motion: none. Each firefly has its own Random.
Sim.Firefly=table.freeze({start=.34,full=.20,spawnGap=1.5,fadeIn=1.2,fadeOut=2,fadeGap=.8,reach=40,ring=table.freeze({6,18}),
	low=1.5,high=3,speed=.25,wander=2.5,pulse=1.8,lit=.1,dim=.55,size=.9,pool=.6,tries=4,hz=15,climb=1.2})
-- How many fireflies the daylight wants out of `cap` (0 by day and with the hour off).
function Sim.fireflyWanted(daylight,cap)
	local F=Sim.Firefly
	if type(daylight)~="number"or daylight~=daylight or type(cap)~="number"or cap<=0 then return 0 end
	local ramp=math.clamp((F.start-daylight)/(F.start-F.full),0,1)
	return math.min(cap,math.floor(cap*ramp+.5))
end
local Fireflies={};Fireflies.__index=Fireflies
Sim.Fireflies=Fireflies
function Fireflies.new(seed)return setmetatable({random=Random.new(seed or 5),list={},spawnAt=-math.huge,serial=0},Fireflies)end
function Fireflies:clear()table.clear(self.list);self.spawnAt=-math.huge end
local function fireflyEntry(self,now,spot,at,glowY,lit)
	local F=Sim.Firefly
	self.serial+=1
	local r=Random.new(self.random:NextInteger(1,1073741823))
	local taken={}
	for _,f in ipairs(self.list)do taken[f.slot]=true end
	local slot=1
	while taken[slot]do slot+=1 end
	local f={id=self.serial,slot=slot,spot=spot,position=at,glowY=glowY,random=r,phase=r:NextNumber()*F.pulse,
		born=if lit then now-F.fadeIn else now}
	f.target=Vector3.new(spot.X+r:NextNumber(-F.wander,F.wander),0,spot.Z+r:NextNumber(-F.wander,F.wander))
	table.insert(self.list,f)
	return f
end
-- A spot to hover over, or nil: a flower patch or a bank point within reach of the camera (from that pool 60% of the
-- time), else a point on the ring round the player on safe ground; Sim.clear always, never a spot already in use.
function Sim.fireflySpot(random,world,spots,used)
	local F=Sim.Firefly
	local camera=world and world.camera
	if typeof(camera)~="Vector3"then return nil end
	used=used or {}
	local pool={}
	for _,list in ipairs({spots and spots.patches or {},spots and spots.banks or {}})do
		for _,spot in ipairs(list)do
			if typeof(spot)=="Vector3"and not used[spot]and(spot-camera).Magnitude<=F.reach and Sim.clear(spot,world)then table.insert(pool,spot)end
		end
	end
	local function fromPool()return if #pool>0 then pool[random:NextInteger(1,#pool)]else nil end
	if #pool>0 and random:NextNumber()<F.pool then return fromPool()end
	local centre=if typeof(world.player)=="Vector3"then world.player else camera
	for _=1,F.tries do
		local a,d=random:NextNumber()*math.pi*2,random:NextNumber(F.ring[1],F.ring[2])
		local x,z=centre.X+math.cos(a)*d,centre.Z+math.sin(a)*d
		local g=world.ground and world.ground(x,z)
		if type(g)=="number"and g==g and math.abs(g)<math.huge and(not world.safe or world.safe(x,z))then
			local at=Vector3.new(x,g,z)
			if Sim.clear(at,world)then return at end
		end
	end
	return fromPool()
end
-- A butterfly whose hand-off finished stays a firefly: adopted where it is, already lit. False at the cap or when
-- `position` is not a place.
function Fireflies:adopt(now,position,cap)
	if typeof(position)~="Vector3"or #self.list>=(cap or 0)then return false end
	fireflyEntry(self,now,Vector3.new(position.X,position.Y-Sim.Firefly.low,position.Z),position,position.Y,true)
	return true
end
-- One step: the live list. world {camera, player, ground(x, z), safe(x, z), stations, pad, course}; spots {patches,
-- banks}; still = Reduced Motion (none); daylight: the garden hour's (nil: none).
function Fireflies:step(now,dt,world,spots,cap,still,daylight)
	local F,list=Sim.Firefly,self.list
	local camera=world and world.camera
	cap=cap or 0
	if still or typeof(camera)~="Vector3"or cap<=0 then table.clear(list);return list end
	for i=#list,1,-1 do
		local f=list[i]
		if i>cap or(f.position-camera).Magnitude>Sim.Drop or(f.fade and now-f.fade>=F.fadeOut)then table.remove(list,i)end
	end
	local live={}
	for _,f in ipairs(list)do if not f.fade then table.insert(live,f)end end
	local wanted=Sim.fireflyWanted(daylight,cap)
	if #live>wanted then
		-- The farthest from the camera go first, fadeGap apart.
		table.sort(live,function(a,b)return(a.position-camera).Magnitude>(b.position-camera).Magnitude end)
		for i=1,#live-wanted do live[i].fade=now+(i-1)*F.fadeGap end
	elseif #live<wanted and #list<cap and now>=self.spawnAt then
		self.spawnAt=now+F.spawnGap
		local used={}
		for _,f in ipairs(list)do used[f.spot]=true end
		local spot=Sim.fireflySpot(self.random,world,spots,used)
		if spot then
			local glowY=spot.Y+self.random:NextNumber(F.low,F.high)
			fireflyEntry(self,now,spot,Vector3.new(spot.X,glowY,spot.Z),glowY,false)
		end
	end
	dt=if type(dt)=="number"and dt==dt then math.clamp(dt,0,.25)else 0
	for _,f in ipairs(list)do
		local to=Vector3.new(f.target.X-f.position.X,0,f.target.Z-f.position.Z)
		local step=F.speed*dt
		local flat
		if to.Magnitude<=math.max(step,.05)then
			flat=Vector3.new(f.target.X,0,f.target.Z)
			local r=f.random
			f.target=Vector3.new(f.spot.X+r:NextNumber(-F.wander,F.wander),0,f.spot.Z+r:NextNumber(-F.wander,F.wander))
		else
			flat=Vector3.new(f.position.X,0,f.position.Z)+to.Unit*step
		end
		local y=f.position.Y+(f.glowY-f.position.Y)*math.min(1,dt*F.climb)
		f.position=Vector3.new(flat.X,y,flat.Z)
	end
	return list
end
-- The glow's transparency now (0 shown, 1 gone): the soft pulse, faded in after birth and out after `fade`.
function Sim.fireflyLook(f,now)
	local F=Sim.Firefly
	local pulse=F.lit+(F.dim-F.lit)*(.5-.5*math.cos(2*math.pi*(now-f.born+f.phase)/F.pulse))
	local shown=smooth((now-f.born)/F.fadeIn)
	if f.fade then shown*=1-smooth((now-f.fade)/F.fadeOut)end
	return 1-(1-pulse)*shown
end

-- Birds (brief C1; round 3: GARDEN-LIFE-NEST-LOOK 3) ---------------------------------------------------------------
-- A small round songbird: a body, a head it turns and cocks on its own, bead eyes, a short beak, folded wings, a tail
-- that flicks on every landing and hop. Low quick hops, often in pairs; it turns by hopping; it flies in bounds (two
-- beats, wings tucked, two beats). Everything eased; nothing is a two-pose swap. Each bird has its own Random.
-- QA-R2-LOOK 3 and FABLE-REVIEW-R3 3: a songbird, upright (the body 35 degrees nose-up), the head on top of the raised
-- chest, a bright half-buried beak, a solid wedge of a tail and two thin legs. `lift` stands the feet on the perch (legs
-- end .39 under the body's centre). The tail angle here is positive DOWN (Fable counts up): rest 10 down (her -10), the
-- flick to 10 above level (her +10).
Sim.Bird=table.freeze({lift=.39,land=.8,leave=1.2,stayMin=8,stayMax=20,flee=12,
	fromMin=9,fromMax=12,upMin=4,upMax=6,riseMin=5,riseMax=7,away=10,
	dip=.12,dipPitch=12,dipIn=.10,dipOut=.15,
	hop=.16,hopTime=.18,hopDip=.06,hopDipTime=.08,pair=.4,pairGap=.12,flick=15,flickTime=.12,
	tail=10,tailUp=-10,tailTime=.16,
	headEveryMin=.8,headEveryMax=2.5,headMin=25,headMax=50,headTime=.12,cock=.3,cockRoll=15,
	turnMin=20,turnMax=45,turnEveryMin=2.5,turnEveryMax=5,turnTime=.15,crouch=.10,crouchTime=.08,diveTilt=15,level=.2,
	beatHz=table.freeze({5.5,3.5}),beats=2,beatMid=15,beatAmp=50,tuckTime=.22,tuckDip=.12,tuckBlend=.06})
local Birds={};Birds.__index=Birds
Sim.Birds=Birds
function Birds.new(seed)return setmetatable({random=Random.new(seed or 3),list={}},Birds)end
function Birds:clear()table.clear(self.list)end
function Birds:find(perch)
	for _,bird in ipairs(self.list)do if bird.perch==perch then return bird end end
	return nil
end
local function yawOf(direction)return math.atan2(-direction.X,-direction.Z)end
-- A hop now, and 40% of the time a second one .12 s after it lands.
local function hop(bird,now)
	local B=Sim.Bird
	bird.hopAt=now
	bird.hop2=if bird.random:NextNumber()<B.pair then now+B.hopTime+B.pairGap else nil
end
-- A chirp from AmbientAudio's perch `perch` (its landing spot `landing`, or nil). "land" (a bird comes in), "hop"
-- (one already sits there), or nil and why: no spot, the cap, a station or the camera in the way, already busy, night
-- (day = false: the garden hour's night lands no new bird; one already sitting still hops and sits out its stay).
-- Reduced Motion: it is just there, folded; no hop.
function Birds:chirp(now,perch,landing,cap,world,reduced,day)
	local B,r=Sim.Bird,self.random
	if typeof(landing)~="Vector3"then return nil,"spot"end
	local bird=self:find(perch)
	if bird then
		if bird.state=="sit"and not reduced then hop(bird,now);return "hop"end
		return nil,"busy"
	end
	if day==false then return nil,"night"end
	if #self.list>=(cap or 0)then return nil,"cap"end
	-- A crown top: only the camera and the stations matter (the course and the pad are on the ground).
	local ok,why=Sim.clear(landing,{camera=world and world.camera,stations=world and world.stations})
	if not ok then return nil,why end
	local a=r:NextNumber()*math.pi*2
	local out=Vector3.new(math.cos(a),0,math.sin(a))
	local from=landing+out*r:NextNumber(B.fromMin,B.fromMax)+Vector3.new(0,r:NextNumber(B.upMin,B.upMax),0)
	local own=Random.new(r:NextInteger(1,1073741823))
	bird={perch=perch,spot=landing,from=from,start=now,state=if reduced then "sit"else "land",colour=perch%3,random=own,
		yaw=yawOf(-out),stayUntil=now+r:NextNumber(B.stayMin,B.stayMax),turnAt=now+r:NextNumber(B.turnEveryMin,B.turnEveryMax),
		head={yaw=0,roll=0,fromYaw=0,fromRoll=0,at=-math.huge},headAt=now+B.land+own:NextNumber(B.headEveryMin,B.headEveryMax)}
	if reduced then bird.landedAt=-math.huge end
	table.insert(self.list,bird)
	return "land"
end
-- Moves every bird on: landed, stayed long enough or the player within `flee`: off it goes (Reduced Motion: gone).
-- Returns the live list; each has root (CFrame), wings ("fly" | "perch"), flick (0 to 1), phi, tuck, head, tau.
function Birds:step(now,world,reduced,cap,level)
	local B,r,list=Sim.Bird,self.random,self.list
	world=world or {}
	for i=#list,1,-1 do
		local bird=list[i]
		local camera=world.camera
		if(camera and(bird.spot-camera).Magnitude>Sim.Drop)or i>(cap or math.huge)then
			table.remove(list,i);continue
		end
		if reduced and bird.state~="sit"then
			if bird.state=="land"then bird.state="sit";bird.landedAt=-math.huge;bird.hopAt=nil;bird.hop2=nil
			else table.remove(list,i);continue end
		end
		if reduced and bird.head and(bird.head.at~=-math.huge or bird.hopAt or bird.turnStart)then
			-- Reduced Motion while perched: head straight, no hop or turn in flight, the tail at rest, at once.
			bird.head={yaw=0,roll=0,fromYaw=0,fromRoll=0,at=-math.huge}
			bird.hopAt,bird.hop2,bird.turnStart=nil,nil,nil
			bird.landedAt=-math.huge
		end
		if bird.state=="land"and now-bird.start>=B.land then bird.state="sit";bird.landedAt=now end
		if bird.state=="sit"then
			local player=world.player
			if now>=bird.stayUntil or(player and(player-bird.spot).Magnitude<B.flee)then
				if reduced then table.remove(list,i);continue end
				local away=if player then Vector3.new(bird.spot.X-player.X,0,bird.spot.Z-player.Z)else Vector3.zero
				if away.Magnitude<1e-3 then away=Vector3.new(-math.sin(bird.yaw),0,-math.cos(bird.yaw))end
				bird.state,bird.leaveAt,bird.away,bird.rise="leave",now,away.Unit,r:NextNumber(B.riseMin,B.riseMax)
			elseif not reduced then
				local own=bird.random
				if now>=bird.turnAt then
					-- Birds turn by hopping.
					bird.turnAt=now+own:NextNumber(B.turnEveryMin,B.turnEveryMax)
					bird.turnFrom,bird.turnStart=bird.yaw,now
					bird.yaw+=math.rad(own:NextNumber(B.turnMin,B.turnMax))*(if own:NextNumber()<.5 then -1 else 1)
					hop(bird,now)
				end
				if now>=bird.headAt then
					-- The head alone snaps to a new look, 30% of the time with a cock, and holds it.
					local head=bird.head
					local k=smooth((now-head.at)/B.headTime)
					head.fromYaw=head.fromYaw+(head.yaw-head.fromYaw)*k
					head.fromRoll=head.fromRoll+(head.roll-head.fromRoll)*k
					head.yaw=own:NextNumber(B.headMin,B.headMax)*(if own:NextNumber()<.5 then -1 else 1)
					head.roll=if own:NextNumber()<B.cock then B.cockRoll*(if own:NextNumber()<.5 then -1 else 1)else 0
					head.at=now
					bird.headAt=now+own:NextNumber(B.headEveryMin,B.headEveryMax)
				end
			end
		end
		if bird.state=="leave"and now-bird.leaveAt>=B.crouchTime+B.leave then table.remove(list,i);continue end
		Sim.birdPose(bird,now,level)
	end
	return list
end
-- Bounding flight `t` seconds in: the wing angle (degrees), how far the wings are tucked (0 beating, 1 folded) and
-- the root's dip while they are folded. Two beats, then a .22 s tuck; level 1 beats at 3.5 Hz.
function Sim.birdBeat(t,level)
	local B=Sim.Bird
	local hz=B.beatHz[math.min(Sim.level(level),1)+1]
	local beating=B.beats/hz
	local c=math.max(t,0)%(beating+B.tuckTime)
	if c<beating then
		local tuck=math.max(1-smooth(c/B.tuckBlend),smooth((c-beating+B.tuckBlend)/B.tuckBlend))
		return B.beatMid+B.beatAmp*math.sin(2*math.pi*hz*c),tuck,0
	end
	return B.beatMid,1,B.tuckDip*math.sin(math.pi*(c-beating)/B.tuckTime)
end
-- The tail's angle: 20 at rest, up to 2 and back over .16 s after a landing or a hop.
local function tailAt(bird,now)
	local B=Sim.Bird
	local last=-math.huge
	local a,b,c=bird.landedAt,bird.hopAt,bird.hop2
	if a and a<=now and a>last then last=a end
	if b and b<=now and b>last then last=b end
	if c and c<=now and c>last then last=c end
	local u=(now-last)/B.tailTime
	if u<0 or u>=1 then return B.tail end
	local k=if u<.5 then smooth(u*2)else smooth((1-u)*2)
	return B.tail-(B.tail-B.tailUp)*k
end
-- Writes bird.root, wings, flick, phi (radians), tuck, head (a CFrame turn) and tau (degrees) for now.
function Sim.birdPose(bird,now,level)
	local B=Sim.Bird
	local lift=Vector3.new(0,B.lift,0)
	bird.head=bird.head or {yaw=0,roll=0,fromYaw=0,fromRoll=0,at=-math.huge}
	bird.tau,bird.turn,bird.still=B.tail,CFrame.identity,false
	if bird.state=="land"then
		local t=math.clamp((now-bird.start)/B.land,0,1)
		local s=1-(1-t)^2
		local phi,tuck,dip=Sim.birdBeat(now-bird.start,level)
		local at=bird.from:Lerp(bird.spot,s)+Vector3.new(0,math.sin(math.pi*t)*.8-dip,0)+lift
		local tilt=math.rad(-B.diveTilt)*math.clamp((1-t)/B.level*B.land,0,1)
		bird.root=CFrame.new(at)*CFrame.Angles(0,bird.yaw,0)*CFrame.Angles(tilt,0,0)
		bird.wings,bird.flick,bird.phi,bird.tuck="fly",0,math.rad(phi),tuck
		return
	end
	if bird.state=="leave"then
		local t=now-bird.leaveAt
		local yaw=yawOf(bird.away)
		if t<B.crouchTime then
			bird.root=CFrame.new(bird.spot+lift-Vector3.new(0,B.crouch,0))*CFrame.Angles(0,bird.yaw,0)
			bird.wings,bird.flick,bird.phi,bird.tuck="perch",0,0,0
			return
		end
		local u=math.clamp((t-B.crouchTime)/B.leave,0,1)
		local phi,tuck,dip=Sim.birdBeat(t-B.crouchTime,level)
		local at=bird.spot+lift+bird.away*(B.away*u*u)+Vector3.new(0,bird.rise*(1-(1-u)^2)-dip,0)
		bird.root=CFrame.new(at)*CFrame.Angles(0,yaw,0)
		bird.wings,bird.flick,bird.phi,bird.tuck="fly",0,math.rad(phi),tuck
		return
	end
	-- Sitting: the landing squash, low hops (often a pair), turns that come with a hop, the head on its own.
	local y,pitch,flick=0,0,0
	local since=now-(bird.landedAt or -math.huge)
	if since<B.dipIn then
		local k=since/B.dipIn;y-=B.dip*k;pitch-=B.dipPitch*k
	elseif since<B.dipIn+B.dipOut then
		local k=1-(since-B.dipIn)/B.dipOut;y-=B.dip*k;pitch-=B.dipPitch*k
	end
	local busy=false
	for i=1,2 do
		local start=if i==1 then bird.hopAt else bird.hop2
		if start then
			local h=now-start
			if h>=0 and h<B.hopTime then local u=h/B.hopTime;y+=B.hop*4*u*(1-u);busy=true
			elseif h>=0 and h<B.hopTime+B.hopDipTime then y-=B.hopDip;busy=true
			elseif h<0 then busy=true end
			if h>=0 and h<B.flickTime then flick=1 end
		end
	end
	bird.tau=tailAt(bird,now)
	if not busy then bird.hopAt,bird.hop2=nil,nil end
	local yaw=bird.yaw
	if bird.turnStart and now-bird.turnStart<B.turnTime then
		yaw=bird.turnFrom+(bird.yaw-bird.turnFrom)*smooth((now-bird.turnStart)/B.turnTime)
	end
	local head=bird.head
	local k=smooth((now-head.at)/B.headTime)
	local hy,hr=head.fromYaw+(head.yaw-head.fromYaw)*k,head.fromRoll+(head.roll-head.fromRoll)*k
	bird.turn=CFrame.Angles(0,math.rad(hy),0)*CFrame.Angles(0,0,math.rad(hr))
	bird.root=CFrame.new(bird.spot+lift+Vector3.new(0,y,0))*CFrame.Angles(0,yaw,0)*CFrame.Angles(math.rad(pitch),0,0)
	bird.wings,bird.flick,bird.phi,bird.tuck="perch",flick,0,0
	-- Nothing moving this frame (no squash, hop, turn or head snap; the tail at rest): GardenLife skips the writes.
	bird.still=since>=B.dipIn+B.dipOut and not busy and bird.tau==B.tail and now-head.at>=B.headTime
		and not(bird.turnStart and now-bird.turnStart<B.turnTime)
end
-- The ten frames in pool order: body, head, beak, eye R, eye L, wing L, wing R, tail, leg R, leg L (FABLE-REVIEW-R3 3).
-- head: the head's own turn (CFrame) under H; phi: the flap (radians) in flight; tuck 0 to 1 lerps the flying wings
-- to the folded pose (the bound); flick 0 to 1 swings the folded tips out; tau: the tail's tilt in degrees. In flight the
-- legs are nil (GardenLife parks them: hidden) and the body flies level (pitch 10).
-- Shape, studs, root = the body's centre, -Z forward. GardenLife sizes its parts from this table.
Sim.BirdShape=table.freeze({
	body=Vector3.new(.50,.50,.74),pitch=35,flyPitch=10,           -- a Sphere-meshed block, upright says songbird
	head=.38,headAt=Vector3.new(0,.34,-.20),                       -- on top of the raised chest; head : body = 1 : 2
	beak=Vector3.new(.14,.12,.26),beakAt=Vector3.new(0,-.03,-.20), -- a spindle, half buried: .13 out, beak : head = 1 : 3
	eye=.09,eyeAt=Vector3.new(.125,.05,-.135),
	-- FABLE-REVIEW-R4 1: a shorter, narrower plate seated further back with less yaw and a 22 degree roll (top edge toward
	-- the spine), so from the front nothing wing-coloured sticks out past the body; the three-quarter file still shows.
	wing=Vector3.new(.03,.48,.22),foldAt=Vector3.new(.205,0,.17),foldYaw=8,fold=-55,foldRoll=22, -- along the 35 degree back
	shoulder=Vector3.new(.20,.12,-.06),
	tail=Vector3.new(.26,.10,.44),tailAt=Vector3.new(0,-.18,.30),tailSink=.08, -- a WedgePart; tail : body = 3 : 5
	leg=Vector3.new(.03,.16,.03),legAt=Vector3.new(.08,-.31,.02),  -- vertical in the world (the root is level)
})
function Sim.birdParts(root,wings,flick,phi,head,tau,tuck)
	local S=Sim.BirdShape
	local H=root*CFrame.new(S.headAt)*(head or CFrame.identity)
	local eye=S.eyeAt
	local flying=wings=="fly"
	local parts={root*CFrame.Angles(math.rad(if flying then S.flyPitch else S.pitch),0,0),H,H*CFrame.new(S.beakAt),
		H*CFrame.new(eye.X,eye.Y,eye.Z),H*CFrame.new(-eye.X,eye.Y,eye.Z)}
	local out=math.rad(Sim.Bird.flick)*(flick or 0)
	-- The folded wings lie along the pitched body, their tips across the tail root.
	local fold=CFrame.Angles(math.rad(S.fold),0,0)
	local at=S.foldAt
	local roll=math.rad(S.foldRoll or 0) -- about the plate's long axis, applied last
	local foldL=root*CFrame.new(-at.X,at.Y,at.Z)*CFrame.Angles(0,0,-out)*CFrame.Angles(0,math.rad(S.foldYaw),0)*fold*CFrame.Angles(0,roll,0)
	local foldR=root*CFrame.new(at.X,at.Y,at.Z)*CFrame.Angles(0,0,out)*CFrame.Angles(0,math.rad(-S.foldYaw),0)*fold*CFrame.Angles(0,-roll,0)
	if wings=="fly"then
		phi=phi or 0
		-- Half the wing out from the shoulder, so the root stays at the shoulder.
		local half,sh=S.wing.Y/2,S.shoulder
		local left=root*CFrame.new(-sh.X,sh.Y,sh.Z)*CFrame.Angles(0,0,-phi)*CFrame.new(-half,0,0)*CFrame.Angles(0,0,-math.pi/2)
		local right=root*CFrame.new(sh.X,sh.Y,sh.Z)*CFrame.Angles(0,0,phi)*CFrame.new(half,0,0)*CFrame.Angles(0,0,math.pi/2)
		tuck=math.clamp(tuck or 0,0,1)
		if tuck>0 then left,right=left:Lerp(foldL,tuck),right:Lerp(foldR,tuck)end
		parts[6],parts[7]=left,right
	else
		parts[6],parts[7]=foldL,foldR
	end
	-- The tail wedge turned over (Rx 180): its full-height face at the root, sunk into the rump, its thin edge at the tip
	-- and up, the flat face (the wedge's Bottom) on top in line with the back, the slope underneath.
	parts[8]=root*CFrame.new(S.tailAt)*CFrame.Angles(math.rad(tau or Sim.Bird.tail),0,0)*CFrame.new(0,0,S.tail.Z/2-S.tailSink)*CFrame.Angles(math.pi,0,0)
	if not flying then
		local leg=S.legAt
		parts[9],parts[10]=root*CFrame.new(leg.X,leg.Y,leg.Z),root*CFrame.new(-leg.X,leg.Y,leg.Z)
	end
	return parts
end

-- Dewdrops (WORLD-PASS-2026-11-22 item 3, looks only; FRUIT-LOOK) ----------------------------------------------
-- Hanging under the lime crowns, 2 or 3 a crown; one lets go in a strong gust (the same one on every client: the
-- gust number and Wind.hash decide), falls, bounces twice, rolls downwind, rests, fades and regrows. A pet within
-- reach of a resting one bats it once, in place (that client's view only). Nothing to collect, no remote. Angles in
-- degrees; a pose's rotation is ImageLabel.Rotation (clockwise on screen): the camera's right turns world travel
-- into screen spin.
Sim.Fruit=table.freeze({
	slots=3,fill=.8,angles=table.freeze({40,160,285}),out=.36,down=.80,hang=.64,pool=16,reach=90,
	swayMin=3,swayGust=12,swayHz=2.2,
	dropAt=.8,chance=.35,
	tug=20,letGo=.15,fall=.55,drift=1.2,turn=180,
	bounces=table.freeze({table.freeze({height=.9,time=.34,drift=.5}),table.freeze({height=.3,time=.2,drift=.2})}),
	squash=.06,squashW=1.15,squashH=.85,
	rollMin=1.6,rollMax=2.4,rollTurn=25,roll=.9,spin=150,
	rest=18,lift=.5,lean=12,rock=6,rockAt=.6,rockHz=1.1,
	fade=1.2,quick=.3,shrink=.7,
	regrow=45,grow=1.5,overshoot=1.12,
	below=14,near=6,find=3,kerb=2,
	bat=3,batUp=.7,batAway=1,batTime=.4,batBounce=.2,batBounceTime=.15,batTurn=360,poll=2,
})
local F=Sim.Fruit
function Sim.fruitKey(i,k)return i*8+k end

-- Crown i's filled slots: {k, key, stem} with the stem tip just inside the crown's lower skirt (FRUIT-LOOK 2).
function Sim.fruitStems(i,crown)
	local out={}
	if type(i)~="number"or type(crown)~="table"or typeof(crown.position)~="Vector3"or typeof(crown.size)~="Vector3"then return out end
	local size=crown.size
	local top=crown.position+Vector3.new(0,size.Y/2,0)
	local base=Wind.hash(i,12)*360
	for k=1,F.slots do
		if Wind.hash(i*8+k,11)<F.fill then
			local a=math.rad(F.angles[k]+base)
			table.insert(out,table.freeze({k=k,key=Sim.fruitKey(i,k),
				stem=top+Vector3.new(F.out*size.X*math.cos(a),-F.down*size.Y,F.out*size.X*math.sin(a))}))
		end
	end
	return out
end
-- The hanging pendulum, degrees toward Wind.Direction; 0 when still (Reduced Motion, budget level 1).
function Sim.fruitSway(k,now,wind,still)
	if still or type(now)~="number"then return 0 end
	wind=if type(wind)=="number"and wind==wind then math.clamp(wind,0,1)else 0
	return(F.swayMin+F.swayGust*wind)*math.sin(now*F.swayHz+k)
end
-- The image centre for a stem tip, swung `angle` degrees downwind, at `scale` (the stem tip stays put).
function Sim.fruitHang(stem,angle,scale)
	local a=math.rad(angle or 0)
	local r=F.hang*(scale or 1)
	return stem+Wind.Direction*(r*math.sin(a))-Vector3.new(0,r*math.cos(a),0)
end
-- The ground under a landing, or nil and why: no number, too far below the crown (water, off the island), or not
-- safe walkable ground (world.safe).
function Sim.fruitGround(x,z,crownY,world)
	local g=world and world.groundY and world.groundY(x,z)
	if type(g)~="number"or g~=g or math.abs(g)==math.huge then return nil,"ground"end
	if crownY-g>F.below then return nil,"low"end
	if world.safe and not world.safe(x,z)then return nil,"water"end
	return g
end
-- A resting point: clear of the stations and pad (Sim.clear), the Dash course whether or not a race is live, every
-- find spot and every park kerb grown by 2. Never the camera (shared: the same on every client; a drawn fruit near
-- the camera fades instead). false and the reason when not.
function Sim.fruitClear(position,world)
	world=world or {}
	local ok,why=Sim.clear(position,{stations=world.stations,pad=world.pad,course=world.course})
	if not ok then return false,why end
	for _,spot in ipairs(world.finds or {})do
		if flat(position,spot)<F.find then return false,"find"end
	end
	for _,kerb in ipairs(world.kerbs or {})do
		local dx,dz=(position.X-kerb.x)/(kerb.rx+F.kerb),(position.Z-kerb.z)/(kerb.rz+F.kerb)
		if dx*dx+dz*dz<=1 then return false,"kerb"end
	end
	return true
end

local function sign(v)return if v<0 then -1 else 1 end
local function screen(right,direction)
	return if typeof(right)=="Vector3"then right:Dot(direction)else 1
end
local HOLD=F.regrow+F.grow -- a slot that let go is not on the tree for this long
Sim.FruitHold=HOLD

-- When gust n lets fruit go at a crown: the gust's peak there must reach dropAt; the let-go is the first 1/60 s on
-- the way up that it does. World time (GetServerTimeNow), or nil. Wind only, so the same on every client.
function Sim.fruitTrigger(position,n)
	if typeof(position)~="Vector3"or type(n)~="number"or Wind.peak(n)<=0 then return nil end
	local start=Wind.start(n)+position:Dot(Wind.Direction)/Wind.Speed
	if Wind.at(position,start+Wind.Rise)<F.dropAt then return nil end
	for step=0,math.ceil(Wind.Rise*60)do
		local t=start+step/60
		if Wind.at(position,t)>=F.dropAt then return t end
	end
	return nil
end

-- The shared flight of slot `slot` of crown i in gust n, let go at `letgo`: positions and times only (no camera, no
-- player). nil and why when any landing has no good ground or the resting point is in the way.
function Sim.fruitPlan(i,crown,slot,n,letgo,world)
	world=world or {}
	local dir=Wind.Direction
	local seed=n*16+i
	local crownY=crown.position.Y
	local release=Sim.fruitHang(slot.stem,F.tug,1)
	local function land(at)
		local g,why=Sim.fruitGround(at.X,at.Z,crownY,world)
		if not g then return nil,why end
		return Vector3.new(at.X,g+F.lift,at.Z)
	end
	local p1,why=land(release+dir*F.drift)
	if not p1 then return nil,why end
	local p2;p2,why=land(p1+dir*F.bounces[1].drift)
	if not p2 then return nil,why end
	local p3;p3,why=land(p2+dir*F.bounces[2].drift)
	if not p3 then return nil,why end
	local turn=math.rad((Wind.hash(seed,16)*2-1)*F.rollTurn)
	local heading=Vector3.new(dir.X*math.cos(turn)+dir.Z*math.sin(turn),0,-dir.X*math.sin(turn)+dir.Z*math.cos(turn))
	local length=F.rollMin+(F.rollMax-F.rollMin)*Wind.hash(seed,15)
	local p4;p4,why=land(p3+heading*length)
	if not p4 then return nil,why end
	local ok;ok,why=Sim.fruitClear(p4,world)
	if not ok then return nil,why end
	local t1=letgo+F.letGo
	local t2=t1+F.fall
	local t3=t2+F.bounces[1].time
	local t4=t3+F.bounces[2].time
	local t5=t4+F.roll
	local t6=t5+F.rest
	return table.freeze({id=slot.key..":"..n,i=i,key=slot.key,k=slot.k,n=n,stem=slot.stem,crownY=crownY,start=letgo,
		sway=Sim.fruitSway(slot.k,letgo,Wind.at(crown.position,letgo),false),release=release,p1=p1,p2=p2,p3=p3,p4=p4,
		heading=heading,length=length,t1=t1,t2=t2,t3=t3,t4=t4,t5=t5,t6=t6,gone=t6+F.fade})
end
-- Gust n at crown i, before the slot rule: the seeded chance, the trigger, the seeded slot (of all its stems), the
-- flight. The plan, or nil and why ("empty", "chance", "calm", or a landing rule).
function Sim.fruitCandidate(i,crown,stems,n,world)
	if #stems==0 then return nil,"empty"end
	local seed=n*16+i
	if Wind.hash(seed,13)>=F.chance then return nil,"chance"end
	local letgo=Sim.fruitTrigger(crown.position,n)
	if not letgo then return nil,"calm"end
	return Sim.fruitPlan(i,crown,stems[math.floor(Wind.hash(seed,14)*#stems)+1],n,letgo,world)
end

-- One drawn fruit for a shared plan: the screen spin from the camera's right now (the roll turns about 150 a stud and
-- ends leaning 12 the way it went, the nearest such angle so nothing snaps at rest), plus its own bat and fade state.
function Sim.fruitLoose(plan,right)
	local loose=table.clone(plan)
	local dot=screen(right,Wind.Direction)
	local s,sr=sign(dot),sign(screen(right,plan.heading))
	local r0=-F.tug*dot
	local r3=r0+F.turn*s
	local lean=F.lean*sr
	loose.plan,loose.dot,loose.r0,loose.r3=plan,dot,r0,r3
	loose.r4=lean+360*math.floor((r3+sr*F.spin*plan.length-lean)/360+.5)
	loose.rest,loose.lands,loose.poll,loose.pose=plan.p4,{plan.t2,plan.t3,plan.t4},plan.t5,{}
	return loose
end

local function hop(a,b,height,u)
	u=math.clamp(u,0,1)
	return a:Lerp(b,u)+Vector3.new(0,height*4*u*(1-u),0)
end
-- Where a drawn fruit is now: {position, rotation, w, h (gui scale), transparency, phase}; phase is "tug", "fall",
-- "bounce", "roll", "rest", "bat", "fade" or "gone". Reuses loose.pose.
function Sim.fruitPose(plan,now)
	local pose=plan.pose
	local w,h,position,rotation,phase=1,1,nil,nil,nil
	if now<plan.t1 then
		local u=math.clamp((now-plan.start)/F.letGo,0,1)
		local angle=plan.sway+(F.tug-plan.sway)*u
		position,rotation,phase=Sim.fruitHang(plan.stem,angle,1),-angle*plan.dot,"tug"
	elseif now<plan.t2 then
		local u=(now-plan.t1)/F.fall
		local a,b=plan.release,plan.p1
		position=Vector3.new(a.X+(b.X-a.X)*u,a.Y+(b.Y-a.Y)*u*u,a.Z+(b.Z-a.Z)*u)
		rotation,phase=plan.r0+(plan.r3-plan.r0)*u,"fall"
	elseif now<plan.t3 then
		position,rotation,phase=hop(plan.p1,plan.p2,F.bounces[1].height,(now-plan.t2)/(plan.t3-plan.t2)),plan.r3,"bounce"
	elseif now<plan.t4 then
		position,rotation,phase=hop(plan.p2,plan.p3,F.bounces[2].height,(now-plan.t3)/(plan.t4-plan.t3)),plan.r3,"bounce"
	elseif now<plan.t5 then
		local e=1-(1-(now-plan.t4)/F.roll)^2
		position,rotation,phase=plan.p3:Lerp(plan.p4,e),plan.r3+(plan.r4-plan.r3)*e,"roll"
	else
		position,rotation,phase=plan.rest,plan.r4,"rest"
		local bat=plan.bat
		if bat and now<bat.done then
			local t=now-bat.start
			position=if t<F.batTime then hop(bat.from,bat.to,F.batUp,t/F.batTime)else hop(bat.to,bat.to,F.batBounce,(t-F.batTime)/F.batBounceTime)
			rotation,phase=plan.r4+bat.s*F.batTurn*smooth(t/(F.batTime+F.batBounceTime)),"bat"
		else
			local at=Wind.at(plan.rest,now)
			if at>F.rockAt then rotation+=F.rock*math.clamp((at-F.rockAt)/(1-F.rockAt)*2,0,1)*math.sin(now*math.pi*2*F.rockHz)end
		end
	end
	for _,landed in ipairs(plan.lands)do
		local d=now-landed
		if d>=0 and d<F.squash then w,h=F.squashW,F.squashH;break end
	end
	local fade=if now>=plan.t6 then(now-plan.t6)/F.fade else 0
	if plan.quick then fade=math.max(fade,(now-plan.quick)/F.quick)end
	local transparency=0
	if fade>0 then
		fade=math.min(fade,1)
		local k=1-(1-F.shrink)*fade
		w*=k;h*=k;transparency=fade
		phase=if fade>=1 then "gone"else "fade"
	end
	pose.position,pose.rotation,pose.w,pose.h,pose.transparency,pose.phase=position,rotation,w,h,transparency,phase
	return pose
end

-- A resting drawn fruit batted by a pet at `pet` (this client's view only): a hop 1 stud straight away (straight up
-- when that spot fails the landing rules), one small bounce, a full turn. Once in its life. True when it hops.
function Sim.fruitBat(plan,pet,now,world,right)
	if plan.bat or plan.quick or now<plan.t5 or now>=plan.t6 or typeof(pet)~="Vector3"then return false end
	local from=plan.rest
	local away=Vector3.new(from.X-pet.X,0,from.Z-pet.Z)
	away=if away.Magnitude>1e-3 then away.Unit else Wind.Direction
	local to=from
	local spot=from+away*F.batAway
	local g=Sim.fruitGround(spot.X,spot.Z,plan.crownY,world)
	if g then
		local landing=Vector3.new(spot.X,g+F.lift,spot.Z)
		if Sim.fruitClear(landing,world)then to=landing end
	end
	local done=now+F.batTime+F.batBounceTime
	plan.bat={start=now,from=from,to=to,s=sign(screen(right,if to==from then away else to-from)),done=done,straight=to==from}
	plan.rest=to
	table.insert(plan.lands,now+F.batTime);table.insert(plan.lands,done)
	plan.t6=math.max(plan.t6,done)
	return true
end

-- The grove: which fruit fall, a pure function of the server time (every lime crown, every client, whatever it can
-- see, its budget or Reduced Motion). A candidate (Sim.fruitCandidate) falls unless the same slot had a candidate in
-- the HOLD seconds before it; a slot is empty for HOLD after it falls, regrowing over the last F.grow. Candidates are
-- cached (they are pure); drawing decides only what to show.
local Grove={};Grove.__index=Grove
Sim.Grove=Grove
Grove.Ahead=2   -- refresh looks this far ahead
Grove.Every=1   -- seconds between refreshes (GardenLife)
-- world: shared data only (groundY, safe, stations, pad, course, finds, kerbs); never a camera.
function Grove.new(crowns,world)
	local self=setmetatable({crowns=crowns or {},world=world or {},stems={},cands={},drops={},at=nil},Grove)
	for i,crown in ipairs(self.crowns)do self.stems[i]=Sim.fruitStems(i,crown);self.cands[i]={};self.drops[i]={}end
	return self
end
-- Gust numbers whose let-go can fall within [a, b] at this place.
local function gustRange(position,a,b)
	local offset=position:Dot(Wind.Direction)/Wind.Speed
	return math.floor((a-offset-Wind.Rise-Wind.Jitter)/Wind.Slot),math.ceil((b-offset+Wind.Jitter)/Wind.Slot)
end
function Grove:candidate(i,n)
	local cands=self.cands[i]
	local c=cands[n]
	if c==nil then
		c=Sim.fruitCandidate(i,self.crowns[i],self.stems[i],n,self.world)or false
		cands[n]=c
	end
	return c or nil
end
-- Crown i's drops let go within [a, b], oldest first.
function Grove:dropsAt(i,a,b)
	local lo,hi=gustRange(self.crowns[i].position,a-HOLD,b)
	local out,last={},{}
	for n=lo,hi do
		local c=self:candidate(i,n)
		if c then
			local before=last[c.key]
			last[c.key]=c.start
			if c.start>=a and c.start<=b and not(before and c.start-before<HOLD)then table.insert(out,c)end
		end
	end
	return out
end
-- Every crown's drops from now - HOLD to now + Ahead; candidates too old to matter are forgotten.
function Grove:refresh(now)
	for i,crown in ipairs(self.crowns)do
		self.drops[i]=self:dropsAt(i,now-HOLD,now+Grove.Ahead)
		local lo=gustRange(crown.position,now-2*HOLD-Wind.Slot,now)
		for n in pairs(self.cands[i])do if n<lo then self.cands[i][n]=nil end end
	end
	self.at=now
end
-- A slot's hanging scale now: 1, 0 to 1.12 to 1 while it regrows, nil while it is empty (needs a refresh within
-- Ahead seconds).
function Grove:hanging(key,now)
	for _,drop in ipairs(self.drops[key//8]or {})do
		if drop.key==key and drop.start<=now then
			local t=now-drop.start-F.regrow
			if t<0 then return nil end
			if t<F.grow then
				local u=t/F.grow
				return if u<.7 then F.overshoot*smooth(u/.7)else F.overshoot-(F.overshoot-1)*smooth((u-.7)/.3)
			end
		end
	end
	return 1
end
-- The drops off the tree now (let go, not yet faded), oldest first.
function Grove:active(now)
	local out={}
	for i=1,#self.crowns do
		for _,drop in ipairs(self.drops[i])do
			if drop.start<=now and now<drop.gone then table.insert(out,drop)end
		end
	end
	table.sort(out,function(a,b)return a.start<b.start end)
	return out
end

-- What this client draws of the grove's loose fruit: at most `cap`, only within Sim.Drop of the camera, none while a
-- race is live; a quick fade closer than F.near to the camera; a pet's bat. Drawing never changes what falls.
local Loose={};Loose.__index=Loose
Sim.Loose=Loose
function Loose.new()return setmetatable({list={},seen={}},Loose)end
function Loose:clear()table.clear(self.list);table.clear(self.seen)end
-- active: Grove:active(now). view: {camera = Vector3, right = Vector3}. world: the grove's shared world (bat
-- landings). pets: {Vector3} or a function returning them, called at most once a step and only when a poll is due.
function Loose:step(now,active,view,world,pets,cap,live)
	local list,seen=self.list,self.seen
	local camera=view and view.camera
	local keep={}
	for _,plan in ipairs(active)do keep[plan.id]=true end
	for id in pairs(seen)do if not keep[id]then seen[id]=nil end end
	for index=#list,1,-1 do
		local loose=list[index]
		local position=Sim.fruitPose(loose,now).position
		if not keep[loose.id]or loose.pose.phase=="gone"then
			table.remove(list,index)
			if keep[loose.id]then seen[loose.id]=false end -- faded early: never drawn again
		elseif index>(cap or 0)or(camera and(position-camera).Magnitude>Sim.Drop)then
			table.remove(list,index);seen[loose.id]=nil
		end
	end
	for _,plan in ipairs(active)do
		if #list>=(cap or 0)then break end
		if seen[plan.id]==nil then
			if live then seen[plan.id]=false
			elseif not camera or(plan.p4-camera).Magnitude<=Sim.Drop then
				local loose=Sim.fruitLoose(plan,view and view.right)
				seen[plan.id]=loose
				table.insert(list,loose)
			end
		end
	end
	local pool=if type(pets)=="table"then pets else nil
	for _,loose in ipairs(list)do
		local position=Sim.fruitPose(loose,now).position
		if not loose.quick and(live or(camera and(position-camera).Magnitude<F.near))then loose.quick=now end
		if not loose.bat and not loose.quick and now>=loose.poll and now<loose.t6 and pets then
			loose.poll=now+F.poll
			if not pool then
				local ok,got=pcall(pets)
				pool=if ok and type(got)=="table"then got else {}
			end
			local best,nearest=F.bat,nil
			for _,pet in ipairs(pool)do
				if typeof(pet)=="Vector3"then
					local d=flat(loose.rest,pet)
					if d<=best then best,nearest=d,pet end
				end
			end
			if nearest then Sim.fruitBat(loose,nearest,now,world,view and view.right)end
		end
	end
	return list
end

return table.freeze(Sim)
