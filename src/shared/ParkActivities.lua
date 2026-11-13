-- Pet Park activity catalogue (BUILD-PLAN 2026-11-13, slice K1). Pure data and pure timing
-- helpers shared by the server director and the client (K3). Nothing here reads the clock,
-- awards anything or touches instances.
--
-- A session's timeline: the pet walks to its slot (planned path time, not listed here), then
-- the play phases run back to back from the session's `startTime` (absolute server time).
-- The snapshot carries startTime/endTime, so any viewer (including a late joiner) derives the
-- current phase, swing/see-saw beat and castle stage from the same numbers.
--
-- Actor actions (GardenState snapshot `action`): "parkApproach" while walking/waiting, then the
-- activity's `action` for the whole play; each phase names the finer pose the client plays
-- (parkSwingMount, parkSwing, parkSlideClimb, parkSlideSit, parkSlide, parkTumble, parkSlideReturn,
-- parkSeesaw, parkDig, parkBall, parkBallToss, parkHopOff, parkCheer). "parkHopOff" is also the
-- actor action of a pet whose see-saw partner left.
--
-- Phase `at` names a ground point of the slot (ParkLayout.Slots[*]): "approach" (default) or
-- "chuteEnd". A phase whose point differs from the previous one moves the pet there over the
-- phase (the server path); the client adds the height (ladder, deck, chute).
local Activities={Version=1}

Activities.PlayDate=table.freeze({Target=3,Reward=4}) -- once a day: 3 finished activities, +4 Stars
Activities.ApproachAction="parkApproach"
Activities.HopOffAction="parkHopOff"
Activities.HopOffSeconds=.9
Activities.StartBuffer=.25 -- the play starts this long after the slower pet arrives
Activities.RestAfter=3 -- idle seconds after a finished activity before the pet may pick again
Activities.MinPlay=8
Activities.MaxPlay=20

local function phase(name,action,duration,extra)
	local entry={name=name,action=action,duration=duration}
	for key,value in pairs(extra or {})do entry[key]=value end
	return table.freeze(entry)
end
local cheer=phase("cheer","parkCheer",1.4)
local SWING_PERIOD=2.4
local SEESAW_PERIOD=1.8
local TOSS_PERIOD=2.0
local DIG=3.2
local castlePhases={
	phase("dig1","parkDig",DIG,{stage=1}),
	phase("dig2","parkDig",DIG,{stage=2}),
	phase("dig3","parkDig",DIG,{stage=3}),
	phase("admire","parkCheer",1.6),
	phase("crumble","parkCheer",1.4,{crumble=true}),
}
local function define(entry)
	local total=0
	for index,step in ipairs(entry.phases)do total+=step.duration;entry.phases[index]=step end
	entry.phases=table.freeze(entry.phases)
	entry.duration=total
	for index,set in ipairs(entry.slotSets)do entry.slotSets[index]=table.freeze(set)end
	entry.slotSets=table.freeze(entry.slotSets)
	return table.freeze(entry)
end

-- kind: "solo" (one pet) or "duo" (two pets, different owners). slotSets: the alternative slot
-- tuples the activity can use (one slot per participant, in seat order). exclusive: only one
-- session on that equipment at a time (one ball, one castle, one chute, one beam).
-- solo: the solo variant a duo becomes when one partner leaves (nil = the partner hops off).
Activities.ById=table.freeze({
	swing=define({id="swing",equipment="swing",kind="solo",exclusive=false,action="parkSwing",period=SWING_PERIOD,
		slotSets={{"swing1"},{"swing2"}},
		phases={phase("mount","parkSwingMount",1),phase("swing","parkSwing",SWING_PERIOD*4,{period=SWING_PERIOD}),
			phase("hop","parkHopOff",.9),cheer}}),
	slide=define({id="slide",equipment="slide",kind="solo",exclusive=true,action="parkSlide",
		slotSets={{"slide"}},
		phases={phase("climb","parkSlideClimb",2),phase("sit","parkSlideSit",.6),phase("slide","parkSlide",1.2,{at="chuteEnd"}),
			phase("tumble","parkTumble",.8,{at="chuteEnd"}),phase("return","parkSlideReturn",2.2),
			phase("climb2","parkSlideClimb",2),phase("sit2","parkSlideSit",.6),phase("slide2","parkSlide",1.2,{at="chuteEnd"}),
			phase("tumble2","parkTumble",.8,{at="chuteEnd"}),phase("cheer","parkCheer",1.4,{at="chuteEnd"})}}),
	seesaw=define({id="seesaw",equipment="seesaw",kind="duo",exclusive=true,action="parkSeesaw",period=SEESAW_PERIOD,
		slotSets={{"seesaw1","seesaw2"}},
		phases={phase("mount","parkSwingMount",1),phase("bob","parkSeesaw",SEESAW_PERIOD*5,{period=SEESAW_PERIOD}),
			phase("hop","parkHopOff",.9),cheer}}),
	sandbox=define({id="sandbox",equipment="sandbox",kind="solo",exclusive=true,action="parkDig",castle=true,
		slotSets={{"sand1"},{"sand2"}},phases=table.clone(castlePhases)}),
	sandboxDuo=define({id="sandboxDuo",equipment="sandbox",kind="duo",exclusive=true,action="parkDig",castle=true,solo="sandbox",
		slotSets={{"sand1","sand2"}},phases=table.clone(castlePhases)}),
	ball=define({id="ball",equipment="ball",kind="solo",exclusive=true,action="parkBall",period=TOSS_PERIOD,
		slotSets={{"ball1"},{"ball2"}},
		phases={phase("play","parkBall",TOSS_PERIOD*5,{period=TOSS_PERIOD}),cheer}}),
	-- Same phase lengths as `ball`, so a toss whose partner leaves finishes as a solo bounce.
	ballToss=define({id="ballToss",equipment="ball",kind="duo",exclusive=true,action="parkBallToss",period=TOSS_PERIOD,solo="ball",
		slotSets={{"ball1","ball2"}},
		phases={phase("play","parkBallToss",TOSS_PERIOD*5,{period=TOSS_PERIOD}),cheer}}),
})
Activities.Order=table.freeze({"swing","slide","seesaw","sandbox","sandboxDuo","ball","ballToss"})
Activities.Equipment=table.freeze({"swing","slide","seesaw","sandbox","ball"})

local function resolve(activity)
	if type(activity)=="string"then return Activities.ById[activity]end
	return activity
end
local function finite(n)return type(n)=="number"and n==n and math.abs(n)<math.huge end

-- Phase at `now` for a session that starts its play at `startTime`. Returns nil before the start
-- (the pet is still walking/waiting) and after the end. Otherwise a table:
--   index, name, action, at, elapsed (seconds into this phase), t (0..1 in this phase),
--   time (seconds into the play), progress (0..1 of the play), beat (0..1 in the current
--   period, for swing/see-saw/ball phases) and cycle (whole periods done).
function Activities.phaseAt(activity,startTime,now)
	activity=resolve(activity)
	if not activity or not finite(startTime)or not finite(now)then return nil end
	local time=now-startTime
	if time<0 or time>=activity.duration then return nil end
	local offset=0
	for index,step in ipairs(activity.phases)do
		if time<offset+step.duration or index==#activity.phases then
			local elapsed=time-offset
			local result={index=index,name=step.name,action=step.action,at=step.at or "approach",elapsed=elapsed,
				t=math.clamp(elapsed/step.duration,0,1),time=time,progress=time/activity.duration}
			if step.period then
				local beats=elapsed/step.period
				result.cycle=math.floor(beats);result.beat=beats-result.cycle
			end
			return result
		end
		offset+=step.duration
	end
	return nil
end

-- Start offset (seconds after startTime) of a named phase, or nil.
function Activities.phaseStart(activity,name)
	activity=resolve(activity)
	if not activity then return nil end
	local offset=0
	for _,step in ipairs(activity.phases)do
		if step.name==name then return offset end
		offset+=step.duration
	end
	return nil
end

-- Castle stage for sandbox sessions, derived from startTime (never stored):
--   0 before the first dig finishes and after the session ends, 1..3 as each dig phase
--   completes, 3 while admiring, 4 while crumbling. Second value: 0..1 progress of the
--   current dig (the growing pile) or of the crumble.
function Activities.stageAt(activity,startTime,now)
	activity=resolve(activity)
	if not activity or not activity.castle then return 0,0 end
	local current=Activities.phaseAt(activity,startTime,now)
	if not current then return 0,0 end
	local done=0
	for index=1,current.index-1 do
		local step=activity.phases[index]
		if step.stage then done=math.max(done,step.stage)end
	end
	local step=activity.phases[current.index]
	if step.crumble then return 4,current.t end
	if step.stage then return done,current.t end
	return done,1
end

-- A swing joining a swing already in play starts on that swing's beat (side by side).
function Activities.alignedStart(activity,earliest,otherStart)
	activity=resolve(activity)
	if not activity or not activity.period or not finite(otherStart)or earliest<=otherStart then return earliest end
	local beats=math.ceil((earliest-otherStart)/activity.period-1e-9)
	return otherStart+beats*activity.period
end

-- Whether the activity can be started by `count` pets (1 or 2).
function Activities.fits(activity,count)
	activity=resolve(activity)
	return activity~=nil and((activity.kind=="solo"and count==1)or(activity.kind=="duo"and count==2))
end

return table.freeze(Activities)
