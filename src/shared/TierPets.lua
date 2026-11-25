-- Pets go up (artifacts/qa-2026-11-26-beta21/WORLD-FINISH-LOOK.md section 5, slice A; architect review applied): pets
-- follow their owners up the cliff path, onto the terrace and back down. The path is transit only (no wander, rest,
-- focus or find on it but the turn pocket's one rest spot); a pet on it walks the middle 3 studs of the tread behind its
-- owner and hops each step of the flight; the terrace is pet floor less 3 studs.
--
-- The Tier pattern: FeatureFlags.TierPets is the build ceiling (with Tier's own ceiling: the beta place or Studio), and
-- the server's switch (TierPetsConfig, ConfigService `garden_tier_pets`: off until the config has loaded once, then
-- missing or malformed = on). The server's gate is TierHost.open and on() and the pet catch-up switch (a pet that falls
-- behind on the flight needs its hop). Off is the game before this build: the pet floor, the planner and every hook in
-- init.server take today's line exactly.
--
-- Pure geometry here, read from Tier.path() (CliffDenData's centre line: points, widths, step flags, arc length u) and
-- Tier's terrace frame. Every function takes an optional path `p` (specs). Positions are pet roots: the ground + Sole.
--   zone(pos)              "terrace" | "path" | "lawn"
--   plan(...)              the legs of a route between zones (GardenState's planner shape), nil when none is needed
--   routeDistance(a, b)    route studs, for catch-up (nil when both are on the lawn or both on the terrace)
--   landing(anchor, pet)   a catch-up landing on the path: LandBehind studs behind the owner, never on the flight
--   anchor / snap          the owner's follow point and a target snapped into the lane or the terrace
--   rests(), restAt(pos)   the pets' rest spots up there (GardenState rest anchors, never exclusive)
local RunService=game:GetService("RunService")
local Flags=require(script.Parent.FeatureFlags)
local Tier=require(script.Parent.Tier)
local Activity=require(script.Parent.GardenActivity)
local Layout=require(script.Parent.GardenLayout)
local Pets={}
Pets.Attribute="TierPets_on"
Pets.Key="garden_tier_pets"
Pets.Lane=1.5          -- pets keep to the middle 3 studs of the tread
Pets.Keep=3            -- and 3 studs inside the terrace's edge
Pets.Sole=.025         -- a pet root stands this far over the ground (GardenLayout.groundAt)
Pets.Below,Pets.Above=2,7 -- a point is on the path when the tread under it is off the lawn and the point within these of it
Pets.LowBelow=4        -- a point in a pet-blocked footprint counts as the path when no further than this under the tread
Pets.Hop=.25           -- seconds a step on the flight (one hop per step of the data's steps run) ...
Pets.HopFast=.2        -- ... and the quickest, when the pet hurries after its owner
Pets.HopHeight=.35     -- the hop's arc over the chord
Pets.RayAbove=6        -- a ground ray on the path starts at most this far over the tread (rock overhangs; the den fix)
Pets.RouteFar=18       -- catch-up: more than this many route studs behind ...
Pets.RouteBehind=5     -- ... or this many seconds behind while on the route
Pets.LandBehind=4      -- the landing: this far behind the owner along the path
-- The pet-blocked footprints (TierHost.footprints) grow the path by Tier.Grow; GardenWalkability adds .35. A point inside
-- one is on the path for routing (architect B1: the lawn planner has no way out of a footprint).
Pets.BlockGrow=Tier.Grow+.35+.5

local ZERO=Vector3.zero
local injected=nil
-- Specs pass env = {flags, place, studio, on}; the game passes nothing.
function Pets.ceiling(env)
	env=env or injected or {}
	if(env.flags or Flags).TierPets~=true then return false end
	return Tier.ceiling(env)
end
-- Pure: a switch value. Anything but a boolean (missing, malformed) is the shipped default, on.
function Pets.resolve(configValue,override,ceiling)
	if ceiling==nil then ceiling=Pets.ceiling()end
	if not ceiling then return false end
	if type(override)=="boolean"then return override end
	if type(configValue)=="boolean"then return configValue end
	return true
end
local switch=false
function Pets.setSwitch(value)
	if not RunService:IsServer()then return false end
	switch=value==true
	return true
end
-- The switch alone (the server's gate also needs TierHost.open and the catch-up switch).
function Pets.on()
	if injected then return injected.on~=false and Pets.ceiling(injected)end
	if not Pets.ceiling()then return false end
	return switch
end
function Pets.inject(env)
	if not RunService:IsStudio()then return false end
	injected=if type(env)=="table"then table.clone(env)else nil
	return true
end

-- Geometry ---------------------------------------------------------------------------------------------------------
local function flat(v)return Vector3.new(v.X,0,v.Z)end
local function lastU(p)return p.u[#p.u]end
-- The u where the first pet-blocked footprint starts (TierHost.footprints' walk).
local blockCache=setmetatable({},{__mode="k"})
function Pets.blockStart(p)
	p=p or Tier.path()
	if not p then return math.huge end
	if blockCache[p]then return blockCache[p]end
	local pts,n=p.points,#p.points
	local i,start=1,math.huge
	while i<n do
		local j=math.min(i+Tier.PathBlock,n)
		if math.max(pts[i].Y,pts[j].Y)>=Tier.FootY+Tier.PathLift then start=p.u[i];break end
		i=j
	end
	blockCache[p]=start
	return start
end
-- The nearest centre-line segment in plan: {i, t, u, dist, lateral (signed, + to the left of travel), half, tread, at}.
function Pets.project(pos,p)
	p=p or Tier.path()
	if not p or typeof(pos)~="Vector3"or pos.X~=pos.X or pos.Z~=pos.Z then return nil end
	local pts=p.points
	local best
	for i=1,#pts-1 do
		local a,b=pts[i],pts[i+1]
		local dx,dz=b.X-a.X,b.Z-a.Z
		local len2=dx*dx+dz*dz
		local t=if len2>0 then math.clamp(((pos.X-a.X)*dx+(pos.Z-a.Z)*dz)/len2,0,1)else 0
		local ex,ez=pos.X-a.X-dx*t,pos.Z-a.Z-dz*t
		local dist=math.sqrt(ex*ex+ez*ez)
		if not best or dist<best.dist then
			local cross=dx*ez-dz*ex -- + when the point is to the left of a -> b, seen from above (x right, z down the page)
			best={i=i,t=t,dist=dist,lateral=if cross<0 then dist else -dist,len2=len2}
		end
	end
	if not best then return nil end
	local i,t=best.i,best.t
	local a,b=pts[i],pts[i+1]
	best.u=p.u[i]+(p.u[i+1]-p.u[i])*t
	best.half=(p.widths[i]+(p.widths[i+1]-p.widths[i])*t)/2
	best.tread=a.Y+(b.Y-a.Y)*t
	best.at=a:Lerp(b,t)
	return best
end
-- The lane's point at arc length u, `lateral` studs to the side (the project() sign), at tread height + Sole.
function Pets.pointAt(u,lateral,p)
	p=p or Tier.path()
	local pts,us=p.points,p.u
	u=math.clamp(u,0,lastU(p))
	local i=1
	while i<#pts-1 and us[i+1]<u do i+=1 end
	local a,b=pts[i],pts[i+1]
	local span=us[i+1]-us[i]
	local t=if span>0 then math.clamp((u-us[i])/span,0,1)else 0
	local at=a:Lerp(b,t)
	local d=Vector3.new(b.X-a.X,0,b.Z-a.Z)
	if lateral and lateral~=0 and d.Magnitude>1e-6 then
		d=d.Unit
		-- project()'s lateral is + on the side where (dx*ez - dz*ex) < 0, i.e. e = (dz, -dx) direction.
		at+=Vector3.new(d.Z,0,-d.X)*lateral
	end
	return Vector3.new(at.X,at.Y+Pets.Sole,at.Z)
end
-- The flight(s): runs of consecutive steps points, as {i0, i1, u0, u1}.
local flightCache=setmetatable({},{__mode="k"})
function Pets.flights(p)
	p=p or Tier.path()
	if not p then return {}end
	if flightCache[p]then return flightCache[p]end
	local out,start={},nil
	local n=#p.points
	for i=1,n do
		local on=p.steps[i]==true
		if on and not start then start=i end
		if start and(not on or i==n)then
			local last=if on then i else i-1
			if last>start then table.insert(out,table.freeze({i0=start,i1=last,u0=p.u[start],u1=p.u[last]}))end
			start=nil
		end
	end
	flightCache[p]=table.freeze(out)
	return flightCache[p]
end
function Pets.onFlight(u,p)
	for _,f in ipairs(Pets.flights(p))do if u>f.u0+1e-6 and u<f.u1-1e-6 then return f end end
	return nil
end
local function terrace(x,z,keep)
	local s,t=Tier.local2(nil,x,z)
	return math.abs(s)<=Tier.Length/2-keep and math.abs(t)<=Tier.Width/2-keep
end
-- Pet floor on the terrace: its plan less Keep.
function Pets.terraceSafe(x,z)
	if type(x)~="number"or type(z)~="number"or x~=x or z~=z then return false end
	return terrace(x,z,Pets.Keep)
end

-- Which floor a point stands on. The terrace needs its height (a sliver of the den lies under its plan).
function Pets.zone(pos,p)
	if typeof(pos)~="Vector3"or pos.X~=pos.X or pos.Y~=pos.Y or pos.Z~=pos.Z then return "lawn"end
	if pos.Y>Tier.RegionY and Tier.inPiece(Tier.Pieces[1],pos.X,pos.Z,0)then return "terrace"end
	p=p or Tier.path()
	if not p then return "lawn"end
	local box=p.box
	local reach=4+Pets.BlockGrow
	if pos.X<box.min.X-reach or pos.X>box.max.X+reach or pos.Z<box.min.Y-reach or pos.Z>box.max.Y+reach then return "lawn"end
	local hit=Pets.project(pos,p)
	if not hit then return "lawn"end
	if hit.tread>=Tier.FootY+Tier.PathLift and hit.dist<=hit.half and pos.Y>=hit.tread-Pets.Below and pos.Y<=hit.tread+Pets.Above then
		return "path"
	end
	-- Inside a pet-blocked footprint, low on the path: routing treats it as the path (architect B1).
	if hit.u>=Pets.blockStart(p)-Pets.BlockGrow and hit.dist<=hit.half+Pets.BlockGrow
		and pos.Y>=hit.tread-Pets.LowBelow and pos.Y<=hit.tread+Pets.Above then return "path"end
	return "lawn"
end
function Pets.up(pos,p)return Pets.zone(pos,p)~="lawn"end

-- A point snapped into the lane (path) or the terrace less Keep, at its floor; nil on the lawn. zoneHint: the owner's
-- zone (an offset point beside the owner may fall off the tread: it still belongs to the owner's floor).
function Pets.snap(pos,zoneHint,p)
	p=p or Tier.path()
	local zone=zoneHint or Pets.zone(pos,p)
	if zone=="terrace"then
		local s,t=Tier.local2(nil,pos.X,pos.Z)
		-- A hair inside, so terraceSafe agrees after the round trip through world studs.
		local hs,ht=Tier.Length/2-Pets.Keep-.01,Tier.Width/2-Pets.Keep-.01
		s=math.clamp(s,-hs,hs)
		t=math.clamp(t,-ht,ht)
		return Tier.T(s,t,Tier.FloorY+Pets.Sole)
	elseif zone=="path"and p then
		local hit=Pets.project(pos,p)
		if not hit then return nil end
		return Pets.pointAt(hit.u,math.clamp(hit.lateral,-Pets.Lane,Pets.Lane),p)
	end
	return nil
end
-- The owner's follow point: `offset` (behind and beside the root, as petAnchor works it out) on the owner's floor.
function Pets.anchor(root,offset,p)
	local zone=Pets.zone(root,p)
	if zone=="lawn"then return nil end
	return Pets.snap(offset,zone,p)
end
-- Where a ground ray over `pos` may start: at most RayAbove over the tread on the path, `top` elsewhere.
function Pets.rayTop(pos,top,p)
	if Pets.zone(pos,p)~="path"then return top end
	local hit=Pets.project(pos,p)
	return if hit then math.min(top,hit.tread+Pets.RayAbove)else top
end

-- Where a zone joins the path: the lawn at the foot (u 0), the terrace at the arrival (the last point).
local function along(pos,zone,p)
	if zone=="lawn"then return 0 end
	if zone=="terrace"then return lastU(p)end
	return Pets.project(pos,p).u
end
-- Route studs between two points (the catch-up gap): along the centre line between their u, plus the chords from each
-- end to the line. nil when no route is needed.
function Pets.routeDistance(a,b,p)
	p=p or Tier.path()
	if not p then return nil end
	local za,zb=Pets.zone(a,p),Pets.zone(b,p)
	if za==zb and za~="path"then return nil end
	local function chord(pos,zone)
		local u=along(pos,zone,p)
		return u,(flat(pos)-flat(Pets.pointAt(u,0,p))).Magnitude
	end
	local ua,ca=chord(a,za)
	local ub,cb=chord(b,zb)
	return math.abs(ua-ub)+ca+cb
end
-- A catch-up landing (the anchor on the path): LandBehind studs behind the owner on the pet's side, on the centre line,
-- moved off the flight to its end on the pet's side. Past the arrival it is the terrace just inside the gap.
function Pets.landing(anchor,pet,p)
	p=p or Tier.path()
	if not p or Pets.zone(anchor,p)~="path"then return nil end
	local ua=Pets.project(anchor,p).u
	local zp=Pets.zone(pet,p)
	local up=if typeof(pet)=="Vector3"then along(pet,zp,p)else 0
	local dir=if up>ua then 1 else -1
	local u=ua+dir*Pets.LandBehind
	local f=Pets.onFlight(u,p)or Pets.onFlight(ua,p)
	if f then u=if dir>0 then f.u1 else f.u0-.3 end
	if u>=lastU(p)-1e-6 then
		local s=Tier.local2(nil,p.points[#p.points].X,p.points[#p.points].Z)
		return Tier.T(s,Tier.Width/2-Pets.Keep,Tier.FloorY+Pets.Sole)
	end
	return Pets.pointAt(math.max(u,0),0,p)
end

-- Rest spots up there: two on the terrace, one at the turn pocket (3.5 studs short of CliffDenData's path.turn).
-- {id, position}, never exclusive (no rest-path solid check: architect).
Pets.TerraceRests=table.freeze({{"tier_ne",-22,-12},{"tier_sw",24,6}})
Pets.TurnRestShort=3.5
local restCache=setmetatable({},{__mode="k"})
function Pets.turnU(p,data)
	p=p or Tier.path()
	local turn=nil
	pcall(function()
		local d=data or require(script.Parent:FindFirstChild("CliffDenData"))
		local t=d and d.path and d.path.turn
		if type(t)=="table"and type(t[1])=="number"then turn=Vector3.new(t[1],t[2],t[3])end
	end)
	if not turn or not p then return nil end
	return Pets.project(turn,p).u
end
function Pets.rests(p)
	p=p or Tier.path()
	if not p then return {}end
	if restCache[p]then return restCache[p]end
	local out={}
	for _,r in ipairs(Pets.TerraceRests)do
		table.insert(out,table.freeze({id=r[1],position=Tier.T(r[2],r[3],Tier.FloorY+Pets.Sole)}))
	end
	local u=Pets.turnU(p)
	if u then table.insert(out,table.freeze({id="tier_turn",position=Pets.pointAt(u-Pets.TurnRestShort,0,p)}))end
	restCache[p]=table.freeze(out)
	return restCache[p]
end
function Pets.restAt(pos,p)
	if typeof(pos)~="Vector3"then return false end
	for _,r in ipairs(Pets.rests(p))do
		local q=r.position
		if Vector2.new(q.X-pos.X,q.Z-pos.Z).Magnitude<=.15 and math.abs(q.Y-pos.Y)<=.5 then return true end
	end
	return false
end
-- Wander, focus and rest targets: the terrace less Keep; on the path only a rest spot; the lawn is not ours (nil).
function Pets.targetOk(pos,p)
	local zone=Pets.zone(pos,p)
	if zone=="lawn"then return nil end
	if zone=="path"then return Pets.restAt(pos,p)end
	return Pets.terraceSafe(pos.X,pos.Z)
end

-- Planning ---------------------------------------------------------------------------------------------------------
local function heading(v,yaw)
	if Vector2.new(v.X,v.Z).Magnitude>1e-4 then return math.atan2(v.X,v.Z)end
	return yaw
end
-- A hand-built leg in GardenActivity's shape (legSample reads from, to, v0, v1, duration, yaw, turnDuration).
local function leg(from,to,v0,v1,duration,yaw)
	return{from=Activity.pack(from),to=Activity.pack(to),v0=Activity.pack(v0),v1=Activity.pack(v1),duration=duration,
		yaw=yaw,turn=0,turnDuration=.12}
end
-- The garden's follow pace for a separation (GardenState.transition's rule, without the owner's look-ahead).
function Pets.followSpeed(separation)
	if separation>16 then return Layout.CatchupSpeed+math.clamp((separation-16)/14,0,1)*(Layout.LeashSpeed-Layout.CatchupSpeed)end
	return Layout.WalkSpeed+math.clamp((separation-4)/8,0,1)*(Layout.CatchupSpeed-Layout.WalkSpeed)
end
-- The zone for planning: zone(), and a point standing on the tread low by the foot (before it has left the lawn) is the
-- path too, so a replan there walks on along the line instead of back to the foot (code review 4).
function Pets.planZone(pos,p)
	local zone=Pets.zone(pos,p)
	if zone~="lawn"then return zone end
	local hit=Pets.project(pos,p)
	if hit and hit.u>.5 and hit.u<lastU(p)-.5 and hit.dist<=hit.half and math.abs(pos.Y-hit.tread-Pets.Sole)<=.3 then return "path"end
	return zone
end
-- The legs between two zones, or nil when the normal planner should do it (both on the lawn, both on the terrace).
-- lawnPlan(from, to, velocity, speed, minimum, yaw, via, terminal): the garden's own planner (with the scene's wet list)
-- for the lawn end; the terrace end is a straight run (no water up there). Each replan starts from the sampled state
-- (architect B3): only the flat velocity along the first move is kept, a mid-hop start drops straight to its step.
-- `minimum` is GardenState's: a rest in place on the path keeps its length (code review 3), and no route is shorter.
function Pets.plan(from,to,velocity,speed,minimum,yaw,lawnPlan,p)
	p=p or Tier.path()
	if not p then return nil end
	local zf,zt=Pets.planZone(from,p),Pets.planZone(to,p)
	if zf==zt and zf~="path"then return nil end
	minimum=minimum or 0
	-- Nowhere to go (a rest, a pause in place): the garden's own curve, with its length.
	if(to-from).Magnitude<.05 then return Activity.plan(from,to,velocity,math.max(speed or 4,1),minimum,yaw or 0,nil,ZERO)end
	speed=math.max(speed or 4,1)
	-- The caller's pace is from the straight separation; along the path (the hairpin at the turn) it is the route's.
	-- Only ever faster, never past the leash pace.
	local route=Pets.routeDistance(from,to,p)
	if route then speed=math.min(Layout.LeashSpeed,math.max(speed,Pets.followSpeed(route)))end
	velocity=if typeof(velocity)=="Vector3"then Vector3.new(velocity.X,0,velocity.Z)else ZERO
	yaw=yaw or 0
	local path,total={},0
	local at,vel,face=from,velocity,yaw
	local function add(list,seconds)
		for _,entry in ipairs(list)do table.insert(path,entry)end
		total+=seconds or 0
		local last=list[#list]
		if last then
			local v1=Activity.vector(last.v1)or ZERO
			local delta=(Activity.vector(last.to)or at)-(Activity.vector(last.from)or at)
			face=heading(if v1.Magnitude>1e-3 then v1 else delta,face)
		end
	end
	-- One straight leg at `speed` (a cubic whose hull never passes it): 1.5 x the run's time from a stand to a stand,
	-- 1 x at full pace through both ends. v0 keeps only its part along the run.
	local function run(a,b,v0,v1)
		local d=b-a
		if d.Magnitude<1e-3 then return {},0 end
		local along=if v0.Magnitude>1e-3 then math.clamp(v0:Dot(d.Unit),0,speed)else 0
		v0=d.Unit*along
		local seconds=math.max(.1,d.Magnitude/speed*(1+.25*(2-along/speed-math.min(v1.Magnitude,speed)/speed)))
		return {leg(a,b,v0,v1,seconds,heading(d,face))},seconds
	end
	local function stopped(list)
		local last=list and list[#list]
		if not last then return true end
		for _,entry in ipairs(list)do if entry.safetyStop then return true end end
		return false
	end
	-- 1. Onto the centre line.
	local u0,lat0
	if zf=="lawn"then
		local foot=Pets.pointAt(0,0,p)
		local legs,seconds=lawnPlan(from,foot,velocity,speed,0,yaw,nil,ZERO)
		if stopped(legs)or(Activity.vector(legs[#legs].to)-foot).Magnitude>=.1 then return legs,seconds end
		add(legs,seconds);at,vel,u0,lat0=foot,ZERO,0,0
	elseif zf=="terrace"then
		-- The terrace is flat and open: one run to the arrival (the flight's first hop starts from a stand).
		local arrival=Pets.pointAt(lastU(p),0,p)
		add(run(from,arrival,velocity,ZERO))
		at,vel,u0,lat0=arrival,ZERO,lastU(p),0
	else
		local hit=Pets.project(from,p)
		u0,lat0=hit.u,math.clamp(hit.lateral,-Pets.Lane,Pets.Lane)
	end
	-- 2. Along the line to the end's u.
	local u1,lat1
	if zt=="lawn"then u1,lat1=0,0
	elseif zt=="terrace"then u1,lat1=lastU(p),0
	else local hit=Pets.project(to,p);u1,lat1=hit.u,math.clamp(hit.lateral,-Pets.Lane,Pets.Lane)end
	local dir=if u1>=u0 then 1 else -1
	-- Waypoints: every vertex strictly between, then the end. Each knows whether its step is a hop.
	local marks={}
	local us=p.u
	if dir>0 then for i=1,#us do if us[i]>u0+1e-3 and us[i]<u1-1e-3 then table.insert(marks,{u=us[i],i=i})end end
	else for i=#us,1,-1 do if us[i]<u0-1e-3 and us[i]>u1+1e-3 then table.insert(marks,{u=us[i],i=i})end end end
	table.insert(marks,{u=u1})
	local span=math.abs(u1-u0)
	local points={}
	for k,m in ipairs(marks)do
		local w=if span>1e-6 then math.abs(m.u-u0)/span else 1
		local lateral=lat0+(lat1-lat0)*w
		local point=if k==#marks and zt=="path"then Pets.snap(to,"path",p)else Pets.pointAt(m.u,lateral,p)
		points[k]={at=point,u=m.u}
	end
	-- A step is a hop when both its ends lie in one flight.
	local function hop(ua,ub)
		for _,f in ipairs(Pets.flights(p))do
			if math.min(ua,ub)>=f.u0-1e-3 and math.max(ua,ub)<=f.u1+1e-3 then return true end
		end
		return false
	end
	-- The first move: a pet in the air (sampled mid-hop) drops straight to its step and lands (no lift, no speed). A pet
	-- a little off the lane (a replan from between two vertices) walks on from where it is, keeping its pace.
	local onLine=Pets.pointAt(u0,lat0,p)
	local airborne=at.Y-onLine.Y>.3
	if airborne or (at-onLine).Magnitude>.3 then
		local d=onLine-at
		local seconds=math.max(.1,d.Magnitude/speed)
		local level=flat(d)
		local v=if vel.Magnitude>1e-3 and level.Magnitude>1e-3 then level.Unit*math.min(vel:Dot(level.Unit),speed)else ZERO
		if v:Dot(d)<0 then v=ZERO end
		local v1=if airborne then ZERO else v
		add({leg(at,onLine,v,v1,seconds,heading(d,face))},seconds)
		at,vel=onLine,v1
	end
	-- The walk: velocity-continuous through each vertex (the tangent through its neighbours at `speed`), stopping at the
	-- end; a hop step is a .25 s arc (its v0 / v1 carry +/- the vertical that lifts the curve HopHeight over the chord).
	local prev=at
	local prevU=u0
	for k,point in ipairs(points)do
		local target=point.at
		local d=target-prev
		if d.Magnitude<1e-3 then prevU=point.u;continue end
		if hop(prevU,point.u)then
			-- .25 s a step, down to HopFast when the pet hurries after its owner.
			local seconds=math.clamp(d.Magnitude/speed,Pets.HopFast,Pets.Hop)
			local lift=4*Pets.HopHeight/seconds
			local v=d/seconds
			local step=leg(prev,target,v+Vector3.new(0,lift,0),v-Vector3.new(0,lift,0),seconds,heading(d,face))
			step.hop=true -- read by the specs and the Studio probe only; clients sample it like any leg
			add({step},seconds)
			vel=ZERO
		else
			local seconds=math.max(.05,d.Magnitude/speed)
			local nextPoint=points[k+1]
			local v1=ZERO
			if nextPoint and not hop(point.u,nextPoint.u)then
				local through=nextPoint.at-prev
				if through.Magnitude>1e-3 then v1=through.Unit*speed end
			end
			local v0=vel
			if v0.Magnitude>1e-3 then
				local along=v0:Dot(d.Unit)
				v0=if along>0 then d.Unit*math.min(along,speed)else ZERO
			end
			add({leg(prev,target,v0,v1,seconds,heading(d,face))},seconds)
			vel=v1
		end
		prev,prevU=target,point.u
	end
	at=prev
	-- 3. Off the line at the far end.
	if zt=="lawn"then
		local legs,seconds=lawnPlan(at,to,ZERO,speed,0,face,nil,ZERO)
		add(legs,seconds)
	elseif zt=="terrace"then
		add(run(at,to,vel,ZERO))
	end
	if #path==0 then return Activity.plan(from,to,ZERO,speed,math.max(minimum,.25),yaw,nil,ZERO)end
	-- Never shorter than asked: hold at the end for what is left.
	if total<minimum then
		local last=Activity.vector(path[#path].to)or to
		add({leg(last,last,ZERO,ZERO,minimum-total,face)},minimum-total)
	end
	return path,total
end

return table.freeze(Pets)
