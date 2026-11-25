-- The garden's scene, the maths (beta 14 QA W3: artifacts/qa-2026-11-23-beta14/WORLD-AND-NEST-LOOK.md section 1 and
-- GARDEN-LIFE-BUILD-PLAN.md section 4). Pure: no instances, no services; the caller passes the time, the camera and
-- the daylight. LifeScene owns the parts. Everything shared (the flock's flights, the lamps' order and times, the
-- shooting star) is a function of the server time and Wind.hash, so every client sees it together; what only looks
-- local (koi shyness, dragonflies, ripples) has its own Random.
--   dapple       Scene.dappleTransparency(daylight), Scene.dapplePose(centre, t, g, phase), Scene.nearest(points, eye, n)
--   koi          Scene.koiPose(k, t, shift, f), Scene.koiShift(shift, player, dt), Scene.ripple(age)
--   far flock    Scene.flockAt(t) -> n, age; Scene.flockBirds(n, age, t, count) -> {wing L, wing R} per bird
--   dragonflies  Scene.Dragonflies:step(now, boxes, eye, cap, day), Scene.dragonflyParts(fly, now)
--   lamps        Scene.lampOrder(), Scene.crossings(daylightOf), Scene.lampLevel(rank, s, cross, reduced)
--   star         Scene.starAt(t) -> streak, u, hour
local Wind=require(script.Parent.Wind)
local Scene={}

local TAU=math.pi*2
local function smooth(x)x=math.clamp(x,0,1);return x*x*(3-2*x)end
local hex=Color3.fromHex

-- Caps by AliveBudget level 0, 1, 2 (level 2: GardenLife is torn down, so none). lights: the lamps' PointLights (phone:
-- cut first, so level 0 only).
Scene.Caps=table.freeze({dapple=table.freeze({6,3,0}),koi=table.freeze({3,2,0}),flock=table.freeze({5,3,0}),
	dragonflies=table.freeze({2,1,0}),lights=table.freeze({4,0,0}),
	-- Beta 17 1.3 B: drifting leaves on the stream, and the flow rings round the stones and piers.
	leaves=table.freeze({6,3,0}),rings=table.freeze({7,7,0})})
function Scene.cap(kind,level)
	level=math.clamp(math.floor(tonumber(level)or 0),0,2)
	return Scene.Caps[kind][level+1]
end

-- Row 3: dapple under the 6 crowns nearest the camera ------------------------------------------------------------
-- FABLE-REVIEW-R5 5: .55 by day (was .72: too faint to read), 11 studs (was 9). If it reads as a sticker, .62.
Scene.Dapple=table.freeze({size=11,lift=.055,colour=hex("#1E2A16"),day=.55,full=.45,gone=.30,drift=.35,period=9,turn=4,
	turnPeriod=13,gust=.5,hz=10,pick=1,fade=.3})
-- The decal's transparency for the garden hour's daylight: .72 by day (and with the hour off), 1 under .30.
function Scene.dappleTransparency(daylight)
	local D=Scene.Dapple
	if type(daylight)~="number"or daylight~=daylight then return D.day end
	return D.day+(1-D.day)*smooth((D.full-daylight)/(D.full-D.gone))
end
-- The plate's pose: its centre drifts along the wind (.35 over 9 s, plus .5 in a gust) and turns +-4 degrees over 13 s.
function Scene.dapplePose(centre,t,g,phase)
	local D=Scene.Dapple
	t=(t or 0)+(phase or 0)
	g=if type(g)=="number"and g==g then math.clamp(g,0,1)else 0
	local along=D.drift*math.sin(TAU*t/D.period)+D.gust*g
	return CFrame.new(centre+Wind.Direction*along+Vector3.new(0,D.lift,0))*CFrame.Angles(0,math.rad(D.turn)*math.sin(TAU*t/D.turnPeriod),0)
end
-- Indices of the n points nearest `eye` on the ground plane, nearest first.
function Scene.nearest(points,eye,n)
	local list={}
	if typeof(eye)~="Vector3"then return list end
	for i,p in ipairs(points or {})do
		local dx,dz=p.X-eye.X,p.Z-eye.Z
		table.insert(list,{i=i,d=dx*dx+dz*dz})
	end
	table.sort(list,function(a,b)return if a.d==b.d then a.i<b.i else a.d<b.d end)
	local out={}
	for k=1,math.min(n or 0,#list)do out[k]=list[k].i end
	return out
end

-- Row 4: koi in the falls pool ------------------------------------------------------------------------------------
-- The pool from the walk map (Water_Pool_Falls; WorldAero.Look.PoolTop agrees). [check] with the island session after
-- its pool repaint: centre, size, surface, and that the water shows the koi (else `over`).
Scene.Pool=table.freeze({centre=Vector3.new(64.5,3.2,-66),half=Vector2.new(13.5,12),share=.6})
Scene.Koi=table.freeze({speed=.5,tail=8,tailHz=1.1,depth=.25,over=true,overLift=.02,overTransparency=.35,
	-- The plate: 1.3 long along its travel (-Z under lookAt), .5 wide; the texture is portrait, head at the top [check] the
	-- Top decal's orientation in Studio (flip the image if a koi swims tail first).
	scales=table.freeze({1,.85,.7}),phases=table.freeze({0,2.1,4.2}),size=Vector3.new(.5,.02,1.3),
	shy=3,shift=.4,shiftSpeed=1.2,back=4,rise=table.freeze({9,15}),
	ripple=table.freeze({from=.4,to=1.6,start=.3,time=1.4,lift=.02}),hz=15,face=180})
-- The figure of eight's length for half extents (a, b), measured once.
local lengths={}
local function eightLength(a,b)
	local key=string.format("%.3f:%.3f",a,b)
	if lengths[key]then return lengths[key]end
	local total,last=0,nil
	for i=0,720 do
		local th=TAU*i/720
		local p=Vector2.new(a*math.sin(th),b*math.sin(2*th))
		if last then total+=(p-last).Magnitude end
		last=p
	end
	lengths[key]=total
	return total
end
-- Koi k's pose at time t: a figure of eight inside 60% of the pool (scaled per koi), moved by the shy `shift` (a
-- Vector3 on the ground plane) and shrunk by f (0 to 1, how shy), along the path at .5 studs a second, the tail sway
-- turning the plate +-8 degrees at 1.1 Hz. Returns the CFrame and the plate's flat position.
function Scene.koiPose(k,t,shift,f)
	local P,K=Scene.Pool,Scene.Koi
	local scale=K.scales[(k-1)%#K.scales+1]*(1-.4*math.clamp(f or 0,0,1))
	local a,b=P.half.X*P.share*scale,P.half.Y*P.share*scale/2
	local length=eightLength(a,b)
	local th=TAU*(t*K.speed/length)+K.phases[(k-1)%#K.phases+1]
	local at=P.centre+(shift or Vector3.zero)+Vector3.new(a*math.sin(th),0,b*math.sin(2*th))
	local dir=Vector3.new(a*math.cos(th),0,2*b*math.cos(2*th))
	dir=if dir.Magnitude>1e-6 then dir.Unit else Vector3.new(1,0,0)
	local y=if K.over then P.centre.Y+K.overLift else P.centre.Y-K.depth
	local position=Vector3.new(at.X,y,at.Z)
	local sway=math.rad(K.tail)*math.sin(TAU*K.tailHz*t+k)
	-- R5 Studio check: the Top decal drew the koi tail first, so the plate turns 180 (Koi.face).
	return CFrame.lookAt(position,position+dir)*CFrame.Angles(0,sway+math.rad(K.face),0),position
end
-- The shy offset: a player within 3 studs of the bank pushes the koi toward the far side (up to 40% of the shorter half
-- extent, at 1.2 studs a second); away, they drift back over 4 s. Returns the new shift and f (0 to 1).
function Scene.koiShift(shift,player,dt)
	local P,K=Scene.Pool,Scene.Koi
	shift=shift or Vector3.zero
	dt=if type(dt)=="number"and dt==dt then math.clamp(dt,0,.25)else 0
	local most=K.shift*math.min(P.half.X,P.half.Y)
	local goal=Vector3.zero
	local speed=most/K.back
	if typeof(player)=="Vector3"then
		local dx,dz=(player.X-P.centre.X)/P.half.X,(player.Z-P.centre.Z)/P.half.Y
		local e=math.sqrt(dx*dx+dz*dz)
		if e<1+K.shy/math.min(P.half.X,P.half.Y)then
			local away=Vector3.new(P.centre.X-player.X,0,P.centre.Z-player.Z)
			if away.Magnitude>1e-3 then goal=away.Unit*most;speed=K.shiftSpeed end
		end
	end
	local to=goal-shift
	local step=speed*dt
	shift=if to.Magnitude<=step then goal else shift+to.Unit*step
	return shift,math.clamp(shift.Magnitude/most,0,1)
end
-- A rise's ring `age` seconds in: its size (studs) and transparency, or nil when done.
function Scene.ripple(age)
	local R=Scene.Koi.ripple
	if type(age)~="number"or age<0 or age>=R.time then return nil end
	local u=age/R.time
	return R.from+(R.to-R.from)*(1-(1-u)^2),R.start+(1-R.start)*u
end

-- Row 5: a far flock ----------------------------------------------------------------------------------------------
-- Every 90 to 150 s (slot 120, jitter 15: every gap inside 90 to 150), shared by the server time; only by day (the
-- caller checks the daylight). 5 birds (level 1: 3) in a loose V on a shallow arc 130 to 170 studs out, 45 to 60 up,
-- 9 studs a second, 25 s in view. Each bird is two flat wing plates flapping 25 degrees at 2.6 Hz.
Scene.Flock=table.freeze({slot=120,jitter=15,speed=9,arc=225,length=225/9,bulge=8,near=130,far=170,low=45,high=60,
	centre=Vector3.new(4,4,-2),wing=Vector3.new(.9,.02,.35),colour=hex("#3B3A40"),flap=25,flapHz=2.6,
	spacing=2.5,wobble=.6,hz=15})
function Scene.flockStart(n)
	local F=Scene.Flock
	return n*F.slot+(Wind.hash(n,41)*2-1)*F.jitter
end
-- The flight in the air at time t: its number and age, or nil.
function Scene.flockAt(t)
	local F=Scene.Flock
	if type(t)~="number"or t~=t then return nil end
	local base=math.floor(t/F.slot)
	for n=base-1,base+1 do
		local age=t-Scene.flockStart(n)
		if age>=0 and age<F.length then return n,age end
	end
	return nil
end
-- Flight n's birds `age` seconds in (time t for the flap): {{left, right}, ...} wing CFrames, `count` birds.
function Scene.flockBirds(n,age,t,count)
	local F=Scene.Flock
	local bearing=Wind.hash(n,42)*TAU
	local radius=F.near+(F.far-F.near)*Wind.hash(n,43)
	local height=F.centre.Y+F.low+(F.high-F.low)*Wind.hash(n,44)
	local sense=if Wind.hash(n,45)<.5 then -1 else 1
	local out=Vector3.new(math.cos(bearing),0,math.sin(bearing))
	local dir=Vector3.new(-out.Z,0,out.X)*sense
	local side=Vector3.new(-dir.Z,0,dir.X)
	local s=-F.arc/2+F.speed*age
	local x=2*s/F.arc
	local lead=F.centre+out*radius+dir*s+out*(F.bulge*(1-x*x))+Vector3.new(0,height-F.centre.Y,0)
	local birds={}
	local rows={{0,0},{1,-1},{1,1},{2,-1},{2,1}}
	for k=1,math.min(count or 5,#rows)do
		local row=rows[k]
		local at=lead-dir*(row[1]*F.spacing)+side*(row[2]*row[1]*F.spacing)
			+Vector3.new(0,(Wind.hash(n*8+k,46)*2-1)*F.wobble,0)
		local root=CFrame.lookAt(at,at+dir)
		local phi=math.rad(F.flap)*math.sin(TAU*F.flapHz*t+k)
		local half=F.wing.X/2
		birds[k]={root*CFrame.Angles(0,0,phi)*CFrame.new(-half,0,0),root*CFrame.Angles(0,0,-phi)*CFrame.new(half,0,0)}
	end
	return birds
end

-- Row 8: dragonflies over the water -------------------------------------------------------------------------------
-- By day, 2 (level 1: 1), each over its own water box within 60 studs of the camera: hover .8 to 2 s (a small bob, the
-- wings a blur: two angles swapped at 15 Hz), then a straight dart of 3 to 5 studs in .35 s (eased out) to a point 1 to
-- 1.6 over the water inside the box. A box is {frame = CFrame (centre, yawed), hx, hz, y (the water's top)}.
Scene.Dragonfly=table.freeze({body=Vector3.new(.06,.06,.35),wing=Vector3.new(.5,.01,.14),bodyColour=hex("#3F6F78"),
	wingColour=hex("#C9D6D8"),wingTransparency=.55,hover=table.freeze({.8,2}),dart=table.freeze({3,5}),dartTime=.35,
	up=table.freeze({1,1.6}),bob=.05,bobHz=1.3,flick=12,flickHz=15,reach=60,inset=1,tries=6})
local Dragonflies={};Dragonflies.__index=Dragonflies
Scene.Dragonflies=Dragonflies
function Dragonflies.new(seed)return setmetatable({random=Random.new(seed or 9),list={}},Dragonflies)end
function Dragonflies:clear()table.clear(self.list)end
local function boxPoint(r,box)
	local D=Scene.Dragonfly
	local hx,hz=math.max(0,box.hx-D.inset),math.max(0,box.hz-D.inset)
	local p=box.frame*Vector3.new(r:NextNumber(-hx,hx),0,r:NextNumber(-hz,hz))
	return Vector3.new(p.X,box.y+r:NextNumber(D.up[1],D.up[2]),p.Z)
end
-- A dart target 3 to 5 studs from `from` inside the box, or a fresh point in it.
local function dartTo(r,box,from)
	local D=Scene.Dragonfly
	for _=1,D.tries do
		local a,d=r:NextNumber()*TAU,r:NextNumber(D.dart[1],D.dart[2])
		local p=Vector3.new(from.X+math.cos(a)*d,box.y+r:NextNumber(D.up[1],D.up[2]),from.Z+math.sin(a)*d)
		local q=box.frame:PointToObjectSpace(Vector3.new(p.X,box.frame.Position.Y,p.Z))
		if math.abs(q.X)<=box.hx-D.inset and math.abs(q.Z)<=box.hz-D.inset then return p end
	end
	return boxPoint(r,box)
end
-- The live list: each {box, position, yaw, hoverUntil, dart = {from, to, start}?}.
function Dragonflies:step(now,boxes,eye,cap,day)
	local D,list,r=Scene.Dragonfly,self.list,self.random
	if not day or typeof(eye)~="Vector3"or(cap or 0)<=0 then table.clear(list);return list end
	for i=#list,1,-1 do
		local fly=list[i]
		if i>cap or(fly.position-eye).Magnitude>D.reach*1.5 then table.remove(list,i)end
	end
	if #list<cap then
		local used={}
		for _,fly in ipairs(list)do used[fly.box]=true end
		local near={}
		for _,box in ipairs(boxes or {})do
			local c=box.frame.Position
			if not used[box]and Vector3.new(c.X-eye.X,0,c.Z-eye.Z).Magnitude<=D.reach and box.hx>D.inset and box.hz>D.inset then
				table.insert(near,box)
			end
		end
		if #near>0 then
			local box=near[r:NextInteger(1,#near)]
			local at=boxPoint(r,box)
			table.insert(list,{box=box,position=at,yaw=r:NextNumber()*TAU,hoverUntil=now+r:NextNumber(D.hover[1],D.hover[2]),phase=r:NextNumber()})
		end
	end
	for _,fly in ipairs(list)do
		local dart=fly.dart
		if dart then
			local u=(now-dart.start)/D.dartTime
			if u>=1 then
				fly.position,fly.dart=dart.to,nil
				fly.hoverUntil=now+r:NextNumber(D.hover[1],D.hover[2])
			else
				fly.position=dart.from:Lerp(dart.to,1-(1-u)^2)
			end
		elseif now>=fly.hoverUntil then
			local to=dartTo(r,fly.box,fly.position)
			local d=Vector3.new(to.X-fly.position.X,0,to.Z-fly.position.Z)
			if d.Magnitude>1e-3 then fly.yaw=math.atan2(-d.X,-d.Z)end
			fly.dart={from=fly.position,to=to,start=now}
		end
	end
	return list
end
-- Body, wing L, wing R for a fly now: hovering it bobs; the wings swap +-12 degrees at 15 Hz (a blur).
function Scene.dragonflyParts(fly,now)
	local D=Scene.Dragonfly
	local bob=if fly.dart then 0 else D.bob*math.sin(TAU*(D.bobHz*now+fly.phase))
	local root=CFrame.new(fly.position+Vector3.new(0,bob,0))*CFrame.Angles(0,fly.yaw,0)
	local flick=math.rad(D.flick)*(if math.floor(now*D.flickHz)%2==0 then 1 else -1)
	local half=D.wing.X/2
	return{root,root*CFrame.new(-.02,.02,-.04)*CFrame.Angles(0,0,flick)*CFrame.new(-half,0,0),
		root*CFrame.new(.02,.02,-.04)*CFrame.Angles(0,0,-flick)*CFrame.new(half,0,0)}
end

-- Row 6: lamps one by one, and a shooting star -------------------------------------------------------------------
-- The v7 lamps (scripts/build_dash_course.py LAMPS, measured; the orbs' band is 8.3 to 9.8 high: [check] the halo
-- height on each). The merged orb mesh (W7_LampOrbs__glow_warm) changes colour all at once (AeroWorld); these halos and
-- lights are what come on one by one.
Scene.Lamps=table.freeze({Vector3.new(69.65,9,51.97),Vector3.new(29.44,9,29.85),Vector3.new(-9,9,28),Vector3.new(-12,9,-44),
	Vector3.new(-70,9,-3),Vector3.new(50,9,-10),Vector3.new(-22,9,38)})
Scene.Lamp=table.freeze({at=.45,gap=.35,dawnGap=.15,ease=.8,plaza=Vector2.new(-30,4),colour=hex("#FFC96A"),halo=2.2,
	brightness=1.2,range=10,haloTransparency=.15})
Scene.Period=3600
-- The lamps in the order they light: nearest the plaza's middle first.
function Scene.lampOrder()
	local L=Scene.Lamp
	local order={}
	for i in ipairs(Scene.Lamps)do order[i]=i end
	local function d(i)local p=Scene.Lamps[i];return(p.X-L.plaza.X)^2+(p.Z-L.plaza.Y)^2 end
	table.sort(order,function(a,b)return d(a)<d(b)end)
	return order
end
-- The garden hour's seconds at which its daylight falls through .45 (down) and rises through it (up), from
-- daylightOf(s) for s in [0, 3600) (GardenHour.phase(s).daylight); nil when it never crosses.
function Scene.crossings(daylightOf)
	local L,P=Scene.Lamp,Scene.Period
	local function dl(s)return daylightOf(s%P)end
	local function refine(a,b,falling)
		for _=1,30 do
			local m=(a+b)/2
			local below=dl(m)<=L.at
			if below==falling then b=m else a=m end
		end
		return b
	end
	local down,up
	local last=dl(P-1)
	for s=0,P-1 do
		local now=dl(s)
		if last>L.at and now<=L.at and not down then down=refine(s-1,s,true)end
		if last<=L.at and now>L.at and not up then up=refine(s-1,s,false)end
		last=now
	end
	if not down or not up then return nil end
	return{down=down%P,up=up%P}
end
-- Lamp `rank` (1 lights first)'s level 0 to 1 at hour-second s: on .35 s apart from the fall through .45, each easing
-- in over .8 s; off .15 s apart from the rise. Reduced Motion: all at once, no ease.
function Scene.lampLevel(rank,s,cross,reduced)
	local L,P=Scene.Lamp,Scene.Period
	if not cross or type(s)~="number"or s~=s then return 0 end
	local gap,dawn,ease=L.gap,L.dawnGap,L.ease
	if reduced then gap,dawn,ease=0,0,0 end
	local on,off=cross.down+gap*(rank-1),cross.up+dawn*(rank-1)
	local span=(off-on)%P
	local sinceOn=(s-on)%P
	if sinceOn<span then return if ease>0 then smooth(sinceOn/ease)else 1 end
	local sinceOff=(s-off)%P
	if ease>0 and sinceOff<ease then
		-- Off from wherever it was (a short night still eases out from full).
		return 1-smooth(sinceOff/ease)
	end
	return 0
end
-- The shooting star: once a night, in its middle third (hour seconds 3120 to 3360), 3 streaks 6 to 9 s apart, each .7 s.
-- t: the garden hour's clock (server time + offset). Returns the streak (1 to 3), its progress 0 to 1, and the hour's
-- number (the seed), or nil.
Scene.Star=table.freeze({from=3120,to=3360,streaks=3,gap=table.freeze({6,9}),time=.7,length=14,width=.25,
	colour=hex("#FFF4D6"),distance=200,travel=30,bearing=40,low=35,high=50})
function Scene.starTimes(hour)
	local S=Scene.Star
	local room=(S.to-S.from)-(S.streaks-1)*S.gap[2]-S.time
	local at=hour*Scene.Period+S.from+Wind.hash(hour,31)*room
	local times={at}
	for j=2,S.streaks do
		at+=S.gap[1]+(S.gap[2]-S.gap[1])*Wind.hash(hour*4+j,32)
		times[j]=at
	end
	return times
end
function Scene.starAt(t)
	local S=Scene.Star
	if type(t)~="number"or t~=t then return nil end
	local hour=math.floor(t/Scene.Period)
	for j,start in ipairs(Scene.starTimes(hour))do
		if t>=start and t<start+S.time then return j,(t-start)/S.time,hour end
	end
	return nil
end
-- A streak's head and tail for a camera (placement per client: 200 studs out within +-40 degrees of its look, 35 to 50
-- degrees up; timing shared). u: 0 to 1 through the streak.
function Scene.starStreak(hour,j,u,camera)
	local S=Scene.Star
	local look=Vector3.new(camera.LookVector.X,0,camera.LookVector.Z)
	look=if look.Magnitude>1e-3 then look.Unit else Vector3.new(0,0,-1)
	local turn=math.rad((Wind.hash(hour*4+j,34)*2-1)*S.bearing)
	local flat=Vector3.new(look.X*math.cos(turn)-look.Z*math.sin(turn),0,look.X*math.sin(turn)+look.Z*math.cos(turn))
	local up=math.rad(S.low+(S.high-S.low)*Wind.hash(hour*4+j,35))
	local centre=camera.Position+(flat*math.cos(up)+Vector3.new(0,math.sin(up),0))*S.distance
	local side=Vector3.new(-flat.Z,0,flat.X)*(if Wind.hash(hour*4+j,36)<.5 then -1 else 1)
	local dir=(side+Vector3.new(0,-.4,0)).Unit
	local head=centre+dir*(S.travel*(u-.5))
	return head,head-dir*S.length
end

-- Beta 17 (WORLD-ALIVE-LOOK 1.3 B): things on the water --------------------------------------------------------------
-- Drifting leaves ride the stream's centre line (the Water_Stream boxes in order, north to south: the stream runs from
-- the Sky Falls channel down to the falls pool [check] that this is the way its texture scrolls) at 1.1 studs a second,
-- each `side` x 35% of the half width off the line, wandering .3 x sin(2 pi t / 7), spinning 8 to 20 degrees a second,
-- fading in over the first second and out over the last. Within 1.5 studs of a stone or pier they ease round it. The
-- clock is the server's, so every client sees the same leaves. Flow rings: one plate round each stone and pier, the
-- ripple texture, pulsing 1.15 to 1.5 x its footprint over 2.6 s and fading .55 to .9, each on its own phase.
Scene.Water=table.freeze({surface=3.2,lift=.02,speed=1.1,side=.35,wander=.3,wanderPeriod=7,spinMin=8,spinMax=20,fade=1,
	leaf=Vector3.new(.7,.02,.45),clear=1.5,hz=15,far=110,extra=2,breathAt=.5,
	ringFrom=1.15,ringTo=1.5,ringPeriod=2.6,ringClear=.55,ringGone=.9,ringStill=1.2,ringLift=.03})
-- The centre line from the stream boxes ({frame, hx, hz, y, name}) in order: points, half widths (the box's smaller
-- half extent, so a leaf stays on the water however the box is turned) and the distance along at each point.
function Scene.streamPath(boxes)
	local points,halves,along={},{},{}
	local total=0
	for _,box in ipairs(boxes or {})do
		if box.name==nil or box.name=="Water_Stream"then
			local p=box.frame.Position
			local at=Vector3.new(p.X,Scene.Water.surface+Scene.Water.lift,p.Z)
			if #points>0 then total+=(at-points[#points]).Magnitude end
			table.insert(points,at);table.insert(halves,math.min(box.hx,box.hz));table.insert(along,total)
		end
	end
	return{points=points,halves=halves,along=along,total=total}
end
-- The point `s` studs down the path: position, unit heading (flat) and the half width there.
function Scene.pathAt(path,s)
	local points,along=path.points,path.along
	local n=#points
	if n<2 then return nil end
	s=math.clamp(s,0,path.total)
	local i=1
	while i<n-1 and along[i+1]<s do i+=1 end
	local span=along[i+1]-along[i]
	local u=if span>0 then(s-along[i])/span else 0
	local a,b=points[i],points[i+1]
	local heading=Vector3.new(b.X-a.X,0,b.Z-a.Z)
	heading=if heading.Magnitude>1e-6 then heading.Unit else Vector3.new(0,0,-1)
	return a:Lerp(b,u),heading,path.halves[i]+(path.halves[i+1]-path.halves[i])*u
end
-- The sideways offset that keeps a leaf `clear` studs off each obstacle ({x, z, size}) near it, eased in and out along
-- the stream so it slides round instead of jumping. `prefer` (the lap's own side, without the wander) picks which way
-- round, so the choice never flips while the leaf passes.
function Scene.skirt(at,heading,side,obstacles,prefer)
	local W=Scene.Water
	local normal=Vector3.new(-heading.Z,0,heading.X)
	prefer=prefer or side
	for _,o in ipairs(obstacles or {})do
		local d=Vector3.new(o.x-at.X,0,o.z-at.Z)
		local ahead,across=d:Dot(heading),d:Dot(normal)
		local radius=(o.size or 0)/2
		local reach=radius+2*W.clear
		if math.abs(ahead)<reach then
			local need=radius+.3 -- the leaf's own half size
			local w=smooth(1-math.abs(ahead)/reach)
			if prefer>=across then
				local goal=across+need
				if side<goal then side+=(goal-side)*w end
			else
				local goal=across-need
				if side>goal then side+=(goal-side)*w end
			end
		end
	end
	return side
end
-- Leaf k of `count` at server time `now`: its frame and the decal's transparency (0 shown .. 1 gone), or nil past the
-- ends. The leaves are evenly spaced along the loop; each lap rolls its own side and spin (Wind.hash).
function Scene.leaf(path,k,count,now,obstacles)
	local W=Scene.Water
	if not path or path.total<=0 or count<=0 then return nil end
	local lap=path.total/W.speed
	local t=now+(k-1)*lap/count
	local n=math.floor(t/lap)
	local age=t-n*lap
	local s=age*W.speed
	local at,heading,half=Scene.pathAt(path,s)
	if not at then return nil end
	local seed=n*16+k
	local base=(Wind.hash(seed,61)*2-1)*W.side*half
	local side=base+W.wander*math.sin(TAU*(t+k*1.3)/W.wanderPeriod)
	side=Scene.skirt(at,heading,side,obstacles,base)
	local spin=(W.spinMin+(W.spinMax-W.spinMin)*Wind.hash(seed,62))*(if Wind.hash(seed,63)<.5 then -1 else 1)
	local normal=Vector3.new(-heading.Z,0,heading.X)
	local position=at+normal*side
	local yaw=math.rad(spin*age)+Wind.hash(seed,64)*TAU
	local fade=math.min(smooth(age/W.fade),smooth((lap-age)/W.fade))
	return CFrame.new(position)*CFrame.Angles(0,yaw,0),1-fade
end
-- A flow ring's size multiplier and the decal's transparency at `now` for phase `phase` (seconds); Reduced Motion: still.
function Scene.flowRing(now,phase,reduced)
	local W=Scene.Water
	if reduced then return W.ringStill,W.ringClear end
	local u=((now+(phase or 0))%W.ringPeriod)/W.ringPeriod
	return W.ringFrom+(W.ringTo-W.ringFrom)*u,W.ringClear+(W.ringGone-W.ringClear)*smooth(u)
end

return table.freeze(Scene)
