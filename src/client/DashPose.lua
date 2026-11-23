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
return Pose
