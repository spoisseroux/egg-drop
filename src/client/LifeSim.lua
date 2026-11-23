-- Garden life, the maths (ALIVE-LIFE-BUILD-PLAN-2026-11-22; look numbers artifacts/alive-life-2026-11-22/LOOK-R2.md, then LOOK.md).
-- Pure: no instances, no clock, no services. GardenLife owns the parts and the one stepper and asks this what to show.
-- Everything random comes from a Random seeded by the caller, so the same seed and the same calls give the same
-- garden. Positions are Vector3, poses are CFrame; forward is -Z, up is +Y.
--   petals       Petals:step(now, dt, winds, cap) -> how many to Emit at each emitter now
--   bubbles      Bubbles:due(now, cap, allowed), Sim.bubbleSpot(camera, random, world), Bubbles:emit(now) -> "small" | "large"
--   butterflies  Butterflies:step(now, dt, world, patches, cap, still) -> the live ones
--   birds        Birds:chirp(now, perch, landing, cap, world, reduced), Birds:step(now, dt, world, reduced)
--   dewdrops     Sim.fruitStems(i, crown), Orchard:gust / :drop / :step, Sim.fruitPose(plan, now) (world pass item 3;
--                look numbers artifacts/world-pass-2026-11-22/FRUIT-LOOK.md). Seeded from Wind.hash and the gust
--                number, never a Random, so every client sees the same fruit fall.
-- `world` is {camera = Vector3?, player = Vector3?, stations = {Vector3}, pad = {x, z, r}?, course = {x, z, ...}?
-- (only while a race is live; fruit passes it always), groundY = fn?, finds = {Vector3}?, kerbs = {{x, z, rx, rz}}?,
-- safe = fn(x, z)?, right = Vector3?}.
local Wind=require(script.Parent.Wind)
local Sim={}

-- Caps by AliveBudget level 0, 1, 2 (level 1 halves every cap; level 2 shows nothing). fruit: hanging Dewdrops shown,
-- loose: Dewdrops off the tree at once (FRUIT-LOOK 4).
Sim.Caps=table.freeze({
	petals=table.freeze({40,20,0}),bubbles=table.freeze({8,4,0}),butterflies=table.freeze({4,2,0}),
	birds=table.freeze({3,2,0}),emitters=table.freeze({3,3,0}),fruit=table.freeze({16,8,0}),loose=table.freeze({3,2,0}),
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

-- Petals (brief B4; LOOK-R2 3) ---------------------------------------------------------------------------------
-- A second, at each emitter: none in the breeze (Wind.at's breeze is at most .25), 7 at a full gust.
Sim.PetalPeak=7
Sim.PetalCalm=.25
Sim.PetalLife=6.5 -- the longest a petal lives (LOOK-R2: 5 to 6.5 s), so the live count never undercounts
-- A gust burst: PetalBurst at once when an emitter's wind first passes BurstAt; again only after it fell below Rearm.
Sim.PetalBurst=6
Sim.PetalBurstAt=.6
Sim.PetalRearm=.3
function Sim.petalRate(at)
	if type(at)~="number"or at~=at then return 0 end
	return Sim.PetalPeak*math.clamp((at-Sim.PetalCalm)/(1-Sim.PetalCalm),0,1)
end
local Petals={};Petals.__index=Petals
Sim.Petals=Petals
function Petals.new()return setmetatable({live={},carry={},spent={}},Petals)end
function Petals:count(now)
	local live=self.live
	for i=#live,1,-1 do if live[i]<=now then table.remove(live,i)end end
	return #live
end
-- winds[i]: Wind.at at emitter i, or false where there is no emitter. Returns {n1, n2, ...}: how many to Emit now.
-- At the cap the fraction carries but nothing piles up, so a lull never ends in a burst. The gust burst comes out of
-- the same room (a burst the cap cut short is spent, not saved); an emitter with no crown re-arms.
function Petals:step(now,dt,winds,cap)
	local room=math.max(0,(cap or 0)-self:count(now))
	local out={}
	dt=if type(dt)=="number"and dt==dt then math.clamp(dt,0,.25)else 0
	for i,at in ipairs(winds)do
		local n=0
		if at then
			local carry=(self.carry[i]or 0)+Sim.petalRate(at)*dt
			local want=math.floor(carry)
			carry-=want
			self.carry[i]=carry
			if type(at)=="number"then
				if not self.spent[i]and at>=Sim.PetalBurstAt then self.spent[i]=true;want+=Sim.PetalBurst
				elseif self.spent[i]and at<Sim.PetalRearm then self.spent[i]=nil end
			end
			n=math.min(want,room)
			room-=n
			for _=1,n do table.insert(self.live,now+Sim.PetalLife)end
		else
			self.carry[i]=0
			self.spent[i]=nil
		end
		out[i]=n
	end
	return out
end
function Petals:clear()table.clear(self.live);table.clear(self.carry);table.clear(self.spent)end

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

-- Butterflies (brief C3; LOOK 2) -------------------------------------------------------------------------------
Sim.Butterfly=table.freeze({reach=60,wander=3,speed=.8,restMin=2,restMax=4,low=1.2,high=2.4,perch=.35,
	bob=.25,bobHz=1.3,wobble=20,wobbleHz=.8,pitch=10,restChance=.35,spawnGap=.5})
local Butterflies={};Butterflies.__index=Butterflies
Sim.Butterflies=Butterflies
function Butterflies.new(seed)return setmetatable({random=Random.new(seed or 2),list={},spawnAt=0},Butterflies)end
function Butterflies:clear()table.clear(self.list);self.spawnAt=0 end
local function wanderPoint(r,patch,radius,low,high)
	local a,d=r:NextNumber()*math.pi*2,math.sqrt(r:NextNumber())*radius
	return Vector3.new(patch.X+math.cos(a)*d,patch.Y+r:NextNumber(low,high),patch.Z+math.sin(a)*d)
end
-- patches: {Vector3} (flower patch middles on the ground). Spawns at most one every spawnGap seconds, on a patch
-- within reach of the camera that is clear (Sim.clear), one of each wing colour (1 to 4). Drops the far ones and
-- any over the cap at once. still = Reduced Motion: none.
function Butterflies:step(now,dt,world,patches,cap,still)
	local B,r,list=Sim.Butterfly,self.random,self.list
	local camera=world and world.camera
	if still or not camera then table.clear(list);return list end
	for i=#list,1,-1 do
		if i>cap or(list[i].position-camera).Magnitude>Sim.Drop then table.remove(list,i)end
	end
	if #list<cap and now>=self.spawnAt and patches then
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
			local patch=near[r:NextInteger(1,#near)]
			local start=wanderPoint(r,patch,B.wander,B.low,B.high)
			if Sim.clear(start,world)then
				local taken={}
				for _,b in ipairs(list)do taken[b.colour]=true end
				local colour=1
				while taken[colour]do colour+=1 end
				table.insert(list,{patch=patch,position=start,target=wanderPoint(r,patch,B.wander,B.low,B.high),mode="fly",
					colour=colour,phase=r:NextNumber()*10,heading=Vector3.new(0,0,-1),born=now})
			end
		end
	end
	for _,b in ipairs(list)do
		if b.mode=="rest"then
			if now>=b.restUntil then
				b.mode="fly";b.target=wanderPoint(r,b.patch,B.wander,B.low,B.high)
			end
		else
			local to=b.target-b.position
			local step=B.speed*dt
			if to.Magnitude<=math.max(step,.05)then
				b.position=b.target
				if b.mode=="land"then
					b.mode="rest";b.restUntil=now+r:NextNumber(B.restMin,B.restMax)
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
-- The root pose: travel heading plus a yaw wobble, nose up, a bob in flight. Resting: still on the flower.
function Sim.butterflyRoot(b,now)
	local B=Sim.Butterfly
	local yaw=math.atan2(-b.heading.X,-b.heading.Z)
	if b.mode=="rest"then return CFrame.new(b.position)*CFrame.Angles(0,yaw,0)end
	local t=now+b.phase
	yaw+=math.rad(B.wobble)*math.sin(t*math.pi*2*B.wobbleHz)
	local bob=if b.mode=="land"then 0 else B.bob*math.sin(t*math.pi*2*B.bobHz)
	return CFrame.new(b.position+Vector3.new(0,bob,0))*CFrame.Angles(0,yaw,0)*CFrame.Angles(math.rad(B.pitch),0,0)
end
-- Wing angle: two poses at 7.5 Hz in flight (flip = which one), a slow sine at rest, one held pose when held.
function Sim.butterflyFlap(b,now,flip,held)
	if b.mode=="rest"then return math.rad(45+25*math.sin((now+b.phase)*math.pi))end
	if held then return math.rad(30)end
	return math.rad(if flip then 60 else -15)
end
-- Body, wing L, wing R (LOOK-R2 2). Each wing is a plate built standing (its Front/Back decals upright) and laid
-- flat by the last -90 about X: image top forward, the Back face up.
local flat90=CFrame.Angles(math.rad(-90),0,0)
function Sim.butterflyParts(root,phi)
	return{root,
		root*CFrame.new(-.05,.03,0)*CFrame.Angles(0,0,-phi)*CFrame.new(-.35,0,0)*flat90,
		root*CFrame.new(.05,.03,0)*CFrame.Angles(0,0,phi)*CFrame.new(.35,0,0)*flat90}
end

-- Birds (brief C1; LOOK 1) -------------------------------------------------------------------------------------
Sim.Bird=table.freeze({lift=.56,land=.8,leave=1.2,stayMin=8,stayMax=20,flee=12,
	fromMin=9,fromMax=12,upMin=4,upMax=6,riseMin=5,riseMax=7,away=10,
	dip=.12,dipPitch=12,dipIn=.10,dipOut=.15,hop=.35,hopTime=.22,hopDip=.06,hopDipTime=.08,flick=25,flickTime=.12,
	turnMin=20,turnMax=45,turnEveryMin=2.5,turnEveryMax=5,turnTime=.15,crouch=.10,crouchTime=.08,diveTilt=15,level=.2})
local Birds={};Birds.__index=Birds
Sim.Birds=Birds
function Birds.new(seed)return setmetatable({random=Random.new(seed or 3),list={}},Birds)end
function Birds:clear()table.clear(self.list)end
function Birds:find(perch)
	for _,bird in ipairs(self.list)do if bird.perch==perch then return bird end end
	return nil
end
local function yawOf(direction)return math.atan2(-direction.X,-direction.Z)end
-- A chirp from AmbientAudio's perch `perch` (its landing spot `landing`, or nil). "land" (a bird comes in), "hop"
-- (one already sits there), or nil and why: no spot, the cap, a station or the camera in the way, already busy.
-- Reduced Motion: it is just there, folded; no hop.
function Birds:chirp(now,perch,landing,cap,world,reduced)
	local B,r=Sim.Bird,self.random
	if typeof(landing)~="Vector3"then return nil,"spot"end
	local bird=self:find(perch)
	if bird then
		if bird.state=="sit"and not reduced then bird.hopAt=now;return "hop"end
		return nil,"busy"
	end
	if #self.list>=(cap or 0)then return nil,"cap"end
	-- A crown top: only the camera and the stations matter (the course and the pad are on the ground).
	local ok,why=Sim.clear(landing,{camera=world and world.camera,stations=world and world.stations})
	if not ok then return nil,why end
	local a=r:NextNumber()*math.pi*2
	local out=Vector3.new(math.cos(a),0,math.sin(a))
	local from=landing+out*r:NextNumber(B.fromMin,B.fromMax)+Vector3.new(0,r:NextNumber(B.upMin,B.upMax),0)
	bird={perch=perch,spot=landing,from=from,start=now,state=if reduced then "sit"else "land",colour=perch%3,
		yaw=yawOf(-out),stayUntil=now+r:NextNumber(B.stayMin,B.stayMax),turnAt=now+r:NextNumber(B.turnEveryMin,B.turnEveryMax)}
	if reduced then bird.landedAt=-math.huge end
	table.insert(self.list,bird)
	return "land"
end
-- Moves every bird on: landed, stayed long enough or the player within `flee`: off it goes (Reduced Motion: gone).
-- Returns the live list; each has root (CFrame), wings ("fly" | "perch") and flick (0 to 1).
function Birds:step(now,world,reduced,cap)
	local B,r,list=Sim.Bird,self.random,self.list
	world=world or {}
	for i=#list,1,-1 do
		local bird=list[i]
		local camera=world.camera
		if(camera and(bird.spot-camera).Magnitude>Sim.Drop)or i>(cap or math.huge)then
			table.remove(list,i);continue
		end
		if reduced and bird.state~="sit"then
			if bird.state=="land"then bird.state="sit";bird.landedAt=-math.huge;bird.hopAt=nil
			else table.remove(list,i);continue end
		end
		if bird.state=="land"and now-bird.start>=B.land then bird.state="sit";bird.landedAt=now end
		if bird.state=="sit"then
			local player=world.player
			if now>=bird.stayUntil or(player and(player-bird.spot).Magnitude<B.flee)then
				if reduced then table.remove(list,i);continue end
				local away=if player then Vector3.new(bird.spot.X-player.X,0,bird.spot.Z-player.Z)else Vector3.zero
				if away.Magnitude<1e-3 then away=Vector3.new(-math.sin(bird.yaw),0,-math.cos(bird.yaw))end
				bird.state,bird.leaveAt,bird.away,bird.rise="leave",now,away.Unit,r:NextNumber(B.riseMin,B.riseMax)
			elseif not reduced and now>=bird.turnAt then
				bird.turnAt=now+r:NextNumber(B.turnEveryMin,B.turnEveryMax)
				bird.turnFrom,bird.turnStart=bird.yaw,now
				bird.yaw+=math.rad(r:NextNumber(B.turnMin,B.turnMax))*(if r:NextNumber()<.5 then -1 else 1)
			end
		end
		if bird.state=="leave"and now-bird.leaveAt>=B.crouchTime+B.leave then table.remove(list,i);continue end
		Sim.birdPose(bird,now)
	end
	return list
end
local function smooth(t)t=math.clamp(t,0,1);return t*t*(3-2*t)end
-- Writes bird.root, bird.wings and bird.flick for now.
function Sim.birdPose(bird,now)
	local B=Sim.Bird
	local lift=Vector3.new(0,B.lift,0)
	if bird.state=="land"then
		local t=math.clamp((now-bird.start)/B.land,0,1)
		local s=1-(1-t)^2
		local at=bird.from:Lerp(bird.spot,s)+Vector3.new(0,math.sin(math.pi*t)*.8,0)+lift
		local tilt=math.rad(-B.diveTilt)*math.clamp((1-t)/B.level*B.land,0,1)
		bird.root=CFrame.new(at)*CFrame.Angles(0,bird.yaw,0)*CFrame.Angles(tilt,0,0)
		bird.wings,bird.flick="fly",0
		return
	end
	if bird.state=="leave"then
		local t=now-bird.leaveAt
		local yaw=yawOf(bird.away)
		if t<B.crouchTime then
			bird.root=CFrame.new(bird.spot+lift-Vector3.new(0,B.crouch,0))*CFrame.Angles(0,bird.yaw,0)
			bird.wings,bird.flick="perch",0
			return
		end
		local u=math.clamp((t-B.crouchTime)/B.leave,0,1)
		local at=bird.spot+lift+bird.away*(B.away*u*u)+Vector3.new(0,bird.rise*(1-(1-u)^2),0)
		bird.root=CFrame.new(at)*CFrame.Angles(0,yaw,0)
		bird.wings,bird.flick="fly",0
		return
	end
	-- Sitting: the landing squash, a hop on a repeat chirp, snappy idle turns.
	local y,pitch,flick=0,0,0
	local since=now-(bird.landedAt or -math.huge)
	if since<B.dipIn then
		local k=since/B.dipIn;y-=B.dip*k;pitch-=B.dipPitch*k
	elseif since<B.dipIn+B.dipOut then
		local k=1-(since-B.dipIn)/B.dipOut;y-=B.dip*k;pitch-=B.dipPitch*k
	end
	if bird.hopAt then
		local h=now-bird.hopAt
		if h<B.hopTime then local u=h/B.hopTime;y+=B.hop*4*u*(1-u)
		elseif h<B.hopTime+B.hopDipTime then y-=B.hopDip
		else bird.hopAt=nil end
		if h>=0 and h<B.flickTime then flick=1 end
	end
	local yaw=bird.yaw
	if bird.turnStart and now-bird.turnStart<B.turnTime then
		yaw=bird.turnFrom+(bird.yaw-bird.turnFrom)*smooth((now-bird.turnStart)/B.turnTime)
	end
	bird.root=CFrame.new(bird.spot+lift+Vector3.new(0,y,0))*CFrame.Angles(0,yaw,0)*CFrame.Angles(math.rad(pitch),0,0)
	bird.wings,bird.flick="perch",flick
end
-- Body, right eye, beak, wing L, wing R, left eye (LOOK-R2 1; eyes and beak from REVIEW-R2: two discs angled out and
-- forward so a bird facing you has two eyes, and a cube turned corner-first so the beak is a point, not a square). phi: the flap angle in flight. The wing plates are thin in X with
-- the texture tip-down (part -Y): perched, the tip points back and down; flying, it points out (+90 right, -90 left).
local tuck=CFrame.Angles(math.rad(-55),0,0)
function Sim.birdParts(root,wings,flick,phi)
	local parts={root,root*CFrame.new(.425,.128,-.357)*CFrame.Angles(0,math.rad(40),0)*CFrame.Angles(0,0,math.rad(13)),
		root*CFrame.new(0,-.04,-.64)*CFrame.Angles(math.rad(-35.26),0,0)*CFrame.Angles(0,math.rad(45),0)}
	parts[6]=root*CFrame.new(-.425,.128,-.357)*CFrame.Angles(0,math.rad(-40),0)*CFrame.Angles(0,0,math.rad(-13))
	if wings=="fly"then
		parts[4]=root*CFrame.new(-.42,.12,.05)*CFrame.Angles(0,0,-phi)*CFrame.new(-.33,0,0)*CFrame.Angles(0,0,-math.pi/2)
		parts[5]=root*CFrame.new(.42,.12,.05)*CFrame.Angles(0,0,phi)*CFrame.new(.33,0,0)*CFrame.Angles(0,0,math.pi/2)
	else
		-- The hop flick: the tip swung out by 25, before the yaw.
		local out=math.rad(Sim.Bird.flick)*(flick or 0)
		parts[4]=root*CFrame.new(-.60,-.06,.13)*CFrame.Angles(0,0,-out)*CFrame.Angles(0,math.rad(12),0)*tuck
		parts[5]=root*CFrame.new(.60,-.06,.13)*CFrame.Angles(0,0,out)*CFrame.Angles(0,math.rad(-12),0)*tuck
	end
	return parts
end
-- Flap: +50 and -20, two poses (flip = which one); held still at budget level 1.
function Sim.birdFlap(flip,held)
	if held then return 0 end
	return math.rad(if flip then 50 else -20)
end

-- Dewdrops (WORLD-PASS-2026-11-22 item 3, looks only; FRUIT-LOOK) ----------------------------------------------
-- Hanging under the lime crowns, 2 or 3 a crown; one lets go in a strong gust (the same one on every client: the
-- gust number and Wind.hash decide), falls, bounces twice, rolls downwind, rests, fades and regrows. A pet within
-- reach of a resting one bats it once, in place. Nothing to collect, no remote. Angles in degrees; a pose's rotation
-- is ImageLabel.Rotation (clockwise on screen): `world.right` (the camera's right) turns world travel into screen spin.
Sim.Fruit=table.freeze({
	slots=3,fill=.8,angles=table.freeze({40,160,285}),out=.36,down=.80,hang=.64,pool=16,reach=90,
	swayMin=3,swayGust=12,swayHz=2.2,
	dropAt=.8,rearm=.5,chance=.35,
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
-- A resting point: clear of the camera, stations and pad (Sim.clear), the Dash course whether or not a race is live,
-- every find spot and every park kerb grown by 2. false and the reason when not.
function Sim.fruitClear(position,world)
	world=world or {}
	local ok,why=Sim.clear(position,world)
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
local function screen(world,direction)
	local right=world and world.right
	return if typeof(right)=="Vector3"then right:Dot(direction)else 1
end
-- The whole flight of slot `slot` of crown i in gust n, let go at `now` from a sway of `sway` degrees; nil and why
-- when any landing has no good ground or the resting point is in the way (the fruit stays on the tree).
function Sim.fruitPlan(i,crown,slot,n,now,world,sway)
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
	local dot=screen(world,dir)
	local s,sr=sign(dot),sign(screen(world,heading))
	local r0=-F.tug*dot
	local r3=r0+F.turn*s
	-- The roll turns about 150 a stud and ends leaning 12 the way it went (the nearest such angle: no snap at rest).
	local lean=F.lean*sr
	local r4=lean+360*math.floor((r3+sr*F.spin*length-lean)/360+.5)
	local t1=now+F.letGo
	local t2=t1+F.fall
	local t3=t2+F.bounces[1].time
	local t4=t3+F.bounces[2].time
	local t5=t4+F.roll
	return{i=i,key=slot.key,k=slot.k,n=n,stem=slot.stem,crownY=crownY,start=now,sway=sway or 0,dot=dot,
		release=release,p1=p1,p2=p2,p3=p3,p4=p4,rest=p4,heading=heading,length=length,r0=r0,r3=r3,r4=r4,
		t1=t1,t2=t2,t3=t3,t4=t4,t5=t5,t6=t5+F.rest,lands={t2,t3,t4},poll=t5,pose={}}
end

local function hop(a,b,height,u)
	u=math.clamp(u,0,1)
	return a:Lerp(b,u)+Vector3.new(0,height*4*u*(1-u),0)
end
-- Where a loose fruit is now: {position, rotation, w, h (gui scale), transparency, phase}; phase is "tug", "fall",
-- "bounce", "roll", "rest", "bat", "fade" or "gone". Reuses plan.pose.
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

-- A resting fruit batted by a pet at `pet`: a hop 1 stud straight away (or straight up when that spot fails the
-- landing rules), one small bounce, a full turn. Once in its life. True when it hops.
function Sim.fruitBat(plan,pet,now,world)
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
	plan.bat={start=now,from=from,to=to,s=sign(screen(world,if to==from then away else to-from)),done=done,straight=to==from}
	plan.rest=to
	table.insert(plan.lands,now+F.batTime);table.insert(plan.lands,done)
	plan.t6=math.max(plan.t6,done)
	return true
end

-- The garden's fruit: which slots are empty (and since when), which crowns are armed for a gust, the loose ones.
local Orchard={};Orchard.__index=Orchard
Sim.Orchard=Orchard
function Orchard.new()return setmetatable({armed={},last={},empty={},loose={}},Orchard)end
-- Parked: the loose ones forgotten (their slots still regrow on time).
function Orchard:clear()table.clear(self.loose)end
-- Reduced Motion: none loose, every slot just filled (no regrow pop).
function Orchard:refill()table.clear(self.loose);table.clear(self.empty)end
-- A slot's hanging scale now: 1, 0 to 1.12 to 1 while it regrows, nil while it is empty.
function Orchard:hanging(key,now)
	local at=self.empty[key]
	if not at then return 1 end
	local t=now-at-F.regrow
	if t<0 then return nil end
	if t>=F.grow then self.empty[key]=nil;return 1 end
	local u=t/F.grow
	return if u<.7 then F.overshoot*smooth(u/.7)else F.overshoot-(F.overshoot-1)*smooth((u-.7)/.3)
end
-- The gust number when crown i's wind first passes dropAt (once a gust, re-armed under rearm), else nil.
function Orchard:gust(i,position,now,at)
	at=if type(at)=="number"then at else Wind.at(position,now)
	if at<F.rearm then self.armed[i]=nil;return nil end
	if at<F.dropAt or self.armed[i]==false then return nil end
	self.armed[i]=false
	local t=Wind.localTime(position,now)
	if not t then return nil end
	local n=math.floor(t/Wind.Slot+.5)
	if self.last[i]==n then return nil end
	self.last[i]=n
	return n
end
-- Gust n at crown i: the seeded chance, then the seeded filled slot (one `shown` holds, when given), then the flight.
-- The plan, or nil and why ("cap", "chance", "empty", "unseen", or a landing rule).
function Orchard:drop(i,crown,stems,n,now,world,cap,sway,shown)
	if #self.loose>=(cap or 0)then return nil,"cap"end
	local seed=n*16+i
	if Wind.hash(seed,13)>=F.chance then return nil,"chance"end
	local filled={}
	for _,slot in ipairs(stems)do if self.empty[slot.key]==nil then table.insert(filled,slot)end end
	if #filled==0 then return nil,"empty"end
	local slot=filled[math.floor(Wind.hash(seed,14)*#filled)+1]
	if shown and not shown[slot.key]then return nil,"unseen"end
	local plan,why=Sim.fruitPlan(i,crown,slot,n,now,world,if sway then sway(slot)else 0)
	if not plan then return nil,why end
	self.empty[slot.key]=now
	table.insert(self.loose,plan)
	return plan
end
-- Moves the loose fruit on: gone once faded, past Sim.Drop or over the cap; a quick fade near the camera or while a
-- race is live; a bat when a pet (flat, within F.bat) is by a resting one, on arrival and every poll. The live list.
-- pets: {Vector3} or a function returning them, called at most once a step and only when a poll is due.
function Orchard:step(now,world,pets,cap,live)
	local loose=self.loose
	local camera=world and world.camera
	local list=if type(pets)=="table"then pets else nil
	for index=#loose,1,-1 do
		local plan=loose[index]
		local position=Sim.fruitPose(plan,now).position
		if plan.pose.phase=="gone"or index>(cap or 0)or(camera and(position-camera).Magnitude>Sim.Drop)then
			table.remove(loose,index)
			continue
		end
		if not plan.quick and(live or(camera and(position-camera).Magnitude<F.near))then plan.quick=now end
		if not plan.bat and not plan.quick and now>=plan.poll and now<plan.t6 and pets then
			plan.poll=now+F.poll
			if not list then
				local ok,got=pcall(pets)
				list=if ok and type(got)=="table"then got else {}
			end
			local best,nearest=F.bat,nil
			for _,pet in ipairs(list)do
				if typeof(pet)=="Vector3"then
					local d=flat(plan.rest,pet)
					if d<=best then best,nearest=d,pet end
				end
			end
			if nearest then Sim.fruitBat(plan,nearest,now,world)end
		end
	end
	return loose
end

return table.freeze(Sim)
