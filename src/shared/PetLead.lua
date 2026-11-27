-- The Bear leads you to the nest (artifacts/qa-2026-11-27-beta37/ONBOARDING-V3-BRIEF.md section 1, switch Onboard
-- "lead"; Spencer's beta 37 note 5: "should it run towards the egg like beckoning us to follow it? with edge case
-- handling like if the player doesnt follow etc so no one gets soft blocked"). Shared and pure, spec-checked offline
-- (scripts/PetLead.spec.lua). The server (GardenState:lead) owns where the pet is, so every player sees it lead; the
-- client (NestLead) owns the words, the nudges and the park. Nothing here touches the game.
--
--   start   the Bear chirps, hops twice on the spot and turns to the nest          (server action "leadStart")
--   run     14 studs a second along the player's trail route (never a straight line through fences)   ("leadRun")
--   wait    12 studs ahead of the player it stops, faces them and beckons every 2.5 s ("leadWait")
--           it runs on once the player is within 7 studs (or has passed it)
--   back    a nudge: it runs back along its route to about 5 studs from the player  ("leadBack")
--   arrive  3 studs short of the nest it stops, faces the nest and bounces           ("leadArrive")
--   cheer   the tuck (and the all-set card): a jump and one spin                      ("leadCheer")
local Lead={}

-- ── Numbers ──────────────────────────────────────────────────────────────────────────────────────────────────────────
Lead.Run=14            -- studs a second (the player walks 16)
Lead.Ahead=12          -- this far ahead of the player (and nearer the nest than them) it stops and looks back
Lead.Resume=7          -- the player this close: it runs on
Lead.Arrive=3          -- it stops this far short of the nest's prompt, along the route
Lead.Reach=8           -- the player this close to the nest's prompt: prompt 2a is done (2b shows on the nest)
Lead.Rest=2            -- s between two prompts (was 4)
Lead.Return=2.5        -- s free after a pause (the deck, a menu, leaving the garden) before it leads again
Lead.Toast=3           -- s, the post-tuck toast
Lead.Hops=table.freeze({count=2,height=.6,time=.35})          -- the start: two hops on the spot
Lead.Beckon=table.freeze({every=2.5,height=.6,time=.35,wave=.5}) -- the look back: a hop, a paw wave, a chirp
Lead.Bounce=table.freeze({height=.35,time=.4,every=.9})       -- arrived: a bounce on the spot
Lead.Cheer=table.freeze({time=.6,height=.9,hold=.8})          -- the jump-spin (tucked, all set)
-- The nudges and the park (client, Lead.watch).
Lead.Still=8           -- s the player stands still: a nudge
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
-- Pure (the server's check of the client's route). raw: the route the client sent (Vector3s from the pet to the nest's
-- prompt). ctx: {pet (the pet's position now), nest (where the nest stands), ground(point) -> y or nil, clear(a, b) ->
-- true when nothing solid stands between the two at the pet's body height}. Returns the grounded points, or nil and why.
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
-- walk is still under way)}. Returns "run", "wait", "arrive", "poof" or nil (go on as it is).
function Lead.decide(lead,ctx)
	local phase=lead.phase
	local pet,owner,goal,now=ctx.pet,ctx.owner,ctx.goal,ctx.now
	local atGoal=flat(pet,goal)<=.6
	if phase=="start"then return if ctx.moving then nil else "run"end
	if phase=="back"then return if ctx.moving then nil else "wait"end
	if phase=="arrive"then return nil end
	local gap=flat(pet,owner)
	local ownerPassed=flat(owner,goal)<=flat(pet,goal)
	if phase=="wait"then
		if atGoal then return "arrive"end
		if gap<=Lead.Resume or ownerPassed then return "run"end
		return nil
	end
	if phase=="run"then
		if atGoal or(not ctx.moving and flat(pet,goal)<=1.5)then return "arrive"end
		if gap>=Lead.Ahead and not ownerPassed then return "wait"end
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
	end
	return 0,0
end
-- Pure: the start's length (s): the two hops, then the turn to the nest (turnSeconds of it).
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
return table.freeze(Lead)
