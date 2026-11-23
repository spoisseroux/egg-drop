-- Pets catch up (beta (12) QA G1, QUICK-FIX-PLAN): a pet too far from its owner, or stuck, hops to a safe cell by the
-- owner with a poof. The IslandBounds pattern: FeatureFlags.PetCatchup is the build ceiling, open only on the beta place
-- or in Studio, while the runtime switch is on (ConfigService key `pet_catchup`, server CatchupConfig: off until the
-- config has loaded once, then missing or malformed = on). Only the server reads it (GardenState through init); clients
-- only see the snapshot's `hop` counter. Off is the game before this build.
--
-- Pure rules here (GardenState keeps one `catch` table per actor and asks step / done):
--   far    the pet's flat distance to the owner's ground anchor (input.anchor) over Far for FarHold seconds
--   stuck  over StuckNear from the anchor and the pet itself has not moved StuckGain studs in StuckSeconds, whatever it
--          is doing (a far follow that stops short, or a sit or pause where it got stuck); never in a greeting
--   rate   Cooldown after a hop, Retry after a search that found no landing; Burst hops in BurstWindow -> BurstQuiet
-- Landing: rings round input.anchor (candidates), each checked by the server for walkable ground and by clear() here.
-- Every number is a field so Studio tuning is a one-line change.
local RunService=game:GetService("RunService")
local Flags=require(script.Parent.FeatureFlags)
local Bounds=require(script.Parent.IslandBounds)
local Course=require(script.Parent.DashCourse)
local Catchup={}
Catchup.PlaceId=107705084891479 -- Pocket Pals Beta
Catchup.Attribute="Catchup_on"
Catchup.Key="pet_catchup"
Catchup.Far=40          -- studs, flat, pet to input.anchor
Catchup.FarHold=1.5     -- seconds over Far before a hop
Catchup.StuckNear=8     -- studs: closer than this is never stuck
Catchup.StuckSeconds=4  -- seconds without StuckGain of movement while following
Catchup.StuckGain=1     -- studs the pet must move to count as progress
Catchup.Cooldown=8      -- seconds between hops, per pet
Catchup.Retry=2         -- seconds after a search that found no landing
Catchup.Burst=4         -- hops in BurstWindow that trip the loop guard
Catchup.BurstWindow=60
Catchup.BurstQuiet=60   -- seconds with no hops after the guard trips
Catchup.Gap=1.5         -- seconds between two decides that reset the tracking (a switch flip, a stall)
Catchup.Rest=.6         -- the landed pet rests this long, then follows
Catchup.Rings=table.freeze({0,2.5,4})
Catchup.Bearings=8
Catchup.Rise=3          -- a landing more than this above or below the anchor is refused (a ledge, a hole)
Catchup.WallKeep=3      -- studs from every IslandBounds wall
Catchup.CourseKeep=4    -- studs from the Dash course line, only while a race is live
Catchup.PadKeep=2       -- studs past the Dash waiting pad's edge, only while a race is live

local injected=nil
-- Specs pass env = {flags, place, studio, on}; the game passes nothing.
function Catchup.ceiling(env)
	env=env or injected or {}
	if(env.flags or Flags).PetCatchup~=true then return false end
	local studio=env.studio
	if studio==nil then studio=RunService:IsStudio()end
	return(env.place or game.PlaceId)==Catchup.PlaceId or studio==true
end
-- Pure: a switch value. Anything but a boolean (missing, malformed) is the shipped default, on.
function Catchup.resolve(configValue,override,ceiling)
	if ceiling==nil then ceiling=Catchup.ceiling()end
	if not ceiling then return false end
	if type(override)=="boolean"then return override end
	if type(configValue)=="boolean"then return configValue end
	return true
end
-- Server only (CatchupConfig): the resolved value GardenState reads. Off until it is set.
local switch=false
function Catchup.setSwitch(value)
	if not RunService:IsServer()then return false end
	switch=value==true
	return true
end
function Catchup.on()
	if injected then return injected.on~=false and Catchup.ceiling(injected)end
	if not Catchup.ceiling()then return false end
	return switch
end
-- Spec seam, refused outside Studio.
function Catchup.inject(env)
	if not RunService:IsStudio()then return false end
	injected=if type(env)=="table"then table.clone(env)else nil
	return true
end

local function flat(a,b)return math.sqrt((a.X-b.X)^2+(a.Z-b.Z)^2)end
Catchup.flat=flat

-- Pure: one decide's look at a pet. `t` is the actor's own table (kept between calls), `gap` the flat studs to the
-- anchor, `at` the pet's position, `following` false in a greeting (no stuck clock). Returns "far", "stuck" or nil.
function Catchup.step(t,now,gap,at,following)
	if t.seenAt==nil or now-t.seenAt>Catchup.Gap then t.farSince,t.still,t.stillAt=nil,nil,nil end
	t.seenAt=now
	if gap>Catchup.Far then t.farSince=t.farSince or now else t.farSince=nil end
	if following and gap>Catchup.StuckNear and typeof(at)=="Vector3"then
		if t.still==nil or flat(at,t.still)>=Catchup.StuckGain then t.still,t.stillAt=at,now end
	else t.still,t.stillAt=nil,nil end
	if now<(t.nextAt or -math.huge)or now<(t.quietUntil or -math.huge)then return nil end
	if t.farSince and now-t.farSince>=Catchup.FarHold then return "far"end
	if t.stillAt and now-t.stillAt>=Catchup.StuckSeconds then return "stuck"end
	return nil
end
-- Pure: after an attempt. A hop starts the cooldown and counts toward the loop guard ("burst" when it trips);
-- no landing waits Retry.
function Catchup.done(t,now,hopped)
	if not hopped then t.nextAt=now+Catchup.Retry;return nil end
	t.nextAt=now+Catchup.Cooldown
	t.farSince,t.still,t.stillAt=nil,nil,nil
	local recent={}
	for _,at in ipairs(t.hops or {})do if now-at<Catchup.BurstWindow then table.insert(recent,at)end end
	table.insert(recent,now)
	t.hops=recent
	if #recent>=Catchup.Burst then
		t.quietUntil,t.hops=now+Catchup.BurstQuiet,{}
		return "burst"
	end
	return nil
end

-- Pure: landing candidates round the anchor, nearest ring first; on each ring the bearing behind the owner first
-- (`facing`, the owner's look on the ground plane, may be nil), then alternately either side of it.
function Catchup.candidates(anchor,facing)
	local out={}
	local base=0
	if typeof(facing)=="Vector3"and(facing.X~=0 or facing.Z~=0)then base=math.atan2(-facing.X,-facing.Z)end
	for _,radius in ipairs(Catchup.Rings)do
		if radius==0 then table.insert(out,anchor);continue end
		local n=Catchup.Bearings
		for k=0,n-1 do
			local step=math.ceil(k/2)*(if k%2==1 then 1 else -1)
			local angle=base+step*2*math.pi/n
			table.insert(out,anchor+Vector3.new(math.sin(angle)*radius,0,math.cos(angle)*radius))
		end
	end
	return out
end

-- The Dash course as a flat x, z polyline in studs (DashCourse's d, x, y, z lists in hundredths), built once.
local line={}
for _,list in ipairs({Course.Main,Course.Branch})do
	local part={}
	for i=1,#list//4 do table.insert(part,list[i*4-2]/100);table.insert(part,list[i*4]/100)end
	table.insert(line,part)
end
local function lineDistance(x,z,points)
	local best=math.huge
	for i=1,#points//2-1 do
		local ax,az,bx,bz=points[i*2-1],points[i*2],points[i*2+1],points[i*2+2]
		local dx,dz=bx-ax,bz-az
		local length=dx*dx+dz*dz
		local t=if length>0 then math.clamp(((x-ax)*dx+(z-az)*dz)/length,0,1)else 0
		best=math.min(best,math.sqrt((x-ax-dx*t)^2+(z-az-dz*t)^2))
	end
	return best
end
function Catchup.courseDistance(x,z)
	local best=math.huge
	for _,points in ipairs(line)do best=math.min(best,lineDistance(x,z,points))end
	return best
end
-- Pure: is (x, z) clear for a landing? Safe walk-map ground (IslandGround), WallKeep from every island wall, and while
-- a race is live clear of the course and the waiting pad. false and the reason when not.
function Catchup.clear(x,z,racing)
	if type(x)~="number"or type(z)~="number"or x~=x or z~=z then return false,"spot"end
	if not Bounds.safeCell(x,z)then return false,"ground"end
	for _,wall in ipairs(Bounds.Walls)do
		if Bounds.distance(wall,x,z)<Catchup.WallKeep then return false,"wall"end
	end
	if racing then
		if Catchup.courseDistance(x,z)<Catchup.CourseKeep then return false,"course"end
		local pad=Course.Pad
		if math.sqrt((x-pad.x/100)^2+(z-pad.z/100)^2)<pad.r/100+Catchup.PadKeep then return false,"pad"end
	end
	return true
end

return table.freeze(Catchup)
