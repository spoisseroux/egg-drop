-- Pet Park poses (BUILD-PLAN 2026-11-13, slice K3). A relative overlay over the shared garden path,
-- like PetCarePose: PetFollow.activity places the pet on the server path, then Pose.apply puts it on
-- the equipment (swing seat, ladder, chute, see-saw seat, sand, ball mat) for the current phase of
-- its park session. Everything comes from the slot entry's server times (ParkActivities.phaseAt),
-- so every viewer sees the same pose and a late joiner lands mid-phase. No instances, no tables and
-- no clock of its own; Reduced Motion keeps the riding (it is content) but drops flips and hops.
--
-- Levers on the GardenPetVisual: origin/yaw (root), carePitch (nose down +), careBodyLower,
-- careHand, careHeadPitch, careFootForward, movementBob, gaitWeight/gaitPhase, activitySit,
-- expression and greet(). parkPose=true tells PetPoseSampler to let the feet follow the root
-- (no planted stance while riding). The caller (ParkClient:drive) restores the server origin
-- before the next PetFollow.activity, so gait and travel are measured on the real path.
local Shared=game:GetService("ReplicatedStorage").Shared
local Park=require(Shared.ParkLayout)
local Catalog=require(Shared.ParkActivities)
local Data=require(Shared.ParkPoseData)
local Pose={}
local TAU=math.pi*2
local UP=Vector3.yAxis
Pose.MountBulge=.9 -- studs the mount/hop arc curls out in front of a seat (seats sit above the slot)
Pose.LandOut=1.25 -- studs in front of a seat the hop lands, clear of the swinging seat
Pose.StepBack=.6 -- the last share of the cheer walks back to the slot point the server holds
Pose.LiftIn=.3 -- seconds to step up onto the sand or the mat

-- Every actor action a park session can carry (the approach walk and each play action).
local actions={}
for _,id in ipairs(Catalog.Order)do
	local activity=Catalog.ById[id];actions[activity.action]=true
	for _,step in ipairs(activity.phases)do actions[step.action]=true end
end
actions[Catalog.ApproachAction]=true;actions[Catalog.HopOffAction]=true
Pose.Actions=table.freeze(actions)

local function ease(u)u=math.clamp(u,0,1);return u*u*(3-2*u)end
local function scaleOf(visual)return(visual.worldScale or .72)/.72 end

-- Polylines with cumulative lengths, built once.
local function polyline(points)
	local lengths,total={0},0
	for i=2,#points do total+=(points[i]-points[i-1]).Magnitude;lengths[i]=total end
	return table.freeze({points=points,lengths=table.freeze(lengths),total=total})
end
local LADDER=polyline(Data.Slide.ladder)
local CHUTE=polyline(Data.Slide.chute)
Pose.Ladder,Pose.Chute=LADDER,CHUTE
-- Point at share u of the polyline and the index of the segment it lies on.
local function along(line,u)
	local s=math.clamp(u,0,1)*line.total
	local points,lengths=line.points,line.lengths
	for i=2,#points do
		if s<=lengths[i]or i==#points then
			local span=lengths[i]-lengths[i-1]
			local w=if span>0 then(s-lengths[i-1])/span else 0
			return points[i-1]:Lerp(points[i],math.clamp(w,0,1)),i
		end
	end
	return points[#points],#points
end
Pose.along=along

-- Clears every lever this module writes (PetFollow.activity's PetCarePose.set clears the care ones
-- each frame; this also covers a standalone call).
function Pose.clear(visual)
	visual.parkPose=false
	visual.carePitch,visual.careBodyLower,visual.careHand,visual.careHeadPitch,visual.careHeadRoll=0,0,0,0,0
	visual.careFootForward,visual.careFootLift=0,0
end
local function begin(visual,session,index)
	Pose.clear(visual)
	visual.parkPose=true;visual.gardenPivot=false
	if visual.parkPhaseSession~=session or visual.parkPhaseIndex~=index then
		visual.parkPhaseSession,visual.parkPhaseIndex=session,index;visual.poseDirty=true
	end
end
local function still(visual)
	visual.gaitWeight,visual.gaitPhase,visual.movementBob,visual.travelSpeed=0,0,0,0
end
-- Arc from a to b that curls `out` (a horizontal vector) away and `lift` up mid-way.
local function arc(a,b,u,out,lift)
	local w=ease(u);local bump=math.sin(math.pi*math.clamp(u,0,1))
	return a:Lerp(b,w)+out*bump+UP*lift*bump
end

local function cheer(visual,entry,phase,position,reduced)
	visual.origin=position
	if visual.parkCheerSession~=entry.session or visual.parkCheerIndex~=phase.index then
		visual.parkCheerSession,visual.parkCheerIndex=entry.session,phase.index
		if not reduced and visual.greet then visual:greet()end
	end
	visual.expression="joy"
	still(visual)
	if not reduced then visual.movementBob=.09*scaleOf(visual)*math.abs(math.sin(TAU*1.6*phase.elapsed))end
end
-- Cheer at a landing point in front of a seat, then walk back to the slot point.
local function cheerAndStepBack(visual,entry,phase,landing,ground,yaw,reduced)
	if phase.t<1-Pose.StepBack then
		cheer(visual,entry,phase,landing,reduced)
		visual.yaw=yaw
		return
	end
	local u=(phase.t-(1-Pose.StepBack))/Pose.StepBack
	visual.origin=landing:Lerp(ground,ease(u))
	visual.yaw=yaw;visual.expression="pleased"
	visual.gaitWeight=if reduced then 0 else .6
	visual.gaitPhase=(u*TAU*2)%TAU;visual.movementBob=0
end

-- Seats: swing and see-saw share mount / ride / hop / cheer.
local function seatFrame(equipment,slotId,entry,t)
	if equipment=="swing"then
		local angle=Data.swingAngle(slotId,entry,t)
		local motion=Data.swingMotion(angle)
		return Data.swingSeat(slotId,angle),Data.Swings[slotId].pivot,motion
	end
	local tilt=Data.seesawTilt(entry,t)
	return Data.seesawSeat(slotId,tilt),Data.SeeSaw.pivot,Data.seesawMotion(tilt)
end
local function seatOut(equipment,slot)
	-- Swings: out in front of the seat. See-saw: off the beam's side that faces the park centre (-Z).
	if equipment=="swing"then return Data.facing(slot.yaw)end
	return Data.Roots.SeeSaw.LookVector
end
local function seats(visual,slotId,entry,activity,phase,t,reduced)
	local slot=Park.Slots[slotId];local ground=slot.approach
	local equipment=activity.equipment;local out=seatOut(equipment,slot)
	local k=scaleOf(visual)
	visual.yaw=slot.yaw
	if phase.action=="parkSwingMount"then
		local seat=seatFrame(equipment,slotId,entry,t)
		visual.origin=arc(ground,seat.Position,phase.t,out*Pose.MountBulge,(if reduced then .2 else .45)*k)
		visual.activitySit=phase.t>.55;visual.expression="joy";still(visual)
	elseif phase.action=="parkSwing"or phase.action=="parkSeesaw"then
		local seat,pivot,motion=seatFrame(equipment,slotId,entry,t)
		visual.origin=seat.Position
		visual.carePitch=Data.pitchFor(pivot,motion,slot.yaw)
		visual.activitySit=true;visual.expression="joy";still(visual)
		if equipment=="swing"then
			-- Lean into the swing and kick the feet on the way forward.
			local angle=Data.swingAngle(slotId,entry,t)
			visual.careHeadPitch=-angle*.35;visual.careFootForward=math.max(0,-angle)*.12*k
		else
			-- Push off at the bottom, arms up at the top.
			local beat=phase.beat or 0;local low=math.cos(TAU*beat)
			local side=if slotId=="seesaw1"then 1 else -1
			visual.careHand=math.max(0,-low*side)*.1*k;visual.careHeadPitch=-.12*math.max(0,-low*side)
		end
	elseif phase.action=="parkHopOff"then
		local start=t-phase.elapsed
		local seat=seatFrame(equipment,slotId,entry,start)
		local landing=ground+out*Pose.LandOut
		visual.origin=arc(seat.Position,landing,phase.t,Vector3.zero,(if reduced then .15 else .5)*k)
		visual.activitySit=phase.t<.25;visual.expression="joy";still(visual)
	else
		cheerAndStepBack(visual,entry,phase,ground+out*Pose.LandOut,ground,slot.yaw,reduced)
	end
	return true
end

local function slide(visual,slotId,entry,activity,phase,t,reduced)
	local slot=Park.Slots[slotId];local yaw=Data.Slide.yaw;local k=scaleOf(visual)
	local action=phase.action
	if action=="parkSlideClimb"then
		local position=along(LADDER,phase.t)
		visual.origin=position;visual.yaw=yaw;visual.expression="curious"
		visual.gaitWeight=if reduced then 0 else .8
		visual.gaitPhase=(phase.t*TAU*5)%TAU;visual.movementBob=0;visual.travelSpeed=0
		visual.carePitch=-.12;visual.careHand=.1*k*math.abs(math.sin(visual.gaitPhase))
	elseif action=="parkSlideSit"then
		visual.origin=Data.Slide.platform:Lerp(Data.Slide.chuteTop,ease(phase.t))
		visual.yaw=yaw;visual.activitySit=true;visual.expression="joy";still(visual)
	elseif action=="parkSlide"then
		local u=math.clamp(phase.t,0,1)^1.6
		local position,index=along(CHUTE,u)
		local a,b=CHUTE.points[index-1],CHUTE.points[index]
		local run=Vector2.new(b.X-a.X,b.Z-a.Z).Magnitude
		visual.origin=position;visual.yaw=yaw
		visual.carePitch=math.atan2(a.Y-b.Y,math.max(1e-3,run))
		visual.careHeadPitch=-.25;visual.activitySit=true;visual.expression="joy";still(visual)
	elseif action=="parkTumble"then
		local from=CHUTE.points[#CHUTE.points];local to=Data.Slide.landing
		local u=ease(phase.t)
		local position=from:Lerp(to,u)
		visual.yaw=yaw;visual.expression="joy";still(visual)
		if reduced then
			visual.origin=position;visual.activitySit=phase.t<.5
		else
			-- One forward roll about the body centre.
			local h=.45*k;local pitch=TAU*u
			local turn=CFrame.Angles(0,yaw,0)*CFrame.Angles(pitch,0,0)
			visual.origin=position+UP*(h+.25*k*math.sin(math.pi*u))-turn:VectorToWorldSpace(UP*h)
			visual.carePitch=pitch
		end
	elseif action=="parkSlideReturn"then
		return false -- the server path walks it back to the ladder
	else
		cheer(visual,entry,phase,slot.chuteEnd,reduced);visual.yaw=yaw
	end
	return true
end

local function sandbox(visual,slotId,entry,activity,phase,t,reduced)
	local slot=Park.Slots[slotId];local k=scaleOf(visual)
	local lift=math.clamp((t-entry.startTime)/Pose.LiftIn,0,1)
	local spot=slot.approach:Lerp(Data.spot(slotId),lift)
	visual.yaw=slot.yaw
	if phase.action=="parkDig"then
		visual.origin=spot;still(visual);visual.expression="pleased"
		local s=math.sin(TAU*2.2*phase.elapsed)
		visual.carePitch=.14;visual.careHeadPitch=.22;visual.careBodyLower=.04*k
		visual.careHand=.07*k*math.max(0,s)
		if not reduced then visual.movementBob=.02*k*math.abs(s)end
	elseif phase.name=="admire"then
		visual.origin=spot;still(visual);visual.activitySit=true;visual.expression="joy";visual.careHeadPitch=-.1
	else
		-- The crumble: a startled blink, then a laugh and a hop.
		cheer(visual,entry,phase,spot,reduced)
		if phase.t<.35 then visual.expression="startled";visual.movementBob=0 end
	end
	return true
end

local function ball(visual,slotId,entry,activity,phase,t,reduced)
	local slot=Park.Slots[slotId];local k=scaleOf(visual)
	local lift=math.clamp((t-entry.startTime)/Pose.LiftIn,0,1)
	local spot=slot.approach:Lerp(Data.spot(slotId),lift)
	visual.yaw=slot.yaw
	if phase.name=="play"then
		visual.origin=spot;still(visual);visual.expression="joy"
		local beat=phase.beat or 0
		local hit=if activity.kind=="duo"and slotId=="ball2"then .5 else 0
		local d=math.abs(beat-hit);d=math.min(d,1-d)
		local pulse=math.max(0,1-d/.12)
		visual.careHand=.14*k*pulse;visual.carePitch=.12*pulse;visual.careHeadPitch=.1
		if not reduced and activity.kind~="duo"then visual.movementBob=.04*k*math.abs(math.sin(TAU*beat))end
	else
		cheer(visual,entry,phase,spot,reduced)
	end
	return true
end

local byEquipment={swing=seats,seesaw=seats,slide=slide,sandbox=sandbox,ball=ball}
local scratch={index=0,name="",action="",elapsed=0,t=0,beat=0}

-- Poses the pet for its slot entry at server time t (already delayed like PetFollow.activity).
-- Returns true when the pet is on the equipment this frame (false while walking to the slot,
-- walking back up to the ladder, or outside the session).
function Pose.apply(visual,slotId,entry,t,dt,reduced)
	local slot=Park.Slots[slotId]
	local activity=entry and Catalog.ById[entry.activity]
	if not slot or not activity or type(entry.startTime)~="number"then return false end
	local index,step,elapsed,u,beat=Data.phase(activity,entry.startTime,t)
	if not index then return false end
	-- One reused phase record (no table per frame).
	local phase=scratch
	phase.index,phase.name,phase.action,phase.elapsed,phase.t,phase.beat=index,step.name,step.action,elapsed,u,beat
	begin(visual,entry.session,index)
	visual.activitySit=false
	local posed=byEquipment[activity.equipment](visual,slotId,entry,activity,phase,t,reduced==true)
	if not posed then Pose.clear(visual)end
	return posed
end

-- A pet whose see-saw partner left hops off where it is (no slot entry any more).
function Pose.hopOff(visual,actor,t,reduced)
	if actor.action~=Catalog.HopOffAction or type(actor.startTime)~="number"then return false end
	local u=(t-actor.startTime)/Catalog.HopOffSeconds
	if u<0 or u>1 then return false end
	begin(visual,"hopOff",actor.actionId)
	visual.activitySit=false;visual.expression="curious";still(visual)
	if not reduced then visual.movementBob=.25*scaleOf(visual)*math.sin(math.pi*u)end
	return true
end

return Pose
