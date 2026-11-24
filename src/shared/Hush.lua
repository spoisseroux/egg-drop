-- The Hush greybox (artifacts/qa-2026-11-23-beta14/HUSH-GREYBOX-BUILD-PLAN.md; look: GARDEN-EXPANSION-LOOK.md). A second
-- garden behind the north ridge, reached through the cave: the Underway (the pocket behind the old CaveBlocker, with
-- three throats) and the Hush (a sunken hollow, floor y -20). Shared and pure, the IslandBounds pattern:
-- FeatureFlags.Hush is the build ceiling and opens only on the beta place or in Studio; the server's switch (HushConfig,
-- ConfigService `garden_hush`: off until the config has loaded once, then missing or malformed = on) reaches clients as
-- the workspace attribute `Hush_on`. Off is the game before this build: the cave blocked, nothing built.
--
-- Space. Hush-local (u east = +X, v north = -Z, h up from the Hush floor) from one origin, the tunnel mouth on the
-- Sill: world x = OriginX + u, y = FloorY + h, z = MouthZ - v. Moving the Hush is one of these three numbers.
-- Boxes are {min, max} Vector3s. The server's pet floor checks and the island bounds read Regions / PetFloors only
-- while HushHost is open (its own flag, never an attribute read on the hot path).
local RunService=game:GetService("RunService")
local Flags=require(script.Parent.FeatureFlags)
local Hush={}
Hush.PlaceId=107705084891479 -- Pocket Pals Beta
Hush.Attribute="Hush_on"
Hush.Key="garden_hush"
Hush.Model="Hush"           -- EggDropLounge.Hush, the built greybox
Hush.Remote="HushPassage"   -- ReplicatedStorage.Remotes: client {kind="go", door, seq}; server out/arrived/refused/evacuated
Hush.Blocker="CaveBlocker"  -- EggDropLounge.CaveBlocker (LoungeWorldV7Art)
Hush.Grade="HushGrade"      -- Lighting.HushGrade, the client's own ColorCorrectionEffect while in the Hush
Hush.Duck="hush"            -- BoardAudio duck name: the world music is out while in the Hush

-- Timings (seconds) and limits.
Hush.FadeOut=.35       -- the client's fade to black; the server moves this long after the request arrives
Hush.FadeIn=.5
Hush.GroundWait=2      -- the client holds black at most this long for the far side to be under its feet
Hush.Cooldown=1.5      -- between two passages of one player
Hush.Slack=3           -- studs the server's view of the root may sit outside a trigger box
Hush.Rate=4            -- packets a second per player; more are dropped
Hush.StreamWait=2      -- RequestStreamAroundAsync timeout when streaming is on
-- No answer in this long: the client fades back in. Covers the server's stream wait and fade, plus 1.5 s of round trip.
Hush.ClientTimeout=Hush.StreamWait+Hush.FadeOut+1.5
Hush.MaxErrors=3       -- errors before the host gives up (evacuates, closes, restores the blocker)
Hush.Tick=.1           -- the host's step
Hush.EffectsEvery=.5   -- the client's region pass (grade, the duck refreshed for DuckFor seconds)
Hush.DuckFor=2
Hush.Near=12           -- studs: the client counts itself arrived within this of the arrival point

Hush.OriginX=-7
Hush.FloorY=-20
Hush.MouthZ=-226
function Hush.at(u,v,h)return Vector3.new(Hush.OriginX+u,Hush.FloorY+(h or 0),Hush.MouthZ-v)end
-- Fable R5: the Sill (and the tunnel floor) stand SillH over the floor so you look down into the hollow; the ramp runs
-- from the Sill's east edge (u 8) down to the floor at u RampFootU (about 43 long, about 13 degrees).
Hush.SillH=10
Hush.RampFootU=51
-- Fable R5: clumps 18 to 24 wide and 14 high so the floor reads as rooms that hide each other. Hush-local footprints
-- {name, u1, v1, u2, v2}; HushGreybox builds them and safeCell keeps landings off them.
Hush.ClumpHeight=14
Hush.Clumps=table.freeze({
	table.freeze({name="ClumpScreen",u1=-27,v1=40,u2=-21,v2=62}),      -- hides the west (Crunch) room from the walk
	table.freeze({name="ClumpShrub",u1=-12,v1=97,u2=12,v2=103}),       -- north of the pool, hides the Quiet Shelf
	table.freeze({name="ClumpEast",u1=38,v1=60,u2=44,v2=80}),          -- hides the Moss Beds pocket
	table.freeze({name="ClumpNorthWest",u1=-58,v1=82,u2=-36,v2=88}),
	table.freeze({name="ClumpNorthEast",u1=48,v1=104,u2=68,v2=110}),
})
local function box(minimum,maximum)
	return table.freeze({min=Vector3.new(math.min(minimum.X,maximum.X),math.min(minimum.Y,maximum.Y),math.min(minimum.Z,maximum.Z)),
		max=Vector3.new(math.max(minimum.X,maximum.X),math.max(minimum.Y,maximum.Y),math.max(minimum.Z,maximum.Z))})
end
local function centred(centre,size)return box(centre-size/2,centre+size/2)end
Hush.box,Hush.centred=box,centred
-- Pure: is p inside b, grown by slack studs on every side?
function Hush.inBox(b,p,slack)
	if typeof(p)~="Vector3"then return false end
	slack=slack or 0
	return p.X>=b.min.X-slack and p.X<=b.max.X+slack and p.Y>=b.min.Y-slack and p.Y<=b.max.Y+slack
		and p.Z>=b.min.Z-slack and p.Z<=b.max.Z+slack
end

-- Regions. `hush`: the hollow, its tunnel and the Quiet Shelf. `underway`: the pocket behind the blocker line (z -99.5),
-- for evacuation and the client. FallY: below it a root in that region has fallen (12 under the Hush floor).
Hush.FallY=Hush.FloorY-12
Hush.Hollow=box(Vector3.new(-86,Hush.FloorY-20,-366),Vector3.new(72,Hush.FloorY+80,-200))
Hush.Pocket=box(Vector3.new(-14,0,-116),Vector3.new(0,26,-99))
-- Pure: "hush", "underway" or nil.
function Hush.regionAt(p)
	if Hush.inBox(Hush.Hollow,p)then return "hush"end
	if Hush.inBox(Hush.Pocket,p)then return "underway"end
	return nil
end
-- Safe ground in the Hush (IslandBounds samples, catch-up landings): the floor inside the walls less 2 studs, and the
-- tunnel and Sill strip. In plan only; the callers check height.
Hush.Safe=table.freeze({
	box(Hush.at(-73,2,-1),Hush.at(73,122,1)),
	box(Hush.at(-2,-23,5),Hush.at(2,0,7)),
})
function Hush.safeCell(x,z)
	if type(x)~="number"or type(z)~="number"or x~=x or z~=z then return false end
	local u,v=x-Hush.OriginX,Hush.MouthZ-z
	for _,c in ipairs(Hush.Clumps)do
		if u>=c.u1-1.5 and u<=c.u2+1.5 and v>=c.v1-1.5 and v<=c.v2+1.5 then return false end
	end
	for _,b in ipairs(Hush.Safe)do
		if x>=b.min.X and x<=b.max.X and z>=b.min.Z and z<=b.max.Z then return true end
	end
	return false
end
-- For IslandBounds (gone, region safe samples): only the hollow; the pocket is inside the island's ring.
Hush.BoundsRegions=table.freeze({table.freeze({name="hush",min=Hush.Hollow.min,max=Hush.Hollow.max,fallY=Hush.FallY,safe=Hush.safeCell})})

-- Pet floors (spec G0, architect 2026-11-23): the Hush interior, its tunnel and the Quiet Shelf. No Underway floor: an
-- owner in the pocket leaves the pet at its last ground anchor by the mouth, as today.
Hush.PetFloors=table.freeze({
	box(Hush.at(-73,1,-10),Hush.at(73,122,20)),
	box(Hush.at(-2.5,-23,-10),Hush.at(2.5,0,20)),
	box(Hush.at(-5,124,-10),Hush.at(15,137,20)),
})
-- Pure: the server's pet floor test. `floor` is EggDropLounge.Floor; inside it less a stud is today's test, exactly
-- (petAnchor, validWander, validFocus). `open` is HushHost's open flag: only `true` adds the Hush pet floors.
function Hush.onPetFloor(floor,position,open)
	local at=floor.CFrame:PointToObjectSpace(position)
	if not(math.abs(at.X)>floor.Size.X*.5-1 or math.abs(at.Z)>floor.Size.Z*.5-1)then return true end
	if open~=true then return false end
	for _,b in ipairs(Hush.PetFloors)do if Hush.inBox(b,position)then return true end end
	return false
end

-- Doors. trigger: walk into it to ask for the passage. arrival: feet frame, facing the way you were walking (the
-- default camera keeps its yaw, so it already looks the right way). landing: the pet's spot (the ground ray finds y).
-- Two players arriving together take the next ArrivalOffsets entry (door-local: x right, -z ahead).
local function facing(at,toward)return CFrame.lookAt(at,Vector3.new(toward.X,at.Y,toward.Z))end
Hush.Doors=table.freeze({
	north=table.freeze({id="north",from="underway",to="hush",
		trigger=centred(Vector3.new(-7,8,-113.75),Vector3.new(6,8,2.5)),
		arrival=facing(Hush.at(0,-17,Hush.SillH),Hush.at(0,0,Hush.SillH)),
		landing=Hush.at(0,-12,Hush.SillH+.025)}),
	home=table.freeze({id="home",from="hush",to="underway",
		trigger=centred(Hush.at(0,-22.5,Hush.SillH+4),Vector3.new(6,8,3)),
		arrival=facing(Vector3.new(-7,4,-108),Vector3.new(-7,4,-100)),
		-- Inside the home Floor (it ends at z -90): home pet code only ever sees home positions.
		landing=Vector3.new(-7,4.625,-88)}),
})
-- Switch off with people inside: out onto the lawn in front of the mouth, inside the home Floor.
Hush.Evacuation=table.freeze({arrival=facing(Vector3.new(-7,4.6,-86),Vector3.new(-7,4.6,-70)),landing=Vector3.new(-7,4.625,-82)})
Hush.ArrivalOffsets=table.freeze({Vector3.zero,Vector3.new(-1.6,0,0),Vector3.new(1.6,0,0),Vector3.new(-.8,0,-2.2),Vector3.new(.8,0,-2.2)})

local injected=nil
-- Specs pass env = {flags, place, studio, on}; the game passes nothing.
function Hush.ceiling(env)
	env=env or injected or {}
	if(env.flags or Flags).Hush~=true then return false end
	local studio=env.studio
	if studio==nil then studio=RunService:IsStudio()end
	return(env.place or game.PlaceId)==Hush.PlaceId or studio==true
end
-- Pure: a switch value. Anything but a boolean (missing, malformed) is the shipped default, on.
function Hush.resolve(configValue,override,ceiling)
	if ceiling==nil then ceiling=Hush.ceiling()end
	if not ceiling then return false end
	if type(override)=="boolean"then return override end
	if type(configValue)=="boolean"then return configValue end
	return true
end
-- Server only (HushConfig): the resolved value HushHost reads. Off until it is set.
local switch=false
function Hush.setSwitch(value)
	if not RunService:IsServer()then return false end
	switch=value==true
	return true
end
function Hush.on()
	if injected then return injected.on~=false and Hush.ceiling(injected)end
	if not Hush.ceiling()then return false end
	if RunService:IsServer()and not switch then return false end
	return workspace:GetAttribute(Hush.Attribute)==true
end
-- Spec seam, refused outside Studio.
function Hush.inject(env)
	if not RunService:IsStudio()then return false end
	injected=if type(env)=="table"then table.clone(env)else nil
	return true
end
return table.freeze(Hush)
