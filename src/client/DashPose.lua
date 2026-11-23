-- Garden Dash poses (V3-DASH-BUILD-PLAN-2026-11-22, slice S7). Puts a garden pet on the course for this frame: the run,
-- the hop, the tumble (Reduced Motion: a sit), the puff, the finish. Visual only, through the GardenPetVisual levers
-- ParkPetPose uses; nothing here reads a clock or makes an instance, a table or a closure a frame.
local Grid=require(game:GetService("ReplicatedStorage").Shared.DashGrid)
local Follow=require(script.Parent.PetFollow)
local Pose={}
local TAU=math.pi*2
Pose.JumpSeconds=.42
Pose.JumpHeight=1.2
Pose.TumbleSeconds=.5
Pose.StudScale=.72
-- One per drawn runner, kept for the race.
function Pose.state()
	return{airAge=-1,airHeld=false,tumbleAge=-1,finishAge=-1,x=0,z=0,speed=0,placed=false}
end
function Pose.begin(visual,state)
	state.airAge,state.airHeld,state.tumbleAge,state.finishAge,state.speed,state.placed=-1,false,-1,-1,0,false
	visual.parkPosedOrigin,visual.parkBase=nil,nil
	if visual.applyGardenPose then visual:applyGardenPose({action="follow",actionPhase=0,expression="curious",behavior="follow"})end
end
function Pose.clear(visual)
	visual.parkPose=false
	visual.carePitch,visual.careBodyLower,visual.careHand,visual.careHeadPitch,visual.careHeadRoll=0,0,0,0,0
	visual.careFootForward,visual.careFootLift=0,0
	visual.activitySit=false
	Follow.rest(visual)
end
-- cs, onStones, lane as Sim.spot. flags: air, tumble, stumble, puff, zoom, dash, finished. running: the race is on.
-- count: the racers in the heat (DashGrid centres the lanes on them).
function Pose.step(visual,state,cs,onStones,lane,flags,running,dt,reduced,count)
	local x,y,z,yaw=Grid.at(cs,onStones,lane,count)
	local k=(visual.worldScale or Pose.StudScale)/Pose.StudScale
	local dx,dz=x-state.x,z-state.z
	local moved=if state.placed then math.sqrt(dx*dx+dz*dz)else 0
	if moved>4 then moved=0 end -- a snap, not a run
	state.x,state.z,state.placed=x,z,true
	-- Ages: an arc runs its own length, whatever the flag does.
	if flags.air and not state.airHeld and state.airAge<0 then state.airAge=0;visual.poseDirty=true end
	state.airHeld=flags.air==true
	if state.airAge>=0 then
		state.airAge+=dt
		if state.airAge>=Pose.JumpSeconds then state.airAge=-1;visual.poseDirty=true end
	end
	if flags.tumble then state.tumbleAge=if state.tumbleAge<0 then 0 else state.tumbleAge+dt
	elseif state.tumbleAge>=0 then state.tumbleAge=-1;visual.poseDirty=true end
	state.finishAge=if flags.finished then(if state.finishAge<0 then 0 else state.finishAge+dt)else -1
	visual.reducedEffects=reduced==true
	visual.gardenPivot,visual.gardenFocus=false,false
	visual.yaw=yaw
	visual.carePitch,visual.careBodyLower,visual.careHand,visual.careHeadPitch,visual.careFootForward=0,0,0,0,0
	local lift,pitch=0,0
	if state.tumbleAge>=0 then
		visual.parkPose=true
		visual.gaitWeight,visual.movementBob,visual.travelSpeed=0,0,0
		visual.expression="startled"
		local u=state.tumbleAge/Pose.TumbleSeconds
		if u<1 and not reduced then
			pitch=u*TAU;lift=.35*k*math.sin(math.pi*u)
			visual.activitySit=false;visual.poseDirty=true
		else
			visual.activitySit=true
			-- The shake dry: a small wobble of the head, never of the camera.
			if not reduced then visual.careHeadPitch=.12*math.sin(state.tumbleAge*18);visual.poseDirty=true end
		end
	elseif state.airAge>=0 then
		visual.parkPose=true
		local u=state.airAge/Pose.JumpSeconds
		lift=(if reduced then .6 else Pose.JumpHeight)*k*math.sin(math.pi*u)
		if not reduced then pitch=.24*(u-.5)end
		visual.careFootForward=.09*k*math.sin(math.pi*u)
		visual.gaitWeight,visual.movementBob=0,0
		visual.activitySit=false;visual.expression="joy";visual.poseDirty=true
	elseif running and not flags.finished then
		visual.parkPose=false;visual.activitySit=false
		local speed=if dt>0 then moved/dt else 0
		state.speed+=(speed-state.speed)*(1-math.exp(-12*dt))
		visual.travelSpeed=state.speed
		visual.gaitWeight=math.clamp((state.speed-.025)/3.5,0,1)
		visual.gaitPhase=if visual.gaitWeight<.002 then 0 else((visual.gaitPhase or 0)+math.min(moved/Follow.stride(state.speed,visual.worldScale),dt*Follow.CadenceCap)*TAU)%TAU
		visual.movementBob=Follow.bob(visual,reduced)
		visual.expression=if flags.puff or flags.stumble then "startled"elseif flags.zoom or flags.dash then "joy"else "curious"
		if flags.dash and not reduced then pitch=.1 end
	else
		visual.parkPose=true;visual.activitySit=false
		visual.gaitWeight,visual.movementBob,visual.travelSpeed=0,0,0
		visual.expression=if flags.finished then "joy"else "curious"
		-- The happy hop under the arch (two hops, then still).
		if state.finishAge>=0 and state.finishAge<1.4 and not reduced then
			lift=.45*k*math.abs(math.sin(state.finishAge/1.4*TAU));visual.poseDirty=true
		end
	end
	if pitch~=0 then
		-- Turn about the middle of the body, not the feet (ParkPetPose's flip).
		local h=.6*k
		visual.carePitch=pitch
		local s=math.sin(pitch)
		x-=h*s*math.sin(yaw);z-=h*s*math.cos(yaw)
		lift+=h*(1-math.cos(pitch))
	end
	visual.origin=Vector3.new(x,y+lift,z)
end

-- Beta 12 U3 and U6: the pet on the sheets' stage (DashStage), at the origin facing the camera's side (yaw 0).
Pose.TreadSpeed=6.75 -- studs a second: a 100% pace at the Fun level
Pose.PodiumHop=3     -- seconds between the happy hops on the podium
-- The run cycle on the spot (the mode picker). Reduced Motion: standing, idle.
function Pose.treadmill(visual,state,dt,reduced)
	visual.reducedEffects=reduced==true
	visual.gardenPivot,visual.gardenFocus=false,false
	visual.yaw=0;visual.activitySit=false
	visual.carePitch,visual.careBodyLower,visual.careHand,visual.careHeadPitch,visual.careFootForward=0,0,0,0,0
	if reduced then
		visual.parkPose=true
		visual.gaitWeight,visual.movementBob,visual.travelSpeed=0,0,0
		visual.expression="curious"
	else
		visual.parkPose=false
		local speed=Pose.TreadSpeed*(visual.worldScale or Pose.StudScale)/Pose.StudScale
		visual.travelSpeed=speed
		visual.gaitWeight=1
		visual.gaitPhase=((visual.gaitPhase or 0)+math.min(speed*dt/Follow.stride(speed,visual.worldScale),dt*Follow.CadenceCap)*TAU)%TAU
		visual.movementBob=Follow.bob(visual,reduced)
		visual.expression="joy"
	end
	visual.origin=Vector3.zero
end
-- Pure: the podium's lift in studs at `age` seconds for a finish `place` (k = the pet's size). 1st to 3rd: two hops,
-- then one every PodiumHop s; lower: one hop. Reduced Motion: none.
function Pose.podiumLift(age,place,k,reduced)
	if reduced or age<0 then return 0 end
	local hops=if place<=3 then 2 else 1
	local u=age/Pose.JumpSeconds
	if u<hops then return Pose.JumpHeight*k*math.abs(math.sin(math.pi*u))end
	if place>3 then return 0 end
	-- A hop at the end of every PodiumHop seconds after the first ones.
	local phase=(age-hops*Pose.JumpSeconds)%Pose.PodiumHop
	local start=Pose.PodiumHop-Pose.JumpSeconds
	if phase<start then return 0 end
	return Pose.JumpHeight*.6*k*math.sin(math.pi*(phase-start)/Pose.JumpSeconds)
end
-- The finish pose on the results stage: hops, then a happy idle (a wag of the head for 4th and lower). Never sad.
-- Reduced Motion: sitting and smiling.
function Pose.podium(visual,state,dt,place,reduced)
	state.podiumAge=(state.podiumAge or 0)+dt
	local age=state.podiumAge
	local k=(visual.worldScale or Pose.StudScale)/Pose.StudScale
	visual.reducedEffects=reduced==true
	visual.gardenPivot,visual.gardenFocus=false,false
	visual.yaw=0;visual.parkPose=true
	visual.gaitWeight,visual.movementBob,visual.travelSpeed=0,0,0
	visual.carePitch,visual.careBodyLower,visual.careHand,visual.careHeadPitch,visual.careFootForward=0,0,0,0,0
	visual.expression="joy"
	visual.activitySit=reduced==true
	visual.careHeadRoll=0
	if not reduced and place>3 and age>Pose.JumpSeconds then
		local wag=(age-Pose.JumpSeconds)%Pose.PodiumHop
		if wag<1 then visual.careHeadRoll=.14*math.sin(wag*TAU*2)end
	end
	visual.poseDirty=true
	visual.origin=Vector3.new(0,Pose.podiumLift(age,place,k,reduced),0)
end
return Pose
