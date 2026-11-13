-- Every-frame position and heading; only ground sampling is throttled.
local Players = game:GetService("Players")
local Activity=require(game:GetService("ReplicatedStorage").Shared.GardenActivity)
local Layout=require(game:GetService("ReplicatedStorage").Shared.GardenLayout)
local Follow = {}

-- Walk retune (FEEL-ALIVE-DIRECTION-2026-11-13 B2): stride grows with speed so the
-- feet stop sliding at the cadence cap, and the body bounces twice per cycle, once
-- per footfall (Ovelle a little less). Above 7 studs a second the bob is 1.5x (a
-- scamper). Shared by both gait paths.
Follow.StrideSlow, Follow.StrideFast, Follow.CadenceCap = 1.5, 3.2, 3
Follow.Bob, Follow.BobOvelle, Follow.ScamperSpeed = .05, .042, 7
function Follow.stride(speed, scale)
	local t = math.clamp(((speed or 0) - 3) / 6, 0, 1)
	return (Follow.StrideSlow + (Follow.StrideFast - Follow.StrideSlow) * t) * (scale or 1)
end
function Follow.bob(visual, reduced)
	if reduced then return 0 end
	local phase = visual.gaitPhase or 0
	local amount = if visual.petId == "puddle" then Follow.BobOvelle else Follow.Bob
	local scamper = if (visual.travelSpeed or 0) > Follow.ScamperSpeed then 1.5 else 1
	return (1 - math.cos(2 * phase)) * .5 * amount * scamper * (visual.gaitWeight or 0)
end

function Follow.ground(position, visual, fallback)
	local params = RaycastParams.new()
	local exclude = { visual.model }
	for _, player in ipairs(Players:GetPlayers()) do
		if player.Character then table.insert(exclude, player.Character) end
	end
	params.FilterDescendantsInstances = exclude
	params.RespectCanCollide = true
	local hit = workspace:Raycast(position + Vector3.new(0, 8, 0), Vector3.new(0, -80, 0), params)
	return if hit then hit.Position.Y + 0.025 else fallback or 4.025
end

function Follow.rest(visual)
	visual.gaitPhase,visual.gaitWeight,visual.movementBob=0,0,0
	visual.travelSpeed=0
end

function Follow.step(visual, root, dt, state, reduced)
 require(script.Parent.PetCarePose).set(visual,nil)
 visual.gardenPivot=false;visual.gardenPivotPhase=0;visual.gardenPivotTurn=0
 visual.activitySit=false;visual.gardenActionAge=nil;visual.gardenActionLength=nil
	if visual.gardenFocus or visual.gardenAction then
		visual.gardenFocus=false
		if visual.applyGardenPose then visual:applyGardenPose({expression="neutral",actionPhase=0})end
		visual.gardenAction=nil
	end
	state = state or {}
	local changedRoot=state.root~=root
	state.root=root
	if changedRoot then state.groundIn,state.groundY=0,nil end
	visual.reducedEffects=reduced==true
	dt = math.clamp(dt, 0, 0.1)
	local desired = root.Position - root.CFrame.LookVector * 3 + root.CFrame.RightVector * 2.6
	state.groundIn = (state.groundIn or 0) - dt
	local far=state.ownerPosition~=nil and (root.Position-state.ownerPosition).Magnitude>40
    state.ownerPosition=root.Position
	if state.groundIn <= 0 or far then
		state.groundIn = 0.10
		state.groundY = Follow.ground(desired, visual, state.groundY)
	end
	local target = Vector3.new(desired.X, state.groundY or visual.origin.Y, desired.Z)
	local delta = Vector3.new(target.X - visual.origin.X, 0, target.Z - visual.origin.Z)
	local old = visual.origin
	local gap=(target-old).Magnitude
    local speed=Layout.WalkSpeed+math.clamp((gap-4)/8,0,1)*(Layout.CatchupSpeed-Layout.WalkSpeed)
    if gap>16 then speed=Layout.CatchupSpeed+math.clamp((gap-16)/14,0,1)*(Layout.LeashSpeed-Layout.CatchupSpeed)end
    local wanted=if gap>.01 then (target-old).Unit*math.min(speed,gap*2)else Vector3.zero
    local velocity=state.velocity or Vector3.zero
    local change=wanted-velocity;local maxChange=12*dt
    velocity+=if change.Magnitude>maxChange then change.Unit*maxChange else change
    state.velocity=velocity
    visual.origin=if far then target else old+velocity*dt
    if far then state.velocity=Vector3.zero end
	local traveled=Vector3.new(visual.origin.X-old.X,0,visual.origin.Z-old.Z).Magnitude
	if changedRoot or far then
		Follow.rest(visual);state.travelSpeed=0
	else
		local speed=if dt>0 then traveled/dt else 0
		state.travelSpeed=(state.travelSpeed or 0)+(speed-(state.travelSpeed or 0))*(1-math.exp(-12*dt))
		local weight=math.clamp((state.travelSpeed-.025)/3.5,0,1)
		visual.gaitWeight=if weight<.002 then 0 else weight
		if visual.gaitWeight==0 then visual.gaitPhase=0
		else
			-- Distance drives slow steps; fast following never aliases into a tremor.
			local cycles=math.min(traveled/Follow.stride(state.travelSpeed,visual.worldScale),dt*Follow.CadenceCap)
			visual.gaitPhase=((visual.gaitPhase or 0)+cycles*math.pi*2)%(math.pi*2)
		end
		visual.travelSpeed=state.travelSpeed
	end
 visual.movementBob=Follow.bob(visual,reduced)
	local toward=Vector3.new(velocity.X,0,velocity.Z)
	if toward.Magnitude > 0.05 then
		local wanted = math.atan2(toward.X, toward.Z) -- pet fronts face +Z
		local yaw = visual.yaw or wanted
		local angle = math.atan2(math.sin(wanted - yaw), math.cos(wanted - yaw))
		visual.yaw = yaw + angle * (1 - math.exp(-18 * dt))
	end
	return state
end

-- Shared server-time paths move every rendered frame. The cosmetic renderer is
-- free to sample its expression/limbs less often; it never owns root movement.
function Follow.activity(visual,actor,now,dt,state,reduced)
 local care=actor.care;local CarePose=require(script.Parent.PetCarePose)
 CarePose.set(visual,care and care.state)
 if care and(care.state=="Carried"or care.state=="Docked"or care.state=="Placed")then
  visual.reducedEffects=reduced==true;Follow.rest(visual);visual.gardenPivot=false;visual.gardenFocus=false;visual.gardenAction=actor.action;visual.expression="pleased"
  local holder=Players:GetPlayerByUserId(actor.ownerId);local character=holder and holder.Character
  if care.state=="Carried"then CarePose.carried(visual,character,dt)
  else visual.origin=CarePose.blend(visual,Activity.vector(actor.to)or visual.origin,dt);visual.yaw=actor.yaw or 0 end
  return {generation=actor.generation,mode=actor.mode,actionId=actor.actionId}
 end
	-- A small shared presentation delay absorbs ordinary replication transit.
    -- Focus and Back share that history; private owner staging never enters it.
    local sampleTime=now-.12
    if actor.previous and sampleTime<actor.startTime then actor=actor.previous end
    local sample=Activity.sample(actor,sampleTime)
	if not sample then return state end
	state=state or {};local old=visual.origin
	visual.origin,visual.reducedEffects=sample.position,reduced==true
    visual.yaw=sample.yaw;visual.gardenPivot=sample.pivot==true;visual.gardenPivotPhase=sample.pivotPhase or 0;visual.gardenPivotTurn=sample.pivotTurn or 0
    state.travelYaw=visual.yaw
	local traveled=Vector2.new(visual.origin.X-old.X,visual.origin.Z-old.Z).Magnitude
	if sample.mode=="Focus"or dt<=0 or traveled>8 then
		Follow.rest(visual)
	else
		local speed=traveled/math.max(.001,dt)
		state.travelSpeed=(state.travelSpeed or 0)+(speed-(state.travelSpeed or 0))*(1-math.exp(-12*dt))
		visual.gaitWeight=math.clamp((state.travelSpeed-.025)/3.5,0,1)
		visual.gaitPhase=if visual.gaitWeight<.002 then 0 else ((visual.gaitPhase or 0)+math.min(traveled/Follow.stride(state.travelSpeed,visual.worldScale),dt*Follow.CadenceCap)*math.pi*2)%(math.pi*2)
		visual.travelSpeed=state.travelSpeed
		visual.movementBob=Follow.bob(visual,reduced)
	end
	state.generation,state.mode=sample.generation,sample.mode
	visual.gardenFocus=sample.action=="focus"
	-- Shared-clock age and length of the current action: every player sees the same sit.
	local started,ended=actor.startTime,actor.endTime
	visual.gardenActionAge=if type(started)=="number"then sampleTime-started else nil
	visual.gardenActionLength=if type(started)=="number"and type(ended)=="number"then ended-started else nil
	if visual.applyGardenPose then visual:applyGardenPose(sample)
	else
		visual.gardenAction,visual.actionPhase,visual.expression=sample.action,sample.actionPhase,sample.expression
		if sample.action=="greet"and state.actionId~=sample.actionId and not reduced then visual:greet()end
	end
	state.actionId=sample.actionId
	return state
end

return Follow
