-- The Garden Dash line's rope ring (beta 14 QA F2; artifacts/qa-2026-11-23-beta14/WORLD-AND-NEST-LOOK.md section 5,
-- NEST-AND-RACE-LINE-BUILD-PLAN section 4 and its architect review). Shared and pure: the numbers the server's stray
-- rule (DashHost) and the client's ring and root clamp (DashLine) both read, and the geometry they share. The ring
-- stands round Course.Pad; build_dash_course.py checks it against the course, the obstacles and the cliff.
--   Radius      the rope (R)
--   Enter       a waiting player's root once this near the pad's middle is "in": the server latches it, the client
--               starts clamping
--   Stray       once in, a root further than this for StraySeconds leaves the line (server, every CheckEvery)
local Course=require(script.Parent.DashCourse)
local Ring={}
Ring.Radius=4.0
Ring.Enter=Ring.Radius-.6
Ring.Stray=Ring.Radius+2.5
Ring.StraySeconds=1
Ring.Stakes=10
Ring.StakeSize=Vector3.new(.16,1,.16)
Ring.StakeSink=.1
Ring.StakeLean=4      -- degrees, outward
Ring.CapHeight=.12
Ring.Sag=.22          -- studs at mid-span
Ring.SwaySag=.34
Ring.RopeWidth=.11
Ring.PlateSize=9
Ring.Rise=.45;Ring.RiseLag=.05;Ring.RopeFade=.3;Ring.SinkAfter=2;Ring.ReducedFade=.3
Ring.PushEvery=4;Ring.PushReach=.6;Ring.PushDot=.5;Ring.Sway=.5

-- The pad's middle on the ground.
function Ring.centre()
	local pad=Course.Pad
	return Vector3.new(pad.x/100,pad.y/100,pad.z/100)
end
local function flat(a,b)return Vector2.new(a.X-b.X,a.Z-b.Z).Magnitude end
-- Flat studs from the pad's middle.
function Ring.distance(at,centre)return flat(at,centre or Ring.centre())end
-- Stake k (1..Stakes): its angle (radians) and its foot on the ring at ground height `y`.
function Ring.stake(k,centre)
	centre=centre or Ring.centre()
	local a=(k-1)/Ring.Stakes*math.pi*2
	return a,Vector3.new(centre.X+math.cos(a)*Ring.Radius,centre.Y,centre.Z+math.sin(a)*Ring.Radius)
end
-- A cubic Bezier's middle drops 0.75 x CurveSize when both ends' axes point down: the CurveSize for a sag.
function Ring.curve(sag)return sag/.75 end
-- Is the ring up for a roster? Someone in the line, or a race gathering.
function Ring.wanted(roster)
	if type(roster)~="table"then return false end
	return roster.phase=="gather"or(type(roster.queue)=="table"and #roster.queue>0)
end
-- The clamp: a root outside `limit` flat studs from the middle comes back onto that circle (Y kept). Returns the new
-- position and the outward unit, or nil when it is inside.
function Ring.clamp(at,centre,limit)
	centre=centre or Ring.centre()
	limit=limit or Ring.Enter
	local dx,dz=at.X-centre.X,at.Z-centre.Z
	local d=math.sqrt(dx*dx+dz*dz)
	if d<=limit or d<1e-6 then return nil end
	local ux,uz=dx/d,dz/d
	return Vector3.new(centre.X+ux*limit,at.Y,centre.Z+uz*limit),Vector3.new(ux,0,uz)
end
-- The server's line rule for one check. rec = {inside, strayAt} (kept by the caller), far = flat studs, dy = height
-- gap, now = clock. Before the root has once been inside Enter the old reach (`reach`) holds, so a player who joined
-- from the prompt can walk in and one kept out by a full ring is never removed for it. Returns ok, reason.
function Ring.rule(rec,far,dy,now,reach,height)
	if far<=Ring.Enter and dy<=height then rec.inside=true end
	if rec.inside then
		if far>Ring.Stray or dy>height then
			rec.strayAt=rec.strayAt or now
			if now-rec.strayAt>=Ring.StraySeconds then return false,"Strayed"end
		else rec.strayAt=nil end
		return true
	end
	if far>reach or dy>height then return false,"Far"end
	return true
end
return table.freeze(Ring)
