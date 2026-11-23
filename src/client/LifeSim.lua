-- Garden life, the maths (ALIVE-LIFE-BUILD-PLAN-2026-11-22; look numbers artifacts/alive-life-2026-11-22/LOOK.md).
-- Pure: no instances, no clock, no services. GardenLife owns the parts and the one stepper and asks this what to show.
-- Everything random comes from a Random seeded by the caller, so the same seed and the same calls give the same
-- garden. Positions are Vector3, poses are CFrame; forward is -Z, up is +Y.
--   petals       Petals:step(now, dt, winds, cap) -> how many to Emit at each emitter now
--   bubbles      Bubbles:due(now, cap, allowed), Sim.bubbleSpot(camera, random, world), Bubbles:emit(now)
--   butterflies  Butterflies:step(now, dt, world, patches, cap, still) -> the live ones
--   birds        Birds:chirp(now, perch, landing, cap, world, reduced), Birds:step(now, dt, world, reduced)
-- `world` is {camera = Vector3?, player = Vector3?, stations = {Vector3}, pad = {x, z, r}?, course = {x, z, ...}?
-- (only while a race is live), groundY = fn?}.
local Sim={}

-- Caps by AliveBudget level 0, 1, 2 (level 1 halves every cap; level 2 shows nothing).
Sim.Caps=table.freeze({
	petals=table.freeze({24,12,0}),bubbles=table.freeze({8,4,0}),butterflies=table.freeze({4,2,0}),
	birds=table.freeze({3,2,0}),emitters=table.freeze({3,3,0}),
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

-- Petals (brief B4; LOOK 4) ------------------------------------------------------------------------------------
-- A second, at each emitter: none in the breeze (Wind.at's breeze is at most .25), 3 at a full gust.
Sim.PetalPeak=3
Sim.PetalCalm=.25
Sim.PetalLife=5.5 -- the longest a petal lives (LOOK: 4.5 to 5.5 s), so the live count never undercounts
function Sim.petalRate(at)
	if type(at)~="number"or at~=at then return 0 end
	return Sim.PetalPeak*math.clamp((at-Sim.PetalCalm)/(1-Sim.PetalCalm),0,1)
end
local Petals={};Petals.__index=Petals
Sim.Petals=Petals
function Petals.new()return setmetatable({live={},carry={}},Petals)end
function Petals:count(now)
	local live=self.live
	for i=#live,1,-1 do if live[i]<=now then table.remove(live,i)end end
	return #live
end
-- winds[i]: Wind.at at emitter i, or false where there is no emitter. Returns {n1, n2, ...}: how many to Emit now.
-- At the cap the fraction carries but nothing piles up, so a lull never ends in a burst.
function Petals:step(now,dt,winds,cap)
	local room=math.max(0,(cap or 0)-self:count(now))
	local out={}
	dt=if type(dt)=="number"and dt==dt then math.clamp(dt,0,.25)else 0
	for i,at in ipairs(winds)do
		local n=0
		if at then
			local carry=(self.carry[i]or 0)+Sim.petalRate(at)*dt
			n=math.min(math.floor(carry),room)
			carry-=math.floor(carry)
			self.carry[i]=carry
			room-=n
			for _=1,n do table.insert(self.live,now+Sim.PetalLife)end
		else
			self.carry[i]=0
		end
		out[i]=n
	end
	return out
end
function Petals:clear()table.clear(self.live);table.clear(self.carry)end

-- Bubbles (brief B7; plan revision 3) --------------------------------------------------------------------------
Sim.BubbleEvery=3
Sim.BubbleLife=9
Sim.BubbleAhead=table.freeze({10,16}) -- studs in front of the camera
Sim.BubbleSide=4
Sim.BubbleRise=.4
Sim.BubbleDrift=table.freeze({1.5,3})
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
-- Counts one in and returns its diameter (LOOK 3: 60% .5 to .75, 40% .75 to 1.1).
function Bubbles:emit(now)
	table.insert(self.live,now+Sim.BubbleLife)
	local r=self.random
	return if r:NextNumber()<.6 then r:NextNumber(.5,.75)else r:NextNumber(.75,1.1)
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
-- Body, wing L, wing R (LOOK 2).
function Sim.butterflyParts(root,phi)
	return{root,
		root*CFrame.new(-.05,.03,0)*CFrame.Angles(0,0,-phi)*CFrame.new(-.30,0,0),
		root*CFrame.new(.05,.03,0)*CFrame.Angles(0,0,phi)*CFrame.new(.30,0,0)}
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
-- Body, eyes, beak, wing L, wing R (LOOK 1). phi: the flap angle in flight.
function Sim.birdParts(root,wings,flick,phi)
	local parts={root,root*CFrame.new(0,.12,-.14),root*CFrame.new(0,-.02,-.68)}
	if wings=="fly"then
		parts[4]=root*CFrame.new(-.40,.10,.05)*CFrame.Angles(0,0,-phi)*CFrame.new(-.31,0,0)*CFrame.Angles(0,0,math.pi/2)
		parts[5]=root*CFrame.new(.40,.10,.05)*CFrame.Angles(0,0,phi)*CFrame.new(.31,0,0)*CFrame.Angles(0,0,math.pi/2)
	else
		local out=math.rad(Sim.Bird.flick)*(flick or 0)
		parts[4]=root*CFrame.new(-.56,-.04,.12)*CFrame.Angles(math.rad(-20),0,0)*CFrame.Angles(0,0,out)
		parts[5]=root*CFrame.new(.56,-.04,.12)*CFrame.Angles(math.rad(-20),0,0)*CFrame.Angles(0,0,-out)
	end
	return parts
end
-- Flap: +55 and -25, two poses (flip = which one); held still at budget level 1.
function Sim.birdFlap(flip,held)
	if held then return 0 end
	return math.rad(if flip then 55 else -25)
end

return table.freeze(Sim)
