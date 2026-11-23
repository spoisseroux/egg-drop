-- Things to do: which onboarding line is due, and what holds it back (V3-THINGS-TO-DO-PLAN-2026-11-22). Pure.
-- CoachCards asks due() on its last branch and blocked() every frame a line waits or shows; init.client reads the game.
--   parkInvite  a new player, after the garden tour and the first egg, who has not been to the Pet Park
--   dashIntro   Garden Dash is on and the first egg is done: after a play date, or at once for a returning player
--               (who reads "New in the garden"); never for someone who has raced
--   findsIntro  Garden finds is on and one of my finds sparkles within Finds.Notice (veterans too)
-- Each once ever (coachMask). At most Max lines a session, Gap seconds apart, counted when a line is really shown.
local Shared=game:GetService("ReplicatedStorage"):WaitForChild("Shared")
local Coach=require(Shared:WaitForChild("CoachMarks"))
local Tips={}
Tips.Max=2
Tips.Gap=300
Tips.Idle=1.2   -- still this long
Tips.Away=20    -- no input for this long: away
Tips.Settle=2.5 -- free in the garden this long

-- The player this session began as: had the tour, or the wins, before it. `state` is the first Ready snapshot.
function Tips.returning(state)
	if type(state)~="table"then return false end
	return Coach.has(state.coachMask,"gardenIntro")or Coach.veteran(state.totalWins)
end
-- What keeps a line off the rail now (nil = nothing). g is the game as init.client reads it; `started` is nil for a line
-- not asked for yet, "queued" while it waits on the rail and "shown" once it is up.
function Tips.blocked(g,started)
	if type(g)~="table"or g.on~=true then return "off"end
	if g.mode~="Room"or g.canRoam~=true then return "roam"end
	if g.revealPending then return "reveal"end
	if g.modal then return "menu"end
	if g.hatch then return "hatch"end
	if g.card then return "card"end
	if g.tour then return "tour"end
	if g.greeting then return "greeting"end
	if g.engaged then return "race"end
	if type(g.action)=="string"and string.match(g.action,"^park")then return "playDate"end
	if(g.parkPending or 0)>0 then return "playDate"end
	if g.care then return "care"end
	if g.petting then return "petting"end
	if g.purchase then return "purchase"end
	if g.windowActive==false or(g.awayFor or 0)>=Tips.Away then return "away"end
	if started=="shown"then return nil end
	if(g.idleFor or 0)<Tips.Idle then return "moving"end
	if started=="queued"then return nil end
	if(g.roomFor or 0)<Tips.Settle then return "settling"end
	if g.railEmpty~=true then return "rail"end
	return nil
end
-- ctx: {mask, seen, totalWins, owned, firstEgg, dashOn, raced, playDates, returning, findsNear, shown, lastAt, now, gate, needs}.
-- The coach id due now and the NoticeCards id it reads from, or nil.
function Tips.due(ctx)
	if(ctx.owned or 0)<=0 or ctx.firstEgg~=true then return nil end
	if(ctx.shown or 0)>=Tips.Max then return nil end
	if ctx.lastAt and(ctx.now or 0)-ctx.lastAt<Tips.Gap then return nil end
	local id,copy
	-- Onboarding v3: with the need bubbles on, need 5 (the park) takes the park line's place.
	if ctx.needs~=true and Coach.wants("parkInvite",ctx)and Coach.has(ctx.mask,"gardenIntro")and Coach.wants("park",ctx)then
		id,copy="parkInvite","parkInvite"
	elseif ctx.dashOn==true and ctx.raced~=true and not Coach.has(ctx.mask,"dashSeen")and Coach.wantsIntro("dashIntro",ctx)
		and(ctx.returning==true or(ctx.playDates or 0)>=1)then
		id,copy="dashIntro",if ctx.returning==true then "dashNew"else "dashIntro"
	elseif ctx.findsNear==true and Coach.wantsIntro("findsIntro",ctx)then
		id,copy="findsIntro","findsIntro"
	end
	if not id or Tips.blocked(ctx.gate)then return nil end
	return id,copy
end

-- ── Follow the Bear (ONBOARDING-V3-PLAN-2026-11-23 section 3, architect review) ───────────────────────────────────────
-- Station label tips: one line on the station's own label, the first time the player comes within its label range.
-- Their own bits, never hatch/style/companions/park (those drive funnel step 6 and the first-visit cards).
Tips.TipBits=table.freeze({Eggs="tipHatch",Customize="tipStyle",Journal="tipCompanions",Park="tipPark",Nest="tipNest"})
Tips.TipCopy=table.freeze({tipHatch="onb3.tip.hatch",tipStyle="onb3.tip.style",tipCompanions="onb3.tip.companions",tipPark="onb3.tip.park",tipNest="onb3.tip.nest"})
Tips.IdleHint=20  -- standing still this long with an open need: the Bear chirps, the bubble hops, the prints replay
Tips.IdleHints=3  -- at most this many per need, then it waits quietly
Tips.IntroAfter=60 -- free in the garden this long: the garden step counts as done (gardenIntro), whatever else happened
-- Which tip bit is due at this station now, or nil. ctx: {follow (the session's captured switch), mask, seen, totalWins,
-- owned}. The nest's tip also needs its own part (Coach.allows), which the caller asks.
function Tips.stationTip(station,ctx)
	ctx=ctx or {}
	local id=Tips.TipBits[station]
	if ctx.follow~=true or id==nil then return nil end
	return if Coach.wants(id,ctx)then id else nil
end
-- The idle hint. track = {} kept by the caller; key = what is open now (a need id, or "follow"), nil = nothing open.
-- True when a hint is due now (and counts it): idleFor seconds standing still, at most IdleHints per key, IdleHint apart.
function Tips.idleDue(track,key,idleFor,now)
	if key==nil then return false end
	if track.key~=key then track.key,track.count,track.lastAt=key,0,nil end
	if track.count>=Tips.IdleHints or(idleFor or 0)<Tips.IdleHint then return false end
	if track.lastAt and now-track.lastAt<Tips.IdleHint then return false end
	track.count+=1;track.lastAt=now
	return true
end
-- The garden step (gardenIntro) under follow the Bear: done when Say hi is done (the bubbles on) or the first trail is over
-- (bubbles off: arrived, skipped or timed out), or after IntroAfter seconds free in the garden, whichever is first.
-- ctx: {saidHi, trailOver, gardenFor, needs}.
function Tips.followDone(ctx)
	if(ctx.gardenFor or 0)>=Tips.IntroAfter then return true end
	if ctx.needs==true then return ctx.saidHi==true end
	return ctx.trailOver==true
end
return table.freeze(Tips)
