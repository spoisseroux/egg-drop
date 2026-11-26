-- Bumble balls: the one pure sim (GARDEN-PLAY-BRIEF section 1). BallMotion.sample(record, now) is where a ball is at
-- workspace:GetServerTimeNow() `now`, for every observer: the kicker's prediction, the server's rest spot and everyone
-- else joining mid-arc all step the same fixed-step plan from the same record, so they agree to the last digit.
--
-- record {id, n, origin: Vector3, velocity: Vector3, startTime, kind?, target?, fade?}
--   a kick: gravity, bounces with Restitution, then a roll with drag to rest; it reflects off the leash, the Blocked
--   boxes, the wet boxes (water) and any ground that is not the island's safe walk map (IslandBounds.safeCell: the edge,
--   rocks). A step that would enter one turns the ball instead, so a ball that starts clear always ends clear.
--   kind "home": a slow straight roll from origin to target (the server checks the line is clear), or with `fade` a
--   jump straight there (the clients shrink, move and grow it).
-- The plan depends only on the record's origin, velocity and id (never startTime), so it is planned once per record and
-- cached. Plain numbers (no Vector3 maths) inside the loop: the same double arithmetic on every device.
local Balls=require(script.Parent.BumbleBalls)
local Motion={}
Motion.Step=1/60
Motion.MaxTime=6          -- a plan never runs longer
Motion.Gravity=60
Motion.Restitution=table.freeze({.55,.42,.30})
Motion.MinBounce=1.2      -- a landing slower than this (after restitution) rolls
Motion.Grip=.9            -- plan speed kept per bounce
Motion.RollDrag=1.2       -- per second, proportional
Motion.RollFriction=3     -- studs/s^2, constant
Motion.StopSpeed=.3
Motion.WallKeep=.65       -- speed kept off a wall or the leash
Motion.WaterKeep=.45      -- and off the water's edge
Motion.Ledge=.6           -- a roll whose ground drops more than this goes airborne
Motion.Pad=.6             -- the boxes grow by this (the ball's body, not its centre, meets them)

-- World ----------------------------------------------------------------------------------------------------------
-- A world: groundY(x, z) and hit(x, z) -> "wall" | "water" | nil. Specs build their own; the game uses the island.
local function box(cx,cz,sx,sz,yaw,kind)
	return{cx=cx,cz=cz,hx=sx*.5+Motion.Pad,hz=sz*.5+Motion.Pad,c=math.cos(yaw or 0),s=math.sin(yaw or 0),kind=kind}
end
Motion.box=box
local function inside(b,x,z)
	-- CFrame.Angles(0, yaw, 0): local X is (cos, 0, -sin), local Z is (sin, 0, cos).
	local dx,dz=x-b.cx,z-b.cz
	return math.abs(dx*b.c-dz*b.s)<=b.hx and math.abs(dx*b.s+dz*b.c)<=b.hz
end
function Motion.world(options)
	local boxes=options.boxes or {}
	local walkable=options.walkable
	return{groundY=options.groundY,boxes=boxes,hit=function(x,z)
		for _,b in ipairs(boxes)do if inside(b,x,z)then return b.kind end end
		if walkable and not walkable(x,z)then return "wall"end
		return nil
	end}
end
local island=nil
function Motion.island()
	if island then return island end
	local World=require(script.Parent.HollowWorldLayout)
	local boxes={}
	for _,b in ipairs(World.Blocked or {})do table.insert(boxes,box(b.center.X,b.center.Y,b.size.X,b.size.Y,b.yaw,"wall"))end
	for _,b in ipairs(World.Wet or {})do table.insert(boxes,box(b.center.X,b.center.Y,b.size.X,b.size.Y,b.yaw,"water"))end
	local walkable=nil
	if World.WorldVersion=="v7"then
		local Data=require(script.Parent.WorldV7Data)
		for _,b in ipairs(Data.wet or {})do table.insert(boxes,box(b.center[1],b.center[3],b.size[1],b.size[3],b.yaw,"water"))end
		local Bounds=require(script.Parent.IslandBounds)
		walkable=Bounds.safeCell
	end
	island=Motion.world({groundY=World.groundY,boxes=boxes,walkable=walkable})
	return island
end

-- Plan -----------------------------------------------------------------------------------------------------------
-- plan {xs, ys, zs (step k + 1 is time k * Step), duration, rest: Vector3, events {t, kind, strength}}
--   events: "bounce" (strength 0..1), "wall", "water"; the clients play sound and squash from them.
local cache=setmetatable({},{__mode="k"})
local function leashHit(home,x,z)
	local dx,dz=x-home.X,z-home.Y
	return dx*dx+dz*dz>Balls.Leash*Balls.Leash
end
local function blocked(world,home,x,z)
	if leashHit(home,x,z)then return "leash"end
	return world.hit(x,z)
end
Motion.blocked=function(id,position,world)
	local ball=Balls.ById[id]
	if not ball or not Balls.finite(position)then return "wall"end
	return blocked(world or Motion.island(),ball.home,position.X,position.Z)
end

local function kickPlan(record,world,home)
	local R,dt,g=Balls.Radius,Motion.Step,Motion.Gravity
	local o,v=record.origin,record.velocity
	local x,y,z=o.X,o.Y,o.Z
	local vx,vy,vz=v.X,v.Y,v.Z
	local ground=world.groundY(x,z)+R
	if y<ground then y=ground end
	local airborne=vy>0 or y>ground+.01
	local xs,ys,zs={x},{y},{z}
	local events={}
	local bounces=0
	local steps=math.floor(Motion.MaxTime/dt+.5)
	-- A ball already in a blocked spot (never from a server record) moves freely until it is out.
	local trapped=blocked(world,home,x,z)~=nil
	for k=1,steps do
		local t=k*dt
		local nx,nz=x+vx*dt,z+vz*dt
		local hit=if trapped then nil else blocked(world,home,nx,nz)
		if hit then
			local speed=math.sqrt(vx*vx+vz*vz)
			if hit=="leash"then
				local dx,dz=x-home.X,z-home.Y
				local len=math.sqrt(dx*dx+dz*dz)
				if len>1e-6 then
					local ux,uz=dx/len,dz/len
					local along=vx*ux+vz*uz
					if along>0 then vx-=2*along*ux;vz-=2*along*uz end
				else vx,vz=-vx,-vz end
			else
				local hx=blocked(world,home,nx,z)~=nil
				local hz=blocked(world,home,x,nz)~=nil
				if hx then vx=-vx end
				if hz then vz=-vz end
				if not hx and not hz then vx,vz=-vx,-vz end
			end
			local keep=if hit=="water"then Motion.WaterKeep else Motion.WallKeep
			vx*=keep;vz*=keep
			table.insert(events,{t=t,kind=if hit=="water"then "water"else "wall",strength=math.min(1,speed/Balls.KickFlat)})
			nx,nz=x,z
		elseif trapped then
			trapped=blocked(world,home,nx,nz)~=nil
		end
		x,z=nx,nz
		ground=world.groundY(x,z)+R
		local done=false
		if airborne then
			vy-=g*dt
			y+=vy*dt
			if y<=ground and vy<=0 then
				y=ground
				bounces+=1
				local impact=-vy
				table.insert(events,{t=t,kind="bounce",strength=math.min(1,impact/Balls.JumpUp)})
				local e=Motion.Restitution[bounces]
				vx*=Motion.Grip;vz*=Motion.Grip
				if e and impact*e>=Motion.MinBounce then vy=impact*e
				else vy=0;airborne=false end
			end
		else
			local speed=math.sqrt(vx*vx+vz*vz)
			local slower=speed-(Motion.RollDrag*speed+Motion.RollFriction)*dt
			if slower<=Motion.StopSpeed then
				vx,vz=0,0;done=true
			else
				local scale=slower/speed
				vx*=scale;vz*=scale
			end
			if ground<y-Motion.Ledge then airborne=true;vy=0 else y=ground end
		end
		table.insert(xs,x);table.insert(ys,y);table.insert(zs,z)
		if done then break end
	end
	-- Out of time while still moving: it stops where it is, on the ground.
	local last=#xs
	ys[last]=world.groundY(xs[last],zs[last])+R
	return{xs=xs,ys=ys,zs=zs,duration=(last-1)*dt,rest=Vector3.new(xs[last],ys[last],zs[last]),events=events}
end
local function homePlan(record,world)
	local R,dt=Balls.Radius,Motion.Step
	local o,target=record.origin,record.target
	local tx,tz=target.X,target.Z
	local ty=world.groundY(tx,tz)+R
	if record.fade then
		return{xs={tx},ys={ty},zs={tz},duration=0,rest=Vector3.new(tx,ty,tz),events={}}
	end
	local dx,dz=tx-o.X,tz-o.Z
	local length=math.sqrt(dx*dx+dz*dz)
	local seconds=math.min(Motion.MaxTime*4,length/Balls.HomeSpeed)
	local steps=math.max(1,math.ceil(seconds/dt))
	local xs,ys,zs={},{},{}
	for k=0,steps do
		local u=k/steps
		local x,z=o.X+dx*u,o.Z+dz*u
		table.insert(xs,x);table.insert(ys,world.groundY(x,z)+R);table.insert(zs,z)
	end
	return{xs=xs,ys=ys,zs=zs,duration=steps*dt,rest=Vector3.new(tx,ty,tz),events={}}
end
function Motion.plan(record,world)
	local own=world==nil
	if own then
		local hit=cache[record]
		if hit then return hit end
	end
	world=world or Motion.island()
	local ball=Balls.ById[record.id]
	assert(ball,"BallMotion: unknown ball")
	local plan=if record.kind=="home"then homePlan(record,world)else kickPlan(record,world,ball.home)
	if own then cache[record]=plan end
	return plan
end

-- Sample ---------------------------------------------------------------------------------------------------------
-- Pure: the plan's position, velocity and whether it still moves, `elapsed` seconds in.
function Motion.at(plan,elapsed)
	local xs,ys,zs=plan.xs,plan.ys,plan.zs
	local last=#xs
	if elapsed<=0 then return Vector3.new(xs[1],ys[1],zs[1]),Vector3.zero,last>1 end
	local f=elapsed/Motion.Step
	local i=math.floor(f)
	if i+1>=last then return plan.rest,Vector3.zero,false end
	local u=f-i
	local a,b=i+1,i+2
	local position=Vector3.new(xs[a]+(xs[b]-xs[a])*u,ys[a]+(ys[b]-ys[a])*u,zs[a]+(zs[b]-zs[a])*u)
	local velocity=Vector3.new(xs[b]-xs[a],ys[b]-ys[a],zs[b]-zs[a])/Motion.Step
	return position,velocity,true
end
function Motion.sample(record,now,world)
	if type(record)~="table"then return nil end
	return(Motion.at(Motion.plan(record,world),now-record.startTime))
end
-- Pure: a still record at `position` (a ball at rest: its home at start-up, or where a plan ended).
function Motion.rest(id,position,n)
	return{id=id,n=n or 0,origin=position,velocity=Vector3.zero,startTime=0}
end
-- Pure: a ball's home on the ground.
function Motion.home(id,world)
	world=world or Motion.island()
	local ball=Balls.ById[id]
	return Vector3.new(ball.home.X,world.groundY(ball.home.X,ball.home.Y)+Balls.Radius,ball.home.Y)
end
-- Pure: is the straight line from a to b clear for ball `id` (sampled every half stud)?
function Motion.lineClear(id,a,b,world)
	world=world or Motion.island()
	local home=Balls.ById[id].home
	local length=Balls.planDistance(a,b)
	local steps=math.max(1,math.ceil(length*2))
	for k=0,steps do
		local u=k/steps
		if blocked(world,home,a.X+(b.X-a.X)*u,a.Z+(b.Z-a.Z)*u)then return false end
	end
	return true
end
return table.freeze(Motion)
