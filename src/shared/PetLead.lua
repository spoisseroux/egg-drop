-- The Bear leads you to the nest (artifacts/qa-2026-11-27-beta37/ONBOARDING-V3-BRIEF.md section 1, switch Onboard
-- "lead"; Spencer's beta 37 note 5: "should it run towards the egg like beckoning us to follow it? with edge case
-- handling like if the player doesnt follow etc so no one gets soft blocked"). Shared and pure, spec-checked offline
-- (scripts/PetLead.spec.lua). The server (GardenState:lead) owns where the pet is, so every player sees it lead; the
-- client (NestLead) owns the words, the nudges and the park. Nothing here touches the game.
--
--   start   the Bear chirps and hops once as it turns to the nest: it runs within 0.6 s     (server action "leadStart")
--   run     18 studs a second along the player's trail route (never a straight line through fences)   ("leadRun")
--           (onboarding fun pass, qa-2026-11-27-beta37/ONBOARDING-FUN-PASS.md section 1: a chase, faster than the
--           player's 16, so they chase it instead of passing it; was 14, two hops and a 2 s rest after the pet)
--   wait    22 studs ahead of the player it arcs round (never a stop and a pivot), faces them and beckons every 2.5 s
--           ("leadWait"); it arcs back and runs on once the player is within 14 studs, has passed it, or comes on
--           faster than 4 studs a second (beta 40; was 12 and 7)
--   pace    a player who keeps following never makes it stop: it trots on at 15 looking back over its shoulder
--           ("leadPace") until they are within 14 again, then runs
--   back    a nudge: it runs back along its route to about 5 studs from the player  ("leadBack")
--   arrive  3 studs short of the nest it stops, faces the nest and bounces           ("leadArrive")
--   cheer   the tuck (and the all-set card): a jump and one spin                      ("leadCheer")
local Lead={}

-- ── Numbers ──────────────────────────────────────────────────────────────────────────────────────────────────────────
Lead.Run=18            -- studs a second (the player walks 16: a chase; was 14)
-- Beta (40), Spencer: "the distance it runs before turning around is too short, and it takes too long to turn back
-- around and run again, needs to be smoother".
Lead.Ahead=22          -- this far ahead of the player (and nearer the nest than them) it looks back (was 12)
Lead.Resume=14         -- the player this close: it runs on (was 7)
Lead.Closing=4         -- the player coming on faster than this (studs a second, toward the pet) is following: a waiting
                       -- pet runs on at once, and a running one never stops: it trots at Pace and looks back
Lead.Pace=15           -- studs a second while it looks back at a following player (a touch under their 16: they close)
Lead.AheadMax=27       -- even a followed pet waits this far ahead (under Far, so a follow is never a nudge)
Lead.Arc=table.freeze({keep=.4,radius=1.5,time=.35,slow=.25,stop=.25,min=2,leg=.25}) -- the turn: keep 40% of the
                       -- speed, curve through at most `radius` studs in about `time` s (after `slow` s easing down to
                       -- it), then stop in `stop` s facing the player; from rest the same arc the other way, then the
                       -- run. Under `min` studs a second it pivots on the spot as before. `leg`: the shortest cubic a
                       -- garden walk has (GardenActivity.leg's floor), so a gentle turn swings wider rather than faster.
Lead.LookBack=table.freeze({yaw=.9,every=2.5,time=.9}) -- the trot's look over the shoulder (head yaw, radians)
Lead.Body=.8           -- studs: the leading pet's half-width (its route keeps this clear of every keep-out circle)
Lead.Detour=.35        -- studs past that a route point is pushed round a keep-out
Lead.MaxDetours=40     -- points a route may gain going round things
Lead.Arrive=3          -- it stops this far short of the nest's prompt, along the route
Lead.Reach=8           -- the player this close to the nest's prompt: prompt 2a is done (2b shows on the nest)
Lead.Rest=2            -- s between two prompts (was 4)
Lead.AfterPet=table.freeze({rest=0,free=.1}) -- the first pet's close: no rest, and the lead asks once the garden is free
                       -- this long (BearNeeds' usual Return is 2.5 s): the Bear runs out of the petting screen
Lead.Return=2.5        -- s free after a pause (the deck, a menu, leaving the garden) before it leads again
Lead.Toast=3           -- s, the post-tuck toast
Lead.Hops=table.freeze({count=1,height=.6,time=.35})          -- the start: one hop, while it turns (was two, then the turn)
Lead.Beckon=table.freeze({every=2.5,height=.6,time=.35,wave=.5}) -- the look back: a hop, a paw wave, a chirp
Lead.Bounce=table.freeze({height=.35,time=.4,every=.9})       -- arrived: a bounce on the spot
Lead.Cheer=table.freeze({time=.6,height=.9,hold=.8})          -- the jump-spin (tucked, all set)
-- The nudges and the park (client, Lead.watch).
Lead.Still=6           -- s the player stands still: a nudge (was 8)
Lead.StillSpeed=1      -- studs a second under this is standing still
Lead.Far=30            -- the player this far from the Bear (the other way): a nudge, counted
Lead.Back=5            -- a nudge brings the Bear back to about this far from the player
Lead.Near=12           -- no route point this close to the player: the Bear poofs to them instead
Lead.ThisWay=2         -- s "This way!" replaces the headline
Lead.Nudges=3          -- nudges ignored: the next one parks the lead
Lead.Cool=3            -- s after a nudge before another can come
Lead.Progress=6        -- studs nearer the nest since the last nudge: it was not ignored, the count starts over
Lead.Chip=36           -- px, the parked moon chip
-- The server.
Lead.StuckMove=2;Lead.StuckTime=2 -- under 2 studs in 2 s while running: it poofs to the next route point
Lead.Hold=60           -- s a wait or an arrival rests before it is held again
Lead.MaxGap=45         -- the owner further than this from the pet: the lead ends (it follows)
Lead.Route=table.freeze({max=80,step=24,length=320,startNear=8,goalNear=12,ground=3,body=1.4})
Lead.Asks=table.freeze({gap=.75,starts=60})
Lead.Restart=table.freeze({wait=1.5,backoff=2,max=10,tries=3}) -- client: a start the server never took

local function finite(n)return type(n)=="number"and n==n and math.abs(n)<1e6 end
local function vec(v)return typeof(v)=="Vector3"and finite(v.X)and finite(v.Y)and finite(v.Z)end
function Lead.flat(a,b)return Vector2.new(a.X-b.X,a.Z-b.Z).Magnitude end
local flat=Lead.flat
local function smooth(u)u=math.clamp(u,0,1);return u*u*(3-2*u)end

-- ── Routes ───────────────────────────────────────────────────────────────────────────────────────────────────────────
-- Pure: the route's flat length.
function Lead.length(points)
	local total=0
	for i=2,#points do total+=flat(points[i-1],points[i])end
	return total
end
-- Pure: the route cut `back` studs short of its end, along it (the Bear's goal is 3 studs before the nest's prompt).
-- A route shorter than that is its first point alone.
function Lead.trim(points,back)
	local n=#points
	if n==0 then return {}end
	local left=back
	for i=n,2,-1 do
		local a,b=points[i-1],points[i]
		local length=flat(a,b)
		if length>=left and length>1e-4 then
			local out=table.move(points,1,i-1,1,{})
			table.insert(out,b:Lerp(a,left/length))
			return out
		end
		left-=length
	end
	return {points[1]}
end
-- Pure: fewer corners. Keeps the first and the last, every point where the way turns more than `turn` radians, and
-- one at least every `gap` studs (pathfinding lays one every 4).
function Lead.simplify(points,turn,gap)
	turn=turn or math.rad(15);gap=gap or 12
	local n=#points
	if n<=2 then return table.clone(points)end
	local out={points[1]}
	local since=0
	for i=2,n-1 do
		local a,b,c=out[#out],points[i],points[i+1]
		since+=flat(points[i-1],b)
		local u=Vector2.new(b.X-a.X,b.Z-a.Z);local v=Vector2.new(c.X-b.X,c.Z-b.Z)
		local bend=0
		if u.Magnitude>1e-3 and v.Magnitude>1e-3 then bend=math.acos(math.clamp(u.Unit:Dot(v.Unit),-1,1))end
		if bend>turn or since>=gap or math.abs(c.Y-a.Y)>1 then table.insert(out,b);since=0 end
	end
	table.insert(out,points[n])
	return out
end
-- Pure (the client, before it sends): the trail's route (pathfinding's points about 4 studs apart, a bridge's two ends
-- the span's length apart) made to fit the server's caps (Route.max points, Route.step studs a leg): the ends of every
-- long leg (a bridge) kept, fewer corners, then any leg over the step cut into even pieces. Coarser passes follow
-- until it fits; nil when even the coarsest does not (Route.length still refuses a route too long to lead along).
Lead.Fit=table.freeze({turn=math.rad(15),gap=12,long=8,rise=1,margin=1})
function Lead.fit(points)
	local R,F=Lead.Route,Lead.Fit
	if type(points)~="table"or #points<2 then return nil end
	for _,p in ipairs(points)do if not vec(p)then return nil end end
	local n=#points
	local keep={[1]=true,[n]=true}
	for i=2,n do if flat(points[i-1],points[i])>F.long then keep[i-1]=true;keep[i]=true end end
	local cap=R.step-F.margin
	local function pass(turn,gap,rise)
		local out={points[1]}
		local since=0
		for i=2,n-1 do
			local a,b,c=out[#out],points[i],points[i+1]
			since+=flat(points[i-1],b)
			local u=Vector2.new(b.X-a.X,b.Z-a.Z);local v=Vector2.new(c.X-b.X,c.Z-b.Z)
			local bend=0
			if u.Magnitude>1e-3 and v.Magnitude>1e-3 then bend=math.acos(math.clamp(u.Unit:Dot(v.Unit),-1,1))end
			if keep[i]or bend>turn or since>=gap or math.abs(c.Y-a.Y)>rise then table.insert(out,b);since=0 end
		end
		table.insert(out,points[n])
		local spaced={out[1]}
		for i=2,#out do
			local a,b=out[i-1],out[i]
			local parts=math.max(1,math.ceil(flat(a,b)/cap))
			for k=1,parts-1 do table.insert(spaced,a:Lerp(b,k/parts))end
			table.insert(spaced,b)
		end
		return spaced
	end
	for _,try in ipairs({{F.turn,F.gap,F.rise},{F.turn*2,F.gap*1.5,F.rise*2},{F.turn*3,cap,R.ground},{math.pi,cap,math.huge}})do
		local out=pass(try[1],try[2],try[3])
		if #out<=R.max then return out end
	end
	return nil
end
-- ── Round the things the navmesh cannot see (beta 40) ───────────────────────────────────────────────────────────────
local function circle(entry)return entry.x or entry.X,entry.z or entry.Z,entry.r or entry.R end
-- Pure: the first keep-out (GardenKeepOut's {x, z, r} or {X, Z, R} records) the leg a-b passes within r + grow of, or
-- nil. A circle the leg's start stands in is not counted when `fromInside` (the pet may stand in a bush: it walks out),
-- nor one its end stands in when `toInside` (the route's last point: the nest's prompt is where it must go).
function Lead.blocker(a,b,list,grow,fromInside,toInside)
	local KeepOut=require(script.Parent.GardenKeepOut)
	for _,entry in ipairs(list or {})do
		local x,z,r=circle(entry)
		if type(x)=="number"and type(z)=="number"and type(r)=="number"then
			local reach=r+(grow or 0)
			local inside=Vector2.new(a.X-x,a.Z-z).Magnitude<reach
			local ends=Vector2.new(b.X-x,b.Z-z).Magnitude<reach
			if not(fromInside and inside)and not(toInside and ends)and KeepOut.toSegment(x,z,a.X,a.Z,b.X,b.Z)<reach then return entry end
		end
	end
	return nil
end
-- Pure (the client, after Lead.fit): the route pushed round every keep-out circle it passes within Body of. Each leg
-- that hits one gains a point beside the circle (r + Body + Detour out from its centre, square to the leg, on the side
-- the leg passes; the other side if that one is in another circle or `ok(a, b)` refuses it: water). A route point
-- standing in one is moved straight out of it first. The first leg may start inside one (the pet stands in a bush),
-- the last may end in one (the nest's prompt). Returns the new points, or nil when a leg cannot be cleared or the route
-- grows past MaxDetours or Route.max points (the caller keeps today's route and the server decides).
function Lead.around(points,list,ok)
	if type(points)~="table"or #points<2 then return nil end
	if type(list)~="table"or #list==0 then return table.clone(points)end
	local n=#points
	local moved=table.clone(points)
	for i=2,n-1 do
		local p=moved[i]
		for _=1,4 do
			local hit=Lead.blocker(p,p,list,Lead.Body,false)
			if not hit then break end
			local x,z,r=circle(hit)
			local away=Vector3.new(p.X-x,0,p.Z-z)
			if away.Magnitude<1e-3 then away=Vector3.new(1,0,0)end
			p=Vector3.new(x,p.Y,z)+away.Unit*(r+Lead.Body+Lead.Detour)
		end
		if Lead.blocker(p,p,list,Lead.Body,false)then return nil end
		moved[i]=p
	end
	local out={moved[1]}
	local added=0
	local queue=table.move(moved,2,n,1,{})
	local guard=0
	while #queue>0 do
		guard+=1
		if guard>Lead.Route.max*4 then return nil end
		local a,b=out[#out],queue[1]
		local first=#out==1
		local hit=Lead.blocker(a,b,list,Lead.Body,first,#queue==1)
		if not hit then
			table.insert(out,table.remove(queue,1))
		else
			local x,z,r=circle(hit)
			local centre=Vector3.new(x,0,z)
			local ab=Vector3.new(b.X-a.X,0,b.Z-a.Z)
			local along=if ab.Magnitude>1e-4 then ab.Unit else Vector3.new(1,0,0)
			local t=math.clamp((centre-Vector3.new(a.X,0,a.Z)):Dot(along)/math.max(ab.Magnitude,1e-4),0,1)
			local closest=Vector3.new(a.X,0,a.Z)+ab*t
			local away=closest-centre
			local side=Vector3.new(-along.Z,0,along.X)
			if away.Magnitude>1e-3 then side=if away:Dot(side)>=0 then side else -side end
			local reach=r+Lead.Body+Lead.Detour
			local y=a.Y+(b.Y-a.Y)*t
			local chosen=nil
			for _,s in ipairs({side,-side})do
				local p=Vector3.new(x+s.X*reach,y,z+s.Z*reach)
				local clear=Lead.blocker(p,p,list,Lead.Body,false)==nil
				if clear and(ok==nil or(ok(a,p)and ok(p,b)))then chosen=p;break end
			end
			if not chosen then return nil end
			added+=1
			if added>Lead.MaxDetours then return nil end
			table.insert(queue,1,chosen)
		end
	end
	if #out>Lead.Route.max then return nil end
	-- a detour never makes a leg longer than the server's step (each new leg is shorter than the one it splits, but a
	-- point pushed out can lengthen one past it): cut any long one in even pieces, checked again
	local spaced={out[1]}
	for k=2,#out do
		local a,b=out[k-1],out[k]
		local parts=math.max(1,math.ceil(flat(a,b)/(Lead.Route.step-Lead.Fit.margin)))
		for m=1,parts-1 do table.insert(spaced,a:Lerp(b,m/parts))end
		table.insert(spaced,b)
	end
	if #spaced>Lead.Route.max then return nil end
	return spaced
end
-- Pure (the server's check of the client's route). raw: the route the client sent (Vector3s from the pet to the nest's
-- prompt). ctx: {pet (the pet's position now), nest (where the nest stands), ground(point) -> y or nil, clear(a, b) ->
-- true when nothing solid stands between the two at the pet's body height, keepOut (optional: GardenKeepOut.lead's
-- circles; beta 40: no leg within Body of one, the first leg may start inside one and the last end in one)}. Returns
-- the grounded points, or
-- nil and why.
function Lead.clean(raw,ctx)
	local R=Lead.Route
	if type(raw)~="table"or #raw<2 or #raw>R.max then return nil,"count"end
	if not vec(ctx.pet)or not vec(ctx.nest)then return nil,"context"end
	local out={}
	for i=1,#raw do
		local p=raw[i]
		if not vec(p)then return nil,"point"end
		local y=ctx.ground(p)
		if type(y)~="number"or y~=y or math.abs(y-p.Y)>R.ground then return nil,"ground"end
		out[i]=Vector3.new(p.X,y+.025,p.Z)
	end
	if flat(out[1],ctx.pet)>R.startNear then return nil,"start"end
	if flat(out[#out],ctx.nest)>R.goalNear then return nil,"goal"end
	local total=0
	for i=2,#out do
		local step=flat(out[i-1],out[i])
		if step>R.step then return nil,"step"end
		total+=step
		if not ctx.clear(out[i-1],out[i])then return nil,"blocked"end
		if ctx.keepOut and Lead.blocker(out[i-1],out[i],ctx.keepOut,Lead.Body,i==2,i==#out)then return nil,"keepout"end
	end
	if total>R.length then return nil,"length"end
	return out
end
-- Pure: where along the route `at` is: the distance along it of its nearest point, and the index of the first route
-- point still ahead of it.
function Lead.progress(points,at)
	local n=#points
	if n==0 then return 0,1 end
	if n==1 then return 0,if flat(points[1],at)<.5 then 2 else 1 end
	local best,bestAlong,bestNext=math.huge,0,1
	local walked=0
	for i=2,n do
		local a,b=points[i-1],points[i]
		local ab=Vector2.new(b.X-a.X,b.Z-a.Z)
		local length=ab.Magnitude
		local u=0
		if length>1e-4 then u=math.clamp(Vector2.new(at.X-a.X,at.Z-a.Z):Dot(ab)/(length*length),0,1)end
		local p=a:Lerp(b,u)
		local d=flat(p,at)
		if d<best-1e-6 then best,bestAlong,bestNext=d,walked+length*u,if u>=.999 then i+1 else i end
		walked+=length
	end
	return bestAlong,bestNext
end
-- Pure: the route points still ahead of `at` (the goal last). Always at least the goal.
function Lead.ahead(points,at,goal)
	local _,next=Lead.progress(points,at)
	local out={}
	for i=next,#points do
		if flat(points[i],at)>.5 then table.insert(out,points[i])end
	end
	if #out==0 or flat(out[#out],goal)>.05 then table.insert(out,goal)end
	return out
end
-- Pure: a nudge's way back. The route points behind the Bear, nearest it first, ending at the one nearest Back studs
-- from the player (never nearer). nil when none of them is within Near studs of the player (it poofs to them).
function Lead.backWay(points,at,owner)
	local _,next=Lead.progress(points,at)
	local best,bestScore=nil,math.huge
	for i=math.min(next-1,#points),1,-1 do
		local d=flat(points[i],owner)
		if d<=Lead.Near then
			local score=math.abs(d-Lead.Back)+(if d<Lead.Back-1 then 4 else 0)
			if score<bestScore then best,bestScore=i,score end
		end
	end
	if not best then return nil end
	local out={}
	for i=math.min(next-1,#points),best,-1 do
		if flat(points[i],at)>.5 then table.insert(out,points[i])end
	end
	if #out==0 then table.insert(out,points[best])end
	return out
end

-- ── The server's state machine ───────────────────────────────────────────────────────────────────────────────────────
-- Pure: what the leading pet does next. lead: {phase, stuckAt, stuckFrom}; ctx: {now, pet, owner, goal, moving (its
-- walk is still under way), closing (beta 40: how fast the owner comes toward the pet, studs a second; nil 0)}.
-- Returns "run", "pace" (run on at Pace, looking back: the owner follows), "wait", "arrive", "poof" or nil (go on).
--   run   at Ahead studs ahead (and the owner not past it): "pace" while the owner follows (closing at least Closing)
--         and the gap is under AheadMax, else "wait"
--   pace  the owner within Resume (or past it): "run"; at AheadMax, or the owner no longer following at Ahead: "wait"
--   wait  the owner within Resume (Back + 2 after a nudge brought it back), past it, or following (closing at least
--         Closing) under AheadMax: "run" at once
function Lead.decide(lead,ctx)
	local phase=lead.phase
	local pet,owner,goal,now=ctx.pet,ctx.owner,ctx.goal,ctx.now
	local atGoal=flat(pet,goal)<=.6
	if phase=="start"then return if ctx.moving then nil else "run"end
	if phase=="back"then return if ctx.moving then nil else "wait"end
	if phase=="arrive"then return nil end
	local gap=flat(pet,owner)
	local ownerPassed=flat(owner,goal)<=flat(pet,goal)
	local following=(tonumber(ctx.closing)or 0)>=Lead.Closing
	if phase=="wait"then
		if atGoal then return "arrive"end
		-- after a nudge's run back (lead.nudged) it waits for the player to come to it (Back + 2) or to follow, as before
		local resume=if lead.nudged then Lead.Back+2 else Lead.Resume
		if gap<=resume or ownerPassed or(following and gap<Lead.AheadMax)then return "run"end
		return nil
	end
	if phase=="run"or phase=="pace"then
		if atGoal or(not ctx.moving and flat(pet,goal)<=1.5)then return "arrive"end
		if phase=="run"and gap>=Lead.Ahead and not ownerPassed then
			return if following and gap<Lead.AheadMax then "pace"else "wait"
		end
		if phase=="pace"then
			if gap<=Lead.Resume or ownerPassed then return "run"end
			if gap>=Lead.AheadMax or(gap>=Lead.Ahead and not following)then return "wait"end
		end
		-- stuck: under StuckMove studs in StuckTime s while running
		if lead.stuckAt==nil or typeof(lead.stuckFrom)~="Vector3"then lead.stuckAt,lead.stuckFrom=now,pet;return nil end
		if now-lead.stuckAt>=Lead.StuckTime then
			local moved=flat(pet,lead.stuckFrom)
			lead.stuckAt,lead.stuckFrom=now,pet
			if moved<Lead.StuckMove then return "poof"end
		end
		return nil
	end
	return nil
end

-- ── The turn (beta 40: an arc, never a stop and a pivot) ─────────────────────────────────────────────────────────────
-- Pure: the arc's own numbers for a turn of `turn` radians (signed) at `speed` studs a second: the speed it keeps
-- through the curve, its radius (at most Arc.radius, smaller for a sharp turn so it still takes about Arc.time) and
-- its seconds. nil when it is too slow to arc (it pivots).
function Lead.arcFor(turn,speed)
	local A=Lead.Arc
	speed=tonumber(speed)or 0
	if speed<A.min then return nil end
	local keep=math.max(A.min,speed*A.keep)
	local sweep=math.abs(turn)
	if sweep<1e-3 then return keep,A.radius,0 end
	local radius=math.min(A.radius,keep*A.time/sweep)
	local seconds=math.max(A.leg,radius*sweep/keep)
	return keep,keep*seconds/sweep,seconds
end
-- Pure: a point and heading `along` radians into an arc of radius r from `from` heading `yaw`, turning toward the sign
-- of `turn` (yaw is atan2(x, z), as the garden's).
function Lead.arcPoint(from,yaw,turn,r,along)
	local k=if turn>=0 then 1 else -1
	local h=yaw+k*along
	return from+Vector3.new(r*k*(math.cos(yaw)-math.cos(h)),0,r*k*(math.sin(h)-math.sin(yaw))),h
end

-- ── Poses (every screen: GardenPetVisual through PetFollow.activity) ─────────────────────────────────────────────────
local function hop(t,height,time)
	if t<0 or t>=time then return 0 end
	return height*math.sin(t/time*math.pi)
end
-- Pure: the lift (studs) and the extra turn (radians) of a pet doing `action`, `age` s into it. Reduced Motion: none
-- (it walks and still looks back: the server turns it).
function Lead.pose(action,age,reduced)
	if reduced or type(age)~="number"or age<0 then return 0,0 end
	if action=="leadStart"then
		local H=Lead.Hops
		local lift=0
		for k=0,H.count-1 do lift=math.max(lift,hop(age-k*H.time,H.height,H.time))end
		return lift,0
	elseif action=="leadWait"then
		local B=Lead.Beckon
		return hop(age%B.every,B.height,B.time),0
	elseif action=="leadArrive"then
		local B=Lead.Bounce
		return hop(age%B.every,B.height,B.time),0
	elseif action=="leadCheer"then
		local C=Lead.Cheer
		if age>=C.time then return 0,0 end
		local u=age/C.time
		return C.height*math.sin(u*math.pi),math.pi*2*smooth(u)
	elseif action=="leadPace"then
		-- beta 40: no stop for a following player; a look back over the shoulder every LookBack.every s (the third
		-- value: 0..1 of LookBack.yaw, the caller picks the side the owner is on)
		local L=Lead.LookBack
		local t=age%L.every
		return 0,0,if t<L.time then math.sin(t/L.time*math.pi)^2 else 0
	end
	return 0,0
end
-- Pure: the head's turn (radians) for a look back of `look` (Lead.pose's third value) toward an owner at `rel` (the
-- owner in the pet's own frame, +Z forward): the side the owner is on, LookBack.yaw at the full look.
function Lead.lookYaw(look,rel)
	look=tonumber(look)or 0
	if look<=0 then return 0 end
	local side=if typeof(rel)=="Vector3"and rel.X<0 then -1 else 1
	return side*Lead.LookBack.yaw*math.clamp(look,0,1)
end
-- Pure: the start's hop (s); the server turns the pet to the nest during it (GardenState:lead), so the run starts after
-- the longer of the two.
function Lead.startHops()return Lead.Hops.count*Lead.Hops.time end
-- Pure: is a beckon due (the client's chirp, paw wave and bubble hop), `age` s into a wait, the last at `last`?
function Lead.beckonDue(age,last)
	if type(age)~="number"or age<0 then return false end
	local beat=math.floor(age/Lead.Beckon.every)
	return last==nil or beat>last,beat
end

-- ── The client's nudges and park ─────────────────────────────────────────────────────────────────────────────────────
function Lead.watcher()return {still=0,count=0,coolUntil=-math.huge}end
-- Pure: one look at the player while the Bear leads. ctx: {now, dt, active (it leads and nothing pauses it), speed (the
-- player's, studs a second), gap (player to the Bear), toNest (player to the nest's prompt)}. Returns "nudge" or "park"
-- (and why: "still" or "far"), or nil. A nudge the player then answers (they get Progress studs nearer the nest) is
-- not ignored: the count starts over. Nothing here ever closes the prompt: the player reaching the nest does.
function Lead.watch(w,ctx)
	if not ctx.active then w.still=0;return nil end
	local dt=math.max(0,ctx.dt or 0)
	if type(ctx.toNest)=="number"and w.mark~=nil and w.mark-ctx.toNest>=Lead.Progress then w.count,w.mark=0,nil end
	if(ctx.speed or 0)<Lead.StillSpeed then w.still+=dt else w.still=0 end
	if ctx.now<w.coolUntil then return nil end
	local why=if w.still>=Lead.Still then "still"elseif(ctx.gap or 0)>Lead.Far then "far"else nil
	if not why then return nil end
	w.still=0;w.coolUntil=ctx.now+Lead.Cool
	if w.count>=Lead.Nudges then return "park",why end
	w.count+=1;w.mark=ctx.toNest;w.thisWayUntil=ctx.now+Lead.ThisWay
	return "nudge",why
end
-- Pure: does "This way!" replace the headline now?
function Lead.thisWay(w,now)return w~=nil and type(w.thisWayUntil)=="number"and now<w.thisWayUntil end

-- ── Words (UICopy keys; BearNeeds and NestLead read them) ────────────────────────────────────────────────────────────
-- The four prompts: {headline, sub-line or nil, icon}. Headline 16 characters or fewer, the sub-line 28 or fewer.
Lead.Prompts=table.freeze({
	needHi={head="onbLead.pet",icon="hand"},
	follow={head="onbLead.follow",sub="onbLead.followSub",icon="paws"},
	tuck={head="onbLead.tuck",sub="onbLead.tuckSub",icon="moon"},
	needDeck={head="onbLead.deck",sub="onbLead.deckSub",icon="deck"},
})
Lead.ThisWayCopy="onbLead.thisWay"
Lead.ToastCopy="onbLead.toast"
-- Beta (40) ("Hatches in X h / X min" always): the tuck's sub-line and the toast count down, never "tomorrow".
Lead.CountCopy=table.freeze({sub=table.freeze({hours="onbLead.tuckSub",minutes="onbLead.tuckSubMin"}),
	toast=table.freeze({hours="onbLead.toast",minutes="onbLead.toastMin"})})
-- Pure: the countdown words for `which` ("sub" or "toast") with `left` seconds to the hatch: a UICopy key and its vars
-- (Nest.countdown: whole hours over an hour, else minutes, rounded up). nil or a ready egg reads a fresh egg's nap
-- (Nest.Seconds): the tuck comes right after the egg lands.
function Lead.hatchWords(which,left)
	local Nest=require(script.Parent.Nest)
	local keys=Lead.CountCopy[which]or Lead.CountCopy.sub
	local kind,value=Nest.countdown(left)
	if kind=="ready"then kind,value=Nest.countdown(Nest.Seconds)end
	if kind=="minutes"then return keys.minutes,{minutes=value}end
	return keys.hours,{hours=value}
end
return table.freeze(Lead)
