-- Every-frame position and heading; only ground sampling is throttled.
local Players = game:GetService("Players")
local Activity=require(game:GetService("ReplicatedStorage").Shared.GardenActivity)
local Layout=require(game:GetService("ReplicatedStorage").Shared.GardenLayout)
local Follow = {}

-- Walk retune (FEEL-ALIVE-DIRECTION-2026-11-13 B2): stride grows with speed so the
-- feet stop sliding at the cadence cap, and the body bounces twice per cycle, once
-- per footfall (Ovelle a little less). Above 7 studs a second the bob is 1.5x (a
-- scamper). Shared by both gait paths.
-- Beta (34) QA ("they're floating around ... walking needs to be cuter / more natural"): a baby's walk is short quick
-- steps with a visible hop on each footfall. The stride (one left and one right step, x the pet's world scale, so
-- smaller pets step quicker) shortened 1.5 -> 1.25 at a stroll, the cadence cap rose 3 -> 3.5 strides a second, the
-- footfall hop grew .05 -> .085 (x the pet's scale in GardenPetVisual) and became a bounce (|sin|: quick off the
-- ground, round at the top) instead of a sway, and the walk reaches full weight at 1.6 studs a second (was 3.5, so a
-- park stroll at 1.3 drew a third of a gait: the glide).
-- Beta (42) note 16, D16 ("the torso isnt moving with its feet, the torso is too high above the feet"): the bob now
-- dips at each footfall and is back at rest by mid-step (PetHop.walkBob), never lifting the body over the planted
-- feet; .085 -> .07 deep (Ovelle .07 -> .055), a scamper x1.3 (was x1.5 up).
Follow.StrideSlow, Follow.StrideFast, Follow.CadenceCap = 1.25, 3.2, 3.5
Follow.Bob, Follow.BobOvelle, Follow.ScamperSpeed = .07, .055, 7
Follow.ScamperBob = 1.3
Follow.FullGait = 1.6
function Follow.stride(speed, scale)
	local t = math.clamp(((speed or 0) - 3) / 6, 0, 1)
	return (Follow.StrideSlow + (Follow.StrideFast - Follow.StrideSlow) * t) * (scale or 1)
end
-- The gait's weight (0 standing, 1 walking) at a travel speed.
function Follow.weight(speed)
	local weight = math.clamp(((speed or 0) - .03) / Follow.FullGait, 0, 1)
	return if weight < .002 then 0 else weight
end
function Follow.bob(visual, reduced)
	if reduced then return 0 end
	local phase = visual.gaitPhase or 0
	local amount = if visual.petId == "puddle" then Follow.BobOvelle else Follow.Bob
	local scamper = if (visual.travelSpeed or 0) > Follow.ScamperSpeed then Follow.ScamperBob else 1
	return require(script.Parent.PetHop).walkBob(phase, amount, scamper, visual.gaitWeight or 0)
end
-- The body's lean into a change of pace (radians, + forward): a little forward as a walk gets going, back as it
-- settles. `state` keeps the smoothed speed between frames; reduced motion: none.
Follow.LeanPerAccel, Follow.LeanMax = .035, .09
function Follow.lean(state, speed, dt, reduced)
	if reduced or dt <= 0 then state.accelLean = 0;return 0 end
	local last = state.leanSpeed or speed
	state.leanSpeed = speed
	local accel = (speed - last) / dt
	local target = math.clamp(accel * Follow.LeanPerAccel, -Follow.LeanMax, Follow.LeanMax)
	state.accelLean = (state.accelLean or 0) + (target - (state.accelLean or 0)) * (1 - math.exp(-8 * dt))
	return state.accelLean
end

-- Code review (cliff den): where a pet ground ray starts. Inside the open Play Den it starts under the room's collision
-- ceiling (DenLayout.groundRayTop, as the server's); anywhere else (and on live) exactly `above` over the point.
function Follow.rayTop(position, above)
	local ok, top = pcall(function()
		local Shared = game:GetService("ReplicatedStorage"):FindFirstChild("Shared")
		local PlayDen = Shared and require(Shared:FindFirstChild("PlayDen"))
		if not PlayDen or not PlayDen.isOpen() then return nil end
		local DenLayout = require(Shared:FindFirstChild("DenLayout"))
		local layout = DenLayout.current()
		return layout and DenLayout.groundRayTop(layout, position, above)
	end)
	return if ok and type(top) == "number" then top else position.Y + above
end

function Follow.ground(position, visual, fallback)
	local params = RaycastParams.new()
	local exclude = { visual.model }
	-- Pet Park player colliders and seats are not pet ground.
	local park = workspace:FindFirstChild("PetPark")
	if park then table.insert(exclude, park) end
	-- Nor the river stones' player colliders (beta 17: the Garden Dash model; its props never collide).
	local dash = workspace:FindFirstChild("GardenDash")
	if dash then table.insert(exclude, dash) end
	for _, player in ipairs(Players:GetPlayers()) do
		if player.Character then table.insert(exclude, player.Character) end
	end
	params.FilterDescendantsInstances = exclude
	params.RespectCanCollide = true
	local hit = workspace:Raycast(Vector3.new(position.X, Follow.rayTop(position, 8), position.Z), Vector3.new(0, -80, 0), params)
	return if hit then hit.Position.Y + 0.025 else fallback or 4.025
end

function Follow.rest(visual)
	visual.gaitPhase,visual.gaitWeight,visual.movementBob=0,0,0
	visual.travelSpeed=0;visual.accelLean=0
	visual.walkLookYaw,visual.walkLookPitch=0,0
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
		visual.gaitWeight=Follow.weight(state.travelSpeed)
		if visual.gaitWeight==0 then visual.gaitPhase=0
		else
			-- Distance drives slow steps; fast following never aliases into a tremor.
			local cycles=math.min(traveled/Follow.stride(state.travelSpeed,visual.worldScale),dt*Follow.CadenceCap)
			visual.gaitPhase=((visual.gaitPhase or 0)+cycles*math.pi*2)%(math.pi*2)
		end
		visual.travelSpeed=state.travelSpeed
	end
 visual.accelLean=Follow.lean(state,state.travelSpeed or 0,dt,reduced)
 visual.walkLookYaw,visual.walkLookPitch=0,0
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
	-- Beta (12) QA G1: a catch-up hop. The snapshot's hop counter persists, so the poof plays once per new seq even
	-- when the sync has already moved the pet on to "follow". The first sight of a pet only records the seq.
	local hop=actor.hop
	local hopSeq=if type(hop)=="table"and type(hop.seq)=="number"then hop.seq else 0
	if state.hopSeen and hopSeq~=state.hopSeq then
		local from=type(hop)=="table"and Activity.vector(hop.from)or old
		pcall(function()require(script.Parent.PetPoof).play(from,sample.position,reduced==true)end)
	end
	state.hopSeq,state.hopSeen=hopSeq,true
	visual.origin,visual.reducedEffects=sample.position,reduced==true
    visual.yaw=sample.yaw;visual.gardenPivot=sample.pivot==true;visual.gardenPivotPhase=sample.pivotPhase or 0;visual.gardenPivotTurn=sample.pivotTurn or 0
    state.travelYaw=visual.yaw
	-- The lead to the nest (Shared.PetLead, onboarding v3 brief section 1): its hops, the beckon, the arrival bounce
	-- and the jump-spin, from the shared clock, the same on every screen. Reduced Motion: none.
	local action=sample.action
	visual.leadLookYaw=0
	if type(action)=="string"and string.sub(action,1,4)=="lead"and type(actor.startTime)=="number"then
		local Lead=require(game:GetService("ReplicatedStorage").Shared.PetLead)
		local lift,spin,look=Lead.pose(action,sampleTime-actor.startTime,reduced==true)
		if lift~=0 then visual.origin+=Vector3.new(0,lift,0)end
		if spin~=0 then visual.yaw+=spin end
		-- beta 40: trotting on for a following owner, it looks back over the shoulder they are on (every screen)
		if look and look>0 then
			local owner=game:GetService("Players"):GetPlayerByUserId(tonumber(actor.ownerId)or 0)
			local root=owner and owner.Character and owner.Character:FindFirstChild("HumanoidRootPart")
			local rel=if root then CFrame.Angles(0,visual.yaw or 0,0):VectorToObjectSpace(root.Position-visual.origin)else nil
			visual.leadLookYaw=Lead.lookYaw(look,rel)
		end
	end
	local traveled=Vector2.new(visual.origin.X-old.X,visual.origin.Z-old.Z).Magnitude
	if sample.mode=="Focus"or dt<=0 or traveled>8 then
		Follow.rest(visual)
	else
		local speed=traveled/math.max(.001,dt)
		state.travelSpeed=(state.travelSpeed or 0)+(speed-(state.travelSpeed or 0))*(1-math.exp(-12*dt))
		visual.gaitWeight=Follow.weight(state.travelSpeed)
		visual.gaitPhase=if visual.gaitWeight<.002 then 0 else ((visual.gaitPhase or 0)+math.min(traveled/Follow.stride(state.travelSpeed,visual.worldScale),dt*Follow.CadenceCap)*math.pi*2)%(math.pi*2)
		visual.travelSpeed=state.travelSpeed
		visual.movementBob=Follow.bob(visual,reduced)
		visual.accelLean=Follow.lean(state,state.travelSpeed,dt,reduced)
	end
	-- A look round (or a sniff) in the pause after a stroll, the same on every screen (PetWalkBeats).
	visual.walkLookYaw,visual.walkLookPitch=require(script.Parent.PetWalkBeats).sample(sample.action,actor.actionId,
		if type(actor.startTime)=="number"then sampleTime-actor.startTime else 0,reduced==true or sample.mode=="Focus")
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
