-- Every-frame position and heading; only ground sampling is throttled.
local Players = game:GetService("Players")
local Activity=require(game:GetService("ReplicatedStorage").Shared.GardenActivity)
local Follow = {}

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
end

function Follow.step(visual, root, dt, state, reduced)
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
	local far = (visual.origin - desired).Magnitude > 40
	if state.groundIn <= 0 or far then
		state.groundIn = 0.10
		state.groundY = Follow.ground(desired, visual, state.groundY)
	end
	local target = Vector3.new(desired.X, state.groundY or visual.origin.Y, desired.Z)
	local delta = Vector3.new(target.X - visual.origin.X, 0, target.Z - visual.origin.Z)
	local old = visual.origin
	visual.origin = if far then target else old:Lerp(target, 1 - math.exp(-10 * dt))
	local traveled=Vector3.new(visual.origin.X-old.X,0,visual.origin.Z-old.Z).Magnitude
	if changedRoot or far or reduced then
		Follow.rest(visual);state.travelSpeed=0
	else
		local speed=if dt>0 then traveled/dt else 0
		state.travelSpeed=(state.travelSpeed or 0)+(speed-(state.travelSpeed or 0))*(1-math.exp(-12*dt))
		local weight=math.clamp((state.travelSpeed-.025)/3.5,0,1)
		visual.gaitWeight=if weight<.002 then 0 else weight
		if visual.gaitWeight==0 then visual.gaitPhase=0
		else
			-- Distance drives slow steps; fast following never aliases into a tremor.
			local cycles=math.min(traveled/(1.45*(visual.worldScale or 1)),dt*3.5)
			visual.gaitPhase=((visual.gaitPhase or 0)+cycles*math.pi*2)%(math.pi*2)
		end
	end
 visual.movementBob=(1-math.cos(visual.gaitPhase or 0))*.025*(visual.gaitWeight or 0)
	local toward = if delta.Magnitude > 0.30 then delta else Vector3.new(root.Position.X - old.X, 0, root.Position.Z - old.Z)
	if toward.Magnitude > 0.05 then
		local wanted = math.atan2(toward.X, toward.Z) -- pet fronts face +Z
		local yaw = visual.yaw or wanted
		local angle = math.atan2(math.sin(wanted - yaw), math.cos(wanted - yaw))
		visual.yaw = yaw + angle * (1 - math.exp(-11 * dt))
	end
	return state
end

-- Shared server-time paths move every rendered frame. The cosmetic renderer is
-- free to sample its expression/limbs less often; it never owns root movement.
function Follow.activity(visual,actor,now,dt,state,reduced)
	local sample=Activity.sample(actor,now)
	if not sample then return state end
	state=state or {};local old=visual.origin
	visual.origin,visual.yaw,visual.reducedEffects=sample.position,sample.yaw,reduced==true
	local traveled=Vector2.new(visual.origin.X-old.X,visual.origin.Z-old.Z).Magnitude
	if state.generation~=sample.generation or reduced or dt<=0 or traveled>8 then
		Follow.rest(visual)
	else
		local speed=traveled/math.max(.001,dt)
		visual.gaitWeight=math.clamp((speed-.025)/3.5,0,1)
		visual.gaitPhase=if visual.gaitWeight<.002 then 0 else ((visual.gaitPhase or 0)+math.min(traveled/(1.45*(visual.worldScale or 1)),dt*3.5)*math.pi*2)%(math.pi*2)
		visual.movementBob=(1-math.cos(visual.gaitPhase))*.025*visual.gaitWeight
	end
	state.generation=sample.generation
	visual.gardenFocus=sample.action=="focus"
	if visual.applyGardenPose then visual:applyGardenPose(sample)
	else
		visual.gardenAction,visual.actionPhase,visual.expression=sample.action,sample.actionPhase,sample.expression
		if sample.action=="greet"and state.actionId~=sample.actionId and not reduced then visual:greet()end
	end
	state.actionId=sample.actionId
	return state
end

return Follow
